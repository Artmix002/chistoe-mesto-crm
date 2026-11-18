import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';

Future<void> showProductAccounting(
  BuildContext context, {
  required List<Product> products,
  required List<Delivery> deliveries,
}) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 1180,
      height: math.min(MediaQuery.sizeOf(context).height * .88, 900),
      child: _ProductFinanceDashboard(
        products: products,
        deliveries: deliveries,
      ),
    ),
  ),
);

class _ProductFinanceDashboard extends StatefulWidget {
  const _ProductFinanceDashboard({
    required this.products,
    required this.deliveries,
  });
  final List<Product> products;
  final List<Delivery> deliveries;
  @override
  State<_ProductFinanceDashboard> createState() =>
      _ProductFinanceDashboardState();
}

class _ProductFinanceDashboardState extends State<_ProductFinanceDashboard> {
  String _period = 'Все время';
  String _deliveryId = '';
  DateTimeRange? _custom;

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _custom,
    );
    if (picked != null && mounted) setState(() => _custom = picked);
  }

  @override
  Widget build(BuildContext context) {
    final report = _ProductFinanceReport.build(
      widget.products,
      widget.deliveries,
      period: _period,
      deliveryId: _deliveryId,
      custom: _custom,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF171B26) : Colors.white;
    final border = dark ? const Color(0xFF30394B) : const Color(0xFFE2E7F0);
    final muted = dark ? const Color(0xFFAAB4C7) : const Color(0xFF657084);
    return Column(
      children: [
        _Header(
          report: report,
          period: _period,
          deliveryId: _deliveryId,
          deliveries: widget.deliveries,
          custom: _custom,
          onPeriod: (value) => setState(() => _period = value),
          onDelivery: (value) => setState(() => _deliveryId = value),
          onCustom: _selectRange,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricGrid(report: report, surface: surface, border: border),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    final trend = _Panel(
                      title: 'Продажи и валовая прибыль',
                      subtitle: 'Динамика по датам продажи',
                      icon: Icons.show_chart_rounded,
                      surface: surface,
                      border: border,
                      child: _SalesChart(points: report.points, muted: muted),
                    );
                    final status = _Panel(
                      title: 'Состояние ассортимента',
                      subtitle:
                          'Количество товаров и единиц по текущим статусам',
                      icon: Icons.inventory_2_outlined,
                      surface: surface,
                      border: border,
                      child: _StatusSummary(report: report, muted: muted),
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: trend),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: status),
                            ],
                          )
                        : Column(
                            children: [
                              trend,
                              const SizedBox(height: 14),
                              status,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Окупаемость поставок',
                  subtitle:
                      'Закупка, выручка, валовая прибыль и остаток по каждой поставке',
                  icon: Icons.local_shipping_outlined,
                  surface: surface,
                  border: border,
                  child: _DeliveryPerformance(
                    rows: report.deliveries,
                    muted: muted,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    final best = _Panel(
                      title: 'Проданные товары',
                      subtitle: 'Самые доходные позиции выбранного периода',
                      icon: Icons.sell_outlined,
                      surface: surface,
                      border: border,
                      child: _SalesList(items: report.sold, muted: muted),
                    );
                    final movements = _Panel(
                      title: 'Движение товара',
                      subtitle:
                          'Поступления, продажи, отправки, возвраты и смены статусов',
                      icon: Icons.history_rounded,
                      surface: surface,
                      border: border,
                      child: _ProductMovements(
                        items: report.movements,
                        muted: muted,
                      ),
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: best),
                              const SizedBox(width: 14),
                              Expanded(child: movements),
                            ],
                          )
                        : Column(
                            children: [
                              best,
                              const SizedBox(height: 14),
                              movements,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.report,
    required this.period,
    required this.deliveryId,
    required this.deliveries,
    required this.custom,
    required this.onPeriod,
    required this.onDelivery,
    required this.onCustom,
    required this.onClose,
  });
  final _ProductFinanceReport report;
  final String period, deliveryId;
  final List<Delivery> deliveries;
  final DateTimeRange? custom;
  final ValueChanged<String> onPeriod, onDelivery;
  final VoidCallback onCustom, onClose;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 17, 16, 16),
    decoration: const BoxDecoration(color: Color(0xFF253B78)),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бухгалтерия товаров',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Финансовый результат по ассортименту, а не по услугам',
                    style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 12),
                  ),
                ],
              ),
            ),
            _HeadPill(
              label: 'Маржа ${report.margin.toStringAsFixed(1)}%',
              color: report.margin >= 0
                  ? const Color(0xFF46D69A)
                  : const Color(0xFFFF9A9A),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              tooltip: 'Закрыть',
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const ['Все время', '30 дней', '90 дней'])
              ChoiceChip(
                label: Text(option),
                selected: period == option,
                onSelected: (_) => onPeriod(option),
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                  color: period == option
                      ? const Color(0xFF2534A0)
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: Colors.white.withValues(alpha: .3)),
              ),
            OutlinedButton.icon(
              onPressed: onCustom,
              icon: const Icon(Icons.date_range, size: 17),
              label: Text(
                custom == null
                    ? 'Период'
                    : '${_date(custom!.start)} - ${_date(custom!.end)}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .4)),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: deliveryId,
                dropdownColor: const Color(0xFF28336B),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Все поставки'),
                  ),
                  ...deliveries.map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '#${d.number} ${d.name.isEmpty ? 'Поставка' : d.name}',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => onDelivery(value ?? ''),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeadPill extends StatelessWidget {
  const _HeadPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.report,
    required this.surface,
    required this.border,
  });
  final _ProductFinanceReport report;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth > 930
          ? 4
          : constraints.maxWidth > 570
          ? 2
          : 1;
      final cards =
          <
            ({
              String title,
              String value,
              String detail,
              IconData icon,
              Color color,
            })
          >[
            (
              title: 'Выручка товаров',
              value: _money(report.sales),
              detail: '${report.sold.length} продано',
              icon: Icons.payments_outlined,
              color: const Color(0xFF159B6B),
            ),
            (
              title: 'Себестоимость',
              value: _money(report.cost),
              detail: 'проданные позиции',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFE05263),
            ),
            (
              title: 'Валовая прибыль',
              value: _money(report.grossProfit),
              detail: 'маржа ${report.margin.toStringAsFixed(1)}%',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF276EF1),
            ),
            (
              title: 'Остаток на складе',
              value: _money(report.inventoryCost),
              detail:
                  '${_qty(report.inStockUnits)} ед. · ${report.inStockCount} поз.',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF8858D9),
            ),
          ];
      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: count == 1 ? 3 : 2.25,
        children: cards
            .map(
              (card) => Container(
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
                            card.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: card.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(card.icon, size: 18, color: card.color),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
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
            Icon(icon, color: const Color(0xFF276EF1), size: 19),
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
        const SizedBox(height: 15),
        child,
      ],
    ),
  );
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points, required this.muted});
  final List<_SalesPoint> points;
  final Color muted;
  @override
  Widget build(BuildContext context) => points.isEmpty
      ? _Empty(label: 'За выбранный период нет продаж', muted: muted)
      : SizedBox(
          height: 176,
          child: CustomPaint(
            painter: _SalesPainter(points, muted),
            child: const SizedBox.expand(),
          ),
        );
}

