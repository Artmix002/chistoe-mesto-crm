import 'models.dart';
import 'schema.dart';

/// Формирует версионированный снимок данных для безопасной фоновой доставки.
/// Интеграционные секреты и OAuth-токены намеренно не принимаются на вход.
Map<String, dynamic> buildSyncPayload(
  String entity, {
  required Iterable<Client> clients,
  required Iterable<StockItem> stockItems,
  required Iterable<StockMovement> stockMovements,
  required Iterable<List<String>> manualDeals,
  required Iterable<Map<String, dynamic>> businessTransactions,
  Iterable<Map<String, dynamic>> products = const [],
  Iterable<Map<String, dynamic>> deliveries = const [],
  Iterable<Map<String, dynamic>> orders = const [],
  Iterable<String> deletedProductIds = const [],
  Iterable<String> deletedDeliveryIds = const [],
  Iterable<String> deletedOrderIds = const [],
  required Iterable<Map<String, dynamic>> closedPeriods,
  Map<String, dynamic>? closedPeriod,
  Iterable<Map<String, dynamic>> serviceCatalog = const [],
  Iterable<Map<String, dynamic>> stickyNotes = const [],
  Iterable<Map<String, dynamic>> revenuePlans = const [],
  String knowledgeBase = '',
  Iterable<Map<String, dynamic>> knowledgeVersions = const [],
  Iterable<Map<String, dynamic>> appointments = const [],
  Iterable<Map<String, dynamic>> auditEntries = const [],
  Iterable<Map<String, String>> pendingMessages = const [],
  Map<String, String> messageAssignees = const {},
  Map<String, List<String>> messageTags = const {},
  Iterable<String> quickReplyTemplates = const [],
  Map<String, int> vkAppointmentMessageIds = const {},
  int? vkSummaryMessageId,
  Iterable<String> accountingCategories = const [],
  String dashboardPeriod = 'Все время',
  String dashboardPeriodFrom = '',
  String dashboardPeriodTo = '',
}) {
  final base = <String, dynamic>{
    'schemaVersion': SheetsSchema.version,
    'kind': 'snapshot',
  };
  switch (entity) {
    case 'Клиент':
      return {
        ...base,
        'scope': 'clients',
        'data': clients.map((client) => client.toJson()).toList(),
      };
    case 'Товар':
    case 'Склад':
      return {
        ...base,
        'scope': 'stock',
        'items': stockItems.map((item) => item.toJson()).toList(),
        'movements': stockMovements
            .map((movement) => movement.toJson())
            .toList(),
      };
    case 'Поставка':
      return {
        ...base,
        'scope': 'deliveries',
        'items': deliveries.map(Map<String, dynamic>.from).toList(),
        'deletedIds': deletedDeliveryIds.toList(),
      };
    case 'Заказ':
      return {
        ...base,
        'scope': 'orders',
        'items': orders.map(Map<String, dynamic>.from).toList(),
        'deletedIds': deletedOrderIds.toList(),
      };
    case 'Товар на продажу':
      return {
        ...base,
        'scope': 'products',
        'items': products.map(Map<String, dynamic>.from).toList(),
        'deletedIds': deletedProductIds.toList(),
      };
    case 'Сделка':
      return {
        ...base,
        'scope': 'manualDeals',
        'headers': SheetsSchema.manualDealColumns,
        'rows': manualDeals.map((row) => List<String>.from(row)).toList(),
      };
    case 'Расход':
    case 'Доход':
    case 'Финансовая операция':
    case 'Бухгалтерия':
      return {
        ...base,
        'scope': 'finance',
        'transactions': businessTransactions
            .map(Map<String, dynamic>.from)
            .toList(),
        'closedPeriods': closedPeriods.map(Map<String, dynamic>.from).toList(),
        'closedPeriod': closedPeriod == null
            ? null
            : Map<String, dynamic>.from(closedPeriod),
        'categories': accountingCategories.toList(),
      };
    case 'Справочник услуг':
      return {
        ...base,
        'scope': 'serviceCatalog',
        'items': serviceCatalog.map(Map<String, dynamic>.from).toList(),
      };
    case 'Запись':
    case 'Календарь':
      return {
        ...base,
        'scope': 'appointments',
        'events': appointments.map(Map<String, dynamic>.from).toList(),
      };
    case 'Заметки':
      return {
        ...base,
        'scope': 'dashboardNotes',
        'notes': stickyNotes.map(Map<String, dynamic>.from).toList(),
      };
    case 'План выручки':
      return {
        ...base,
        'scope': 'revenuePlans',
        'revenuePlans': revenuePlans.map(Map<String, dynamic>.from).toList(),
      };
    case 'Рабочее пространство':
      return {
        ...base,
        'scope': 'workspace',
        'notes': stickyNotes.map(Map<String, dynamic>.from).toList(),
        'revenuePlans': revenuePlans.map(Map<String, dynamic>.from).toList(),
        'settings': {
          'dashboardPeriod': dashboardPeriod,
          'dashboardPeriodFrom': dashboardPeriodFrom,
          'dashboardPeriodTo': dashboardPeriodTo,
        },
      };
    case 'База знаний':
      return {
        ...base,
        'scope': 'knowledgeBase',
        'content': knowledgeBase,
        'versions': knowledgeVersions.map(Map<String, dynamic>.from).toList(),
      };
    case 'Сообщения':
      return {
        ...base,
        'scope': 'messages',
        'quickReplyTemplates': quickReplyTemplates.toList(),
        'assignees': Map<String, String>.from(messageAssignees),
        'tags': {
          for (final entry in messageTags.entries)
            entry.key: List<String>.from(entry.value),
        },
        'pendingMessages': pendingMessages
            .map((message) => Map<String, String>.from(message))
            .toList(),
        'vkAppointmentMessageIds': Map<String, int>.from(
          vkAppointmentMessageIds,
        ),
        'vkSummaryMessageId': vkSummaryMessageId,
      };
    case 'Журнал CRM':
      return {
        ...base,
        'scope': 'auditOnly',
        'entries': auditEntries.map(Map<String, dynamic>.from).toList(),
      };
    default:
      return {...base, 'scope': 'auditOnly'};
  }
}
