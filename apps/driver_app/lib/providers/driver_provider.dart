import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_services/request_repository.dart';
import 'package:shared_services/location_service.dart';
import 'auth_provider.dart';
import 'location_provider.dart';
import 'request_provider.dart';

final pendingOffersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.value;
  if (user == null) return Stream.value([]);

  final repo = ref.watch(requestRepositoryProvider);
  return repo.watchPendingOffersForDriver(user.id);
});

class DriverStatusNotifier extends StateNotifier<bool> {
  final RequestRepository _requestRepo;
  final LocationService _locationService;
  final String _driverId;
  Timer? _locationTimer;

  DriverStatusNotifier(this._requestRepo, this._locationService, this._driverId) : super(false);

  Future<void> toggleOnlineStatus() async {
    final nextStatus = !state;
    await _requestRepo.updateDriverOnlineStatus(_driverId, nextStatus);
    state = nextStatus;

    if (nextStatus) {
      _startLocationSharing();
    } else {
      _stopLocationSharing();
    }
  }

  void _startLocationSharing() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final pos = await _locationService.getCurrentLocation();
        await _requestRepo.updateDriverLocation(_driverId, pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  void _stopLocationSharing() {
    _locationTimer?.cancel();
  }

  @override
  void dispose() {
    _stopLocationSharing();
    super.dispose();
  }
}

final driverStatusProvider = StateNotifierProvider<DriverStatusNotifier, bool>((ref) {
  final repo = ref.watch(requestRepositoryProvider);
  final locationService = ref.watch(locationServiceProvider);
  final user = ref.watch(currentUserProvider).value;
  return DriverStatusNotifier(repo, locationService, user?.id ?? '');
});
