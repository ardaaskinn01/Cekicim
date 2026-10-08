import 'package:flutter/material.dart';
import '../app_colors.dart';

enum SocialButtonType {
  google,
  apple,
}

class SocialAuthButton extends StatelessWidget {
  final SocialButtonType type;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? customText;

  const SocialAuthButton({
    super.key,
    required this.type,
    this.onPressed,
    this.isLoading = false,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    // Styling according to brand guidelines
    final Color backgroundColor;
    final Color textColor;
    final Color borderColor;
    final String defaultText;
    final Widget icon;

    switch (type) {
      case SocialButtonType.google:
        backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        textColor = isDark ? Colors.white : const Color(0xFF1F2937);
        borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        defaultText = 'Google ile Devam Et';
        icon = const _GoogleIcon(size: 20);
        break;

      case SocialButtonType.apple:
        backgroundColor = isDark ? Colors.white : Colors.black;
        textColor = isDark ? Colors.black : Colors.white;
        borderColor = isDark ? Colors.white : Colors.black;
        defaultText = 'Apple ile Devam Et';
        icon = Icon(
          Icons.apple,
          size: 24,
          color: textColor,
        );
        break;
    }

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            customText ?? defaultText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  final double size;

  const _GoogleIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Standard 4-color Google "G" path arcs
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw Google "G" segments
    // Red: Top arc
    final redPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -2.356, // -135 deg
        1.57,  // 90 deg
        false,
      )
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Blue: Right arc + horizontal bar
    final bluePath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -0.785, // -45 deg
        1.57,  // 90 deg
        false,
      )
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green: Bottom arc
    final greenPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        0.785, // 45 deg
        1.57,  // 90 deg
        false,
      )
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow: Left arc
    final yellowPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        2.356, // 135 deg
        1.57,  // 90 deg
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Punch out the center circle for doughnut effect
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    // Draw white center hole (or overlay circle)
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.58, holePaint);

    // Draw Blue horizontal bar of the 'G'
    final barRect = Rect.fromLTRB(
      center.dx,
      center.dy - (radius * 0.22),
      center.dx + radius,
      center.dy + (radius * 0.22),
    );
    canvas.drawRect(barRect, bluePaint);

    // Cut out the upper right quarter wedge
    final wedgePath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius, center.dy - radius * 0.6)
      ..lineTo(center.dx, center.dy - radius * 0.6)
      ..close();
    canvas.drawPath(wedgePath, holePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
