import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendPasswordResetOTP(email);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Row(
            children: [
              Icon(Icons.mark_email_read, color: AppColors.accent),
              SizedBox(width: 10),
              Text('E-posta Gönderildi', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Text(
            '$email adresinize şifre sıfırlama bağlantısı gönderildi. E-postanızdaki bağlantıya tıklayarak yeni şifrenizi belirleyebilirsiniz.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/login');
              },
              child: const Text('Tamam', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Bağlantı gönderiliyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Şifremi Unuttum')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.accent),
                  const SizedBox(height: 24),
                  const Text(
                    'Şifre Sıfırlama Bağlantısı',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hesabınıza tanımlı e-posta adresinizi giriniz. Size bir şifre sıfırlama bağlantısı göndereceğiz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _emailController,
                    label: 'E-posta Adresi',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'E-posta gereklidir';
                      if (!val.contains('@')) return 'Geçerli e-posta giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  GreenButton(
                    text: 'Sıfırlama Bağlantısı Gönder',
                    onPressed: _handleSendResetLink,
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
