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

class CustomerRatingScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String driverId;
  final String driverName;

  const CustomerRatingScreen({
    super.key,
    required this.requestId,
    required this.driverId,
    required this.driverName,
  });

  @override
  ConsumerState<CustomerRatingScreen> createState() => _CustomerRatingScreenState();
}

class _CustomerRatingScreenState extends ConsumerState<CustomerRatingScreen> {
  double _score = 5.0;
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
      if (user == null) return;

      final rating = RatingModel(
        id: '',
        requestId: widget.requestId,
        raterId: user.id,
        ratedId: widget.driverId,
        score: _score.toInt(),
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      final repo = RatingRepository();
      await repo.submitRating(rating);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirmeniz alındı. Teşekkür ederiz!'), backgroundColor: AppColors.success),
      );
      context.go('/customer');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Gönderiliyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Hizmeti Değerlendir')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 72, color: AppColors.accent),
                const SizedBox(height: 16),
                const Text(
                  'Hizmetiniz Tamamlandı!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.driverName} sunduğu çekici hizmetini nasıl buldunuz?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Center(
                  child: RatingWidget(
                    rating: _score,
                    size: 40,
                    onRatingChanged: (newRating) {
                      setState(() => _score = newRating);
                    },
                  ),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _commentController,
                  label: 'Yorumunuz (İsteğe Bağlı)',
                  hint: 'Sürücü ve hizmet hakkında düşünceleriniz...',
                  prefixIcon: Icons.rate_review_outlined,
                ),
                const Spacer(),
                GreenButton(
                  text: 'Puanla ve Bitir',
                  onPressed: _submitRating,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/customer'),
                  child: const Text('Şimdi Değil', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
