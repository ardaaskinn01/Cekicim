import 'package:flutter/material.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_services/rating_repository.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';

class DriverSelectionCard extends StatelessWidget {
  final DriverModel driver;
  final double distanceKm;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const DriverSelectionCard({
    super.key,
    required this.driver,
    required this.distanceKm,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final etaMinutes = (distanceKm / 40.0 * 60).round();
    final price = PriceCalculator.calculatePrice(distanceKm);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: onChanged,
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driver.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live rating from RatingRepository
                        FutureBuilder<double>(
                          future: RatingRepository().getAverageRating(driver.id),
                          builder: (ctx, snap) {
                            final avg = snap.data ?? driver.rating;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                Text(
                                  ' ${avg.toStringAsFixed(1)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  ' (${driver.totalServices})',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mesafe: ${distanceKm.toStringAsFixed(1)} km • Tahmini: $etaMinutes dk',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PriceCalculator.formatPrice(price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
