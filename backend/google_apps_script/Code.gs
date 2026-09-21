/**
 * Endpoint синхронизации CRM «Чистое место».
 *
 * Разверните как Web app, задав Script properties CRM_OWNER_PIN и
 * CRM_SHEET_ID. Все данные CRM записываются только в отдельные листы CRM_*;
 * исходные операционные листы не перезаписываются этим скриптом.
 */
// Должна совпадать с SheetsSchema.version в приложении.
const CRM_SCHEMA_VERSION = 3;
const CRM_AUDIT_SHEET = 'CRM_SyncAudit';
const CRM_SUPPORTED_SCOPES = [
  'clients', 'stock', 'manualDeals', 'finance', 'appointments',
  'serviceCatalog', 'workspace', 'dashboardNotes', 'revenuePlans',
  'knowledgeBase', 'messages', 'auditOnly',
];
const CRM_MAX_CHANGES_PER_REQUEST = 20;
const CRM_LOCK_TIMEOUT_MS = 30000;
const CRM_USERS_PROPERTY = 'CRM_USERS';
const CRM_SESSIONS_PROPERTY = 'CRM_SESSIONS';
const CRM_CONFIGURATION_PROPERTY = 'CRM_CONFIGURATION';
const CRM_SECRETS_PROPERTY = 'CRM_SECRETS';
const CRM_PERMISSION_AREAS = [
  'dashboard', 'clients', 'deals', 'calendar', 'finance', 'stock',
  'settings', 'messages', 'bot', 'integrations', 'backup',
];

function doGet() {
  return json_({ok: true, schemaVersion: CRM_SCHEMA_VERSION});
}

function doPost(event) {
  try {
    const request = JSON.parse(event.postData.contents || '{}');
    const operation = String(request.operation || 'pushChanges');
    if (operation === 'listUsers') return json_({users: publicUsers_()});
    if (operation === 'login') return json_(login_(request));
    const session = requireSession_(request);
    if (operation === 'resumeSession') return json_(sessionResponse_(session));
    if (operation === 'logout') return json_(logout_(request.sessionToken));
    if (operation === 'saveUser') return json_(saveUser_(session, request));
    if (operation === 'deactivateUser') return json_(deactivateUser_(session, request));
    if (operation === 'migrateConfiguration') {
      return json_(migrateConfiguration_(session, request));
    }
    if (operation === 'integrationProxy') {
      return json_(integrationProxy_(session, request));
    }
    if (request.operation === 'readSheet') {
      requirePermission_(session, 'finance', 'view');
      return readSheet_(request);
    }
    if (request.operation === 'readWorkspace') {
      requireAnyPermission_(session, 'view');
      return readWorkspace_(request);
    }
    requireChangePermissions_(session, request.changes);
    if (request.schemaVersion !== CRM_SCHEMA_VERSION ||
        !Array.isArray(request.changes) ||
        request.changes.length > CRM_MAX_CHANGES_PER_REQUEST ||
        !request.changes.every(isSupportedChange_)) {
      return json_({acceptedIds: [], error: 'Unsupported payload'});
    }

    const spreadsheetId = PropertiesService.getScriptProperties().getProperty(
      'CRM_SHEET_ID',
    );
    if (!spreadsheetId) {
      return json_({acceptedIds: [], error: 'CRM_SHEET_ID is not configured'});
    }
    // Снимки заменяют содержимое CRM_* листов. Сериализуем такие операции,
    // чтобы параллельные клиенты не выполняли запись одновременно; при
    // нескольких писателях разрешение конфликтов должно быть на backend.
    const lock = LockService.getScriptLock();
    if (!lock.tryLock(CRM_LOCK_TIMEOUT_MS)) {
      return json_({acceptedIds: [], error: 'Synchronization is busy'});
    }
    try {
      const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
      const acceptedIds = [];
      request.changes.forEach((change) => {
        if (!change || !change.id) return;
        if (alreadyProcessed_(spreadsheet, String(change.id))) {
          acceptedIds.push(String(change.id));
          return;
        }
        applyChange_(spreadsheet, change);
        appendAudit_(spreadsheet, change);
        acceptedIds.push(String(change.id));
      });
      return json_({acceptedIds: acceptedIds});
    } finally {
      lock.releaseLock();
    }
  } catch (error) {
    if (error && error.crmAuthCode) {
      return json_({
        acceptedIds: [],
        error: 'Сессия отозвана. Войдите снова.',
        errorCode: error.crmAuthCode,
      });
    }
    // Не подтверждаем ничего при ошибке: клиент безопасно повторит запрос.
    // Не пишем объект исключения в журнал: он может содержать URL или
    // фрагменты входного запроса. Для диагностики достаточно общего кода.
    console.error('CRM sync failed');
    return json_({acceptedIds: [], error: 'Synchronization failed'});
  }
}

