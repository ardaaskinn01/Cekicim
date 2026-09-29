import 'package:flutter/material.dart';
import '../app_colors.dart';

class RatingWidget extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final bool isReadOnly;
  final double size;

  const RatingWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.isReadOnly = false,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating >= starValue;
        final isHalf = rating > index && rating < starValue;

        return GestureDetector(
          onTap: isReadOnly || onRatingChanged == null
              ? null
              : () => onRatingChanged!(starValue.toDouble()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              isFilled
                  ? Icons.star_rounded
                  : isHalf
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              color: isFilled || isHalf ? AppColors.warning : AppColors.textSecondary,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
