import 'package:barcode/barcode.dart';
import 'package:crm/models.dart';
import 'package:crm/order_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes the Avito tracking number as Code 128 data', () {
    final order = Order(
      id: 'order-1',
      number: 70000000563884053,
      barcode: '805 118 276 93796',
    );

    final data = labelBarcodeData(order);

    expect(data, '80511827693796');
    expect(
      Barcode.code128().toSvg(data, width: 530, height: 85, drawText: false),
      contains('<svg'),
    );
  });

  test('uses the CRM order number when Avito has no tracking number yet', () {
    final order = Order(id: 'order-2', number: 70000000563884053);

    expect(labelBarcodeData(order), '70000000563884053');
  });

  test('shows the carrier saved with the Avito order', () {
    expect(
      orderDeliveryService(
        Order(
          id: 'order-3',
          source: 'avito',
          comment: 'Отправьте заказ · СДЭК',
        ),
      ),
      'СДЭК',
    );
    expect(
      orderDeliveryService(
        Order(id: 'order-4', source: 'avito', comment: 'Почта России'),
      ),
      'Почта России',
    );
    expect(
      orderDeliveryService(
        Order(id: 'order-6', source: 'avito', comment: 'Яндекс Маркет'),
      ),
      'Яндекс',
    );
    expect(
      orderDeliveryService(Order(id: 'order-5', source: 'avito')),
      'Авито',
    );
  });

  test('shows a pickup point only for returns', () {
    final outgoing = Order(
      id: 'outgoing',
      source: 'avito',
      pvz: 'Рязань, Лермонтова 9/2',
    );
    final returned = Order(
      id: 'returned',
      source: 'avito',
      status: 'returned',
      pvz: 'Рязань, Лермонтова 9/2',
    );

    expect(isOrderReturn(outgoing), isFalse);
    expect(isOrderReturn(returned), isTrue);
  });

  testWidgets('keeps the outgoing label focused on shipping data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final outgoing = Order(
      id: 'outgoing',
      number: 70000000567181749,
      source: 'avito',
      comment: 'Отправьте заказ · Яндекс Доставка',
      product: 'Женская куртка',
      article: '0042',
      barcode: 'P03925503878',
      pvz: 'Рязань, Лермонтова 9/2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showOrderLabels(context, [outgoing], title: 'Этикетка'),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('ЯНДЕКС'), findsOneWidget);
    expect(find.text('Рязань, Лермонтова 9/2'), findsNothing);
    expect(find.textContaining('70000000567181749'), findsNothing);
  });

  testWidgets('creates a 58 by 40 mm label PDF with the embedded font', (
    tester,
  ) async {
    final pdf = await buildOrderLabelsPdf([
      Order(
        id: 'order-3',
        number: 70000000557555307,
        product: 'Пуховик женский',
        article: '0042',
        barcode: '10347765591',
        pvz: 'Рязань, улица Лермонтова, 9/2',
      ),
    ]);

    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
