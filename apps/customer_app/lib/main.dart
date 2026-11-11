import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

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
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint("Failed to initialize Supabase: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  try {
    await NotificationService().initialize();
    // Müşteri uygulamayı kullandığında 7 gün sonrasına hatırlatıcı zamanla
    await NotificationService().scheduleCustomerInactivityReminder();
  } catch (e) {
    debugPrint("Failed to initialize local notifications: $e");
  }

  runApp(const ProviderScope(child: CekiciApp()));
}

class CekiciApp extends ConsumerStatefulWidget {
  const CekiciApp({super.key});

  @override
  ConsumerState<CekiciApp> createState() => _CekiciAppState();
}

class _CekiciAppState extends ConsumerState<CekiciApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService().scheduleCustomerInactivityReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().scheduleCustomerInactivityReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    NotificationService.onNotificationTapped = (requestId, type) {
      if (requestId.trim().isEmpty) return;
      final cleanRequestId = requestId.trim();
      final isVoip = (type == 'VOIP_CALL' || type == 'call');
      final isChat = (type == 'CHAT_MESSAGE' || type == 'chat');
      if (isVoip) {
        router.push('/customer/call/$cleanRequestId');
      } else if (isChat) {
        router.push('/customer/chat/$cleanRequestId');
      } else {
        router.push('/customer/tracking/$cleanRequestId');
      }
    };

    return MaterialApp.router(
      title: 'Çekicim',
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
