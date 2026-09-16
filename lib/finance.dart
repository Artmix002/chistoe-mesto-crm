import 'models.dart';
import 'deal_logic.dart';

class FinancialSnapshot {
  const FinancialSnapshot({
    required this.revenue,
    required this.expenses,
    required this.dealCount,
    this.workerPayout = 0,
    this.businessReserve = 0,
    this.ownerProfit = 0,
  });

  final double revenue;
  final double expenses;
  final int dealCount;
  final double workerPayout;
  final double businessReserve;
  final double ownerProfit;
  double get profit => revenue - expenses;
  double get margin => revenue == 0 ? 0 : profit / revenue * 100;

  /// Владельцам остаётся прибыль после выплат и резерва. Значение уже
  /// вычисляется для каждой сделки при построении снимка.
  double get calculatedOwnerProfit => profit - workerPayout - businessReserve;
  double get effectiveOwnerProfit => ownerProfit;

  Map<String, dynamic> toJson() => {
    'revenue': revenue,
    'expenses': expenses,
    'profit': profit,
    'margin': margin,
    'dealCount': dealCount,
    'workerPayout': workerPayout,
    'businessReserve': businessReserve,
    'ownerProfit': effectiveOwnerProfit,
  };
}

/// Показатель для одного среза отчёта: услуги, исполнителя или дня работы.
class DealPerformanceMetric {
  const DealPerformanceMetric({
    this.dealCount = 0,
    this.revenue = 0,
    this.expenses = 0,
    this.workerPayout = 0,
  });

  final int dealCount;
  final double revenue;
  final double expenses;
  final double workerPayout;

  /// Прибыль по сделкам до распределения выплаты исполнителю.
  double get profit => revenue - expenses;

  DealPerformanceMetric add(Deal deal, {double payout = 0}) =>
      DealPerformanceMetric(
        dealCount: dealCount + 1,
        revenue: revenue + deal.revenue,
        expenses: expenses + deal.expenses,
        workerPayout: workerPayout + payout,
      );
}

class DealPerformanceReport {
  const DealPerformanceReport({
    required this.byService,
    required this.byPerformer,
    required this.byDay,
  });

  final Map<String, DealPerformanceMetric> byService;
  final Map<String, DealPerformanceMetric> byPerformer;
  final Map<String, DealPerformanceMetric> byDay;

  int get activeDays => byDay.length;
}

