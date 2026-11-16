import 'package:flutter/material.dart';
import 'package:shared_models/notification_model.dart';
import '../app_colors.dart';

class NotificationsSheet extends StatelessWidget {
  final List<NotificationModel> notifications;
  final ValueChanged<NotificationModel>? onNotificationTap;
  final ValueChanged<String>? onMarkAsRead;
  final VoidCallback? onMarkAllAsRead;
  final ValueChanged<String>? onDelete;
  final ValueChanged<NotificationModel>? onActionTap;

  const NotificationsSheet({
    super.key,
    required this.notifications,
    this.onNotificationTap,
    this.onMarkAsRead,
    this.onMarkAllAsRead,
    this.onDelete,
    this.onActionTap,
  });

  static Future<void> show(
    BuildContext context, {
    required List<NotificationModel> notifications,
    ValueChanged<NotificationModel>? onNotificationTap,
    ValueChanged<String>? onMarkAsRead,
    VoidCallback? onMarkAllAsRead,
    ValueChanged<String>? onDelete,
    ValueChanged<NotificationModel>? onActionTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: NotificationsSheet(
          notifications: notifications,
          onNotificationTap: onNotificationTap,
          onMarkAsRead: onMarkAsRead,
          onMarkAllAsRead: onMarkAllAsRead,
          onDelete: onDelete,
          onActionTap: onActionTap,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }
  }

  bool _isDocumentOrActionable(NotificationModel n) {
    final text = '${n.title} ${n.body}'.toLowerCase();
    return text.contains('evrak') ||
        text.contains('belge') ||
        text.contains('onaylanmadı') ||
        text.contains('reddedildi') ||
        text.contains('eksik') ||
        n.type == 'document' ||
        n.type == 'verification';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Column(
      children: [
        // Handle bar
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bildirimler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '$unreadCount yeni',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              if (unreadCount > 0 && onMarkAllAsRead != null)
                TextButton.icon(
                  onPressed: onMarkAllAsRead,
                  icon: const Icon(Icons.done_all, size: 16, color: AppColors.accent),
                  label: const Text(
                    'Tümünü Okundu Yap',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),

        const Divider(color: AppColors.border, height: 1),

        // Notification List
        Expanded(
          child: notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz Bildiriminiz Yok',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Evrak onayları, durum güncellemeleri ve önemli duyurular burada listelenecektir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isActionable = _isDocumentOrActionable(n);

                    // Icon & Color based on type / content
                    Color iconColor = AppColors.accent;
                    IconData iconData = Icons.notifications_rounded;
                    final lowerBody = '${n.title} ${n.body}'.toLowerCase();

                    if (lowerBody.contains('onaylandı') || lowerBody.contains('başarılı')) {
                      iconColor = const Color(0xFF10B981); // Emerald green
                      iconData = Icons.verified_rounded;
                    } else if (lowerBody.contains('reddedildi') || lowerBody.contains('engellendi') || lowerBody.contains('askıya')) {
                      iconColor = const Color(0xFFEF4444); // Red
                      iconData = Icons.highlight_off_rounded;
                    } else if (lowerBody.contains('eksik') || lowerBody.contains('uyarı')) {
                      iconColor = const Color(0xFFF59E0B); // Amber
                      iconData = Icons.warning_amber_rounded;
                    } else if (n.type == 'request' || lowerBody.contains('çekici') || lowerBody.contains('talep')) {
                      iconColor = const Color(0xFF3B82F6); // Blue
                      iconData = Icons.local_shipping_rounded;
                    }

                    return Dismissible(
                      key: Key(n.id),
                      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        onDelete?.call(n.id);
                      },
                      child: InkWell(
                        onTap: () {
                          if (!n.isRead) {
                            onMarkAsRead?.call(n.id);
                          }
                          onNotificationTap?.call(n);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isRead ? AppColors.surface : AppColors.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: n.isRead ? AppColors.border : iconColor.withValues(alpha: 0.45),
                              width: n.isRead ? 1.0 : 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title & Body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (!n.isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(left: 6),
                                                decoration: BoxDecoration(
                                                  color: iconColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTimeAgo(n.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (isActionable && onActionTap != null)
                                    InkWell(
                                      onTap: () {
                                        if (!n.isRead) onMarkAsRead?.call(n.id);
                                        onActionTap?.call(n);
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Evrakları Güncelle',
                                              style: TextStyle(
                                                color: iconColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 10),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