function scriptProperties_() {
  return PropertiesService.getScriptProperties();
}

function parseProperty_(key, fallback) {
  const raw = scriptProperties_().getProperty(key);
  if (!raw) return fallback;
  try { return JSON.parse(raw); } catch (_) { return fallback; }
}

function saveProperty_(key, value) {
  scriptProperties_().setProperty(key, JSON.stringify(value));
}

function authError_(code) {
  const error = new Error(code);
  error.crmAuthCode = code;
  return error;
}

function defaultPermissions_(role) {
  const permissions = {};
  CRM_PERMISSION_AREAS.forEach((area) => permissions[area] = 'hidden');
  if (role === 'Владелец' || role === 'Администратор') {
    CRM_PERMISSION_AREAS.forEach((area) => permissions[area] = 'edit');
  } else if (role === 'Мастер') {
    permissions.calendar = 'view';
  } else if (role === 'Бухгалтер') {
    permissions.dashboard = 'view';
    permissions.finance = 'edit';
  }
  return permissions;
}

function normalizePermissions_(source, role) {
  const base = defaultPermissions_(role);
  const input = source && typeof source === 'object' ? source : {};
  CRM_PERMISSION_AREAS.forEach((area) => {
    if (['hidden', 'view', 'edit'].indexOf(input[area]) !== -1) {
      base[area] = input[area];
    }
  });
  return base;
}

function hashPin_(pin, salt) {
  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256, String(salt) + ':' + String(pin),
    Utilities.Charset.UTF_8,
  );
  return bytes.map((b) => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');
}

function randomToken_() {
  return Utilities.base64EncodeWebSafe(Utilities.getUuid() + ':' + new Date().getTime());
}

function bootstrapOwner_() {
  const users = parseProperty_(CRM_USERS_PROPERTY, []);
  if (users.length) return users;
  const props = scriptProperties_();
  const pin = props.getProperty('CRM_OWNER_PIN');
  if (!/^\d{4}$/.test(String(pin || ''))) {
    throw new Error('Настройте 4-значный CRM_OWNER_PIN в Script Properties.');
  }
  const salt = randomToken_();
  const owner = {
    id: 'owner-' + Utilities.getUuid(),
    name: props.getProperty('CRM_OWNER_NAME') || 'Владелец',
    role: 'Владелец', active: true,
    pinSalt: salt, pinHash: hashPin_(pin, salt),
    permissions: defaultPermissions_('Владелец'),
  };
  saveProperty_(CRM_USERS_PROPERTY, [owner]);
  // Стартовый PIN больше не нужен после безопасного создания владельца.
  props.deleteProperty('CRM_OWNER_PIN');
  return [owner];
}

function allUsers_() { return bootstrapOwner_(); }

function publicUser_(user) {
  return {
    id: String(user.id), name: String(user.name || ''),
    role: String(user.role || 'Сотрудник'), active: user.active !== false,
    permissions: normalizePermissions_(user.permissions, user.role),
  };
}

function publicUsers_() { return allUsers_().map(publicUser_); }

