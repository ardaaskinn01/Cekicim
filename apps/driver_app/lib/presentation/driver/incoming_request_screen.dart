import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_services/rating_repository.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_services/notification_service.dart';
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
  Timer? _timer;
  int _timeLeft = 30; // 30 seconds to accept

  Future<double>? _customerRatingFuture;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Play the alarm sound locally via local notifications
    NotificationService().showLocalNotification(
      'YENİ YOL YARDIM TALEBİ',
      'Yakınınızda yeni bir çekici talebi var. Kabul etmek için tıklayın.',
    ).catchError((e) {
      debugPrint('Error triggering alarm sound in foreground: $e');
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı bulunamadı.');

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
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, st) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.white))),
          data: (request) {
            final user = ref.watch(currentUserProvider).value;
            if (request.status != RequestStatus.awaitingAcceptance) {
              if (request.driverId == user?.id) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
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
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final progressValue = _timeLeft / 30.0;
            final timerColor = _timeLeft < 10 ? AppColors.error : AppColors.primary;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Circular Countdown Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: progressValue,
                          strokeWidth: 6,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_timeLeft',
                            style: TextStyle(
                              fontSize: 26, 
                              fontWeight: FontWeight.w900, 
                              color: timerColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const Text(
                            'SANİYE',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'YENİ TALEBİNİZ VAR',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.w900, 
                      color: AppColors.textPrimary, 
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: AppColors.cardBackground,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Müşteri puanı
                          FutureBuilder<double>(
                            future: _customerRatingFuture ??= RatingRepository().getAverageRating(request.customerId),
                            builder: (context, snap) {
                              final avg = snap.data ?? 5.0;
                              return Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary, size: 20),
                                  const SizedBox(width: 10),
                                  const Text('Müşteri Puanı', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        snap.connectionState == ConnectionState.done
                                            ? avg.toStringAsFixed(1)
                                            : '...',
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const Divider(color: AppColors.border, height: 28),
                          _buildInfoRow(
                            Icons.directions_car_filled_outlined,
                            'Araç Tipi',
                            request.vehicleType ?? 'Bilinmiyor',
                          ),
                          const Divider(color: AppColors.border, height: 28),
                          _buildInfoRow(
                            Icons.navigation_outlined,
                            'Mesafe',
                            '${request.distanceKm.toStringAsFixed(1)} km',
                          ),
                          const Divider(color: AppColors.border, height: 28),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Hedef Sanayi',
                            request.destinationIndustryZone ?? 'Bilinmiyor',
                          ),
                          const Divider(color: AppColors.border, height: 28),
                          // Earning display banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: AppColors.primary, size: 22),
                                const SizedBox(width: 10),
                                const Text(
                                  'Tahmini Kazanç', 
                                  style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  PriceCalculator.formatPrice(request.price),
                                  style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _rejectRequest,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                            foregroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Reddet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GreenButton(
                          text: _isLoading ? 'Kabul Ediliyor...' : 'Kabul Et',
                          onPressed: _isLoading ? null : _acceptRequest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
