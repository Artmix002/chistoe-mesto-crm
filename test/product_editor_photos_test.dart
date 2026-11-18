import 'package:crm/avito_catalog.dart';
import 'package:crm/models.dart';
import 'package:crm/widgets/product_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('photo links are not requested as category fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const requiredInput = AvitoFieldContent(
      fieldType: 'input',
      dataType: 'string',
      required: true,
    );
    const catalog = AvitoCatalogData(
      categories: [],
      fields: {
        'test': [
          AvitoField(
            tag: 'ImageUrls',
            label: 'Ссылки на фото',
            content: [requiredInput],
          ),
          AvitoField(
            tag: 'ImageNames',
            label: 'Названия фото',
            content: [requiredInput],
          ),
          AvitoField(tag: 'Brand', label: 'Бренд', content: [requiredInput]),
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProductEditorScreen(
          product: Product(
            id: '1',
            name: 'Товар',
            sku: '0001',
            attributes: {'avito_slug': 'test'},
          ),
          isNew: true,
          catalog: catalog,
          catalogLoaded: true,
          deliveries: const [],
          mediaBaseUrl: '',
          isSkuTaken: (_) => false,
          onSave: (_) async {},
          onDelete: null,
        ),
      ),
    );
    expect(find.text('Ссылки на фото'), findsNothing);
    expect(find.text('Названия фото'), findsNothing);
    expect(find.textContaining('Бренд'), findsWidgets);
  });

  testWidgets('loaded clothing sizes are selectable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const options = AvitoFieldContent(
      fieldType: 'select',
      dataType: 'string',
      required: true,
      values: [
        {'value': '48'},
        {'value': '50'},
      ],
      valuesLinkJson: 'https://api.avito.ru/example',
    );
    final restored = AvitoFieldContent.fromJson(options.toJson());
    expect(restored.valuesLinkJson, options.valuesLinkJson);
    const catalog = AvitoCatalogData(
      categories: [],
      fields: {
        'clothing': [
          AvitoField(tag: 'Size', label: 'Размер', content: [options]),
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProductEditorScreen(
          product: Product(
            id: '1',
            name: 'Куртка',
            sku: '0001',
            attributes: {'avito_slug': 'clothing'},
          ),
          isNew: true,
          catalog: catalog,
          catalogLoaded: true,
          deliveries: const [],
          mediaBaseUrl: '',
          isSkuTaken: (_) => false,
          onSave: (_) async {},
          onDelete: null,
        ),
      ),
    );
    await tester.tap(
      find
          .ancestor(
            of: find.text('Размер *'),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('48'), findsWidgets);
    expect(find.text('50'), findsWidgets);
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();
    expect(find.text('50'), findsWidgets);
  });
}
