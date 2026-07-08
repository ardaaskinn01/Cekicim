import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationTrackingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  RealtimeChannel? _realtimeChannel;
  DateTime? _lastDbUpdateTime;
  
  static const double _dbUpdateIntervalSeconds = 30;

  /// Sürücünün konumunu dinlemeyi ve canlı yayınlamayı başlatır
  Future<void> startTracking({
    required String requestId,
    required String driverId,
  }) async {
    // Eğer halihazırda takip varsa önce durdur
    await stopTracking();

    // Supabase Realtime kanalı oluştur
    _realtimeChannel = _supabase.channel('trip_tracking:$requestId');
    await _realtimeChannel!.subscribe();

    // Android & iOS için arka plan konum takibi ayarları
    // Android'de uygulamayı arka plana aldığımızda bildirim çekmecesinde "Konum Takip Ediliyor" gösterilecek.
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // En az 3 metre hareket etmesini bekle
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Çekici konum takibi aktif. Müşteri sizi haritada canlı izliyor.",
        notificationTitle: "Hizmet Devam Ediyor",
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _handleLocationUpdate(
        position: position,
        requestId: requestId,
        driverId: driverId,
      );
    }, onError: (error) {
      debugPrint("Konum Takibi Hatası: $error");
    });
  }

  /// Her konum güncellemesinde tetiklenen metot
  Future<void> _handleLocationUpdate({
    required Position position,
    required String requestId,
    required String driverId,
  }) async {
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
      } catch (e) {
        debugPrint("Driver location veritabanı güncelleme hatası: $e");
      }
    }
  }

  /// Takip işlemini sonlandırır
  Future<void> stopTracking() async {
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