function cleanSessions_() {
  const sessions = parseProperty_(CRM_SESSIONS_PROPERTY, {});
  Object.keys(sessions).forEach((token) => {
    if (!sessions[token] || !sessions[token].userId) {
      delete sessions[token];
    }
  });
  saveProperty_(CRM_SESSIONS_PROPERTY, sessions);
  return sessions;
}

function requireSession_(request) {
  const token = String(request.sessionToken || '');
  const sessions = cleanSessions_();
  const session = sessions[token];
  if (!token || !session) throw authError_('SESSION_INVALID');
  const user = allUsers_().filter((item) => item.id === session.userId)[0];
  if (!user || user.active === false) throw authError_('ACCOUNT_REVOKED');
  return {token: token, user: user};
}

function requireOwner_(session) {
  if (session.user.role !== 'Владелец') throw new Error('Только владелец может управлять пользователями.');
}

function permissionRank_(value) { return {hidden: 0, view: 1, edit: 2}[value] || 0; }
function requirePermission_(session, area, needed) {
  const permissions = normalizePermissions_(session.user.permissions, session.user.role);
  if (permissionRank_(permissions[area]) < permissionRank_(needed)) {
    throw new Error('Недостаточно прав для раздела «' + area + '».');
  }
}

function requireAnyPermission_(session, needed) {
  const permissions = normalizePermissions_(session.user.permissions, session.user.role);
  const allowed = CRM_PERMISSION_AREAS.some((area) =>
    permissionRank_(permissions[area]) >= permissionRank_(needed));
  if (!allowed) throw new Error('У пользователя нет доступных разделов.');
}

function requireChangePermissions_(session, changes) {
  const scopeArea = {
    clients: 'clients', stock: 'stock', manualDeals: 'deals', finance: 'finance',
    appointments: 'calendar', serviceCatalog: 'integrations', workspace: 'dashboard',
    dashboardNotes: 'dashboard', revenuePlans: 'finance',
    messages: 'messages', knowledgeBase: 'bot', auditOnly: 'dashboard',
  };
  (changes || []).forEach((change) => {
    const area = scopeArea[(change.payload || {}).scope];
    if (area) requirePermission_(session, area, 'edit');
  });
}

function configuration_() {
  return parseProperty_(CRM_CONFIGURATION_PROPERTY, {});
}

function dataSources_(configuration) {
  const sources = {
    deals: 'Август',
    accounting: 'Основное',
    expenses: 'Расходы',
    appointments: 'CRM_Appointments',
  };
  const configured = configuration && configuration.dataSources;
  if (configured && typeof configured === 'object') {
    Object.keys(sources).forEach((key) => {
      const value = String(configured[key] || '').trim();
      if (value) sources[key] = value;
    });
  }
  return sources;
}

function sessionResponse_(session) {
  return {user: publicUser_(session.user), configuration: configuration_()};
}

function login_(request) {
  const user = allUsers_().filter((item) => item.id === String(request.userId || ''))[0];
  const pin = String(request.pin || '');
  if (!user || user.active === false || !/^\d{4}$/.test(pin) ||
      hashPin_(pin, user.pinSalt) !== user.pinHash) {
    throw new Error('Неверный PIN или пользователь отключён.');
  }
  const sessions = cleanSessions_();
  const token = randomToken_();
  sessions[token] = {userId: user.id};
  saveProperty_(CRM_SESSIONS_PROPERTY, sessions);
  const response = sessionResponse_({token: token, user: user});
  response.sessionToken = token;
  return response;
}

function logout_(token) {
  const sessions = cleanSessions_();
  delete sessions[String(token || '')];
  saveProperty_(CRM_SESSIONS_PROPERTY, sessions);
  return {ok: true};
}

function revokeUserSessions_(userId) {
  const sessions = cleanSessions_();
  Object.keys(sessions).forEach((token) => {
    if (sessions[token].userId === userId) delete sessions[token];
  });
  saveProperty_(CRM_SESSIONS_PROPERTY, sessions);
}

