import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_services/app_error_handler.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/social_auth_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_ui/widgets/legal_consent_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await ref.read(authNotifierProvider.notifier).signIn(email, password);

      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      context.go('/customer');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.parse(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _handlePostSocialLoginSuccess() async {
    final consentAccepted = await LegalConsentSheet.show(context);
    if (!consentAccepted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yasal şartlar onaylanmadığı için giriş işlemi tamamlanamadı.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    ref.invalidate(currentUserProvider);
    context.go('/customer');
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;
      await _handlePostSocialLoginSuccess();
    } catch (e) {
      if (!mounted) return;
      // Kullanıcı bilerek iptal ettiyse hata gösterme
      final msg = e.toString().toLowerCase();
      if (!msg.contains('iptal') && !msg.contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.parse(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() => _isAppleLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithApple();

      if (!mounted) return;
      await _handlePostSocialLoginSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (!msg.contains('iptal') && !msg.contains('cancel') && !msg.contains('1001')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.parse(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  bool get _isAppleSupported {
    if (kIsWeb) return true;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final anyLoading = _isLoading || _isGoogleLoading || _isAppleLoading;

    return LoadingOverlay(
      isLoading: anyLoading,
      message: _isGoogleLoading
          ? 'Google ile giriş yapılıyor...'
          : _isAppleLoading
              ? 'Apple ile giriş yapılıyor...'
              : 'Giriş yapılıyor...',
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ÇEKİCİM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'En yakın çekici bir tık uzağınızda',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    AppTextField(
                      controller: _emailController,
                      label: 'E-posta Adresi',
                      hint: '',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'E-posta adresi gereklidir';
                        if (!val.contains('@') || !val.contains('.')) return 'Geçerli bir e-posta adresi giriniz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    AppTextField(
                      controller: _passwordController,
                      label: 'Şifre',
                      hint: '',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Şifre gereklidir';
                        if (val.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                        return null;
                      },
                    ),

                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: anyLoading ? null : () => context.push('/forgot-password'),
                        child: const Text(
                          'Şifremi Unuttum',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Login Button
                    GreenButton(
                      text: 'Giriş Yap',
                      onPressed: _handleEmailLogin,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 24),

                    // "Veya" Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'veya',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Google Sign-In Button
                    SocialAuthButton(
                      type: SocialButtonType.google,
                      onPressed: anyLoading ? null : _handleGoogleLogin,
                      isLoading: _isGoogleLoading,
                    ),

                    // Apple Sign-In Button (iOS, macOS, Web)
                    if (_isAppleSupported) ...[
                      const SizedBox(height: 12),
                      SocialAuthButton(
                        type: SocialButtonType.apple,
                        onPressed: anyLoading ? null : _handleAppleLogin,
                        isLoading: _isAppleLoading,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Hesabınız yok mu? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: anyLoading ? null : () => context.push('/register'),
                          child: const Text(
                            'Kayıt Ol',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
