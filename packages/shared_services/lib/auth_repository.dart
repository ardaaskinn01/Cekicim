import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/driver_model.dart';
import 'supabase_service.dart';
import 'nvi_service.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.instance.client;
  bool get _isProductionOfficial => false;

  Future<UserModel> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Giriş başarısız oldu.');
    }

    final profileData = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .limit(1)
        .maybeSingle();

    if (profileData == null) {
      throw Exception('Kullanıcı profili bulunamadı.');
    }
    final role = UserRole.fromString(profileData['role'] as String?);

    final userModel = await getCurrentUser(role);
    if (userModel == null) {
      throw Exception('Kullanıcı profili bulunamadı.');
    }
    return userModel;
  }

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String? vehiclePlate,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'role': role.dbValue,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Kayıt oluşturulamadı.');
    }

    final userModel = UserModel(
      id: user.id,
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
      createdAt: DateTime.now(),
    );

    if (role == UserRole.driver && vehiclePlate != null) {
      return DriverModel(
        id: user.id,
        email: email,
        fullName: fullName,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
        vehiclePlate: vehiclePlate,
      );
    }

    return userModel;
  }

  Future<void> sendPasswordResetOTP(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.cekici://login-callback',
    );
  }

  Future<void> verifyOTP(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserModel?> getCurrentUser(UserRole expectedRole) async {
    User? user;
    try {
      final response = await _client.auth.getUser();
      user = response.user;
    } catch (e) {
      debugPrint('getCurrentUser: session validation failed, signing out: $e');
      try {
        await signOut();
      } catch (_) {}
      return null;
    }

    if (user == null) return null;

    final profileData = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .eq('role', expectedRole.dbValue)
        .maybeSingle();

    if (profileData == null) return null;

    final metadataVerified = user.userMetadata?['is_verified'] as bool? ?? false;
    final profileDataCopy = Map<String, dynamic>.from(profileData);
    // is_verified kolonu profiles tablosunda olmayabilir, güvenli fallback
    if (!profileDataCopy.containsKey('is_verified') || profileDataCopy['is_verified'] == null) {
      profileDataCopy['is_verified'] = metadataVerified;
    }

    final userModel = UserModel.fromJson(profileDataCopy);

    if (expectedRole == UserRole.driver) {
      final driverData = await _client
          .from('drivers')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (driverData != null) {
        return DriverModel.fromJson(profileDataCopy, driverData);
      }
    }

    return userModel;
  }

  Future<void> signInWithPhone(String phone) async {
    var normalizedPhone = phone.trim();
    if (!normalizedPhone.startsWith('+')) {
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '+90${normalizedPhone.substring(1)}';
      } else if (normalizedPhone.startsWith('90')) {
        normalizedPhone = '+$normalizedPhone';
      } else {
        normalizedPhone = '+90$normalizedPhone';
      }
    }

    await _client.auth.signInWithOtp(
      phone: normalizedPhone,
    );
  }

  Future<void> verifyPhoneOTP(String phone, String token) async {
    var normalizedPhone = phone.trim();
    if (!normalizedPhone.startsWith('+')) {
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '+90${normalizedPhone.substring(1)}';
      } else if (normalizedPhone.startsWith('90')) {
        normalizedPhone = '+$normalizedPhone';
      } else {
        normalizedPhone = '+90$normalizedPhone';
      }
    }

    await _client.auth.verifyOTP(
      phone: normalizedPhone,
      token: token,
      type: OtpType.sms,
    );
  }

  Future<UserModel> createUserProfile({
    required String fullName,
    required String phone,
    required UserRole role,
    String? vehiclePlate,
    String? email,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı.');
    }

    var normalizedPhone = phone.trim();
    if (!normalizedPhone.startsWith('+')) {
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '+90${normalizedPhone.substring(1)}';
      } else if (normalizedPhone.startsWith('90')) {
        normalizedPhone = '+$normalizedPhone';
      } else {
        normalizedPhone = '+90$normalizedPhone';
      }
    }

    // Upsert profile (handles re-registration without duplicate key errors)
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': email ?? user.email ?? '$normalizedPhone@phone.user',
      'full_name': fullName,
      'phone': normalizedPhone,
      'role': role.dbValue,
      'is_verified': false,
    }, onConflict: 'id');

    final userModel = UserModel(
      id: user.id,
      email: user.email ?? '$normalizedPhone@phone.user',
      fullName: fullName,
      phone: normalizedPhone,
      role: role,
      createdAt: DateTime.now(),
    );

    // If driver, insert driver record
    if (role == UserRole.driver && vehiclePlate != null) {
      await _client.from('drivers').upsert({
        'id': user.id,
        'vehicle_plate': vehiclePlate,
        'is_onboarding_completed': false,
      }, onConflict: 'id');

      return DriverModel(
        id: user.id,
        email: user.email ?? '$normalizedPhone@phone.user',
        fullName: fullName,
        phone: normalizedPhone,
        role: role,
        createdAt: DateTime.now(),
        vehiclePlate: vehiclePlate,
      );
    }

    return userModel;
  }

  Future<UserModel> updateUserProfile(UserModel userModel) async {
    await _client.from('profiles').update({
      'full_name': userModel.fullName,
      'phone': userModel.phone,
      'avatar_url': userModel.avatarUrl,
    }).eq('id', userModel.id);

    if (userModel is DriverModel) {
      await _client.from('drivers').upsert(userModel.toDriverJson());
    }

    return userModel;
  }

  Future<void> verifyCustomerTC({
    required String tcNo,
    required String firstName,
    required String lastName,
    required int birthYear,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    bool isValid = false;
    if (!_isProductionOfficial) {
      isValid = true;
      debugPrint('MERNIS (Bypass Mode): T.C. Kimlik doğrulaması tamamen atlandı (Aktif Bypass).');
    } else {
      isValid = await NviService().validateTCKimlikNo(
        tcNo: tcNo,
        firstName: firstName,
        lastName: lastName,
        birthYear: birthYear,
      );
    }

    if (!isValid) {
      throw Exception('Kimlik doğrulama başarısız oldu. Lütfen bilgilerinizi kontrol ediniz.');
    }

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'is_verified': true,
          'tc_no': tcNo,
        },
      ),
    );

    await _client.from('profiles').update({
      'is_verified': true,
    }).eq('id', user.id);
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final profileData = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profileData == null) return null;
    return UserModel.fromJson(profileData);
  }

  Future<String> uploadDriverDocument({
    required String driverId,
    required String documentType,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final path = '$driverId/$documentType/$fileName';
    await _client.storage.from('driver-documents').uploadBinary(
      path,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),
    );
    return _client.storage.from('driver-documents').getPublicUrl(path);
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _client.from('profiles').update({
      'fcm_token': token,
    }).eq('id', userId);
  }
}
