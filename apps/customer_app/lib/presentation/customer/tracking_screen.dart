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
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/rating_widget.dart';
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
  Animation<LatLng>? _latLngAnimation;
  LatLng? _currentDriverLocation;
  double _driverBearing = 0.0;

  bool _isRealtimeSubscribed = false;

  BitmapDescriptor? _driverIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3), // Konum güncelleme aralığıyla (3sn) senkronize
      vsync: this,
    )..addListener(() {
        if (_latLngAnimation != null) {
          setState(() {
            _currentDriverLocation = _latLngAnimation!.value;
          });
        }
      });
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await _getBytesFromCanvas(100, 100, Icons.rv_hookup, AppColors.success);
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

  void _subscribeRealtime(String requestId, LatLng customerLatLng) {
    if (_isRealtimeSubscribed) return;
    _isRealtimeSubscribed = true;

    _realtimeChannel = Supabase.instance.client.channel('trip_tracking:$requestId');
    
    _realtimeChannel!.onBroadcast(
      event: 'location_update',
      callback: (payload) {
        final double lat = payload['latitude'];
        final double lng = payload['longitude'];
        final double bearing = (payload['bearing'] ?? 0.0) + 0.0;
        _onDriverLocationReceived(LatLng(lat, lng), bearing, customerLatLng);
      },
    ).subscribe();
  }

  void _onDriverLocationReceived(LatLng newLocation, double newBearing, LatLng customerLatLng) {
    if (!mounted) return;

    if (_currentDriverLocation == null) {
      _currentDriverLocation = newLocation;
      _driverBearing = newBearing;
      setState(() {});
      _fetchRouteAndETA(newLocation, customerLatLng);
      return;
    }

    // Koordinat yumuşatma animasyonunu başlat
    _latLngAnimation = LatLngTween(
      begin: _currentDriverLocation,
      end: newLocation,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.linear,
    ));

    _driverBearing = newBearing;
    _animationController!.reset();
    _animationController!.forward();

    // Rota ve ETA sorgusunu 20 saniyede bir çalıştır (API limit tasarrufu için)
    final now = DateTime.now();
    if (_lastRouteFetchTime == null ||
        now.difference(_lastRouteFetchTime!).inSeconds >= 20) {
      _lastRouteFetchTime = now;
      _fetchRouteAndETA(newLocation, customerLatLng);
    }
  }

  Future<void> _fetchRouteAndETA(LatLng driverPos, LatLng customerPos) async {
    try {
      final routeCoords = await _routingService.getRoute(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: customerPos.latitude,
        destLng: customerPos.longitude,
      );

      final etaData = await _routingService.getETA(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: customerPos.latitude,
        destLng: customerPos.longitude,
      );

      if (mounted) {
        setState(() {
          _routePoints = routeCoords.map((p) => LatLng(p[0], p[1])).toList();
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
    if (request.acceptedAt != null) {
      final difference = DateTime.now().difference(request.acceptedAt!);
      if (difference.inMinutes >= 5) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text('İptal Süresi Aşıldı', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'Sürücü talebinizi kabul edeli 5 dakikayı geçtiği için doğrudan iptal işlemi yapamazsınız. Lütfen uyuşmazlık bildirin ya da sürücüyle iletişime geçin.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Talebi İptal Et', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu talebi iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(requestNotifierProvider.notifier).cancelRequest(request.id);
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/customer');
          });
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

        final customerLatLng = LatLng(request.customerLat, request.customerLng);

        // Canlı yayın dinleyicisini başlat
        if (request.driverId != null) {
          _subscribeRealtime(request.id, customerLatLng);
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
                  _fetchRouteAndETA(activeDriverLoc, customerLatLng);
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
                  // IBAN Bilgisi: eşleşme sonrası göster
                  if ((request.status == RequestStatus.accepted ||
                          request.status == RequestStatus.inProgress) &&
                      driver.iban != null) ...
                    [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance, color: AppColors.primary, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Ödeme Bilgisi',
                                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                const Icon(Icons.lock_outline, color: AppColors.primary, size: 14),
                                const SizedBox(width: 4),
                                const Text('Güvenli', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (driver.ibanOwnerName != null)
                              Text(
                                driver.ibanOwnerName!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatIban(driver.iban!),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: driver.iban!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('IBAN panoya kopyalandı.'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, color: AppColors.accent, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hizmet bedelini tamamlanma sonrası bu hesaba transfer ediniz.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 24,
                  opacity: 0.85,
                  border: const Border(top: BorderSide(color: AppColors.border, width: 1.5)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (request.status == RequestStatus.pending || request.status == RequestStatus.awaitingAcceptance) ...[
                        const CircularProgressIndicator(color: AppColors.accent),
                        const SizedBox(height: 16),
                        Text(
                          request.status == RequestStatus.pending ? 'En yakın çekiciler aranıyor...' : 'Seçilen çekicilerden onay bekleniyor...', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        driverInfoWidget,
                         if (request.status == RequestStatus.accepted && request.completionCode != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Column(
                              children: [
                                const Text('Yolcu Biniş Doğrulama Kodu', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  request.completionCode!,
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppColors.primary),
                                ),
                                const SizedBox(height: 4),
                                const Text('Sürücü geldiğinde bu kodu vererek binişinizi onaylayın.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                      if (request.status == RequestStatus.pending || request.status == RequestStatus.awaitingAcceptance || request.status == RequestStatus.accepted)
                        OutlinedButton(
                          onPressed: () => _cancelRequest(request),
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
    final clean = iban.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
