import 'app_constants.dart';

class PriceCalculator {
  static double calculatePrice(double distanceKm) {
    if (distanceKm <= AppConstants.baseKm) {
      return AppConstants.minPrice;
    }
    if (distanceKm <= 10.0) {
      final extraKm = distanceKm - AppConstants.baseKm;
      return AppConstants.minPrice + (extraKm * AppConstants.pricePerKm);
    } else {
      final baseTenKmPrice = AppConstants.minPrice + (9.0 * AppConstants.pricePerKm);
      final extraOverTen = distanceKm - 10.0;
      return baseTenKmPrice + (extraOverTen * 100.0);
    }
  }

  static String formatPrice(double price) {
    final intPrice = price.round();
    final buffer = StringBuffer();
    final str = intPrice.toString();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '₺${buffer.toString()}';
  }
}
