
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_models/driver_model.dart';
import '../../providers/auth_provider.dart';
import '../../presentation/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/verify_otp_screen.dart';
import '../../presentation/auth/reset_password_screen.dart';
import '../../presentation/auth/driver_onboarding_screen.dart';
import '../../presentation/driver/driver_home_screen.dart';
import '../../presentation/driver/driver_history_screen.dart';
import '../../presentation/driver/driver_profile_screen.dart';
import '../../presentation/driver/rate_customer_screen.dart';
import '../../presentation/driver/incoming_request_screen.dart';
import '../../presentation/driver/navigation_screen.dart';
import '../../presentation/driver/chat_screen.dart';
import '../../presentation/driver/voip_call_screen.dart';
import '../../presentation/driver/driver_disputes_screen.dart';
import '../../presentation/driver/complete_request_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplashing = state.uri.path == '/splash';
      final isAuthRoute = state.uri.path.startsWith('/login') ||
          state.uri.path.startsWith('/register') ||
          state.uri.path.startsWith('/forgot-password') ||
          state.uri.path.startsWith('/verify-otp') ||
          state.uri.path.startsWith('/reset-password');

      if (isSplashing) return null;

      final session = authState.value?.session;
      final isAuthenticated = session != null;

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated) {
        if (currentUserAsync.hasValue) {
          final userModel = currentUserAsync.value;
          if (userModel == null) {
            // Profile is missing, redirect to registration/complete profile screen
            if (state.uri.path != '/register' && state.uri.path != '/verify-otp') {
              return '/register';
            }
            return null;
          }

          if (userModel.role == UserRole.driver) {
            final isDriverModel = userModel is DriverModel;
            final hasRejection = isDriverModel &&
                userModel.rejectionReason != null &&
                userModel.rejectionReason!.isNotEmpty;
            final completedOnboarding = isDriverModel &&
                userModel.isOnboardingCompleted &&
                !hasRejection; // If rejected, onboarding is not completed successfully
            final isOnboardingRoute = state.uri.path == '/driver/onboarding';

            if (!completedOnboarding) {
              if (!isOnboardingRoute) return '/driver/onboarding';
            } else {
              if (isOnboardingRoute || isAuthRoute) return '/driver';
            }
          } else {
            return '/login';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return VerifyOtpScreen(phone: phone);
        },
      ),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: '/driver/onboarding', builder: (context, state) => const DriverOnboardingScreen()),
      GoRoute(path: '/driver', builder: (context, state) => const DriverHomeScreen()),
      GoRoute(path: '/driver/history', builder: (context, state) => const DriverHistoryScreen()),
      GoRoute(path: '/driver/profile', builder: (context, state) => const DriverProfileScreen()),
      GoRoute(path: '/driver/disputes', builder: (context, state) => const DriverDisputesScreen()),
      GoRoute(
        path: '/driver/rate/:requestId/:customerId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          final customerId = state.pathParameters['customerId'] ?? '';
          final customerName = state.uri.queryParameters['name'] ?? 'Müşteri';
          return RateCustomerScreen(requestId: requestId, customerId: customerId, customerName: customerName);
        },
      ),
      GoRoute(
        path: '/driver/offer/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return IncomingRequestScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/driver/navigate/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return NavigationScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/driver/chat/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return ChatScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/driver/complete/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return CompleteRequestScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/driver/call/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          final isInitiator = state.uri.queryParameters['initiator'] == 'true';
          return VoIPCallScreen(requestId: requestId, isInitiator: isInitiator);
        },
      ),
    ],
  );
});
