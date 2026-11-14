import base64, hashlib, hmac, os, re, secrets, threading, uuid
import json
import io
import time
import urllib.request
import urllib.error
import urllib.parse
import concurrent.futures
from typing import Any
from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import FileResponse
from xml.sax.saxutils import escape, quoteattr
from PIL import Image, ImageOps
from pillow_heif import register_heif_opener
from sqlalchemy import create_engine, text

DB_URL = os.getenv('DATABASE_URL', 'postgresql+psycopg://crm:crm@db:5432/crm')
engine = create_engine(DB_URL, pool_pre_ping=True)
app = FastAPI(title='Чистое место CRM API', version='1.0')
register_heif_opener()

SCHEMA = '''
create table if not exists crm_users (id text primary key, name text not null, role text not null, active boolean not null default true, pin_hash text not null, permissions jsonb not null default '{}'::jsonb);
create table if not exists crm_sessions (token text primary key, user_id text references crm_users(id), created_at timestamptz not null default now());
create table if not exists crm_changes (id text primary key, scope text not null, payload jsonb not null, created_at timestamptz not null default now());
create table if not exists crm_snapshots (scope text primary key, payload jsonb not null, revision integer not null default 0, updated_at timestamptz not null default now());
create table if not exists crm_revisions (scope text primary key, revision integer not null default 0);
create table if not exists crm_sheets (name text primary key, rows jsonb not null, updated_at timestamptz not null default now());
create table if not exists crm_login_failures (user_id text primary key, attempts integer not null default 0, locked_until timestamptz);
create table if not exists crm_configuration (id integer primary key default 1, payload jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now());
create table if not exists crm_avito_catalog (slug text primary key, name text not null default '', fields jsonb not null, updated_at timestamptz not null default now());
'''

SUPPORTED_SCOPES = {
    'clients', 'stock', 'products', 'deliveries', 'orders', 'manualDeals', 'finance', 'appointments',
    'serviceCatalog', 'workspace', 'dashboardNotes', 'revenuePlans',
    'knowledgeBase', 'messages', 'auditOnly',
}
SCOPE_AREA = {
    'clients': 'clients', 'stock': 'stock', 'products': 'stock', 'deliveries': 'stock', 'orders': 'stock', 'manualDeals': 'deals',
    'finance': 'finance', 'appointments': 'calendar',
    'serviceCatalog': 'integrations', 'workspace': 'dashboard',
    'dashboardNotes': 'dashboard', 'revenuePlans': 'finance',
    'messages': 'messages', 'knowledgeBase': 'bot', 'auditOnly': 'dashboard',
}
RANK = {'hidden': 0, 'view': 1, 'edit': 2}
PERMISSION_AREAS = (
    'dashboard', 'clients', 'deals', 'calendar', 'finance', 'stock',
    'settings', 'messages', 'bot', 'integrations', 'backup',
)
MAX_CHANGES_PER_REQUEST = 20
MAX_SHEET_ROWS = 20000
MAX_SHEET_COLUMNS = 50
MERGE_SCOPES = {'products', 'deliveries', 'orders'}
DEFAULT_SHEET_AREAS = {'Август': 'deals', 'Основное': 'finance', 'Расходы': 'finance'}
MEDIA_DIR = os.getenv('MEDIA_DIR', '/data/media')
MAX_PHOTO_BYTES = 8 * 1024 * 1024
PIN_ITERATIONS = 200_000
MAX_LOGIN_ATTEMPTS = 5
LOCKOUT_MINUTES = 5
SESSION_DAYS = 180


def _prepare_photo(data):
    """Convert HEIF photos to full-resolution JPEG; keep other formats intact."""
    if data.startswith(b'\xff\xd8\xff'):
        return data, 'jpg'
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return data, 'png'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return data, 'webp'
    if data[4:8] != b'ftyp':
        raise ValueError('Поддерживаются JPEG, PNG, WebP и HEIC')
    try:
        with Image.open(io.BytesIO(data), formats=['HEIF']) as source:
            source.seek(0)
            image = ImageOps.exif_transpose(source).convert('RGB')
            result = io.BytesIO()
            options = {'format': 'JPEG', 'quality': 95, 'subsampling': 0}
            if source.info.get('icc_profile'):
                options['icc_profile'] = source.info['icc_profile']
            image.save(result, **options)
            return result.getvalue(), 'jpg'
    except (OSError, ValueError, SyntaxError, Image.DecompressionBombError) as exc:
        raise ValueError('Не удалось прочитать HEIC-фото') from exc


def hash_pin(pin):
    """PBKDF2-HMAC-SHA256 with a per-user salt; four-digit PINs are weak, so
    the server also locks out repeated failures."""
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac('sha256', str(pin).encode(), salt.encode(), PIN_ITERATIONS).hex()
    return f'pbkdf2${PIN_ITERATIONS}${salt}${digest}'


def verify_pin(stored, pin):
    if not isinstance(stored, str):
        return False
    if stored.startswith('pbkdf2$'):
        try:
            _, iterations, salt, digest = stored.split('$', 3)
            calculated = hashlib.pbkdf2_hmac('sha256', str(pin).encode(), salt.encode(), int(iterations)).hex()
        except (ValueError, TypeError):
            return False
        return hmac.compare_digest(calculated, digest)
    # Legacy format created by earlier builds: salt:sha256(salt:pin).
    if ':' in stored:
        salt, digest = stored.split(':', 1)
        calculated = hashlib.sha256(f'{salt}:{pin}'.encode()).hexdigest()
        return hmac.compare_digest(calculated, digest)
    return False


@app.on_event('startup')
def startup():
    with engine.begin() as c:
        c.execute(text(SCHEMA))
        # Seed canonical revision counters for databases imported or upgraded
        # from an older schema; existing counters are never reduced.
        for row in c.execute(text('select scope,revision from crm_snapshots')).mappings():
            canonical = revision_scope(str(row['scope']))
            c.execute(text('insert into crm_revisions(scope,revision) values (:scope,:revision) on conflict(scope) do update set revision=greatest(crm_revisions.revision,:revision)'), {'scope': canonical, 'revision': int(row['revision'] or 0)})
        if not c.execute(text('select 1 from crm_users limit 1')).first():
            pin = os.environ.get('CRM_OWNER_PIN', '')
            if not re.fullmatch(r'\d{4}', pin):
                raise RuntimeError('CRM_OWNER_PIN must be set to exactly 4 digits')
            permissions = {area: 'edit' for area in SCOPE_AREA.values()}
            permissions.update({'settings': 'edit', 'backup': 'edit'})
            c.execute(text("insert into crm_users(id,name,role,pin_hash,permissions) values ('owner',:name,'Владелец',:hash,:permissions)"), {'name': os.getenv('CRM_OWNER_NAME', 'Владелец'), 'hash': hash_pin(pin), 'permissions': json.dumps(permissions)})


def user_row(c, uid):
    return c.execute(text('select id,name,role,active,permissions from crm_users where id=:id'), {'id': uid}).mappings().first()


def public(u):
    return {'id': u['id'], 'name': u['name'], 'role': u['role'], 'active': u['active'], 'permissions': u['permissions']}


def all_users(c):
    return [public(x) for x in c.execute(text('select id,name,role,active,permissions from crm_users order by name')).mappings()]


def permissions_of(user):
    value = user['permissions'] if user else {}
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except ValueError:
            value = {}
    return value if isinstance(value, dict) else {}


def default_permissions(role):
    if role in ('Владелец', 'Администратор'):
        return {area: 'edit' for area in PERMISSION_AREAS}
    if role == 'Мастер':
        return {**{area: 'hidden' for area in PERMISSION_AREAS}, 'calendar': 'view'}
    if role == 'Бухгалтер':
        return {**{area: 'hidden' for area in PERMISSION_AREAS},
                'dashboard': 'view', 'finance': 'edit'}
    return {area: 'hidden' for area in PERMISSION_AREAS}