class _SalesPainter extends CustomPainter {
  _SalesPainter(this.points, this.muted);
  final List<_SalesPoint> points;
  final Color muted;
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromLTWH(4, 6, s.width - 8, s.height - 25);
    final maxV = math.max(
      1,
      points.fold<double>(0, (v, p) => math.max(v, p.sales)),
    );
    final grid = Paint()..color = muted.withValues(alpha: .16);
    for (var i = 0; i < 4; i++) {
      final y = rect.top + rect.height * i / 3;
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    final step = points.length == 1 ? rect.width : rect.width / points.length;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final h = p.sales / maxV * rect.height;
      final left = rect.left + i * step + step * .17;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, rect.bottom - h, step * .42, h),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF276EF1),
      );
      final gh = p.profit / maxV * rect.height;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + step * .46, rect.bottom - gh, step * .22, gh),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF46D69A),
      );
    }
    final t = TextPainter(textDirection: TextDirection.ltr);
    t.text = TextSpan(
      text: 'Синий — выручка   Зелёный — валовая прибыль',
      style: TextStyle(fontSize: 10, color: muted),
    );
    t.layout();
    t.paint(c, Offset(5, s.height - 15));
  }

  @override
  bool shouldRepaint(covariant _SalesPainter old) => old.points != points;
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.report, required this.muted});
  final _ProductFinanceReport report;
  final Color muted;
  @override
  Widget build(BuildContext context) {
    final data = [
      ('В наличии', report.inStockUnits, const Color(0xFF276EF1)),
      ('Отправлено', report.shippedUnits, const Color(0xFFF08A24)),
      ('Возвраты', report.returnedUnits, const Color(0xFF8858D9)),
      ('Продано', report.soldUnits, const Color(0xFF159B6B)),
    ];
    final total = math.max(1, data.fold<double>(0, (s, x) => s + x.$2));
    return Column(
      children: [
        ...data.map(
          (x) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        x.$1,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    Text(
                      _qty(x.$2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: x.$2 / total,
                    minHeight: 7,
                    color: x.$3,
                    backgroundColor: x.$3.withValues(alpha: .14),
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

class _DeliveryPerformance extends StatelessWidget {
  const _DeliveryPerformance({required this.rows, required this.muted});
  final List<_DeliveryMetric> rows;
  final Color muted;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _Empty(label: 'Нет поставок по выбранному фильтру', muted: muted);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: TextStyle(
          fontSize: 12,
          color: muted,
          fontWeight: FontWeight.w800,
        ),
        columns: const [
          DataColumn(label: Text('Поставка')),
          DataColumn(label: Text('Закупка'), numeric: true),
          DataColumn(label: Text('Выручка'), numeric: true),
          DataColumn(label: Text('Прибыль'), numeric: true),
          DataColumn(label: Text('Окупаемость'), numeric: true),
          DataColumn(label: Text('Остаток'), numeric: true),
        ],
        rows: rows
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      '#${r.delivery.number} ${r.delivery.name.isEmpty ? 'Поставка' : r.delivery.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(_money(r.cost))),
                  DataCell(Text(_money(r.sales))),
                  DataCell(
                    Text(
                      _money(r.profit),
                      style: TextStyle(
                        color: r.profit >= 0
                            ? const Color(0xFF159B6B)
                            : const Color(0xFFE05263),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DataCell(Text('${r.payback.toStringAsFixed(0)}%')),
                  DataCell(
                    Text('${_qty(r.leftUnits)} · ${_money(r.leftCost)}'),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.items, required this.muted});
  final List<Product> items;
  final Color muted;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Empty(label: 'Продаж за выбранный период нет', muted: muted);
    }
    return Column(
      children: items
          .take(8)
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: const Color(0xFF159B6B).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF159B6B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.sku.isEmpty ? 'Без арт.' : p.sku} · ${p.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Себестоимость ${_money(_cost(p))}',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(_sale(p)),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProductMovements extends StatefulWidget {
  const _ProductMovements({required this.items, required this.muted});
  final List<_ProductMove> items;
  final Color muted;
  @override
  State<_ProductMovements> createState() => _ProductMovementsState();
}

class _ProductMovementsState extends State<_ProductMovements> {
  var all = false;
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _Empty(
        label: 'Нет сохранённой истории изменений',
        muted: widget.muted,
      );
    }
    final items = all ? widget.items : widget.items.take(8).toList();
    return Column(
      children: [
        ...items.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Icon(_moveIcon(m.kind), size: 17, color: _moveColor(m.kind)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${m.kind} · ${m.date}',
                        style: TextStyle(fontSize: 11, color: widget.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  m.quantity == 0 ? '' : _qty(m.quantity),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
              onPressed: () => setState(() => all = !all),
              icon: Icon(all ? Icons.expand_less : Icons.expand_more),
              label: Text(
                all
                    ? 'Свернуть историю'
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
    height: 110,
    child: Center(
      child: Text(label, style: TextStyle(fontSize: 12, color: muted)),
    ),
  );
}

class _ProductFinanceReport {
  _ProductFinanceReport({
    required this.sales,
    required this.cost,
    required this.inventoryCost,
    required this.inStockUnits,
    required this.inStockCount,
    required this.sold,
    required this.points,
    required this.deliveries,
    required this.movements,
    required this.inStockUnitsByStatus,
    required this.shippedUnits,
    required this.returnedUnits,
    required this.soldUnits,
  });
  final double sales,
      cost,
      inventoryCost,
      inStockUnits,
      shippedUnits,
      returnedUnits,
      soldUnits,
      inStockUnitsByStatus;
  final int inStockCount;
  final List<Product> sold;
  final List<_SalesPoint> points;
  final List<_DeliveryMetric> deliveries;
  final List<_ProductMove> movements;
  double get grossProfit => sales - cost;
  double get margin => sales == 0 ? 0 : grossProfit / sales * 100;
  factory _ProductFinanceReport.build(
    List<Product> products,
    List<Delivery> deliveries, {
    required String period,
    required String deliveryId,
    required DateTimeRange? custom,
  }) {
    final now = DateTime.now();
    DateTime? from;
    if (custom != null) {
      from = custom.start;
    } else if (period == '30 дней') {
      from = now.subtract(const Duration(days: 30));
    } else if (period == '90 дней') {
      from = now.subtract(const Duration(days: 90));
    }
    bool chosen(Product p) => deliveryId.isEmpty || p.deliveryId == deliveryId;
    bool inPeriod(DateTime? date) =>
        from == null ||
        (date != null &&
            !date.isBefore(from) &&
            (custom == null ||
                !date.isAfter(custom.end.add(const Duration(days: 1)))));
    final filtered = products.where(chosen).toList();
    final sold =
        filtered
            .where((p) => p.sold || p.status == 'sold')
            .where((p) => inPeriod(_soldDate(p)))
            .toList()
          ..sort((a, b) => _sale(b).compareTo(_sale(a)));
    final byDate = <String, _SalesPoint>{};
    for (final p in sold) {
      final d = _soldDate(p);
      final key = d == null ? 'Без даты' : _date(d);
      final old = byDate[key] ?? _SalesPoint(key, 0, 0);
      byDate[key] = _SalesPoint(
        key,
        old.sales + _sale(p),
        old.profit + _sale(p) - _lineCost(p),
      );
    }
    final metrics = <_DeliveryMetric>[];
    for (final d in deliveries.where(
      (d) => deliveryId.isEmpty || d.id == deliveryId,
    )) {
      final ps = filtered.where((p) => p.deliveryId == d.id).toList();
      final sale = ps
          .where((p) => p.sold || p.status == 'sold')
          .fold<double>(0, (s, p) => s + _sale(p));
      final left = ps.where((p) => p.status == 'in_stock' && !p.sold).toList();
      final leftCost = left.fold<double>(
        0,
        (s, p) => s + _cost(p) * p.quantity,
      );
      metrics.add(
        _DeliveryMetric(
          d,
          d.totalCost,
          sale,
          left.fold<double>(0, (s, p) => s + p.quantity),
          leftCost,
        ),
      );
    }
    metrics.sort((a, b) => b.sales.compareTo(a.sales));
    final moves = <_ProductMove>[];
    for (final p in filtered) {
      for (final event in p.statusEvents) {
        final at = DateTime.tryParse(event.at);
        if (inPeriod(at)) {
          moves.add(
            _ProductMove(
              product: '${p.sku.isEmpty ? 'Без арт.' : p.sku} · ${p.name}',
              kind: _statusLabel(event.status),
              date: event.at.replaceFirst('T', ' ').split('.').first,
              quantity: event.quantity,
              at: at,
            ),
          );
        }
      }
      if ((p.sold || p.status == 'sold') &&
          p.statusEvents.where((e) => e.status == 'sold').isEmpty) {
        final at = _soldDate(p);
        if (inPeriod(at)) {
          moves.add(
            _ProductMove(
              product: '${p.sku.isEmpty ? 'Без арт.' : p.sku} · ${p.name}',
              kind: 'Продано',
              date: at == null ? 'Дата не указана' : _date(at),
              quantity: p.quantity,
              at: at,
            ),
          );
        }
      }
    }
    moves.sort(
      (a, b) => (b.at ?? DateTime(1900)).compareTo(a.at ?? DateTime(1900)),
    );
    double units(String status) => filtered
        .where((p) => p.status == status && !p.sold)
        .fold<double>(0, (s, p) => s + p.quantity);
    final inventory = filtered
        .where((p) => p.status == 'in_stock' && !p.sold)
        .toList();
    return _ProductFinanceReport(
      sales: sold.fold<double>(0, (s, p) => s + _sale(p)),
      cost: sold.fold<double>(0, (s, p) => s + _lineCost(p)),
      inventoryCost: inventory.fold<double>(
        0,
        (s, p) => s + _cost(p) * p.quantity,
      ),
      inStockUnits: inventory.fold<double>(0, (s, p) => s + p.quantity),
      inStockCount: inventory.length,
      sold: sold,
      points: byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date)),
      deliveries: metrics,
      movements: moves,
      inStockUnitsByStatus: units('in_stock'),
      shippedUnits: units('shipped'),
      returnedUnits: units('returned'),
      soldUnits: sold.fold<double>(0, (s, p) => s + p.quantity),
    );
  }
}

class _SalesPoint {
  const _SalesPoint(this.date, this.sales, this.profit);
  final String date;
  final double sales, profit;
}

class _DeliveryMetric {
  const _DeliveryMetric(
    this.delivery,
    this.cost,
    this.sales,
    this.leftUnits,
    this.leftCost,
  );
  final Delivery delivery;
  final double cost, sales, leftUnits, leftCost;
  double get profit => sales - cost;
  double get payback => cost <= 0 ? (sales > 0 ? 100 : 0) : sales / cost * 100;
}

class _ProductMove {
  const _ProductMove({
    required this.product,
    required this.kind,
    required this.date,
    required this.quantity,
    required this.at,
  });
  final String product, kind, date;
  final double quantity;
  final DateTime? at;
}

DateTime? _soldDate(Product p) => p.soldTimestamp > 0
    ? DateTime.fromMillisecondsSinceEpoch(p.soldTimestamp)
    : null;
double _cost(Product p) => p.costPrice ?? p.purchasePrice;
double _lineCost(Product p) => _cost(p) * p.quantity;
double _sale(Product p) =>
    (p.salePrice > 0 ? p.salePrice : p.myPrice) * p.quantity;
String _money(double v) {
  final n = v.round();
  final s = n < 0 ? '-' : '';
  final raw = n.abs().toString();
  final groups = <String>[];
  for (var end = raw.length; end > 0; end -= 3) {
    groups.add(raw.substring(math.max(0, end - 3), end));
  }
  return '$s${groups.reversed.join(' ')} ₽';
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String _statusLabel(String status) => switch (status) {
  'sold' => 'Продано',
  'shipped' => 'Отправлено',
  'returned' => 'Возврат',
  'in_stock' => 'Поступление',
  _ => status,
};
IconData _moveIcon(String kind) => kind == 'Продано'
    ? Icons.sell_outlined
    : kind == 'Отправлено'
    ? Icons.local_shipping_outlined
    : kind == 'Возврат'
    ? Icons.assignment_return_outlined
    : Icons.inventory_2_outlined;
Color _moveColor(String kind) => kind == 'Продано'
    ? const Color(0xFF159B6B)
    : kind == 'Отправлено'
    ? const Color(0xFFF08A24)
    : kind == 'Возврат'
    ? const Color(0xFF8858D9)
    : const Color(0xFF276EF1);
