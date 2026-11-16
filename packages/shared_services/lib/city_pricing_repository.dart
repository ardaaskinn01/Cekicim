import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/city_pricing_model.dart';
import 'supabase_service.dart';

class CityPricingRepository {
  final SupabaseClient _client;

  CityPricingRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  static const List<CityPricingModel> defaultPricings = [
    CityPricingModel(
      id: 'istanbul',
      cityName: 'İstanbul',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 1,
    ),
    CityPricingModel(
      id: 'ankara',
      cityName: 'Ankara',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 2,
    ),
    CityPricingModel(
      id: 'izmir',
      cityName: 'İzmir',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 3,
    ),
    CityPricingModel(
      id: 'bursa',
      cityName: 'Bursa',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 4,
    ),
    CityPricingModel(
      id: 'antalya',
      cityName: 'Antalya',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 5,
    ),
    CityPricingModel(
      id: 'konya',
      cityName: 'Konya',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 6,
    ),
    CityPricingModel(
      id: 'adana',
      cityName: 'Adana',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 7,
    ),
    CityPricingModel(
      id: 'sanliurfa',
      cityName: 'Şanlıurfa',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 8,
    ),
    CityPricingModel(
      id: 'gaziantep',
      cityName: 'Gaziantep',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 9,
    ),
    CityPricingModel(
      id: 'kocaeli',
      cityName: 'Kocaeli',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 10,
    ),
    CityPricingModel(
      id: 'diger',
      cityName: 'Diğer İller',
      basePrice: 1500.0,
      kmPriceTier1: 200.0,
      kmPriceTier2: 150.0,
      accidentMultiplier: 1.5,
      sortOrder: 99,
    ),
  ];

  Future<List<CityPricingModel>> getCityPricings() async {
    try {
      final res = await _client
          .from('city_pricing_settings')
          .select()
          .order('sort_order', ascending: true);

      final list = (res as List).map((e) => CityPricingModel.fromJson(e)).toList();
      if (list.isEmpty) {
        return defaultPricings;
      }
      return list;
    } catch (e) {
      debugPrint('⚠️ CityPricingRepository.getCityPricings error, falling back to defaults: $e');
      return defaultPricings;
    }
  }

  Stream<List<CityPricingModel>> streamCityPricings() {
    return _client
        .from('city_pricing_settings')
        .stream(primaryKey: ['id'])
        .order('sort_order', ascending: true)
        .map((list) {
          if (list.isEmpty) return defaultPricings;
          return list.map((e) => CityPricingModel.fromJson(e)).toList();
        })
        .handleError((e) {
          debugPrint('⚠️ CityPricingRepository.streamCityPricings error: $e');
          return defaultPricings;
        });
  }

  Future<void> updateCityPricing(CityPricingModel pricing) async {
    await _client.from('city_pricing_settings').upsert({
      'id': pricing.id,
      'city_name': pricing.cityName,
      'base_price': pricing.basePrice,
      'km_price_tier1': pricing.kmPriceTier1,
      'km_price_tier2': pricing.kmPriceTier2,
      'accident_multiplier': pricing.accidentMultiplier,
      'sort_order': pricing.sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Normalizes Turkish characters to facilitate matching
  static String normalizeTurkish(String text) {
    return text
        .toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .trim();
  }

  /// Finds matching city tariff based on address or city name
  CityPricingModel matchCity(String? addressOrCity, List<CityPricingModel> list) {
    if (addressOrCity == null || addressOrCity.trim().isEmpty) {
      return _findFallback(list);
    }

    final normalized = normalizeTurkish(addressOrCity);

    // Specific aliases / districts matching
    for (final pricing in list) {
      if (pricing.cityName == 'Diğer İller') continue;
      final cityNorm = normalizeTurkish(pricing.cityName);
      if (normalized.contains(cityNorm)) {
        return pricing;
      }
    }

    // Known common districts for the key cities
    if (normalized.contains('kadikoy') ||
        normalized.contains('besiktas') ||
        normalized.contains('sisli') ||
        normalized.contains('umraniye') ||
        normalized.contains('fatih') ||
        normalized.contains('esenyurt')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('istanbul'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('cankaya') ||
        normalized.contains('yenimahalle') ||
        normalized.contains('kecioren') ||
        normalized.contains('etimesgut') ||
        normalized.contains('mamak') ||
        normalized.contains('ostim') ||
        normalized.contains('sincan')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('ankara'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('konak') ||
        normalized.contains('karsiyaka') ||
        normalized.contains('bornova') ||
        normalized.contains('buca') ||
        normalized.contains('cigli')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('izmir'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('nilufer') ||
        normalized.contains('osmangazi') ||
        normalized.contains('yildirim')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('bursa'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('muratpasa') ||
        normalized.contains('kepez') ||
        normalized.contains('konyaalti') ||
        normalized.contains('alanya')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('antalya'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('selcuklu') ||
        normalized.contains('meram') ||
        normalized.contains('karatay')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('konya'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('seyhan') ||
        normalized.contains('yuregir') ||
        normalized.contains('cukurova')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('adana'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('haliliye') ||
        normalized.contains('eyyubiye') ||
        normalized.contains('karakopru') ||
        normalized.contains('urfa')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('sanliurfa'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('sehitkamil') ||
        normalized.contains('sahinbey') ||
        normalized.contains('antep')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('gaziantep'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    if (normalized.contains('izmit') ||
        normalized.contains('gebze') ||
        normalized.contains('darica') ||
        normalized.contains('korfez')) {
      final p = list.firstWhere((p) => normalizeTurkish(p.cityName).contains('kocaeli'), orElse: () => _findFallback(list));
      if (p.cityName != 'Diğer İller') return p;
    }

    return _findFallback(list);
  }

  CityPricingModel _findFallback(List<CityPricingModel> list) {
    return list.firstWhere(
      (p) => p.cityName == 'Diğer İller' || p.id == 'diger',
      orElse: () => defaultPricings.last,
    );
  }
}
