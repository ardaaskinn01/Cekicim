import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_theme.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/notification_service.dart';
import 'core/router/app_router.dart';
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
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? '🚨 Yeni Yol Yardım Talebi!';
    final body = notification?.body ?? message.data['body'] ?? 'Yakınınızda yeni bir talep var. Hemen inceleyin!';

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
      sound: RawResourceAndroidNotificationSound('bg_alarm2'),
      playSound: true,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: 'bg_alarm2.mp3',
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
    );
  } catch (e) {
    debugPrint('Background message handle error: $e');
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

    // Set FCM notification tap handler — navigates to offer screen when tapped
    NotificationService.onNotificationTapped = (requestId) {
      router.go('/driver/offer/$requestId');
    };

    return MaterialApp.router(
      title: 'Çekici Sürücü',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
