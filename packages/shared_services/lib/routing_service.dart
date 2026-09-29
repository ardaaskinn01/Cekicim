import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'location_utils.dart';

class RoutingService {
  final String _googleMapsApiKey = dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');

  /// Google Distance Matrix API kullanarak canlı trafik durumuna göre mesafe ve tahmini varış süresini (ETA) döner.
  Future<Map<String, dynamic>> getETA({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (_googleMapsApiKey.isEmpty) {
      // Eğer Google API Key yoksa, OSRM üzerinden trafik bilgisi olmadan tahmini süre hesapla
      return _getETAFromOSRM(originLat, originLng, destLat, destLng);
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=$originLat,$originLng'
      '&destinations=$destLat,$destLng'
      '&mode=driving'
      '&departure_time=now'
      '&key=$_googleMapsApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['rows'] != null &&
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            data['rows'][0]['elements'].isNotEmpty) {
          
          final element = data['rows'][0]['elements'][0];
          if (element['status'] == 'OK') {
            final distanceText = element['distance']['text'] as String;
            final distanceValue = element['distance']['value'] as int; // metre cinsinden

            // Canlı trafik varsa duration_in_traffic, yoksa standart duration al
            final durationElement = element['duration_in_traffic'] ?? element['duration'];
            final durationText = durationElement['text'] as String;
            final durationValue = durationElement['value'] as int; // saniye cinsinden

            return {
              'success': true,
              'distanceText': distanceText,
              'distanceValue': distanceValue,
              'durationText': durationText,
              'durationValue': durationValue,
              'source': 'google',
            };
          }
        }
        debugPrint("Google Distance Matrix Hata Durumu: ${data['status']}");
      }
    } catch (e) {
      debugPrint("Google Distance Matrix API Hatası: $e");
    }

