import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/app_colors.dart';

import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _plateController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentPhone = Supabase.instance.client.auth.currentUser?.phone ?? '';
    _phoneController.text = currentPhone;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).completeProfile(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        vehiclePlate: _plateController.text.trim(),
      );

      // Invalidate provider cache to force router redirect recalculation
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      context.go('/driver');
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
      message: 'Profiliniz tamamlanıyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Profili Tamamla')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sürücü Profilinizi Tamamlayın',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistemdeki yol yardım taleplerini yanıtlamak için lütfen bilgilerinizi tamamlayın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _fullNameController,
                    label: 'Ad Soyad',
                    prefixIcon: Icons.person_outline,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ad soyad gereklidir';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Telefon Numarası',
                    prefixIcon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Telefon numarası gereklidir' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _emailController,
                    label: 'E-posta Adresi (İsteğe bağlı)',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Geçersiz e-posta adresi';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _plateController,
                    label: 'Araç Plakası',
                    prefixIcon: Icons.numbers_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Plaka gereklidir';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  GreenButton(
                    text: 'Kaydı Tamamla',
                    onPressed: _handleRegister,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      try {
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: const Text(
                      'Giriş Ekranına Dön / Çıkış Yap',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
