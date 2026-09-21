import 'package:flutter/material.dart';

import 'dashboard_stat_card.dart';

class OverviewMetric {
  const OverviewMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = const Color(0xFFF28C28),
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
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
    this.workspace,
  });

  final List<OverviewMetric> metrics;
  final int loadedDeals;
  final bool loading;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final Widget? workspace;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Сводка по работе детейлинг-центра',
        style: TextStyle(color: mutedTextColor, fontSize: 14),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final cards = metrics
              .map(
                (metric) => DashboardStatCard(
                  title: metric.title,
                  value: metric.value,
                  icon: metric.icon,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  mainTextColor: mainTextColor,
                  mutedTextColor: mutedTextColor,
                  accentColor: metric.accentColor,
                  onTap: metric.onTap,
                ),
              )
              .toList(growable: false);
          if (!compact) {
            return Wrap(spacing: 14, runSpacing: 14, children: cards);
          }
          final cardWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(growable: false),
          );
        },
      ),
      if (workspace != null)
        Padding(padding: const EdgeInsets.only(top: 18), child: workspace!),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final leading = Row(
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
              ],
            );
            final source = Text(
              'Обновлено из листа «Август»',
              style: TextStyle(color: mutedTextColor, fontSize: 12),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [leading, const SizedBox(height: 8), source],
                  )
                : Row(
                    children: [
                      Expanded(child: leading),
                      const SizedBox(width: 12),
                      source,
                    ],
                  );
          },
        ),
      ),
    ],
  );
}
