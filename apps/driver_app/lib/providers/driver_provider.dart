import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_services/request_repository.dart';
import 'package:shared_services/location_service.dart';
import 'package:shared_services/supabase_service.dart';
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

class DriverStatusNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  final RequestRepository _requestRepo;
  final LocationService _locationService;
  final String _driverId;
  Timer? _locationTimer;
  Timer? _backgroundOfflineTimer;
  bool _wasOnlineBeforeBackground = false;

  DriverStatusNotifier(this._requestRepo, this._locationService, this._driverId) : super(false) {
    if (_driverId.isNotEmpty) {
      WidgetsBinding.instance.addObserver(this);
      _initStatus();
    }
  }

  Future<void> _setOnlinePreference(bool isOnline) async {
    try {
      final file = File('${Directory.systemTemp.path}/cekici_driver_online_pref.txt');
      await file.writeAsString(isOnline ? 'online' : 'offline');
    } catch (_) {}
  }

  Future<bool> _getOnlinePreference() async {
    try {
      final file = File('${Directory.systemTemp.path}/cekici_driver_online_pref.txt');
      if (await file.exists()) {
        final val = await file.readAsString();
        return val == 'online';
      }
    } catch (_) {}
    return false;
  }

  Future<void> _initStatus() async {
    try {
      final prefOnline = await _getOnlinePreference();
      
      if (prefOnline) {
        // Automatically make online on reopen/relaunch
        await _requestRepo.updateDriverOnlineStatus(_driverId, true);
        state = true;
        _startLocationSharing();
      } else {
        // Sync with DB
        final data = await SupabaseService.instance.client
            .from('drivers')
            .select('is_available')
            .eq('id', _driverId)
            .maybeSingle();
        final isAvailable = data?['is_available'] as bool? ?? false;
        state = isAvailable;
        if (isAvailable) {
          _startLocationSharing();
        } else {
          _requestRepo.expireAllPendingOffersForDriver(_driverId).catchError((_) {});
        }
      }
    } catch (_) {}
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (_driverId.isEmpty) return;

    if (lifecycleState == AppLifecycleState.paused || lifecycleState == AppLifecycleState.inactive) {
      // App entered background
      if (state) {
        _wasOnlineBeforeBackground = true;
        // Start 60 minutes timer to set offline in the database
        _backgroundOfflineTimer?.cancel();
        _backgroundOfflineTimer = Timer(const Duration(minutes: 60), () async {
          try {
            await _requestRepo.updateDriverOnlineStatus(_driverId, false);
            debugPrint('Heartbeat: Marked offline due to 60 minutes background inactivity.');
          } catch (_) {}
        });
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      // App returned to foreground
      _backgroundOfflineTimer?.cancel();
      if (_wasOnlineBeforeBackground) {
        _wasOnlineBeforeBackground = false;
        // Automatically set online in database again
        _requestRepo.updateDriverOnlineStatus(_driverId, true).then((_) {
          state = true;
          _startLocationSharing();
        }).catchError((_) {});
      } else {
        // Just sync status to be safe
        _initStatus();
      }
    }
  }

  Future<void> toggleOnlineStatus() async {
    final nextStatus = !state;
    await _requestRepo.updateDriverOnlineStatus(_driverId, nextStatus);
    await _setOnlinePreference(nextStatus);
    state = nextStatus;

    if (nextStatus) {
      _startLocationSharing();
    } else {
      _stopLocationSharing();
      _backgroundOfflineTimer?.cancel();
      _wasOnlineBeforeBackground = false;
      _requestRepo.expireAllPendingOffersForDriver(_driverId).catchError((_) {});
    }
  }

  void _startLocationSharing() {
    _locationTimer?.cancel();
    
    Future<void> updateLoc() async {
      try {
        final pos = await _locationService.getCurrentLocation();
        await _requestRepo.updateDriverLocation(_driverId, pos.latitude, pos.longitude);
      } catch (_) {}
    }

    // Update location immediately on resume/activation
    updateLoc();

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await updateLoc();
    });
  }

  void _stopLocationSharing() {
    _locationTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationSharing();
    _backgroundOfflineTimer?.cancel();
    super.dispose();
  }
}

final driverStatusProvider = StateNotifierProvider<DriverStatusNotifier, bool>((ref) {
  final repo = ref.watch(requestRepositoryProvider);
  final locationService = ref.watch(locationServiceProvider);
  final user = ref.watch(currentUserProvider).value;
  return DriverStatusNotifier(repo, locationService, user?.id ?? '');
});
