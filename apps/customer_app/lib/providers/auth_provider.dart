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
      if (user.role != UserRole.customer) {
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

  Future<void> sendSMSCode(String phone) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signInWithPhone(phone);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifySMSCode(String phone, String code) async {
    state = const AsyncValue.loading();
    try {
      await _repository.verifyPhoneOTP(phone, code);
      final user = await _repository.getCurrentUser(UserRole.customer);
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
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
