import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updatePassword(_passwordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreniz başarıyla güncellendi! Yeni şifrenizle giriş yapabilirsiniz.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şifre güncellenemedi: ${e.toString().replaceAll('Exception: ', '')}'),
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
      message: 'Şifreniz güncelleniyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Yeni Şifre Belirle')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 72, color: AppColors.accent),
                  const SizedBox(height: 24),
                  const Text(
                    'Yeni Şifrenizi Oluşturun',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lütfen en az 6 karakterden oluşan güvenli yeni şifrenizi giriniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Yeni Şifre',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Şifre gereklidir';
                      if (val.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: 'Yeni Şifre (Tekrar)',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Şifre tekrarı gereklidir';
                      if (val != _passwordController.text) return 'Şifreler uyuşmuyor';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  GreenButton(
                    text: 'Şifreyi Güncelle ve Giriş Yap',
                    onPressed: _handleResetPassword,
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