function saveUser_(session, request) {
  requireOwner_(session);
  const input = request.user || {};
  const name = String(input.name || '').trim();
  const id = String(input.id || '');
  const pin = input.pin === undefined ? '' : String(input.pin);
  if (!name) throw new Error('Укажите имя пользователя.');
  if (pin && !/^\d{4}$/.test(pin)) throw new Error('PIN должен состоять из 4 цифр.');
  const users = allUsers_();
  let user = users.filter((item) => item.id === id)[0];
  if (!user) {
    if (!/^\d{4}$/.test(pin)) throw new Error('Для нового пользователя задайте PIN из 4 цифр.');
    const salt = randomToken_();
    user = {id: 'user-' + Utilities.getUuid(), pinSalt: salt, pinHash: hashPin_(pin, salt)};
    users.push(user);
  } else if (pin) {
    user.pinSalt = randomToken_();
    user.pinHash = hashPin_(pin, user.pinSalt);
  }
  user.name = name;
  user.role = String(input.role || 'Сотрудник');
  user.active = input.active !== false;
  user.permissions = normalizePermissions_(input.permissions, user.role);
  if (user.role === 'Владелец') {
    CRM_PERMISSION_AREAS.forEach((area) => user.permissions[area] = 'edit');
  }
  saveProperty_(CRM_USERS_PROPERTY, users);
  if (pin || user.active === false) revokeUserSessions_(user.id);
  return {users: publicUsers_()};
}

function deactivateUser_(session, request) {
  requireOwner_(session);
  const id = String(request.userId || '');
  const users = allUsers_();
  const user = users.filter((item) => item.id === id)[0];
  if (!user) throw new Error('Пользователь не найден.');
  const activeOwners = users.filter((item) => item.active !== false && item.role === 'Владелец');
  if (user.role === 'Владелец' && user.active !== false && activeOwners.length <= 1) {
    throw new Error('Нельзя отключить единственного активного владельца.');
  }
  user.active = false;
  saveProperty_(CRM_USERS_PROPERTY, users);
  revokeUserSessions_(user.id);
  return {users: publicUsers_()};
}

function migrateConfiguration_(session, request) {
  requirePermission_(session, 'integrations', 'edit');
  const config = request.configuration;
  if (!config || typeof config !== 'object') throw new Error('Некорректная конфигурация.');
  const publicConfig = {
    sheetUrl: String(config.sheetUrl || ''),
    dataSources: dataSources_(config),
    calendarId: String(config.calendarId || 'primary'),
    calendarName: String(config.calendarName || 'Основной календарь'),
    aiSettings: config.aiSettings || {},
    messengers: config.messengers || {},
    avitoAccounts: (config.avitoAccounts || []).map((item) => ({
      key: item.key || '', name: item.name || 'Avito', userId: item.userId || '',
    })),
  };
  const secretConfig = {
    syncToken: String(config.syncToken || ''),
    calendarAccessToken: String(config.calendarAccessToken || ''),
    calendarRefreshToken: String(config.calendarRefreshToken || ''),
    calendarClientSecret: String(config.calendarClientSecret || ''),
    aiApiKey: String(config.aiApiKey || ''),
    messengerTokens: config.messengerTokens || {},
    avitoAccounts: config.avitoAccounts || [],
  };
  saveProperty_(CRM_CONFIGURATION_PROPERTY, publicConfig);
  saveProperty_(CRM_SECRETS_PROPERTY, secretConfig);
  return {ok: true, configuration: publicConfig};
}

