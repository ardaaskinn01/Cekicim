import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_services/app_error_handler.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

import 'package:shared_ui/widgets/legal_documents_dialog.dart';

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

  bool _isLoading = false;
  bool _isCompletingProfile = false;

  // Ön tanımlı seçili OLMAYAN (false) hukuki kutucuklar
  bool _kvkkAccepted = false;
  bool _termsAccepted = false;
  bool _consentAccepted = false;

  @override
  void initState() {
    super.initState();
    final currentUser = Supabase.instance.client.auth.currentUser;
    _isCompletingProfile = currentUser != null;

    if (currentUser != null) {
      final metaName = (currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name']) as String? ?? '';
      _fullNameController.text = metaName;
      _emailController.text = currentUser.email ?? '';
      _phoneController.text = currentUser.phone ?? (currentUser.userMetadata?['phone'] as String? ?? '');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_kvkkAccepted || !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam edebilmek için KVKK Aydınlatma Metni ve Kullanım Koşullarını kabul etmelisiniz.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fullName = _fullNameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();

      if (_isCompletingProfile) {
        await ref.read(authNotifierProvider.notifier).completeProfile(
          fullName: fullName,
          phone: phone,
          email: email.isNotEmpty ? email : null,
        );
      } else {
        final password = _passwordController.text;
        await ref.read(authNotifierProvider.notifier).signUp(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
        );
      }

      ref.invalidate(currentUserProvider);

      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: _isCompletingProfile ? 'Profiliniz tamamlanıyor...' : 'Hesabınız oluşturuluyor...',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isCompletingProfile ? 'Profili Tamamla' : 'Kayıt Ol'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isCompletingProfile ? 'Profilinizi Tamamlayın' : 'Yeni Hesap Oluşturun',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCompletingProfile
                        ? 'Hizmet alabilmeniz ve sürücülerin size ulaşabilmesi için bilgilerinizi tamamlayınız.'
                        : 'Çekicim hizmetlerinden yararlanmak için formu doldurunuz.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Full Name
                  AppTextField(
                    controller: _fullNameController,
                    label: 'Ad Soyad',
                    hint: '',
                    prefixIcon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Ad soyad gereklidir' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  AppTextField(
                    controller: _phoneController,
                    label: 'İletişim Telefon Numarası',
                    hint: '',
                    prefixIcon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Telefon numarası gereklidir';
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return 'Lütfen geçerli 10 haneli telefon numarası giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  AppTextField(
                    controller: _emailController,
                    label: 'E-posta Adresi',
                    hint: '',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _isCompletingProfile && _emailController.text.isNotEmpty,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'E-posta gereklidir';
                      if (!val.contains('@') || !val.contains('.')) return 'Geçerli bir e-posta adresi giriniz';
                      return null;
                    },
                  ),

                  // Password (only for fresh signup)
                  if (!_isCompletingProfile) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Şifre',
                      hint: 'En az 6 karakter',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Şifre gereklidir';
                        if (val.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Kutucuk 1 (Bilgilendirme / Zorunlu)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _kvkkAccepted,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _kvkkAccepted = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.kvkk),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                children: [
                                  TextSpan(text: 'ÇEKİCİM '),
                                  TextSpan(
                                    text: 'KVKK Aydınlatma Metni\'ni',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                  TextSpan(text: ' okudum, bilgi edindim. (Zorunlu)'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Kutucuk 2 (Sözleşme / Zorunlu)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.terms),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                children: [
                                  TextSpan(
                                    text: 'Sorumluluk Reddi Beyanı ve Platform Kullanım Koşulları\'nı',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                  TextSpan(text: ' okudum, kabul ediyorum. (Zorunlu)'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Kutucuk 3 (Açık Rıza / İsteğe Bağlı)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _consentAccepted,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _consentAccepted = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.consent),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                children: [
                                  TextSpan(
                                    text: 'Açık Rıza Metni',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                  TextSpan(text: ' kapsamında kişisel verilerimin ve belge görsellerindeki özel nitelikli verilerimin işlenmesine açık rıza veriyorum. (İsteğe Bağlı)'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  GreenButton(
                    text: _isCompletingProfile ? 'Kaydı Tamamla' : 'Hesap Oluştur',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Bottom action
                  if (_isCompletingProfile)
                    TextButton(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        try {
                          await ref.read(authNotifierProvider.notifier).signOut();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      child: const Text(
                        'Giriş Ekranına Dön / Çıkış Yap',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Zaten hesabınız var mı? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Giriş Yap',
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
    );
  }
}
