import 'package:shared_services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_services/supabase_service.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final hasPendingNotification = NotificationService.hasPendingNotification;

    // Fast-path: If launched via notification, do NOT wait 2 seconds; proceed immediately!
    if (!hasPendingNotification) {
      await Future.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;

    try {
      final user = await ref.read(currentUserProvider.future);
      if (!mounted) return;

      // If launched via notification tap, onNotificationTapped handler routes directly to offer/call/chat screen
      if (NotificationService.hasPendingNotification) {
        debugPrint('[SplashScreen] Notification pending, delegating navigation to onNotificationTapped');
        return;
      }

      if (user == null) {
        final hasSession = SupabaseService.instance.client.auth.currentSession != null;
        if (hasSession) {
          context.go('/driver');
        } else {
          context.go('/login');
        }
      } else {
        switch (user.role) {
          case UserRole.driver:
          case UserRole.customer:
            context.go('/driver');
            break;
          case UserRole.admin:
            context.go('/login');
            break;
        }
      }
    } catch (e) {
      debugPrint("Splash screen auth error: $e");
      if (mounted) {
        if (NotificationService.hasPendingNotification) return;
        final hasSession = SupabaseService.instance.client.auth.currentSession != null;
        if (hasSession) {
          context.go('/driver');
        } else {
          context.go('/login');
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(100),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.local_shipping_rounded,
                      size: 80,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SÜRÜCÜ',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Çekicim Yol Yardım Sürücü Uygulaması',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
