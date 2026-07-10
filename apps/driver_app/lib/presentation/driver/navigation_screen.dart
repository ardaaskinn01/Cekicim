import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_launcher/map_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:shared_ui/widgets/dispute_dialog.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_services/location_tracking_service.dart';
import 'package:shared_services/routing_service.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/green_button.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final String requestId;
  const NavigationScreen({super.key, required this.requestId});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  bool _isActionLoading = false;
  final LocationTrackingService _trackingService = LocationTrackingService();
  final RoutingService _routingService = RoutingService();
  List<LatLng> _routePoints = [];
  bool _isTrackingStarted = false;
  BuildContext? _incomingCallDialogContext;

  void _showIncomingCallDialog(BuildContext context, ServiceRequestModel request) {
    if (_incomingCallDialogContext != null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _incomingCallDialogContext = dialogContext;
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.phone_in_talk, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Gelen Arama', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: const Text('Müşteriden gelen sesli aramayı yanıtlamak ister misiniz?', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () async {
                _incomingCallDialogContext = null;
                Navigator.pop(dialogContext);
                try {
                  await ref.read(requestRepositoryProvider).updateCallStatus(request.id, null, null);
                } catch (_) {}
              },
              child: const Text('Reddet', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                _incomingCallDialogContext = null;
                Navigator.pop(dialogContext);
                context.push('/driver/call/${request.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cevapla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((_) {
      _incomingCallDialogContext = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _initTrackingAndRouting();
  }

  Future<void> _initTrackingAndRouting() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final driver = ref.read(currentUserProvider).value;
        if (driver != null && !_isTrackingStarted) {
          // Arka plan konum yayınını başlat
          await _trackingService.startTracking(
            requestId: widget.requestId,
            driverId: driver.id,
          );
          _isTrackingStarted = true;
        }
        // OSRM rotasını çiz
        _loadRoute();
      } catch (e) {
        debugPrint("Hata konum takibi başlatılırken: $e");
      }
    });
  }

  Future<void> _loadRoute() async {
    try {
      final req = await ref.read(requestRepositoryProvider).getRequestById(widget.requestId);

      final driverPos = await Geolocator.getCurrentPosition();
      final routeCoords = await _routingService.getRoute(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: req.customerLat,
        destLng: req.customerLng,
      );

      if (mounted) {
        setState(() {
          _routePoints = routeCoords.map((p) => LatLng(p[0], p[1])).toList();
        });
      }
    } catch (e) {
      debugPrint("Hata OSRM rotası çizilirken: $e");
    }
  }

  @override
  void dispose() {
    _trackingService.stopTracking();
    super.dispose();
  }

  Future<void> _updateStatus(ServiceRequestModel request, RequestStatus nextStatus) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateRequestStatus(request.id, nextStatus);

      if (nextStatus == RequestStatus.completed) {
        await _trackingService.stopTracking();
        final customerProfile = await AuthRepository().getUserProfile(request.customerId);
        if (!mounted) return;
        final customerName = customerProfile?.fullName ?? 'Müşteri';
        context.go('/driver/rate/${request.id}/${request.customerId}?name=$customerName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _openExternalNavigation(double lat, double lng, String name) async {
    try {
      final availableMaps = await launcher.MapLauncher.installedMaps;
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.cardBackground,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Navigasyon Uygulaması Seçin',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                    ),
                    const Divider(color: AppColors.divider),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableMaps.length,
                        itemBuilder: (context, index) {
                          final map = availableMaps[index];
                          return ListTile(
                            onTap: () {
                              map.showDirections(
                                destination: launcher.Coords(lat, lng),
                                destinationTitle: name,
                              );
                              Navigator.pop(context);
                            },
                            title: Text(map.mapName, style: const TextStyle(color: AppColors.textPrimary)),
                            leading: SvgPicture.asset(
                              map.icon.toString(),
                              width: 32,
                              height: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigasyon başlatılamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _reportDispute(ServiceRequestModel req) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    showDisputeDialog(
      context: context,
      onSubmit: (title, description) async {
        final dispute = DisputeModel(
          id: '',
          requestId: req.id,
          reporterId: user.id,
          reportedId: req.customerId,
          title: title,
          description: description,
          createdAt: DateTime.now(),
        );
        await DisputeRepository().createDispute(dispute);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sorun başarıyla bildirildi.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ServiceRequestModel>>(requestStatusProvider(widget.requestId), (prev, next) {
      final request = next.value;
      final user = ref.read(currentUserProvider).value;
      if (request != null && user != null) {
        if (request.activeCallChannel != null && request.activeCallCallerId != user.id) {
          if (GoRouterState.of(context).uri.path != '/driver/call/${widget.requestId}') {
            _showIncomingCallDialog(context, request);
          }
        } else if (request.activeCallChannel == null && _incomingCallDialogContext != null) {
          Navigator.pop(_incomingCallDialogContext!);
          _incomingCallDialogContext = null;
        }
      }
    });

    final requestAsync = ref.watch(requestStatusProvider(widget.requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Navigasyon & Rota')),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, st) => Center(child: Text('Yüklenemedi: $err')),
        data: (req) {
          final customerLatLng = LatLng(req.customerLat, req.customerLng);

          // Bir sonraki aksiyon durumunu belirleme
          String buttonText = '';
          RequestStatus? nextStatus;
          if (req.status == RequestStatus.accepted) {
            buttonText = 'Müşteriye Ulaştım (Hizmet Başladı)';
            nextStatus = RequestStatus.inProgress;
          } else if (req.status == RequestStatus.inProgress) {
            buttonText = 'Hizmeti Tamamla (İndirildi)';
            nextStatus = RequestStatus.completed;
          }

          return Stack(
            children: [
              MapWidget(
                initialPosition: customerLatLng,
                markers: {
                  Marker(
                    markerId: const MarkerId('customer'),
                    position: customerLatLng,
                    infoWindow: const InfoWindow(title: 'Müşteri Rota Hedefi'),
                  ),
                },
                polylines: _routePoints.isNotEmpty
                    ? {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routePoints,
                          color: AppColors.accent,
                          width: 5,
                        ),
                      }
                    : {},
                showMyLocation: true,
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
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<UserModel?>(
                                future: AuthRepository().getUserProfile(req.customerId),
                                builder: (context, userSnapshot) {
                                  final name = userSnapshot.data?.fullName ?? 'Müşteri Yükleniyor...';
                                  return Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text('Telefon: ${req.customerPhone ?? 'Belirtilmedi'}', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                          if (req.customerPhone != null) ...[
                            IconButton(
                              icon: const Icon(Icons.chat_bubble, color: AppColors.accent, size: 28),
                              onPressed: () => context.push('/driver/chat/${req.id}'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk, color: AppColors.accent, size: 28),
                              onPressed: () => context.push('/driver/call/${req.id}?initiator=true'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Yol Tarifi Al (Harita Entegrasyonu) Butonu
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openExternalNavigation(
                                req.customerLat,
                                req.customerLng,
                                req.customerAddress ?? 'Müşteri Konumu',
                              ),
                              icon: const Icon(Icons.navigation_outlined, color: AppColors.accent),
                              label: const Text('Yol Tarifi Al', style: TextStyle(color: AppColors.accent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _reportDispute(req),
                        icon: const Icon(Icons.gavel_rounded, color: AppColors.error),
                        label: const Text('Sorun / Uyuşmazlık Bildir', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (nextStatus != null)
                        GreenButton(
                          text: buttonText,
                          onPressed: _isActionLoading ? null : () => _updateStatus(req, nextStatus!),
                          isLoading: _isActionLoading,
                        )
                      else
                        const Text('Talep tamamlandı veya iptal edildi.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
