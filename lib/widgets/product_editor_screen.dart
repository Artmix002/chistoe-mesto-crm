import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../avito_catalog.dart';
import '../cached_photo.dart';
import '../models.dart';

/// Элемент категории для пошагового выбора (маленький ответ сервера).
typedef AvitoCategoryEntry = ({
  String name,
  String slug,
  bool hasChildren,
  bool hasFields,
});

/// Полноэкранный редактор товара с подсказками по категории Авито.
///
/// Открывается из раздела «Товары» вместо прежней встроенной формы.
/// Слева — фото и основные данные, справа — цена, склад и обязательные
/// параметры выбранной категории Авито.
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    super.key,
    required this.product,
    required this.isNew,
    required this.catalog,
    required this.catalogLoaded,
    required this.deliveries,
    required this.mediaBaseUrl,
    required this.onSave,
    required this.isSkuTaken,
    required this.onDelete,
    this.onUploadPhotos,
    this.onSyncCatalog,
    this.onLoadCatalog,
    this.onLoadFields,
    this.onLoadCategories,
    this.onSearchCategories,
  });

  final Product product;
  final bool isNew;
  final AvitoCatalogData? catalog;
  final bool catalogLoaded;
  final List<Delivery> deliveries;
  final String mediaBaseUrl;
  final Future<void> Function(Product product) onSave;
  final bool Function(String sku) isSkuTaken;
  final Future<void> Function(Product product)? onDelete;
  final Future<List<String>> Function(List<XFile> files)? onUploadPhotos;

  /// Дочерние категории для дерева (пустой parent — корневые).
  final Future<List<AvitoCategoryEntry>> Function(String parent)?
  onLoadCategories;

  /// Поиск категорий на сервере.
  final Future<List<AvitoCategoryEntry>> Function(String query)?
  onSearchCategories;
  final Future<void> Function()? onSyncCatalog;

  /// Загружает/обновляет справочник (дерево + поля) и возвращает его.
  final Future<AvitoCatalogData?> Function()? onLoadCatalog;

  /// Точечная загрузка полей выбранной категории (быстро, без полного синка).
  final Future<AvitoCatalogData?> Function(String slug)? onLoadFields;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController size;
  late final TextEditingController description;
  late final TextEditingController quantity;
  late final TextEditingController cost;
  late final TextEditingController marketplace;
  late final TextEditingController discount;
  late final TextEditingController myPrice;
  late final TextEditingController salePercent;
  late final TextEditingController saleBasePrice;

  final Map<String, TextEditingController> params = {};
  String? categorySlug;
  String categoryName = '';
  AvitoCatalogData? catalog;
  late String status;
  late String deliveryId;
  late List<String> photos;
  bool uploading = false;
  bool onlyRequired = true;

  static const autoFieldTags = {
    'Id',
    'Title',
    'Description',
    'Images',
    'Image',
    'Category',
    'Price',
    'Address',
    'AdType',
    'GoodsType',
    'VideoURL',
  };

  Product get p => widget.product;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: p.name);
    sku = TextEditingController(text: p.sku);
    size = TextEditingController(text: p.size);
    description = TextEditingController(text: p.description);
    quantity = TextEditingController(text: _text(p.quantity));
    cost = TextEditingController(text: _text(p.costPrice ?? 0));
    marketplace = TextEditingController(text: _text(p.marketplacePrice));
    discount = TextEditingController(text: _text(p.discountPercent));
    myPrice = TextEditingController(
      text: p.myPriceOverride == null ? '' : _text(p.myPriceOverride!),
    );
    salePercent = TextEditingController(text: _text(p.salePercent));
    saleBasePrice = TextEditingController(text: _text(p.saleBasePrice));
    status = p.status;
    deliveryId = p.deliveryId;
    photos = List<String>.from(p.photos);
    catalog = widget.catalog;
    categorySlug = (p.attributes['avito_slug'] ?? '').isEmpty
        ? null
        : p.attributes['avito_slug'];
    categoryName = p.category;
    for (final entry in p.attributes.entries) {
      if (entry.key == 'avito_slug') continue;
      params[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      sku,
      size,
      description,
      quantity,
      cost,
      marketplace,
      discount,
      myPrice,
      salePercent,
      saleBasePrice,
    ]) {
      c.dispose();
    }
    for (final c in params.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _text(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : '$v');

  static double _num(String v) {
    var t = v.trim().replaceAll(RegExp(r'[\s\u00a0]'), '');
    t = t.replaceAll(RegExp(r'(₽|руб\.?|р\.)'), '');
    return double.tryParse(t.replaceAll(',', '.')) ?? 0;
  }

  List<AvitoField> get allFields {
    final active = catalog;
    final slug = categorySlug;
    if (active == null || slug == null) return const [];
    return (active.fields[slug] ?? const [])
        .where((f) => !autoFieldTags.contains(f.tag))
        .toList(growable: false);
  }

  /// Поля для показа: по умолчанию только обязательные.
  List<AvitoField> get fields => onlyRequired
      ? allFields.where((f) => f.hasRequired).toList(growable: false)
      : allFields;

  List<AvitoField> get requiredFields =>
      fields.where((f) => f.hasRequired).toList(growable: false);

  int get optionalCount => allFields.where((f) => !f.hasRequired).length;

  int get filledRequired => requiredFields
      .where((f) => (params[f.label]?.text.trim() ?? '').isNotEmpty)
      .length;

  double get priceValue {
    final manual = myPrice.text.trim();
    if (manual.isNotEmpty) return _num(manual);
    final base = _num(marketplace.text);
    final d = _num(discount.text).clamp(0, 100);
    return base * (1 - d / 100);
  }

  List<String> get problems {
    final out = <String>[];
    if (name.text.trim().isEmpty) out.add('Не заполнено название');
    if (sku.text.trim().isEmpty) out.add('Не заполнен артикул (SKU)');
    if (priceValue <= 0) out.add('Не указана цена');
    if (photos.isEmpty) out.add('Нет ни одного фото');
    if (categorySlug == null) out.add('Не выбрана категория Авито');
    final missing = requiredFields.where(
      (f) => (params[f.label]?.text.trim() ?? '').isEmpty,
    );
    if (missing.isNotEmpty) {
      out.add(
        'Не заполнены обязательные параметры: '
        '${missing.take(3).map((f) => f.label).join(', ')}'
        '${missing.length > 3 ? '…' : ''}',
      );
    }
    return out;
  }

  void _apply() {
    p
      ..name = name.text.trim()
      ..sku = sku.text.trim()
      ..size = size.text.trim()
      ..description = description.text
      ..quantity = _num(quantity.text)
      ..costPrice = _num(cost.text)
      ..marketplacePrice = _num(marketplace.text)
      ..discountPercent = _num(discount.text)
      ..salePercent = _num(salePercent.text)
      ..saleBasePrice = _num(saleBasePrice.text)
      ..status = status
      ..deliveryId = deliveryId
      ..photos = List<String>.from(photos)
      ..category = categoryName;
    final manual = myPrice.text.trim();
    p.myPriceOverride = manual.isEmpty ? null : _num(manual);
    p.attributes = {
      'avito_slug': categorySlug ?? '',
      for (final entry in params.entries) entry.key: entry.value.text.trim(),
    };
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _save() async {
    if (widget.isSkuTaken(sku.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Такой артикул уже используется')),
        );
      }
      return;
    }
    _apply();
    await widget.onSave(p);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _trySave() async {
    if (widget.isSkuTaken(sku.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Такой артикул уже используется')),
      );
      return;
    }
    final issues = problems;
    if (issues.isEmpty) return _save();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Товар не готов к публикации'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Можно сохранить сейчас и дозаполнить позже. '
              'Пока этих данных нет, объявление не опубликуется на Авито:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 15,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(issue, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Вернуться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить как есть'),
          ),
        ],
      ),
    );
    if (proceed == true) await _save();
  }

  Future<void> _loadCatalog() async {
    final loader = widget.onLoadCatalog;
    if (loader == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Загружаю категории Авито…'),
          ],
        ),
      ),
    );
    try {
      final loaded = await loader().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => catalog = loaded ?? catalog);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _pickPhotos() async {
    const group = XTypeGroup(
      label: 'Изображения',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
    );
    final files = await openFiles(acceptedTypeGroups: const [group]);
    if (files.isEmpty || widget.onUploadPhotos == null) return;
    final free = 10 - photos.length;
    if (free <= 0) return;
    setState(() => uploading = true);
    try {
      final urls = await widget.onUploadPhotos!(files.take(free).toList());
      if (!mounted) return;
      setState(() => photos = [...photos, ...urls]);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showDialog<AvitoCategoryEntry>(
      context: context,
      builder: (_) => _AvitoCategoryPickerDialog(
        selectedSlug: categorySlug,
        loadCategories:
            widget.onLoadCategories ??
            (parent) async => const <AvitoCategoryEntry>[],
        searchCategories:
            widget.onSearchCategories ??
            (query) async => const <AvitoCategoryEntry>[],
      ),
    );
    if (picked == null) return;
    final loadFields = widget.onLoadFields;
    if (loadFields != null) {
      final loaded = await loadFields(picked.slug);
      if (mounted) setState(() => catalog = loaded ?? catalog);
    }
    if (!mounted) return;
    setState(() {
      categorySlug = picked.slug;
      categoryName = picked.name;
      final known = catalog?.fields[picked.slug] ?? const [];
      final keep = <String, String>{};
      for (final field in known.where((f) => !autoFieldTags.contains(f.tag))) {
        final old = params[field.label]?.text;
        if (old != null) keep[field.label] = old;
      }
      for (final c in params.values) {
        c.dispose();
      }
      params.clear();
      for (final entry in keep.entries) {
        params[entry.key] = TextEditingController(text: entry.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0D1017) : const Color(0xFFF3F5FA);
    final issues = problems;
    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          _header(context, issues),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _photosCard(context),
                      const SizedBox(height: 16),
                      _mainCard(context),
                    ],
                  );
                  final right = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _priceCard(context),
                      const SizedBox(height: 16),
                      _stockCard(context),
                      const SizedBox(height: 16),
                      _avitoCard(context),
                    ],
                  );
                  // Параметры Авито — отдельным блоком во всю ширину,
                  // чтобы длинный список не вытягивался в одну колонку.
                  final params = _paramsCard(context, wide);
                  if (wide) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: left),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: right),
                          ],
                        ),
                        const SizedBox(height: 16),
                        params,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: 16),
                      right,
                      const SizedBox(height: 16),
                      params,
                    ],
                  );
                },
              ),
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, List<String> issues) {
    final ready = issues.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              widget.isNew ? Icons.add_box_outlined : Icons.edit_note,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNew ? 'Новый товар' : 'Редактирование товара',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ready
                      ? 'Все данные заполнены — товар готов к публикации'
                      : 'Не хватает данных: ${issues.length}',
                  style: TextStyle(
                    color: ready
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFCD34D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isNew && widget.onDelete != null)
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Удалить товар?'),
                    content: Text(
                      '«${p.name}» будет удалён без возможности '
                      'восстановления.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await widget.onDelete!(p);
                  if (mounted) Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFCA5A5),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить'),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Закрыть',
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF273040) : const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {IconData? icon, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _photosCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Фотографии',
            icon: Icons.photo_library_outlined,
            trailing: Text(
              '${photos.length}/10',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedPhoto(
                            url: _mediaPhotoUrl(photos[i], widget.mediaBaseUrl),
                            width: 100,
                            height: 100,
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            left: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Главное',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: InkWell(
                            onTap: () => setState(
                              () => photos = [...photos]..removeAt(i),
                            ),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (photos.length < 10)
                  InkWell(
                    onTap: uploading ? null : _pickPhotos,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4F46E5),
                          width: 1.4,
                        ),
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                      ),
                      child: Center(
                        child: uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Добавить',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Без фото объявление не публикуется на Авито',
                style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mainCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Основное', icon: Icons.sell_outlined),
          TextField(
            controller: name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Название*',
              hintText: 'Как товар будет показан покупателю',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sku,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Артикул (SKU)*',
                    helperText: 'Уникальный ID объявления на Авито',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: size,
                  decoration: const InputDecoration(labelText: 'Размер / цвет'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: description,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Описание',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Цена', icon: Icons.payments_outlined),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: marketplace,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Цена маркетплейса, ₽',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Скидка, %'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: myPrice,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Своя цена, ₽ (переопределяет расчёт)',
              helperText: 'К публикации: ${priceValue.round()} ₽',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Себестоимость, ₽',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Количество'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Распродажа', style: TextStyle(fontSize: 13)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: saleBasePrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Старая цена, ₽',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: salePercent,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Скидка распродажи, %',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Склад и статус', icon: Icons.inventory_2_outlined),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Статус'),
            items: const [
              DropdownMenuItem(value: 'in_stock', child: Text('В наличии')),
              DropdownMenuItem(value: 'ready', child: Text('Готов к продаже')),
              DropdownMenuItem(value: 'shipped', child: Text('Отправлен')),
              DropdownMenuItem(value: 'returned', child: Text('Возврат')),
              DropdownMenuItem(value: 'sold', child: Text('Продан')),
            ],
            onChanged: (value) => setState(() => status = value ?? 'in_stock'),
          ),
          const SizedBox(height: 12),
          if (widget.deliveries.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: deliveryId.isEmpty ? null : deliveryId,
              decoration: const InputDecoration(labelText: 'Поставка'),
              items: [
                for (final delivery in widget.deliveries)
                  DropdownMenuItem(
                    value: delivery.id,
                    child: Text(
                      '#${delivery.number} ${delivery.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => deliveryId = value ?? ''),
            ),
        ],
      ),
    );
  }

  Widget _avitoCard(BuildContext context) {
    final catalog = this.catalog;
    final list = allFields;
    final required = requiredFields;
    final canPublish = catalog != null && categorySlug != null;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Публикация на Авито',
            icon: Icons.storefront_outlined,
            trailing: required.isEmpty
                ? null
                : Text(
                    '$filledRequired/${required.length} обязательных',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: filledRequired == required.length
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFB45309),
                    ),
                  ),
          ),
          InkWell(
            onTap: _pickCategory,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Категория*'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryName.trim().isEmpty
                          ? 'Выберите категорию и подкатегорию'
                          : categoryName,
                      overflow: TextOverflow.ellipsis,
                      style: categoryName.trim().isEmpty
                          ? TextStyle(color: Theme.of(context).hintColor)
                          : null,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (catalog == null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Справочник Авито не загружен — параметры категорий '
                    'недоступны.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: _loadCatalog,
                  child: const Text('Загрузить'),
                ),
              ],
            ),
          ] else if (canPublish && list.isEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Для этой категории поля ещё не загружены. '
                    'Обновите каталог.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: _loadCatalog,
                  child: const Text('Обновить'),
                ),
              ],
            ),
          ] else if (list.isNotEmpty || optionalCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Switch(
                  value: onlyRequired,
                  onChanged: (value) => setState(() => onlyRequired = value),
                ),
                const Expanded(
                  child: Text(
                    'Только обязательные параметры',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '+$optionalCount',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Поля параметров выбранной категории — во всю ширину, в 2 колонки.
  Widget _paramsCard(BuildContext context, bool wide) {
    final list = fields;
    if (categorySlug == null) return const SizedBox.shrink();
    if (list.isEmpty) {
      return _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Параметры категории', icon: Icons.tune_outlined),
            const Text(
              'Для этой категории нет параметров или они ещё не загружены.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            onlyRequired ? 'Обязательные параметры' : 'Все параметры',
            icon: Icons.tune_outlined,
            trailing: Text(
              onlyRequired
                  ? '${filledRequired}/${requiredFields.length} заполнено'
                  : '${list.length} полей',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: filledRequired == requiredFields.length
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
          if (wide)
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final field in list)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 420) / 2,
                    child: _paramField(field),
                  ),
              ],
            )
          else
            for (final field in list) _paramField(field),
        ],
      ),
    );
  }

  Widget _paramField(AvitoField field) {
    final controller = params[field.label] ??= TextEditingController(
      text: p.attributes[field.label] ?? '',
    );
    final required = field.hasRequired;
    final values = <String>[];
    for (final content in field.content) {
      for (final value in content.values) {
        final text = value is Map
            ? '${value['value'] ?? value['label'] ?? value['name'] ?? value}'
            : '$value';
        if (text.isNotEmpty && !values.contains(text)) values.add(text);
      }
    }
    final isSelect = field.content.any(
      (c) => c.fieldType == 'select' || c.fieldType == 'checkbox',
    );
    final label = '${field.label}${required ? ' *' : ''}';

    if (isSelect && values.isNotEmpty) {
      final current = controller.text.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(current) ? current : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final value in values)
              DropdownMenuItem(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => controller.text = value);
          },
        ),
      );
    }
    final numeric =
        field.content.isNotEmpty && field.content.first.dataType != 'string';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: field.content.isNotEmpty
              ? '${field.content.first.fieldType}'
                    '${field.content.first.dataType != 'string' ? ' · ${field.content.first.dataType}' : ''}'
              : null,
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF141821)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF273040)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              problems.isEmpty
                  ? 'Готово к публикации на Авито'
                  : problems.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: problems.isEmpty
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _trySave,
            icon: const Icon(Icons.check),
            label: const Text('Сохранить'),
          ),
        ],
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

