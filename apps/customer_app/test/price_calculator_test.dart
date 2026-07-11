import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/price_calculator.dart';

void main() {
  group('PriceCalculator Tests', () {
    test('0.5 km test', () {
      expect(PriceCalculator.calculatePrice(0.5), equals(2000.0));
    });

    test('1.0 km test', () {
      expect(PriceCalculator.calculatePrice(1.0), equals(2000.0));
    });

    test('3.0 km test', () {
      expect(PriceCalculator.calculatePrice(3.0), equals(2400.0));
    });

    test('10.0 km test', () {
      expect(PriceCalculator.calculatePrice(10.0), equals(3800.0));
    });

    test('12.0 km test (> 10 km tier test)', () {
      expect(PriceCalculator.calculatePrice(12.0), equals(4200.0));
    });
  });
}
