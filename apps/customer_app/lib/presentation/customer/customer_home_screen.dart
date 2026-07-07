import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/request_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/green_button.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final locationAsync = ref.watch(locationProvider);
    final activeRequestAsync = ref.watch(activeRequestProvider);

    final user = userAsync.value;
    final currentPos = locationAsync.value;
    final activeRequest = activeRequestAsync.value;

    final initialLatLng = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(41.0082, 28.9784);

    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          MapWidget(
            initialPosition: initialLatLng,
            showMyLocation: true,
          ),

          // Top Header Panel (Glassmorphism design)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withAlpha(220),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person, size: 20, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Merhaba, ${user?.fullName ?? 'Müşteri'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withAlpha(220),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.history, color: AppColors.accent),
                      onPressed: () => context.push('/customer/history'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Content Panel
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: activeRequest != null
                ? _buildActiveRequestCard(context, activeRequest)
                : _buildCallTowCard(context),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) context.push('/customer/history');
          if (index == 2) context.push('/customer/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildCallTowCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: AppColors.accent, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yol Yardım İhtiyacınız mı Var?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('En yakın çekici 15 km yarıçapında aranır.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GreenButton(
            text: 'Çekici Çağır',
            icon: Icons.local_shipping_rounded,
            onPressed: () => context.push('/customer/request'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestCard(BuildContext context, dynamic request) {
    final status = request.status as RequestStatus;
    return InkWell(
      onTap: () => context.push('/customer/tracking/${request.id}'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(245),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(status.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent)),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${request.carBrand} ${request.carModel}', style: const TextStyle(color: AppColors.textPrimary)),
                Text('₺${request.price.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
