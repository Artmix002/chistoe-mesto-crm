/// Versioned Google Sheets contract. Keep this in sync with the published
/// workbook and bump when a column is added or renamed.
class SheetsSchema {
  // Версия 3 добавляет облачные снимки записей, справочника услуг,
  // Dashboard и базы знаний в защищённые служебные листы CRM_*.
  static const version = 3;
  static const dealsSheet = 'Август';
  static const accountingSheet = 'Основное';
  static const expensesSheet = 'Расходы';
  static const requiredDealColumns = [
    'Авто',
    'Телефон',
    'Услуга',
    'Работник',
    'Стоимость',
    'Расходы',
    'Чистая прибыль',
  ];
  static const requiredExpenseColumns = ['ID', 'Дата', 'Описание', 'Сумма'];

  static const manualDealColumns = [
    'Дата',
    'Автомобиль',
    'Телефон',
    'Услуга',
    'Исполнители',
    'Выручка',
    'Расходы',
    'Чистая прибыль',
    '% работника',
    'Выплата работнику',
    '% бизнес-счёта',
    'Отложено на бизнес-счёт',
    'Прибыль владельцев',
    'Дима',
    'Артём',
    'Егор',
    'Статус',
    'Клиент',
    'Источник',
    'Комментарий',
    'Ручной расчёт',
    'ID',
  ];

  /// Заголовки служебных листов, которые создаёт Apps Script endpoint.
  /// Они не заменяют рабочие листы, а дают стабильный контракт для миграции
  /// на отдельный backend.
  static const crmClientColumns = [
    'id',
    'name',
    'phone',
    'car',
    'source',
    'note',
    'lastContact',
    'status',
    'responsible',
    'carHistory',
    'interactionHistory',
    'telegramChatId',
    'vkPeerId',
    'phones',
    'cars',
    'vehicleIds',
  ];
  static const crmClosedPeriodColumns = [
    'closedAt',
    'from',
    'to',
    'revenue',
    'expenses',
    'profit',
    'workerPayout',
    'businessReserve',
    'ownerProfit',
    'dealCount',
  ];

  static const crmServiceCatalogColumns = [
    'id',
    'name',
    'durationHours',
    'category',
    'materialIds',
    'archived',
    'updatedAt',
  ];

  static List<String> missingColumns(
    List<String> headers,
    List<String> required,
  ) {
    final normalized = headers.map((h) => h.trim().toLowerCase()).toSet();
    return required
        .where((column) => !normalized.contains(column.toLowerCase()))
        .toList();
  }
}