/// Формирует повторно используемые срезы без привязки к виджетам или ячейкам
/// таблицы. Несколько исполнителей в одной сделке получают равные доли выплаты.
DealPerformanceReport summarizeDealPerformance(Iterable<Deal> deals) {
  final services = <String, DealPerformanceMetric>{};
  final performers = <String, DealPerformanceMetric>{};
  final days = <String, DealPerformanceMetric>{};

  for (final deal in deals) {
    final service = deal.service.trim().isEmpty
        ? 'Без услуги'
        : deal.service.trim();
    services[service] = (services[service] ?? const DealPerformanceMetric())
        .add(deal, payout: deal.workerPayout);

    final day = deal.date.trim().isEmpty ? 'Без даты' : deal.date.trim();
    days[day] = (days[day] ?? const DealPerformanceMetric()).add(
      deal,
      payout: deal.workerPayout,
    );

    final names = deal.performers
        .split(RegExp(r'[,;\\n/&]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) continue;
    final payoutPart = deal.workerPayout / names.length;
    for (final name in names) {
      performers[name] = (performers[name] ?? const DealPerformanceMetric())
          .add(deal, payout: payoutPart);
    }
  }
  return DealPerformanceReport(
    byService: services,
    byPerformer: performers,
    byDay: days,
  );
}

DateTime? parseCrmDate(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(value);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
}

/// Number of calendar days that have actually elapsed inside a reporting
/// period. A current or future-ending period is capped at [now], while a past
/// period keeps all of its days. This lets daily revenue include days with no
/// completed work.
int elapsedCalendarDaysInPeriod({
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  final today = DateTime(now.year, now.month, now.day);
  final elapsedLast = today.isBefore(last) ? today : last;
  if (elapsedLast.isBefore(first)) return 0;
  return elapsedLast.difference(first).inDays + 1;
}

bool isDateWithinPeriod(
  String date, {
  required DateTime from,
  required DateTime to,
}) {
  final parsed = parseCrmDate(date);
  if (parsed == null) return false;
  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  return !parsed.isBefore(first) && !parsed.isAfter(last);
}

bool isDateWithinClosedPeriod(String date, Map<String, dynamic> period) {
  final from = period['from']?.toString();
  final to = period['to']?.toString();
  final fromDate = from == null ? null : parseCrmDate(from);
  final toDate = to == null ? null : parseCrmDate(to);
  if (fromDate == null || toDate == null) return false;
  return isDateWithinPeriod(date, from: fromDate, to: toDate);
}

/// Локальные операции можно менять только при корректной дате и вне уже
/// закрытых периодов. Это правило одинаково для добавления и удаления.
bool isFinancialOperationEditable(
  String date,
  Iterable<Map<String, dynamic>> closedPeriods,
) {
  if (parseCrmDate(date) == null) return false;
  return !closedPeriods.any((period) => isDateWithinClosedPeriod(date, period));
}

FinancialSnapshot summarizeDeals(Iterable<Deal> deals) {
  final values = deals.toList(growable: false);
  return FinancialSnapshot(
    revenue: values.fold(0, (sum, deal) => sum + deal.revenue),
    expenses: values.fold(0, (sum, deal) => sum + deal.expenses),
    dealCount: values.length,
    workerPayout: values.fold(0, (sum, deal) => sum + deal.workerPayout),
    businessReserve: values.fold(0, (sum, deal) => sum + deal.businessReserve),
    ownerProfit: values.fold(
      0,
      (sum, deal) =>
          sum +
          (deal.ownerProfit != 0
              ? deal.ownerProfit
              : deal.profit - deal.workerPayout - deal.businessReserve),
    ),
  );
}

/// Накопительный баланс бизнес-счёта. В отличие от аналитических показателей
/// Dashboard он намеренно не принимает фильтр периода: это остаток счёта за
/// всё время, включая резервы со сделок и локальные пополнения/расходы.
double businessAccountBalance(
  Iterable<Deal> deals,
  Iterable<Map<String, dynamic>> transactions,
) =>
    deals.fold<double>(0, (sum, deal) => sum + deal.businessReserve) +
    transactions.fold<double>(
      0,
      (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
    );

/// Общая лента движений счёта, от новой даты к старой. Доходы, расходы и
/// отчисления со сделок не разделяются на блоки, поэтому хронология остаётся
/// читаемой даже когда операции добавлялись в разном порядке.
List<Map<String, dynamic>> sortBusinessTransactionsByDate(
  Iterable<Map<String, dynamic>> transactions,
) {
  final sorted = transactions
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  DateTime dateOf(Map<String, dynamic> item) =>
      parseCrmDate(item['date']?.toString() ?? '') ?? DateTime(1900);
  sorted.sort((a, b) {
    final byDate = dateOf(b).compareTo(dateOf(a));
    if (byDate != 0) return byDate;
    return (b['id']?.toString() ?? '').compareTo(a['id']?.toString() ?? '');
  });
  return sorted;
}

/// Преобразует строки листа «Расходы» в локальные операции, не создавая дубли.
List<Map<String, dynamic>> importSheetExpenses(
  Iterable<List<String>> rows, {
  Iterable<Map<String, dynamic>> existing = const [],
}) {
  final known = existing
      .map((item) => item['sourceId']?.toString())
      .whereType<String>()
      .toSet();
  final result = <Map<String, dynamic>>[];
  for (final raw in rows) {
    final cells = raw.map((value) => value.trim()).toList();
    if (cells.length < 8) continue;
    final sourceId = cells[3];
    final amount = parseLocalizedNumber(cells[7]);
    if (sourceId.isEmpty || amount <= 0 || known.contains(sourceId)) continue;
    known.add(sourceId);
    result.add({
      'id': 'sheet-$sourceId',
      'amount': -amount,
      'comment': cells[6].isEmpty ? 'Расход' : cells[6],
      'date': cells[4],
      'sourceId': sourceId,
      'source': 'google_sheets',
    });
  }
  return result;
}