/// Выбор категории Авито: пошаговый спуск по дереву + поиск.
/// Каждый шаг — маленький запрос к серверу, поэтому работает на медленной сети.
class _AvitoCategoryPickerDialog extends StatefulWidget {
  const _AvitoCategoryPickerDialog({
    required this.selectedSlug,
    required this.loadCategories,
    required this.searchCategories,
  });

  final String? selectedSlug;
  final Future<List<AvitoCategoryEntry>> Function(String parent) loadCategories;
  final Future<List<AvitoCategoryEntry>> Function(String query)
  searchCategories;

  @override
  State<_AvitoCategoryPickerDialog> createState() =>
      _AvitoCategoryPickerDialogState();
}

class _AvitoCategoryPickerDialogState
    extends State<_AvitoCategoryPickerDialog> {
  final List<AvitoCategoryEntry> path = [];
  List<AvitoCategoryEntry> items = const [];
  List<AvitoCategoryEntry> results = const [];
  bool loading = true;
  bool searching = false;
  String? error;
  Timer? debounce;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _load(String parent) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget
          .loadCategories(parent)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        items = loaded;
        loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Не удалось загрузить категории: ${err.runtimeType}';
      });
    }
  }

  void _onQueryChanged(String value) {
    query = value;
    debounce?.cancel();
    final text = value.trim();
    if (text.isEmpty) {
      setState(() {
        searching = false;
        results = const [];
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => searching = true);
      try {
        final found = await widget
            .searchCategories(text)
            .timeout(const Duration(seconds: 20));
        if (!mounted || query.trim() != text) return;
        setState(() {
          results = found;
          searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          results = const [];
          searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchMode = query.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Категория Авито'),
      content: SizedBox(
        width: 620,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Поиск категории',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 8),
            if (!searchMode && path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => path.clear());
                        _load('');
                      },
                      child: const Text('Все категории'),
                    ),
                    for (var i = 0; i < path.length - 1; i++) ...[
                      const Icon(Icons.chevron_right, size: 16),
                      TextButton(
                        onPressed: () {
                          final node = path[i];
                          setState(() {
                            path.removeRange(i + 1, path.length);
                          });
                          _load(node.slug);
                        },
                        child: Text(path[i].name),
                      ),
                    ],
                    const Icon(Icons.chevron_right, size: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        path.last.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: searchMode ? _searchList() : _levelList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  Widget _searchList() {
    if (searching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          dense: true,
          title: Text(item.name, overflow: TextOverflow.ellipsis),
          trailing: item.hasFields
              ? const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Color(0xFF16A34A),
                )
              : null,
          onTap: () => Navigator.pop(context, item),
        );
      },
    );
  }

  Widget _levelList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _load(path.isEmpty ? '' : path.last.slug),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(child: Text('Нет подкатегорий'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected =
            item.slug.isNotEmpty && item.slug == widget.selectedSlug;
        return ListTile(
          dense: true,
          selected: selected,
          leading: Icon(
            item.hasChildren ? Icons.folder_outlined : Icons.sell_outlined,
            size: 18,
            color: item.hasChildren
                ? const Color(0xFF4F46E5)
                : const Color(0xFF16A34A),
          ),
          title: Text(item.name, overflow: TextOverflow.ellipsis),
          subtitle: item.hasChildren || !item.hasFields
              ? null
              : const Text(
                  'поля загружены',
                  style: TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                ),
          trailing: item.hasChildren
              ? const Icon(Icons.chevron_right, size: 18)
              : const Icon(Icons.check, size: 18),
          onTap: () {
            if (item.hasChildren) {
              setState(() => path.add(item));
              _load(item.slug);
            } else {
              Navigator.pop(context, item);
            }
          },
        );
      },
    );
  }
}