function integrationProxy_(session, request) {
  const action = String((request.request || {}).action || '');
  const area = action.indexOf('calendar') === 0 ? 'calendar' :
      action.indexOf('message') === 0 ? 'messages' :
      action.indexOf('ai') === 0 ? 'bot' : 'integrations';
  requirePermission_(session, area, action.indexOf('read') >= 0 ? 'view' : 'edit');
  const input = (request.request || {}).payload || {};
  const secrets = parseProperty_(CRM_SECRETS_PROPERTY, {});
  const config = configuration_();
  // Ключи остаются в Script Properties. Этот endpoint возвращает только
  // полезный ответ поставщика и никогда не сериализует CRM_SECRETS.
  if (action === 'calendar.read') {
    const access = String(secrets.calendarAccessToken || '');
    if (!access) throw new Error('Google Календарь ещё не подключён владельцем.');
    const calendarId = encodeURIComponent(String(config.calendarId || 'primary'));
    const url = 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId +
      '/events?singleEvents=true&orderBy=startTime&maxResults=250';
    const response = UrlFetchApp.fetch(url, {headers: {Authorization: 'Bearer ' + access}, muteHttpExceptions: true});
    return providerResponse_(response);
  }
  if (action === 'calendar.write') {
    const access = String(secrets.calendarAccessToken || '');
    const method = String(input.method || 'POST').toUpperCase();
    const eventId = input.eventId ? '/' + encodeURIComponent(String(input.eventId)) : '';
    const calendarId = encodeURIComponent(String(config.calendarId || 'primary'));
    const url = 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events' + eventId;
    const response = UrlFetchApp.fetch(url, {
      method: method,
      headers: {Authorization: 'Bearer ' + access, 'Content-Type': 'application/json'},
      payload: JSON.stringify(input.body || {}), muteHttpExceptions: true,
    });
    return providerResponse_(response);
  }
  if (action === 'message.telegram') {
    const token = String((secrets.messengerTokens || {}).telegram || '');
    if (!token) throw new Error('Telegram ещё не подключён владельцем.');
    const response = UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/' + String(input.method || 'getUpdates'), {
      method: 'post', contentType: 'application/json', payload: JSON.stringify(input.body || {}), muteHttpExceptions: true,
    });
    return providerResponse_(response);
  }
  if (action === 'message.vk') {
    const token = String((secrets.messengerTokens || {}).vk || '');
    if (!token) throw new Error('VK ещё не подключён владельцем.');
    const body = input.body || {};
    body.access_token = token;
    body.v = body.v || '5.199';
    const response = UrlFetchApp.fetch('https://api.vk.com/method/' + String(input.method || 'messages.getConversations'), {
      method: 'post', payload: body, muteHttpExceptions: true,
    });
    return providerResponse_(response);
  }
  if (action === 'ai.chat') {
    const settings = config.aiSettings || {};
    const key = String(secrets.aiApiKey || '');
    const base = String(settings.baseUrl || '').replace(/\/+$/, '');
    if (!key || !base) throw new Error('AI ещё не подключён владельцем.');
    const response = UrlFetchApp.fetch(base + '/chat/completions', {
      method: 'post', contentType: 'application/json',
      headers: {Authorization: 'Bearer ' + key},
      payload: JSON.stringify(input.body || {}), muteHttpExceptions: true,
    });
    return providerResponse_(response);
  }
  throw new Error('Действие интеграции не поддержано: ' + action);
}

function providerResponse_(response) {
  const status = response.getResponseCode();
  const text = response.getContentText();
  let body;
  try { body = JSON.parse(text); } catch (_) { body = {raw: text.substring(0, 2000)}; }
  if (status < 200 || status >= 300) {
    throw new Error('Внешний сервис вернул HTTP ' + status + '.');
  }
  return {ok: true, body: body};
}

function readSheet_(request) {
  const sources = dataSources_(configuration_());
  const allowed = Object.keys(sources).map((key) => sources[key]);
  if (allowed.indexOf(String(request.sheet || '')) === -1) {
    return json_({rows: [], error: 'Unsupported sheet'});
  }
  const spreadsheetId = PropertiesService.getScriptProperties().getProperty(
    'CRM_SHEET_ID',
  );
  if (!spreadsheetId) return json_({rows: [], error: 'CRM_SHEET_ID is not configured'});
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = spreadsheet.getSheetByName(String(request.sheet));
  if (!sheet) return json_({rows: []});
  return json_({
    schemaVersion: CRM_SCHEMA_VERSION,
    rows: sheet.getDataRange().getDisplayValues(),
  });
}

