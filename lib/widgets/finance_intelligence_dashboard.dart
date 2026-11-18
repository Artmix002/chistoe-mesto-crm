// The dashboard deliberately uses small inline branches to keep the financial
// mapping next to the visual block it feeds.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../finance.dart';
import '../models.dart';

/// A compact financial cockpit built from the CRM's own source data. It keeps
/// money, goods and stock movements in the same reporting period so accounting
/// never has to rely on a second, manually maintained report.
class FinanceIntelligenceDashboard extends StatelessWidget {
  const FinanceIntelligenceDashboard({
    super.key,
    required this.deals,
    required this.products,
    required this.deliveries,
    required this.stockMovements,
    required this.transactions,
    this.from,
    this.to,
  });

  final List<Deal> deals;
  final List<Product> products;
  final List<Delivery> deliveries;
  final List<StockMovement> stockMovements;
  final List<Map<String, dynamic>> transactions;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context) {
    final report = _FinanceReport.build(
      deals: deals,
      products: products,
      deliveries: deliveries,
      stockMovements: stockMovements,
      transactions: transactions,
      from: from,
      to: to,
    );
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF171B26) : Colors.white;
    final border = dark ? const Color(0xFF30394B) : const Color(0xFFE2E7F0);
    final muted = dark ? const Color(0xFFAAB4C7) : const Color(0xFF657084);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(report: report, muted: muted),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1120
                ? 4
                : constraints.maxWidth >= 720
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 2.9 : 2.2,
              children: [
                _MetricCard(
                  title: 'Выручка',
                  value: _money(report.snapshot.revenue),
                  caption: '${report.snapshot.dealCount} сделок',
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF159B6B),
                  surface: surface,
                  border: border,
                ),
                _MetricCard(
                  title: 'Чистый результат',
                  value: _money(report.ownerResult),
                  caption: 'после выплат и резерва',
                  icon: report.ownerResult >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: report.ownerResult >= 0
                      ? const Color(0xFF276EF1)
                      : const Color(0xFFE05263),
                  surface: surface,
                  border: border,
                ),
                _MetricCard(
                  title: 'Бизнес-счёт',
                  value: _money(report.businessBalance),
                  caption: '${report.transactionCount} операций',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFF08A24),
                  surface: surface,
                  border: border,
                ),
                _MetricCard(
                  title: 'Товар в наличии',
                  value: _money(report.inventoryValue),
                  caption: '${_qty(report.inventoryUnits)} ед. на складе',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF8858D9),
                  surface: surface,
                  border: border,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final trend = _SectionCard(
              title: 'Динамика прибыли',
              subtitle: 'Выручка и расходы по дням выбранного периода',
              icon: Icons.show_chart_rounded,
              surface: surface,
              border: border,
              child: _TrendChart(points: report.dayPoints, muted: muted),
            );
            final allocation = _SectionCard(
              title: 'Структура денег',
              subtitle: 'Распределение каждой выручки',
              icon: Icons.pie_chart_outline_rounded,
              surface: surface,
              border: border,
              child: _AllocationChart(report: report, muted: muted),
            );
            if (!wide) {
              return Column(
                children: [trend, const SizedBox(height: 14), allocation],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: trend),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: allocation),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final operations = _SectionCard(
              title: 'Движение денег',
              subtitle: 'Сделки, резерв и операции бизнес-счёта',
              icon: Icons.swap_vert_rounded,
              surface: surface,
              border: border,
              child: _MoneyTimeline(items: report.moneyMoves, muted: muted),
            );
            final goods = _SectionCard(
              title: 'Товары и поставки',
              subtitle: 'Продажи, оборачиваемость и стоимость остатка',
              icon: Icons.inventory_outlined,
              surface: surface,
              border: border,
              child: _GoodsSummary(report: report, muted: muted),
            );
            if (!wide) {
              return Column(
                children: [operations, const SizedBox(height: 14), goods],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: operations),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: goods),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Журнал движения товара',
          subtitle:
              'Последние изменения количества: поступления, списания и инвентаризации',
          icon: Icons.receipt_long_outlined,
          surface: surface,
          border: border,
          child: _StockTimeline(items: report.stockMoves, muted: muted),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report, required this.muted});
  final _FinanceReport report;
  final Color muted;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF276EF1).withValues(alpha: .13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.insights_rounded, color: Color(0xFF276EF1)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Финансовый обзор',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(report.periodLabel, style: TextStyle(color: muted)),
          ],
        ),
      ),
      _Pill(
        icon: report.snapshot.margin >= 0
            ? Icons.check_circle_outline
            : Icons.error_outline,
        label: 'Маржа ${report.snapshot.margin.toStringAsFixed(1)}%',
        color: report.snapshot.margin >= 0
            ? const Color(0xFF159B6B)
            : const Color(0xFFE05263),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.surface,
    required this.border,
  });
  final String title, value, caption;
  final IconData icon;
  final Color color, surface, border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.surface,
    required this.border,
    required this.child,
  });
  final String title, subtitle;
  final IconData icon;
  final Color surface, border;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: const Color(0xFF276EF1)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.muted});
  final List<_DayPoint> points;
  final Color muted;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return _Empty(label: 'За выбранный период нет сделок', muted: muted);
    return SizedBox(
      height: 184,
      child: CustomPaint(
        painter: _TrendPainter(
          points,
          muted,
          Theme.of(context).brightness == Brightness.dark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.muted, this.dark);
  final List<_DayPoint> points;
  final Color muted;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final maxY = math.max(
      1,
      points.fold<double>(
        0,
        (v, p) => math.max(v, math.max(p.revenue, p.expenses)),
      ),
    );
    final chart = Rect.fromLTWH(4, 8, size.width - 8, size.height - 30);
    final grid = Paint()
      ..color = muted.withValues(alpha: .17)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    final step = points.length == 1 ? 0.0 : chart.width / (points.length - 1);
    Path lineFor(double Function(_DayPoint) get) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final point = Offset(
          chart.left + i * step,
          chart.bottom - get(p) / maxY * chart.height,
        );
        if (i == 0)
          path.moveTo(point.dx, point.dy);
        else
          path.lineTo(point.dx, point.dy);
      }
      return path;
    }

    final revenue = lineFor((p) => p.revenue);
    final fill = Path.from(revenue)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = const Color(0xFF276EF1).withValues(alpha: .12),
    );
    canvas.drawPath(
      revenue,
      Paint()
        ..color = const Color(0xFF276EF1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(
      lineFor((p) => p.expenses),
      Paint()
        ..color = const Color(0xFFE05263)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (final entry in [
      (const Color(0xFF276EF1), 'Выручка'),
      (const Color(0xFFE05263), 'Расходы'),
    ].indexed) {
      final x = chart.left + entry.$1 * 88;
      canvas.drawCircle(
        Offset(x + 5, size.height - 10),
        4,
        Paint()..color = entry.$2.$1,
      );
      text.text = TextSpan(
        text: entry.$2.$2,
        style: TextStyle(color: muted, fontSize: 10),
      );
      text.layout();
      text.paint(canvas, Offset(x + 13, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points || old.dark != dark;
}

class _AllocationChart extends StatelessWidget {
  const _AllocationChart({required this.report, required this.muted});
  final _FinanceReport report;
  final Color muted;
  @override
  Widget build(BuildContext context) {
    final values = <_Part>[
      _Part('Расходы', report.snapshot.expenses, const Color(0xFFE05263)),
      _Part(
        'Исполнителям',
        report.snapshot.workerPayout,
        const Color(0xFF8858D9),
      ),
      _Part('Резерв', report.snapshot.businessReserve, const Color(0xFFF08A24)),
      _Part(
        'Владельцам',
        math.max(0, report.ownerResult),
        const Color(0xFF159B6B),
      ),
    ];
    final total = values.fold<double>(0, (sum, part) => sum + part.value);
    if (total == 0)
      return _Empty(label: 'Нет распределённых сумм', muted: muted);
    return Column(
      children: [
        SizedBox(
          height: 112,
          child: CustomPaint(
            painter: _DonutPainter(
              values,
              total,
              Theme.of(context).colorScheme.onSurface,
            ),
            child: Center(
              child: Text(
                _money(total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...values
            .where((p) => p.value > 0)
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        p.label,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    Text(
                      '${_money(p.value)}  ${(p.value / total * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.total, this.textColor);
  final List<_Part> parts;
  final double total;
  final Color textColor;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: math.min(size.width, size.height) - 12,
      height: math.min(size.width, size.height) - 12,
    );
    var start = -math.pi / 2;
    for (final p in parts) {
      if (p.value <= 0) continue;
      final sweep = p.value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = p.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.parts != parts;
}

class _MoneyTimeline extends StatefulWidget {
  const _MoneyTimeline({required this.items, required this.muted});
  final List<_MoneyMove> items;
  final Color muted;

  @override
  State<_MoneyTimeline> createState() => _MoneyTimelineState();
}

class _MoneyTimelineState extends State<_MoneyTimeline> {
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _Empty(
        label: 'За выбранный период движений нет',
        muted: widget.muted,
      );
    }
    final items = _showAll ? widget.items : widget.items.take(7).toList();
    return Column(
      children: [
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.amount >= 0
                        ? const Color(0xFF159B6B).withValues(alpha: .12)
                        : const Color(0xFFE05263).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    item.amount >= 0 ? Icons.add : Icons.remove,
                    size: 16,
                    color: item.amount >= 0
                        ? const Color(0xFF159B6B)
                        : const Color(0xFFE05263),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${item.date} · ${item.kind}',
                        style: TextStyle(fontSize: 11, color: widget.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.amount >= 0 ? '+' : ''}${_money(item.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: item.amount >= 0
                        ? const Color(0xFF159B6B)
                        : const Color(0xFFE05263),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.items.length > 7)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showAll
                    ? 'Свернуть ленту'
                    : 'Показать все (${widget.items.length})',
              ),
            ),
          ),
      ],
    );
  }
}

class _GoodsSummary extends StatelessWidget {
  const _GoodsSummary({required this.report, required this.muted});
  final _FinanceReport report;
  final Color muted;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(
        label: 'Продано товаров',
        value:
            '${report.soldProducts.length} поз. · ${_money(report.productSales)}',
        muted: muted,
      ),
      _InfoRow(
        label: 'Себестоимость проданного',
        value: _money(report.productCost),
        muted: muted,
      ),
      _InfoRow(
        label: 'Валовая прибыль товара',
        value: _money(report.productSales - report.productCost),
        muted: muted,
        positive: report.productSales >= report.productCost,
      ),
      _InfoRow(
        label: 'Поставки',
        value: '${report.deliveryCount} · ${_money(report.deliveryCost)}',
        muted: muted,
      ),
      const Divider(height: 22),
      Text(
        'Лидеры продаж',
        style: TextStyle(
          fontSize: 12,
          color: muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (report.soldProducts.isEmpty)
        Text(
          'Проданных товаров за период нет',
          style: TextStyle(fontSize: 12, color: muted),
        )
      else
        ...report.soldProducts
            .take(4)
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.sku.isEmpty ? 'Без арт.' : p.sku} · ${p.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      _money(p.salePrice > 0 ? p.salePrice : p.myPrice),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.muted,
    this.positive,
  });
  final String label, value;
  final Color muted;
  final bool? positive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: muted)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: positive == null
                ? null
                : positive!
                ? const Color(0xFF159B6B)
                : const Color(0xFFE05263),
          ),
        ),
      ],
    ),
  );
}

class _StockTimeline extends StatefulWidget {
  const _StockTimeline({required this.items, required this.muted});
  final List<_StockMove> items;
  final Color muted;

  @override
  State<_StockTimeline> createState() => _StockTimelineState();
}

class _StockTimelineState extends State<_StockTimeline> {
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty)
      return _Empty(
        label: 'Движений товара за выбранный период нет',
        muted: widget.muted,
      );
    final items = _showAll ? widget.items : widget.items.take(8).toList();
    return Column(
      children: [
        ...items.map(
          (m) => Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: widget.muted.withValues(alpha: .16)),
              ),
            ),
            child: Row(
              children: [
                Icon(_stockIcon(m.type), color: _stockColor(m.type), size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${m.type}${m.note.isEmpty ? '' : ' · ${m.note}'} · ${m.date}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: widget.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${m.quantity > 0 ? '+' : ''}${_qty(m.quantity)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _stockColor(m.type),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.items.length > 8)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showAll
                    ? 'Свернуть журнал'
                    : 'Показать все (${widget.items.length})',
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label, required this.muted});
  final String label;
  final Color muted;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 118,
    child: Center(
      child: Text(label, style: TextStyle(color: muted, fontSize: 12)),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _FinanceReport {
  _FinanceReport({
    required this.snapshot,
    required this.businessBalance,
    required this.inventoryValue,
    required this.inventoryUnits,
    required this.ownerResult,
    required this.dayPoints,
    required this.moneyMoves,
    required this.stockMoves,
    required this.soldProducts,
    required this.productSales,
    required this.productCost,
    required this.deliveryCost,
    required this.deliveryCount,
    required this.transactionCount,
    required this.periodLabel,
  });
  final FinancialSnapshot snapshot;
  final double businessBalance,
      inventoryValue,
      inventoryUnits,
      ownerResult,
      productSales,
      productCost,
      deliveryCost;
  final int deliveryCount, transactionCount;
  final List<_DayPoint> dayPoints;
  final List<_MoneyMove> moneyMoves;
  final List<_StockMove> stockMoves;
  final List<Product> soldProducts;
  final String periodLabel;
  factory _FinanceReport.build({
    required List<Deal> deals,
    required List<Product> products,
    required List<Delivery> deliveries,
    required List<StockMovement> stockMovements,
    required List<Map<String, dynamic>> transactions,
    DateTime? from,
    DateTime? to,
  }) {
    bool included(String date) {
      final day = parseCrmDate(date);
      if (day == null) return from == null && to == null;
      return (from == null || !day.isBefore(from)) &&
          (to == null || !day.isAfter(to));
    }

    final periodDeals = deals.where((d) => included(d.date)).toList();
    final snapshot = summarizeDeals(periodDeals);
    final sold =
        products.where((p) {
          final at = p.soldTimestamp;
          return p.sold || p.status == 'sold'
              ? (at == 0 ||
                    included(
                      DateTime.fromMillisecondsSinceEpoch(at).toIso8601String(),
                    ))
              : false;
        }).toList()..sort(
          (a, b) => (b.salePrice > 0 ? b.salePrice : b.myPrice).compareTo(
            a.salePrice > 0 ? a.salePrice : a.myPrice,
          ),
        );
    final periodDeliveries = deliveries.where((d) => included(d.date)).toList();
    final periodTransactions = transactions
        .where((t) => included(t['date']?.toString() ?? ''))
        .toList();
    final periodStock = stockMovements.where((m) => included(m.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final pointMap = <String, _DayPoint>{};
    for (final d in periodDeals) {
      final key = d.date;
      final old = pointMap[key] ?? _DayPoint(key, 0, 0);
      pointMap[key] = _DayPoint(
        key,
        old.revenue + d.revenue,
        old.expenses + d.expenses,
      );
    }
    final points = pointMap.values.toList()
      ..sort(
        (a, b) => (parseCrmDate(a.date) ?? DateTime(1900)).compareTo(
          parseCrmDate(b.date) ?? DateTime(1900),
        ),
      );
    final moves = <_MoneyMove>[];
    for (final d in periodDeals) {
      if (d.revenue != 0)
        moves.add(
          _MoneyMove(
            date: d.date,
            title: d.service.isEmpty ? d.clientName : d.service,
            amount: d.revenue,
            kind: 'Сделка',
          ),
        );
      if (d.businessReserve != 0)
        moves.add(
          _MoneyMove(
            date: d.date,
            title: 'Резерв по сделке',
            amount: d.businessReserve,
            kind: 'Бизнес-счёт',
          ),
        );
    }
    for (final t in periodTransactions) {
      final value = (t['amount'] as num?)?.toDouble() ?? 0;
      moves.add(
        _MoneyMove(
          date: t['date']?.toString() ?? '',
          title: t['comment']?.toString() ?? 'Операция',
          amount: value,
          kind: t['source'] == 'google_sheets' ? 'Расходы' : 'Операция',
        ),
      );
    }
    moves.sort(
      (a, b) => (parseCrmDate(b.date) ?? DateTime(1900)).compareTo(
        parseCrmDate(a.date) ?? DateTime(1900),
      ),
    );
    final productById = {for (final p in products) p.id: p};
    final stock = periodStock
        .map(
          (m) => _StockMove(
            date: m.date,
            product: productById[m.itemId]?.name ?? m.itemId,
            type: m.type,
            quantity: m.quantity,
            note: m.note,
          ),
        )
        .toList();
    final inventory = products.where((p) => !p.sold && p.status != 'sold');
    final inventoryValue = inventory.fold<double>(
      0,
      (sum, p) => sum + (p.costPrice ?? p.purchasePrice) * p.quantity,
    );
    final label = from == null && to == null
        ? 'Все финансовые данные CRM'
        : '${_date(from!)} - ${_date(to ?? DateTime.now())}';
    return _FinanceReport(
      snapshot: snapshot,
      businessBalance: businessAccountBalance(deals, transactions),
      inventoryValue: inventoryValue,
      inventoryUnits: inventory.fold<double>(0, (sum, p) => sum + p.quantity),
      ownerResult: snapshot.effectiveOwnerProfit,
      dayPoints: points,
      moneyMoves: moves,
      stockMoves: stock,
      soldProducts: sold,
      productSales: sold.fold<double>(
        0,
        (sum, p) => sum + (p.salePrice > 0 ? p.salePrice : p.myPrice),
      ),
      productCost: sold.fold<double>(
        0,
        (sum, p) => sum + (p.costPrice ?? p.purchasePrice),
      ),
      deliveryCost: periodDeliveries.fold<double>(
        0,
        (sum, d) => sum + d.totalCost,
      ),
      deliveryCount: periodDeliveries.length,
      transactionCount: periodTransactions.length,
      periodLabel: label,
    );
  }
}

class _DayPoint {
  const _DayPoint(this.date, this.revenue, this.expenses);
  final String date;
  final double revenue, expenses;
}

class _MoneyMove {
  const _MoneyMove({
    required this.date,
    required this.title,
    required this.amount,
    required this.kind,
  });
  final String date, title, kind;
  final double amount;
}

class _StockMove {
  const _StockMove({
    required this.date,
    required this.product,
    required this.type,
    required this.quantity,
    required this.note,
  });
  final String date, product, type, note;
  final double quantity;
}

class _Part {
  const _Part(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

String _money(double value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.add(digits.substring(math.max(0, end - 3), end));
  }
  return '$sign${groups.reversed.join(' ')} ₽';
}

String _qty(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
IconData _stockIcon(String type) => type == 'Приход'
    ? Icons.add_box_outlined
    : type == 'Расход' || type == 'Списание'
    ? Icons.remove_circle_outline
    : Icons.inventory_outlined;
Color _stockColor(String type) => type == 'Приход'
    ? const Color(0xFF159B6B)
    : type == 'Расход' || type == 'Списание'
    ? const Color(0xFFE05263)
    : const Color(0xFFF08A24);
