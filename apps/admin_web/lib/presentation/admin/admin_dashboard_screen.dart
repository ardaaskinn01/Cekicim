import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_services/supabase_service.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = false;
  List<ServiceRequestModel> _allRequests = [];
  List<Map<String, dynamic>> _unverifiedDrivers = [];

  double _totalEarnings = 0.0;
  int _activeRequestsCount = 0;
  int _completedRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;

      // Fetch all service requests
      final requestsData = await client
          .from('service_requests')
          .select()
          .order('created_at', ascending: false);

      _allRequests = (requestsData as List)
          .map((json) => ServiceRequestModel.fromJson(json))
          .toList();

      // Fetch unverified drivers
      final driversData = await client
          .from('drivers')
          .select('*, profiles(*)')
          .eq('is_verified', false);

      _unverifiedDrivers = List<Map<String, dynamic>>.from(driversData);

      // Calculations
      _totalEarnings = _allRequests
          .where((r) => r.status.dbValue == 'completed')
          .fold(0.0, (sum, r) => sum + r.price);

      _activeRequestsCount = _allRequests
          .where((r) => r.status.dbValue != 'completed' && r.status.dbValue != 'cancelled')
          .length;

      _completedRequestsCount = _allRequests
          .where((r) => r.status.dbValue == 'completed')
          .length;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDriver(String driverId) async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      await client.from('drivers').update({'is_verified': true}).eq('id', driverId);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sürücü başarıyla onaylandı.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çekici Admin Yönetim Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Toplam Ciro',
                          value: '${_totalEarnings.toStringAsFixed(2)} TL',
                          icon: Icons.monetization_on,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Aktif Talepler',
                          value: '$_activeRequestsCount',
                          icon: Icons.local_shipping,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tamamlanan Talepler',
                          value: '$_completedRequestsCount',
                          icon: Icons.check_circle,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Lower Section: Driver approval and request logs
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver approval queue
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Onay Bekleyen Çekiciler',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            if (_unverifiedDrivers.isEmpty)
                              const Card(
                                color: AppColors.cardBackground,
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'Onay bekleyen çekici sürücüsü bulunmuyor.',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _unverifiedDrivers.length,
                                itemBuilder: (context, index) {
                                  final driver = _unverifiedDrivers[index];
                                  final profile = driver['profiles'] as Map<String, dynamic>;

                                  return Card(
                                    color: AppColors.cardBackground,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      title: Text(profile['full_name'] ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Plaka: ${driver['vehicle_plate'] ?? ''}\nTel: ${profile['phone'] ?? ''}'),
                                      trailing: ElevatedButton(
                                        onPressed: () => _verifyDriver(driver['id']),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                        child: const Text('Onayla'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Recent activity logs
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Son Sistem Hareketleri',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            if (_allRequests.isEmpty)
                              const Card(
                                color: AppColors.cardBackground,
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'Sistemde henüz talep kaydı bulunmuyor.',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _allRequests.length > 10 ? 10 : _allRequests.length,
                                itemBuilder: (context, index) {
                                  final req = _allRequests[index];

                                  return Card(
                                    color: AppColors.cardBackground,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const Icon(Icons.history_toggle_off, color: AppColors.textSecondary),
                                      title: Text('${req.carBrand} ${req.carModel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Arıza: ${req.problemType} • Fiyat: ${req.price} TL'),
                                      trailing: Chip(
                                        label: Text(req.status.label),
                                        backgroundColor: AppColors.surface,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            Icon(icon, size: 48, color: color),
          ],
        ),
      ),
    );
  }
}
