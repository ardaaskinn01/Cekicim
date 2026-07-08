import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

import '../../providers/auth_provider.dart';

class CustomerVerificationScreen extends ConsumerStatefulWidget {
  const CustomerVerificationScreen({super.key});

  @override
  ConsumerState<CustomerVerificationScreen> createState() => _CustomerVerificationScreenState();
}

class _CustomerVerificationScreenState extends ConsumerState<CustomerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final repo = ref.read(authRepositoryProvider);
      // Send verified names to updates profiles, bypass MERNIS in repo
      await repo.verifyCustomerTC(
        tcNo: '00000000000',
        firstName: firstName,
        lastName: lastName,
        birthYear: 2000,
      );

      // Save names directly into customer profile
      final current = ref.read(currentUserProvider).value;
      if (current != null) {
        final updated = current.copyWith(
          fullName: '$firstName $lastName',
        );
        await repo.updateUserProfile(updated);
      }
      
      if (!mounted) return;

      // Refresh local user model state
      await ref.read(authNotifierProvider.notifier).loadCurrentUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesabınız başarıyla aktifleştirildi.'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/customer');
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
      message: 'Hesabınız aktifleştiriliyor...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hesap Aktivasyonu'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hesabınızı Aktifleştirin',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hesabınızı aktifleştirmek için lütfen adınızı ve soyadınızı giriniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      controller: _firstNameController,
                      label: 'Adınız',
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
                      label: 'Soyadınız',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Soyad alanı gereklidir';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    GreenButton(
                      text: 'Hesabımı Aktifleştir',
                      onPressed: _handleVerification,
                      isLoading: _isLoading,
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
