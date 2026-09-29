import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationTrackingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  RealtimeChannel? _realtimeChannel;
  DateTime? _lastDbUpdateTime;

  Position? _initialPosition;
  Position? _latestPosition;
  DateTime? _trackingStartTime;
  Timer? _inactivityCheckTimer;
  VoidCallback? onInactivityDetected;
  void Function(Position pos)? onLocationUpdate;
  bool _inactivityTriggered = false;
  
  Timer? _mockTimer;

  static const double _dbUpdateIntervalSeconds = 2; // Faster DB updates during simulation

  void resetInactivityTimer() {
    _initialPosition = _latestPosition;
    _trackingStartTime = DateTime.now();
    _inactivityTriggered = false;
  }

  /// Sürücünün konumunu dinlemeyi ve canlı yayınlamayı başlatır
  Future<void> startTracking({
    required String requestId,
    required String driverId,
    VoidCallback? onInactivity,
    void Function(Position pos)? onLocationUpdate,
    bool isDebugMock = false,
    List<Map<String, double>>? mockPoints,
  }) async {
    // Eğer halihazırda takip varsa önce durdur
    await stopTracking();

    onInactivityDetected = onInactivity;
    this.onLocationUpdate = onLocationUpdate;
    _trackingStartTime = DateTime.now();
    _initialPosition = null;
    _latestPosition = null;
    _inactivityTriggered = false;

    _inactivityCheckTimer?.cancel();
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkInactivity();
    });

    // Supabase Realtime kanalı oluştur
    _realtimeChannel = _supabase.channel('trip_tracking:$requestId');
    await _realtimeChannel!.subscribe();

    if (isDebugMock) {
      // Mock Location Mode (3x Speed): Emit simulated positions every 500ms along actual route points
      final rawPoints = mockPoints ?? _getDefaultMockRoute();
      final densePoints = _interpolatePoints(rawPoints);
      int index = 0;

      _mockTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (index >= densePoints.length) {
          index = 0; // Loop the mock route for continuous testing
        }
        final pt = densePoints[index++];
        final mockPos = Position(
          latitude: pt['lat']!,
          longitude: pt['lng']!,
          timestamp: DateTime.now(),
          altitude: 0,
          accuracy: 5,
          heading: pt['heading'] ?? 90.0,
          speed: 25.0, // ~90 km/h (3x speed)
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        _handleLocationUpdate(
          position: mockPos,
          requestId: requestId,
          driverId: driverId,
        );
      });
      return;
    }

    // Android & iOS için gerçek GPS cihaz konum takibi ayarları
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // En az 3 metre hareket etmesini bekle
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Çekici konum takibi aktif. Müşteri sizi haritada canlı izliyor.",
          notificationTitle: "Hizmet Devam Ediyor",
        ),
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _handleLocationUpdate(
        position: position,
        requestId: requestId,
        driverId: driverId,
      );
    });
  }

  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * (pi / 180.0);
    final y = sin(dLng) * cos(lat2 * (pi / 180.0));
    final x = cos(lat1 * (pi / 180.0)) * sin(lat2 * (pi / 180.0)) -
              sin(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * cos(dLng);
    final brng = atan2(y, x) * (180.0 / pi);
    return (brng + 360.0) % 360.0;
  }

  List<Map<String, double>> _interpolatePoints(List<Map<String, double>> rawPoints) {
    if (rawPoints.length < 2) return rawPoints;

    final List<Map<String, double>> densePoints = [];
    for (int i = 0; i < rawPoints.length - 1; i++) {
      final p1 = rawPoints[i];
      final p2 = rawPoints[i + 1];

      final double lat1 = p1['lat']!;
      final double lng1 = p1['lng']!;
      final double lat2 = p2['lat']!;
      final double lng2 = p2['lng']!;

      final double distanceMeters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
      final double bearing = _calculateBearing(lat1, lng1, lat2, lng2);

      // Interpolate sub-points every 15 meters along route segment
      final int steps = (distanceMeters / 15.0).ceil().clamp(1, 15);

      for (int s = 0; s < steps; s++) {
        final double fraction = s / steps;
        final double interpLat = lat1 + (lat2 - lat1) * fraction;
        final double interpLng = lng1 + (lng2 - lng1) * fraction;

        densePoints.add({
          'lat': interpLat,
          'lng': interpLng,
          'heading': bearing,
        });
      }
    }

    final last = rawPoints.last;
    final prev = rawPoints[rawPoints.length - 2];
    densePoints.add({
      'lat': last['lat']!,
      'lng': last['lng']!,
      'heading': _calculateBearing(prev['lat']!, prev['lng']!, last['lat']!, last['lng']!),
    });

    return densePoints;
  }

  List<Map<String, double>> _getDefaultMockRoute() {
    return [
      {'lat': 38.4500, 'lng': 27.2000, 'heading': 45.0},
      {'lat': 38.4600, 'lng': 27.2100, 'heading': 45.0},
      {'lat': 38.4700, 'lng': 27.2200, 'heading': 45.0},
      {'lat': 38.4800, 'lng': 27.2300, 'heading': 45.0},
      {'lat': 38.4900, 'lng': 27.2400, 'heading': 45.0},
      {'lat': 38.5000, 'lng': 27.2500, 'heading': 45.0},
      {'lat': 38.5500, 'lng': 27.3000, 'heading': 45.0},
      {'lat': 38.6000, 'lng': 27.3500, 'heading': 45.0},
      {'lat': 38.7000, 'lng': 27.4000, 'heading': 45.0},
      {'lat': 38.8000, 'lng': 27.4500, 'heading': 45.0},
      {'lat': 39.0000, 'lng': 27.5000, 'heading': 45.0},
      {'lat': 39.5000, 'lng': 27.8000, 'heading': 45.0},
      {'lat': 40.0000, 'lng': 28.5000, 'heading': 45.0},
      {'lat': 40.7500, 'lng': 29.5100, 'heading': 45.0}, // Osmangazi
      {'lat': 40.9000, 'lng': 29.2000, 'heading': 45.0},
      {'lat': 41.0082, 'lng': 28.9784, 'heading': 45.0}, // İstanbul
    ];
  }

  void _checkInactivity() {
    if (_trackingStartTime == null || _inactivityTriggered) return;

    final elapsedMinutes = DateTime.now().difference(_trackingStartTime!).inMinutes;
    if (elapsedMinutes >= 5) {
      if (_initialPosition != null && _latestPosition != null) {
        final distanceMoved = Geolocator.distanceBetween(
          _initialPosition!.latitude,
          _initialPosition!.longitude,
          _latestPosition!.latitude,
          _latestPosition!.longitude,
        );

        if (distanceMoved < 20) {
          _inactivityTriggered = true;
          onInactivityDetected?.call();
        }
      } else {
        _inactivityTriggered = true;
        onInactivityDetected?.call();
      }
    }
  }

  /// Her konum güncellemesinde tetiklenen metot
  Future<void> _handleLocationUpdate({
    required Position position,
    required String requestId,
    required String driverId,
  }) async {
    _latestPosition = position;
    _initialPosition ??= position;

    onLocationUpdate?.call(position);

    final double bearing = position.heading;
    final double speed = position.speed; // m/s cinsinden gelir

    // 1. Supabase Realtime üzerinden canlı konumu Müşteriye yayınla (Broadcast)
    if (_realtimeChannel != null) {
      try {
        await _realtimeChannel!.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'bearing': bearing,
            'speed': speed,
          },
        );
      } catch (e) {
        debugPrint("Realtime Broadcast Gönderim Hatası: $e");
      }
    }

    // 2. Veritabanını 30 saniyede bir debounced olarak güncelle
    final now = DateTime.now();
    if (_lastDbUpdateTime == null ||
        now.difference(_lastDbUpdateTime!).inSeconds >= _dbUpdateIntervalSeconds) {
      _lastDbUpdateTime = now;
      
      try {
        // POINT(longitude latitude) formatı PostGIS için standarttır.
        await _supabase.from('driver_locations').upsert({
          'id': driverId,
          'location': 'POINT(${position.longitude} ${position.latitude})',
          'bearing': bearing,
          'speed': speed,
          'updated_at': now.toUtc().toIso8601String(),
        });
        await _supabase.from('drivers').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location_updated_at': now.toUtc().toIso8601String(),
        }).eq('id', driverId);
      } catch (e) {
        debugPrint("Driver location veritabanı güncelleme hatası: $e");
      }
    }
  }

  /// Takip işlemini sonlandırır
  Future<void> stopTracking() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    _inactivityCheckTimer?.cancel();
    _inactivityCheckTimer = null;
    _trackingStartTime = null;
    _initialPosition = null;
    _latestPosition = null;
    _inactivityTriggered = false;

    if (_positionSubscription != null) {
      await _positionSubscription!.cancel();
      _positionSubscription = null;
    }
    if (_realtimeChannel != null) {
      await _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _lastDbUpdateTime = null;
  }
}
