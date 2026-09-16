import 'deal_logic.dart';
import 'finance.dart';
import 'models.dart';

class FinancialReconciliation {
  const FinancialReconciliation({
    required this.dealRevenue,
    required this.dealExpenses,
    required this.dealCount,
    required this.accountingRevenue,
    required this.accountingExpenses,
    required this.accountingRowCount,
    required this.expensesSheetAmount,
    required this.expensesSheetCount,
  });

  final double dealRevenue;
  final double dealExpenses;
  final int dealCount;
  final double? accountingRevenue;
  final double? accountingExpenses;
  final int accountingRowCount;
  final double expensesSheetAmount;
  final int expensesSheetCount;

  bool get hasAccountingComparison =>
      accountingRevenue != null || accountingExpenses != null;

  List<String> get discrepancies {
    const tolerance = .01;
    final result = <String>[];
    if (accountingRevenue != null &&
        (dealRevenue - accountingRevenue!).abs() > tolerance) {
      result.add('Выручка сделок отличается от листа «Основное»');
    }
    if (accountingExpenses != null &&
        (dealExpenses - accountingExpenses!).abs() > tolerance) {
      result.add('Расходы сделок отличаются от листа «Основное»');
    }
    return result;
  }

  bool get isReconciled => hasAccountingComparison && discrepancies.isEmpty;
}

String _normalizeHeader(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\\s+'), ' ');

int _findHeaderIndex(List<String> headers, Iterable<String> alternatives) {
  final normalized = headers.map(_normalizeHeader).toList();
  for (final alternative in alternatives) {
    final index = normalized.indexOf(_normalizeHeader(alternative));
    if (index >= 0) return index;
  }
  return -1;
}

double? _sumNamedColumn(
  Iterable<List<String>> rows,
  Iterable<String> alternatives, {
  DateTime? from,
  DateTime? to,
}) {
  final values = rows.toList(growable: false);
  if (values.isEmpty) return null;
  final headers = values.first;
  final valueIndex = _findHeaderIndex(headers, alternatives);
  if (valueIndex < 0) return null;
  final dateIndex = _findHeaderIndex(headers, const ['Дата', 'Дата операции']);
  return values.skip(1).fold<double>(0, (sum, row) {
    if (dateIndex >= 0 && from != null && to != null) {
      final date = dateIndex < row.length ? parseCrmDate(row[dateIndex]) : null;
      if (date != null && (date.isBefore(from) || date.isAfter(to))) return sum;
    }
    return sum +
        (valueIndex < row.length ? parseLocalizedNumber(row[valueIndex]) : 0);
  });
}

FinancialReconciliation reconcileFinanceSources({
  required Iterable<Deal> deals,
  required Iterable<List<String>> accountingRows,
  required Iterable<Map<String, dynamic>> transactions,
  DateTime? from,
  DateTime? to,
}) {
  final dealValues = deals.toList(growable: false);
  final accounting = accountingRows.toList(growable: false);
  final expenseTransactions = transactions.where(
    (item) => item['source']?.toString() == 'google_sheets',
  );
  var expensesSheetAmount = 0.0;
  var expensesSheetCount = 0;
  for (final item in expenseTransactions) {
    final date = parseCrmDate(item['date']?.toString() ?? '');
    if (from != null &&
        to != null &&
        date != null &&
        (date.isBefore(from) || date.isAfter(to))) {
      continue;
    }
    final raw = item['amount'];
    final amount = raw is num
        ? raw.toDouble()
        : parseLocalizedNumber(raw?.toString() ?? '');
    expensesSheetAmount += amount.abs();
    expensesSheetCount++;
  }
  return FinancialReconciliation(
    dealRevenue: dealValues.fold(0, (sum, deal) => sum + deal.revenue),
    dealExpenses: dealValues.fold(0, (sum, deal) => sum + deal.expenses),
    dealCount: dealValues.length,
    accountingRevenue: _sumNamedColumn(
      accounting,
      const ['Выручка', 'Доходы', 'Доход'],
      from: from,
      to: to,
    ),
    accountingExpenses: _sumNamedColumn(
      accounting,
      const ['Расходы', 'Расход'],
      from: from,
      to: to,
    ),
    accountingRowCount: accounting.length > 1 ? accounting.length - 1 : 0,
    expensesSheetAmount: expensesSheetAmount,
    expensesSheetCount: expensesSheetCount,
  );
}
