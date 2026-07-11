import 'app_constants.dart';

class PriceCalculator {
  static double calculatePrice(double distanceKm) {
    if (distanceKm <= AppConstants.baseKm) {
      return AppConstants.minPrice;
    }
    if (distanceKm <= 15.0) {
      final extraKm = distanceKm - AppConstants.baseKm;
      return AppConstants.minPrice + (extraKm * AppConstants.pricePerKmUpTo15);
    } else {
      final baseFifteenKmPrice = AppConstants.minPrice + (14.0 * AppConstants.pricePerKmUpTo15);
      final extraOverFifteen = distanceKm - 15.0;
      return baseFifteenKmPrice + (extraOverFifteen * AppConstants.pricePerKmAfter15);
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
