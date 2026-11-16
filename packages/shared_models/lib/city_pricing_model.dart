class CityPricingModel {
  final String id;
  final String cityName;
  final double basePrice;
  final double kmPriceTier1; // 0 - 15 km
  final double kmPriceTier2; // 15+ km
  final double accidentMultiplier; // e.g. 1.5
  final int sortOrder;

  const CityPricingModel({
    required this.id,
    required this.cityName,
    this.basePrice = 1500.0,
    this.kmPriceTier1 = 200.0,
    this.kmPriceTier2 = 150.0,
    this.accidentMultiplier = 1.5,
    this.sortOrder = 99,
  });

  factory CityPricingModel.fromJson(Map<String, dynamic> json) {
    return CityPricingModel(
      id: json['id'] as String? ?? '',
      cityName: json['city_name'] as String? ?? 'Diğer İller',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 1500.0,
      kmPriceTier1: (json['km_price_tier1'] as num?)?.toDouble() ?? 200.0,
      kmPriceTier2: (json['km_price_tier2'] as num?)?.toDouble() ?? 150.0,
      accidentMultiplier: (json['accident_multiplier'] as num?)?.toDouble() ?? 1.5,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 99,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'city_name': cityName,
    'base_price': basePrice,
    'km_price_tier1': kmPriceTier1,
    'km_price_tier2': kmPriceTier2,
    'accident_multiplier': accidentMultiplier,
    'sort_order': sortOrder,
  };

  CityPricingModel copyWith({
    String? id,
    String? cityName,
    double? basePrice,
    double? kmPriceTier1,
    double? kmPriceTier2,
    double? accidentMultiplier,
    int? sortOrder,
  }) {
    return CityPricingModel(
      id: id ?? this.id,
      cityName: cityName ?? this.cityName,
      basePrice: basePrice ?? this.basePrice,
      kmPriceTier1: kmPriceTier1 ?? this.kmPriceTier1,
      kmPriceTier2: kmPriceTier2 ?? this.kmPriceTier2,
      accidentMultiplier: accidentMultiplier ?? this.accidentMultiplier,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Calculates total estimated price based on distance, breakdown vs accident, and toll fee
  double calculatePrice({
    required double distanceKm,
    bool isAccident = false,
    double tollFee = 0.0,
  }) {
    double price = basePrice;
    if (distanceKm > 1.0) {
      if (distanceKm <= 15.0) {
        price += (distanceKm - 1.0) * kmPriceTier1;
      } else {
        price += (14.0 * kmPriceTier1) + ((distanceKm - 15.0) * kmPriceTier2);
      }
    }
    if (isAccident) {
      price = price * accidentMultiplier;
    }
    // Round to nearest 50 TL step for clean customer presentation
    final roundedBase = (price / 50).round() * 50.0;
    return roundedBase + tollFee;
  }
}
