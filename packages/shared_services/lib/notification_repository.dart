import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/notification_model.dart';
import 'supabase_service.dart';

class NotificationRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Kullanıcının tüm bildirimlerini getirir (en yeniden eskiye)
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('[NotificationRepository] getNotifications error: $e');
      return [];
    }
  }

  /// Okunmamış bildirim sayısını döner
  Future<int> getUnreadCount(String userId) async {
    try {
      final count = await _client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false);

      return count;
    } catch (e) {
      debugPrint('[NotificationRepository] getUnreadCount error: $e');
      return 0;
    }
  }

  /// Realtime stream: Bildirim listesi değiştiğinde canlı güncellenir
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows
            .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList());
  }

  /// Tek bir bildirimi okundu olarak işaretler
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotificationRepository] markAsRead error: $e');
    }
  }

  /// Kullanıcının tüm bildirimlerini okundu olarak işaretler
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationRepository] markAllAsRead error: $e');
    }
  }

  /// Bildirimi siler
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotificationRepository] deleteNotification error: $e');
    }
  }
}
