import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_services/dispute_repository.dart';
import 'package:shared_ui/app_colors.dart';
import '../../providers/auth_provider.dart';

class CustomerDisputesScreen extends ConsumerStatefulWidget {
  const CustomerDisputesScreen({super.key});

  @override
  ConsumerState<CustomerDisputesScreen> createState() => _CustomerDisputesScreenState();
}

class _CustomerDisputesScreenState extends ConsumerState<CustomerDisputesScreen> {
  List<DisputeModel> _disputes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final list = await DisputeRepository().getDisputesForUser(user.id);
        // Sort disputes to show newest first
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) {
          setState(() {
            _disputes = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Kullanıcı oturumu bulunamadı.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Talepler yüklenirken bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(DisputeStatus status) {
    switch (status) {
      case DisputeStatus.pending:
        return AppColors.warning;
      case DisputeStatus.investigating:
        return AppColors.primary;
      case DisputeStatus.resolved:
        return AppColors.success;
      case DisputeStatus.dismissed:
        return AppColors.error;
    }
  }

  String _getStatusLabel(DisputeStatus status) {
    switch (status) {
      case DisputeStatus.pending:
        return 'Beklemede';
      case DisputeStatus.investigating:
        return 'İnceleniyor';
      case DisputeStatus.resolved:
        return 'Çözüldü';
      case DisputeStatus.dismissed:
        return 'Kapatıldı';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Destek Taleplerim'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDisputes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDisputes,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Yeniden Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _disputes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent_outlined, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Henüz herhangi bir destek talebiniz bulunmuyor.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDisputes,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _disputes.length,
                        itemBuilder: (context, index) {
                          final dispute = _disputes[index];
                          final statusColor = _getStatusColor(dispute.status);
                          final statusLabel = _getStatusLabel(dispute.status);

                          return Card(
                            color: AppColors.cardBackground,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Title and status badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dispute.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Date
                                  Text(
                                    'Talep Tarihi: ${dispute.createdAt.day}.${dispute.createdAt.month}.${dispute.createdAt.year} ${dispute.createdAt.hour.toString().padLeft(2, '0')}:${dispute.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Divider(color: AppColors.border, height: 24),
                                  // Description
                                  const Text(
                                    'Şikayet Açıklaması',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dispute.description,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  // Admin Decision / Notes (If present)
                                  if (dispute.adminNotes != null && dispute.adminNotes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                dispute.status == DisputeStatus.resolved ? 'Destek Kararı (Çözüldü)' : 'Destek Kararı',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dispute.adminNotes!,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
