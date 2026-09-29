import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/user_role.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.customer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rol Seçimi'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Uygulamayı Nasıl Kullanmak İstiyorsunuz?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Size özel hizmetleri sunabilmemiz için lütfen rolünüzü seçiniz.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildRoleCard(
                      role: UserRole.customer,
                      title: 'Müşteriyim',
                      subtitle: 'Aracım yolda kaldı, çekici ve yol yardım hizmeti almak istiyorum.',
                      icon: Icons.person_pin_circle_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      role: UserRole.driver,
                      title: 'Çekici Sürücüsüyüm',
                      subtitle: 'Çekici aracımla yakındaki çekici taleplerini karşılamak istiyorum.',
                      icon: Icons.local_shipping_rounded,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  context.push('/register?role=${_selectedRole.dbValue}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.background,
              ),
              child: Icon(
                icon,
                size: 36,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Radio<UserRole>(
              value: role,
              groupValue: _selectedRole,
              activeColor: AppColors.accent,
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
