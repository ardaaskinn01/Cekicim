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

/// Top-level background message handler - must be a top-level function.
/// Tum mantik NotificationService.handleRemoteMessage icinde (cift bildirim engelleme dahil).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  await NotificationService().handleRemoteMessage(message, isForeground: false);
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
    // Uygulama açıldığında 3 gün sonrasına hatırlatıcı zamanla
    await NotificationService().scheduleInactivityReminder(days: 3);
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
      if (requestId.trim().isEmpty) {
        debugPrint('[NotificationTap] requestId is empty, redirecting to /driver');
        router.go('/driver');
        return;
      }
      final cleanRequestId = requestId.trim();
      final isVoip = (type == 'VOIP_CALL' || type == 'call');
      final isChat = (type == 'CHAT_MESSAGE' || type == 'chat');
      if (isVoip) {
        router.push('/driver/call/$cleanRequestId');
      } else if (isChat) {
        router.push('/driver/chat/$cleanRequestId');
      } else {
        router.go('/driver/offer/$cleanRequestId');
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
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
