import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static Function(String requestId)? onNotificationTapped;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'cekici_alerts_v2',
      'Çekici Bildirimleri',
      description: 'Yeni teklif ve yol yardım bildirim kanalı',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('bg_alarm2'),
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> setupFCM(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get token
      final token = await messaging.getToken();
      if (token != null) {
        final authRepo = AuthRepository();
        await authRepo.updateFcmToken(userId, token);
        debugPrint('FCM Token updated: $token');
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) async {
        final authRepo = AuthRepository();
        await authRepo.updateFcmToken(userId, newToken);
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showLocalNotification(
            message.notification!.title ?? 'Çekici',
            message.notification!.body ?? '',
          );
        }
      });

      // Handle background taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final requestId = message.data['request_id'] as String?;
        if (requestId != null && onNotificationTapped != null) {
          onNotificationTapped!(requestId);
        }
      });

      // Handle terminated taps
      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final requestId = message.data['request_id'] as String?;
          if (requestId != null && onNotificationTapped != null) {
            onNotificationTapped!(requestId);
          }
        }
      });
    } catch (e) {
      debugPrint('Error setting up FCM: $e');
    }
  }

  Future<void> showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'cekici_alerts_v2',
      'Çekici Bildirimleri',
      channelDescription: 'Yeni teklif ve yol yardım bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('bg_alarm2'),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: 'bg_alarm2.mp3',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }
}
