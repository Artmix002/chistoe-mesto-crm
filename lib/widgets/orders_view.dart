import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

class OrdersView extends StatefulWidget {
  const OrdersView({
    super.key,
    required this.orders,
    required this.lastAvitoSync,
    required this.onClose,
    required this.onLoadAvito,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onChanged,
    this.onLinkProduct,
    this.productUrlFor,
  });

  final List<Order> orders;
  final int lastAvitoSync;
  final VoidCallback onClose;
  final Future<int> Function() onLoadAvito;
  final Future<Order?> Function() onCreate;
  final Future<Order?> Function(Order order) onEdit;
  final Future<void> Function(Order order) onDelete;
  final VoidCallback onChanged;
  final Future<void> Function(Order order)? onLinkProduct;
  /// Ссылка на объявление товара, связанного с заказом (если есть).
  final String Function(Order order)? productUrlFor;

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  String status = 'action';
  String sort = 'number';
  String query = '';
  late int lastSyncAt = widget.lastAvitoSync;

  static const _statusTitles = {
    'all': 'Все',
    'active': 'Активные',
    'action': 'Действие',
    'shipped': 'В доставке',
    'returned': 'Возвраты',
    'done': 'Завершены',
    'canceled': 'Отменены',
  };

  String _lastSyncLabel(int milliseconds) {
    if (milliseconds <= 0) return 'Авито ещё не синхронизировался';
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Обновлено с Авито: ${two(value.day)}.${two(value.month)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Color _statusColor(String value) => switch (value) {
    'new' => const Color(0xFF2563EB),
    'paid' => const Color(0xFF16A34A),
    'shipped' => const Color(0xFFEA580C),
    'done' => const Color(0xFF475569),
    'returned' => const Color(0xFF9333EA),
    'canceled' => const Color(0xFFDC2626),
    _ => const Color(0xFF64748B),
  };

  String _statusLabel(Order order) {
    if (order.avitoStatus.isNotEmpty) return order.avitoStatus;
    return switch (order.status) {
      'paid' => 'Оплачен',
      'shipped' => 'Отправлен',
      'done' => 'Выполнен',
      'returned' => 'Возврат',
      'canceled' => 'Отменён',
      _ => 'Новый',
    };
  }

  bool _requiresAction(Order order) {
    final text = order.avitoStatus.toLowerCase();
    if (text.contains('закрыт после возврата')) return false;
    if (text.contains('отменён')) return false;
    return order.status == 'new' ||
        text.contains('заберите') ||
        text.contains('отправьте') ||
        text.contains('подтвердите') ||
        text.contains('ждёт отправки') ||
        text.contains('ожидает подтверждения');
  }

  bool _isClosedReturn(Order order) {
    final text = order.avitoStatus.toLowerCase();
    return text.contains('закрыт после возврата');
  }

  bool _isReturn(Order order) =>
      order.status == 'returned' && !_isClosedReturn(order);

  bool _isInDelivery(Order order) {
    if (_isClosedReturn(order)) return false;
    if (order.status != 'shipped') return false;
    return !order.avitoStatus.toLowerCase().contains('возврат');
  }

  bool _isActive(Order order) {
    if (_isClosedReturn(order)) return false;
    if (order.status == 'new' || order.status == 'shipped') return true;
    return _isReturn(order);
  }

  double get _inDeliverySum => widget.orders
      .where(_isInDelivery)
      .fold<double>(0, (sum, order) => sum + order.amount);

  int get _activeCount => widget.orders.where(_isActive).length;

  int get _returnsCount => widget.orders.where(_isReturn).length;

  List<Order> get _filtered {
    final text = query.trim().toLowerCase();
    final list = widget.orders.where((order) {
      if (status == 'action') {
        if (!_requiresAction(order)) return false;
      } else if (status == 'active') {
        if (!_isActive(order)) return false;
      } else if (status == 'returned') {
        if (!_isReturn(order)) return false;
      } else if (status != 'all' && order.status != status) {
        return false;
      }
      if (text.isEmpty) return true;
      return order.product.toLowerCase().contains(text) ||
          order.customer.toLowerCase().contains(text) ||
          order.article.toLowerCase().contains(text) ||
          order.barcode.toLowerCase().contains(text) ||
          '${order.number}'.contains(text);
    }).toList();
    switch (sort) {
      case 'amount':
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case 'date':
        list.sort((a, b) => b.date.compareTo(a.date));
      default:
        list.sort((a, b) => b.number.compareTo(a.number));
    }
    return list;
  }

  double get _totalSum =>
      _filtered.fold<double>(0, (sum, order) => sum + order.amount);

  int _count(String value) {
    if (value == 'all') return widget.orders.length;
    if (value == 'action') {
      return widget.orders.where(_requiresAction).length;
    }
    if (value == 'active') return _activeCount;
    if (value == 'returned') return _returnsCount;
    return widget.orders.where((order) => order.status == value).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF171A21) : Colors.white;
    final background =
        dark ? const Color(0xFF0F1117) : const Color(0xFFF4F6FB);
    final border = dark ? const Color(0xFF2A2F3A) : const Color(0xFFE4E8F0);
    final muted = dark ? const Color(0xFF9BA3B4) : const Color(0xFF64748B);
    final list = _filtered;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1120,
        height: 780,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(theme, muted),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    _filters(dark, surface, border, muted),
                    const SizedBox(height: 14),
                    Expanded(
                      child: list.isEmpty
                          ? _empty(muted)
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _orderCard(list[index], dark, surface, border, muted),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, Color muted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Заказы',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Text(
                    'Все продажи и доставки в одном месте',
                    style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 12),
                  ),
                  Text(
                    _lastSyncLabel(lastSyncAt),
                    style: const TextStyle(
                      color: Color(0xFFA5B4FC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final syncedAt = await widget.onLoadAvito();
                  if (mounted && syncedAt > 0) {
                    setState(() => lastSyncAt = syncedAt);
                  } else {
                    setState(() {});
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Загрузить из Авито'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  final order = await widget.onCreate();
                  if (order == null) return;
                  widget.onChanged();
                  setState(() {});
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Новый заказ'),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat(
                'Всего заказов',
                '${widget.orders.length}',
                Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 10),
              _stat(
                'Активные',
                '$_activeCount',
                Icons.local_shipping_outlined,
              ),
              const SizedBox(width: 10),
              _stat(
                'В доставке',
                '${_inDeliverySum.toStringAsFixed(0)} ₽',
                Icons.payments_outlined,
              ),
              const SizedBox(width: 10),
              _stat(
                'Возвраты',
                '$_returnsCount',
                Icons.keyboard_return,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC7D2FE), size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(bool dark, Color surface, Color border, Color muted) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in _statusTitles.entries) ...[
                      _statusChip(entry.key, entry.value, dark, border),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 250,
              height: 42,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск по заказу, товару…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Сортировка',
              icon: const Icon(Icons.sort),
              initialValue: sort,
              onSelected: (value) => setState(() => sort = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'number', child: Text('Сначала новые')),
                PopupMenuItem(value: 'amount', child: Text('По сумме')),
                PopupMenuItem(value: 'date', child: Text('По дате')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String value, String title, bool dark, Color border) {
    final selected = status == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4338CA)
              : (dark ? const Color(0xFF1F2430) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF4338CA) : border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : null,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : border,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_count(value)}',
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(
    Order order,
    bool dark,
    Color surface,
    Color border,
    Color muted,
  ) {
    final color = _statusColor(order.status);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final updated = await widget.onEdit(order);
          if (updated == null) return;
          widget.onChanged();
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 74,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(order),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${order.number}',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      order.product.isEmpty
                          ? 'Заказ без названия'
                          : order.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (order.article.isNotEmpty)
                          if (order.article.isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: widget.onLinkProduct == null
                                  ? null
                                  : () async {
                                      await widget.onLinkProduct!(order);
                                      if (mounted) setState(() {});
                                    },
                              child: _meta(
                                Icons.qr_code_2,
                                'арт. ${order.article}',
                                muted,
                              ),
                            )
                          else
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: widget.onLinkProduct == null
                                  ? null
                                  : () async {
                                      await widget.onLinkProduct!(order);
                                      if (mounted) setState(() {});
                                    },
                              child: _meta(
                                Icons.link_off,
                                'не связан — связать',
                                const Color(0xFFB45309),
                              ),
                            ),
                        if (order.customer.isNotEmpty)
                          _meta(Icons.person_outline, order.customer, muted),
                        if (order.phone.isNotEmpty)
                          _meta(Icons.phone_outlined, order.phone, muted),
                        _meta(
                          Icons.inventory_outlined,
                          '${order.quantity.toStringAsFixed(0)} шт',
                          muted,
                        ),
                        _meta(Icons.event_outlined, order.date, muted),
                      ],
                    ),
                    if (order.avitoStatus.isNotEmpty ||
                        order.barcode.isNotEmpty ||
                        order.pvz.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (order.avitoStatus.isNotEmpty)
                            _meta(
                              Icons.local_shipping_outlined,
                              [
                                order.avitoStatus,
                                if (order.avitoDeadline.isNotEmpty)
                                  order.avitoDeadline
                                      .replaceFirst('До ', 'до '),
                              ].join(' '),
                              const Color(0xFFB45309),
                            ),
                          if (order.barcode.isNotEmpty)
                            _barcodeChip(order.barcode),
                          if (order.pvz.isNotEmpty)
                            _meta(Icons.place_outlined, order.pvz, muted),
                          if ((widget.productUrlFor?.call(order) ?? '')
                              .isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => launchUrl(
                                Uri.parse(widget.productUrlFor!(order)),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: _meta(
                                Icons.open_in_new,
                                'объявление',
                                const Color(0xFF2563EB),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.amount.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Изменить',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final updated = await widget.onEdit(order);
                          if (updated == null) return;
                          widget.onChanged();
                          setState(() {});
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await widget.onDelete(order);
                          widget.onChanged();
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Штрихкод для отправки: крупно, моноширинно, с копированием.
  Widget _barcodeChip(String code) {
    return Tooltip(
      message: 'Нажмите, чтобы скопировать штрихкод',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Штрихкод $code скопирован')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy, size: 13, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _empty(Color muted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 54, color: muted),
          const SizedBox(height: 10),
          Text(
            query.isEmpty && status == 'all'
                ? 'Заказов пока нет'
                : 'Ничего не найдено',
            style: TextStyle(color: muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
