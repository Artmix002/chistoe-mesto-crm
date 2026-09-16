import 'package:flutter/material.dart';

import 'dashboard_stat_card.dart';

class OverviewMetric {
  const OverviewMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Представление сводки. Денежные расчёты намеренно выполняются вне виджета:
/// так один и тот же UI не знает деталей Google Sheets и локального хранилища.
class OverviewDashboard extends StatelessWidget {
  const OverviewDashboard({
    super.key,
    required this.metrics,
    required this.loadedDeals,
    required this.loading,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    this.financialSummary,
    this.reconciliationReport,
    this.performanceReport,
    this.workspace,
  });

  final List<OverviewMetric> metrics;
  final int loadedDeals;
  final bool loading;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final Widget? financialSummary;
  final Widget? reconciliationReport;
  final Widget? performanceReport;
  final Widget? workspace;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Сводка по работе детейлинг-центра',
        style: TextStyle(color: mutedTextColor, fontSize: 14),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: metrics
            .map(
              (metric) => DashboardStatCard(
                title: metric.title,
                value: metric.value,
                icon: metric.icon,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                mainTextColor: mainTextColor,
                mutedTextColor: mutedTextColor,
                onTap: metric.onTap,
              ),
            )
            .toList(growable: false),
      ),
      if (workspace != null)
        Padding(padding: const EdgeInsets.only(top: 24), child: workspace!),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFFF28C28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Загружено заказов: $loadedDeals',
                style: TextStyle(
                  color: mainTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Обновлено из листа «Август»',
              style: TextStyle(color: mutedTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
      if (!loading && financialSummary != null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: financialSummary!,
        ),
      if (!loading && reconciliationReport != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: reconciliationReport!,
        ),
      if (!loading && performanceReport != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: performanceReport!,
        ),
    ],
  );
}
