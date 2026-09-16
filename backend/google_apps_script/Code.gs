/**
 * Endpoint синхронизации CRM «Чистое место».
 *
 * Разверните как Web app, задав Script properties CRM_SYNC_TOKEN и
 * CRM_SHEET_ID. Все данные CRM записываются только в отдельные листы CRM_*;
 * исходные операционные листы не перезаписываются этим скриптом.
 */
// Должна совпадать с SheetsSchema.version в приложении.
const CRM_SCHEMA_VERSION = 3;
const CRM_AUDIT_SHEET = 'CRM_SyncAudit';
const CRM_SUPPORTED_SCOPES = [
  'clients', 'stock', 'manualDeals', 'finance', 'appointments',
  'serviceCatalog', 'workspace', 'knowledgeBase', 'auditOnly',
];
const CRM_MAX_CHANGES_PER_REQUEST = 20;
const CRM_LOCK_TIMEOUT_MS = 30000;

function doGet() {
  return json_({ok: true, schemaVersion: CRM_SCHEMA_VERSION});
}

function doPost(event) {
  try {
    const request = JSON.parse(event.postData.contents || '{}');
    const secret = PropertiesService.getScriptProperties().getProperty(
      'CRM_SYNC_TOKEN',
    );
    if (!secret || request.syncToken !== secret) {
      return json_({acceptedIds: [], error: 'Unauthorized'});
    }
    if (request.operation === 'readSheet') {
      return readSheet_(request);
    }
    if (request.operation === 'readWorkspace') {
      return readWorkspace_(request);
    }
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
    // Не подтверждаем ничего при ошибке: клиент безопасно повторит запрос.
    // Не пишем объект исключения в журнал: он может содержать URL или
    // фрагменты входного запроса. Для диагностики достаточно общего кода.
    console.error('CRM sync failed');
    return json_({acceptedIds: [], error: 'Synchronization failed'});
  }
}

function readSheet_(request) {
  const allowed = ['Август', 'Основное', 'Расходы'];
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
      appointments: readObjectSheet_(spreadsheet, 'CRM_Appointments'),
      serviceCatalog: readObjectSheet_(spreadsheet, 'CRM_ServiceCatalog'),
      notes: readObjectSheet_(spreadsheet, 'CRM_DashboardNotes'),
      revenuePlans: readObjectSheet_(spreadsheet, 'CRM_RevenuePlans'),
      workspaceSettings: (readObjectSheet_(spreadsheet, 'CRM_DashboardSettings')[0] || {}),
      knowledge: readObjectSheet_(spreadsheet, 'CRM_KnowledgeBase'),
      knowledgeVersions: readObjectSheet_(spreadsheet, 'CRM_KnowledgeVersions'),
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
      return;
    case 'appointments':
      replaceObjectSheet_(spreadsheet, 'CRM_Appointments', [
        'id', 'summary', 'description', 'start', 'end', 'extendedProperties',
        'updated',
      ], payload.events || []);
      return;
    case 'serviceCatalog':
      replaceObjectSheet_(spreadsheet, 'CRM_ServiceCatalog', [
        'id', 'name', 'durationHours', 'category', 'materialIds', 'prices',
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
