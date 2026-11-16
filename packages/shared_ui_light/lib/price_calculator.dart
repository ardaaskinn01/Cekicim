import 'package:shared_models/city_pricing_model.dart';
import 'app_constants.dart';

class PriceCalculator {
  static double calculatePrice(
    double distanceKm, {
    CityPricingModel? cityPricing,
    bool isAccident = false,
    double tollFee = 0.0,
  }) {
    if (cityPricing != null) {
      return cityPricing.calculatePrice(
        distanceKm: distanceKm,
        isAccident: isAccident,
        tollFee: tollFee,
      );
    }

    // Fallback using AppConstants defaults if no city pricing provided
    double price = AppConstants.minPrice;
    if (distanceKm > AppConstants.baseKm) {
      if (distanceKm <= 15.0) {
        final extraKm = distanceKm - AppConstants.baseKm;
        price += extraKm * AppConstants.pricePerKmUpTo15;
      } else {
        final baseFifteenKmPrice = AppConstants.minPrice + (14.0 * AppConstants.pricePerKmUpTo15);
        final extraOverFifteen = distanceKm - 15.0;
        price = baseFifteenKmPrice + (extraOverFifteen * AppConstants.pricePerKmAfter15);
      }
    }

    if (isAccident) {
      price = price * 1.5;
    }

    final roundedBase = (price / 50).round() * 50.0;
    return roundedBase + tollFee;
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
