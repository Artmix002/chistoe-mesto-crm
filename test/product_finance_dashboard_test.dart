import 'package:crm/models.dart';
import 'package:crm/widgets/product_finance_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows product margin, inventory and delivery payback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final soldAt = DateTime(2026, 11, 17);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showProductAccounting(
                context,
                deliveries: [
                  Delivery(
                    id: 'd-1',
                    number: 12,
                    name: 'Зимняя одежда',
                    totalCost: 3000,
                  ),
                ],
                products: [
                  Product(
                    id: 'sold',
                    name: 'Пуховик',
                    sku: '0042',
                    deliveryId: 'd-1',
                    sold: true,
                    soldAt: soldAt.millisecondsSinceEpoch,
                    salePrice: 2500,
                    purchasePrice: 1000,
                  ),
                  Product(
                    id: 'stock',
                    name: 'Куртка',
                    sku: '0043',
                    deliveryId: 'd-1',
                    quantity: 2,
                    purchasePrice: 800,
                  ),
                ],
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Бухгалтерия товаров'), findsOneWidget);
    expect(find.text('Выручка товаров'), findsOneWidget);
    expect(find.text('Окупаемость поставок'), findsOneWidget);
    expect(find.text('Проданные товары'), findsOneWidget);
    expect(find.textContaining('0042'), findsWidgets);
  });
}
