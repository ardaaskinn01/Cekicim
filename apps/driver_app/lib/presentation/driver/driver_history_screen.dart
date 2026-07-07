import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_ui/extensions/request_status_extension.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class DriverHistoryScreen extends ConsumerStatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  ConsumerState<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends ConsumerState<DriverHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapınız.')));
    }

    final repo = ref.watch(requestRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş Görevler (Çekici)')),
      body: FutureBuilder<List<ServiceRequestModel>>(
        future: repo.getDriverHistory(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Görevler yüklenirken bir hata oluştu: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'Henüz tamamlanmış veya aktif bir göreviniz bulunmuyor.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final req = list[index];

              return Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${req.carBrand} ${req.carModel}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: req.status.color.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.status.label,
                              style: TextStyle(color: req.status.color, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Arıza: ${req.problemType}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 2),
                              FutureBuilder<UserModel?>(
                                future: AuthRepository().getUserProfile(req.customerId),
                                builder: (context, userSnapshot) {
                                  final name = userSnapshot.data?.fullName ?? '...';
                                  return Text('Müşteri: $name', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13));
                                },
                              ),
                            ],
                          ),
                          Text(
                            PriceCalculator.formatPrice(req.price),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
