
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../presentation/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/admin/admin_dashboard_screen.dart';

// GoRouter'ın dinleyebileceği bir Notifier - auth state'i takip eder
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUserAsync = ref.read(currentUserProvider);

      final isSplashing = state.uri.path == '/splash';
      final isAuthRoute = state.uri.path.startsWith('/login');

      if (isSplashing) return null;

      // Henüz yüklenmediyse bekle
      if (authState.isLoading || currentUserAsync.isLoading) return null;

      final session = authState.value?.session;
      final isAuthenticated = session != null;

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated) {
        if (currentUserAsync.hasValue) {
          final userModel = currentUserAsync.value;
          if (userModel == null || userModel.role != UserRole.admin) {
            return '/login';
          }
          if (isAuthRoute) {
            return '/admin';
          }
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
