
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../presentation/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/auth/role_selection_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/verify_otp_screen.dart';
import '../../presentation/auth/reset_password_screen.dart';
import '../../presentation/auth/customer_verification_screen.dart';
import '../../presentation/customer/customer_home_screen.dart';
import '../../presentation/customer/request_service_screen.dart';
import '../../presentation/customer/history_screen.dart';
import '../../presentation/customer/profile_screen.dart';
import '../../presentation/customer/tracking_screen.dart';
import '../../presentation/customer/rating_screen.dart';
import '../../presentation/customer/chat_screen.dart';
import '../../presentation/customer/voip_call_screen.dart';
import '../../presentation/customer/customer_disputes_screen.dart';

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
        final userModel = currentUserAsync.value;
        if (userModel == null) return null;

        if (userModel.role == UserRole.customer) {
          if (isAuthRoute) return '/customer';
        } else {
          return '/login';
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
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: '/customer', builder: (context, state) => const CustomerHomeScreen()),
      GoRoute(path: '/customer/request', builder: (context, state) => const RequestServiceScreen()),
      GoRoute(path: '/customer/history', builder: (context, state) => const HistoryScreen()),
      GoRoute(path: '/customer/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/customer/disputes', builder: (context, state) => const CustomerDisputesScreen()),
      GoRoute(path: '/customer/tracking/:requestId', builder: (context, state) => const TrackingScreen()),
      GoRoute(
        path: '/customer/rate/:requestId/:driverId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          final driverId = state.pathParameters['driverId'] ?? '';
          final driverName = state.uri.queryParameters['name'] ?? 'Sürücü';
          return CustomerRatingScreen(requestId: requestId, driverId: driverId, driverName: driverName);
        },
      ),
      GoRoute(
        path: '/customer/chat/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return ChatScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/customer/call/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          final isInitiator = state.uri.queryParameters['initiator'] == 'true';
          return VoIPCallScreen(requestId: requestId, isInitiator: isInitiator);
        },
      ),
    ],
  );
});