/**
 * Supplies the cloud source of truth to a newly authorised CRM instance.
 * Secrets, OAuth tokens, message credentials and test-conversation text are
 * never present in this payload.
 */
function readWorkspace_(request) {
  const spreadsheetId = PropertiesService.getScriptProperties().getProperty(
    'CRM_SHEET_ID',
  );
  if (!spreadsheetId) {
    return json_({workspace: {}, error: 'CRM_SHEET_ID is not configured'});
  }
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const manual = readRowsSheet_(spreadsheet, 'CRM_ManualDeals');
  return json_({
    schemaVersion: CRM_SCHEMA_VERSION,
    workspace: {
      clients: readObjectSheet_(spreadsheet, 'CRM_Clients'),
      stockItems: readObjectSheet_(spreadsheet, 'CRM_Stock'),
      stockMovements: readObjectSheet_(spreadsheet, 'CRM_StockMovements'),
      manualDeals: manual.rows.length > 1 ? manual.rows.slice(1) : [],
      manualDealHeaders: manual.rows.length ? manual.rows[0] : [],
      transactions: readObjectSheet_(spreadsheet, 'CRM_LocalTransactions'),
      closedPeriods: readObjectSheet_(spreadsheet, 'CRM_ClosedPeriods'),
      financeSettings: (readObjectSheet_(spreadsheet, 'CRM_FinanceSettings')[0] || {}),
      appointments: readObjectSheet_(spreadsheet, 'CRM_Appointments'),
      serviceCatalog: readObjectSheet_(spreadsheet, 'CRM_ServiceCatalog'),
      notes: readObjectSheet_(spreadsheet, 'CRM_DashboardNotes'),
      revenuePlans: readObjectSheet_(spreadsheet, 'CRM_RevenuePlans'),
      workspaceSettings: (readObjectSheet_(spreadsheet, 'CRM_DashboardSettings')[0] || {}),
      messageSettings: (readObjectSheet_(spreadsheet, 'CRM_MessageSettings')[0] || {}),
      knowledge: readObjectSheet_(spreadsheet, 'CRM_KnowledgeBase'),
      knowledgeVersions: readObjectSheet_(spreadsheet, 'CRM_KnowledgeVersions'),
      audit: readSyncAudit_(spreadsheet),
    },
  });
}

function isSupportedChange_(change) {
  return Boolean(change && typeof change.id === 'string' &&
    change.id.length > 0 && change.id.length <= 128 && change.payload &&
    change.payload.schemaVersion === CRM_SCHEMA_VERSION &&
    change.payload.kind === 'snapshot' &&
    CRM_SUPPORTED_SCOPES.indexOf(change.payload.scope) !== -1);
}