    // Google başarısız olursa OSRM'e fallback yap
    return _getETAFromOSRM(originLat, originLng, destLat, destLng);
  }

  /// OSRM üzerinden trafik bilgisi olmadan mesafe ve süre hesaplama (Tamamen Ücretsiz)
  Future<Map<String, dynamic>> _getETAFromOSRM(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    // OSRM koordinat formatı: [lng,lat]
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLng,$originLat;$destLng,$destLat'
      '?overview=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final double distance = route['distance'] + 0.0; // metre
          final double duration = route['duration'] + 0.0; // saniye

          final distanceKm = (distance / 1000).toStringAsFixed(1);
          final durationMin = (duration / 60).round();

          return {
            'success': true,
            'distanceText': '$distanceKm km',
            'distanceValue': distance.round(),
            'durationText': '$durationMin dk',
            'durationValue': duration.round(),
            'source': 'osrm',
          };
        }
      }
    } catch (e) {
      debugPrint("OSRM ETA Hatası: $e");
    }

    return {
      'success': false,
      'distanceText': 'Bilinmiyor',
      'distanceValue': 0,
      'durationText': 'Bilinmiyor',
      'durationValue': 0,
      'source': 'none',
    };
  }

  /// Premium 3-Tier Enterprise HGS & Toll Engine for Highways and Bridges
  Future<Map<String, dynamic>> checkTollsAndRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final distKm = LocationUtils.distanceBetween(originLat, originLng, destLat, destLng);

    // ZERO-TOLL GUARANTEE: Short local rides (< 30 km) inside city limits (e.g. Bornova 2.7 km) NEVER cross toll bridges/highways,
    // EXCEPT when crossing the Istanbul Bosphorus Strait (Asia <-> Europe)
    final minLng = originLng < destLng ? originLng : destLng;
    final maxLng = originLng > destLng ? originLng : destLng;
    final minLat = originLat < destLat ? originLat : destLat;
    final maxLat = originLat > destLat ? originLat : destLat;

    final isIstanbulBosphorusCrossing = (minLng <= 29.02 && maxLng >= 29.08) &&
                                       (minLat >= 40.85 && maxLat <= 41.30);

    if (distKm < 30.0 && !isIstanbulBosphorusCrossing) {
      return {'hasTolls': false, 'tollFee': 0.0, 'bridgeFee': 0.0, 'highwayHgsFee': 0.0};
    }

    // Tier 1: Google Directions API V2 Compute Routes & Step Inspector
    if (_googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _googleMapsApiKey,
            'X-Goog-FieldMask': 'routes.travelAdvisory.tollInfo,routes.legs.steps',
          },
          body: json.encode({
            "origin": {"location": {"latLng": {"latitude": originLat, "longitude": originLng}}},
            "destination": {"location": {"latLng": {"latitude": destLat, "longitude": destLng}}},
            "travelMode": "DRIVE",
            "extraComputations": ["TOLL_INFO"]
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            final tollInfo = route['travelAdvisory']?['tollInfo'];
            if (tollInfo != null && tollInfo['estimatedPrice'] != null) {
              final List estimatedPrices = tollInfo['estimatedPrice'];
              double totalToll = 0.0;
              for (var price in estimatedPrices) {
                final unitsStr = price['units'] as String? ?? '0';
                final nanos = (price['nanos'] as num? ?? 0) / 1e9;
                totalToll += (double.tryParse(unitsStr) ?? 0.0) + nanos;
              }
              if (totalToll > 0) {
                return {
                  'hasTolls': true,
                  'tollFee': totalToll,
                  'bridgeFee': totalToll * 0.6,
                  'highwayHgsFee': totalToll * 0.4,
                  'bridgeName': 'Paralı Otoyol / Geçiş Ücreti',
                  'details': 'Otoyol ve Geçiş HGS Ücreti (₺${totalToll.round()})',
                };
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Google Routes API Toll Hatası: $e");
      }
    }

    // Tier 2: Dynamic Spatial Geo-Corridor Toll & Bridge Fallback Matrix
    return _estimateTollsFromRoute(originLat, originLng, destLat, destLng);
  }

  Map<String, dynamic> _estimateTollsFromRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final minLat = originLat < destLat ? originLat : destLat;
    final maxLat = originLat > destLat ? originLat : destLat;
    final minLng = originLng < destLng ? originLng : destLng;
    final maxLng = originLng > destLng ? originLng : destLng;

    final distKm = LocationUtils.distanceBetween(originLat, originLng, destLat, destLng);

    // Short local rides (< 30 km) inside city limits NEVER cross toll bridges
    if (distKm < 30.0) {
      return {'hasTolls': false, 'tollFee': 0.0, 'bridgeFee': 0.0, 'highwayHgsFee': 0.0};
    }

    // Osmangazi Köprüsü koordinatı ~40.75 N. Sadece Kuzey (Kocaeli/İstanbul >= 40.70) ve Güney (Bursa/İzmir <= 40.60) arası geçişlerde tetiklenir.
    final hasNorthEndpoint = (originLat >= 40.70 || destLat >= 40.70);
    final hasSouthEndpoint = (originLat <= 40.60 || destLat <= 40.60);
    final crossesOsmangazi = hasNorthEndpoint && hasSouthEndpoint && (distKm >= 50.0);

    if (crossesOsmangazi) {
      // Resmi 2025/2026 Tarifeleri: Osmangazi Köprüsü Çekici/Minibüs Geçiş Ücreti ~₺1.270 TL + O-5 Otoyolu HGS ~₺970 TL
      double bridgeFee = 1270.0;
      double highwayHgsFee = 970.0;

      if (distKm < 150.0) {
        highwayHgsFee = 350.0;
      }

      final totalToll = bridgeFee + highwayHgsFee; // ~2.240 TL tam parkur

      return {
        'hasTolls': true,
        'tollFee': totalToll,
        'bridgeFee': bridgeFee,
        'highwayHgsFee': highwayHgsFee,
        'bridgeName': 'Osmangazi Köprüsü + O-5 Otoyolu HGS',
        'details': 'Osmangazi Köprü Ücreti (₺${bridgeFee.round()}) + O-5 Otoyol HGS Ücreti (₺${highwayHgsFee.round()})',
      };
    }

    // Check 1915 Çanakkale Köprüsü (Çanakkale Boğazı geçişi 40.34 N)
    final crossesCanakkale = (minLat <= 40.2 && maxLat >= 40.5) && (distKm >= 50.0);
    if (crossesCanakkale) {
      return {
        'hasTolls': true,
        'tollFee': 750.0,
        'bridgeFee': 550.0,
        'highwayHgsFee': 200.0,
        'bridgeName': '1915 Çanakkale Köprüsü + HGS',
        'details': 'Çanakkale Köprü Ücreti (₺550) + Malkara-Çanakkale HGS (₺200)',
      };
    }

    // Check İstanbul Boğaz Köprüleri (15 Temmuz / FSM / YSS) - Avrupa ve Anadolu yakası arası geçiş
    final crossesIstanbulBridges = (minLng <= 29.02 && maxLng >= 29.08) && (minLat >= 40.85 && maxLat <= 41.30) && (distKm >= 15.0);
    if (crossesIstanbulBridges) {
      return {
        'hasTolls': true,
        'tollFee': 250.0,
        'bridgeFee': 180.0,
        'highwayHgsFee': 70.0,
        'bridgeName': 'İstanbul Köprüleri & HGS',
        'details': 'Boğaz Köprü Geçişi (₺180) + Kuzey Marmara / Otoyol HGS (₺70)',
      };
    }

    // General Highway HGS Estimate for long-distance highway routes (> 50 km) elsewhere in Turkey
    if (distKm > 50.0) {
      final estHighwayToll = (distKm * 0.85).roundToDouble(); // Standard average highway tariff per km
      return {
        'hasTolls': true,
        'tollFee': estHighwayToll,
        'bridgeFee': 0.0,
        'highwayHgsFee': estHighwayToll,
        'bridgeName': 'Otoyol HGS Geçişi',
        'details': 'Mesafe Bazlı Otoyol HGS Geçiş Ücreti (₺${estHighwayToll.round()})',
      };
    }

    return {'hasTolls': false, 'tollFee': 0.0, 'bridgeFee': 0.0, 'highwayHgsFee': 0.0};
  }

  /// İki nokta arasındaki rota çizgisini (Polyline koordinatlarını) döner (Önce Google Directions, fallback OSRM)
  Future<List<List<double>>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (_googleMapsApiKey.isNotEmpty) {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&mode=driving'
        '&key=$_googleMapsApiKey',
      );

      try {
        final response = await http.get(googleUrl);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' &&
              data['routes'] != null &&
              (data['routes'] as List).isNotEmpty) {
            final encoded = data['routes'][0]['overview_polyline']['points'] as String;
            return compute(_decodePolylineHelper, encoded);
          }
        }
      } catch (e) {
        debugPrint("Google Directions API Rota Hatası: $e");
      }
    }

    // OSRM Fallback (Google kullanılamazsa)
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLng,$originLat;$destLng,$destLat'
      '?geometries=polyline&overview=full',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final encodedPolyline = data['routes'][0]['geometry'] as String;
          return compute(_decodePolylineHelper, encodedPolyline);
        }
      }
    } catch (e) {
      debugPrint("OSRM Rota Çizim Hatası: $e");
    }

    return [];
  }
}

/// Encoded Polyline stringini [lat, lng] koordinat listesine çözer (Top-level for compute isolate)
List<List<double>> _decodePolylineHelper(String encoded) {
  List<List<double>> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add([lat / 1E5, lng / 1E5]);
  }
  return points;
}
