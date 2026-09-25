import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:shared_ui/widgets/dispute_dialog.dart';
import 'package:shared_services/routing_service.dart';
import 'package:shared_services/app_error_handler.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/rating_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_ui/widgets/glass_container.dart';

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> with SingleTickerProviderStateMixin {
  RealtimeChannel? _realtimeChannel;
  final RoutingService _routingService = RoutingService();
  
  // Rota ve ETA durumları
  List<LatLng> _routePoints = [];
  String? _etaDuration;
  String? _etaDistance;
  DateTime? _lastRouteFetchTime;
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
          content: const Text('Çekiciden gelen sesli aramayı yanıtlamak ister misiniz?', style: TextStyle(color: AppColors.textSecondary)),
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
                context.push('/customer/call/${request.id}');
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

  // Animasyon durumları (Konum yumuşatma için)
  AnimationController? _animationController;
  LatLng? _currentDriverLocation;
  double _driverBearing = 0.0;
  List<LatLng> _fullRoutePoints = [];

  bool _isRealtimeSubscribed = false;
  bool _isCancellationDialogShown = false;

  BitmapDescriptor? _driverIcon;
  double _currentZoom = 15.0;
  bool _isPanelVisible = true;

  List<LatLng> _trimRoutePoints(List<LatLng> fullRoute, LatLng currentPos) {
    if (fullRoute.length < 2) return fullRoute;

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < fullRoute.length; i++) {
      final dist = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        fullRoute[i].latitude,
        fullRoute[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    if (closestIndex >= fullRoute.length - 1) {
      return [currentPos, fullRoute.last];
    }
    return [currentPos, ...fullRoute.sublist(closestIndex + 1)];
  }

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker({double zoom = 15.0}) async {
    final int size = 38; // Sleek, perfectly proportioned 38x38 px canvas icon
    try {
      final icon = await _getBytesFromCanvas(size, size, Icons.rv_hookup, AppColors.success);
      if (mounted) {
        setState(() {
          _driverIcon = icon;
        });
      }
    } catch (e) {
      debugPrint("Hata custom marker oluşturulurken: $e");
    }
  }

  Future<BitmapDescriptor> _getBytesFromCanvas(int width, int height, IconData iconData, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Dış halka/gölge boyası
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2, paint);

    // Beyaz kenarlık
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2 - 2, borderPaint);

    // İkon çizimi
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: width * 0.55,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
        package: iconData.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, (height - textPainter.height) / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(width, height);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _unsubscribeRealtime() async {
    if (_realtimeChannel != null) {
      await Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  void _subscribeRealtime(ServiceRequestModel request) {
    if (_isRealtimeSubscribed) return;
    _isRealtimeSubscribed = true;

    _realtimeChannel = Supabase.instance.client.channel('trip_tracking:${request.id}');
    
    _realtimeChannel!.onBroadcast(
      event: 'location_update',
      callback: (payload) {
        final double lat = payload['latitude'];
        final double lng = payload['longitude'];
        final double bearing = (payload['bearing'] ?? 0.0) + 0.0;
        _onDriverLocationReceived(LatLng(lat, lng), bearing, request);
      },
    ).subscribe();
  }

  void _onDriverLocationReceived(LatLng newLocation, double newBearing, ServiceRequestModel request) {
    if (!mounted) return;

    if (_currentDriverLocation == null) {
      _currentDriverLocation = newLocation;
      _driverBearing = newBearing;
      if (_fullRoutePoints.isNotEmpty) {
        _routePoints = _trimRoutePoints(_fullRoutePoints, newLocation);
      }
      setState(() {});
      _fetchRouteAndETA(newLocation, request);
      return;
    }

    final double distanceMeters = Geolocator.distanceBetween(
      _currentDriverLocation!.latitude,
      _currentDriverLocation!.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    if (distanceMeters < 0.5) {
      if (newBearing > 0 && newBearing != _driverBearing) {
        setState(() {
          _driverBearing = newBearing;
        });
      }
      return;
    }

    // Direct 1.5s interval update (eliminates 60 FPS full-screen re-render lag)
    setState(() {
      _currentDriverLocation = newLocation;
      if (newBearing > 0) {
        _driverBearing = newBearing;
      }
      if (_fullRoutePoints.isNotEmpty) {
        _routePoints = _trimRoutePoints(_fullRoutePoints, newLocation);
      }
    });

    // Throttle heavy network route recalculations to once every 15 seconds to keep map 60 FPS smooth
    final now = DateTime.now();
    if (_lastRouteFetchTime == null || now.difference(_lastRouteFetchTime!).inSeconds >= 15) {
      _lastRouteFetchTime = now;
      _fetchRouteAndETA(newLocation, request);
    }
  }

  RequestStatus? _lastStatus;

  Future<void> _fetchRouteAndETA(LatLng driverPos, ServiceRequestModel request) async {
    try {
      double destLat = request.customerLat;
      double destLng = request.customerLng;

      if (request.status == RequestStatus.inProgress &&
          request.destinationLat != null &&
          request.destinationLng != null) {
        destLat = request.destinationLat!;
        destLng = request.destinationLng!;
      }

      final routeCoords = await _routingService.getRoute(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: destLat,
        destLng: destLng,
      );

      final etaData = await _routingService.getETA(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: destLat,
        destLng: destLng,
      );

      if (mounted) {
        setState(() {
          _fullRoutePoints = routeCoords.map((p) => LatLng(p[0], p[1])).toList();
          _routePoints = _trimRoutePoints(_fullRoutePoints, driverPos);
          if (etaData['success'] == true) {
            _etaDistance = etaData['distanceText'];
            _etaDuration = etaData['durationText'];
          }
        });
      }
    } catch (e) {
      debugPrint("Rota/ETA çekilirken hata: $e");
    }
  }



  Future<void> _cancelRequest(ServiceRequestModel request) async {
    // 1. Eğer henüz bir sürücü kabul etmemişse (eşleşme yoksa), direkt basit onay diyalogu göster
    if (request.driverId == null || request.status == RequestStatus.awaitingAcceptance) {
      final confirmCancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Talebi İptal Et', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: const Text(
            'Çekici talebinizi iptal etmek istediğinize emin misiniz?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Talebi İptal Et'),
            ),
          ],
        ),
      );

      if (confirmCancel != true) return;

      try {
        await ref.read(requestNotifierProvider.notifier).cancelRequest(
          request.id,
          'Müşteri eşleşme öncesi vazgeçti',
        );
        if (mounted) {
          context.go('/customer');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppErrorHandler.parse(e)), backgroundColor: AppColors.error),
          );
        }
      }
      return;
    }

    // 2. Eğer eşleşme sağlanmışsa (sürücü kabul etmişse), detaylı iptal nedeni modalını aç
    if (request.acceptedAt != null) {
      final difference = DateTime.now().difference(request.acceptedAt!);
      if (difference.inMinutes >= 5) {
        final confirmForce = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text('İptal Süresi Aşıldı', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'Sürücü talebinizi kabul edeli 5 dakikayı geçti. Yine de iptal etmek istiyor musunuz?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Yine de Devam Et'),
              ),
            ],
          ),
        );
        if (confirmForce != true) return;
      }
    }

    final List<String> customerReasons = [
      '💸 Fiyat Uyuşmazlığı',
      '⏱️ Sürücü Çok Gecikti / Hareketsiz Kaldı',
      '🚗 Yanlış Konum / Adres Değişikliği',
      '🛠️ Sorun Kendiliğinden Çözüldü / Vazgeçtim',
      '❓ Diğer',
    ];

    if (!mounted) return;
    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? chosen;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Talebi İptal Etme Nedeni',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Lütfen iptal etme nedeninizi seçin:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ...customerReasons.map((reason) {
                      return RadioListTile<String>(
                        value: reason,
                        groupValue: chosen,
                        activeColor: AppColors.error,
                        contentPadding: EdgeInsets.zero,
                        title: Text(reason, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        onChanged: (val) {
                          setModalState(() => chosen = val);
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: chosen == null
                                ? null
                                : () => Navigator.pop(ctx, chosen),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            child: const Text('İptal Et'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (selectedReason == null) return;

    try {
      await ref.read(requestNotifierProvider.notifier).cancelRequest(request.id, selectedReason);
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

    ref.listen<AsyncValue<ServiceRequestModel>>(requestStatusProvider(requestId), (prev, next) {
      final request = next.value;
      final user = ref.read(currentUserProvider).value;
      if (request != null && user != null) {
        if (request.activeCallChannel != null && request.activeCallCallerId != user.id) {
          if (GoRouterState.of(context).uri.path != '/customer/call/$requestId') {
            _showIncomingCallDialog(context, request);
          }
        } else if (request.activeCallChannel == null && _incomingCallDialogContext != null) {
          Navigator.pop(_incomingCallDialogContext!);
          _incomingCallDialogContext = null;
        }
      }
    });

    final requestAsync = ref.watch(requestStatusProvider(requestId));

    return requestAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent))),
      error: (err, st) => Scaffold(body: Center(child: Text('Hata: $err'))),
      data: (request) {
        if (request.status == RequestStatus.cancelled) {
          if (!_isCancellationDialogShown) {
            _isCancellationDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Talep İptal Edildi', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                    content: Text(
                      request.cancellationReason != null && request.cancellationReason!.isNotEmpty
                          ? 'Bu hizmet talebi iptal edilmiştir.\n\nİptal Nedeni: ${request.cancellationReason}'
                          : 'Bu hizmet talebi iptal edilmiştir.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          context.go('/customer');
                        },
                        child: const Text('Tamam', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
            });
          }
          return const Scaffold();
        }

        if (request.status == RequestStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/customer/rate/${request.id}/${request.driverId ?? ""}');
            }
          });
          return const Scaffold();
        }

        if (_lastStatus != request.status) {
          _lastStatus = request.status;
          _routePoints = [];
          _etaDuration = null;
          _lastRouteFetchTime = null;
        }

        final customerLatLng = LatLng(request.customerLat, request.customerLng);

        // Canlı yayın dinleyicisini başlat
        if (request.driverId != null) {
          _subscribeRealtime(request);
        }

        Set<Marker> markers = {
          Marker(
            markerId: const MarkerId('customer'),
            position: customerLatLng,
            infoWindow: const InfoWindow(title: 'Siz'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        };

        Set<Polyline> polylines = {};

        // OSRM Rotası varsa haritaya ekle
        if (_routePoints.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: AppColors.accent,
              width: 5,
            ),
          );
        }

        Widget driverInfoWidget = const SizedBox();

        if (request.driverId != null) {
          final driverAsync = ref.watch(driverLocationProvider(request.driverId!));
          driverInfoWidget = driverAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (err, st) => const Text('Sürücü bilgisi alınamadı.'),
            data: (driver) {
              final activeDriverLoc = _currentDriverLocation ?? 
                  (driver.latitude != null && driver.longitude != null 
                      ? LatLng(driver.latitude!, driver.longitude!) 
                      : null);

              if (activeDriverLoc != null && _etaDuration == null && _routePoints.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fetchRouteAndETA(activeDriverLoc, request);
                });
              }

              if (activeDriverLoc != null) {
                LatLng displayLoc = activeDriverLoc;
                if (activeDriverLoc.latitude == customerLatLng.latitude && 
                    activeDriverLoc.longitude == customerLatLng.longitude) {
                  // Eşleşme testinde üst üste binmemesi için 15-20 metre kuzeydoğuya ötele
                  displayLoc = LatLng(activeDriverLoc.latitude + 0.00015, activeDriverLoc.longitude + 0.00015);
                }
                markers.add(
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: displayLoc,
                    rotation: _driverBearing,
                    anchor: const Offset(0.5, 0.5), // Merkezden dönüş için
                    infoWindow: const InfoWindow(title: 'Çekici'),
                    icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
                        radius: 26,
                        backgroundColor: AppColors.surface,
                        backgroundImage: driver.avatarUrl != null ? NetworkImage(driver.avatarUrl!) : null,
                        child: driver.avatarUrl == null ? const Icon(Icons.person, color: AppColors.textPrimary) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.fullName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 4),
                            RatingWidget(rating: driver.rating, isReadOnly: true, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  // ETA ve Kalan Mesafe Bilgisi (Gerçek Zamanlı Trafik)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.timer_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            _etaDuration ?? 'Hesaplanıyor...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Text('Tahmini Varış', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      Container(height: 30, width: 1, color: AppColors.divider),
                      Column(
                        children: [
                          const Icon(Icons.navigation_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            _etaDistance ?? 'Hesaplanıyor...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Text('Kalan Mesafe', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      if (request.price > 0) ...[
                        Container(height: 30, width: 1, color: AppColors.divider),
                        Column(
                          children: [
                            const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              '₺${request.price.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                            ),
                            Text(
                              request.tollFee > 0 ? 'Ücret (HGS Dahil)' : 'Ücret',
                              style: TextStyle(
                                color: request.tollFee > 0 ? AppColors.warning : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: request.tollFee > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (request.tollFee > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🛣️ Rotanızda paralı geçiş tespit edildi (+₺${request.tollFee.round()} Osmangazi Köprü + O-5 Otoyol HGS Ücreti Dahildir).',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  // IBAN Bilgisi: eşleşme sonrası göster
                  if ((request.status == RequestStatus.accepted ||
                          request.status == RequestStatus.inProgress) &&
                      driver.iban != null) ...
                    [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance, color: AppColors.primary, size: 14),
                                const SizedBox(width: 6),
                                const Text(
                                  'Ödeme Bilgisi',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                const Icon(Icons.lock_outline, color: AppColors.primary, size: 12),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (driver.ibanOwnerName != null)
                              Text(
                                driver.ibanOwnerName!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatIban(driver.iban!),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: driver.iban!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('IBAN panoya kopyalandı.'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.copy, color: AppColors.accent, size: 15),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
                onZoomChanged: (zoom) {
                  if ((zoom - _currentZoom).abs() > 0.8) {
                    _currentZoom = zoom;
                    _loadCustomMarker(zoom: zoom);
                  }
                },
              ),
              // Sol üst: geri butonu
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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
              // Eylemsizlik / Hareketsizlik Uyarısı Kılavuz Kartı
              if (request.status == RequestStatus.accepted &&
                  request.acceptedAt != null &&
                  DateTime.now().difference(request.acceptedAt!).inMinutes >= 5) ...[
                Positioned(
                  top: 70,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.orange.withValues(alpha: 0.95),
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ℹ️ Çekici sürücünüz 5 dakikadır sabit konumda bekliyor.',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push('/customer/call/${request.id}?initiator=true'),
                                  icon: const Icon(Icons.phone_in_talk, size: 16),
                                  label: const Text('Sürücüyü Ara', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _cancelRequest(request),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('Talebi İptal Et', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // Floating action column for VoIP Call, Chat, and Dispute
              if (request.driverId != null)
                Positioned(
                  right: 20,
                  top: 120, // Positioned at top right to avoid being covered by bottom sheet
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chat Button
                      FloatingActionButton.small(
                        heroTag: 'chat_action',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: () => context.push('/customer/chat/${request.id}'),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      ),
                      const SizedBox(height: 12),
                      // VoIP Phone Button
                      FloatingActionButton.small(
                        heroTag: 'call_action',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: () => context.push('/customer/call/${request.id}?initiator=true'),
                        child: const Icon(Icons.phone_in_talk_outlined, size: 20),
                      ),
                      const SizedBox(height: 12),
                      // Dispute Button
                      FloatingActionButton.small(
                        heroTag: 'dispute_action',
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        onPressed: () => _reportDispute(request.id, request.driverId!),
                        child: const Icon(Icons.gavel_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Toggle button — ortada, yuvarlak, arkaplanı saydam
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _isPanelVisible = !_isPanelVisible),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPanelVisible ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isPanelVisible ? 'Gizle' : 'Bilgileri Göster',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: _isPanelVisible
                          ? GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              borderRadius: 24,
                              opacity: 0.85,
                              border: const Border(top: BorderSide(color: AppColors.border, width: 1.5)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (request.status == RequestStatus.pending || request.status == RequestStatus.awaitingAcceptance) ...[
                                    const CircularProgressIndicator(color: AppColors.accent),
                                    const SizedBox(height: 12),
                                    Text(
                                      request.status == RequestStatus.pending ? 'En yakın çekiciler aranıyor...' : 'Çekicilerden onay bekleniyor...', 
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    driverInfoWidget,
                                    if (request.status == RequestStatus.accepted && request.completionCode != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.primary),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.qr_code_2, color: AppColors.primary, size: 16),
                                            const SizedBox(width: 8),
                                            const Text('Doğrulama Kodu:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text(
                                              request.completionCode!,
                                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                  ],
                                  if (request.status == RequestStatus.pending || request.status == RequestStatus.awaitingAcceptance || request.status == RequestStatus.accepted)
                                    OutlinedButton(
                                      onPressed: () => _cancelRequest(request),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        minimumSize: const Size.fromHeight(46),
                                      ),
                                      child: const Text('Talebi İptal Et'),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reportDispute(String requestId, String driverId) {
    // Get client user ID from supabase auth directly
    final client = Supabase.instance.client;
    final reporterId = client.auth.currentUser?.id;
    if (reporterId == null) return;

    showDisputeDialog(
      context: context,
      onSubmit: (title, description) async {
        final dispute = DisputeModel(
          id: '',
          requestId: requestId,
          reporterId: reporterId,
          reportedId: driverId,
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

  /// IBAN'ı okunabilir formatta gösterir (TR00 0000 0000 ...)
  String _formatIban(String iban) {
    String clean = iban.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length > 26) {
      clean = clean.substring(0, 26);
    }
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
