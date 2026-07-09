import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Izmir center (Kordon/Konak)
  static const double izmirLat = 38.4237;
  static const double izmirLng = 27.1428;

  // Ankara center (Kizilay)
  static const double ankaraLat = 39.9208;
  static const double ankaraLng = 32.8541;

  // Stable seed offset based on device identity hash, to keep this device on a stable Ankara location
  static final double _stableSeedOffsetLat = (Random().nextDouble() - 0.5) * 0.015; // ~1.5km max offset
  static final double _stableSeedOffsetLng = (Random().nextDouble() - 0.5) * 0.020;

  /// Helper to convert any incoming Position to the corresponding mock Ankara position.
  static Position _mockToAnkara(Position pos) {
    // 1. Check if the coordinates are already within Ankara bounds
    // Rough bounding box for Ankara province: Lat 39.3 to 40.5, Lng 32.0 to 33.8
    final bool isInAnkara = (pos.latitude >= 39.3 && pos.latitude <= 40.5) &&
                            (pos.longitude >= 32.0 && pos.longitude <= 33.8);

    if (isInAnkara) {
      // If already in Ankara, keep the actual position as is
      return pos;
    }

    // 2. If not in Ankara, apply mock/offset simulation
    // Determine if it is the emulator's default US location (Googleplex/Mountain View ~37.42, -122.08)
    final bool isEmulatorUS = (pos.latitude > 37.0 && pos.latitude < 38.0) && 
                              (pos.longitude > -123.0 && pos.longitude < -121.0);

    double mockLat;
    double mockLng;

    if (isEmulatorUS || pos.latitude.abs() < 1.0) {
      // US emulator position gets mapped to a stable randomized Ankara center
      mockLat = ankaraLat + _stableSeedOffsetLat;
      mockLng = ankaraLng + _stableSeedOffsetLng;
    } else {
      // If near Izmir (bounding box Lat 38.0 to 39.0, Lng 26.0 to 28.5), relatively translate it to Ankara
      final bool isNearIzmir = (pos.latitude >= 38.0 && pos.latitude <= 39.0) &&
                               (pos.longitude >= 26.0 && pos.longitude <= 28.5);

      if (isNearIzmir) {
        final double deltaLat = pos.latitude - izmirLat;
        final double deltaLng = pos.longitude - izmirLng;
        mockLat = ankaraLat + deltaLat;
        mockLng = ankaraLng + deltaLng;
      } else {
        // Any other place gets a stable randomized Ankara coordinate
        mockLat = ankaraLat + _stableSeedOffsetLat;
        mockLng = ankaraLng + _stableSeedOffsetLng;
      }
    }

    return Position(
      latitude: mockLat,
      longitude: mockLng,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
      altitude: pos.altitude,
      altitudeAccuracy: pos.altitudeAccuracy,
      heading: pos.heading,
      headingAccuracy: pos.headingAccuracy,
      speed: pos.speed,
      speedAccuracy: pos.speedAccuracy,
      floor: pos.floor,
      isMocked: true,
    );
  }

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
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      // If no permission, return a default simulated Ankara position instead of throwing
      return Position(
        latitude: ankaraLat + _stableSeedOffsetLat,
        longitude: ankaraLng + _stableSeedOffsetLng,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
        isMocked: true,
      );
    }

    final realPos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return _mockToAnkara(realPos);
  }

  Stream<Position> watchPosition() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .map((realPos) => _mockToAnkara(realPos));
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} (Ankara Bölgesi)';
  }
}