def effective_permissions(user):
    """Role defaults, overridden by the explicitly stored per-area levels."""
    base = default_permissions(user['role'] if user else '')
    stored = permissions_of(user)
    for area in PERMISSION_AREAS:
        if stored.get(area) in RANK:
            base[area] = stored[area]
    return base


def permission_rank(user, area):
    """Server-side area check, matching the client's role/permission policy."""
    return RANK.get(effective_permissions(user).get(area, 'hidden'), 0)


def can_view(user, scope):
    return permission_rank(user, SCOPE_AREA[scope]) >= 1


def revision_scope(scope):
    return 'workspace' if scope in ('dashboardNotes', 'revenuePlans') else scope


def merge_items(existing, incoming):
    """Merge record lists by id for parallel edits from several devices."""
    if not isinstance(existing, dict):
        return incoming
    items = existing.get('items')
    by_id = {}
    if isinstance(items, list):
        for item in items:
            if isinstance(item, dict) and item.get('id'):
                by_id[str(item['id'])] = item
    incoming_items = incoming.get('items')
    if isinstance(incoming_items, list):
        for item in incoming_items:
            if not isinstance(item, dict) or not item.get('id'):
                continue
            key = str(item['id'])
            current = by_id.get(key)
            if current is None or int(item.get('updatedAt') or 0) >= int(current.get('updatedAt') or 0):
                by_id[key] = item
    deleted = incoming.get('deletedIds')
    if isinstance(deleted, list):
        for value in deleted:
            by_id.pop(str(value), None)
    merged = dict(incoming)
    merged['items'] = list(by_id.values())
    return merged


def change_scope(change):
    if not isinstance(change, dict):
        return None
    cid = change.get('id')
    if not isinstance(cid, str) or not cid.strip() or len(cid) > 128:
        return None
    payload = change.get('payload')
    if not isinstance(payload, dict):
        return None
    if type(payload.get('schemaVersion')) is not int or payload['schemaVersion'] != 3:
        return None
    if payload.get('kind') != 'snapshot':
        return None
    scope = payload.get('scope')
    return scope if scope in SUPPORTED_SCOPES else None


def validate_changes_request(req, user):
    """Validate the whole batch before writing anything.

    A partially authorised or malformed batch is rejected entirely, mirroring
    the Apps Script backend and preventing unexpected partial application.
    """
    if type(req.get('schemaVersion')) is not int or req['schemaVersion'] != 3:
        return 'Unsupported schemaVersion'
    changes = req.get('changes')
    if not isinstance(changes, list) or len(changes) > MAX_CHANGES_PER_REQUEST:
        return 'Unsupported payload'
    for change in changes:
        scope = change_scope(change)
        if scope is None:
            return 'Unsupported payload'
        if permission_rank(user, SCOPE_AREA[scope]) < 2:
            return 'Недостаточно прав для раздела'
    return None


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'))


def ensure_revision_row(c, scope):
    c.execute(text('insert into crm_revisions(scope,revision) values (:scope,0) on conflict (scope) do nothing'), {'scope': scope})


def current_revision(c, scope):
    ensure_revision_row(c, scope)
    value = c.execute(text('select revision from crm_revisions where scope=:scope for update'), {'scope': scope}).scalar()
    return int(value or 0)


def read_revisions(c):
    revisions = {}
    for row in c.execute(text('select scope,revision from crm_revisions')).mappings():
        revisions[str(row['scope'])] = int(row['revision'] or 0)
    for row in c.execute(text('select scope,revision from crm_snapshots')).mappings():
        scope = revision_scope(str(row['scope']))
        revisions[scope] = max(revisions.get(scope, 0), int(row['revision'] or 0))
    return revisions


def _snapshot(values, scope, user):
    """Return a validated snapshot only when the user may read the area."""
    if scope not in values or not can_view(user, scope):
        return None
    payload = values[scope]
    if not isinstance(payload, dict):
        raise ValueError(f'Invalid {scope} snapshot')
    version = payload.get('schemaVersion')
    if type(version) is not int or version != 3:
        raise ValueError(f'Invalid {scope} snapshot')
    if payload.get('kind') != 'snapshot' or payload.get('scope') != scope:
        raise ValueError(f'Invalid {scope} snapshot')
    return payload


def _objects(payload, key, scope):
    value = payload.get(key)
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise ValueError(f'Invalid {scope}.{key}')
    return [dict(item) for item in value]


def _strings(payload, key, scope):
    value = payload.get(key)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f'Invalid {scope}.{key}')
    return list(value)


def project_workspace(values, user):
    """Build the client workspace shape from the scopes present on the server.

    Missing scopes add no keys, so a new or partially migrated server cannot
    silently replace locally stored data with empty lists. Malformed snapshots
    abort the whole read instead of being treated as empty data.
    """
    workspace = {}
    clients = _snapshot(values, 'clients', user)
    if clients is not None:
        workspace['clients'] = _objects(clients, 'data', 'clients')
    stock = _snapshot(values, 'stock', user)
    if stock is not None:
        workspace['stockItems'] = _objects(stock, 'items', 'stock')
        workspace['stockMovements'] = _objects(stock, 'movements', 'stock')
    products = _snapshot(values, 'products', user)
    if products is not None:
        workspace['products'] = _objects(products, 'items', 'products')
    deliveries = _snapshot(values, 'deliveries', user)
    if deliveries is not None:
        workspace['deliveries'] = _objects(deliveries, 'items', 'deliveries')
    orders = _snapshot(values, 'orders', user)
    if orders is not None:
        workspace['orders'] = _objects(orders, 'items', 'orders')
    deals = _snapshot(values, 'manualDeals', user)
    if deals is not None:
        rows = deals.get('rows')
        if not isinstance(rows, list) or not all(isinstance(row, list) for row in rows):
            raise ValueError('Invalid manualDeals.rows')
        workspace['manualDeals'] = [list(row) for row in rows]
        headers = deals.get('headers', [])
        if not isinstance(headers, list):
            raise ValueError('Invalid manualDeals.headers')
        workspace['manualDealHeaders'] = list(headers)
    finance = _snapshot(values, 'finance', user)
    if finance is not None:
        workspace['transactions'] = _objects(finance, 'transactions', 'finance')
        workspace['closedPeriods'] = _objects(finance, 'closedPeriods', 'finance')
        categories = finance.get('categories', [])
        if not isinstance(categories, list) or not all(isinstance(item, str) for item in categories):
            raise ValueError('Invalid finance.categories')
        workspace['financeSettings'] = {'categories': list(categories)}
    appointments = _snapshot(values, 'appointments', user)
    if appointments is not None:
        workspace['appointments'] = _objects(appointments, 'events', 'appointments')
    catalog = _snapshot(values, 'serviceCatalog', user)
    if catalog is not None:
        workspace['serviceCatalog'] = _objects(catalog, 'items', 'serviceCatalog')
    notes = _snapshot(values, 'dashboardNotes', user)
    plans = _snapshot(values, 'revenuePlans', user)
    workspace_scope = _snapshot(values, 'workspace', user)
    if notes is not None:
        workspace['notes'] = _objects(notes, 'notes', 'dashboardNotes')
    elif workspace_scope is not None and isinstance(workspace_scope.get('notes'), list):
        workspace['notes'] = _objects(workspace_scope, 'notes', 'workspace')
    if plans is not None:
        workspace['revenuePlans'] = _objects(plans, 'revenuePlans', 'revenuePlans')
    elif workspace_scope is not None and isinstance(workspace_scope.get('revenuePlans'), list):
        workspace['revenuePlans'] = _objects(workspace_scope, 'revenuePlans', 'workspace')
    if workspace_scope is not None:
        settings = workspace_scope.get('settings')
        if not isinstance(settings, dict):
            raise ValueError('Invalid workspace.settings')
        workspace['workspaceSettings'] = dict(settings)
    messages = _snapshot(values, 'messages', user)
    if messages is not None:
        workspace['messageSettings'] = {
            'quickReplyTemplates': _strings(messages, 'quickReplyTemplates', 'messages'),
            'assignees': dict(messages.get('assignees') if isinstance(messages.get('assignees'), dict) else {}),
            'tags': dict(messages.get('tags') if isinstance(messages.get('tags'), dict) else {}),
            'pendingMessages': _objects(messages, 'pendingMessages', 'messages'),
            'vkAppointmentMessageIds': dict(messages.get('vkAppointmentMessageIds') if isinstance(messages.get('vkAppointmentMessageIds'), dict) else {}),
            'vkSummaryMessageId': messages.get('vkSummaryMessageId'),
        }
    knowledge = project_knowledge(values, user)
    if knowledge:
        workspace.update(knowledge)
    audit = _snapshot(values, 'auditOnly', user)
    if audit is not None:
        workspace['audit'] = _objects(audit, 'entries', 'auditOnly')
    return workspace


