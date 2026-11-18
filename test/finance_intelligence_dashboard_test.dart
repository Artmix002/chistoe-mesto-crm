import 'package:crm/models.dart';
import 'package:crm/widgets/finance_intelligence_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows connected money and inventory analytics', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = Product(
      id: 'p-1',
      name: 'Пуховик',
      sku: '0042',
      quantity: 2,
      purchasePrice: 600,
    );
    final sold = Product(
      id: 'p-2',
      name: 'Куртка',
      sku: '0043',
      sold: true,
      soldAt: DateTime(2026, 11, 17).millisecondsSinceEpoch,
      salePrice: 1800,
      purchasePrice: 700,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FinanceIntelligenceDashboard(
              deals: [
                Deal(
                  id: 'd-1',
                  date: '17.11.2026',
                  clientId: 'c-1',
                  clientName: 'Иван',
                  service: 'Химчистка',
                  revenue: 5000,
                  expenses: 1000,
                  workerPayout: 1200,
                  businessReserve: 500,
                  ownerProfit: 2300,
                ),
              ],
              products: [product, sold],
              deliveries: [
                Delivery(
                  id: 'delivery-1',
                  number: 1,
                  date: '17.11.2026',
                  totalCost: 2500,
                ),
              ],
              stockMovements: [
                StockMovement(
                  id: 'move-1',
                  itemId: product.id,
                  type: 'Приход',
                  quantity: 2,
                  date: '17.11.2026',
                ),
              ],
              transactions: const [
                {'date': '17.11.2026', 'amount': -300, 'comment': 'Упаковка'},
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Финансовый обзор'), findsOneWidget);
    expect(find.text('Движение денег'), findsOneWidget);
    expect(find.text('Журнал движения товара'), findsOneWidget);
    expect(find.textContaining('5 000'), findsWidgets);
    expect(find.textContaining('Пуховик'), findsWidgets);
  });
}
