import 'package:flutter/material.dart';
import '../app_colors.dart';

class TripLiveProgressCard extends StatelessWidget {
  final String statusTitle; // örn: "Çekici Konumunuza Geliyor"
  final String statusSubtitle; // örn: "34 ABC 123 • Ahmet Yılmaz"
  final String? etaDuration; // örn: "12 dk"
  final String? etaDistance; // örn: "4.2 km"
  final double progressPercent; // 0.0 - 1.0
  final int currentStep; // 0: Eşleşti, 1: Yolda (Müşteriye Geliyor), 2: Çekiciye Yüklendi / Varışa Gidiyor, 3: Tamamlandı
  final VoidCallback? onLiveMapTap;

  const TripLiveProgressCard({
    super.key,
    required this.statusTitle,
    required this.statusSubtitle,
    this.etaDuration,
    this.etaDistance,
    required this.progressPercent,
    this.currentStep = 1,
    this.onLiveMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPercent = progressPercent.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Satır: Canlı Takip Etiketi & ETA
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'CANLI TAKİP',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (etaDuration != null && etaDuration!.isNotEmpty) ...[
                const Icon(Icons.timer_outlined, size: 15, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  etaDuration!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              if (etaDistance != null && etaDistance!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '($etaDistance)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Başlık ve Alt Başlık
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // İlerleme Çubuğu ve Araç İkonu
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              const iconSize = 18.0;
              final iconLeft = (barWidth - iconSize) * clampedPercent;

              return Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Arka Plan Çubuğu
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Dolu Çubuk (Gradient)
                      FractionallySizedBox(
                        widthFactor: clampedPercent == 0.0 ? 0.03 : clampedPercent,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E676), AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // İlerleyen Çekici Gösterge İkonu
                      Positioned(
                        left: iconLeft,
                        top: -5,
                        child: Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            size: 10,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Aşamalar (Eşleşti -> Geliyor -> Taşınıyor -> Tamamlandı)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepLabel('Kabul Edildi', isActive: currentStep >= 0, isCurrent: currentStep == 0),
                      _buildStepLabel('Sürücü Yolda', isActive: currentStep >= 1, isCurrent: currentStep == 1),
                      _buildStepLabel('Araç Taşınıyor', isActive: currentStep >= 2, isCurrent: currentStep == 2),
                      _buildStepLabel('Teslim Edildi', isActive: currentStep >= 3, isCurrent: currentStep == 3),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(String label, {required bool isActive, required bool isCurrent}) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
        color: isCurrent
            ? AppColors.accent
            : (isActive ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.6)),
      ),
    );
  }
}

