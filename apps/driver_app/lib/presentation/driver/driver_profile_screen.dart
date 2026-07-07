import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/driver_model.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _plateController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    final driver = user is DriverModel ? user : null;
    _nameController = TextEditingController(text: driver?.fullName ?? '');
    _phoneController = TextEditingController(text: driver?.phone ?? '');
    _plateController = TextEditingController(text: driver?.vehiclePlate ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final current = ref.read(currentUserProvider).value;
      if (current != null && current is DriverModel) {
        final updated = current.copyWith(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          vehiclePlate: _plateController.text.trim(),
        );

        await repo.updateUserProfile(updated);
        ref.invalidate(currentUserProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi.'), backgroundColor: AppColors.success),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Profil güncelleniyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person, size: 50, color: AppColors.accent),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    controller: _nameController,
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
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Telefon gereklidir';
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
                    text: 'Değişiklikleri Kaydet',
                    onPressed: _handleUpdate,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _handleSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Oturumu Kapat'),
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
