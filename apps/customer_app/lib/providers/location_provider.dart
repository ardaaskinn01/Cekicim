import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final selectedLocationProvider = StateProvider<LatLng?>((ref) => null);

class LocationNotifier extends StateNotifier<AsyncValue<Position?>> {
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;

  LocationNotifier(this._locationService) : super(const AsyncValue.loading()) {
    initLocation();
  }

  Future<void> initLocation() async {
    state = const AsyncValue.loading();
    try {
      final position = await _locationService.getCurrentLocation();
      state = AsyncValue.data(position);
      _listenToLocationUpdates();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _listenToLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.watchPosition().listen(
      (position) {
        state = AsyncValue.data(position);
      },
      onError: (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, AsyncValue<Position?>>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});
