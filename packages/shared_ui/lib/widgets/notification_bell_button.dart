import 'package:flutter/material.dart';
import '../app_colors.dart';

class NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  final Color? color;

  const NotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bildirimler',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
            color: color ?? AppColors.textPrimary,
            size: 24,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444), // Vibrant Red
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }
}
