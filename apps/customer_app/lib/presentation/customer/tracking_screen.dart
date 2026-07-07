import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/request_status.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/rating_widget.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await ref.read(requestNotifierProvider.notifier).cancelRequest(requestId);
      if (mounted) {
        context.go('/customer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = GoRouterState.of(context).pathParameters['requestId'];
    if (requestId == null) {
      return const Scaffold(body: Center(child: Text('Talep bulunamadı.')));
    }

    final requestAsync = ref.watch(requestStatusProvider(requestId));

    return requestAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent))),
      error: (err, st) => Scaffold(body: Center(child: Text('Hata: $err'))),
      data: (request) {
        if (request.status == RequestStatus.cancelled || request.status == RequestStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/customer');
          });
          return const Scaffold();
        }

        final customerLatLng = LatLng(request.customerLat, request.customerLng);
        Set<Marker> markers = {
          Marker(
            markerId: const MarkerId('customer'),
            position: customerLatLng,
            infoWindow: const InfoWindow(title: 'Siz'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        };

        Set<Polyline> polylines = {};

        Widget driverInfoWidget = const SizedBox();

        if (request.driverId != null) {
          final driverAsync = ref.watch(driverLocationProvider(request.driverId!));
          driverInfoWidget = driverAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (err, st) => const Text('Sürücü bilgisi alınamadı.'),
            data: (driver) {
              if (driver.latitude != null && driver.longitude != null) {
                final driverLatLng = LatLng(driver.latitude!, driver.longitude!);
                markers.add(
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: driverLatLng,
                    infoWindow: const InfoWindow(title: 'Çekici'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                );
                polylines.add(
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [customerLatLng, driverLatLng],
                    color: AppColors.accent,
                    width: 4,
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: driver.avatarUrl != null ? NetworkImage(driver.avatarUrl!) : null,
                        child: driver.avatarUrl == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            RatingWidget(rating: driver.rating, isReadOnly: true, size: 16),
                          ],
                        ),
                      ),
                      if (driver.phone != null)
                        IconButton(
                          onPressed: () => _makePhoneCall(driver.phone!),
                          icon: const Icon(Icons.phone, color: AppColors.accent),
                          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                        ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Araç Plakası', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(driver.vehiclePlate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          request.status == RequestStatus.inProgress ? 'Geldi' : 'Yolda',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              MapWidget(
                initialPosition: customerLatLng,
                markers: markers,
                polylines: polylines,
                showMyLocation: false,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface.withAlpha(220), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/customer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (request.status == RequestStatus.pending) ...[
                        const CircularProgressIndicator(color: AppColors.accent),
                        const SizedBox(height: 16),
                        const Text('En yakın çekiciler aranıyor...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                      ] else ...[
                        driverInfoWidget,
                        const SizedBox(height: 24),
                      ],
                      if (request.status == RequestStatus.pending || request.status == RequestStatus.accepted)
                        OutlinedButton(
                          onPressed: () => _cancelRequest(request.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text('Talebi İptal Et'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
