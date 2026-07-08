import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_services/rating_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _startTimer();
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
      context.go('/driver/active'); // Or whatever the active route is
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
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 80, color: AppColors.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'YENİ TALEP',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 2),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Müşteri puanı
                          FutureBuilder<double>(
                            future: RatingRepository().getAverageRating(request.customerId),
                            builder: (context, snap) {
                              final avg = snap.data ?? 5.0;
                              final count = snap.connectionState == ConnectionState.done ? '' : '';
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Müşteri Puanı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
                                      Text(count, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const Divider(color: AppColors.border, height: 24),
                          _buildInfoRow('Araç Tipi', request.vehicleType ?? 'Bilinmiyor'),
                          const Divider(color: AppColors.border, height: 24),
                          _buildInfoRow('Mesafe', '${request.distanceKm.toStringAsFixed(1)} km'),
                          const Divider(color: AppColors.border, height: 24),
                          _buildInfoRow('Hedef', request.destinationIndustryZone ?? 'Bilinmiyor'),
                          const Divider(color: AppColors.border, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Kazanç', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                              Text(
                                PriceCalculator.formatPrice(PriceCalculator.calculatePrice(request.distanceKm)),
                                style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '$_timeLeft sn içinde yanıtlayın',
                    style: TextStyle(
                      color: _timeLeft < 10 ? AppColors.error : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _rejectRequest,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reddet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GreenButton(
                          text: _isLoading ? 'Bekleyin...' : 'Kabul Et',
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
