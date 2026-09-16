import 'package:flutter/material.dart';

import '../finance.dart';
import '../reconciliation.dart';

class FinancialSummaryCard extends StatelessWidget {
  const FinancialSummaryCard({
    super.key,
    required this.snapshot,
    required this.materialCost,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
  });

  final FinancialSnapshot snapshot;
  final double materialCost;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(surfaceColor, borderColor),
    child: Wrap(
      spacing: 28,
      runSpacing: 12,
      children:
          [
                Text(
                  'Финансовый итог',
                  style: TextStyle(
                    color: mainTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('Выручка: ${_money(snapshot.revenue)}'),
                Text('Расходы: ${_money(snapshot.expenses)}'),
                Text('Прибыль до распределения: ${_money(snapshot.profit)}'),
                Text('Исполнителям: ${_money(snapshot.workerPayout)}'),
                Text('Бизнес-счёт: ${_money(snapshot.businessReserve)}'),
                Text('Владельцам: ${_money(snapshot.effectiveOwnerProfit)}'),
                Text('Маржа: ${snapshot.margin.toStringAsFixed(1)}%'),
                Text('Материалы: ${_money(materialCost)}'),
              ]
              .map(
                (child) => DefaultTextStyle(
                  style: TextStyle(color: mainTextColor),
                  child: child,
                ),
              )
              .toList(),
    ),
  );
}

class FinanceReconciliationCard extends StatelessWidget {
  const FinanceReconciliationCard({
    super.key,
    required this.report,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
  });

  final FinancialReconciliation report;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    final status = report.isReconciled
        ? 'Сверка пройдена'
        : report.hasAccountingComparison
        ? 'Есть расхождения'
        : 'Недостаточно полей для сравнения';
    final icon = report.isReconciled
        ? Icons.verified
        : report.hasAccountingComparison
        ? Icons.warning_amber
        : Icons.info_outline;
    final color = report.isReconciled
        ? Colors.green
        : report.hasAccountingComparison
        ? Colors.orange
        : mutedTextColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(surfaceColor, borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Сверка источников: $status',
                  style: TextStyle(
                    color: mainTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children:
                [
                      Text(
                        'Сделки: ${report.dealCount} • выручка ${_money(report.dealRevenue)} • расходы ${_money(report.dealExpenses)}',
                      ),
                      Text(
                        'Основное: ${report.accountingRowCount} строк${report.accountingRevenue == null ? '' : ' • выручка ${_money(report.accountingRevenue!)}'}${report.accountingExpenses == null ? '' : ' • расходы ${_money(report.accountingExpenses!)}'}',
                      ),
                      Text(
                        'Расходы: ${report.expensesSheetCount} строк • ${_money(report.expensesSheetAmount)}',
                      ),
                      ...report.discrepancies.map(
                        (message) => Text(
                          message,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ]
                    .map(
                      (child) => DefaultTextStyle(
                        style: TextStyle(color: mainTextColor, fontSize: 12),
                        child: child,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class DealPerformanceCard extends StatelessWidget {
  const DealPerformanceCard({
    super.key,
    required this.report,
    required this.totalDeals,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
  });

  final DealPerformanceReport report;
  final int totalDeals;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, DealPerformanceMetric>> sorted(
      Map<String, DealPerformanceMetric> values,
      double Function(DealPerformanceMetric value) measure,
    ) {
      final entries = values.entries.toList()
        ..sort((a, b) => measure(b.value).compareTo(measure(a.value)));
      return entries;
    }

    final services = sorted(report.byService, (metric) => metric.profit);
    final staff = sorted(report.byPerformer, (metric) => metric.workerPayout);
    final days = report.byDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final averageLoad = report.activeDays == 0
        ? 0
        : totalDeals / report.activeDays;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(surfaceColor, borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Отчёт по услугам, сотрудникам и загрузке',
            style: TextStyle(color: mainTextColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 30,
            runSpacing: 8,
            children:
                [
                      Text('Услуг: ${services.length}'),
                      Text('Исполнителей: ${staff.length}'),
                      Text('Рабочих дней: ${report.activeDays}'),
                      Text(
                        'Средняя загрузка: ${averageLoad.toStringAsFixed(1)} заказа/день',
                      ),
                      ...services
                          .take(5)
                          .map(
                            (entry) => Text(
                              '${entry.key}: ${entry.value.dealCount} заказов • прибыль ${_money(entry.value.profit)}',
                            ),
                          ),
                      ...staff
                          .take(5)
                          .map(
                            (entry) => Text(
                              '${entry.key}: ${entry.value.dealCount} заказов • выплаты ${_money(entry.value.workerPayout)}',
                            ),
                          ),
                      ...days
                          .take(7)
                          .map(
                            (entry) => Text(
                              '${entry.key}: ${entry.value.dealCount} заказов • выручка ${_money(entry.value.revenue)}',
                            ),
                          ),
                    ]
                    .map(
                      (child) => DefaultTextStyle(
                        style: TextStyle(color: mainTextColor, fontSize: 12),
                        child: child,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(Color surfaceColor, Color borderColor) =>
    BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    );

String _money(num value) => '${value.toStringAsFixed(0)} ₽';
