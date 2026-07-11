import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_services/rating_repository.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_ui/price_calculator.dart';
import '../../providers/request_provider.dart';
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
  late TextEditingController _ibanController;
  late TextEditingController _ibanOwnerController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    final driver = user is DriverModel ? user : null;
    _nameController = TextEditingController(text: driver?.fullName ?? '');
    _phoneController = TextEditingController(text: driver?.phone ?? '');
    _plateController = TextEditingController(text: driver?.vehiclePlate ?? '');
    _ibanController = TextEditingController(text: driver?.iban ?? '');
    _ibanOwnerController = TextEditingController(text: driver?.ibanOwnerName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _ibanController.dispose();
    _ibanOwnerController.dispose();
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
          iban: _ibanController.text.replaceAll(' ', '').toUpperCase(),
          ibanOwnerName: _ibanOwnerController.text.trim(),
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
    final user = ref.watch(currentUserProvider).value;
    final driver = user is DriverModel ? user : null;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Profil güncelleniyor...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              await ref.read(currentUserProvider.future);
              await ref.read(authNotifierProvider.notifier).loadCurrentUser();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                  const SizedBox(height: 8),
                  // Driver rating badge
                  Builder(builder: (ctx) {
                    final user = ref.watch(currentUserProvider).value;
                    if (user == null) return const SizedBox.shrink();
                    return FutureBuilder<double>(
                      future: RatingRepository().getAverageRating(user.id),
                      builder: (ctx2, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final avg = snap.data ?? 0.0;
                        return Center(
                          child: Container(
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
                          ),
                        );
                      },
                    );
                  }),
                  Builder(builder: (ctx) {
                    final user = ref.watch(currentUserProvider).value;
                    if (user == null) return const SizedBox.shrink();
                    return FutureBuilder<Map<String, double>>(
                      future: ref.read(requestRepositoryProvider).getDriverEarningsSummary(user.id),
                      builder: (ctx2, snap) {
                        if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                        final earnings = snap.data ?? {'today': 0.0, 'week': 0.0};
                        final todayText = PriceCalculator.formatPrice(earnings['today']!);
                        final weekText = PriceCalculator.formatPrice(earnings['week']!);

                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Bugün', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(todayText, style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(width: 1, height: 30, color: AppColors.border),
                              Column(
                                children: [
                                  const Text('Bu Hafta', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(weekText, style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _ibanController,
                    label: 'IBAN (Ödeme Almak İçin)',
                    prefixIcon: Icons.account_balance,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'IBAN gereklidir';
                      final clean = val.replaceAll(' ', '');
                      if (!clean.startsWith('TR')) return "Türkiye IBAN'ı TR ile başlamalıdır.";
                      if (clean.length != 26) return 'IBAN 26 karakter olmalıdır (TR + 24 rakam).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _ibanOwnerController,
                    label: 'IBAN Hesap Sahibi',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Hesap sahibi adı gereklidir';
                      if (val.trim().split(' ').length < 2) return 'Lütfen en az ad ve soyad girin.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Premium Verification Documents Status Panel
                  if (driver != null) ...[
                    Card(
                      color: AppColors.cardBackground,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: driver.isVerified ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  driver.isVerified ? Icons.verified_user_rounded : Icons.shield_outlined, 
                                  color: driver.isVerified ? AppColors.primary : AppColors.warning,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Hesap Doğrulama Durumu', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const Divider(color: AppColors.border, height: 24),
                            // Document Items
                            _buildDocumentStatusRow(
                              'Ehliyet Belgesi', 
                              driver.driverLicenseUrl != null,
                              driver.isVerified,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentStatusRow(
                              'SRC Belgesi', 
                              driver.srcCertificateUrl != null,
                              driver.isVerified,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentStatusRow(
                              'Psikoteknik Raporu', 
                              driver.psychotechnicUrl != null,
                              driver.isVerified,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentStatusRow(
                              'Ruhsat & Plaka Belgesi', 
                              driver.vehicleRegistrationUrl != null,
                              driver.isVerified,
                            ),
                            
                            // Rejection bubble
                            if (!driver.isVerified && driver.rejectionReason != null && driver.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Red Gerekçesi:', 
                                            style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            driver.rejectionReason!,
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  GreenButton(
                    text: 'Değişiklikleri Kaydet',
                    onPressed: _handleUpdate,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    onTap: () => context.push('/driver/disputes'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: AppColors.surface,
                    leading: const Icon(Icons.support_agent_outlined, color: AppColors.accent),
                    title: const Text('Destek Taleplerim', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: const Text('Şikayet ve uyuşmazlık geçmişiniz', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
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
    ),
  );
  }

  Widget _buildDocumentStatusRow(String title, bool isUploaded, bool isDriverVerified) {
    Color badgeColor;
    String statusText;
    IconData icon;

    if (!isUploaded) {
      badgeColor = AppColors.error;
      statusText = 'Yüklenmedi';
      icon = Icons.cancel_outlined;
    } else if (isDriverVerified) {
      badgeColor = AppColors.success;
      statusText = 'Onaylandı';
      icon = Icons.check_circle_outline_rounded;
    } else {
      badgeColor = AppColors.warning;
      statusText = 'İnceleniyor';
      icon = Icons.hourglass_empty_rounded;
    }

    return Row(
      children: [
        Icon(Icons.description_outlined, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title, 
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: badgeColor, size: 14),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
