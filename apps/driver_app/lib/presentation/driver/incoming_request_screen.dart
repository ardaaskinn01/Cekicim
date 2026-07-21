import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_services/rating_repository.dart';
import 'package:shared_models/request_status.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_services/routing_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class IncomingRequestScreen extends ConsumerStatefulWidget {
  final String requestId;
  
  const IncomingRequestScreen({super.key, required this.requestId});

  @override
  ConsumerState<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends ConsumerState<IncomingRequestScreen> {
  bool _isLoading = false;
  bool _hasLoadedRequest = false; // Guard: don't redirect until first real data arrives
  bool _navigationPending = false; // Guard: prevent duplicate go('/driver')
  bool _loadingTimedOut = false;
  Timer? _timer;
  Timer? _loadingTimeoutTimer;
  int _timeLeft = 15; // 15 seconds to accept

  List<LatLng> _routePoints = [];
  bool _isRouteFetched = false;
  Future<double>? _customerRatingFuture;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // If stream doesn't resolve within 5 seconds, show retry UI
    _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_hasLoadedRequest) {
        setState(() => _loadingTimedOut = true);
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        _timeoutRequest();
      }
    });
  }

  Future<void> _fetchRoute(double originLat, double originLng, double destLat, double destLng) async {
    try {
      final points = await RoutingService().getRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );
      if (mounted) {
        setState(() {
          _routePoints = points.map((p) => LatLng(p[0], p[1])).toList();
          _isRouteFetched = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest() async {
    setState(() => _isLoading = true);
    _timer?.cancel(); // Stop countdown timer
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı bulunamadı.');

      // Cancel the local notification that triggered this screen
      final notifPlugin = FlutterLocalNotificationsPlugin();
      await notifPlugin.cancelAll();

      await ref.read(requestNotifierProvider.notifier).acceptRequest(widget.requestId, user.id);
      
      if (!mounted) return;
      context.go('/driver/navigate/${widget.requestId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kabul edilemedi: $e'), backgroundColor: AppColors.error),
      );
      context.go('/driver'); // Go back to main
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _timeoutRequest() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        await ref.read(requestRepositoryProvider).updateOfferStatus(widget.requestId, user.id, 'expired');
      }
    } catch (_) {}
    if (mounted) {
      context.go('/driver');
    }
  }

  Future<void> _rejectRequest() async {
    _timer?.cancel();
    final List<String> reasons = [
      'Fiyat yetersiz',
      'Mesafe çok uzak',
      'Ekipman yetersiz',
      'Başka işim çıktı',
      'Müşteri puanı çok düşük',
    ];
    
    final selectedReason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Reddetme Nedeni', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return ListTile(
              title: Text(reason, style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, reason),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    if (selectedReason == null) {
      if (_timeLeft > 0) {
        _startTimer();
      } else {
        _timeoutRequest();
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        await ref.read(requestRepositoryProvider).updateOfferStatus(widget.requestId, user.id, 'rejected', reason: selectedReason);
      }
    } catch (_) {}
    if (mounted) {
      context.go('/driver');
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(requestStatusProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: requestAsync.when(
          loading: () {
            if (_loadingTimedOut) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Talep yüklenemedi.',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bağlantı sorunu yaşanıyor olabilir.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadingTimedOut = false;
                          _loadingTimeoutTimer?.cancel();
                          _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
                            if (mounted && !_hasLoadedRequest) setState(() => _loadingTimedOut = true);
                          });
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        if (mounted) context.go('/driver');
                      },
                      child: const Text('Ana Sayfaya Dön', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          },
          error: (err, st) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.white))),
          data: (request) {
            final user = ref.watch(currentUserProvider).value;

            // Fetch route points once when request data is available
            if (!_isRouteFetched && 
                request.destinationLat != null && 
                request.destinationLng != null) {
              _isRouteFetched = true; // prevent duplicate calls
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchRoute(
                  request.customerLat,
                  request.customerLng,
                  request.destinationLat!,
                  request.destinationLng!,
                );
              });
            }

            // Mark that we've received real data at least once
            if (!_hasLoadedRequest) {
              // Do it after build to avoid setState in build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _hasLoadedRequest = true);
              });
            }

            if (request.status != RequestStatus.awaitingAcceptance) {
              if (request.driverId == user?.id) {
                // This driver accepted it — show loading while navigating
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              // Only redirect if we have loaded the request at least once
              // (prevents race condition on first stream emission)
              if (_hasLoadedRequest && !_navigationPending) {
                _navigationPending = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Talep başka bir sürücü tarafından kabul edildi veya iptal edildi.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    context.go('/driver');
                  }
                });
              }
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final pickupLatLng = LatLng(request.customerLat, request.customerLng);
            final destLatLng = LatLng(request.destinationLat ?? 0.0, request.destinationLng ?? 0.0);

            return Stack(
              children: [
                // 1. Full screen MapWidget background
                Positioned.fill(
                  child: MapWidget(
                    initialPosition: pickupLatLng,
                    showMyLocation: false,
                    fitMarkers: true,
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup_marker'),
                        position: pickupLatLng,
                        infoWindow: const InfoWindow(title: 'Yolcu Alış Konumu'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                      Marker(
                        markerId: const MarkerId('destination_marker'),
                        position: destLatLng,
                        infoWindow: const InfoWindow(title: 'Yolcu İniş Konumu'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    polylines: {
                      if (_routePoints.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routePoints,
                          color: AppColors.primary,
                          width: 5,
                        ),
                    },
                  ),
                ),

                // 2. Floating Reject ("Reddet") Button on the map
                Positioned(
                  right: 20,
                  bottom: 300, // Positioned right above the bottom details card
                  child: FloatingActionButton.extended(
                    onPressed: _isLoading ? null : _rejectRequest,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    icon: const Icon(Icons.close, color: AppColors.error),
                    label: const Text(
                      'Reddet',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                // 3. Bottom Sheet details card
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Customer Name/Rating and Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FutureBuilder<double>(
                              future: _customerRatingFuture ??= RatingRepository().getAverageRating(request.customerId),
                              builder: (context, snap) {
                                final avg = snap.data ?? 5.0;
                                final ratingStr = snap.connectionState == ConnectionState.done
                                    ? avg.toStringAsFixed(1)
                                    : '...';
                                return Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.border,
                                      child: Icon(Icons.person, color: AppColors.textSecondary, size: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.carPlate.isNotEmpty ? request.carPlate : 'Müşteri',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              ratingStr,
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            Text(
                              PriceCalculator.formatPrice(request.price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Route detail rows matching reference design
                        Row(
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.circle, color: Colors.green, size: 16),
                                Container(
                                  width: 2,
                                  height: 24,
                                  color: Colors.grey.shade300,
                                ),
                                const Icon(Icons.location_on, color: Colors.red, size: 16),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${request.distanceKm.toStringAsFixed(1)} KM uzaklıkta',
                                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    request.customerAddress ?? 'Belirtilmedi',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    request.destinationAddress ?? 'Belirtilmedi',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (request.vehiclePhotoUrl != null && request.vehiclePhotoUrl!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.photo_camera_outlined, color: AppColors.textSecondary, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'Arıza Fotoğrafı',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      request.vehiclePhotoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                request.vehiclePhotoUrl!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Kabul Et Button with circular timer number
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _acceptRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLoading ? 'Kabul Ediliyor...' : 'Kabul Et',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                if (!_isLoading) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_timeLeft',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
