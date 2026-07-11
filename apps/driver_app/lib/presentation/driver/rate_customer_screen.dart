import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/rating_model.dart';
import 'package:shared_services/rating_repository.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
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

  Future<void> _submitRating() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
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
        appBar: AppBar(title: const Text('Müşteriyi Değerlendir')),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    widget.customerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hizmet verdiğiniz müşteriyi puanlayıp geri bildirimde bulunun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: RatingWidget(
                      rating: _rating,
                      onRatingChanged: (newRating) {
                        setState(() => _rating = newRating);
                      },
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _commentController,
                    label: 'Müşteri hakkında yorum yazın (İsteğe bağlı)',
                    prefixIcon: Icons.comment_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 48),
                  GreenButton(
                    text: 'Puanla & Bitir',
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