function applyChange_(spreadsheet, change) {
  const payload = change.payload || {};
  if (payload.kind !== 'snapshot') return;
  switch (payload.scope) {
    case 'clients':
      replaceObjectSheet_(spreadsheet, 'CRM_Clients', [
        'id', 'name', 'phone', 'car', 'source', 'note', 'lastContact',
        'status', 'responsible', 'carHistory', 'interactionHistory',
        'telegramChatId', 'vkPeerId', 'phones', 'cars', 'vehicleIds',
      ], payload.data || []);
      return;
    case 'stock':
      replaceObjectSheet_(spreadsheet, 'CRM_Stock', [
        'id', 'name', 'unit', 'quantity', 'minQuantity', 'purchasePrice',
        'supplier',
      ], payload.items || []);
      replaceObjectSheet_(spreadsheet, 'CRM_StockMovements', [
        'id', 'itemId', 'type', 'quantity', 'date', 'note', 'dealId',
        'service',
      ], payload.movements || []);
      return;
    case 'manualDeals':
      replaceRowsSheet_(
        spreadsheet,
        'CRM_ManualDeals',
        [
          payload.headers || [
            'Дата', 'Автомобиль', 'Телефон', 'Услуга', 'Исполнители',
            'Выручка', 'Расходы', 'Чистая прибыль', '% работника',
            'Выплата работнику', '% бизнес-счёта', 'Отложено на бизнес-счёт',
            'Прибыль владельцев', 'Дима', 'Артём', 'Егор', 'Статус',
            'Клиент', 'Источник', 'Комментарий', 'Ручной расчёт', 'ID',
          ],
        ].concat(payload.rows || []),
      );
      return;
    case 'finance':
      replaceObjectSheet_(spreadsheet, 'CRM_LocalTransactions', [
        'id', 'amount', 'comment', 'category', 'date', 'source',
      ], payload.transactions || []);
      replaceObjectSheet_(
        spreadsheet,
        'CRM_ClosedPeriods',
        [
          'closedAt', 'from', 'to', 'revenue', 'expenses', 'profit',
          'workerPayout', 'businessReserve', 'ownerProfit', 'dealCount',
        ],
        payload.closedPeriods || (payload.closedPeriod ? [payload.closedPeriod] : []),
      );
      replaceObjectSheet_(spreadsheet, 'CRM_FinanceSettings', ['categories'], [{
        categories: payload.categories || [],
      }]);
      return;
    case 'appointments':
      replaceObjectSheet_(spreadsheet, 'CRM_Appointments', [
        'id', 'summary', 'description', 'start', 'end', 'extendedProperties',
        'updated',
      ], payload.events || []);
      return;
    case 'serviceCatalog':
      replaceObjectSheet_(spreadsheet, 'CRM_ServiceCatalog', [
        'id', 'name', 'durationHours', 'category', 'materialIds',
        'archived', 'updatedAt',
      ], payload.items || []);
      return;
    case 'workspace':
      replaceObjectSheet_(spreadsheet, 'CRM_DashboardNotes', [
        'id', 'text', 'createdAt', 'updatedAt',
      ], payload.notes || []);
      replaceObjectSheet_(spreadsheet, 'CRM_RevenuePlans', [
        'id', 'title', 'target', 'from', 'to', 'createdAt',
      ], payload.revenuePlans || []);
      replaceObjectSheet_(spreadsheet, 'CRM_DashboardSettings', [
        'dashboardPeriod', 'dashboardPeriodFrom', 'dashboardPeriodTo',
      ], [payload.settings || {}]);
      return;
    case 'dashboardNotes':
      replaceObjectSheet_(spreadsheet, 'CRM_DashboardNotes', [
        'id', 'text', 'createdAt', 'updatedAt',
      ], payload.notes || []);
      return;
    case 'revenuePlans':
      replaceObjectSheet_(spreadsheet, 'CRM_RevenuePlans', [
        'id', 'title', 'target', 'from', 'to', 'createdAt',
      ], payload.revenuePlans || []);
      return;
    case 'messages':
      replaceObjectSheet_(spreadsheet, 'CRM_MessageSettings', [
        'quickReplyTemplates', 'assignees', 'tags', 'pendingMessages',
      ], [{
        quickReplyTemplates: payload.quickReplyTemplates || [],
        assignees: payload.assignees || {},
        tags: payload.tags || {},
        pendingMessages: payload.pendingMessages || [],
      }]);
      return;
    case 'knowledgeBase':
      replaceObjectSheet_(spreadsheet, 'CRM_KnowledgeBase', [
        'id', 'content', 'updatedAt',
      ], [{
        id: 'knowledge-base',
        content: payload.content || '',
        updatedAt: new Date().toISOString(),
      }]);
      replaceObjectSheet_(spreadsheet, 'CRM_KnowledgeVersions', [
        'id', 'content', 'createdAt', 'source', 'comment',
      ], payload.versions || []);
      return;
    case 'auditOnly':
      // Записи, настройки интеграций и прочие события не имеют отдельного
      // листа-источника. Их достаточно сохранить в CRM_SyncAudit, который
      // appendAudit_ добавляет после применения изменения.
      return;
    default:
      return;
  }
}

