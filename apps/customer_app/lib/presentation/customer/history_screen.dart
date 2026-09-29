import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:shared_ui/widgets/dispute_dialog.dart';
import 'package:shared_ui/extensions/request_status_extension.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_models/user_model.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/rating_widget.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<ServiceRequestModel>? _history;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final repo = ref.read(requestRepositoryProvider);
        final list = await repo.getCustomerHistory(user.id);
        if (mounted) {
          setState(() {
            _history = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reportDispute(ServiceRequestModel req) {
    final user = ref.read(currentUserProvider).value;
    if (user == null || req.driverId == null) return;

    showDisputeDialog(
      context: context,
      onSubmit: (title, description) async {
        final dispute = DisputeModel(
          id: '',
          requestId: req.id,
          reporterId: user.id,
          reportedId: req.driverId!,
          title: title,
          description: description,
          createdAt: DateTime.now(),
        );
        await DisputeRepository().createDispute(dispute);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sorun başarıyla bildirildi.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hizmet Geçmişim')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _history == null || _history!.isEmpty
              ? const Center(
                  child: Text('Henüz geçmiş bir hizmet kaydınız bulunmuyor.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history!.length,
                  itemBuilder: (context, index) {
                    final req = _history![index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                Text(
                                  PriceCalculator.formatPrice(req.price),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                             Text(
                               'Tarih: ${req.createdAt.day}.${req.createdAt.month}.${req.createdAt.year} ${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                               style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                             ),
                             if (req.driverId != null) ...[
                               const SizedBox(height: 6),
                               FutureBuilder<UserModel?>(
                                 future: ref.read(authRepositoryProvider).getUserProfile(req.driverId!),
                                 builder: (context, snapshot) {
                                   final driverName = snapshot.data?.fullName ?? 'Yükleniyor...';
                                   return Row(
                                     children: [
                                       const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                       const SizedBox(width: 4),
                                       Text(
                                         'Çekici: $driverName',
                                         style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                       ),
                                     ],
                                   );
                                 },
                               ),
                             ],
                             const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: req.status.color.withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    req.status.label,
                                    style: TextStyle(color: req.status.color, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const Spacer(),
                                  const RatingWidget(rating: 5.0, isReadOnly: true, size: 16),
                                ],
                              ),
                              const Divider(color: AppColors.border, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      final plate = req.carPlate;
                                      final vehicleType = req.vehicleType ?? '';
                                      final zone = req.destinationIndustryZone ?? '';
                                      context.push(
                                        Uri(
                                          path: '/customer/request',
                                          queryParameters: {
                                            'plate': plate,
                                            'vehicleType': vehicleType,
                                            'zone': zone,
                                          },
                                        ).toString(),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                                    label: const Text(
                                      'Yeniden Talep Et',
                                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  if (req.driverId != null)
                                    TextButton.icon(
                                      onPressed: () => _reportDispute(req),
                                      icon: const Icon(Icons.gavel_rounded, size: 16, color: AppColors.error),
                                      label: const Text(
                                        'Sorun Bildir',
                                        style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go('/customer');
          if (index == 2) context.go('/customer/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
