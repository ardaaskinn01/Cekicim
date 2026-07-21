import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/rating_model.dart';
import 'package:shared_services/rating_repository.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_ui/widgets/rating_widget.dart';

class RateCustomerScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String customerId;
  final String customerName;

  const RateCustomerScreen({
    super.key,
    required this.requestId,
    required this.customerId,
    required this.customerName,
  });

  @override
  ConsumerState<RateCustomerScreen> createState() => _RateCustomerScreenState();
}

class _RateCustomerScreenState extends ConsumerState<RateCustomerScreen> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _ratingText {
    switch (_rating.round()) {
      case 5:
        return 'Harika! Kusursuz Bir Yolculuk';
      case 4:
        return 'Çok İyi, Memnun Kaldım';
      case 3:
        return 'Normal / Ortalama';
      case 2:
        return 'Kötü / Memnun Kalmadım';
      case 1:
        return 'Çok Kötü / Kabul Edilemez';
      default:
        return '';
    }
  }

  Color get _ratingColor {
    switch (_rating.round()) {
      case 5:
        return AppColors.success;
      case 4:
        return Colors.greenAccent;
      case 3:
        return Colors.orangeAccent;
      case 2:
        return Colors.orange;
      case 1:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _submitRating() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final ratingObj = RatingModel(
          id: '',
          requestId: widget.requestId,
          raterId: user.id,
          ratedId: widget.customerId,
          score: _rating.round(),
          comment: _commentController.text.trim(),
          createdAt: DateTime.now(),
        );

        final ratingRepo = RatingRepository();
        await ratingRepo.submitRating(ratingObj);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Değerlendirmeniz başarıyla iletildi.'), backgroundColor: AppColors.success),
          );
          context.go('/driver');
        }
      }
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString().replaceAll('Exception: ', '');
        if (errMsg.contains('zaten değerlendirme')) {
          context.go('/driver');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Değerlendirme gönderiliyor...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Müşteriyi Değerlendir'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  
                  // Decorative Glow Card Wrapper
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Column(
                      children: [
                        // Customer Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 40,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Customer Name
                        Text(
                          widget.customerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        const Text(
                          'Hizmet verdiğiniz müşteriyi puanlayıp geri bildirimde bulunarak topluluk güvenliğini artırın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 36),
                        
                        // Star Rating Bar
                        Center(
                          child: RatingWidget(
                            rating: _rating,
                            onRatingChanged: (newRating) {
                              setState(() => _rating = newRating);
                            },
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Dynamic Descriptive Rating Text
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _ratingColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _ratingColor.withValues(alpha: 0.25), width: 1),
                          ),
                          child: Text(
                            _ratingText,
                            style: TextStyle(
                              color: _ratingColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Comment Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 4,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Müşteri veya yolculuk hakkında eklemek istediğiniz yorum... (İsteğe bağlı)',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        border: InputBorder.none,
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 50.0),
                          child: Icon(Icons.rate_review_outlined, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Button
                  GreenButton(
                    text: 'Değerlendirmeyi Gönder',
                    onPressed: _submitRating,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