function replaceObjectSheet_(spreadsheet, name, headers, objects) {
  const rows = objects.map((value) => headers.map((header) => scalar_(value[header])));
  replaceRowsSheet_(spreadsheet, name, [headers].concat(rows));
}

function readRowsSheet_(spreadsheet, name) {
  const sheet = spreadsheet.getSheetByName(name);
  return {rows: sheet && sheet.getLastRow() > 0 ? sheet.getDataRange().getDisplayValues() : []};
}

function readObjectSheet_(spreadsheet, name) {
  const rows = readRowsSheet_(spreadsheet, name).rows;
  if (rows.length < 2) return [];
  const headers = rows[0];
  return rows.slice(1).filter((row) => row.some((value) => String(value).trim() !== ''))
    .map((row) => {
      const object = {};
      headers.forEach((header, index) => {
        object[header] = parseScalar_(row[index]);
      });
      return object;
    });
}

function readSyncAudit_(spreadsheet) {
  return readObjectSheet_(spreadsheet, CRM_AUDIT_SHEET).slice(-500).map((entry) => ({
    action: 'Синхронизация',
    entity: String(entry.entity || ''),
    details: String(entry.details || ''),
    date: String(entry.createdAt || entry.receivedAt || ''),
    actor: 'CRM',
  }));
}

function parseScalar_(value) {
  const text = String(value === undefined ? '' : value);
  if (text === '') return '';
  if ((text[0] === '{' && text[text.length - 1] === '}') ||
      (text[0] === '[' && text[text.length - 1] === ']')) {
    try { return JSON.parse(text); } catch (_) {}
  }
  if (text === 'true') return true;
  if (text === 'false') return false;
  const number = Number(text);
  return text.trim() !== '' && !isNaN(number) ? number : text;
}

function replaceRowsSheet_(spreadsheet, name, rows) {
  const sheet = getOrCreateSheet_(spreadsheet, name);
  sheet.clearContents();
  if (!rows.length) return;
  const width = rows.reduce((maximum, row) => Math.max(maximum, row.length), 1);
  const values = rows.map((row) => {
    const padded = row.slice(0, width);
    while (padded.length < width) padded.push('');
    return padded.map(scalar_);
  });
  sheet.getRange(1, 1, values.length, width).setValues(values);
  sheet.setFrozenRows(1);
}

function scalar_(value) {
  if (value === null || value === undefined) return '';
  if (Array.isArray(value) || typeof value === 'object') return JSON.stringify(value);
  return value;
}

function appendAudit_(spreadsheet, change) {
  const sheet = getOrCreateSheet_(spreadsheet, CRM_AUDIT_SHEET);
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(['syncId', 'receivedAt', 'entity', 'details', 'createdAt', 'attempts', 'scope']);
    sheet.setFrozenRows(1);
  }
  sheet.appendRow([
    String(change.id),
    new Date().toISOString(),
    change.entity || '',
    change.details || '',
    change.createdAt || '',
    change.attempts || 0,
    (change.payload || {}).scope || '',
  ]);
}

function alreadyProcessed_(spreadsheet, id) {
  const sheet = spreadsheet.getSheetByName(CRM_AUDIT_SHEET);
  if (!sheet || sheet.getLastRow() < 2) return false;
  return sheet.getRange(2, 1, sheet.getLastRow() - 1, 1)
    .createTextFinder(id)
    .matchEntireCell(true)
    .findNext() !== null;
}

function getOrCreateSheet_(spreadsheet, name) {
  return spreadsheet.getSheetByName(name) || spreadsheet.insertSheet(name);
}

function json_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
