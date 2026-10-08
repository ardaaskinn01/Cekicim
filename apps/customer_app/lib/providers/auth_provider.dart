import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_services/supabase_service.dart';
import 'package:shared_services/notification_service.dart';

import 'package:shared_models/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  try {
    final user = await repo.getCurrentUser(UserRole.customer);
    if (user != null) {
      if (user.role != UserRole.customer && user.role != UserRole.driver) {
        await repo.signOut();
        return null;
      }
      // Run FCM setup in the background to prevent blocking critical UI routing
      NotificationService().setupFCM(user.id).catchError((e) {
        debugPrint('Error setting up FCM: $e');
      });
    }
    return user;
  } catch (e) {
    // JWT geçersiz veya kullanıcı silinmiş — oturumu temizle
    debugPrint('currentUserProvider error (auto sign-out): $e');
    try {
      await repo.signOut();
    } catch (_) {}
    return null;
  }
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser(UserRole.customer);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @Deprecated('SMS ile giriş devre dışı bırakılmıştır.')
  Future<void> sendSMSCode(String phone) async {
    state = const AsyncValue.loading();
    try {
      // ignore: deprecated_member_use
      await _repository.signInWithPhone(phone);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  @Deprecated('SMS ile giriş devre dışı bırakılmıştır.')
  Future<void> verifySMSCode(String phone, String code) async {
    state = const AsyncValue.loading();
    try {
      // ignore: deprecated_member_use
      await _repository.verifyPhoneOTP(phone, code);
      final user = await _repository.getCurrentUser(UserRole.customer);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInWithGoogle(UserRole.customer);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInWithApple(UserRole.customer);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: UserRole.customer,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeProfile({
    required String fullName,
    required String phone,
    String? email,
    String? vehiclePlate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.createUserProfile(
        fullName: fullName,
        phone: phone,
        role: UserRole.customer,
        vehiclePlate: vehiclePlate,
        email: email,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInWithEmail(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteAccount();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
