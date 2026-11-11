import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  /// Alarm kanalı. Android'de kanal sesi/önemi oluşturulduktan sonra DEĞİŞTİRİLEMEZ;
  /// eski 'cekici_alerts_v2' kanalı bozuk/sessiz kaldığı için yeni id (v3) kullanılır.
  static const String alertChannelId = 'cekici_alerts_v3';
  static const String _legacyAlertChannelId = 'cekici_alerts_v2';

  /// Sessiz/normal sesli bildirimler (mesaj, hatırlatma, talep alındı vb.) için kanal.
  static const String messageChannelId = 'cekici_messages_v1';

  /// Alarm sesiyle çalması gereken bildirim tipleri.
  static const Set<String> _alarmTypes = {
    'NEW_REQUEST',
    'VOIP_CALL',
    'call',
    'DRIVER_ARRIVING',
    'OFFLINE_DRIVER_REMINDER',
  };

  bool _pluginInitialized = false;

  /// Aynı iş (talep + tip) için HER ZAMAN aynı bildirim id'sini üretir (FNV-1a).
  /// Böylece tekrar gelen bildirim öncekinin üstüne yazılır, birikmez.
  static int notificationIdFor(String? requestId, String? type) {
    final key = '${requestId ?? ''}|${type ?? ''}';
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _initPlugin(requestPermissions: true);
  }

  /// Arka plan isolate'ında (izin istemeden) eklentiyi hazırlar.
  Future<void> ensureInitializedForBackground() async {
    await _initPlugin(requestPermissions: false);
  }

  Future<void> _initPlugin({required bool requestPermissions}) async {
    if (_pluginInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: requestPermissions,
      requestBadgePermission: requestPermissions,
      requestSoundPermission: requestPermissions,
    );
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && onNotificationTapped != null) {
          final parts = payload.split('|');
          final reqId = parts[0].trim();
          final type = parts.length > 1 ? parts[1].trim() : null;
          if (reqId.isNotEmpty) {
            onNotificationTapped!(reqId, type);
          }
        }
      },
    );
    _pluginInitialized = true;

    const androidChannel = AndroidNotificationChannel(
      alertChannelId,
      'Çekici Alarmları',
      description: 'Yeni talep, gelen arama ve çekici yaklaşma alarmları',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    const messageChannel = AndroidNotificationChannel(
      messageChannelId,
      'Mesajlar ve Bilgilendirmeler',
      description: 'Sohbet mesajları, hatırlatmalar ve durum bilgilendirmeleri',
      importance: Importance.high,
      playSound: true,
    );

    const tripProgressChannel = AndroidNotificationChannel(
      'cekici_trip_progress',
      'Çekici Canlı Takip',
      description: 'Sürücü gelişi ve çekici seferi canlı durum bildirim kanalı',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
    await androidPlugin?.createNotificationChannel(messageChannel);
    await androidPlugin?.createNotificationChannel(tripProgressChannel);
    // Sessiz kalan eski kanalı kaldır (kullanıcı ayarlarında çift kanal görünmesin)
    try {
      await androidPlugin?.deleteNotificationChannel(_legacyAlertChannelId);
    } catch (_) {}
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
      
      // Handle foreground messages (tek giriş noktası: handleRemoteMessage)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        handleRemoteMessage(message, isForeground: true);
      });

      // Handle background taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;
        final type = (message.data['type'] ?? message.data['notification_type']) as String?;
        if (requestId != null && requestId.trim().isNotEmpty && onNotificationTapped != null) {
          onNotificationTapped!(requestId.trim(), type);
        }
      });

      // Handle terminated taps
      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;
          final type = (message.data['type'] ?? message.data['notification_type']) as String?;
          if (requestId != null && requestId.trim().isNotEmpty && onNotificationTapped != null) {
            onNotificationTapped!(requestId.trim(), type);
          }
        }
      });
    } catch (e) {
      _isFCMSetup = false;
      debugPrint('Error setting up FCM: $e');
    }
  }

  /// Gelen FCM mesajını (ön plan / arka plan) TEK yerden işler.
  ///
  /// Çift bildirimi önleyen kurallar:
  ///  * iOS: APNs `alert`'ini işletim sistemi zaten gösterir (ön planda
  ///    `setForegroundNotificationPresentationOptions` ile) → yerel kopya ÜRETİLMEZ.
  ///  * Android: sunucu data-only gönderir. Eski sürüm sunucudan `notification`
  ///    bloğu gelirse ve uygulama arka plandaysa sistem tepsisi zaten gösterir → atlanır.
  Future<void> handleRemoteMessage(RemoteMessage message, {required bool isForeground}) async {
    try {
      final data = message.data;
      final type = (data['type'] ?? data['notification_type']) as String?;
      final requestId = (data['request_id'] ?? data['requestId']) as String?;

      // Talep başkası tarafından alındıysa, bu talep için çalan alarm bildirimini temizle
      if (type == 'REQUEST_TAKEN' && requestId != null && requestId.isNotEmpty) {
        await ensureInitializedForBackground();
        await _flutterLocalNotificationsPlugin
            .cancel(notificationIdFor(requestId, 'NEW_REQUEST'));
        await _flutterLocalNotificationsPlugin
            .cancel(notificationIdFor(requestId, 'OFFLINE_DRIVER_REMINDER'));
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return;
      if (!isForeground && message.notification != null) return;

      final isVoip = (type == 'VOIP_CALL' || type == 'call');
      final title = (data['title'] as String?) ??
          message.notification?.title ??
          (isVoip ? '📞 Gelen Sesli Arama' : 'Çekici');
      final body = (data['body'] as String?) ??
          message.notification?.body ??
          (isVoip ? 'Çekici hizmetiniz için canlı sesli arama geliyor.' : '');

      await ensureInitializedForBackground();
      await showLocalNotification(
        title,
        body,
        payload: requestId != null ? '$requestId|${type ?? ""}' : null,
        type: type,
      );
    } catch (e) {
      debugPrint('handleRemoteMessage error: $e');
    }
  }

  /// Bir talebe ait alarm bildirimlerini (yeni talep / offline hatırlatma) kaldırır.
  /// `cancelAll()` kullanılmaz; canlı takip bildirimini de silmesin diye.
  Future<void> cancelRequestAlerts(String requestId) async {
    try {
      await _flutterLocalNotificationsPlugin
          .cancel(notificationIdFor(requestId, 'NEW_REQUEST'));
      await _flutterLocalNotificationsPlugin
          .cancel(notificationIdFor(requestId, 'OFFLINE_DRIVER_REMINDER'));
    } catch (e) {
      debugPrint('cancelRequestAlerts error: $e');
    }
  }

  Future<void> showLocalNotification(
    String title,
    String body, {
    String? payload,
    String? type,
  }) async {
    final parts = payload?.split('|');
    final requestId = (parts != null && parts.isNotEmpty) ? parts[0].trim() : null;
    var resolvedType = type;
    if ((resolvedType == null || resolvedType.isEmpty) && parts != null && parts.length > 1) {
      resolvedType = parts[1].trim();
    }
    if (resolvedType != null && resolvedType.isEmpty) resolvedType = null;

    // Tip bilinmiyorsa eski davranış: alarm (yeni talep)
    final isAlarm = resolvedType == null || _alarmTypes.contains(resolvedType);
    final isVoip = resolvedType == 'VOIP_CALL' || resolvedType == 'call';
    final effectiveType = resolvedType ?? 'NEW_REQUEST';

    final androidDetails = isAlarm
        ? AndroidNotificationDetails(
            alertChannelId,
            'Çekici Alarmları',
            channelDescription: 'Yeni talep, gelen arama ve çekici yaklaşma alarmları',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            sound: const RawResourceAndroidNotificationSound('alarm'),
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: isVoip ? AndroidNotificationCategory.call : AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            onlyAlertOnce: false,
            // Eski/cevaplanmamış teklifler bildirim çubuğunda birikmesin
            timeoutAfter: effectiveType == 'NEW_REQUEST' ? 90000 : null,
          )
        : const AndroidNotificationDetails(
            messageChannelId,
            'Mesajlar ve Bilgilendirmeler',
            channelDescription: 'Sohbet mesajları, hatırlatmalar ve durum bilgilendirmeleri',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
          );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      sound: isAlarm ? 'alarm.mp3' : null,
      interruptionLevel: isAlarm ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
      threadIdentifier: requestId,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _flutterLocalNotificationsPlugin.show(
      // Aynı talep + tip → aynı id → öncekinin üstüne yazar (birikme yok)
      notificationIdFor(requestId, effectiveType),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static const int _driver3DayNotificationId = 88883;
  static const int _driver7DayNotificationId = 88887;
  static const int _customer7DayNotificationId = 77777;
  static const int tripProgressNotificationId = 99990;

  /// Kilit ekranında ve bildirim merkezinde sürücünün gelişini ve sefer ilerlemesini
  /// canlı ilerleme çubuğuyla (Progress Bar) gösteren zengin bildirim widget'ı.
  Future<void> showTripProgressNotification({
    required String title,
    required String body,
    required int progressPercent, // 0 - 100
    String? subText,
    String? requestId,
  }) async {
    final clampedProgress = progressPercent.clamp(0, 100);

    final androidDetails = AndroidNotificationDetails(
      'cekici_trip_progress',
      'Çekici Canlı Takip',
      channelDescription: 'Sürücü gelişi ve çekici seferi canlı durum bildirim kanalı',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ongoing: true, // Kullanıcı kazara kaydırıp kapatmasın
      autoCancel: false,
      onlyAlertOnce: true, // Her mesafe değişiminde ses/titreşim yapıp rahatsız etmesin
      showProgress: true,
      maxProgress: 100,
      progress: clampedProgress,
      subText: subText ?? 'Canlı Takip',
      visibility: NotificationVisibility.public, // Kilit ekranında tam görünürlük
      category: AndroidNotificationCategory.status,
      color: const Color(0xFF00C853), // AppColors.accent / primary
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false, // Her koordinatta banner fırlatmasın
      presentBadge: false,
      presentSound: false,
      presentBanner: false,
      interruptionLevel: InterruptionLevel.passive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      tripProgressNotificationId,
      title,
      body,
      details,
      payload: requestId != null ? '$requestId|trip_tracking' : null,
    );
  }

  /// Yolculuk bittiğinde veya iptal edildiğinde canlı bildirim çubuğunu temizler.
  Future<void> cancelTripProgressNotification() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(tripProgressNotificationId);
    } catch (e) {
      debugPrint('Error canceling trip progress notification: $e');
    }
  }

  /// Sürücü uygulamayı kullanmadığında 3. gün ve 7. günde tetiklenecek 2 ayrı bildirim planlar.
  Future<void> scheduleDriverInactivityReminders() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(_driver3DayNotificationId);
      await _flutterLocalNotificationsPlugin.cancel(_driver7DayNotificationId);

      const androidDetails = AndroidNotificationDetails(
        messageChannelId,
        'Mesajlar ve Bilgilendirmeler',
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
        messageChannelId,
        'Mesajlar ve Bilgilendirmeler',
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
