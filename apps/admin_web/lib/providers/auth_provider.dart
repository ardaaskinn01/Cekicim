import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_services/auth_repository.dart';
import 'package:shared_services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  final user = await repo.getCurrentUser(UserRole.admin);
  if (user != null) {
    if (user.role != UserRole.admin) {
      await repo.signOut();
      return null;
    }
  }
  return user;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser(UserRole.admin);
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
      final user = await _repository.getCurrentUser(UserRole.admin);
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
