import 'package:flutter_test/flutter_test.dart';
import 'package:shop_sphere/main.dart';

void main() {
  test('parses a product response and applies safe defaults', () {
    final product = Product.fromJson({
      'id': 7,
      'title': 'Demo product',
      'price': 19.5,
      'rating': 4.2,
      'images': ['https://example.com/image.jpg'],
    });

    expect(product.id, 7);
    expect(product.title, 'Demo product');
    expect(product.price, 19.5);
    expect(product.thumbnail, 'https://example.com/image.jpg');
    expect(product.category, 'uncategorized');
    expect(product.stock, 0);
  });
}