def project_knowledge(values, user):
    """Convert the knowledgeBase snapshot to the client's list shape.

    A missing scope adds no keys; a malformed snapshot is rejected as a whole
    instead of being silently turned into empty data.
    """
    if 'knowledgeBase' not in values or not can_view(user, 'knowledgeBase'):
        return {}
    payload = values['knowledgeBase']
    if not isinstance(payload, dict):
        raise ValueError('Invalid knowledge snapshot')
    version = payload.get('schemaVersion')
    if type(version) is not int or version != 3:
        raise ValueError('Invalid knowledge snapshot')
    if payload.get('kind') != 'snapshot' or payload.get('scope') != 'knowledgeBase':
        raise ValueError('Invalid knowledge snapshot')
    content = payload.get('content')
    versions = payload.get('versions')
    if not isinstance(content, str):
        raise ValueError('Invalid knowledge snapshot')
    if not isinstance(versions, list) or not all(isinstance(item, dict) for item in versions):
        raise ValueError('Invalid knowledge snapshot')
    return {
        'knowledge': [{'id': 'knowledge-base', 'content': content}],
        'knowledgeVersions': [dict(item) for item in versions],
    }


AVITO_CATEGORY_MAP = {
    'Бытовая техника': 'Бытовая техника',
    'Одежда': 'Одежда, обувь, аксессуары',
    'Одежда, обувь, аксессуары': 'Одежда, обувь, аксессуары',
    'Детская одежда': 'Детская одежда и обувь',
    'Детская одежда и обувь': 'Детская одежда и обувь',
    'Автотовары': 'Запчасти и аксессуары',
    'Автотовары и аксессуары': 'Запчасти и аксессуары',
    'Автоаксессуары': 'Запчасти и аксессуары',
    'Аксессуары для авто': 'Запчасти и аксессуары',
    'Запчасти': 'Запчасти и аксессуары',
    'Запчасти и аксессуары': 'Запчасти и аксессуары',
    'Запчасти для авто': 'Запчасти и аксессуары',
    'Товары для дома': 'Для дома и дачи',
    'Ремонт и строительство': 'Ремонт и строительство',
    'Мебель и интерьер': 'Мебель и интерьер',
    'Кемпинг': 'Спорт и отдых',
    'Спорт': 'Спорт и отдых',
    'Спорт и отдых': 'Спорт и отдых',
    'Товары для компьютера': 'Товары для компьютера',
    'Телефоны': 'Телефоны',
    'Игры, приставки и программы': 'Игры, приставки и программы',
    'Посуда и товары для кухни': 'Посуда и товары для кухни',
    'Красота и здоровье': 'Красота и здоровье',
    'Продукты питания': 'Продукты питания',
    'Охота и рыбалка': 'Охота и рыбалка',
    'Фототехника': 'Фототехника',
    'Электроника': 'Электроника',
    'Автоэлектроника': 'Электроника',
    'Другое': 'Другие категории',
}

# Статусы товара CRM, которые публикуются как активные объявления.
FEED_SELLABLE_STATUSES = {'in_stock', 'ready'}


def _feed_category(category: str, name: str) -> str | None:
    return AVITO_CATEGORY_MAP.get(category.strip())


def _feed_price(item: dict) -> int:
    override = item.get('myPriceOverride')
    if isinstance(override, (int, float)) and override > 0:
        return int(round(override))
    price = item.get('marketplacePrice') or 0
    discount = item.get('discountPercent') or 0
    try:
        return int(round(float(price) * (1 - float(discount) / 100)))
    except Exception:
        return 0


def _clip_value(value: str, limit: int) -> str:
    """Обрезает строку, не разрывая суррогатную пару (эмодзи).

    Avito ограничивает <Title> 50 символами; простая обрезка по индексу могла
    бы разрезать эмодзи и сделать XML невалидным.
    """
    if len(value) <= limit:
        return value
    clipped = value[:limit]
    last = clipped[-1]
    if 0xD800 <= ord(last) <= 0xDBFF:
        clipped = clipped[:-1]
    return clipped


def feed_entries(items, domain: str) -> list[dict]:
    """Возвращает записи фида автозагрузки Авито из снимка товаров.

    В фид попадают товары со SKU, названием, известной категорией,
    положительной ценой и хотя бы одним фото, со статусом «в наличии» или
    «готов к продаже». Дубли SKU пропускаются, порядок стабильный (по SKU).
    Возвращает [{sku, category, title, description, price, urls}].
    """
    used_ids = set()
    entries = []
    sellable = sorted(
        (item for item in items or [] if isinstance(item, dict)),
        key=lambda item: str(item.get('sku') or ''),
    )
    for item in sellable:
        sku = str(item.get('sku') or '').strip()
        name = str(item.get('name') or '').strip()
        if not sku or not name or sku in used_ids:
            continue
        status = str(item.get('status') or '').strip()
        sold = item.get('sold') is True or (
            bool(status) and status not in FEED_SELLABLE_STATUSES
        )
        category = _feed_category(str(item.get('category') or ''), name)
        if category is None:
            continue
        price = _feed_price(item)
        if price <= 0:
            continue
        photos = [str(x) for x in (item.get('photos') or []) if str(x).strip()]
        urls = []
        for photo in photos:
            if photo.startswith('http'):
                urls.append(photo)
            elif domain:
                urls.append(f'https://{domain}{photo}')
        if not urls:
            continue
        size = str(item.get('size') or '').strip()
        base = str(item.get('description') or '').strip()
        if base:
            description = base + ('' if base.endswith(sku) else f'\n\nАртикул: {sku}')
        else:
            description = f'Артикул: {sku}.' + (f' {size}' if size else '')
        used_ids.add(sku)
        entries.append({
            'sku': sku,
            'category': category,
            'title': _clip_value(name, 50),
            'description': description,
            'price': price,
            'urls': urls[:10],
            'sold': sold,
            '_raw': item,
        })
    return entries


def _avito_normalize(value):
    return ' '.join(str(value or '').replace('\u00a0', ' ').casefold().split())


def _catalog_field_values(field):
    return [str(value['value']) for content in field.get('content', [])
            if isinstance(content, dict)
            for value in content.get('values', [])
            if isinstance(value, dict) and value.get('value') is not None]


def _select_feed_template(catalog, item):
    """Resolve the template using explicit category and saved attribute values.

    A tie is not guessed: unrelated listings often have the same name.
    """
    attrs = item.get('attributes') or {}
    if not isinstance(attrs, dict) or not catalog:
        return None
    fields_map = catalog.get('fields') or {}
    slug = str(attrs.get('avito_slug') or '').strip()
    if slug:
        node = fields_map.get(slug)
        if not isinstance(node, dict):
            return None
        allowed = {_avito_normalize(v) for f in node.get('fields', [])
                   if f.get('tag') == 'Category' for v in _catalog_field_values(f)}
        selected = _avito_normalize(_feed_category(str(item.get('category') or ''), ''))
        return node if not allowed or selected in allowed else None
    names = {_avito_normalize(v) for v in attrs.values() if isinstance(v, str)}
    category = _avito_normalize(_feed_category(str(item.get('category') or ''), ''))
    matches = []
    for node in fields_map.values():
        if not isinstance(node, dict):
            continue
        if _avito_normalize((node.get('node') or {}).get('name')) not in names:
            continue
        fields = node.get('fields') or []
        category_values = {_avito_normalize(v) for f in fields
                           if f.get('tag') == 'Category'
                           for v in _catalog_field_values(f)}
        if not category_values or category not in category_values:
            continue
        score = 0
        for field in fields:
            val = attrs.get(field.get('label'))
            options = {_avito_normalize(v) for v in _catalog_field_values(field)}
            if val and len(options) == 1:
                if _avito_normalize(val) not in options:
                    break
                score += 1
        else:
            matches.append((score, node))
    if not matches:
        return None
    top = max(score for score, _ in matches)
    winners = [node for score, node in matches if score == top]
    return winners[0] if len(winners) == 1 else None


