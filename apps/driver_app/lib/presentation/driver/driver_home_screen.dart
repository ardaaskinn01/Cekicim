import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/driver_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/driver_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final driver = user is DriverModel ? user : null;
    final isOnline = ref.watch(driverStatusProvider);
    final locationAsync = ref.watch(locationProvider);

    // Watch pending offers
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(pendingOffersProvider, (prev, next) {
      final list = next.value;
      if (list != null && list.isNotEmpty) {
        final offer = list.first;
        final reqId = offer['request_id'] as String;
        context.push('/driver/offer/$reqId');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isOnline ? 'Çevrimiçi (Saha)' : 'Çevrimdışı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/driver/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/driver/history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          locationAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (err, st) => Center(child: Text('Konum yüklenemedi: $err')),
            data: (pos) {
              if (pos == null) return const Center(child: Text('Konum bulunamadı.'));
              final latLng = LatLng(pos.latitude, pos.longitude);

              return MapWidget(
                initialPosition: latLng,
                showMyLocation: true,
              );
            },
          ),
          if (driver != null && !driver.isVerified)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Card(
                color: AppColors.error.withValues(alpha: 0.95),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Evraklarınız inceleniyor. Yönetici onayından sonra çevrimiçi olabilirsiniz.',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: Card(
              color: AppColors.cardBackground.withAlpha(235),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          driver?.fullName ?? 'Sürücü',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          driver?.vehiclePlate ?? 'Plaka Yok',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: isOnline,
                      activeColor: AppColors.accent,
                      onChanged: (driver == null || !driver.isVerified)
                          ? null
                          : (val) {
                              ref.read(driverStatusProvider.notifier).toggleOnlineStatus();
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
