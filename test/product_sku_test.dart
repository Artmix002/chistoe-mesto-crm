import 'package:flutter_test/flutter_test.dart';
import 'package:crm/product_sku.dart';

void main() {
  test('next article follows the largest numeric article', () {
    expect(nextProductSku(['0008', '0111', 'A999', '0099']), '0112');
    expect(nextProductSku(['9999']), '10000');
    expect(nextProductSku([]), '0001');
  });

  test('duplicate articles ignore spaces, case and leading zeroes', () {
    expect(skuEquals(' 0008 ', '8'), isTrue);
    expect(skuEquals(' abc ', 'ABC'), isTrue);
    expect(skuEquals('', ''), isFalse);
    expect(skuEquals('8', '9'), isFalse);
  });
}