def _feed_params(catalog, item):
    """Render Avito XML fields from the matching category template."""
    attrs = item.get('attributes') or {}
    if not isinstance(attrs, dict):
        attrs = {}
    node = _select_feed_template(catalog, item)
    fields = (node or {}).get('fields') or []
    out = []
    emitted = {'Id', 'Category', 'Title', 'Description', 'Price', 'Images',
               'ImageUrls', 'ImageNames', 'AvitoId', 'ListingFee', 'AdStatus'}
    for field in fields:
        tag = str(field.get('tag') or '')
        if tag in emitted or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', tag):
            continue
        contents = field.get('content') or []
        if field.get('feed_format') and 'xml' not in field['feed_format']:
            continue
        value = str(attrs.get(field.get('label')) or '').strip()
        if tag == 'Address':
            value = 'Рязань, улица Лермонтова, 9/2'
        options = _catalog_field_values(field)
        normalized = {_avito_normalize(v): v for v in options}
        if value and normalized:
            # Checkbox fields can contain several values in the CRM.
            multi = any(c.get('field_type') == 'checkbox' for c in contents if isinstance(c, dict))
            if multi:
                parts = [normalized.get(_avito_normalize(v)) for v in value.split('|')]
                if all(parts) and len(parts) > 1:
                    out.append(f'<{tag}>' + ''.join(f'<Option>{escape(part)}</Option>' for part in parts) + f'</{tag}>')
                    emitted.add(tag)
                    continue
                value = parts[0] if parts and all(parts) else ''
            else:
                value = normalized.get(_avito_normalize(value), '')
        if not value and tag == 'AdType' and not attrs.get(field.get('label')):
            # Avito's validator applies this same default to missing AdType.
            value = normalized.get(_avito_normalize('Товар приобретен на продажу'), '')
        if not value and any(c.get('required') for c in contents if isinstance(c, dict)):
            if len(normalized) == 1:
                value = next(iter(normalized.values()))
        if value:
            out.append(f'<{tag}>{escape(value)}</{tag}>')
            emitted.add(tag)
    if 'Address' not in emitted and attrs.get('Адрес'):
        address = 'Рязань, улица Лермонтова, 9/2'
        out.append(f'<Address>{escape(address)}</Address>')
    avito_id = str(item.get('avitoItemId') or '').strip()
    if avito_id.isdigit():
        out.append(f'<AvitoId>{avito_id}</AvitoId>')
    return out


def build_avito_feed(items, domain: str, catalog=None) -> str:
    """Собирает XML фида автозагрузки Авито из снимка товаров.

    catalog (опционально) — справочник полей категорий Авито.
    """
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<Ads formatVersion="3" target="Avito.ru">',
    ]
    entries = feed_entries(items, domain)
    for entry in entries:
        parts.append('<Ad>')
        parts.append(f'<Id>{escape(entry["sku"])}</Id>')
        parts.append(f'<Category>{escape(entry["category"])}</Category>')
        parts.append(f'<Title>{escape(entry["title"])}</Title>')
        parts.append(f'<Description>{escape(entry["description"])}</Description>')
        parts.append(f'<Price>{entry["price"]}</Price>')
        if entry.get('sold'):
            # Авито снимает объявление, если DateEnd уже прошла.
            parts.append('<DateEnd>2000-01-01</DateEnd>')
        parts.append('<ListingFee>Single</ListingFee>')
        parts.append('<Images>')
        for url in entry['urls']:
            parts.append(f'<Image url={quoteattr(url)}/>')
        parts.append('</Images>')
        params = _feed_params(catalog, entry.get('_raw') or {})
        if params:
            parts.extend(params)
        parts.append('</Ad>')
    parts.append('</Ads>')
    return '\n'.join(parts)


@app.get('/avito/feed.xml')
def avito_feed():
    """Public Avito autoload feed generated from the latest products snapshot."""
    with engine.begin() as c:
        payload = c.execute(
            text("select payload from crm_snapshots where scope='products'")
        ).scalar()
    if not isinstance(payload, dict) or not isinstance(payload.get('items'), list):
        raise HTTPException(status_code=503, detail='Products snapshot is unavailable')
    items = payload.get('items') if isinstance(payload, dict) else []
    domain = (os.environ.get('CRM_DOMAIN') or '168.113.189.186.nip.io').strip()
    # Old product cards store category values but not the template slug.
    # Find candidate templates by their exact names in saved attributes.
    names, slugs = set(), set()
    for item in items or []:
        if not isinstance(item, dict):
            continue
        attrs = item.get('attributes') or {}
        if not isinstance(attrs, dict):
            continue
        for value in attrs.values():
            if isinstance(value, str) and value.strip():
                names.add(value.strip())
                names.add(value.replace('\u00a0', ' ').strip())
        slug = str(attrs.get('avito_slug') or '').strip()
        if slug:
            slugs.add(slug)
    fields_map = {}
    if names or slugs:
        with engine.connect() as c:
            result = c.execute(text(
                'select slug, fields from crm_avito_catalog '
                'where name = ANY(:names) or slug = ANY(:slugs)'
            ), {'names': list(names), 'slugs': list(slugs)})
            for row in result.mappings():
                if isinstance(row['fields'], dict):
                    fields_map[row['slug']] = row['fields']
    catalog = {'fields': fields_map} if fields_map else None
    if any(_select_feed_template(catalog, entry['_raw']) is None
           for entry in feed_entries(items, domain)):
        raise HTTPException(status_code=503, detail='Avito category parameters are unavailable')
    return Response(
        content=build_avito_feed(items, domain, catalog=catalog),
        media_type='application/xml',
    )


THUMB_DIR = '/data/media/thumbs'


@app.get('/media-thumb/{name}')
def media_thumb(name: str):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
        raise HTTPException(status_code=404)
    source = f'/data/media/{name}'
    if not os.path.exists(source):
        raise HTTPException(status_code=404)
    os.makedirs(THUMB_DIR, exist_ok=True)
    target = f'{THUMB_DIR}/{name}'
    if not os.path.exists(target):
        try:
            image = Image.open(source).convert('RGB')
            image.thumbnail((300, 300))
            image.save(target, 'JPEG', quality=45, optimize=True)
        except Exception:
            raise HTTPException(status_code=404)
    return FileResponse(target, media_type='image/jpeg')





def _redact_error(value):
    text = str(value)
    # Никогда не возвращаем клиенту сырые токены/пароли из исключений.
    return re.sub(r'(Bearer\s+)?[A-Za-z0-9_\-.]{32,}', '[redacted]', text)


AVITO_CATALOG_TREE_URL = 'https://api.avito.ru/autoload/v1/user-docs/tree'
AVITO_CATALOG_FIELDS_URL = 'https://api.avito.ru/autoload/v1/user-docs/node/{slug}/fields'
AVITO_TOKEN_URL = 'https://api.avito.ru/token'

AVITO_CATALOG_KEY = 'avito_catalog'


