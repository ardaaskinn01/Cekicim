import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
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
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_services/notification_service.dart';
import 'package:shared_services/alarm_audio_service.dart';
import '../../providers/request_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  Timer? _verificationPollTimer;
  String? _lastNavigatedOfferId;
  BitmapDescriptor? _towTruckIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _startVerificationPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        NotificationService().setupFCM(user.id);
      }
    });
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await _getBytesFromCanvas(36, 36, Icons.rv_hookup, AppColors.accent);
      if (mounted) {
        setState(() {
          _towTruckIcon = icon;
        });
      }
    } catch (e) {
      debugPrint("Hata custom marker oluşturulurken: $e");
    }
  }

  Future<BitmapDescriptor> _getBytesFromCanvas(int width, int height, IconData iconData, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2 - 1.5, borderPaint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: width * 0.6,
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
    _verificationPollTimer?.cancel();
    super.dispose();
  }

  void _startVerificationPolling() {
    _verificationPollTimer?.cancel();
    _verificationPollTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      final user = ref.read(currentUserProvider).value;
      if (user is DriverModel && !user.isVerified) {
        // Invalidate current user provider to force reload from Supabase
        ref.invalidate(currentUserProvider);
        ref.read(authNotifierProvider.notifier).loadCurrentUser();
      } else if (user is DriverModel && user.isVerified) {
        _verificationPollTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final driver = user is DriverModel ? user : null;
    final isOnline = ref.watch(driverStatusProvider);
    final locationAsync = ref.watch(locationProvider);

    final activeReq = ref.watch(activeRequestProvider).value;
    final isOnDuty = activeReq != null &&
        activeReq.status != RequestStatus.completed &&
        activeReq.status != RequestStatus.cancelled;

    // Auto redirect to active request navigation screen when active request exists
    ref.listen<AsyncValue<ServiceRequestModel?>>(activeRequestProvider, (prev, next) {
      final req = next.value;
      if (req != null && req.status != RequestStatus.completed && req.status != RequestStatus.cancelled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/driver/navigate/${req.id}');
          }
        });
      }
    });

    // Watch pending offers — guard against duplicate pushes or ringing when on duty
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(pendingOffersProvider, (prev, next) {
      if (isOnDuty || !isOnline) return;
      final list = next.value;
      if (list != null && list.isNotEmpty) {
        final offer = list.first;
        final reqId = offer['request_id'] as String;
        // Only navigate if we haven't already navigated for this offer
        if (_lastNavigatedOfferId != reqId) {
          _lastNavigatedOfferId = reqId;
          // Play alarm sound and start looping audio when offer arrives while app is in foreground
          AlarmAudioService().startAlarm();
          NotificationService().showLocalNotification(
            '🚨 Yeni Yol Yardım Talebi!',
            'Yakınınızda yeni bir talep var. Hemen inceleyin!',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.push('/driver/offer/$reqId');
          });
        }
      } else if (list != null && list.isEmpty) {
        // List is empty — reset so next offer can be navigated to
        _lastNavigatedOfferId = null;
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
            error: (err, st) => _buildLocationErrorState(err.toString()),
            data: (pos) {
              if (pos == null) {
                return _buildLocationErrorState('Konum bilgisi alınamadı.');
              }
              final latLng = LatLng(pos.latitude, pos.longitude);

              return MapWidget(
                initialPosition: latLng,
                showMyLocation: false,
                fitMarkers: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('driver_current_position'),
                    position: latLng,
                    infoWindow: const InfoWindow(title: 'Benim Konumum'),
                    icon: _towTruckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  ),
                },
              );
            },
          ),
          if (isOnline)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Card(
                color: Colors.orange.withValues(alpha: 0.95),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⚠️ Uygulamayı arka planda açık tut! Kapatırsan talep alamazsın.',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        driver.rejectionReason != null && driver.rejectionReason!.isNotEmpty
                            ? Icons.error_outline_rounded
                            : Icons.hourglass_empty_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              driver.rejectionReason != null && driver.rejectionReason!.isNotEmpty
                                  ? 'Başvurunuz Reddedildi: ${driver.rejectionReason}'
                                  : 'Evraklarınız inceleniyor. Yönetici onayından sonra çevrimiçi olabilirsiniz.',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            if (driver.rejectionReason != null && driver.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => context.go('/driver/onboarding'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Evrakları Düzenle & Yeniden Gönder',
                                    style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (activeReq != null && activeReq.status != RequestStatus.completed && activeReq.status != RequestStatus.cancelled)
            Positioned(
              left: 24,
              right: 24,
              bottom: 110,
              child: InkWell(
                onTap: () => context.go('/driver/navigate/${activeReq.id}'),
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  color: AppColors.primary,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              '🚨 Aktif Göreve Dön',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                      ],
                    ),
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
                          : (val) async {
                              /*
                              // AWS Rekognition Yüz Doğrulama Altyapısı (Test Sürecinde Yorum Satırında):
                              // Çevrimiçi açılırken canlı selfie isteyip sürücü belgesindeki fotoğrafla eşleştirir:
                              if (val == true) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lütfen canlı selfie doğrulamasını tamamlayın...')),
                                  );
                                }
                                final result = await FaceVerificationService.instance.captureAndVerifySelfie(driver.id);
                                if (!result.isMatch) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.error ?? 'Yüz eşleşmedi! Çevrimiçi olunamadı.'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                  return; // Yüz eşleşmezse çevrimiçi olma
                                }
                              }
                              */

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

  Widget _buildLocationErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Konum Erişimi Başarısız',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(locationProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
