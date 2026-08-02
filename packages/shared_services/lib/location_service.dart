import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Türkiye genel başlangıç fallback konumu
  static const double defaultLat = 39.9208;
  static const double defaultLng = 32.8541;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentLocation() async {
    try {
      return await Future.any([
        _getCurrentLocationInternal(),
        Future.delayed(const Duration(seconds: 4)).then((_) => throw TimeoutException('Location request timed out')),
      ]);
    } catch (e) {
      // Fallback: Gerçek cihazın son bilinen konumunu al
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
      if (lastKnown != null) {
        return lastKnown;
      }
      return Position(
        latitude: defaultLat,
        longitude: defaultLng,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
        isMocked: false,
      );
    }
  }

  Future<Position> _getCurrentLocationInternal() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
      return Position(
        latitude: defaultLat,
        longitude: defaultLng,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
        isMocked: false,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 4),
      );
    } catch (e) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      rethrow;
    }
  }

  Stream<Position> watchPosition() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}
