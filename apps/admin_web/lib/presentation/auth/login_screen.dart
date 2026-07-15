import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_ui/app_colors.dart';

import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      if (!_codeSent) {
        // Send OTP
        await ref.read(authNotifierProvider.notifier).sendSMSCode(phone);
        setState(() {
          _codeSent = true;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doğrulama kodu gönderildi!'), backgroundColor: AppColors.success),
        );
      } else {
        // Verify OTP
        final code = _otpController.text.trim();
        await ref.read(authNotifierProvider.notifier).verifySMSCode(phone, code);
        
        // Let's verify if the logged in user is actually an admin!
        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser == null || currentUser.role != UserRole.admin) {
          throw Exception('Bu telefon numarası yetkili bir yönetici (admin) hesabına ait değil!');
        }
        
        if (!mounted) return;
        context.go('/admin');
      }
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
      message: _codeSent ? 'Giriş yapılıyor...' : 'Kod gönderiliyor...',
      child: Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, size: 64, color: AppColors.accent),
                      const SizedBox(height: 16),
                      const Text(
                        'ADMİN PANELİ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_codeSent) ...[
                        AppTextField(
                          controller: _phoneController,
                          label: 'Telefon Numarası',
                          hint: '05... veya +905...',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Telefon numarası gereklidir';
                            return null;
                          },
                        ),
                      ] else ...[
                        AppTextField(
                          controller: _otpController,
                          label: 'Doğrulama Kodu',
                          hint: '6 Haneli OTP Kodu',
                          prefixIcon: Icons.security_rounded,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Kod gereklidir';
                            if (val.length < 6) return 'Kod en az 6 haneli olmalıdır';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                      GreenButton(
                        text: _codeSent ? 'Giriş Yap' : 'Kod Gönder',
                        onPressed: _handleLogin,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
