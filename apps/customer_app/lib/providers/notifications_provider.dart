import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/notification_model.dart';
import 'package:shared_services/notification_repository.dart';
import 'auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Müşterinin realtime bildirim akışı
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null || user.id.isEmpty) {
    return Stream.value(<NotificationModel>[]);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamNotifications(user.id);
});

/// Okunmamış bildirim sayısı
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsStreamProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});
