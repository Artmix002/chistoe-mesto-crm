import 'dart:async';

import 'package:flutter/material.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cached_photo.dart';
import '../models.dart';
import '../avito_catalog.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({
    super.key,
    required this.items,
    required this.deliveries,
    required this.selectedDeliveryId,
    required this.draft,
    required this.canEdit,
    required this.onSelectDelivery,
    required this.onNewDelivery,
    required this.onEditDelivery,
    required this.onDeleteDelivery,
    this.onStatusChanged,
    this.onAvitoSync,
    this.onAvitoSettings,
    this.onAvitoCatalog,
    this.onAvitoStats,
    this.onAvitoPrices,
    this.onOrders,
    this.activeOrdersCount = 0,
    this.onExportExcel,
    this.onImportExcel,
    this.onImportAvito,
    this.onBulkUpdate,
    this.onSale,
    this.onSalePriceChanged,
    required this.onStartProduct,
    required this.onSaveProduct,
    required this.onDeleteProduct,
    required this.onCloseDraft,
    required this.onEditProduct,
    this.mediaBaseUrl = '',
    this.onUploadPhotos,
    this.feedSkus = const {},
    this.feedSkusLoaded = false,
    this.catalog,
    this.catalogLoaded = false,
  });

  final List<Product> items;
  final List<Delivery> deliveries;
  final String selectedDeliveryId;
  final Product? draft;
  final bool canEdit;
  final ValueChanged<String> onSelectDelivery;
  final VoidCallback onNewDelivery;
  final ValueChanged<Delivery> onEditDelivery;
  final Future<void> Function(Delivery) onDeleteDelivery;
  final void Function(Product product, String status)? onStatusChanged;
  final Future<void> Function()? onAvitoSync;
  final Future<void> Function()? onAvitoSettings;
  final Future<void> Function()? onAvitoCatalog;
  final Future<void> Function()? onAvitoStats;
  final Future<void> Function()? onAvitoPrices;
  final Future<void> Function()? onOrders;
  final int activeOrdersCount;
  final Future<void> Function()? onExportExcel;
  final Future<void> Function()? onImportExcel;
  final Future<void> Function()? onImportAvito;
  final Future<void> Function(List<Product> products,
      {String? status, String? deliveryId, String? category})? onBulkUpdate;
  final Future<void> Function(List<Product> products, double percent)? onSale;
  final Future<void> Function(Product product, double price)? onSalePriceChanged;
  final VoidCallback onStartProduct;
  final ValueChanged<Product> onSaveProduct;
  final Future<void> Function(Product) onDeleteProduct;
  final VoidCallback onCloseDraft;
  final ValueChanged<Product> onEditProduct;
  final String mediaBaseUrl;
  final Future<List<String>> Function(List<XFile> files)? onUploadPhotos;
  // SKU товаров, которые есть в фиде автозагрузки Авито. Значок «на Авито»
  // в карточке товара строится по этому списку.
  final Set<String> feedSkus;
  final bool feedSkusLoaded;
  // Справочник категорий Авито для формы товара (обязательные параметры).
  final AvitoCatalogData? catalog;
  final bool catalogLoaded;

  Widget _headerStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFC7D2FE)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolbarMenu(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 16, color: color),
        ],
      ),
    );
  }

  double _percent(Delivery delivery) {
    final revenue = items
        .where((p) => p.deliveryId == delivery.id && p.sold)
        .fold<double>(0, (sum, p) => sum + p.salePrice * p.quantity);
    if (delivery.totalCost <= 0) return revenue > 0 ? 100 : 0;
    return revenue / delivery.totalCost * 100;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    final delivery = deliveries
        .cast<Delivery?>()
        .firstWhere((d) => d?.id == selectedDeliveryId, orElse: () => null);
    final visible = items
        .where((p) => selectedDeliveryId.isEmpty || p.deliveryId == selectedDeliveryId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final totalAmount =
        items.fold<double>(0, (sum, product) => sum + product.amount);
    final soldCount = items.where((product) => product.sold).length;
    final inStock = items.where((product) => product.status == 'in_stock').length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x221E3A8A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Wrap(
            spacing: 22,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Товары',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '${items.length} позиций · ${_fmtMoney(totalAmount)} ₽',
                    style: const TextStyle(
                      color: Color(0xFFC7D2FE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              _headerStat('В наличии', '$inStock', Icons.inventory_2_outlined),
              _headerStat('Продано', '$soldCount', Icons.check_circle_outline),
              _headerStat(
                'Поставок',
                '${deliveries.length}',
                Icons.local_shipping_outlined,
              ),
              if (canEdit)
                FilledButton.icon(
                  onPressed: onStartProduct,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Товар'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              const Text(
                'Поставки',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                'нажмите на поставку для деталей',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _DeliveryBubble(
                label: 'Все',
                percent: null,
                selected: selectedDeliveryId.isEmpty,
                onTap: () => onSelectDelivery(''),
              ),
              for (final d in deliveries)
                _DeliveryBubble(
                  label: '#${d.number} ${d.name}',
                  percent: _percent(d),
                  selected: selectedDeliveryId == d.id,
                  onTap: () => _showDeliveryDetails(
                    context,
                    d,
                    items,
                    onSelectDelivery,
                    onEditDelivery,
                    onDeleteDelivery,
                    onSalePriceChanged,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onOrders != null)
              Badge(
                isLabelVisible: activeOrdersCount > 0,
                label: Text('$activeOrdersCount'),
                child: FilledButton.tonalIcon(
                  onPressed: onOrders,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Заказы'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: onNewDelivery,
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Поставка'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Авито',
              onSelected: (value) {
                if (value == 'sync') {
                  unawaited(
                    (onAvitoSync ?? () async => _showAvitoSync(context))(),
                  );
                } else if (value == 'stats') {
                  final callback = onAvitoStats;
                  if (callback != null) unawaited(callback());
                } else if (value == 'prices') {
                  final callback = onAvitoPrices;
                  if (callback != null) unawaited(callback());
                } else if (value == 'settings') {
                  final callback = onAvitoSettings;
                  if (callback != null) unawaited(callback());
                } else if (value == 'catalog') {
                  final callback = onAvitoCatalog;
                  if (callback != null) unawaited(callback());
                } else if (value == 'import') {
                  final callback = onImportAvito;
                  if (callback != null) unawaited(callback());
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.sync, size: 20),
                    title: Text('Синхронизировать'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (onAvitoStats != null)
                  const PopupMenuItem(
                    value: 'stats',
                    child: ListTile(
                      leading: Icon(Icons.insights_outlined, size: 20),
                      title: Text('Статистика'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onAvitoPrices != null)
                  const PopupMenuItem(
                    value: 'prices',
                    child: ListTile(
                      leading: Icon(Icons.sell_outlined, size: 20),
                      title: Text('Реальные цены'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onAvitoSettings != null)
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined, size: 20),
                      title: Text('Настройки Авито'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onAvitoCatalog != null)
                  const PopupMenuItem(
                    value: 'catalog',
                    child: ListTile(
                      leading: Icon(Icons.category_outlined, size: 20),
                      title: Text('Параметры категорий Авито'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onImportAvito != null)
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.table_view_outlined, size: 20),
                      title: Text('Импорт выгрузки Авито'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
              child: _toolbarMenu(
                'Авито',
                Icons.cloud_outlined,
                const Color(0xFF7C3AED),
              ),
            ),
            if (canEdit && (onImportExcel != null || onExportExcel != null))
              PopupMenuButton<String>(
                tooltip: 'Excel',
                onSelected: (value) {
                  if (value == 'import') onImportExcel?.call();
                  if (value == 'export') onExportExcel?.call();
                },
                itemBuilder: (_) => [
                  if (onImportExcel != null)
                    const PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        leading: Icon(Icons.upload_file_outlined, size: 20),
                        title: Text('Импорт товаров'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (onExportExcel != null)
                    const PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.download_outlined, size: 20),
                        title: Text('Экспорт товаров'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
                child: _toolbarMenu(
                  'Excel',
                  Icons.grid_on_outlined,
                  const Color(0xFF16A34A),
                ),
              ),
            TextButton.icon(
              onPressed: () => _showAccounting(context, items, deliveries),
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: const Text('Бухгалтерия'),
            ),
            if (canEdit && delivery != null) ...[
              IconButton(
                tooltip: 'Изменить поставку',
                onPressed: () => onEditDelivery(delivery),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Удалить поставку',
                onPressed: () => onDeleteDelivery(delivery!),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        if (delivery != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                'Стоимость поставки: ${_fmtMoney(delivery.totalCost)} ₽',
                'Выручка: ${_fmtMoney(_revenue(items, delivery))} ₽',
                'Прибыль: ${_fmtMoney(_revenue(items, delivery) - delivery.totalCost)} ₽',
                'Товаров: ${items.where((p) => p.deliveryId == delivery.id).length}',
                if (delivery.supplier.isNotEmpty) delivery.supplier,
                if (delivery.date.isNotEmpty) delivery.date,
                if (delivery.comment.isNotEmpty) delivery.comment,
              ].join(' · '),
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        _ProductCatalog(
          items: items,
          deliveries: deliveries,
          selectedDeliveryId: selectedDeliveryId,
          mediaBaseUrl: mediaBaseUrl,
          canEdit: canEdit,
          onStatusChanged: onStatusChanged,
          onEditProduct: onEditProduct,
          onDeleteProduct: onDeleteProduct,
          onBulkUpdate: onBulkUpdate,
          onSale: onSale,
          feedSkus: feedSkus,
          feedSkusLoaded: feedSkusLoaded,
        ),
      ],
    );
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';
  static String _money(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

  double _revenue(List<Product> items, Delivery delivery) => items
      .where((p) => p.deliveryId == delivery.id && p.sold)
      .fold<double>(0, (sum, p) => sum + p.salePrice * p.quantity);

  void _showAccounting(
    BuildContext context,
    List<Product> items,
    List<Delivery> deliveries,
  ) {
    var totalCost = 0.0;
    var totalRevenue = 0.0;
    final rows = <DataRow>[];
    for (final d in deliveries) {
      final products = items.where((p) => p.deliveryId == d.id).toList();
      final revenue = _revenue(items, d);
      final sold = products.where((p) => p.sold).length;
      final inStock = products
          .where((p) => p.status == 'in_stock')
          .fold<double>(0, (s, p) => s + p.quantity);
      final shipped = products
          .where((p) => p.status == 'shipped')
          .fold<double>(0, (s, p) => s + p.quantity);
      final returned = products
          .where((p) => p.status == 'returned')
          .fold<double>(0, (s, p) => s + p.quantity);
      final remainingValue = products
          .where((p) => p.status == 'in_stock')
          .fold<double>(0, (s, p) => s + (p.costPrice ?? 0) * p.quantity);
      totalCost += d.totalCost;
      totalRevenue += revenue;
      rows.add(DataRow(cells: [
        DataCell(Text('#${d.number}')),
        DataCell(Text(d.name)),
        DataCell(Text('${_fmtMoney(d.totalCost)} ₽')),
        DataCell(Text('${_fmtMoney(revenue)} ₽')),
        DataCell(Text('${_fmtMoney(revenue - d.totalCost)} ₽')),
        DataCell(Text(_fmtNumber(inStock))),
        DataCell(Text(_fmtNumber(shipped))),
        DataCell(Text(_fmtNumber(returned))),
        DataCell(Text('$sold')),
        DataCell(Text('${_fmtMoney(remainingValue)} ₽')),
      ]));
    }
    rows.add(DataRow(cells: [
      const DataCell(Text('Итого')),
      const DataCell(Text('')),
      DataCell(Text('${_fmtMoney(totalCost)} ₽')),
      DataCell(Text('${_fmtMoney(totalRevenue)} ₽')),
      DataCell(Text('${_fmtMoney(totalRevenue - totalCost)} ₽')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
    ]));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Бухгалтерия товаров'),
        content: SizedBox(
          width: 820,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('№')),
                  DataColumn(label: Text('Поставка')),
                  DataColumn(label: Text('Закупка')),
                  DataColumn(label: Text('Выручка')),
                  DataColumn(label: Text('Прибыль')),
                  DataColumn(label: Text('В наличии')),
                  DataColumn(label: Text('Отправлено')),
                  DataColumn(label: Text('Возврат')),
                  DataColumn(label: Text('Продано')),
                  DataColumn(label: Text('Остаток, ₽')),
                ],
                rows: rows,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    Product p,
    String mediaBaseUrl,
    bool canEdit,
    ValueChanged<Product> onEditProduct,
    List<Delivery> deliveries,
    Future<void> Function(Product) onDeleteProduct,
    Set<String> feedSkus,
    bool feedSkusLoaded,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ProductDetailsDialog(
        product: p,
        mediaBaseUrl: mediaBaseUrl,
        canEdit: canEdit,
        deliveries: deliveries,
        feedSkus: feedSkus,
        feedSkusLoaded: feedSkusLoaded,
        onEdit: () {
          Navigator.pop(dialogContext);
          onEditProduct(p);
        },
        onDelete: () {
          Navigator.pop(dialogContext);
          onDeleteProduct(p);
        },
        onClose: () => Navigator.pop(dialogContext),
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 190, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  String _deliveryTitle(String id, List<Delivery> deliveries) {
    for (final d in deliveries) {
      if (d.id == id) return '#${d.number} ${d.name}';
    }
    return '';
  }

class _ProductDetailsDialog extends StatefulWidget {
  const _ProductDetailsDialog({
    required this.product,
    required this.mediaBaseUrl,
    required this.canEdit,
    required this.deliveries,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    this.feedSkus = const {},
    this.feedSkusLoaded = false,
  });

  final Product product;
  final String mediaBaseUrl;
  final bool canEdit;
  final List<Delivery> deliveries;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  // SKU товаров, которые есть в фиде автозагрузки Авито.
  final Set<String> feedSkus;
  final bool feedSkusLoaded;

  @override
  State<_ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<_ProductDetailsDialog> {
  var _photo = 0;

  Product get p => widget.product;

  String _deliveryTitle() {
    for (final delivery in widget.deliveries) {
      if (delivery.id == p.deliveryId) {
        return '#${delivery.number} ${delivery.name}';
      }
    }
    return '';
  }

  /// Значок «на Авито» в детальном окне товара.
  Widget _feedBadge(BuildContext context) {
    final inFeed = widget.feedSkusLoaded
        ? widget.feedSkus.contains(p.sku)
        : productInAvitoFeed(p);
    final color =
        inFeed ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    return Tooltip(
      message: inFeed
          ? 'Товар есть в фиде автозагрузки Авито'
          : 'Товара нет в фиде Авито (статус, категория, цена или фото)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inFeed ? Icons.check_circle : Icons.remove_circle_outline,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              inFeed ? 'На Авито' : 'Нет на Авито',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF10131A) : const Color(0xFFF5F7FB);
    final card = dark ? const Color(0xFF181C25) : Colors.white;
    final border = dark ? const Color(0xFF2A303D) : const Color(0xFFE5E9F2);
    final muted = dark ? const Color(0xFF9AA3B5) : const Color(0xFF667085);
    final size = MediaQuery.sizeOf(context);
    final photos = p.photos;
    final selected = photos.isEmpty ? '' : photos[_photo.clamp(0, photos.length - 1)];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        width: 1040,
        height: (size.height - 60).clamp(520.0, 800.0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 48,
              offset: Offset(0, 20),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(dark, card, border, muted),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gallery(card, border, photos, selected, muted),
                  Expanded(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(4, 18, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _metrics(card, border, muted, dark),
                            const SizedBox(height: 16),
                            if (p.description.isNotEmpty)
                              _section(
                                'Описание',
                                Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if (p.attributes.isNotEmpty)
                              _section(
                                'Характеристики',
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in p.attributes.entries)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: card,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(color: border),
                                        ),
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: muted,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '${entry.key}: ',
                                                style: TextStyle(
                                                  color: muted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              TextSpan(
                                                text: entry.value,
                                                style: TextStyle(
                                                  color: dark
                                                      ? Colors.white
                                                      : const Color(0xFF1D2939),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (p.avitoStatsAt > 0)
                              _section(
                                'Статистика Авито · 30 дней',
                                Row(
                                  children: [
                                    _metricChip(
                                      Icons.visibility_outlined,
                                      '${p.avitoViews}',
                                      'просмотры',
                                      const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 8),
                                    _metricChip(
                                      Icons.chat_bubble_outline,
                                      '${p.avitoContacts}',
                                      'контакты',
                                      const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    _metricChip(
                                      Icons.favorite_border,
                                      '${p.avitoFavorites}',
                                      'избранное',
                                      const Color(0xFFDB2777),
                                    ),
                                  ],
                                ),
                              ),
                            _section(
                              'Подробности',
                              Column(
                                children: [
                                  _infoRow('Поставка', _deliveryTitle(), muted, border),
                                  _infoRow('Артикул', p.sku, muted, border),
                                  _infoRow('Категория', p.category, muted, border),
                                  _infoRow(
                                    'Размер / особенности',
                                    p.size,
                                    muted,
                                    border,
                                  ),
                                  _infoRow(
                                    'ID объявления Авито',
                                    p.avitoItemId,
                                    muted,
                                    border,
                                  ),
                                  _infoRow('Скидка', '${_fmtNumber(p.discountPercent)}%', muted, border),
                                  if (p.sold)
                                    _infoRow(
                                      'Дата продажи',
                                      p.soldTimestamp > 0
                                          ? _fmtDate(p.soldTimestamp)
                                          : '—',
                                      muted,
                                      border,
                                    ),
                                ],
                              ),
                            ),
                            if (p.statusEvents.isNotEmpty)
                              _section(
                                'История статусов',
                                Column(
                                  children: [
                                    for (final event
                                        in p.statusEvents.reversed.take(8))
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4338CA),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${_fmtDateTime(event.at)} · '
                                                '${_eventLabel(event.status)} · '
                                                '${_fmtNumber(event.quantity)} шт',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _footer(card, border, muted),
          ],
        ),
      ),
    );
  }

  Widget _header(bool dark, Color card, Color border, Color muted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      decoration: BoxDecoration(
        color: card,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name.trim().isEmpty ? 'Без названия' : p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _AvitoPill(product: p),
                    if (p.marketplaceKey.isNotEmpty)
                      _MarketplacePill(product: p),
                    _StatusPill(product: p),
                    _feedBadge(context),
                    if (p.sku.isNotEmpty)
                      Text(
                        'арт. ${p.sku}',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _gallery(
    Color card,
    Color border,
    List<String> photos,
    String selected,
    Color muted,
  ) {
    return Container(
      width: 430,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.antiAlias,
              child: selected.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_outlined, size: 44, color: muted),
                          const SizedBox(height: 8),
                          Text(
                            'Нет фотографий',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: const EdgeInsets.all(24),
                          child: InteractiveViewer(
                            child: CachedPhoto(
                              url: _mediaPhotoUrl(selected, widget.mediaBaseUrl),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      child: CachedPhoto(
                        url: _mediaPhotoUrl(selected, widget.mediaBaseUrl),
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _photo = index),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: index == _photo
                            ? const Color(0xFF4338CA)
                            : border,
                        width: index == _photo ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedPhoto(
                      url: _mediaPhotoUrl(photos[index], widget.mediaBaseUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metrics(Color card, Color border, Color muted, bool dark) {
    final profit = p.sold && p.costPrice != null
        ? p.salePrice - p.costPrice!
        : p.myPrice - (p.costPrice ?? 0);
    return Row(
      children: [
        _metricCard(
          'Моя цена',
          '${_fmtMoney(p.myPrice)} ₽',
          Icons.sell_outlined,
          const Color(0xFF4338CA),
          card,
          border,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Сумма',
          '${_fmtMoney(p.amount)} ₽',
          Icons.payments_outlined,
          const Color(0xFF0891B2),
          card,
          border,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Количество',
          '${_fmtNumber(p.quantity)} шт',
          Icons.inventory_2_outlined,
          const Color(0xFF16A34A),
          card,
          border,
        ),
        const SizedBox(width: 8),
        _metricCard(
          p.sold ? 'Прибыль' : 'Потенциал',
          '${_fmtMoney(profit)} ₽',
          Icons.trending_up,
          profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          card,
          border,
        ),
      ],
    );
  }

  Widget _metricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color card,
    Color border,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color muted, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(Color card, Color border, Color muted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          if (p.marketplaceUrl.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(p.marketplaceUrl)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Открыть на Авито'),
            ),
          const Spacer(),
          if (widget.canEdit) ...[
            TextButton.icon(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
              label: const Text('Удалить'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Изменить'),
            ),
          ] else
            Text(
              'Только просмотр',
              style: TextStyle(color: muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _DeliveryDetailsDialog extends StatelessWidget {
  const _DeliveryDetailsDialog({
    required this.delivery,
    required this.goods,
    required this.onShow,
    required this.onEdit,
    required this.onDelete,
    required this.onSalePriceChanged,
    required this.onClose,
  });

  final Delivery delivery;
  final List<Product> goods;
  final VoidCallback onShow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(Product product, double price)?
      onSalePriceChanged;
  final VoidCallback onClose;

  double get cost => delivery.totalCost;
  double get revenue => goods
      .where((product) => product.sold)
      .fold<double>(0, (sum, product) => sum + product.salePrice * product.quantity);
  double get profit => revenue - cost;
  double get percent => cost <= 0 ? (revenue > 0 ? 100 : 0) : revenue / cost * 100;
  double get totalQuantity =>
      goods.fold<double>(0, (sum, product) => sum + product.quantity);
  double get soldQuantity => goods
      .where((product) => product.sold)
      .fold<double>(0, (sum, product) => sum + product.quantity);
  double get amount =>
      goods.fold<double>(0, (sum, product) => sum + product.amount);

  Color get accent => percent >= 100 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF10131A) : const Color(0xFFF5F7FB);
    final card = dark ? const Color(0xFF181C25) : Colors.white;
    final border = dark ? const Color(0xFF2A303D) : const Color(0xFFE5E9F2);
    final muted = dark ? const Color(0xFF9AA3B5) : const Color(0xFF667085);
    final size = MediaQuery.sizeOf(context);
    final sold = goods.where((product) => product.sold).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final topGoods = [...goods]..sort((a, b) => b.amount.compareTo(a.amount));
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        width: 980,
        height: (size.height - 60).clamp(520.0, 800.0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 44,
              offset: Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(dark, card, border, muted),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summary(card, border, muted, dark),
                    const SizedBox(height: 16),
                    _productsBlock(
                      context,
                      'Товары поставки',
                      topGoods,
                      card,
                      border,
                      muted,
                      dark,
                      emptyText: 'В поставке пока нет товаров',
                    ),
                    const SizedBox(height: 16),
                    _productsBlock(
                      context,
                      'Продажи',
                      sold,
                      card,
                      border,
                      muted,
                      dark,
                      emptyText: 'Продаж по этой поставке пока нет',
                      sales: true,
                    ),
                  ],
                ),
              ),
            ),
            _footer(card, border),
          ],
        ),
      ),
    );
  }

  Widget _header(bool dark, Color card, Color border, Color muted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0E7490), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Поставка #${delivery.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  [
                    if (delivery.name.isNotEmpty) delivery.name,
                    if (delivery.supplier.isNotEmpty) delivery.supplier,
                    if (delivery.date.isNotEmpty) delivery.date,
                  ].join(' · '),
                  style: const TextStyle(
                    color: Color(0xFFCFFAFE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _summary(Color card, Color border, Color muted, bool dark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 190,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: (percent / 100).clamp(0.0, 1.0),
                        strokeWidth: 10,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.12),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percent.round()}%',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        Text(
                          'окупаемость',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                percent >= 100 ? 'Поставка окупилась' : 'Не окупилась',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  _statCard(
                    'Стоимость',
                    '${_fmtMoney(cost)} ₽',
                    Icons.shopping_cart_outlined,
                    const Color(0xFF6366F1),
                    card,
                    border,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Выручка',
                    '${_fmtMoney(revenue)} ₽',
                    Icons.payments_outlined,
                    const Color(0xFF0891B2),
                    card,
                    border,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Прибыль',
                    '${_fmtMoney(profit)} ₽',
                    Icons.trending_up,
                    profit >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    card,
                    border,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard(
                    'Товаров',
                    '${goods.length}',
                    Icons.inventory_2_outlined,
                    const Color(0xFF7C3AED),
                    card,
                    border,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Продано',
                    '${_fmtNumber(soldQuantity)} / ${_fmtNumber(totalQuantity)}',
                    Icons.check_circle_outline,
                    const Color(0xFF16A34A),
                    card,
                    border,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Потенциал',
                    '${_fmtMoney(amount)} ₽',
                    Icons.auto_graph,
                    const Color(0xFFEA580C),
                    card,
                    border,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color card,
    Color border,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSale(BuildContext context, Product product) async {
    final callback = onSalePriceChanged;
    if (callback == null) return;
    final controller = TextEditingController(
      text: product.salePrice.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Цена продажи'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Цена за 1 шт, ₽',
            helperText: '${product.name} · ${product.sku}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (price != null && price >= 0) {
                Navigator.pop(dialogContext, price);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await callback(product, value);
    if (context.mounted) Navigator.pop(context);
  }

  Widget _productsBlock(
    BuildContext context,
    String title,
    List<Product> list,
    Color card,
    Color border,
    Color muted,
    bool dark, {
    required String emptyText,
    bool sales = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyText,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            )
          else
            for (final product in list.take(50))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        product.sku.isEmpty ? '—' : product.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: sales && onSalePriceChanged != null
                            ? () => _editSale(context, product)
                            : null,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name.isEmpty ? 'Без названия' : product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              '${_fmtNumber(product.quantity)} шт',
                              if (product.size.isNotEmpty) product.size,
                              if (sales)
                                'продано за ${_fmtMoney(product.salePrice)} ₽'
                                    '${product.soldTimestamp > 0 ? ' · ${_fmtDate(product.soldTimestamp)}' : ''}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                        ],
                      ),
                      ),
                    ),
                    if (!sales)
                      Text(
                        '${_fmtMoney(product.amount)} ₽',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fmtMoney(product.salePrice * product.quantity)} ₽',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.costPrice != null)
                            Text(
                              'прибыль ${_fmtMoney((product.salePrice - product.costPrice!) * product.quantity)} ₽',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _footer(Color card, Color border) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onShow,
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: const Text('Показать товары поставки'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            label: const Text('Удалить'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Изменить'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryBubble extends StatelessWidget {
  const _DeliveryBubble({
    required this.label,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double? percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = percent;
    final done = value != null && value >= 100;
    final color = value == null
        ? scheme.primary
        : done
            ? Colors.green
            : Colors.red;
    final progress = value == null ? 0.0 : (value / 100).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(44),
      child: Container(
        width: 92,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value == null ? 1 : progress,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  Text(
                    value == null ? 'Все' : '${value.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvitoPill extends StatelessWidget {
  const _AvitoPill({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 30,
      child: Material(
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6163), Color(0xFF00AAFF), Color(0xFF97CF26)],
            ),
          ),
          child: InkWell(
            onTap: () {
              final url = product.marketplace == 'avito'
                  ? product.marketplaceUrl
                  : '';
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Авито: ссылка ещё не синхронизирована')),
                );
                return;
              }
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Center(
              child: Text(
                'AVITO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplacePill extends StatelessWidget {
  const _MarketplacePill({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final isWb = product.marketplaceKey == 'wb';
    final url = product.marketplaceProductUrl;
    return SizedBox(
      width: 104,
      height: 30,
      child: Material(
        color: isWb ? const Color(0xFFCB11AB) : const Color(0xFF005BFF),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: url.isEmpty
              ? null
              : () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
          child: Center(
            child: Text(
              isWb ? 'WB' : 'OZON',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (product.status) {
      'sold' => ('Продан', Colors.red),
      'shipped' => ('Отправлен', Colors.amber),
      'returned' => ('Возврат', Colors.amber),
      'ready' => ('Готов к продаже', const Color(0xFF007AFF)),
      _ => (
          '${_fmtNumber(product.quantity)} шт',
          Colors.green,
        ),
    };
    return Container(
      width: 104,
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: color == Colors.amber ? Colors.black87 : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _mediaPhotoUrl(String photo, String mediaBase) {
  if (photo.startsWith('http')) return photo;
  if (photo.startsWith('/media/')) {
    return '$mediaBase/media-thumb/${photo.substring('/media/'.length)}';
  }
  return '$mediaBase$photo';
}

String _fmtDate(int milliseconds) {
  if (milliseconds <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String _eventLabel(String status) => switch (status) {
  'sold' => 'Продан',
  'shipped' => 'Отправлен',
  'returned' => 'Возврат',
  'ready' => 'Готов к продаже',
  _ => 'В наличии',
};

String _fmtDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

String _fmtNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : '$v';
String _fmtMoney(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(2);

void _showAvitoSync(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Синхронизация с Авито'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Профиль: Vibe Store'),
            SizedBox(height: 8),
            Text(
              'Синхронизация будет сопоставлять объявления Авито с товарами '
              'по артикулу и названию, обновлять статусы, цены и ссылки.',
            ),
            SizedBox(height: 12),
            Text(
              'Подключение Авито к CRM пока не настроено. Кнопка готова — '
              'следующим шагом добавим авторизацию и обмен данными.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

class _ProductCatalog extends StatefulWidget {
  const _ProductCatalog({
    required this.items,
    required this.deliveries,
    required this.selectedDeliveryId,
    required this.mediaBaseUrl,
    required this.canEdit,
    required this.onStatusChanged,
    required this.onEditProduct,
    required this.onDeleteProduct,
    this.onBulkUpdate,
    this.onSale,
    this.feedSkus = const {},
    this.feedSkusLoaded = false,
  });

  final List<Product> items;
  final List<Delivery> deliveries;
  final String selectedDeliveryId;
  final String mediaBaseUrl;
  final bool canEdit;
  final void Function(Product, String)? onStatusChanged;
  final ValueChanged<Product> onEditProduct;
  final Future<void> Function(Product) onDeleteProduct;
  final Future<void> Function(List<Product> products,
      {String? status, String? deliveryId, String? category})? onBulkUpdate;
  final Future<void> Function(List<Product> products, double percent)? onSale;
  // SKU товаров, которые есть в фиде автозагрузки Авито.
  final Set<String> feedSkus;
  final bool feedSkusLoaded;

  @override
  State<_ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<_ProductCatalog> {
  String query = '';
  final Set<String> statuses = {};
  String sort = 'updated';
  bool group = false;
  final Set<String> expanded = {};
  bool selectMode = false;
  final Set<String> selected = {};
  String? bulkStatus;
  String? bulkDeliveryId;

  @override
  void initState() {
    super.initState();
    _loadListPreferences();
  }

  Future<void> _loadListPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        sort = prefs.getString('crm_catalog_sort') ?? sort;
        final savedStatuses =
            prefs.getStringList('crm_catalog_statuses') ?? const [];
        statuses
          ..clear()
          ..addAll(savedStatuses);
        if (savedStatuses.isEmpty) {
          final old = prefs.getString('crm_catalog_status') ?? 'all';
          if (old != 'all') statuses.add(old);
        }
        group = prefs.getBool('crm_catalog_group') ?? group;
      });
    } catch (_) {}
  }

  void _persistListPreferences() {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('crm_catalog_sort', sort);
        await prefs.setStringList('crm_catalog_statuses', statuses.toList());
        await prefs.setBool('crm_catalog_group', group);
      } catch (_) {}
    }());
  }

  List<Product> get filtered {
    final q = query.trim().toLowerCase();
    return widget.items
        .where((p) =>
            widget.selectedDeliveryId.isEmpty ||
            p.deliveryId == widget.selectedDeliveryId)
        .where((p) => statuses.isEmpty || statuses.contains(p.status))
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.supplier.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<Product> _sorted(List<Product> source) {
    final list = List<Product>.from(source);
    int compareText(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    switch (sort) {
      case 'sku_asc':
        list.sort((a, b) {
          if (a.sku.isEmpty != b.sku.isEmpty) return a.sku.isEmpty ? 1 : -1;
          return _naturalCompare(a.sku, b.sku);
        });
      case 'sku_desc':
        list.sort((a, b) {
          if (a.sku.isEmpty != b.sku.isEmpty) return a.sku.isEmpty ? 1 : -1;
          return _naturalCompare(b.sku, a.sku);
        });
      case 'name_asc':
        list.sort((a, b) => compareText(a.name, b.name));
      case 'price_asc':
        list.sort((a, b) => a.myPrice.compareTo(b.myPrice));
      case 'price_desc':
        list.sort((a, b) => b.myPrice.compareTo(a.myPrice));
      case 'qty_desc':
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  static int _naturalCompare(String a, String b) {
    final left = RegExp(r'\d+|\D+')
        .allMatches(a.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();
    final right = RegExp(r'\d+|\D+')
        .allMatches(b.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();
    final length = left.length < right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = left[i];
      final r = right[i];
      final lNum = int.tryParse(l);
      final rNum = int.tryParse(r);
      if (lNum != null && rNum != null) {
        final compared = lNum.compareTo(rNum);
        if (compared != 0) return compared;
      } else {
        final compared = l.compareTo(r);
        if (compared != 0) return compared;
      }
    }
    return left.length.compareTo(right.length);
  }

  Widget _iosSelect<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
          width: 0.6,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint == null ? null : Text(hint),
          items: items,
          onChanged: onChanged,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          style: TextStyle(
            fontSize: 13,
            color: dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }

  PopupMenuButton<String> _sortButton() => PopupMenuButton<String>(
        tooltip: 'Сортировка',
        icon: const Icon(Icons.sort),
        initialValue: sort,
        onSelected: (value) {
        setState(() => sort = value);
        _persistListPreferences();
      },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'updated', child: Text('Сначала новые')),
          PopupMenuItem(value: 'sku_asc', child: Text('Артикул: А–Я')),
          PopupMenuItem(value: 'sku_desc', child: Text('Артикул: Я–А')),
          PopupMenuItem(value: 'name_asc', child: Text('Название: А–Я')),
          PopupMenuItem(value: 'price_asc', child: Text('Цена: по возрастанию')),
          PopupMenuItem(value: 'price_desc', child: Text('Цена: по убыванию')),
          PopupMenuItem(value: 'qty_desc', child: Text('Количество: больше')),
        ],
      );

  Widget _tile(Product p) {
    final name = p.name.trim().isEmpty ? 'Без названия' : p.name;
    final title = p.sku.trim().isNotEmpty ? p.sku : name;
    final firstPhoto = p.photos.isEmpty ? '' : p.photos.first;
    final isSelected = selected.contains(p.id);
    return ListTile(
      leading: selectMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => setState(() {
                if (isSelected) {
                  selected.remove(p.id);
                } else {
                  selected.add(p.id);
                }
              }),
            )
          : firstPhoto.isEmpty
          ? const CircleAvatar(child: Icon(Icons.shopping_bag_outlined))
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedPhoto(
                url: _mediaPhotoUrl(firstPhoto, widget.mediaBaseUrl),
                width: 48,
                height: 48,
              ),
            ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: [
                    name,
                    if (p.size.isNotEmpty) p.size,
                    if (p.costPrice != null)
                      'себестоимость ${_fmtMoney(p.costPrice!)} ₽',
                  ].join(' · '),
                ),
                const TextSpan(text: ' · '),
                if (p.onSale) ...[
                  TextSpan(
                    text: '${_fmtMoney(p.saleOldPrice)} ₽',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  TextSpan(
                    text: ' ${_fmtMoney(p.saleNewPrice)} ₽',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else
                  TextSpan(
                    text: 'Моя цена: ${_fmtMoney(p.myPrice)} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [_feedBadge(p)],
            ),
          ),
          if (p.avitoStatsAt > 0)if (p.avitoStatsAt > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _statChip(
                    Icons.visibility_outlined,
                    p.avitoViews,
                    'Просмотры за 30 дней',
                    const Color(0xFF2563EB),
                  ),
                  _statChip(
                    Icons.chat_bubble_outline,
                    p.avitoContacts,
                    'Контакты за 30 дней',
                    const Color(0xFF16A34A),
                  ),
                  _statChip(
                    Icons.favorite_border,
                    p.avitoFavorites,
                    'В избранном за 30 дней',
                    const Color(0xFFDB2777),
                  ),
                ],
              ),
            ),
        ],
      ),
      isThreeLine: p.avitoStatsAt > 0,
      trailing: selectMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvitoPill(product: p),
                const SizedBox(width: 6),
                if (p.marketplaceKey.isNotEmpty)
                  _MarketplacePill(product: p)
                else
                  const SizedBox(width: 104, height: 30),
                const SizedBox(width: 6),
                if (widget.onStatusChanged == null)
                  _StatusPill(product: p)
                else
                  PopupMenuButton<String>(
              tooltip: 'Изменить статус',
              onSelected: (value) => widget.onStatusChanged!(p, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'in_stock', child: Text('В наличии')),
                PopupMenuItem(
                  value: 'ready',
                  child: Text('Готов к продаже'),
                ),
                PopupMenuItem(value: 'shipped', child: Text('Отправлен')),
                PopupMenuItem(value: 'returned', child: Text('Возврат')),
                PopupMenuItem(value: 'sold', child: Text('Продан')),
              ],
                    child: _StatusPill(product: p),
                  ),
              ],
            ),
      onTap: selectMode
          ? () => setState(() {
                if (isSelected) {
                  selected.remove(p.id);
                } else {
                  selected.add(p.id);
                }
              })
          : () => _showDetails(
                context,
                p,
                widget.mediaBaseUrl,
                widget.canEdit,
                widget.onEditProduct,
                widget.deliveries,
                widget.onDeleteProduct,
                widget.feedSkus,
                widget.feedSkusLoaded,
              ),
    );
  }

  Widget _statChip(IconData icon, int value, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Значок «на Авито»: показывает, попал ли товар в фид автозагрузки.
  /// Если список SKU с сервера ещё не пришёл, считаем локально по тем же
  /// правилам, что применяет фид (статус, категория, цена, фото, SKU).
  Widget _feedBadge(Product p) {
    final inFeed = widget.feedSkusLoaded
        ? widget.feedSkus.contains(p.sku)
        : productInAvitoFeed(p);
    final color =
        inFeed ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    return Tooltip(
      message: inFeed
          ? 'Товар есть в фиде автозагрузки Авито'
          : 'Товара нет в фиде Авито (статус, категория, цена или фото)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inFeed ? Icons.check_circle : Icons.remove_circle_outline,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              inFeed ? 'На Авито' : 'Нет на Авито',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary(List<Product> groupItems) {
    double sum(String status) => groupItems
        .where((p) => p.status == status)
        .fold<double>(0, (s, p) => s + p.quantity);
    return [
      '${_fmtNumber(sum('in_stock'))} в наличии',
      if (sum('shipped') > 0) '${_fmtNumber(sum('shipped'))} отправлено',
      if (sum('returned') > 0) '${_fmtNumber(sum('returned'))} возврат',
      if (sum('sold') > 0) '${_fmtNumber(sum('sold'))} продано',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final items = _sorted(filtered);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Поиск по артикулу, названию или категории',
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            const SizedBox(width: 8),
            _sortButton(),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('По артикулу'),
              selected: group,
              onSelected: (value) {
                setState(() => group = value);
                _persistListPreferences();
              },
            ),
            if (widget.onBulkUpdate != null)
              IconButton(
                tooltip: selectMode ? 'Выйти из выбора' : 'Массовые действия',
                isSelected: selectMode,
                onPressed: () => setState(() {
                  selectMode = !selectMode;
                  selected.clear();
                }),
                icon: const Icon(Icons.checklist_outlined),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Все статусы'),
                selected: statuses.isEmpty,
                onSelected: (_) {
                  setState(statuses.clear);
                  _persistListPreferences();
                },
              ),
              for (final entry in const [
                ('in_stock', 'В наличии', Color(0xFF16A34A)),
                ('ready', 'Готов к продаже', Color(0xFF007AFF)),
                ('shipped', 'Отправлен', Color(0xFFF59E0B)),
                ('returned', 'Возврат', Color(0xFFF59E0B)),
                ('sold', 'Продан', Color(0xFFDC2626)),
              ])
                Builder(
                  builder: (context) {
                    final selected = statuses.contains(entry.$1);
                    return FilterChip(
                      label: Text(entry.$2),
                      selected: selected,
                      selectedColor: entry.$3,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : entry.$3,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: entry.$3.withValues(alpha: 0.45),
                      ),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            statuses.add(entry.$1);
                          } else {
                            statuses.remove(entry.$1);
                          }
                        });
                        _persistListPreferences();
                      },
                    );
                  },
                ),
            ],
          ),
        ),
        if (selectMode)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFE5E5EA),
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Выбрано: ${selected.length} из ${filtered.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => selected.addAll(
                          filtered.map((product) => product.id),
                        ),
                      ),
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('Выбрать все'),
                    ),
                    if (selected.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(selected.clear),
                        child: const Text('Снять выбор'),
                      ),
                  ],
                ),
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _iosSelect<String>(
                        hint: 'Статус',
                        value: bulkStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'in_stock',
                            child: Text('В наличии'),
                          ),
                          DropdownMenuItem(
                            value: 'ready',
                            child: Text('Готов к продаже'),
                          ),
                          DropdownMenuItem(
                            value: 'shipped',
                            child: Text('Отправлен'),
                          ),
                          DropdownMenuItem(
                            value: 'returned',
                            child: Text('Возврат'),
                          ),
                          DropdownMenuItem(
                            value: 'sold',
                            child: Text('Продан'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => bulkStatus = value),
                      ),
                      _iosSelect<String>(
                        hint: 'Поставка',
                        value: bulkDeliveryId,
                        items: [
                          for (final d in widget.deliveries)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text('#${d.number} ${d.name}'),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => bulkDeliveryId = value),
                      ),
                      TextButton.icon(
                        onPressed: _pickCategory,
                        icon: const Icon(Icons.category_outlined, size: 18),
                        label: const Text('Категория'),
                      ),
                      if (widget.onSale != null)
                        TextButton.icon(
                          onPressed: _pickSale,
                          icon: const Icon(
                            Icons.local_offer_outlined,
                            size: 18,
                          ),
                          label: const Text('Распродажа'),
                        ),
                      FilledButton(
                        onPressed: () {
                          final targets = widget.items
                              .where((p) => selected.contains(p.id))
                              .toList();
                          widget.onBulkUpdate!(
                            targets,
                            status: bulkStatus,
                            deliveryId: bulkDeliveryId,
                            category: null,
                          );
                          setState(() {
                            selected.clear();
                            bulkStatus = null;
                            bulkDeliveryId = null;
                          });
                        },
                        child: const Text('Применить'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Ничего не найдено',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else if (!group)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _tile(items[index]),
          )
        else
          for (final entry in _groups(items).entries)
            ExpansionTile(
              key: PageStorageKey(entry.key),
              initiallyExpanded: expanded.contains(entry.key),
              onExpansionChanged: (value) => setState(() {
                if (value) {
                  expanded.add(entry.key);
                } else {
                  expanded.remove(entry.key);
                }
              }),
              title: Text(entry.key),
              subtitle: Text(_summary(entry.value)),
              children: [for (final p in entry.value) _tile(p)],
            ),
      ],
    );
  }

  Future<void> _pickSale() async {
    final targets = widget.items
        .where((product) => selected.contains(product.id))
        .toList();
    if (targets.isEmpty) return;
    final controller = TextEditingController(text: '20');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Распродажа'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Товаров: ${targets.length}'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Скидка, %',
                  helperText: 'Старая цена сохранится и будет зачёркнута',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0.0),
            child: const Text('Снять скидку'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final percent = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (percent != null && percent > 0 && percent < 100) {
                Navigator.pop(dialogContext, percent);
              }
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await widget.onSale!(targets, value);
    if (!mounted) return;
    setState(() => selected.clear());
  }

  Future<void> _pickCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Категория'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    final targets =
        widget.items.where((p) => selected.contains(p.id)).toList();
    await widget.onBulkUpdate!(targets, category: value);
    if (!mounted) return;
    setState(() => selected.clear());
  }

  Map<String, List<Product>> _groups(List<Product> items) {
    final result = <String, List<Product>>{};
    for (final p in items) {
      final key = p.sku.trim().isNotEmpty
          ? p.sku.trim()
          : (p.name.trim().isEmpty ? 'Без названия' : p.name.trim());
      result.putIfAbsent(key, () => []).add(p);
    }
    return result;
  }
}

void _showDeliveryDetails(
  BuildContext context,
  Delivery delivery,
  List<Product> items,
  ValueChanged<String> onSelectDelivery,
  ValueChanged<Delivery> onEditDelivery,
  Future<void> Function(Delivery) onDeleteDelivery,
  Future<void> Function(Product product, double price)? onSalePriceChanged,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _DeliveryDetailsDialog(
      delivery: delivery,
      goods: items
          .where((product) => product.deliveryId == delivery.id)
          .toList(),
      onShow: () {
        Navigator.pop(dialogContext);
        onSelectDelivery(delivery.id);
      },
      onEdit: () {
        Navigator.pop(dialogContext);
        onEditDelivery(delivery);
      },
      onDelete: () {
        Navigator.pop(dialogContext);
        onDeleteDelivery(delivery);
      },
      onSalePriceChanged: onSalePriceChanged,
      onClose: () => Navigator.pop(dialogContext),
    ),
  );
}



/// Категории, которые поддерживает фид автозагрузки Авито (совпадает с
/// AVITO_CATEGORY_MAP на сервере).
const avitoFeedCategoryIds = <String, int>{
  'Бытовая техника': 21,
  'Одежда': 27,
  'Одежда, обувь, аксессуары': 27,
  'Детская одежда': 29,
  'Детская одежда и обувь': 29,
  'Автотовары': 10,
  'Автотовары и аксессуары': 10,
  'Автоаксессуары': 10,
  'Аксессуары для авто': 10,
  'Запчасти': 10,
  'Запчасти и аксессуары': 10,
  'Запчасти для авто': 10,
  'Товары для дома': 2,
  'Ремонт и строительство': 19,
  'Мебель и интерьер': 20,
  'Кемпинг': 39,
  'Спорт': 39,
  'Спорт и отдых': 39,
  'Товары для компьютера': 101,
  'Телефоны': 84,
  'Игры, приставки и программы': 97,
  'Посуда и товары для кухни': 87,
  'Красота и здоровье': 88,
  'Продукты питания': 82,
  'Охота и рыбалка': 102,
  'Фототехника': 105,
  'Электроника': 6,
  'Автоэлектроника': 6,
  'Другое': 26,
};

/// Локальная проверка «попадёт ли товар в фид автозагрузки», повторяющая
/// правила сервера (build_avito_feed). Используется, пока список SKU с
/// сервера не загружен; после загрузки приоритет у серверного списка.
bool productInAvitoFeed(Product p) {
  final sku = p.sku.trim();
  final name = p.name.trim();
  if (sku.isEmpty || name.isEmpty) return false;
  if (p.sold) return false;
  if (p.status.isNotEmpty && p.status != 'in_stock' && p.status != 'ready') {
    return false;
  }
  final category = p.category.trim();
  if (avitoFeedCategoryIds[category] == null &&
      !name.toLowerCase().contains('детск')) {
    return false;
  }
  final price = p.myPriceOverride ?? p.marketplacePrice * (1 - (p.discountPercent.clamp(0, 100) / 100));
  if (price <= 0) return false;
  if (p.photos.where((photo) => photo.trim().isNotEmpty).isEmpty) return false;
  return true;
}
