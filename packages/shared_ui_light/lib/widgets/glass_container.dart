import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 10.0,
    this.opacity = 0.85,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final defaultBorderColor = isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder;
    final defaultShadowColor = isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(
          color: defaultBorderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: defaultShadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
