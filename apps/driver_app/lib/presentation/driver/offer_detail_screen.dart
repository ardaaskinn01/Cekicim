import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/app_constants.dart';
import 'package:shared_ui/price_calculator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/green_button.dart';

class OfferDetailScreen extends ConsumerStatefulWidget {
  const OfferDetailScreen({super.key});

  @override
  ConsumerState<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends ConsumerState<OfferDetailScreen> {
  int _secondsLeft = AppConstants.offerTimeoutSeconds;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _rejectOffer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _acceptOffer() async {
    final requestId = GoRouterState.of(context).pathParameters['requestId'];
    if (requestId == null) return;

    setState(() => _isProcessing = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final repo = ref.read(requestRepositoryProvider);
        await repo.acceptOffer(requestId, user.id);
        _timer?.cancel();
        if (mounted) {
          context.go('/driver/navigate/$requestId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectOffer() async {
    final requestId = GoRouterState.of(context).pathParameters['requestId'];
    if (requestId == null) return;

    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final repo = ref.read(requestRepositoryProvider);
        await repo.rejectOffer(requestId, user.id);
      }
    } catch (_) {}
    _timer?.cancel();
    if (mounted) {
      context.go('/driver');
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = GoRouterState.of(context).pathParameters['requestId'];
    if (requestId == null) {
      return const Scaffold(body: Center(child: Text('Geçersiz teklif.')));
    }

    final requestAsync = ref.watch(requestStatusProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Yol Yardım Teklifi')),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, st) => Center(child: Text('Yüklenemedi: $err')),
        data: (req) {
          final customerLatLng = LatLng(req.customerLat, req.customerLng);

          return Stack(
            children: [
              MapWidget(
                initialPosition: customerLatLng,
                markers: {
                  Marker(
                    markerId: const MarkerId('customer'),
                    position: customerLatLng,
                    infoWindow: const InfoWindow(title: 'Müşteri Konumu'),
                  ),
                },
                showMyLocation: false,
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
                      LinearProgressIndicator(
                        value: _secondsLeft / AppConstants.offerTimeoutSeconds,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${req.carBrand} ${req.carModel}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text('Arıza Tipi: ${req.problemType}', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                          Text(
                            PriceCalculator.formatPrice(req.price),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : _rejectOffer,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                minimumSize: const Size.fromHeight(50),
                              ),
                              child: const Text('Reddet'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GreenButton(
                              text: 'Kabul Et',
                              onPressed: _isProcessing ? null : _acceptOffer,
                              isLoading: _isProcessing,
                            ),
                          ),
                        ],
                      ),
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
