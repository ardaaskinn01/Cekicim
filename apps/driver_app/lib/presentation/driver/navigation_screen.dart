import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_services/auth_repository.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/green_button.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  bool _isActionLoading = false;

  Future<void> _updateStatus(ServiceRequestModel request, RequestStatus nextStatus) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateRequestStatus(request.id, nextStatus);

      if (nextStatus == RequestStatus.completed) {
        final customerProfile = await AuthRepository().getUserProfile(request.customerId);
        if (!mounted) return;
        final customerName = customerProfile?.fullName ?? 'Müşteri';
        context.go('/driver/rate/${request.id}/${request.customerId}?name=$customerName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = GoRouterState.of(context).pathParameters['requestId'];
    if (requestId == null) {
      return const Scaffold(body: Center(child: Text('Geçersiz rota.')));
    }

    final requestAsync = ref.watch(requestStatusProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Navigasyon & Rota')),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, st) => Center(child: Text('Yüklenemedi: $err')),
        data: (req) {
          final customerLatLng = LatLng(req.customerLat, req.customerLng);

          // Get next action configuration
          String buttonText = '';
          RequestStatus? nextStatus;
          if (req.status == RequestStatus.accepted) {
            buttonText = 'Müşteriye Ulaştım (Hizmet Başladı)';
            nextStatus = RequestStatus.inProgress;
          } else if (req.status == RequestStatus.inProgress) {
            buttonText = 'Hizmeti Tamamla (İndirildi)';
            nextStatus = RequestStatus.completed;
          }

          return Stack(
            children: [
              MapWidget(
                initialPosition: customerLatLng,
                markers: {
                  Marker(
                    markerId: const MarkerId('customer'),
                    position: customerLatLng,
                    infoWindow: const InfoWindow(title: 'Müşteri Rota Hedefi'),
                  ),
                },
                showMyLocation: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<UserModel?>(
                                future: AuthRepository().getUserProfile(req.customerId),
                                builder: (context, userSnapshot) {
                                  final name = userSnapshot.data?.fullName ?? 'Müşteri Yükleniyor...';
                                  return Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text('Telefon: ${req.customerPhone ?? 'Belirtilmedi'}', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                          if (req.customerPhone != null)
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk, color: AppColors.accent, size: 28),
                              onPressed: () async {
                                final telUri = Uri.parse('tel:${req.customerPhone}');
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(telUri);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (nextStatus != null)
                        GreenButton(
                          text: buttonText,
                          onPressed: _isActionLoading ? null : () => _updateStatus(req, nextStatus!),
                          isLoading: _isActionLoading,
                        )
                      else
                        const Text('Talep tamamlandı veya iptal edildi.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
