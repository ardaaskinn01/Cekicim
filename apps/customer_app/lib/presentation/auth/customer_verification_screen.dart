import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_services/nvi_service.dart';
import '../../providers/auth_provider.dart';

class CustomerVerificationScreen extends ConsumerStatefulWidget {
  const CustomerVerificationScreen({super.key});

  @override
  ConsumerState<CustomerVerificationScreen> createState() => _CustomerVerificationScreenState();
}

class _CustomerVerificationScreenState extends ConsumerState<CustomerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tcController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthYearController = TextEditingController();

  bool _isLoading = false;
  final _nviService = NviService();

  @override
  void dispose() {
    _tcController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tcNo = _tcController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final birthYear = int.parse(_birthYearController.text.trim());

      final isValid = await _nviService.validateTCKimlikNo(
        tcNo: tcNo,
        firstName: firstName,
        lastName: lastName,
        birthYear: birthYear,
      );

      if (!mounted) return;

      if (isValid) {
        final repo = ref.read(authRepositoryProvider);
        await repo.verifyCustomerTC(tcNo);
        
        // Refresh local user model state
        await ref.read(authNotifierProvider.notifier).loadCurrentUser();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kimlik doğrulama başarıyla tamamlandı.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/customer');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kimlik bilgileri doğrulamadan geçemedi. Lütfen bilgilerinizi e-Devlet ile birebir eşleşecek şekilde Türkçe karakterlerle giriniz.'),
            backgroundColor: AppColors.error,
          ),
        );
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Kimlik bilgileri NVİ üzerinden sorgulanıyor...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kimlik Doğrulama'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Güvenliğiniz İçin Doğrulama',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lütfen T.C. Kimlik bilgilerinizi e-Devlet kayıtlarında olduğu gibi eksiksiz doldurun. Bilgileriniz sadece Nüfus Müdürlüğü doğrulaması amacıyla kullanılacaktır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _tcController,
                    label: 'T.C. Kimlik Numarası',
                    prefixIcon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'T.C. Kimlik Numarası gereklidir';
                      if (val.trim().length != 11) return 'T.C. Kimlik Numarası 11 haneli olmalıdır';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _firstNameController,
                    label: 'Adınız (e-Devlet\'teki gibi)',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.name,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ad alanı gereklidir';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _lastNameController,
                    label: 'Soyadınız (e-Devlet\'teki gibi)',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.name,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Soyad alanı gereklidir';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _birthYearController,
                    label: 'Doğum Yılınız (Örn: 1990)',
                    prefixIcon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Doğum yılı gereklidir';
                      if (val.trim().length != 4) return 'Geçerli bir yıl giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  GreenButton(
                    text: 'Bilgileri Doğrula',
                    onPressed: _handleVerification,
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
