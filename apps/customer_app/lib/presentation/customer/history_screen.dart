import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_ui/extensions/request_status_extension.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/rating_widget.dart';

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
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
