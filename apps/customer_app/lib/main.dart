import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Failed to initialize local notifications: $e");
  }

  runApp(const ProviderScope(child: CekiciApp()));
}

class CekiciApp extends ConsumerWidget {
  const CekiciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Çekici',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
