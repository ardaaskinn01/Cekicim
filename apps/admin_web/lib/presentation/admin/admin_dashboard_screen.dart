import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/extensions/request_status_extension.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_models/message_model.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import '../../core/utils/export_service.dart';
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
  int _pendingApprovalsCount = 0;
  int _unresolvedDisputesCount = 0;

  // Test requests tracking (excluded from financial calculations)
  final Set<String> _testRequestIds = {};
  bool _filterExcludeTestsInAudit = true;

  // Selection states for details view
  Map<String, dynamic>? _selectedDriverApproval;
  Map<String, dynamic>? _selectedArchiveDriver;
  DisputeModel? _selectedDispute;
  List<MessageModel> _selectedDisputeChatLogs = [];
  bool _loadingChatLogs = false;

  // Live Map selection states
  Map<String, dynamic>? _selectedLiveDriver;
  ServiceRequestModel? _selectedLiveRequest;

  // Filters for Requests Tab
  String _requestStatusFilter = 'all';
  String _requestDateFilter = 'all';
  String _requestPriceFilter = 'all';

  // Filters for Drivers Tab
  String _driverStatusFilter = 'all';
  String _driverRatingFilter = 'all';

  // Filters for Customers Tab
  String _customerStatusFilter = 'all';
  String _customerRatingFilter = 'all';

  // ZIP batch download progress
  bool _isDownloadingArchive = false;
  String _archiveDownloadStatus = '';

  // Search controllers
  final _driverSearchController = TextEditingController();
  final _archiveSearchController = TextEditingController();
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
    _archiveSearchController.dispose();
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
      try {
        dynamic requestsData;
        try {
          requestsData = await client
              .from('service_requests')
              .select('*, customer:profiles!service_requests_customer_id_fkey(full_name), driver:profiles!service_requests_driver_id_fkey(full_name), ratings(*)')
              .order('created_at', ascending: false);
        } catch (joinErr) {
          debugPrint('[AdminPanel] Join query failed, falling back to simple select: $joinErr');
          requestsData = await client
              .from('service_requests')
              .select('*')
              .order('created_at', ascending: false);
        }
        _allRequests = (requestsData as List)
            .map((json) {
              final map = Map<String, dynamic>.from(json);
              final req = ServiceRequestModel.fromJson(map);
              // Check if marked as test in DB column or problemDescription tag
              final isTest = map['is_test'] == true ||
                  (req.problemDescription ?? '').trim().startsWith('[TEST]') ||
                  (req.cancellationReason ?? '').trim().startsWith('[TEST]');
              if (isTest) {
                _testRequestIds.add(req.id);
              }
              return req;
            })
            .toList();
      } catch (e) {
        debugPrint('[AdminPanel] service_requests load error: $e');
      }

      // 2. Fetch unverified drivers (onboarding completed but not verified)
      try {
        final unverifiedData = await client
            .from('drivers')
            .select('*, profiles(*)')
            .eq('is_verified', false)
            .neq('vehicle_plate', '');
        _unverifiedDrivers = (unverifiedData as List)
            .where((d) => d['iban'] != null || d['driver_license_url'] != null)
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
        debugPrint('[AdminPanel] unverified drivers: ${_unverifiedDrivers.length}');
      } catch (e) {
        debugPrint('[AdminPanel] unverified drivers load error: $e');
      }

      // 3. Fetch all drivers (and ensure unverified drivers are offline)
      try {
        await client
            .from('drivers')
            .update({'is_available': false})
            .eq('is_verified', false)
            .eq('is_available', true);
      } catch (e) {
        debugPrint('[AdminPanel] unverified driver offline sync notice: $e');
      }

      try {
        final allDriversData = await client
            .from('drivers')
            .select('*, profiles(*)');
        _allDrivers = List<Map<String, dynamic>>.from(allDriversData);
      } catch (e) {
        debugPrint('[AdminPanel] all drivers load error: $e');
      }

      // 4. Fetch all customers (profiles with role customer)
      try {
        final customersData = await client
            .from('profiles')
            .select()
            .eq('role', 'customer');
        _allCustomers = (customersData as List)
            .map((json) => UserModel.fromJson(json))
            .toList();
      } catch (e) {
        debugPrint('[AdminPanel] customers load error: $e');
      }

      // 5. Fetch all disputes
      try {
        _allDisputes = await DisputeRepository().getAllDisputes();
      } catch (e) {
        debugPrint('[AdminPanel] disputes load error: $e');
      }

      // 6. Fetch all ratings
      try {
        final ratingsData = await client
            .from('ratings')
            .select('*, rater:profiles!rater_id(*), rated:profiles!rated_id(*)');
        _allRatings = List<Map<String, dynamic>>.from(ratingsData);
      } catch (e) {
        debugPrint('[AdminPanel] ratings load error: $e');
      }

      // Recalculate statistics (exclude test requests from financial totals)
      _totalEarnings = _allRequests
          .where((r) => r.status.dbValue == 'completed' && !_testRequestIds.contains(r.id))
          .fold(0.0, (sum, r) => sum + r.price);

      _activeRequestsCount = _allRequests
          .where((r) => r.status.dbValue != 'completed' && r.status.dbValue != 'cancelled')
          .length;

      _pendingApprovalsCount = _unverifiedDrivers.length;

      _unresolvedDisputesCount = _allDisputes
          .where((d) => d.status == DisputeStatus.pending || d.status == DisputeStatus.investigating)
          .length;

      // Auto-select first elements if selection is null
      if (_unverifiedDrivers.isNotEmpty && _selectedDriverApproval == null) {
        _selectedDriverApproval = _unverifiedDrivers.first;
      }
      final verifiedDrivers = _allDrivers.where((d) => (d['is_verified'] as bool? ?? false)).toList();
      if (verifiedDrivers.isNotEmpty && _selectedArchiveDriver == null) {
        _selectedArchiveDriver = verifiedDrivers.first;
      }
      if (_allDisputes.isNotEmpty && _selectedDispute == null) {
        _selectDispute(_allDisputes.first);
      }
    } catch (e) {
      debugPrint('[AdminPanel] _loadDashboardData top-level error: $e');
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
      // Use SECURITY DEFINER RPC to bypass RLS for admin operations
      await client.rpc('admin_verify_driver', params: {'driver_id': driverId});

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
          SnackBar(content: Text('Onaylama hatası: $e'), backgroundColor: AppColors.error),
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
      // Use SECURITY DEFINER RPC to bypass RLS for admin operations
      await client.rpc('admin_reject_driver', params: {'driver_id': driverId, 'reason': reason});

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
          SnackBar(content: Text('Ret hatası: $e'), backgroundColor: AppColors.error),
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
      // Use SECURITY DEFINER RPC to bypass RLS for admin operations
      await client.rpc('admin_toggle_user_block', params: {'target_user_id': userId, 'should_block': block});
      await _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(block ? 'Kullanıcı engellendi.' : 'Kullanıcı engeli kaldırıldı.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Engelleme hatası: $e'), backgroundColor: AppColors.error),
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

  void _showRequestDetailsDialog(ServiceRequestModel req) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Talep Detayları', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Talep ID: ${req.id}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Name (Big and prominent with rating)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Müşteri', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            req.customerName ?? 'Müşteri Bilinmiyor',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (req.customerRatingFromDriver != null)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${req.customerRatingFromDriver!.toInt()}/5',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Driver Name (Big and prominent with rating)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sürücü', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            req.driverName ?? (req.driverId != null ? 'Sürücü Atandı' : 'Bekliyor'),
                            style: TextStyle(
                              color: req.driverName != null ? AppColors.textPrimary : Colors.orange, 
                              fontSize: 20, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      if (req.driverRatingFromCustomer != null)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${req.driverRatingFromCustomer!.toInt()}/5',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  _buildDetailItem('Araç Bilgisi', '${req.carBrand} ${req.carModel} (${req.carColor})'),
                  const SizedBox(height: 12),
                  _buildDetailItem('Plaka', req.carPlate),
                  const SizedBox(height: 12),
                  _buildDetailItem('Arıza Tipi', req.problemType),
                  if (req.problemDescription != null && req.problemDescription!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailItem('Arıza Açıklaması', req.problemDescription!),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailItem('Alınacak Adres', req.customerAddress ?? '-'),
                  const SizedBox(height: 12),
                  _buildDetailItem('Gidilecek Adres', req.destinationAddress ?? '-'),
                  const SizedBox(height: 12),
                  _buildDetailItem('Hedef Sanayi', req.destinationIndustryZone ?? '-'),
                  const SizedBox(height: 12),
                  _buildDetailItem('Mesafe / Fiyat', '${req.distanceKm.toStringAsFixed(1)} KM / ${req.price} TL'),
                  const SizedBox(height: 12),
                  _buildDetailItem('Durum', req.status.label),
                  const SizedBox(height: 12),
                  _buildDetailItem('Tarih', '${req.createdAt.day}.${req.createdAt.month}.${req.createdAt.year} ${req.createdAt.hour}:${req.createdAt.minute}'),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _toggleTestRequest(req.id);
              },
              icon: Icon(
                _testRequestIds.contains(req.id) ? Icons.check_circle_outline : Icons.bug_report_outlined,
                color: _testRequestIds.contains(req.id) ? AppColors.success : Colors.amber,
                size: 16,
              ),
              label: Text(
                _testRequestIds.contains(req.id) ? 'Testten Çıkar' : 'Test Olarak İşaretle',
                style: TextStyle(
                  color: _testRequestIds.contains(req.id) ? AppColors.success : Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: (_testRequestIds.contains(req.id) ? AppColors.success : Colors.amber).withValues(alpha: 0.6)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

  void _showMissingDocumentDialog(String driverId, String driverName) {
    String selectedReason = 'Ehliyet ve/veya araç ruhsatı belgeniz okunaksız veya net değil. Lütfen belgelerinizi tekrar yükleyiniz.';
    final customController = TextEditingController(text: selectedReason);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Eksik Evrak Bildirimi & Talep', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sürücü: $driverName', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                const Text(
                  'Bu işlem sürücüyü anında bilgilendirir ve sürücü uygulamasında belgelerini yeniden yükleyip gönderebilmesi için başvuru ekranını açar.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('Hızlı Şablon Seçin:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('Ehliyet / Ruhsat Okunaksız', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  subtitle: const Text('Fotoğraf bulanık veya eksik.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  value: 'Ehliyet ve/veya araç ruhsatı belgeniz okunaksız veya net değil. Lütfen belgelerinizi tekrar yükleyiniz.',
                  groupValue: selectedReason,
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() {
                      selectedReason = val!;
                      customController.text = val;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Vergi Levhası / Adli Sicil Eksik', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  subtitle: const Text('Yasal zorunlu evraklar sisteme yüklenmemiş.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  value: 'Vergi levhası ve/veya adli sicil kaydı belgeniz eksik. Lütfen geçerli belgeleri yükleyiniz.',
                  groupValue: selectedReason,
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() {
                      selectedReason = val!;
                      customController.text = val;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Araç Fotoğrafları Yetersiz', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  subtitle: const Text('Aracın 4 açıdan (ön, arka, sağ, sol) çekimi gerekiyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  value: 'Çekici aracınızın 4 cepheden çekilmiş net fotoğrafları eksik veya standartlara uymuyor.',
                  groupValue: selectedReason,
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() {
                      selectedReason = val!;
                      customController.text = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Sürücüye İletilecek Özel Açıklama',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final reason = customController.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.pop(context);
                  _rejectDriver(driverId, reason);
                }
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Bildirimi Gönder'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendNotificationDialog(String driverId, String driverName) {
    final titleController = TextEditingController(text: 'Çekicim Yönetim Bildirimi');
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: AppColors.accent),
            SizedBox(width: 10),
            Text('Sürücüye Bildirim Gönder', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alıcı: $driverName', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Hızlı Şablonlar:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Konum Servisi Uyarısı'),
                    backgroundColor: AppColors.surface,
                    labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    onPressed: () {
                      messageController.text = 'Lütfen cihazınızın konum servisinin açık olduğundan emin olunuz.';
                    },
                  ),
                  ActionChip(
                    label: const Text('Acil Görev Çağrısı'),
                    backgroundColor: AppColors.surface,
                    labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    onPressed: () {
                      messageController.text = 'Bölgenizde acil kurtarma talebi bulunmaktadır. Lütfen çevrimiçi durumunuzu kontrol ediniz.';
                    },
                  ),
                  ActionChip(
                    label: const Text('Evrak Hatırlatması'),
                    backgroundColor: AppColors.surface,
                    labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    onPressed: () {
                      messageController.text = 'Süresi yaklaşan resmi belgelerinizi lütfen profilinizden güncelleyiniz.';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Bildirim Başlığı',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Bildirim Mesajı',
                  hintText: 'Sürücüye iletilecek mesajı yazınız...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _sendNotificationToUser(driverId, titleController.text.trim(), messageController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotificationToUser(String userId, String title, String body) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim başarıyla iletildi.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim kaydedildi: $e'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  Future<void> _toggleTestRequest(String requestId) async {
    final willBeTest = !_testRequestIds.contains(requestId);
    setState(() {
      if (willBeTest) {
        _testRequestIds.add(requestId);
      } else {
        _testRequestIds.remove(requestId);
      }
      // Recalculate earnings
      _totalEarnings = _allRequests
          .where((r) => r.status.dbValue == 'completed' && !_testRequestIds.contains(r.id))
          .fold(0.0, (sum, r) => sum + r.price);
    });

    try {
      final client = SupabaseService.instance.client;
      // Try updating is_test column directly
      try {
        await client.from('service_requests').update({'is_test': willBeTest}).eq('id', requestId);
      } catch (colErr) {
        debugPrint('[AdminPanel] is_test column update notice, tagging problem_description fallback: $colErr');
        // Fallback: tag problem_description with [TEST] prefix
        final req = _allRequests.firstWhere((r) => r.id == requestId);
        String currentDesc = req.problemDescription ?? '';
        if (willBeTest && !currentDesc.startsWith('[TEST]')) {
          currentDesc = '[TEST] $currentDesc'.trim();
        } else if (!willBeTest && currentDesc.startsWith('[TEST]')) {
          currentDesc = currentDesc.replaceFirst('[TEST]', '').trim();
        }
        await client.from('service_requests').update({'problem_description': currentDesc}).eq('id', requestId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(willBeTest
                ? 'Talep TEST verisi olarak işaretlendi. Mali tablolardan hariç tutuldu.'
                : 'Talep test işaretinden çıkarıldı ve mali tablolara dahil edildi.'),
            backgroundColor: willBeTest ? AppColors.warning : AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AdminPanel] toggle test request error: $e');
    }
  }

  void _showFinancialAuditDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalGmv = 0.0;
          double totalDriverPayout = 0.0;
          double totalPlatformFee = 0.0;
          int completedCount = 0;

          final completedRequests = _allRequests.where((r) => r.status.dbValue == 'completed').toList();

          for (var r in completedRequests) {
            final isTest = _testRequestIds.contains(r.id);
            if (_filterExcludeTestsInAudit && isTest) continue;

            completedCount++;
            totalGmv += r.price;
            // Platform komisyonu %10, Sürücü hakedişi %90
            totalDriverPayout += (r.price * 0.90);
            totalPlatformFee += (r.price * 0.10);
          }

          final avgTicket = completedCount > 0 ? (totalGmv / completedCount) : 0.0;
          final testCount = completedRequests.where((r) => _testRequestIds.contains(r.id)).length;

          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent),
                    const SizedBox(width: 10),
                    const Text('Finans & Hakediş Denetim Modülü', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Komisyon: %10', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAuditMetric('Brüt Ciro (GMV)', '${totalGmv.toStringAsFixed(0)} TL', AppColors.accent),
                          _buildAuditMetric('Sürücü Hakediş (%90)', '${totalDriverPayout.toStringAsFixed(0)} TL', const Color(0xFF3B82F6)),
                          _buildAuditMetric('Net Komisyon (%10)', '${totalPlatformFee.toStringAsFixed(0)} TL', AppColors.success),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Test toggle control bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _filterExcludeTestsInAudit ? const Color(0xFF1E293B) : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _filterExcludeTestsInAudit ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: _filterExcludeTestsInAudit ? Colors.amber : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Test Taleplerini Hariç Tut ($testCount Test Kaydı)',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Switch(
                            value: _filterExcludeTestsInAudit,
                            activeColor: AppColors.accent,
                            onChanged: (val) {
                              setDialogState(() {
                                _filterExcludeTestsInAudit = val;
                              });
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detail stats list
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildAuditRow('Dahil Edilen Görev Sayısı:', '$completedCount Adet'),
                          const Divider(color: AppColors.border),
                          _buildAuditRow('Ortalama Sefer Ücreti:', '${avgTicket.toStringAsFixed(1)} TL'),
                          const Divider(color: AppColors.border),
                          _buildAuditRow('Sürücülere Ödenecek Toplam Hakediş (%90):', '${totalDriverPayout.toStringAsFixed(2)} TL'),
                          const Divider(color: AppColors.border),
                          _buildAuditRow('Platform Kasa Bakiyesi (%10 Komisyon):', '${totalPlatformFee.toStringAsFixed(2)} TL', isBold: true, highlightColor: AppColors.accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Request Level Test Marking List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tamamlanan Talepler & Test Denetimi',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${completedRequests.length} talep incelendi',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: completedRequests.isEmpty
                          ? const Center(child: Text('Tamamlanmış talep bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: completedRequests.length,
                              separatorBuilder: (context, _) => const Divider(color: AppColors.border, height: 1),
                              itemBuilder: (context, idx) {
                                final req = completedRequests[idx];
                                final isTest = _testRequestIds.contains(req.id);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isTest ? Colors.amber.withValues(alpha: 0.08) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      if (isTest)
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                          ),
                                          child: const Text('TEST', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${req.carBrand} ${req.carModel} • ${req.price.toStringAsFixed(0)} TL',
                                              style: TextStyle(
                                                color: isTest ? AppColors.textSecondary : AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                decoration: isTest ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            Text(
                                              'Müşteri: ${req.customerName ?? "Bilinmiyor"}  •  Sürücü: ${req.driverName ?? "Bilinmiyor"}',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await _toggleTestRequest(req.id);
                                          setDialogState(() {});
                                        },
                                        icon: Icon(
                                          isTest ? Icons.check_circle_outline : Icons.bug_report_outlined,
                                          size: 14,
                                          color: isTest ? AppColors.success : Colors.amber,
                                        ),
                                        label: Text(
                                          isTest ? 'Testten Çıkar' : 'Test Olarak İşaretle',
                                          style: TextStyle(
                                            color: isTest ? AppColors.success : Colors.amber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: (isTest ? AppColors.success : Colors.amber).withValues(alpha: 0.6)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ExportService.exportFinancialReportToCsv(_allRequests, excludedRequestIds: _testRequestIds);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Finansal rapor (%10 komisyon, testler hariç) CSV olarak indirildi.'), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Mali Raporu İndir (CSV)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuditMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAuditRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: highlightColor ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(dynamic dateValue) {
    if (dateValue == null) return 'Bilinmiyor';
    try {
      final date = dateValue is DateTime ? dateValue : DateTime.parse(dateValue.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} saat önce';
      return '${diff.inDays} gün önce';
    } catch (_) {
      return 'Bilinmiyor';
    }
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
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_shipping, color: AppColors.accent, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Çekicim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'PORTAL',
                              style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'v2.4 Pro',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                _buildSidebarMenuItem(2, 'Sürücü Arşivi (Evrak & Foto)', Icons.folder_shared_outlined),
                _buildSidebarMenuItem(3, 'Uyuşmazlık Merkezi', Icons.gavel_outlined, badgeCount: _unresolvedDisputesCount),
                _buildSidebarMenuItem(4, 'Çekici Sürücüleri', Icons.drive_eta_outlined),
                _buildSidebarMenuItem(5, 'Müşteriler', Icons.people_outline),
                _buildSidebarMenuItem(6, 'Tüm Talepler', Icons.history_edu_outlined),
                _buildSidebarMenuItem(7, 'Canlı Takip Haritası', Icons.map_outlined),
                _buildSidebarMenuItem(8, 'Değerlendirmeler', Icons.star_outline),
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
      case 2: pageTitle = isMobile ? 'Sürücü Arşivi' : 'Sürücü Evrak ve Fotoğraf Arşivi'; break;
      case 3: pageTitle = isMobile ? 'Uyuşmazlık' : 'Uyuşmazlık Çözüm Merkezi'; break;
      case 4: pageTitle = 'Sürücüler'; break;
      case 5: pageTitle = 'Müşteriler'; break;
      case 6: pageTitle = isMobile ? 'Talepler' : 'Sistem Talep Kayıtları'; break;
      case 7: pageTitle = isMobile ? 'Canlı Harita' : 'Canlı Operasyon Haritası'; break;
      case 8: pageTitle = 'Değerlendirmeler'; break;
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
      case 2: return _buildDriverArchiveTab();
      case 3: return _buildDisputesTab();
      case 4: return _buildDriversTab();
      case 5: return _buildCustomersTab();
      case 6: return _buildRequestsTab();
      case 7: return _buildLiveMapTab();
      case 8: return _buildRatingsTab();
      default: return const Center(child: Text('Sekme bulunamadı.'));
    }
  }

  // TAB 0: DASHBOARD
  Widget _buildDashboardTab() {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Overview grid
          GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: isMobile ? 12 : 20,
            mainAxisSpacing: isMobile ? 12 : 20,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isMobile ? 1.15 : 1.35,
            children: [
              _buildStatCard(
                title: 'Toplam Ciro',
                value: '${_totalEarnings.toStringAsFixed(2)} TL',
                icon: Icons.monetization_on_outlined,
                color: AppColors.accent,
                trend: '+%14.2',
                isPositiveTrend: true,
                subtitle: 'geçen haftaya göre',
              ),
              _buildStatCard(
                title: 'Aktif Talepler',
                value: '$_activeRequestsCount',
                icon: Icons.local_shipping_outlined,
                color: const Color(0xFF3B82F6),
                trend: 'Canlı',
                isPositiveTrend: true,
                subtitle: 'operasyonda',
                onTap: () {
                  setState(() => _selectedMenuIndex = 7); // Live map
                },
              ),
              _buildStatCard(
                title: 'Onay Bekleyenler',
                value: '$_pendingApprovalsCount',
                icon: Icons.verified_user_outlined,
                color: AppColors.warning,
                trend: _pendingApprovalsCount > 0 ? 'Kuyrukta' : 'Güncel',
                isPositiveTrend: _pendingApprovalsCount == 0,
                subtitle: 'yeni evrak kontrolü',
                onTap: () {
                  setState(() => _selectedMenuIndex = 1); // Approvals
                },
              ),
              _buildStatCard(
                title: 'Uyuşmazlıklar',
                value: '$_unresolvedDisputesCount',
                icon: Icons.gavel_outlined,
                color: AppColors.error,
                trend: _unresolvedDisputesCount > 0 ? 'Aksiyon' : 'Çözüldü',
                isPositiveTrend: _unresolvedDisputesCount == 0,
                subtitle: 'açık dosya',
                onTap: () {
                  setState(() => _selectedMenuIndex = 3); // Disputes
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User statistics grid
          GridView.count(
            crossAxisCount: isMobile ? 1 : 2,
            crossAxisSpacing: isMobile ? 12 : 20,
            mainAxisSpacing: isMobile ? 12 : 20,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isMobile ? 2.3 : 2.9,
            children: [
              _buildStatCard(
                title: 'Toplam Çekici Sürücüsü',
                value: '${_allDrivers.length}',
                icon: Icons.drive_eta_outlined,
                color: const Color(0xFF6366F1),
                trend: '${_allDrivers.where((d) => d['is_verified'] == true).length} onaylı',
                isPositiveTrend: true,
                subtitle: 'sistemde kayıtlı çekici',
                onTap: () {
                  setState(() => _selectedMenuIndex = 4); // Drivers
                },
              ),
              _buildStatCard(
                title: 'Toplam Müşteri Portföyü',
                value: '${_allCustomers.length}',
                icon: Icons.people_outline,
                color: const Color(0xFF06B6D4),
                trend: 'Aktif',
                isPositiveTrend: true,
                subtitle: 'bireysel ve kurumsal kullanıcı',
                onTap: () {
                  setState(() => _selectedMenuIndex = 5); // Customers
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Analytics and Distribution Charts
          if (isMobile)
            Column(
              children: [
                _buildFinancialChartCard(),
                const SizedBox(height: 20),
                _buildRequestStatusChartCard(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildFinancialChartCard()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildRequestStatusChartCard()),
              ],
            ),
          const SizedBox(height: 28),

          // Recent Activity Log Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Son Talepler ve Canlı Akış',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'CANLI',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedMenuIndex = 6;
                  });
                },
                icon: const Text('Tümünü Gör', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                label: const Icon(Icons.arrow_forward, size: 15, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _allRequests.isEmpty
              ? _buildEmptyState('Sistemde talep kaydı bulunmuyor.')
              : Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allRequests.length > 8 ? 8 : _allRequests.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final req = _allRequests[index];
                      return InkWell(
                        onTap: () => _showRequestDetailsDialog(req),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: req.status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: req.status.color.withValues(alpha: 0.25)),
                                ),
                                child: Icon(Icons.local_shipping_outlined, color: req.status.color, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${req.carBrand} ${req.carModel}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppColors.border, width: 0.8),
                                          ),
                                          child: Text(
                                            req.carPlate,
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${req.customerAddress ?? "Belirtilmedi"} → ${req.destinationAddress ?? req.destinationIndustryZone ?? "Hedef Belirtilmedi"}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${req.price.toStringAsFixed(0)} TL',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: req.status.color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: req.status.color.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      req.status.label,
                                      style: TextStyle(color: req.status.color, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                            ],
                          ),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showMissingDocumentDialog(driver['id'], profile['full_name'] ?? 'Sürücü'),
                            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                            label: const Text('Eksik Evrak Bildir', style: TextStyle(color: AppColors.warning)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.warning)),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showRejectionDialog(driver['id']),
                            icon: const Icon(Icons.close_rounded, color: AppColors.error),
                            label: const Text('Reddet', style: TextStyle(color: AppColors.error)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _verifyDriver(driver['id']),
                            icon: const Icon(Icons.check_rounded, color: Colors.white),
                            label: const Text('Evrakları Onayla'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
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
                      _buildDetailItem(
                        'Araç Tipi',
                        driver['vehicle_type'] == 'small'
                            ? 'Küçük / Standart (Oto Çekici)'
                            : driver['vehicle_type'] == 'medium'
                                ? 'Orta (Ahtapot / Çift Katlı)'
                                : driver['vehicle_type'] == 'large'
                                    ? 'Büyük (Ağır Vasıta)'
                                    : (driver['vehicle_type'] ?? '-'),
                      ),
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
    final isPdf = url.toLowerCase().contains('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPdf) ...[
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, color: AppColors.accent, size: 18),
                  tooltip: 'Bu Belgeyi İndir',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => launchUrl(Uri.parse(url)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: InkWell(
            onTap: () {
              if (isPdf) {
                launchUrl(Uri.parse(url));
              } else {
                _showImageZoom(url);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                color: AppColors.surface,
                image: isPdf
                    ? null
                    : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
              ),
              child: isPdf
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                          SizedBox(height: 6),
                          Text('PDF Görüntüle', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // TAB 2: DRIVER ARCHIVE (Evrak & Fotoğraf Arşivi)
  Widget _buildDriverArchiveTab() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final query = _archiveSearchController.text.toLowerCase().trim();

    // Sadece kabul edilen (onaylı) sürücüler
    final acceptedDrivers = _allDrivers.where((d) {
      final isVerified = d['is_verified'] as bool? ?? false;
      if (!isVerified) return false;

      final prof = d['profiles'] as Map<String, dynamic>? ?? {};
      final name = (prof['full_name'] as String? ?? '').toLowerCase();
      final plate = (d['vehicle_plate'] as String? ?? '').toLowerCase();
      final phone = (prof['phone'] as String? ?? '').toLowerCase();

      return name.contains(query) || plate.contains(query) || phone.contains(query);
    }).toList();

    if (acceptedDrivers.isEmpty && query.isEmpty) {
      return _buildEmptyState('Sistemde onaylanmış ve arşive alınmış sürücü bulunmamaktadır.');
    }

    final driver = _selectedArchiveDriver ?? (acceptedDrivers.isNotEmpty ? acceptedDrivers.first : null);
    final profile = driver != null ? (driver['profiles'] as Map<String, dynamic>? ?? {}) : const <String, dynamic>{};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sol Sütun: Sürücü İsim Listesi ve Arama
        if (!isMobile || !_showDetailsMobile)
          SizedBox(
            width: isMobile ? MediaQuery.of(context).size.width : 340,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  // Arama Çubuğu
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _archiveSearchController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            hintText: 'İsim, plaka veya telefon ara...',
                            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isDownloadingArchive || acceptedDrivers.isEmpty
                              ? null
                              : () async {
                                  setState(() {
                                    _isDownloadingArchive = true;
                                    _archiveDownloadStatus = 'Hazırlanıyor...';
                                  });
                                  try {
                                    await ExportService.downloadAllDriversArchiveZip(
                                      acceptedDrivers,
                                      onProgress: (cur, tot, name) {
                                        if (mounted) {
                                          setState(() {
                                            _archiveDownloadStatus = '$cur / $tot ($name)';
                                          });
                                        }
                                      },
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Tüm sürücü arşivi klasörler halinde ZIP olarak indirildi.'), backgroundColor: AppColors.success),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isDownloadingArchive = false);
                                  }
                                },
                          icon: _isDownloadingArchive
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.archive_outlined, size: 16),
                          label: Text(
                            _isDownloadingArchive ? _archiveDownloadStatus : 'Tüm Arşivi İndir (ZIP)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  // Liste
                  Expanded(
                    child: acceptedDrivers.isEmpty
                        ? const Center(child: Text('Aramaya uygun sürücü bulunamadı.', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: acceptedDrivers.length,
                            itemBuilder: (context, index) {
                              final d = acceptedDrivers[index];
                              final prof = d['profiles'] as Map<String, dynamic>? ?? {};
                              final isSelected = driver != null && d['id'] == driver['id'];
                              final name = prof['full_name'] as String? ?? 'İsimsiz Sürücü';
                              final plate = d['vehicle_plate'] as String? ?? '-';
                              final avatarUrl = prof['avatar_url'] as String?;

                              return Card(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () {
                                    setState(() {
                                      _selectedArchiveDriver = d;
                                      if (isMobile) _showDetailsMobile = true;
                                    });
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.surface,
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.accent) : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Plaka: $plate',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.folder_open, size: 18, color: AppColors.accent),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

        // Sağ Sütun: Seçilen Sürücünün Tüm Arşiv Evrakları ve Araç Fotoğrafları
        if (driver != null && (!isMobile || _showDetailsMobile))
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
              child: Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
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
                              label: const Text('Arşiv Listesine Dön', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),
                      ],

                      // Sürücü Başlık ve Kimlik Bilgileri
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.surface,
                            backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                            child: profile['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.accent, size: 32) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      profile['full_name'] ?? 'İsimsiz Sürücü',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified, color: AppColors.success, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'E-posta: ${profile['email'] ?? '-'}  •  Telefon: ${profile['phone'] ?? '-'}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sürücü ID: ${driver['id']}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sürücü evrakları paketleniyor, lütfen bekleyiniz...'), duration: Duration(seconds: 2)),
                              );
                              await ExportService.downloadSingleDriverArchiveZip(driver);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sürücü evrakları ZIP olarak indirildi.'), backgroundColor: AppColors.success),
                                );
                              }
                            },
                            icon: const Icon(Icons.folder_zip_outlined, color: AppColors.accent, size: 16),
                            label: Text(isMobile ? 'ZIP İndir' : 'Evrakları İndir (.ZIP)', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accent, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 36),

                      // Araç ve Finans Detayları
                      const Text('Kayıtlı Araç ve Finans Bilgileri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 36,
                        runSpacing: 16,
                        children: [
                          _buildDetailItem('Plaka', driver['vehicle_plate'] ?? '-'),
                          _buildDetailItem(
                            'Araç Tipi',
                            driver['vehicle_type'] == 'small'
                                ? 'Küçük / Standart (Oto Çekici)'
                                : driver['vehicle_type'] == 'medium'
                                    ? 'Orta (Ahtapot / Çift Katlı)'
                                    : driver['vehicle_type'] == 'large'
                                        ? 'Büyük (Ağır Vasıta)'
                                        : (driver['vehicle_type'] ?? '-'),
                          ),
                          _buildDetailItem('IBAN Sahibi', driver['iban_owner_name'] ?? '-'),
                          _buildDetailItem('IBAN Numarası', driver['iban'] ?? '-'),
                          _buildDetailItem('Puan / Hizmet', '${(driver['rating'] as num?)?.toStringAsFixed(1) ?? "5.0"} ⭐ (${driver['total_services'] ?? 0} Sefer)'),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 36),

                      // Resmi Evraklar (Supabase Storage: driver-documents)
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          const Text('Resmi Evrak Arşivi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const Spacer(),
                          Text(
                            'Supabase Storage: driver-documents/${driver['id']}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      () {
                        final docItems = <Map<String, String>>[];
                        if (driver['driver_license_url'] != null && (driver['driver_license_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'Sürücü Ehliyeti', 'url': driver['driver_license_url']});
                        }
                        if (driver['vehicle_registration_url'] != null && (driver['vehicle_registration_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'Araç Ruhsatı', 'url': driver['vehicle_registration_url']});
                        }
                        if (driver['tax_plate_url'] != null && (driver['tax_plate_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'Vergi Levhası', 'url': driver['tax_plate_url']});
                        }
                        if (driver['criminal_record_url'] != null && (driver['criminal_record_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'Adli Sicil Kaydı', 'url': driver['criminal_record_url']});
                        }
                        if (driver['src_certificate_url'] != null && (driver['src_certificate_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'SRC Belgesi', 'url': driver['src_certificate_url']});
                        }
                        if (driver['psychotechnic_url'] != null && (driver['psychotechnic_url'] as String).isNotEmpty) {
                          docItems.add({'title': 'Psikoteknik Belgesi', 'url': driver['psychotechnic_url']});
                        }

                        if (docItems.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text('Bu sürücüye ait yüklenmiş resmi evrak bulunmuyor.', style: TextStyle(color: AppColors.textSecondary)),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 2 : 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: docItems.length,
                          itemBuilder: (context, i) => _buildDocImagePreview(docItems[i]['title']!, docItems[i]['url']!),
                        );
                      }(),

                      const Divider(color: AppColors.border, height: 36),

                      // Çekici Aracı Fotoğrafları (4 Açı)
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          const Text('Çekici Aracı Fotoğrafları (4 Açı)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      () {
                        final rawPhotos = driver['vehicle_photos'];
                        final photos = (rawPhotos is List)
                            ? rawPhotos.whereType<String>().where((p) => p.isNotEmpty && !p.contains('picsum')).toList()
                            : <String>[];

                        if (photos.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text('Bu araca ait yüklenmiş fotoğraf kaydı bulunmuyor.', style: TextStyle(color: AppColors.textSecondary)),
                          );
                        }

                        final labels = ['Ön Görünüm', 'Arka Görünüm', 'Sol Görünüm', 'Sağ Görünüm'];

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 2 : 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (context, idx) {
                            final label = idx < labels.length ? labels[idx] : 'Fotoğraf ${idx + 1}';
                            return _buildDocImagePreview(label, photos[idx]);
                          },
                        );
                      }(),
                    ],
                  ),
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(disp.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Uyuşmazlık ID: ${disp.id}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        if (disp.status == DisputeStatus.pending || disp.status == DisputeStatus.investigating)
                          Wrap(
                            spacing: 16,
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    final query = _driverSearchController.text.toLowerCase().trim();

    final list = _allDrivers.where((d) {
      final prof = d['profiles'] as Map<String, dynamic>? ?? {};
      final name = (prof['full_name'] as String? ?? '').toLowerCase();
      final plate = (d['vehicle_plate'] as String? ?? '').toLowerCase();
      final phone = (prof['phone'] as String? ?? '').toLowerCase();
      final matchesQuery = name.contains(query) || plate.contains(query) || phone.contains(query);
      if (!matchesQuery) return false;

      final isVerified = d['is_verified'] as bool? ?? false;
      final isSuspended = prof['is_suspended'] as bool? ?? false;
      final rating = (d['rating'] as num?)?.toDouble() ?? 5.0;

      // Status filter
      if (_driverStatusFilter == 'verified' && !isVerified) return false;
      if (_driverStatusFilter == 'pending' && isVerified) return false;
      if (_driverStatusFilter == 'suspended' && !isSuspended) return false;

      // Rating filter
      if (_driverRatingFilter == '4.5+' && rating < 4.5) return false;
      if (_driverRatingFilter == '4.0-4.5' && (rating < 4.0 || rating >= 4.5)) return false;
      if (_driverRatingFilter == 'below_4.0' && rating >= 4.0) return false;

      return true;
    }).toList();

    final hasActiveFilters = _driverStatusFilter != 'all' || _driverRatingFilter != 'all' || query.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arama & Dışa Aktarma (Export) Barı
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _driverSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _driverSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Sürücü adı, araç plakası veya telefon ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: list.isEmpty ? null : () => ExportService.exportDriversToCsv(list),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(isMobile ? 'CSV' : 'Sürücüleri Dışa Aktar (CSV)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Çoklu Filtreleme Barı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Durum:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tümü', _driverStatusFilter == 'all', () => setState(() => _driverStatusFilter = 'all')),
                    _buildFilterChip('Onaylı Sürücüler', _driverStatusFilter == 'verified', () => setState(() => _driverStatusFilter = 'verified'), color: AppColors.success),
                    _buildFilterChip('Onay Bekleyenler', _driverStatusFilter == 'pending', () => setState(() => _driverStatusFilter = 'pending'), color: AppColors.warning),
                    _buildFilterChip('Engellenenler', _driverStatusFilter == 'suspended', () => setState(() => _driverStatusFilter = 'suspended'), color: AppColors.error),
                    const SizedBox(width: 12),
                    const Text('Puan:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tüm Puanlar', _driverRatingFilter == 'all', () => setState(() => _driverRatingFilter = 'all')),
                    _buildFilterChip('4.5+ ⭐', _driverRatingFilter == '4.5+', () => setState(() => _driverRatingFilter = '4.5+'), color: Colors.amber),
                    _buildFilterChip('4.0 - 4.5 ⭐', _driverRatingFilter == '4.0-4.5', () => setState(() => _driverRatingFilter = '4.0-4.5')),
                    _buildFilterChip('4.0 Altı ⚠️', _driverRatingFilter == 'below_4.0', () => setState(() => _driverRatingFilter = 'below_4.0'), color: AppColors.error),
                  ],
                ),
                if (hasActiveFilters) ...[
                  const Divider(color: AppColors.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtrelenen: ${list.length} / ${_allDrivers.length} sürücü',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _driverStatusFilter = 'all';
                            _driverRatingFilter = 'all';
                            _driverSearchController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 14, color: AppColors.textSecondary),
                        label: const Text('Filtreleri Sıfırla', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          isMobile
              ? Column(
                  children: list.isEmpty
                      ? [_buildEmptyState('Eşleşen sürücü bulunamadı.')]
                      : list.map((d) => _buildDriverMobileCard(d)).toList(),
                )
              : Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                  child: list.isEmpty
                      ? _buildEmptyState('Eşleşen sürücü bulunamadı.')
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF162032)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), fontSize: 13, letterSpacing: 0.3),
                            dataTextStyle: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
                            horizontalMargin: 24,
                            columnSpacing: 28,
                            dividerThickness: 0.6,
                            columns: const [
                              DataColumn(label: Text('Ad Soyad')),
                              DataColumn(label: Text('Telefon')),
                              DataColumn(label: Text('Araç Plakası')),
                              DataColumn(label: Text('Puan')),
                              DataColumn(label: Text('Evrak Onay')),
                              DataColumn(label: Text('Hızlı İşlemler')),
                            ],
                            rows: list.map((d) {
                              final prof = d['profiles'] as Map<String, dynamic>? ?? {};
                              final isVerified = d['is_verified'] as bool? ?? false;
                              final isSuspended = prof['is_suspended'] as bool? ?? false;
                              final rating = (d['rating'] as num?)?.toDouble() ?? 5.0;
                              final driverId = d['id'] as String? ?? '';
                              final driverName = prof['full_name'] as String? ?? 'Sürücü';

                              return DataRow(
                                cells: [
                                  DataCell(Text(driverName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                  DataCell(Text(prof['phone'] ?? '-', style: const TextStyle(color: AppColors.textSecondary))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                                    child: Text(d['vehicle_plate'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                  )),
                                  DataCell(Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  )),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isVerified ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: (isVerified ? AppColors.success : AppColors.warning).withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isVerified ? Icons.check_circle : Icons.pending_actions,
                                          size: 13,
                                          color: isVerified ? AppColors.accent : AppColors.warning,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isVerified ? 'Onaylı' : 'Bekliyor',
                                          style: TextStyle(
                                            color: isVerified ? AppColors.accent : AppColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.notifications_active_outlined, color: AppColors.accent, size: 18),
                                          tooltip: 'Bildirim Gönder',
                                          onPressed: () => _showSendNotificationDialog(prof['id'] ?? driverId, driverName),
                                        ),
                                        if (!isVerified)
                                          IconButton(
                                            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                                            tooltip: 'Eksik Evrak Bildirimi Gönder',
                                            onPressed: () => _showMissingDocumentDialog(driverId, driverName),
                                          ),
                                        const SizedBox(width: 4),
                                        OutlinedButton(
                                          onPressed: () => _toggleUserBlock(prof['id'] ?? driverId, !isSuspended),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isSuspended ? AppColors.accent : AppColors.error,
                                            side: BorderSide(color: (isSuspended ? AppColors.accent : AppColors.error).withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          ),
                                          child: Text(
                                            isSuspended ? 'Engeli Kaldır' : 'Engelle',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
        ],
      ),
    );
  }

  // TAB 4: CUSTOMERS
  Widget _buildCustomersTab() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final query = _customerSearchController.text.toLowerCase().trim();

    final list = _allCustomers.where((c) {
      final name = c.fullName.toLowerCase();
      final email = c.email.toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      final matchesQuery = name.contains(query) || email.contains(query) || phone.contains(query);
      if (!matchesQuery) return false;

      // Status filter
      if (_customerStatusFilter == 'active' && c.isSuspended) return false;
      if (_customerStatusFilter == 'suspended' && !c.isSuspended) return false;

      // Rating filter
      if (_customerRatingFilter == '4.5+' && c.rating < 4.5) return false;
      if (_customerRatingFilter == 'below_4.0' && c.rating >= 4.0) return false;

      return true;
    }).toList();

    final hasActiveFilters = _customerStatusFilter != 'all' || _customerRatingFilter != 'all' || query.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arama & Dışa Aktarma (Export) Barı
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _customerSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Müşteri adı, e-posta veya telefon ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: list.isEmpty ? null : () => ExportService.exportCustomersToCsv(list),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(isMobile ? 'CSV' : 'Müşterileri Dışa Aktar (CSV)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Çoklu Filtreleme Barı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Durum:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tümü', _customerStatusFilter == 'all', () => setState(() => _customerStatusFilter = 'all')),
                    _buildFilterChip('Aktif Hesaplar', _customerStatusFilter == 'active', () => setState(() => _customerStatusFilter = 'active'), color: AppColors.success),
                    _buildFilterChip('Engellenenler', _customerStatusFilter == 'suspended', () => setState(() => _customerStatusFilter = 'suspended'), color: AppColors.error),
                    const SizedBox(width: 12),
                    const Text('Puan:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tüm Puanlar', _customerRatingFilter == 'all', () => setState(() => _customerRatingFilter = 'all')),
                    _buildFilterChip('4.5+ ⭐', _customerRatingFilter == '4.5+', () => setState(() => _customerRatingFilter = '4.5+'), color: Colors.amber),
                    _buildFilterChip('4.0 Altı ⚠️', _customerRatingFilter == 'below_4.0', () => setState(() => _customerRatingFilter = 'below_4.0'), color: AppColors.error),
                  ],
                ),
                if (hasActiveFilters) ...[
                  const Divider(color: AppColors.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtrelenen: ${list.length} / ${_allCustomers.length} müşteri',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _customerStatusFilter = 'all';
                            _customerRatingFilter = 'all';
                            _customerSearchController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 14, color: AppColors.textSecondary),
                        label: const Text('Filtreleri Sıfırla', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          isMobile
              ? Column(
                  children: list.isEmpty
                      ? [_buildEmptyState('Müşteri bulunamadı.')]
                      : list.map((c) => _buildCustomerMobileCard(c)).toList(),
                )
              : Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                  child: list.isEmpty
                      ? _buildEmptyState('Müşteri bulunamadı.')
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF162032)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), fontSize: 13, letterSpacing: 0.3),
                            dataTextStyle: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
                            horizontalMargin: 24,
                            columnSpacing: 32,
                            dividerThickness: 0.6,
                            columns: const [
                              DataColumn(label: Text('Ad Soyad')),
                              DataColumn(label: Text('E-posta')),
                              DataColumn(label: Text('Telefon')),
                              DataColumn(label: Text('Puan')),
                              DataColumn(label: Text('Hızlı İşlemler')),
                            ],
                            rows: list.map((c) {
                              final isSuspended = c.isSuspended;

                              return DataRow(
                                cells: [
                                  DataCell(Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                  DataCell(Text(c.email, style: const TextStyle(color: AppColors.textSecondary))),
                                  DataCell(Text(c.phone ?? '-', style: const TextStyle(color: AppColors.textSecondary))),
                                  DataCell(Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(c.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.notifications_active_outlined, color: AppColors.accent, size: 18),
                                          tooltip: 'Bildirim Gönder',
                                          onPressed: () => _showSendNotificationDialog(c.id, c.fullName),
                                        ),
                                        const SizedBox(width: 4),
                                        OutlinedButton(
                                          onPressed: () => _toggleUserBlock(c.id, !isSuspended),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isSuspended ? AppColors.accent : AppColors.error,
                                            side: BorderSide(color: (isSuspended ? AppColors.accent : AppColors.error).withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          ),
                                          child: Text(
                                            isSuspended ? 'Engeli Kaldır' : 'Engelle',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
        ],
      ),
    );
  }

  // TAB 5: REQUESTS
  Widget _buildRequestsTab() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final query = _requestSearchController.text.toLowerCase().trim();
    final now = DateTime.now();

    final list = _allRequests.where((r) {
      final brand = r.carBrand.toLowerCase();
      final model = r.carModel.toLowerCase();
      final zone = (r.destinationIndustryZone ?? '').toLowerCase();
      final customer = (r.customerName ?? '').toLowerCase();
      final driver = (r.driverName ?? '').toLowerCase();
      final id = r.id.toLowerCase();
      final plate = r.carPlate.toLowerCase();
      final matchesQuery = brand.contains(query) || 
             model.contains(query) || 
             zone.contains(query) || 
             customer.contains(query) || 
             driver.contains(query) || 
             plate.contains(query) || 
             id.contains(query);

      if (!matchesQuery) return false;

      // Status Filter
      if (_requestStatusFilter == 'active') {
        if (!['accepted', 'on_way', 'arrived', 'loaded', 'in_transit'].contains(r.status.dbValue)) return false;
      } else if (_requestStatusFilter == 'completed') {
        if (r.status.dbValue != 'completed') return false;
      } else if (_requestStatusFilter == 'cancelled') {
        if (r.status.dbValue != 'cancelled') return false;
      } else if (_requestStatusFilter == 'pending') {
        if (!['pending', 'searching', 'offered'].contains(r.status.dbValue)) return false;
      }

      // Date Filter
      if (_requestDateFilter == 'today') {
        if (!(r.createdAt.year == now.year && r.createdAt.month == now.month && r.createdAt.day == now.day)) return false;
      } else if (_requestDateFilter == 'week') {
        if (now.difference(r.createdAt).inDays > 7) return false;
      } else if (_requestDateFilter == 'month') {
        if (now.difference(r.createdAt).inDays > 30) return false;
      }

      // Price Filter
      if (_requestPriceFilter == '0-1000') {
        if (r.price > 1000) return false;
      } else if (_requestPriceFilter == '1000-3000') {
        if (r.price <= 1000 || r.price > 3000) return false;
      } else if (_requestPriceFilter == '3000+') {
        if (r.price <= 3000) return false;
      }

      return true;
    }).toList();

    final hasActiveFilters = _requestStatusFilter != 'all' || _requestDateFilter != 'all' || _requestPriceFilter != 'all' || query.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arama & Dışa Aktarma (Export) Barı
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _requestSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _requestSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    hintText: 'Araç, müşteri, sürücü, plaka veya talep ID ile ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: list.isEmpty ? null : () => ExportService.exportRequestsToCsv(list),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(isMobile ? 'CSV' : 'Talepleri Dışa Aktar (CSV)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Çoklu Filtreleme Seçenekleri (Durum, Tarih, Tutar)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Durum Filtresi
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Durum:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tümü', _requestStatusFilter == 'all', () => setState(() => _requestStatusFilter = 'all')),
                    _buildFilterChip('Aktif Operasyon', _requestStatusFilter == 'active', () => setState(() => _requestStatusFilter = 'active'), color: const Color(0xFF3B82F6)),
                    _buildFilterChip('Tamamlandı', _requestStatusFilter == 'completed', () => setState(() => _requestStatusFilter = 'completed'), color: const Color(0xFF10B981)),
                    _buildFilterChip('Beklemede', _requestStatusFilter == 'pending', () => setState(() => _requestStatusFilter = 'pending'), color: const Color(0xFFF59E0B)),
                    _buildFilterChip('İptal Edildi', _requestStatusFilter == 'cancelled', () => setState(() => _requestStatusFilter = 'cancelled'), color: const Color(0xFFF43F5E)),
                  ],
                ),
                const SizedBox(height: 10),

                // Tarih & Tutar Filtreleri
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Tarih:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tüm Zamanlar', _requestDateFilter == 'all', () => setState(() => _requestDateFilter = 'all')),
                    _buildFilterChip('Bugün', _requestDateFilter == 'today', () => setState(() => _requestDateFilter = 'today')),
                    _buildFilterChip('Son 7 Gün', _requestDateFilter == 'week', () => setState(() => _requestDateFilter = 'week')),
                    _buildFilterChip('Son 30 Gün', _requestDateFilter == 'month', () => setState(() => _requestDateFilter = 'month')),
                    const SizedBox(width: 8),
                    const Text('Tutar:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildFilterChip('Tüm Fiyatlar', _requestPriceFilter == 'all', () => setState(() => _requestPriceFilter = 'all')),
                    _buildFilterChip('0 - 1.000 TL', _requestPriceFilter == '0-1000', () => setState(() => _requestPriceFilter = '0-1000')),
                    _buildFilterChip('1.000 - 3.000 TL', _requestPriceFilter == '1000-3000', () => setState(() => _requestPriceFilter = '1000-3000')),
                    _buildFilterChip('3.000+ TL', _requestPriceFilter == '3000+', () => setState(() => _requestPriceFilter = '3000+')),
                  ],
                ),

                if (hasActiveFilters) ...[
                  const Divider(color: AppColors.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtrelenen: ${list.length} / ${_allRequests.length} talep',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _requestStatusFilter = 'all';
                            _requestDateFilter = 'all';
                            _requestPriceFilter = 'all';
                            _requestSearchController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 14, color: AppColors.textSecondary),
                        label: const Text('Filtreleri Sıfırla', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          isMobile
              ? Column(
                  children: list.isEmpty
                      ? [_buildEmptyState('Filtrelere uygun talep bulunamadı.')]
                      : list.map((r) => _buildRequestMobileCard(r)).toList(),
                )
              : Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                  child: list.isEmpty
                      ? _buildEmptyState('Filtrelere uygun talep bulunamadı.')
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF162032)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), fontSize: 13, letterSpacing: 0.3),
                            dataTextStyle: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
                            horizontalMargin: 24,
                            columnSpacing: 28,
                            dividerThickness: 0.6,
                            columns: const [
                              DataColumn(label: Text('Talep ID')),
                              DataColumn(label: Text('Müşteri Adı')),
                              DataColumn(label: Text('Sürücü Adı')),
                              DataColumn(label: Text('Araç / Plaka')),
                              DataColumn(label: Text('Durum')),
                              DataColumn(label: Text('Tutar')),
                              DataColumn(label: Text('Tarih')),
                              DataColumn(label: Text('Test Durumu')),
                              DataColumn(label: Text('İncele')),
                            ],
                            rows: list.map((r) {
                              final isTest = _testRequestIds.contains(r.id);
                              return DataRow(
                                onSelectChanged: (_) => _showRequestDetailsDialog(r),
                                cells: [
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isTest)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                                          ),
                                          child: const Text('TEST', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      Text(
                                        r.id.length > 8 ? '${r.id.substring(0, 8)}...' : r.id,
                                        style: const TextStyle(fontFamily: 'monospace', color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  )),
                                  DataCell(Text(r.customerName ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                  DataCell(Text(
                                    r.driverName ?? (r.driverId != null ? 'Sürücü Atandı' : 'Bekliyor'),
                                    style: TextStyle(color: r.driverName != null ? AppColors.textPrimary : AppColors.textSecondary),
                                  )),
                                  DataCell(Text('${r.carBrand} ${r.carModel} (${r.carPlate})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: r.status.color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: r.status.color.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      r.status.label,
                                      style: TextStyle(color: r.status.color, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  )),
                                  DataCell(Text(
                                    '${r.price.toStringAsFixed(0)} TL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isTest ? AppColors.textSecondary : AppColors.accent,
                                      decoration: isTest ? TextDecoration.lineThrough : null,
                                    ),
                                  )),
                                  DataCell(Text(
                                    '${r.createdAt.day.toString().padLeft(2, '0')}.${r.createdAt.month.toString().padLeft(2, '0')}.${r.createdAt.year}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  )),
                                  DataCell(
                                    InkWell(
                                      onTap: () => _toggleTestRequest(r.id),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isTest ? Colors.amber : AppColors.surface).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isTest ? Colors.amber : AppColors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(isTest ? Icons.bug_report : Icons.bug_report_outlined, size: 14, color: isTest ? Colors.amber : AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              isTest ? 'Test' : 'Canlı',
                                              style: TextStyle(color: isTest ? Colors.amber : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    final activeColor = color ?? AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color != null ? activeColor : AppColors.textPrimary) : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Common UI helper widgets
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
    bool isPositiveTrend = true,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 750;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: isMobile ? 10 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(isMobile ? 7 : 9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(icon, size: isMobile ? 18 : 22, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 18 : 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (trend != null || subtitle != null)
              Row(
                children: [
                  if (trend != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (isPositiveTrend ? AppColors.primary : AppColors.error).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isPositiveTrend ? AppColors.primary : AppColors.error).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                            size: 12,
                            color: isPositiveTrend ? AppColors.accent : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trend,
                            style: TextStyle(
                              color: isPositiveTrend ? AppColors.accent : AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 4),
          ],
        ),
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
    final isMobile = MediaQuery.of(context).size.width < 750;
    final dailyData = <String, double>{};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      dailyData[key] = 0.0;
    }

    for (var r in _allRequests) {
      if (r.status.dbValue == 'completed' && r.completedAt != null && !_testRequestIds.contains(r.id)) {
        final key = '${r.completedAt!.day.toString().padLeft(2, '0')}/${r.completedAt!.month.toString().padLeft(2, '0')}';
        if (dailyData.containsKey(key)) {
          dailyData[key] = dailyData[key]! + r.price;
        }
      }
    }

    final maxVal = dailyData.values.fold(100.0, (max, v) => v > max ? v : max);
    final weekTotal = dailyData.values.fold(0.0, (sum, v) => sum + v);

    final barGroups = <BarChartGroupData>[];
    int index = 0;
    for (var entry in dailyData.entries) {
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: isMobile ? 14 : 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal * 1.15,
                color: AppColors.surface.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      );
      index++;
    }

    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bar_chart_rounded, color: AppColors.accent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'Mali Analiz ve Gelir Trendi',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Son 7 günde tamamlanan taleplerin günlük ciro dağılımı',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showFinancialAuditDialog,
                      icon: const Icon(Icons.analytics_outlined, size: 14, color: AppColors.accent),
                      label: const Text('Mali Denetim', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('7 Günlük Ciro', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            '${weekTotal.toStringAsFixed(0)} TL',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF0F172A),
                      tooltipRoundedRadius: 8,
                      tooltipBorder: const BorderSide(color: AppColors.border, width: 1),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final dateKey = dailyData.keys.elementAt(group.x.toInt());
                        return BarTooltipItem(
                          '$dateKey\n',
                          const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                              text: '${rod.toY.toStringAsFixed(0)} TL',
                              style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          final formatted = value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : '${value.toInt()}';
                          return Text(
                            formatted,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < dailyData.keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                dailyData.keys.elementAt(idx),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxVal / 4).clamp(50.0, 100000.0),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border.withValues(alpha: 0.35),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusChartCard() {
    final isMobile = MediaQuery.of(context).size.width < 750;

    final completedCount = _allRequests.where((r) => r.status.dbValue == 'completed').length;
    final activeCount = _allRequests.where((r) => ['accepted', 'on_way', 'arrived', 'loaded', 'in_transit'].contains(r.status.dbValue)).length;
    final pendingCount = _allRequests.where((r) => ['pending', 'searching', 'offered'].contains(r.status.dbValue)).length;
    final cancelledCount = _allRequests.where((r) => r.status.dbValue == 'cancelled').length;
    final total = _allRequests.isEmpty ? 1 : _allRequests.length;

    final sections = <PieChartSectionData>[
      if (completedCount > 0)
        PieChartSectionData(
          color: const Color(0xFF10B981),
          value: completedCount.toDouble(),
          title: '${((completedCount / total) * 100).round()}%',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (activeCount > 0)
        PieChartSectionData(
          color: const Color(0xFF3B82F6),
          value: activeCount.toDouble(),
          title: '${((activeCount / total) * 100).round()}%',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (pendingCount > 0)
        PieChartSectionData(
          color: const Color(0xFFF59E0B),
          value: pendingCount.toDouble(),
          title: '${((pendingCount / total) * 100).round()}%',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (cancelledCount > 0)
        PieChartSectionData(
          color: const Color(0xFFF43F5E),
          value: cancelledCount.toDouble(),
          title: '${((cancelledCount / total) * 100).round()}%',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];

    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: AppColors.surface,
          value: 1,
          title: '0',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    Widget buildLegendItem(String label, int count, Color color) {
      final pct = _allRequests.isEmpty ? 0 : ((count / _allRequests.length) * 100).round();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            Text('$count ', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            Text('($pct%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pie_chart_outline_rounded, color: Colors.blueAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Talep Durum Dağılımı',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tüm operasyonel çağrıların anlık durum yüzdeleri',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_allRequests.length}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const Text(
                            'Talep',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildLegendItem('Tamamlanan', completedCount, const Color(0xFF10B981)),
                      buildLegendItem('Aktif / Yolda', activeCount, const Color(0xFF3B82F6)),
                      buildLegendItem('Arayışta', pendingCount, const Color(0xFFF59E0B)),
                      buildLegendItem('İptal Edilen', cancelledCount, const Color(0xFFF43F5E)),
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

  Widget _buildLiveMapTab() {
    final isMobile = MediaQuery.of(context).size.width < 1000;
    final activeRequests = _allRequests.where((r) => r.status.dbValue != 'completed' && r.status.dbValue != 'cancelled').toList();
    final availableDrivers = _allDrivers.where((d) => d['is_available'] == true && d['is_verified'] == true).toList();

    final markers = <Marker>{};
    final polylines = <Polyline>{};
    LatLng centerPos = const LatLng(41.0082, 28.9784); // İstanbul merkez

    for (var d in availableDrivers) {
      final lat = (d['current_latitude'] as num?)?.toDouble();
      final lng = (d['current_longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final pos = LatLng(lat, lng);
        centerPos = pos;
        final prof = d['profiles'] as Map<String, dynamic>? ?? {};
        final name = prof['full_name'] as String? ?? 'Sürücü';
        final plate = d['vehicle_plate'] as String? ?? '-';
        final speed = d['current_speed'] ?? 0;

        markers.add(
          Marker(
            markerId: MarkerId('driver_${d['id']}'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: '$name ($plate)',
              snippet: 'Hız: $speed km/s • ${_formatRelativeTime(d['last_location_updated_at'])}',
            ),
            onTap: () {
              setState(() {
                _selectedLiveDriver = d;
                _selectedLiveRequest = null;
              });
            },
          ),
        );
      }
    }

    for (var r in activeRequests) {
      if (r.customerLat != 0.0 && r.customerLng != 0.0) {
        final custPos = LatLng(r.customerLat, r.customerLng);
        centerPos = custPos;

        markers.add(
          Marker(
            markerId: MarkerId('req_cust_${r.id}'),
            position: custPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Müşteri: ${r.customerName ?? "Bilinmiyor"} (${r.carPlate})',
              snippet: 'Arıza: ${r.problemType} • ${r.customerAddress ?? ""}',
            ),
            onTap: () {
              setState(() {
                _selectedLiveRequest = r;
                _selectedLiveDriver = null;
              });
            },
          ),
        );

        if (r.destinationLat != null && r.destinationLng != null && r.destinationLat != 0.0) {
          final destPos = LatLng(r.destinationLat!, r.destinationLng!);
          markers.add(
            Marker(
              markerId: MarkerId('req_dest_${r.id}'),
              position: destPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Hedef: ${r.destinationIndustryZone ?? "Sanayi/Servis"}',
                snippet: r.destinationAddress ?? '',
              ),
            ),
          );

          polylines.add(
            Polyline(
              polylineId: PolylineId('route_${r.id}'),
              points: [custPos, destPos],
              color: AppColors.accent,
              width: 4,
            ),
          );
        }
      }
    }

    Widget buildDriversList() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.drive_eta, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Müsait Çekiciler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('${availableDrivers.length} Hazır', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (availableDrivers.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Şu an aktif çevrimiçi sürücü bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: availableDrivers.length,
                itemBuilder: (context, idx) {
                  final d = availableDrivers[idx];
                  final isSelected = _selectedLiveDriver != null && _selectedLiveDriver!['id'] == d['id'];
                  return Card(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedLiveDriver = d;
                          _selectedLiveRequest = null;
                        });
                      },
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.local_shipping_outlined, color: AppColors.accent, size: 20),
                      ),
                      title: Text(
                        (d['profiles'] as Map?)?['full_name'] ?? 'Sürücü',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${d['vehicle_plate'] ?? "-"} • Hız: ${d['current_speed'] ?? 0} km/s',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.my_location, size: 16, color: AppColors.accent),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    Widget buildRequestsList() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.fmd_good_outlined, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Aktif Operasyonlar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('${activeRequests.length} Görev', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeRequests.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Şu an aktif kurtarma görevi bulunmuyor.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: activeRequests.length,
                itemBuilder: (context, idx) {
                  final r = activeRequests[idx];
                  final isSelected = _selectedLiveRequest != null && _selectedLiveRequest!.id == r.id;
                  return Card(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedLiveRequest = r;
                          _selectedLiveDriver = null;
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: r.status.color.withValues(alpha: 0.15),
                        child: Icon(Icons.car_crash_outlined, color: r.status.color, size: 20),
                      ),
                      title: Text(
                        '${r.carBrand} ${r.carModel} (${r.carPlate})',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${r.customerName ?? "Müşteri"} → ${r.status.label}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      trailing: Text(
                        '${r.price.toStringAsFixed(0)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    Widget buildMapArea() {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MapWidget(
              initialPosition: centerPos,
              markers: markers,
              polylines: polylines,
              showMyLocation: false,
              fitMarkers: markers.isNotEmpty,
            ),
          ),

          // Sürücü Bilgi Kartı (Overlay)
          if (_selectedLiveDriver != null) ...[
            Positioned(
              top: 16,
              left: 16,
              right: isMobile ? 16 : null,
              child: SizedBox(
                width: isMobile ? null : 360,
                child: Card(
                  color: AppColors.cardBackground.withValues(alpha: 0.95),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.accent, width: 1.4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.surface,
                                  child: Icon(Icons.drive_eta, color: AppColors.accent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_selectedLiveDriver!['profiles'] as Map?)?['full_name'] ?? 'Sürücü',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                    ),
                                    Text(
                                      _selectedLiveDriver!['vehicle_plate'] ?? '-',
                                      style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                              onPressed: () => setState(() => _selectedLiveDriver = null),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border, height: 16),
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('Hız: ${_selectedLiveDriver!['current_speed'] ?? 0} km/s', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                            const Spacer(),
                            const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(_formatRelativeTime(_selectedLiveDriver!['last_location_updated_at']), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final prof = _selectedLiveDriver!['profiles'] as Map?;
                                  _showSendNotificationDialog(prof?['id'] ?? _selectedLiveDriver!['id'], prof?['full_name'] ?? 'Sürücü');
                                },
                                icon: const Icon(Icons.notifications_outlined, size: 14),
                                label: const Text('Bildirim', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(color: AppColors.accent),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final prof = _selectedLiveDriver!['profiles'] as Map?;
                                  final isSusp = prof?['is_suspended'] as bool? ?? false;
                                  _toggleUserBlock(prof?['id'] ?? _selectedLiveDriver!['id'], !isSusp);
                                },
                                icon: const Icon(Icons.block, size: 14),
                                label: const Text('Engelle', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Talep Bilgi Kartı (Overlay)
          if (_selectedLiveRequest != null) ...[
            Positioned(
              top: 16,
              left: 16,
              right: isMobile ? 16 : null,
              child: SizedBox(
                width: isMobile ? null : 360,
                child: Card(
                  color: AppColors.cardBackground.withValues(alpha: 0.95),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _selectedLiveRequest!.status.color, width: 1.4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _selectedLiveRequest!.status.color.withValues(alpha: 0.15),
                                  child: Icon(Icons.local_shipping, color: _selectedLiveRequest!.status.color, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_selectedLiveRequest!.carBrand} ${_selectedLiveRequest!.carModel}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                    ),
                                    Text(
                                      _selectedLiveRequest!.carPlate,
                                      style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                              onPressed: () => setState(() => _selectedLiveRequest = null),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border, height: 16),
                        Text(
                          'Müşteri: ${_selectedLiveRequest!.customerName ?? "Bilinmiyor"}  •  Sürücü: ${_selectedLiveRequest!.driverName ?? "Atanıyor"}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_selectedLiveRequest!.customerAddress ?? "Başlangıç"} → ${_selectedLiveRequest!.destinationAddress ?? _selectedLiveRequest!.destinationIndustryZone ?? "Hedef"}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedLiveRequest!.price.toStringAsFixed(0)} TL',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                            ElevatedButton(
                              onPressed: () => _showRequestDetailsDialog(_selectedLiveRequest!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              child: const Text('Detayları Aç', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 360,
              child: buildMapArea(),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: buildDriversList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: buildRequestsList(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sol Panel: Canlı Operasyon ve Takip Haritası (Flex 3)
          Expanded(
            flex: 3,
            child: Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: buildMapArea(),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Sağ Panel: Müsait Çekiciler & Aktif Operasyonlar (Flex 2)
          SizedBox(
            width: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: buildDriversList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border, width: 1.2)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: buildRequestsList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsTab() {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Değerlendirme Geçmişi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${_allRatings.length} Değerlendirme', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Puanlama ve Kullanıcı Değerlendirme Geçmişi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('${_allRatings.length} Değerlendirme Kaydedildi', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
              const SizedBox(height: 24),
              Expanded(
                child: isMobile
                    ? ListView.builder(
                        itemCount: _allRatings.length,
                        itemBuilder: (context, idx) {
                          return _buildRatingMobileCard(_allRatings[idx]);
                        },
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF162032)),
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), fontSize: 13, letterSpacing: 0.3),
                          dataTextStyle: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
                          horizontalMargin: 24,
                          columnSpacing: 28,
                          dividerThickness: 0.6,
                          columns: const [
                            DataColumn(label: Text('Tarih')),
                            DataColumn(label: Text('Değerlendiren')),
                            DataColumn(label: Text('Değerlendirilen')),
                            DataColumn(label: Text('Puan')),
                            DataColumn(label: Text('Yorum')),
                          ],
                          rows: _allRatings.map((r) {
                            final date = r['created_at'] != null ? DateTime.parse(r['created_at'] as String) : DateTime.now();
                            final rater = (r['rater'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
                            final rated = (r['rated'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
                            final score = r['score'] as int? ?? 5;
                            final comment = r['comment'] as String? ?? '-';

                            return DataRow(
                              cells: [
                                DataCell(Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}')),
                                DataCell(Text(rater, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                DataCell(Text(rated, style: const TextStyle(color: AppColors.textSecondary))),
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
                                DataCell(Text(comment, style: const TextStyle(color: AppColors.textPrimary))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverMobileCard(Map<String, dynamic> d) {
    final prof = d['profiles'] as Map<String, dynamic>;
    final isVerified = d['is_verified'] as bool? ?? false;
    final isSuspended = prof['is_suspended'] as bool? ?? false;
    final rating = (d['rating'] as num?)?.toDouble() ?? 5.0;

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                Expanded(
                  child: Text(
                    prof['full_name'] ?? 'Bilinmiyor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.warning_amber_rounded,
                      color: isVerified ? AppColors.success : AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Onaylı' : 'Onaysız',
                      style: TextStyle(
                        color: isVerified ? AppColors.success : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Telefon: ${prof['phone'] ?? '-'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Araç Plakası: ${d['vehicle_plate'] ?? '-'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _toggleUserBlock(prof['id'], !isSuspended),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isSuspended ? 'Engeli Kaldır' : 'Engelle',
                    style: TextStyle(
                      color: isSuspended ? AppColors.accent : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerMobileCard(UserModel c) {
    final isSuspended = c.isSuspended;

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'E-posta: ${c.email}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Telefon: ${c.phone ?? '-'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      c.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _toggleUserBlock(c.id, !isSuspended),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isSuspended ? 'Engeli Kaldır' : 'Engelle',
                    style: TextStyle(
                      color: isSuspended ? AppColors.accent : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestMobileCard(ServiceRequestModel r) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showRequestDetailsDialog(r),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.id.length > 8 ? 'ID: ${r.id.substring(0, 8)}...' : 'ID: ${r.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: r.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: r.status.color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      r.status.label,
                      style: TextStyle(color: r.status.color, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Müşteri: ${r.customerName ?? 'Bilinmiyor'}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Sürücü: ${r.driverName ?? (r.driverId != null ? 'Sürücü Atandı' : 'Bekliyor')}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Araç: ${r.carBrand} ${r.carModel} (${r.carPlate})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year} ${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text(
                    '${r.price.toInt()} TL',
                    style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingMobileCard(Map<String, dynamic> r) {
    final date = r['created_at'] != null ? DateTime.parse(r['created_at'] as String) : DateTime.now();
    final rater = (r['rater'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
    final rated = (r['rated'] as Map?)?['full_name'] ?? 'Bilinmeyen Kullanıcı';
    final score = r['score'] as int? ?? 5;
    final comment = r['comment'] as String? ?? '-';

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star_rounded,
                      color: index < score ? Colors.amber : AppColors.textSecondary.withValues(alpha: 0.3),
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Değerlendiren: $rater',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Değerlendirilen: $rated',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (comment != '-') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
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
