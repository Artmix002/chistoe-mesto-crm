/// Сверка локальных данных с тем, что реально сохранилось на VPS.
///
/// Проверка сравнивает количество записей по разделам, а не содержимое:
/// это быстрый способ заметить неполный перенос до переключения устройств.
class MigrationSection {
  const MigrationSection({
    required this.title,
    required this.local,
    required this.server,
  });

  final String title;
  final int local;
  final int server;

  bool get matches => local == server;
}

class MigrationReport {
  const MigrationReport(this.sections);

  final List<MigrationSection> sections;

  List<MigrationSection> get mismatches =>
      sections.where((section) => !section.matches).toList(growable: false);

  bool get isComplete => mismatches.isEmpty;
}

const migrationSectionTitles = <String, String>{
  'clients': 'Клиенты',
  'stockItems': 'Склад',
  'products': 'Товары',
  'deliveries': 'Поставки',
  'orders': 'Заказы',
  'manualDeals': 'Ручные сделки',
  'transactions': 'Финансовые операции',
  'closedPeriods': 'Закрытые периоды',
  'appointments': 'Записи',
  'serviceCatalog': 'Справочник услуг',
  'notes': 'Заметки',
  'revenuePlans': 'Планы выручки',
  'dealsSheet': 'Лист «Август»',
  'accountingSheet': 'Лист «Основное»',
  'expensesSheet': 'Лист «Расходы»',
  'knowledge': 'База знаний',
};

/// Строит отчёт в стабильном порядке. Отсутствующий ключ считается нулём,
/// потому что сервер отдаёт только реально существующие области.
MigrationReport buildMigrationReport({
  required Map<String, int> local,
  required Map<String, int> server,
}) {
  return MigrationReport([
    for (final entry in migrationSectionTitles.entries)
      MigrationSection(
        title: entry.value,
        local: local[entry.key] ?? 0,
        server: server[entry.key] ?? 0,
      ),
  ]);
}
