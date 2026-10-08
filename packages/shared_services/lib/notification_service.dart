import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'auth_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static Function(String requestId, String? type)? onNotificationTapped;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && onNotificationTapped != null) {
          final parts = payload.split('|');
          final reqId = parts[0];
          final type = parts.length > 1 ? parts[1] : null;
          onNotificationTapped!(reqId, type);
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'cekici_alerts_v2',
      'Çekici Bildirimleri',
      description: 'Yeni teklif ve yol yardım bildirim kanalı',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  bool _isFCMSetup = false;

  Future<void> setupFCM(String userId) async {
    if (_isFCMSetup) {
      debugPrint('FCM already setup. Skipping.');
      return;
    }
    _isFCMSetup = true;
    try {
      // Safely check if Firebase has been initialized first
      try {
        if (Firebase.apps.isEmpty) {
          debugPrint('Firebase is not initialized. Skipping FCM setup.');
          _isFCMSetup = false;
          return;
        }
      } catch (e) {
        debugPrint('Firebase checking error: $e. Skipping FCM setup.');
        _isFCMSetup = false;
        return;
      }

      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // ÖNEMLİ: Uygulama ön plandayken alarm çalması ve bildirim göstermesi için:
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // On iOS, retry fetching APNs token up to 10 seconds before requesting FCM token
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        int attempts = 0;
        while (apnsToken == null && attempts < 10) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            attempts++;
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        if (apnsToken != null) {
          debugPrint('APNS token retrieved successfully: $apnsToken');
        } else {
          debugPrint('APNS token not available after 10s wait. Proceeding to attempt FCM token.');
        }
      }

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
        final type = (message.data['type'] ?? message.data['notification_type']) as String?;
        String title = message.notification?.title ?? message.data['title'] ?? 'Çekici';
        String body = message.notification?.body ?? message.data['body'] ?? '';

        if (type == 'call' || type == 'VOIP_CALL') {
          title = message.data['title'] ?? '📞 Gelen Sesli Arama';
          body = message.data['body'] ?? 'Sizi arıyorlar. Görüşmeyi yanıtlamak için tıklayın.';
        }

        final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;

        showLocalNotification(
          title,
          body,
          payload: requestId != null ? '$requestId|${type ?? ""}' : null,
        );
      });

      // Handle background taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;
        final type = (message.data['type'] ?? message.data['notification_type']) as String?;
        if (requestId != null && onNotificationTapped != null) {
          onNotificationTapped!(requestId, type);
        }
      });

      // Handle terminated taps
      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;
          final type = (message.data['type'] ?? message.data['notification_type']) as String?;
          if (requestId != null && onNotificationTapped != null) {
            onNotificationTapped!(requestId, type);
          }
        }
      });
    } catch (e) {
      _isFCMSetup = false;
      debugPrint('Error setting up FCM: $e');
    }
  }

  Future<void> showLocalNotification(String title, String body, {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'cekici_alerts_v2',
      'Çekici Bildirimleri',
      channelDescription: 'Yeni teklif ve yol yardım bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      sound: 'alarm.mp3',
      interruptionLevel: InterruptionLevel.timeSensitive,
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
      payload: payload,
    );
  }

  static const int _driver3DayNotificationId = 88883;
  static const int _driver7DayNotificationId = 88887;
  static const int _customer7DayNotificationId = 77777;

  /// Sürücü uygulamayı kullanmadığında 3. gün ve 7. günde tetiklenecek 2 ayrı bildirim planlar.
  Future<void> scheduleDriverInactivityReminders() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(_driver3DayNotificationId);
      await _flutterLocalNotificationsPlugin.cancel(_driver7DayNotificationId);

      const androidDetails = AndroidNotificationDetails(
        'cekici_alerts_v2',
        'Çekici Bildirimleri',
        channelDescription: 'Sürücü hatırlatma bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 3. Gün Bildirimi
      final date3Days = tz.TZDateTime.now(tz.local).add(const Duration(days: 3));
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _driver3DayNotificationId,
        'Hadi iş vakti! 🚜',
        'Çevrende talepler artıyor! Hemen çevrimiçi ol ve kazanmaya başla 💰',
        date3Days,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // 7. Gün Bildirimi (1 Hafta)
      final date7Days = tz.TZDateTime.now(tz.local).add(const Duration(days: 7));
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _driver7DayNotificationId,
        'Seni özledik! 🚜',
        'Çevrendeki çekici ve yol yardım fırsatlarını kaçırmamak için hemen giriş yap!',
        date7Days,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Driver inactivity notifications scheduled for: 3d ($date3Days), 7d ($date7Days)');
    } catch (e) {
      debugPrint('Error scheduling driver inactivity notifications: $e');
    }
  }

  /// Müşteri uygulamayı 7 gün boyunca açmadığında tetiklenen hatırlatma bildirimi.
  Future<void> scheduleCustomerInactivityReminder() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(_customer7DayNotificationId);

      const androidDetails = AndroidNotificationDetails(
        'cekici_alerts_v2',
        'Çekici Bildirimleri',
        channelDescription: 'Müşteri hatırlatma bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final date7Days = tz.TZDateTime.now(tz.local).add(const Duration(days: 7));
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _customer7DayNotificationId,
        'Çekici veya Yol Yardımı Lazım mı? 🚗',
        'Çekicim her an yanında! Aracınla ilgili bir yardıma ihtiyacın olursa tek tıkla ulaşabilirsin.',
        date7Days,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Customer 7-day reminder scheduled for: $date7Days');
    } catch (e) {
      debugPrint('Error scheduling customer inactivity notification: $e');
    }
  }

  /// Geriye dönük uyumluluk için eski metot çağrılarını sürdürüyoruz.
  Future<void> scheduleInactivityReminder({int days = 3}) async {
    await scheduleDriverInactivityReminders();
  }

  Future<void> cancelInactivityReminder() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(_driver3DayNotificationId);
      await _flutterLocalNotificationsPlugin.cancel(_driver7DayNotificationId);
      await _flutterLocalNotificationsPlugin.cancel(_customer7DayNotificationId);
    } catch (e) {
      debugPrint('Error canceling inactivity notifications: $e');
    }
  }
}
