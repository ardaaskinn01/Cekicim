import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_services/rating_repository.dart';
import 'package:shared_ui/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      _fullNameController.text = user.fullName;
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final updated = user.copyWith(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        final repo = ref.read(authRepositoryProvider);
        await repo.updateUserProfile(updated);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileriniz güncellendi.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Güncelleniyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Profilim')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'M',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                // Average rating badge
                if (user != null)
                  FutureBuilder<double>(
                    future: RatingRepository().getAverageRating(user.id),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final avg = snap.data ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              avg == 0.0 ? 'Henüz puan yok' : avg.toStringAsFixed(1),
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (avg > 0) ...
                              const [
                                SizedBox(width: 4),
                                Text('/5', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _fullNameController,
                  label: 'Ad Soyad',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  label: 'Telefon Numarası',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                GreenButton(
                  text: 'Bilgileri Güncelle',
                  onPressed: _updateProfile,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 32),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 16),
                ListTile(
                  onTap: () => context.push('/customer/disputes'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: AppColors.surface,
                  leading: const Icon(Icons.support_agent_outlined, color: AppColors.accent),
                  title: const Text('Destek Taleplerim', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: const Text('Şikayet ve uyuşmazlık geçmişiniz', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Oturumu Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/customer');
          if (index == 1) context.go('/customer/history');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    ),
  );
}
}
