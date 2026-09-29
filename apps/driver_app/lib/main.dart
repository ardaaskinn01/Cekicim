import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_theme.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/notification_service.dart';
import 'core/router/app_router.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler — must be a top-level function.
/// Android requires this for background/terminated FCM messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  try {
    final type = message.data['type'] as String?;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? (type == 'VOIP_CALL' ? '📞 Gelen Sesli Arama' : '🚨 Yeni Yol Yardım Talebi!');
    final body = notification?.body ?? message.data['body'] ?? (type == 'VOIP_CALL' ? 'Çekici hizmetiniz için canlı sesli arama geliyor.' : 'Yakınınızda yeni bir talep var. Hemen inceleyin!');
    final requestId = (message.data['request_id'] ?? message.data['requestId']) as String?;

    final localNotifications = FlutterLocalNotificationsPlugin();
    
    // Initialize inside background isolate
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

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

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: requestId != null ? '$requestId|${type ?? ""}' : null,
    );
  } catch (e) {
    debugPrint('Background message handler error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Register background handler BEFORE runApp
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint("Failed to initialize Supabase: $e");
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Failed to initialize local notifications: $e");
  }

  runApp(const ProviderScope(child: DriverApp()));
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Set FCM notification tap handler — navigates to offer or call screen when tapped
    NotificationService.onNotificationTapped = (requestId, type) {
      if (type == 'VOIP_CALL') {
        router.push('/driver/call/$requestId');
      } else {
        router.go('/driver/offer/$requestId');
      }
    };

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Çekicim Sürücü',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
