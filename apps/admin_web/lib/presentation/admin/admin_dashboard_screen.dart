import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/extensions/request_status_extension.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_models/message_model.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:shared_services/rating_repository.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = false;
  int _selectedMenuIndex = 0;

  // Data lists
  List<ServiceRequestModel> _allRequests = [];
  List<Map<String, dynamic>> _unverifiedDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  List<UserModel> _allCustomers = [];
  List<DisputeModel> _allDisputes = [];
  List<Map<String, dynamic>> _allRatings = [];

  // Overview stats
  double _totalEarnings = 0.0;
  int _activeRequestsCount = 0;
  int _completedRequestsCount = 0;
  int _pendingApprovalsCount = 0;
  int _unresolvedDisputesCount = 0;

  // Selection states for details view
  Map<String, dynamic>? _selectedDriverApproval;
  DisputeModel? _selectedDispute;
  List<MessageModel> _selectedDisputeChatLogs = [];
  bool _loadingChatLogs = false;

  // Search controllers
  final _driverSearchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _requestSearchController = TextEditingController();

  // Admin notes input for dispute resolving
  final _adminNotesController = TextEditingController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showDetailsMobile = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _driverSearchController.dispose();
    _customerSearchController.dispose();
    _requestSearchController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;

      // 1. Fetch requests
      final requestsData = await client
          .from('service_requests')
          .select()
          .order('created_at', ascending: false);

      _allRequests = (requestsData as List)
          .map((json) => ServiceRequestModel.fromJson(json))
          .toList();

      // 2. Fetch unverified drivers (onboarding completed but not verified)
      final unverifiedData = await client
          .from('drivers')
          .select('*, profiles(*)')
          .eq('is_verified', false)
          .neq('vehicle_plate', '')
          .not('iban', 'is', null);

      _unverifiedDrivers = List<Map<String, dynamic>>.from(unverifiedData);

      // 3. Fetch all drivers
      final allDriversData = await client
          .from('drivers')
          .select('*, profiles(*)');
      _allDrivers = List<Map<String, dynamic>>.from(allDriversData);

      // 4. Fetch all customers (profiles with role customer)
      final customersData = await client
          .from('profiles')
          .select()
          .eq('role', 'customer');
      _allCustomers = (customersData as List)
          .map((json) => UserModel.fromJson(json))
          .toList();

      // 5. Fetch all disputes
      _allDisputes = await DisputeRepository().getAllDisputes();

      // 6. Fetch all ratings
      final ratingsData = await client
          .from('ratings')
          .select('*, rater:profiles!rater_id(*), rated:profiles!rated_id(*)');
      _allRatings = List<Map<String, dynamic>>.from(ratingsData);

      // Recalculate statistics
      _totalEarnings = _allRequests
          .where((r) => r.status.dbValue == 'completed')
          .fold(0.0, (sum, r) => sum + r.price);

      _activeRequestsCount = _allRequests
          .where((r) => r.status.dbValue != 'completed' && r.status.dbValue != 'cancelled')
          .length;

      _completedRequestsCount = _allRequests
          .where((r) => r.status.dbValue == 'completed')
          .length;

      _pendingApprovalsCount = _unverifiedDrivers.length;

      _unresolvedDisputesCount = _allDisputes
          .where((d) => d.status == DisputeStatus.pending || d.status == DisputeStatus.investigating)
          .length;

      // Auto-select first elements if selection is null
      if (_unverifiedDrivers.isNotEmpty && _selectedDriverApproval == null) {
        _selectedDriverApproval = _unverifiedDrivers.first;
      }
      if (_allDisputes.isNotEmpty && _selectedDispute == null) {
        _selectDispute(_allDisputes.first);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDispute(DisputeModel dispute) async {
    setState(() {
      _selectedDispute = dispute;
      _loadingChatLogs = true;
      _adminNotesController.text = dispute.adminNotes ?? '';
    });
    try {
      final logs = await DisputeRepository().getRequestChatLogs(dispute.requestId);
      if (mounted) {
        setState(() {
          _selectedDisputeChatLogs = logs;
          _loadingChatLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChatLogs = false);
    }
  }

  Future<void> _verifyDriver(String driverId) async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      await client.from('drivers').update({
        'is_verified': true,
        'rejection_reason': null,
      }).eq('id', driverId);

      _selectedDriverApproval = null;
      await _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sürücü başvurusu onaylandı.'), backgroundColor: AppColors.success),
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

  Future<void> _rejectDriver(String driverId, String reason) async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      await client.from('drivers').update({
        'is_verified': false,
        'rejection_reason': reason,
      }).eq('id', driverId);

      _selectedDriverApproval = null;
      await _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başvuru reddedildi ve gerekçesi sürücüye iletildi.'), backgroundColor: AppColors.success),
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

  Future<void> _resolveDispute(String disputeId, DisputeStatus status) async {
    setState(() => _isLoading = true);
    try {
      await DisputeRepository().updateDisputeStatus(
        disputeId,
        status,
        _adminNotesController.text.trim().isEmpty ? null : _adminNotesController.text.trim(),
      );

      _selectedDispute = null;
      await _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uyuşmazlık durumu güncellendi: ${status.label}'), backgroundColor: AppColors.success),
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

  Future<void> _toggleUserBlock(String userId, bool block) async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      await client.from('profiles').update({'is_suspended': block}).eq('id', userId);
      await _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(block ? 'Kullanıcı engellendi.' : 'Kullanıcı engeli kaldırıldı.'), backgroundColor: AppColors.success),
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
    if (mounted) context.go('/login');
  }

  void _showImageZoom(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionDialog(String driverId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Başvuruyu Reddet', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lütfen sürücüye iletilecek ret gerekçesini yazınız:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: 'Örn: Ehliyet fotoğrafı bulanık veya okunaksız.',
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _rejectDriver(driverId, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: isMobile ? Drawer(child: _buildSidebar()) : null,
      body: Row(
        children: [
          // Sidebar Navigation (Desktop only)
          if (!isMobile) _buildSidebar(),

          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar
                _buildHeader(),

                // Tab Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(right: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Çekicim',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSidebarMenuItem(0, 'Gösterge Paneli', Icons.dashboard_outlined),
                _buildSidebarMenuItem(1, 'Belge Onay Sırası', Icons.verified_user_outlined, badgeCount: _pendingApprovalsCount),
                _buildSidebarMenuItem(2, 'Uyuşmazlık Merkezi', Icons.gavel_outlined, badgeCount: _unresolvedDisputesCount),
                _buildSidebarMenuItem(3, 'Çekici Sürücüleri', Icons.drive_eta_outlined),
                _buildSidebarMenuItem(4, 'Müşteriler', Icons.people_outline),
                _buildSidebarMenuItem(5, 'Tüm Talepler', Icons.history_edu_outlined),
                _buildSidebarMenuItem(6, 'Canlı Takip Haritası', Icons.map_outlined),
                _buildSidebarMenuItem(7, 'Değerlendirmeler', Icons.star_outline),
              ],
            ),
          ),

          // Footer Profile info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.admin_panel_settings, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final currentUser = ref.watch(currentUserProvider).value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentUser?.fullName ?? 'Yönetici',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
                  onPressed: _handleSignOut,
                  tooltip: 'Çıkış Yap',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarMenuItem(int index, String title, IconData icon, {int badgeCount = 0}) {
    final isSelected = _selectedMenuIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedMenuIndex = index;
          });
          if (MediaQuery.of(context).size.width < 900) {
            Navigator.pop(context);
          }
        },
        selected: isSelected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isSelected ? AppColors.accent : AppColors.textSecondary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    String pageTitle = '';
    switch (_selectedMenuIndex) {
      case 0: pageTitle = 'Gösterge Paneli'; break;
      case 1: pageTitle = isMobile ? 'Evrak Onay' : 'Sürücü Evrak Onaylama Kuyruğu'; break;
      case 2: pageTitle = isMobile ? 'Uyuşmazlık' : 'Uyuşmazlık Çözüm Merkezi'; break;
      case 3: pageTitle = 'Sürücüler'; break;
      case 4: pageTitle = 'Müşteriler'; break;
      case 5: pageTitle = isMobile ? 'Talepler' : 'Sistem Talep Kayıtları'; break;
      case 6: pageTitle = isMobile ? 'Canlı Harita' : 'Canlı Operasyon Haritası'; break;
      case 7: pageTitle = 'Değerlendirmeler'; break;
    }

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.accent),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              pageTitle,
              style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _loadDashboardData,
            tooltip: 'Verileri Yenile',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedMenuIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildApprovalsTab();
      case 2: return _buildDisputesTab();
      case 3: return _buildDriversTab();
      case 4: return _buildCustomersTab();
      case 5: return _buildRequestsTab();
      case 6: return _buildLiveMapTab();
      case 7: return _buildRatingsTab();
      default: return const Center(child: Text('Sekme bulunamadı.'));
    }
  }

  // TAB 0: DASHBOARD
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Overview row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Ciro',
                  '${_totalEarnings.toStringAsFixed(2)} TL',
                  Icons.monetization_on_outlined,
                  AppColors.accent,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  'Aktif Talepler',
                  '$_activeRequestsCount',
                  Icons.local_shipping_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  'Onay Bekleyenler',
                  '$_pendingApprovalsCount',
                  Icons.verified_user_outlined,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  'Uyuşmazlıklar',
                  '$_unresolvedDisputesCount',
                  Icons.gavel_outlined,
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // User statistics row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Sürücü',
                  '${_allDrivers.length}',
                  Icons.drive_eta_outlined,
                  AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  'Toplam Müşteri',
                  '${_allCustomers.length}',
                  Icons.people_outline,
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildFinancialChartCard(),
          const SizedBox(height: 48),

          // Recent Activity Log
          const Text(
            'Son Talepler ve Canlı Akış',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _allRequests.isEmpty
              ? _buildEmptyState('Sistemde talep kaydı bulunmuyor.')
              : Card(
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allRequests.length > 8 ? 8 : _allRequests.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final req = _allRequests[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: req.status.color.withValues(alpha: 0.12),
                          child: Icon(Icons.local_shipping_outlined, color: req.status.color),
                        ),
                        title: Text('${req.carBrand} ${req.carModel}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text('Arıza: ${req.problemType} • Fiyat: ${req.price} TL'),
                        trailing: Chip(
                          label: Text(req.status.label),
                          backgroundColor: req.status.color.withValues(alpha: 0.15),
                          side: BorderSide(color: req.status.color.withValues(alpha: 0.4)),
                          labelStyle: TextStyle(color: req.status.color, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // TAB 1: APPROVALS
  Widget _buildApprovalsTab() {
    if (_unverifiedDrivers.isEmpty) {
      return _buildEmptyState('Onay bekleyen sürücü evrağı bulunmamaktadır.');
    }

    final driver = _selectedDriverApproval;
    final isMobile = MediaQuery.of(context).size.width < 750;
    if (driver == null && !isMobile) return const SizedBox.shrink();

    final profile = driver != null ? driver['profiles'] as Map<String, dynamic> : const <String, dynamic>{};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile || !_showDetailsMobile)
          isMobile
              ? Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _unverifiedDrivers.length,
                    itemBuilder: (context, index) {
                      final d = _unverifiedDrivers[index];
                      final prof = d['profiles'] as Map<String, dynamic>;
                      final isSelected = driver != null && d['id'] == driver['id'];

                      return Card(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedDriverApproval = d;
                              _showDetailsMobile = true;
                            });
                          },
                          title: Text(prof['full_name'] ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          subtitle: Text('Plaka: ${d['vehicle_plate'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                        ),
                      );
                    },
                  ),
                )
              : SizedBox(
                  width: 320,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _unverifiedDrivers.length,
                      itemBuilder: (context, index) {
                        final d = _unverifiedDrivers[index];
                        final prof = d['profiles'] as Map<String, dynamic>;
                        final isSelected = driver != null && d['id'] == driver['id'];

                        return Card(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => setState(() => _selectedDriverApproval = d),
                            title: Text(prof['full_name'] ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            subtitle: Text('Plaka: ${d['vehicle_plate'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),

        // Right Column: Document Details Review
        if (driver != null && (!isMobile || _showDetailsMobile))
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
              child: Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isMobile) ...[
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() => _showDetailsMobile = false),
                              icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                              label: const Text('Başvurular Listesine Dön', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),
                      ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile['full_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('E-posta: ${profile['email'] ?? ''} | Telefon: ${profile['phone'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showRejectionDialog(driver['id']),
                            icon: const Icon(Icons.close_rounded, color: AppColors.error),
                            label: const Text('Reddet', style: TextStyle(color: AppColors.error)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => _verifyDriver(driver['id']),
                            icon: const Icon(Icons.check_rounded, color: Colors.white),
                            label: const Text('Onayla', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 40),

                  // Vehicle/Payment Details
                  const Text('Araç ve Ödeme Bilgileri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 40,
                    runSpacing: 16,
                    children: [
                      _buildDetailItem('Araç Plakası', driver['vehicle_plate'] ?? '-'),
                      _buildDetailItem('Araç Tipi', driver['vehicle_type'] ?? '-'),
                      _buildDetailItem('IBAN Sahibi', driver['iban_owner_name'] ?? '-'),
                      _buildDetailItem('IBAN Numarası', driver['iban'] ?? '-'),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 40),

                  // Documents section
                  const Text('Yüklenen Evraklar (Büyütmek için tıklayın)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                    children: [
                      if (driver['driver_license_url'] != null)
                        _buildDocImagePreview('Sürücü Ehliyeti', driver['driver_license_url']),
                      if (driver['vehicle_registration_url'] != null)
                        _buildDocImagePreview('Araç Ruhsatı', driver['vehicle_registration_url']),
                      if (driver['criminal_record_url'] != null)
                        _buildDocImagePreview('Adli Sicil Kaydı', driver['criminal_record_url']),
                      if (driver['src_certificate_url'] != null)
                        _buildDocImagePreview('SRC Belgesi', driver['src_certificate_url']),
                      if (driver['psychotechnic_url'] != null)
                        _buildDocImagePreview('Psikoteknik Belgesi', driver['psychotechnic_url']),
                      if (driver['tax_plate_url'] != null)
                        _buildDocImagePreview('Vergi Levhası', driver['tax_plate_url']),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 40),

                  // Vehicle photos section
                  const Text('Çekici Aracı Fotoğrafları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  if (driver['vehicle_photos'] != null && (driver['vehicle_photos'] as List).isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: (driver['vehicle_photos'] as List).length,
                      itemBuilder: (context, idx) {
                        final photoUrl = (driver['vehicle_photos'] as List)[idx];
                        return _buildDocImagePreview('Fotoğraf ${idx + 1}', photoUrl);
                      },
                    )
                  else
                    const Text('Araç fotoğrafı yüklenmemiş.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildDocImagePreview(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Expanded(
          child: InkWell(
            onTap: () => _showImageZoom(url),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // TAB 2: DISPUTES
  Widget _buildDisputesTab() {
    if (_allDisputes.isEmpty) {
      return _buildEmptyState('Herhangi bir uyuşmazlık / destek talebi bulunmuyor.');
    }

    final disp = _selectedDispute;
    final isMobile = MediaQuery.of(context).size.width < 750;
    if (disp == null && !isMobile) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Disputes list sidebar
        if (!isMobile || !_showDetailsMobile)
          isMobile
          ? Expanded(
            child: Container(
              decoration: const BoxDecoration(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allDisputes.length,
                itemBuilder: (context, index) {
                  final d = _allDisputes[index];
                  final isSelected = disp != null && d.id == disp.id;

                  return Card(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        _selectDispute(d);
                        if (isMobile) setState(() => _showDetailsMobile = true);
                      },
                      title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: d.status == DisputeStatus.resolved
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(d.status.label, style: TextStyle(fontSize: 10, color: d.status == DisputeStatus.resolved ? AppColors.success : AppColors.error)),
                          ),
                          const SizedBox(width: 8),
                          Text('${d.createdAt.day}.${d.createdAt.month}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          )
          : SizedBox(
            width: 320,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allDisputes.length,
                itemBuilder: (context, index) {
                  final d = _allDisputes[index];
                  final isSelected = disp != null && d.id == disp.id;

                  return Card(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _selectDispute(d),
                      title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: d.status == DisputeStatus.resolved
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(d.status.label, style: TextStyle(fontSize: 10, color: d.status == DisputeStatus.resolved ? AppColors.success : AppColors.error)),
                          ),
                          const SizedBox(width: 8),
                          Text('${d.createdAt.day}.${d.createdAt.month}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),

        // Dispute details
        if (disp != null && (!isMobile || _showDetailsMobile))
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
              child: Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isMobile) ...[
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() => _showDetailsMobile = false),
                              icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                              label: const Text('Uyuşmazlık Listesine Dön', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),
                      ],
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(disp.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Uyuşmazlık ID: ${disp.id}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 16),
                        if (disp.status == DisputeStatus.pending || disp.status == DisputeStatus.investigating)
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed: () => _resolveDispute(disp.id, DisputeStatus.dismissed),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                ),
                                child: const Text('Talebi Reddet / Kapat'),
                              ),
                              ElevatedButton(
                                onPressed: () => _resolveDispute(disp.id, DisputeStatus.resolved),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                child: const Text('Sorun Çözüldü İşaretle', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: disp.status == DisputeStatus.resolved ? AppColors.success.withValues(alpha: 0.15) : AppColors.divider,
                              border: Border.all(color: disp.status == DisputeStatus.resolved ? AppColors.success : AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Karar: ${disp.status.label}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: disp.status == DisputeStatus.resolved ? AppColors.success : AppColors.textPrimary),
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(disp.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text('Uyuşmazlık ID: ${disp.id}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (disp.status == DisputeStatus.pending || disp.status == DisputeStatus.investigating)
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _resolveDispute(disp.id, DisputeStatus.dismissed),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                ),
                                child: const Text('Talebi Reddet / Kapat'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _resolveDispute(disp.id, DisputeStatus.resolved),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                child: const Text('Sorun Çözüldü İşaretle', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: disp.status == DisputeStatus.resolved ? AppColors.success.withValues(alpha: 0.15) : AppColors.divider,
                              border: Border.all(color: disp.status == DisputeStatus.resolved ? AppColors.success : AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Karar: ${disp.status.label}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: disp.status == DisputeStatus.resolved ? AppColors.success : AppColors.textPrimary),
                            ),
                          ),
                      ],
                    ),
                  const Divider(color: AppColors.border, height: 40),

                  // Parties
                  const Text('İlgili Taraflar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    _buildPartyCard('Şikayeti Paylaşan (Reporter)', disp.reporterId),
                    const SizedBox(height: 16),
                    _buildPartyCard('Şikayet Edilen (Reported)', disp.reportedId),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildPartyCard('Şikayeti Paylaşan (Reporter)', disp.reporterId),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildPartyCard('Şikayet Edilen (Reported)', disp.reportedId),
                        ),
                      ],
                    ),
                  const Divider(color: AppColors.border, height: 40),

                  // Description
                  const Text('Olay Açıklaması', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Text(
                      disp.description,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 40),

                  // Chat Logs Visualizer
                  const Text('İletişim Sohbet Kayıtları (Chat Logs)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _loadingChatLogs
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _selectedDisputeChatLogs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('Bu talebe ait herhangi bir mesajlaşma kaydı bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            )
                          : Container(
                              height: 300,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _selectedDisputeChatLogs.length,
                                itemBuilder: (context, idx) {
                                  final msg = _selectedDisputeChatLogs[idx];
                                  final isReporter = msg.senderId == disp.reporterId;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    alignment: isReporter ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isMobile ? 0.7 : 0.4)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isReporter ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isReporter ? 'Şikayetçi' : 'Şikayet Edilen',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isReporter ? AppColors.accent : AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(msg.content, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                  const Divider(color: AppColors.border, height: 40),

                  // Admin Notes input
                  const Text('Yönetici İnceleme Notları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adminNotesController,
                    maxLines: 4,
                    readOnly: disp.status == DisputeStatus.resolved || disp.status == DisputeStatus.dismissed,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: 'Uyuşmazlıkla ilgili inceleme notlarını buraya kaydedin...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildPartyCard(String title, String userId) {
    return FutureBuilder<UserModel?>(
      future: AuthRepository().getUserProfile(userId),
      builder: (context, snap) {
        final name = snap.data?.fullName ?? 'Yükleniyor...';
        final role = snap.data?.role.label ?? '';
        final phone = snap.data?.phone ?? 'Belirtilmemiş';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Rol: $role | Tel: $phone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: DRIVERS
  Widget _buildDriversTab() {
    final query = _driverSearchController.text.toLowerCase().trim();
    final list = _allDrivers.where((d) {
      final prof = d['profiles'] as Map<String, dynamic>;
      final name = (prof['full_name'] as String? ?? '').toLowerCase();
      final plate = (d['vehicle_plate'] as String? ?? '').toLowerCase();
      return name.contains(query) || plate.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _driverSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Sürücü adı veya araç plakası ile ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            child: list.isEmpty
                ? _buildEmptyState('Eşleşen sürücü bulunamadı.')
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('Ad Soyad')),
                      DataColumn(label: Text('Telefon')),
                      DataColumn(label: Text('Araç Plakası')),
                      DataColumn(label: Text('Puan')),
                      DataColumn(label: Text('Evrak Onay')),
                      DataColumn(label: Text('İşlem')),
                    ],
                    rows: list.map((d) {
                      final prof = d['profiles'] as Map<String, dynamic>;
                      final isVerified = d['is_verified'] as bool? ?? false;
                      final isSuspended = prof['is_suspended'] as bool? ?? false;
                      final rating = (d['rating'] as num?)?.toDouble() ?? 5.0;

                      return DataRow(
                        cells: [
                          DataCell(Text(prof['full_name'] ?? 'Bilinmiyor')),
                          DataCell(Text(prof['phone'] ?? '-')),
                          DataCell(Text(d['vehicle_plate'] ?? '-')),
                          DataCell(Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1)),
                            ],
                          )),
                          DataCell(Icon(
                            isVerified ? Icons.verified : Icons.warning_amber_rounded,
                            color: isVerified ? AppColors.success : AppColors.warning,
                          )),
                          DataCell(
                            TextButton(
                              onPressed: () => _toggleUserBlock(prof['id'], !isSuspended),
                              child: Text(
                                isSuspended ? 'Engeli Kaldır' : 'Engelle',
                                style: TextStyle(color: isSuspended ? AppColors.accent : AppColors.error),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 4: CUSTOMERS
  Widget _buildCustomersTab() {
    final query = _customerSearchController.text.toLowerCase().trim();
    final list = _allCustomers.where((c) {
      return c.fullName.toLowerCase().contains(query) || c.email.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Müşteri adı veya e-posta ile ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            child: list.isEmpty
                ? _buildEmptyState('Müşteri bulunamadı.')
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('Ad Soyad')),
                      DataColumn(label: Text('E-posta')),
                      DataColumn(label: Text('Telefon')),
                      DataColumn(label: Text('Puan')),
                      DataColumn(label: Text('İşlem')),
                    ],
                    rows: list.map((c) {
                      final isSuspended = c.isSuspended;

                      return DataRow(
                        cells: [
                          DataCell(Text(c.fullName)),
                          DataCell(Text(c.email)),
                          DataCell(Text(c.phone ?? '-')),
                          DataCell(Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(c.rating.toStringAsFixed(1)),
                            ],
                          )),
                          DataCell(
                            TextButton(
                              onPressed: () => _toggleUserBlock(c.id, !isSuspended),
                              child: Text(
                                isSuspended ? 'Engeli Kaldır' : 'Engelle',
                                style: TextStyle(color: isSuspended ? AppColors.accent : AppColors.error),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 5: REQUESTS
  Widget _buildRequestsTab() {
    final query = _requestSearchController.text.toLowerCase().trim();
    final list = _allRequests.where((r) {
      final brand = r.carBrand.toLowerCase();
      final model = r.carModel.toLowerCase();
      final zone = (r.destinationIndustryZone ?? '').toLowerCase();
      return brand.contains(query) || model.contains(query) || zone.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _requestSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Araç markası, modeli veya sanayi bölgesi ile ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            child: list.isEmpty
                ? _buildEmptyState('Talep bulunamadı.')
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('Araç')),
                      DataColumn(label: Text('Arıza Tipi')),
                      DataColumn(label: Text('Hedef Sanayi')),
                      DataColumn(label: Text('Fiyat')),
                      DataColumn(label: Text('Durum')),
                      DataColumn(label: Text('Tarih')),
                    ],
                    rows: list.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${r.carBrand} ${r.carModel}')),
                          DataCell(Text(r.problemType ?? '-')),
                          DataCell(Text(r.destinationIndustryZone ?? '-')),
                          DataCell(Text('${r.price} TL')),
                          DataCell(Text(r.status.label, style: TextStyle(color: r.status.color, fontWeight: FontWeight.bold))),
                          DataCell(Text('${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year}')),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // Common UI helper widgets
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 28, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(Icons.folder_open_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialChartCard() {
    final dailyData = <String, double>{};
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.day}/${date.month}';
      dailyData[key] = 0.0;
    }

    for (var r in _allRequests) {
      if (r.status.dbValue == 'completed' && r.completedAt != null) {
        final key = '${r.completedAt!.day}/${r.completedAt!.month}';
        if (dailyData.containsKey(key)) {
          dailyData[key] = dailyData[key]! + r.price;
        }
      }
    }

    final maxVal = dailyData.values.fold(100.0, (max, v) => v > max ? v : max);

    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mali Analiz ve Günlük Ciro Dağılımı (Son 7 Gün)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Toplam Ciro: ${_totalEarnings.toStringAsFixed(2)} TL',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dailyData.entries.map((e) {
                  final double percentage = e.value / maxVal;
                  final double barHeight = (percentage * 150).clamp(10.0, 150.0);
                  
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          e.value > 0 ? '${e.value.toInt()} TL' : '',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          e.key,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMapTab() {
    final activeRequests = _allRequests.where((r) => r.status.dbValue != 'completed' && r.status.dbValue != 'cancelled').toList();
    final availableDrivers = _allDrivers.where((d) => d['is_available'] == true).toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Available Drivers List (Left Panel)
          Expanded(
            flex: 1,
            child: Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.drive_eta, color: Colors.green),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Müsait Çekiciler',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${availableDrivers.length} Sürücü Çevrimiçi & Hazır', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          if (availableDrivers.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Şu an aktif çevrimiçi sürücü bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))),
                          ...availableDrivers.map((d) {
                            final profile = d['profiles'] as Map?;
                            final name = profile?['full_name'] ?? 'Sürücü';
                            final phone = profile?['phone'] ?? 'Telefon Yok';
                            final plate = d['vehicle_plate'] ?? 'Plaka Yok';
                            final score = d['rating'] as num? ?? 5.0;

                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.border,
                                  child: Icon(Icons.person, color: AppColors.textPrimary),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Plaka: $plate | Tel: $phone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(score.toStringAsFixed(1), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          // Active Operations List (Right Panel)
          Expanded(
            flex: 1,
            child: Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.local_shipping, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Aktif Operasyonlar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${activeRequests.length} Kurtarma Talebi İşlemde', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          if (activeRequests.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Şu an aktif kurtarma talebi bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))),
                          ...activeRequests.map((r) => Card(
                            color: AppColors.surface,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: r.status.color.withValues(alpha: 0.5))),
                            child: ListTile(
                              title: Text(r.carPlate, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.destinationIndustryZone ?? 'Hedef OSB Seçilmedi', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  Text('Ücret: ${r.price.toInt()} TL', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: r.status.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(r.status.label, style: TextStyle(color: r.status.color, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Puanlama ve Kullanıcı Değerlendirme Geçmişi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('${_allRatings.length} Değerlendirme Kaydedildi', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Tarih', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Değerlendiren', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Değerlendirilen', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Puan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Yorum', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                    ],
                    rows: _allRatings.map((r) {
                      final date = r['created_at'] != null ? DateTime.parse(r['created_at'] as String) : DateTime.now();
                      final rater = (r['rater'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
                      final rated = (r['rated'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
                      final score = r['score'] as int? ?? 5;
                      final comment = r['comment'] as String? ?? '-';

                      return DataRow(
                        cells: [
                          DataCell(Text('${date.day}/${date.month}/${date.year}')),
                          DataCell(Text(rater)),
                          DataCell(Text(rated)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return Icon(
                                Icons.star_rounded,
                                color: index < score ? Colors.amber : AppColors.textSecondary.withValues(alpha: 0.3),
                                size: 16,
                              );
                            }),
                          )),
                          DataCell(Text(comment)),
                        ],
                      );
                    }).toList(),
                  ).customStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// Extension to allow DataTable to take custom typography colors easily
extension DataTableTextColor on DataTable {
  Widget get customStyle => Theme(
        data: ThemeData.dark(),
        child: this,
      );
}
