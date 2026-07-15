import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  /// İki nokta arasındaki rota çizgisini (Polyline koordinatlarını) döner (OSRM kullanarak ücretsiz)
  Future<List<List<double>>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // OSRM koordinatları: [lng,lat]
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
