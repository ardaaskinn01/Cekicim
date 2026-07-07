
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../presentation/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/admin/admin_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplashing = state.uri.path == '/splash';
      final isAuthRoute = state.uri.path.startsWith('/login');

      if (isSplashing) return null;

      final session = authState.value?.session;
      final isAuthenticated = session != null;

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        final userModel = currentUserAsync.value;
        if (userModel == null) return null;
        if (userModel.role == UserRole.admin) {
          return '/admin';
        } else {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
    ],
  );
});
