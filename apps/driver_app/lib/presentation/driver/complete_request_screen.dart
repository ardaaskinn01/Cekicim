import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import '../../providers/request_provider.dart';

class CompleteRequestScreen extends ConsumerStatefulWidget {
  final String requestId;
  const CompleteRequestScreen({super.key, required this.requestId});

  @override
  ConsumerState<CompleteRequestScreen> createState() => _CompleteRequestScreenState();
}

class _CompleteRequestScreenState extends ConsumerState<CompleteRequestScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isConfirmed = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _completeRequest() async {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 4 haneli tamamlama kodunu girin.')),
      );
      return;
    }

    if (!_isConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen hizmetin tamamlandığını onaylayın.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(requestRepositoryProvider).completeRequest(widget.requestId, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hizmet başarıyla tamamlandı.'), backgroundColor: AppColors.primary),
      );
      context.go('/driver'); // Return to main screen
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
      message: 'Tamamlanıyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Hizmeti Tamamla')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Müşteriden Aldığınız Kodu Girin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Hizmetin başarıyla tamamlandığını doğrulamak için müşterinin ekranında yazan 4 haneli kodu giriniz.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _codeController,
                label: 'Tamamlama Kodu',
                hint: 'Örn: 1234',
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                title: const Text(
                  'Aracı eksiksiz, hasarsız ve sorunsuz bir şekilde teslim ettiğimi onaylıyorum.',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                value: _isConfirmed,
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                onChanged: (val) {
                  setState(() => _isConfirmed = val ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              GreenButton(
                text: 'Hizmeti Bitir',
                onPressed: _completeRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
