import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/user_role.dart';
import 'package:shared_models/user_model.dart';
import 'package:shared_models/driver_model.dart';
import 'supabase_service.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<UserModel> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Giriş başarısız oldu.');
    }

    final userModel = await getCurrentUser();
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

  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final profileData = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profileData == null) return null;

    final metadataVerified = user.userMetadata?['is_verified'] as bool? ?? false;
    final profileDataCopy = Map<String, dynamic>.from(profileData);
    profileDataCopy['is_verified'] = profileDataCopy['is_verified'] ?? metadataVerified;

    final userModel = UserModel.fromJson(profileDataCopy);

    if (userModel.role == UserRole.driver) {
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

  Future<UserModel> updateUserProfile(UserModel userModel) async {
    await _client.from('profiles').update({
      'full_name': userModel.fullName,
      'phone': userModel.phone,
      'avatar_url': userModel.avatarUrl,
    }).eq('id', userModel.id);

    if (userModel is DriverModel) {
      await _client.from('drivers').update(userModel.toDriverJson()).eq('id', userModel.id);
    }

    return userModel;
  }

  Future<void> verifyCustomerTC(String tcNo) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'is_verified': true,
          'tc_no': tcNo,
        },
      ),
    );
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
}