def _avito_api_token(client_id, client_secret):
    data = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
    }).encode()
    request = urllib.request.Request(
        AVITO_TOKEN_URL,
        data=data,
        headers={'content-type': 'application/x-www-form-urlencoded'},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = json.loads(response.read().decode('utf-8'))
    token = body.get('access_token')
    if not token:
        raise ValueError('Авито не выдал access_token')
    return str(token)


def _avito_api_get_json(url, token, attempts=3):
    """GET к api.avito.ru с повтором при лимитах (429) и сбоях 5xx."""
    last_error = None
    for attempt in range(attempts):
        request = urllib.request.Request(
            url,
            headers={'authorization': f'Bearer {token}'},
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code in (429, 500, 502, 503) and attempt < attempts - 1:
                time.sleep(1.5 * (attempt + 1))
                continue
            raise
        except Exception as error:
            last_error = error
            if attempt < attempts - 1:
                time.sleep(1.0 * (attempt + 1))
                continue
            raise
    raise last_error if last_error else ValueError('Запрос к Авито не выполнен')


_catalog_progress = {
    'stage': 'idle', 'total': 0, 'done': 0, 'current': '',
    'errors': 0, 'categories': 0, 'startedAt': 0, 'finishedAt': 0,
    'message': '',
}
_catalog_progress_lock = threading.Lock()
_catalog_log_lock = threading.Lock()
_catalog_value_budget = {'left': 900}


def _progress_update(**changes):
    with _catalog_progress_lock:
        _catalog_progress.update(changes)


def _progress_snapshot():
    with _catalog_progress_lock:
        return dict(_catalog_progress)


def _catalog_log(line):
    """Пишет строку в /data/avito/catalog-sync.log (для диагностики)."""
    try:
        path = os.path.join(os.getenv('AVITO_DATA_DIR', '/data/avito'),
                            'catalog-sync.log')
        os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
        with _catalog_log_lock, open(path, 'a', encoding='utf-8') as target:
            target.write(f'{time.strftime("%Y-%m-%d %H:%M:%S")} {line}\n')
    except Exception:
        pass


def _walk_categories(value, out, seen):
    """Собирает категории из ответа API независимо от структуры вложенности.

    API может отдавать nested как массив групп, как объект групп или как
    список узлов; поэтому просто рекурсивно обходим весь JSON и берём любые
    объекты со slug и name.
    """
    if isinstance(value, dict):
        slug = str(value.get('slug') or '').strip()
        name = str(value.get('name') or '').strip()
        if slug and slug not in seen:
            seen.add(slug)
            out.append((slug, name))
        for item in value.values():
            _walk_categories(item, out, seen)
    elif isinstance(value, list):
        for item in value:
            _walk_categories(item, out, seen)


def _child_nodes(node):
    """Совместимость: возвращает дочерние узлы (используется в тестах)."""
    nested = node.get('nested')
    children = []
    if isinstance(nested, list):
        for group in nested:
            if isinstance(group, dict):
                for values in group.values():
                    if isinstance(values, list):
                        children.extend(v for v in values if isinstance(v, dict))
            elif isinstance(group, list):
                children.extend(v for v in group if isinstance(v, dict))
    elif isinstance(nested, dict):
        for values in nested.values():
            if isinstance(values, list):
                children.extend(v for v in values if isinstance(v, dict))
    return children


def _collect_category_slugs(node, out):
    """Рекурсивно собирает категории узла (совместимость с тестами)."""
    seen = set()
    _walk_categories(node, out, seen)


def _load_avito_catalog(connection):
    """Возвращает метаданные справочника (список категорий) или None.

    Сами поля категорий лежат построчно в crm_avito_catalog: один большой
    JSON на слабом сервере не помещался в память.
    """
    row = connection.execute(text(
        'select payload from crm_configuration where id=1'
    )).scalar()
    payload = row if isinstance(row, dict) else (json.loads(row) if row else None)
    if not isinstance(payload, dict):
        return None
    catalog = payload.get(AVITO_CATALOG_KEY)
    return catalog if isinstance(catalog, dict) else None


def sync_avito_tree(client_id, client_secret):
    """Быстро обновляет только дерево категорий (1 запрос к API).

    Нужно форме товара: пользователь выбирает категорию/подкатегорию по
    дереву, а поля категорий уже лежат в кэше.
    """
    if not isinstance(client_id, str) or not client_id.strip():
        return None, {'error': 'Не указан client_id Авито'}
    if not isinstance(client_secret, str) or not client_secret.strip():
        return None, {'error': 'Не указан client_secret Авито'}
    try:
        _catalog_log('запрос дерева категорий')
        token = _avito_api_token(client_id.strip(), client_secret.strip())
        tree = _avito_api_get_json(AVITO_CATALOG_TREE_URL, token)
        slugs, seen = [], set()
        _walk_categories(tree, slugs, seen)
        with engine.connect() as c:
            meta = dict(_load_avito_catalog(c) or {})
        meta['tree'] = tree
        meta['treeUpdatedAt'] = int(time.time() * 1000)
        if not meta.get('categories'):
            meta['categories'] = slugs
        _save_catalog_meta(meta)
        _catalog_log(f'дерево обновлено: {len(slugs)} категорий')
        return meta, None
    except Exception as error:
        return None, {'error': f'Не удалось обновить дерево: {_redact_error(error)}'}


def _node_children(node):
    """Дочерние узлы дерева (поддерживает оба формата nested)."""
    nested = node.get('nested') if isinstance(node, dict) else None
    out = []
    if isinstance(nested, list):
        for item in nested:
            if isinstance(item, dict) and ('name' in item or 'slug' in item):
                out.append(item)
            elif isinstance(item, dict):
                for value in item.values():
                    if isinstance(value, list):
                        out.extend(v for v in value if isinstance(v, dict))
            elif isinstance(item, list):
                out.extend(v for v in item if isinstance(v, dict))
    elif isinstance(nested, dict):
        for value in nested.values():
            if isinstance(value, list):
                out.extend(v for v in value if isinstance(v, dict))
    return out


def _find_node(nodes, slug):
    for node in nodes or []:
        if not isinstance(node, dict):
            continue
        if str(node.get('slug') or '') == slug:
            return node
        found = _find_node(_node_children(node), slug)
        if found is not None:
            return found
    return None


def _catalog_children(connection, parent_slug):
    """Дети узла (или корневые категории) — небольшой ответ для клиента."""
    meta = _load_avito_catalog(connection) or {}
    nodes = ((meta.get('tree') or {}).get('categories') or [])
    if parent_slug:
        node = _find_node(nodes, parent_slug)
        nodes = _node_children(node) if node else []
    out = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        children = _node_children(node)
        out.append({
            'name': str(node.get('name') or ''),
            'slug': str(node.get('slug') or ''),
            'hasChildren': bool(children),
            'hasFields': False,
        })
    return out


def _catalog_search(connection, query, limit=40):
    meta = _load_avito_catalog(connection) or {}
    text = query.strip().lower()
    out = []
    for slug, name in (meta.get('categories') or []):
        if text and text not in str(name).lower():
            continue
        out.append({'name': str(name), 'slug': str(slug)})
        if len(out) >= limit:
            break
    return out


def _catalog_fields(connection, slug):
    """Поля одной категории из кэша (None, если нет)."""
    row = connection.execute(
        text('select fields from crm_avito_catalog where slug=:slug'),
        {'slug': slug},
    ).scalar()
    if row is None:
        return None
    return row if isinstance(row, dict) else json.loads(row)


def _catalog_fields_many(connection, slugs):
    """Поля нескольких категорий: {slug: node}."""
    out = {}
    for slug in {str(item) for item in slugs if str(item).strip()}:
        node = _catalog_fields(connection, slug)
        if isinstance(node, dict):
            out[slug] = node
    return out


def _flush_catalog_rows(buffer):
    """Пишет пачку категорий в БД одной транзакцией (без гигантского JSON)."""
    if not buffer:
        return
    with engine.begin() as c:
        for slug, name, node in buffer:
            c.execute(text(
                'insert into crm_avito_catalog(slug,name,fields,updated_at) '
                'values (:slug,:name,:fields,now()) '
                'on conflict(slug) do update set name=:name, fields=:fields, '
                'updated_at=now()'
            ), {'slug': slug, 'name': name,
                'fields': json.dumps(node, ensure_ascii=False)})
    buffer.clear()


def _save_catalog_meta(meta):
    with engine.begin() as c:
        current = c.execute(text(
            'select payload from crm_configuration where id=1')).scalar()
        payload = current if isinstance(current, dict) else (
            json.loads(current) if current else {})
        payload[AVITO_CATALOG_KEY] = meta
        c.execute(text(
            'insert into crm_configuration(id,payload,updated_at) '
            'values (1,:payload,now()) '
            'on conflict(id) do update set payload=:payload, updated_at=now()'
        ), {'payload': json.dumps(payload, ensure_ascii=False)})


def _fetch_catalog_values(node, token, consumed=0):
    """Подгружает значения каталожных полей по values_link_json.

    Бюджет запросов ограничен (_catalog_value_budget), чтобы не упираться
    в лимиты API. Значения кладутся в content['values'].
    """
    if not isinstance(node, dict):
        return node
    fields = node.get('fields')
    if not isinstance(fields, list):
        return node
    for field in fields:
        if not isinstance(field, dict):
            continue
        contents = field.get('content')
        if not isinstance(contents, list):
            continue
        for content in contents:
            if not isinstance(content, dict):
                continue
            link = content.get('values_link_json')
            if not link or content.get('values'):
                continue
            with _catalog_progress_lock:
                if _catalog_value_budget['left'] <= 0:
                    continue
                _catalog_value_budget['left'] -= 1
            try:
                data = _avito_api_get_json(str(link), token)
                items = data.get('values') if isinstance(data, dict) else data
                if isinstance(items, list):
                    content['values'] = [
                        {'value': str(item.get('value') if isinstance(item, dict)
                                      else item)}
                        for item in items
                    ]
            except Exception:
                content.pop('values', None)
    return node


def _fetch_one_category(slug, token):
    """Загружает поля одной категории (и каталожные значения)."""
    node = _avito_api_get_json(AVITO_CATALOG_FIELDS_URL.format(slug=slug), token)
    time.sleep(0.05)
    return _fetch_catalog_values(node, token)


def sync_avito_catalog(client_id, client_secret, only_failed=False):
    """Обновляет справочник категорий Авито.

    Поля категорий пишутся построчно пачками (по 20), поэтому память и БД
    не получают один гигантский JSON. Прогресс отдаётся в _catalog_progress,
    лог — в /data/avito/catalog-sync.log.

    only_failed=True — повторная попытка только для категорий, которые не
    загрузились в прошлый раз (их список сохраняется в метаданных).
    """
    if not isinstance(client_id, str) or not client_id.strip():
        return None, {'error': 'Не указан client_id Авито'}
    if not isinstance(client_secret, str) or not client_secret.strip():
        return None, {'error': 'Не указан client_secret Авито'}
    _catalog_value_budget['left'] = 300
    started = int(time.time() * 1000)
    _progress_update(stage='token', total=0, done=0, current='', errors=0,
                     categories=0, startedAt=started, finishedAt=0,
                     message='Получаю токен Авито')
    _catalog_log(f'=== старт синхронизации (only_failed={only_failed}) ===')
    try:
        token = _avito_api_token(client_id.strip(), client_secret.strip())
        _progress_update(stage='tree', message='Загружаю дерево категорий')
        tree = _avito_api_get_json(AVITO_CATALOG_TREE_URL, token)
        slugs, seen = [], set()
        _walk_categories(tree, slugs, seen)
        _catalog_log(f'дерево: категорий {len(slugs)}; ключи: '
                     f'{list(tree.keys()) if isinstance(tree, dict) else type(tree).__name__}')
        try:
            _catalog_log('tree sample: ' +
                         json.dumps(tree, ensure_ascii=False)[:1200])
        except Exception:
            pass

        previous = None
        with engine.connect() as c:
            previous = _load_avito_catalog(c)
        previous_failed = []
        if only_failed and isinstance(previous, dict):
            previous_failed = [str(x) for x in (previous.get('failedSlugs') or [])]
        targets = [(slug, name) for slug, name in slugs
                   if (not only_failed or slug in set(previous_failed))]
        if only_failed and not targets:
            _progress_update(stage='done', finishedAt=int(time.time() * 1000),
                             message='Нечего повторять')
            return previous, None

        _progress_update(stage='fields', total=len(targets), done=0,
                         categories=len(slugs) if not only_failed else
                         len((previous or {}).get('categories') or []),
                         message='Загружаю поля категорий')
        buffer = []
        failed = []
        done = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {pool.submit(_fetch_one_category, slug, token): (slug, name)
                       for slug, name in targets}
            for future in concurrent.futures.as_completed(futures):
                slug, name = futures[future]
                done += 1
                try:
                    node = future.result()
                    if isinstance(node, dict) and node.get('fields'):
                        buffer.append((slug, name, node))
                    else:
                        failed.append(slug)
                except Exception as error:
                    failed.append(slug)
                    if len(failed) <= 20:
                        _catalog_log(f'ошибка {slug}: {_redact_error(error)}')
                if len(buffer) >= 20:
                    _flush_catalog_rows(buffer)
                _progress_update(done=done, current=slug, errors=len(failed))
        _flush_catalog_rows(buffer)

        if only_failed:
            # Дополняем предыдущие метаданные: список категорий не меняется.
            meta = dict(previous or {})
            meta.update({
                'updatedAt': int(time.time() * 1000),
                'failedSlugs': failed,
                'errorCount': len(failed),
            })
        else:
            # Удаляем категории, которых больше нет в дереве Авито.
            try:
                with engine.begin() as c:
                    c.execute(text(
                        'delete from crm_avito_catalog '
                        'where updated_at < to_timestamp(:ts)'), {'ts': started / 1000})
            except Exception as error:
                _catalog_log(f'очистка устаревших: {_redact_error(error)}')
            with engine.connect() as c:
                count = c.execute(text('select count(*) from crm_avito_catalog')).scalar()
            meta = {
                'updatedAt': int(time.time() * 1000),
                'categories': slugs,
                'tree': tree,
                'treeUpdatedAt': int(time.time() * 1000),
                'fieldsCount': int(count or 0),
                'failedSlugs': failed,
                'errorCount': len(failed),
                'startedAt': started,
            }
        _progress_update(stage='saving', message='Сохраняю справочник')
        _save_catalog_meta(meta)
        _catalog_log(f'готово: категорий {len(meta.get("categories") or [])}, '
                     f'полей {meta.get("fieldsCount")}, ошибок {len(failed)}')
        _progress_update(stage='done', current='', errors=len(failed),
                         finishedAt=int(time.time() * 1000), message='Готово')
        return meta, None
    except Exception as error:
        message = _redact_error(error)
        _catalog_log(f'сбой: {message}')
        _progress_update(stage='error', finishedAt=int(time.time() * 1000),
                         message=message)
        return None, {'error': f'Не удалось обновить каталог Авито: {message}'}


@app.get('/')
def health():
    """Readiness probe: report healthy only when PostgreSQL is reachable."""
    try:
        with engine.begin() as c:
            c.execute(text('select 1'))
    except Exception:
        raise HTTPException(status_code=503, detail='database unavailable')
    return {'ok': True, 'schemaVersion': 3}


def _authed_user(req):
    """Короткая проверка сессионного токена без удержания транзакции.

    Длинные операции (браузер Playwright) не должны держать соединение с БД
    открытым: проверяем сессию отдельным подключением и возвращаем user.
    """
    token = req.get('sessionToken')
    if not token:
        return None, {'error': 'Сессия отозвана. Войдите снова.', 'errorCode': 'AUTH_REQUIRED'}
    with engine.connect() as c:
        uid = c.execute(text(f"select user_id from crm_sessions where token=:t and created_at > now() - interval '{SESSION_DAYS} days'"), {'t': token}).scalar()
        if not uid:
            return None, {'error': 'Сессия отозвана. Войдите снова.', 'errorCode': 'AUTH_REQUIRED'}
        user = user_row(c, uid)
    if not user or not user['active']:
        return None, {'error': 'Учётная запись отключена.', 'errorCode': 'AUTH_REQUIRED'}
    return user, None


@app.post('/')
def api(req: dict[str, Any]):
    op = req.get('operation', 'pushChanges')
    # Операции с браузером выполняются вне транзакции: они могут занимать
    # десятки секунд, и держать при этом соединение с БД нельзя.
    if op == 'avitoFeedSkus':
        # Список SKU, которые реально попадут в фид автозагрузки. Клиент
        # показывает по нему значок «на Авито» у товаров в разделе «Товары».
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if permission_rank(user, 'stock') < 1:
            return {'error': 'Недостаточно прав для раздела'}
        with engine.connect() as c:
            payload = c.execute(
                text("select payload from crm_snapshots where scope='products'")
            ).scalar()
        items = payload.get('items') if isinstance(payload, dict) else []
        domain = (os.environ.get('CRM_DOMAIN') or '168.113.189.186.nip.io').strip()
        skus = [entry['sku'] for entry in feed_entries(items, domain)]
        return {'ok': True, 'skus': skus}
    if op == 'avitoCatalogSync':
        # Полное обновление справочника категорий Авито (владелец). Ключи
        # приходят в запросе и не сохраняются на сервере.
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if user['role'] not in ('Владелец', 'Администратор'):
            return {'error': 'Недостаточно прав'}
        catalog, problem = sync_avito_catalog(
            req.get('clientId'), req.get('clientSecret'),
            only_failed=req.get('onlyFailed') is True)
        if problem is not None:
            return problem
        return {
            'ok': True,
            'categories': len(catalog.get('categories') or []),
            'fields': int(catalog.get('fieldsCount') or 0),
            'updatedAt': catalog.get('updatedAt'),
            'errorCount': int(catalog.get('errorCount') or 0),
            'failedSlugs': (catalog.get('failedSlugs') or [])[:20],
        }
    if op == 'avitoCatalogTree':
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if user['role'] not in ('Владелец', 'Администратор'):
            return {'error': 'Недостаточно прав'}
        meta, problem = sync_avito_tree(
            req.get('clientId'), req.get('clientSecret'))
        if problem is not None:
            return problem
        return {'ok': True,
                'categories': len(meta.get('categories') or []),
                'updatedAt': meta.get('treeUpdatedAt')}
    if op == 'avitoCatalogChildren':
        # Маленький ответ: дети категории (или корень) для пошагового выбора.
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if permission_rank(user, 'stock') < 1:
            return {'error': 'Недостаточно прав для раздела'}
        with engine.connect() as c:
            children = _catalog_children(c, str(req.get('parent') or '').strip())
            for item in children:
                item['hasFields'] = _catalog_fields(c, item['slug']) is not None
        return {'ok': True, 'items': children}
    if op == 'avitoCatalogSearch':
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if permission_rank(user, 'stock') < 1:
            return {'error': 'Недостаточно прав для раздела'}
        with engine.connect() as c:
            items = _catalog_search(c, str(req.get('query') or ''))
        return {'ok': True, 'items': items}
    if op == 'avitoCatalogProgress':
        # Ход загрузки справочника: клиент опрашивает, пока идёт синк.
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if user['role'] not in ('Владелец', 'Администратор'):
            return {'error': 'Недостаточно прав'}
        snapshot = _progress_snapshot()
        return {'ok': True, **snapshot}
    if op == 'avitoCatalog':
        # Чтение кэшированного справочника (всем пользователям со складом).
        user, auth_error = _authed_user(req)
        if auth_error:
            return auth_error
        if permission_rank(user, 'stock') < 1:
            return {'error': 'Недостаточно прав для раздела'}
        slug = str(req.get('slug') or '').strip()
        with engine.connect() as c:
            catalog = _load_avito_catalog(c)
            if catalog is None:
                return {'ok': False, 'error': 'Каталог Авито ещё не загружен',
                        'errorCode': 'AVITO_CATALOG_NOT_READY'}
            if slug:
                fields = _catalog_fields(c, slug)
                names = dict((str(a), str(b)) for a, b in
                             (catalog.get('categories') or []))
                if fields is None:
                    return {'ok': False, 'error': 'Поля категории не загружены',
                            'errorCode': 'AVITO_CATEGORY_NOT_FOUND'}
                return {'ok': True, 'name': names.get(slug, slug),
                        'fields': fields}
        return {'ok': True, 'categories': catalog.get('categories') or [],
                'updatedAt': catalog.get('updatedAt'),
                'tree': catalog.get('tree'),
                'fieldsCount': int(catalog.get('fieldsCount') or 0),
                'errorCount': int(catalog.get('errorCount') or 0)}
    with engine.begin() as c:
        if op == 'listUsers':
            return {'users': [public(x) for x in c.execute(text('select id,name,role,active,permissions from crm_users where active')).mappings()]}
        if op == 'login':
            u = user_row(c, req.get('userId'))
            if not u or not u['active']:
                return {'error': 'Пользователь не найден'}
            locked = c.execute(text('select 1 from crm_login_failures where user_id=:id and locked_until is not null and locked_until > now()'), {'id': u['id']}).scalar()
            if locked:
                return {'error': f'Слишком много попыток. Повторите через {LOCKOUT_MINUTES} минут.', 'errorCode': 'PIN_LOCKED'}
            stored = c.execute(text('select pin_hash from crm_users where id=:id'), {'id': u['id']}).scalar()
            if not verify_pin(stored, req.get('pin')):
                c.execute(text('insert into crm_login_failures(user_id,attempts) values (:id,1) on conflict(user_id) do update set attempts=crm_login_failures.attempts+1'), {'id': u['id']})
                attempts = c.execute(text('select attempts from crm_login_failures where user_id=:id'), {'id': u['id']}).scalar() or 0
                if attempts >= MAX_LOGIN_ATTEMPTS:
                    c.execute(text(f"update crm_login_failures set attempts=0, locked_until=now() + interval '{LOCKOUT_MINUTES} minutes' where user_id=:id"), {'id': u['id']})
                    return {'error': f'Слишком много попыток. Вход заблокирован на {LOCKOUT_MINUTES} минут.', 'errorCode': 'PIN_LOCKED'}
                return {'error': 'Неверный PIN'}
            c.execute(text('delete from crm_login_failures where user_id=:id'), {'id': u['id']})
            token = secrets.token_urlsafe(32)
            c.execute(text('insert into crm_sessions(token,user_id) values (:t,:u)'), {'t': token, 'u': u['id']})
            return {'user': public(u), 'sessionToken': token, 'configuration': {'schemaVersion': 3}}
        token = req.get('sessionToken')
        uid = c.execute(text(f"select user_id from crm_sessions where token=:t and created_at > now() - interval '{SESSION_DAYS} days'"), {'t': token}).scalar() if token else None
        if not uid:
            return {'error': 'Сессия отозвана. Войдите снова.', 'errorCode': 'AUTH_REQUIRED'}
        user = user_row(c, uid)
        if not user or not user['active']:
            return {'error': 'Учётная запись отключена.', 'errorCode': 'AUTH_REQUIRED'}
        if op == 'resumeSession':
            return {'user': public(user), 'configuration': {'schemaVersion': 3}}
        if op == 'logout':
            c.execute(text('delete from crm_sessions where token=:t'), {'t': token})
            return {'ok': True}
        if op == 'saveUser':
            if user['role'] not in ('Владелец', 'Администратор'):
                return {'error': 'Недостаточно прав'}
            u = req.get('user') or {}
            user_id = str(u.get('id') or secrets.token_hex(8))
            pin = str(u.get('pin') or '')
            if pin and not re.fullmatch(r'\d{4}', pin):
                return {'error': 'PIN должен состоять из 4 цифр'}
            if pin:
                c.execute(text("insert into crm_users(id,name,role,active,pin_hash,permissions) values (:id,:name,:role,:active,:pin,:permissions) on conflict(id) do update set name=:name,role=:role,active=:active,pin_hash=:pin,permissions=:permissions"), {'id': user_id, 'name': str(u.get('name', '')), 'role': str(u.get('role', 'Сотрудник')), 'active': bool(u.get('active', True)), 'pin': hash_pin(pin), 'permissions': json.dumps(u.get('permissions') or {})})
                # A changed PIN revokes every existing session of that user.
                c.execute(text('delete from crm_sessions where user_id=:id'), {'id': user_id})
            else:
                c.execute(text("update crm_users set name=:name,role=:role,active=:active,permissions=:permissions where id=:id"), {'id': user_id, 'name': str(u.get('name', '')), 'role': str(u.get('role', 'Сотрудник')), 'active': bool(u.get('active', True)), 'permissions': json.dumps(u.get('permissions') or {})})
            return {'users': all_users(c)}
        if op == 'deactivateUser':
            if user['role'] not in ('Владелец', 'Администратор'):
                return {'error': 'Недостаточно прав'}
            target = str(req.get('userId'))
            c.execute(text('update crm_users set active=false where id=:id'), {'id': target})
            c.execute(text('delete from crm_sessions where user_id=:id'), {'id': target})
            return {'users': all_users(c)}
        if op == 'migrateConfiguration':
            # Secret storage and integration proxying are not implemented yet.
            # An explicit error is essential: a success response can make the
            # client delete its only local copy of the integration credentials.
            return {'error': 'Перенос конфигурации на VPS ещё не поддерживается. Локальные ключи сохранены.'}
        if op == 'uploadPhoto':
            if permission_rank(user, 'stock') < 2:
                return {'error': 'Недостаточно прав для загрузки фото'}
            raw = req.get('dataBase64')
            if not isinstance(raw, str) or not raw:
                return {'error': 'Файл не передан'}
            try:
                data = base64.b64decode(raw, validate=True)
            except ValueError:
                return {'error': 'Некорректный файл'}
            if not data or len(data) > MAX_PHOTO_BYTES:
                return {'error': 'Файл слишком большой'}
            try:
                data, ext = _prepare_photo(data)
            except ValueError as exc:
                return {'error': str(exc)}
            os.makedirs(MEDIA_DIR, exist_ok=True)
            name = f'{uuid.uuid4().hex}.{ext}'
            with open(os.path.join(MEDIA_DIR, name), 'wb') as target:
                target.write(data)
            return {'url': f'/media/{name}', 'size': len(data)}
        if op == 'integrationProxy':
            return {'ok': False, 'error': 'Интеграция ещё не настроена на VPS'}
        if op == 'readSheet':
            name = str(req.get('sheet') or '').strip()
            if not name:
                return {'error': 'Не указан лист', 'errorCode': 'UNSUPPORTED_SHEET'}
            requested = req.get('area')
            area = requested if requested in PERMISSION_AREAS else DEFAULT_SHEET_AREAS.get(name)
            if area is None:
                return {'error': 'Неизвестный лист', 'errorCode': 'UNSUPPORTED_SHEET'}
            if permission_rank(user, area) < 1:
                return {'error': 'Недостаточно прав для раздела'}
            row = c.execute(text('select rows from crm_sheets where name=:name'), {'name': name}).mappings().first()
            if row is None:
                return {'error': 'Лист не найден на VPS', 'errorCode': 'SHEET_NOT_FOUND'}
            rows = row['rows']
            if not isinstance(rows, list):
                return {'error': 'Повреждённый лист на VPS'}
            return {'rows': [[str(cell) for cell in line] for line in rows if isinstance(line, list)]}
        if op == 'importSheets':
            sheets = req.get('sheets')
            if not isinstance(sheets, dict) or not sheets:
                return {'error': 'Нет листов для загрузки'}
            validated = {}
            for name, item in sheets.items():
                if not isinstance(name, str) or not name.strip() or len(name) > 128:
                    return {'error': 'Некорректное имя листа'}
                if not isinstance(item, dict):
                    return {'error': 'Некорректный лист'}
                area = item.get('area')
                rows = item.get('rows')
                if area not in PERMISSION_AREAS:
                    return {'error': 'Некорректный раздел листа'}
                if permission_rank(user, area) < 2:
                    return {'error': 'Недостаточно прав для раздела'}
                if not isinstance(rows, list) or len(rows) > MAX_SHEET_ROWS:
                    return {'error': 'Некорректные строки листа'}
                clean = []
                for line in rows:
                    if not isinstance(line, list) or len(line) > MAX_SHEET_COLUMNS:
                        return {'error': 'Некорректные строки листа'}
                    clean.append([str(cell) if cell is not None else '' for cell in line])
                validated[name] = clean
            for name, rows in validated.items():
                c.execute(text('insert into crm_sheets(name,rows) values (:name,:rows) on conflict(name) do update set rows=:rows,updated_at=now()'), {'name': name, 'rows': json.dumps(rows, ensure_ascii=False)})
            return {'ok': True, 'sheets': {name: len(rows) for name, rows in validated.items()}}
        if op == 'readWorkspace':
            values = {x['scope']: x['payload'] for x in c.execute(text('select scope,payload from crm_snapshots')).mappings()}
            try:
                workspace = project_workspace(values, user)
            except ValueError as error:
                return {'error': str(error)}
            return {'schemaVersion': 3, 'workspace': workspace, 'revisions': read_revisions(c)}
        if op == 'pushChanges':
            problem = validate_changes_request(req, user)
            if problem:
                return {'acceptedIds': [], 'conflicts': [], 'error': problem}
            accepted = []
            conflicts = []
            for change in req['changes']:
                cid = str(change['id'])
                payload = change['payload']
                scope = payload['scope']
                target = revision_scope(scope)
                stored = c.execute(text('select payload from crm_changes where id=:id'), {'id': cid}).scalar()
                if stored is not None:
                    stored = stored if isinstance(stored, dict) else json.loads(stored)
                    if canonical(stored) == canonical(payload):
                        accepted.append(cid)
                    else:
                        conflicts.append({'id': cid, 'scope': target})
                    continue
                revision = current_revision(c, target)
                base = payload.get('baseRevision')
                if (base is not None and scope not in MERGE_SCOPES and
                        (type(base) is not int or base != revision)):
                    conflicts.append({'id': cid, 'scope': target, 'serverRevision': revision})
                    continue
                result = c.execute(text('insert into crm_changes(id,scope,payload) values (:id,:scope,:payload) on conflict (id) do nothing'), {'id': cid, 'scope': scope, 'payload': json.dumps(payload, ensure_ascii=False)})
                if not result.rowcount:
                    # Lost a race with an identical retry: confirm only if the
                    # stored operation is exactly the same.
                    stored = c.execute(text('select payload from crm_changes where id=:id'), {'id': cid}).scalar()
                    stored = stored if isinstance(stored, dict) else json.loads(stored)
                    if canonical(stored) == canonical(payload):
                        accepted.append(cid)
                    else:
                        conflicts.append({'id': cid, 'scope': target})
                    continue
                new_revision = revision + 1
                stored_payload = payload
                if scope in MERGE_SCOPES:
                    row = c.execute(text('select payload from crm_snapshots where scope=:scope'), {'scope': scope}).scalar()
                    existing_payload = row if isinstance(row, dict) else (json.loads(row) if row else None)
                    stored_payload = merge_items(existing_payload, payload)
                c.execute(text('insert into crm_snapshots(scope,payload,revision) values (:scope,:payload,:revision) on conflict(scope) do update set payload=:payload,revision=:revision,updated_at=now()'), {'scope': scope, 'payload': json.dumps(stored_payload, ensure_ascii=False), 'revision': new_revision})
                c.execute(text('update crm_revisions set revision=:revision where scope=:scope'), {'revision': new_revision, 'scope': target})
                accepted.append(cid)
            return {'acceptedIds': accepted, 'conflicts': conflicts, 'revisions': read_revisions(c)}
        return {'error': 'Неизвестная операция', 'errorCode': 'UNSUPPORTED_OPERATION'}
