import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User, OAuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'role': role.dbValue,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate.trim(),
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Kayıt oluşturulamadı. Lütfen bilgilerinizi kontrol ediniz.');
    }

    // Ensure database profile is created immediately
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email.trim(),
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'role': role.dbValue,
        'is_verified': false,
      }, onConflict: 'id');

      if (role == UserRole.driver) {
        await _client.from('drivers').upsert({
          'id': user.id,
          'vehicle_plate': vehiclePlate?.trim() ?? '',
          'is_onboarding_completed': false,
          'is_verified': false,
        }, onConflict: 'id');
      }
    } catch (e) {
      debugPrint('signUpWithEmail profile upsert notice: $e');
    }

    final userModel = UserModel(
      id: user.id,
      email: email.trim(),
      fullName: fullName.trim(),
      phone: phone.trim(),
      role: role,
      createdAt: DateTime.now(),
      isProfileComplete: fullName.trim().isNotEmpty,
    );

    if (role == UserRole.driver && vehiclePlate != null) {
      return DriverModel(
        id: user.id,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: role,
        createdAt: DateTime.now(),
        vehiclePlate: vehiclePlate.trim(),
        isProfileComplete: fullName.trim().isNotEmpty,
      );
    }

    return userModel;
  }

  Future<UserModel> signInWithGoogle(UserRole role) async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? iosClientId : null,
      serverClientId: webClientId,
      scopes: const ['email', 'profile'],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google ile giriş işlemi iptal edildi.');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google kimlik belirteci (ID Token) alınamadı. Lütfen Web Client ID ayarlarını kontrol ediniz.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Google ile oturum açılamadı.');
    }

    return await _ensureProfileAfterOAuth(
      user: user,
      role: role,
      defaultFullName: googleUser.displayName ?? '',
      defaultEmail: googleUser.email,
      avatarUrl: googleUser.photoUrl,
    );
  }

  Future<UserModel> signInWithApple(UserRole role) async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception('Apple kimlik belirteci alınamadı.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Apple ile oturum açılamadı.');
    }

    String appleFullName = '';
    if (credential.givenName != null || credential.familyName != null) {
      appleFullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
    }

    return await _ensureProfileAfterOAuth(
      user: user,
      role: role,
      defaultFullName: appleFullName,
      defaultEmail: credential.email ?? user.email ?? '',
    );
  }

  Future<UserModel> _ensureProfileAfterOAuth({
    required User user,
    required UserRole role,
    required String defaultFullName,
    required String defaultEmail,
    String? avatarUrl,
  }) async {
    Map<String, dynamic>? profileData = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profileData == null) {
      final metaName = (user.userMetadata?['full_name'] ?? user.userMetadata?['name']) as String? ?? '';
      final name = defaultFullName.isNotEmpty ? defaultFullName : metaName;
      final email = defaultEmail.isNotEmpty ? defaultEmail : (user.email ?? '');

      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': name,
        'phone': user.phone ?? (user.userMetadata?['phone'] as String? ?? ''),
        'role': role.dbValue,
        'avatar_url': avatarUrl ?? (user.userMetadata?['avatar_url'] as String?),
        'is_verified': false,
      }, onConflict: 'id');

      if (role == UserRole.driver) {
        await _client.from('drivers').upsert({
          'id': user.id,
          'vehicle_plate': '',
          'is_onboarding_completed': false,
          'is_verified': false,
        }, onConflict: 'id');
      }
    } else {
      final currentName = profileData['full_name'] as String? ?? '';
      final updates = <String, dynamic>{};
      if (currentName.isEmpty && defaultFullName.isNotEmpty) {
        updates['full_name'] = defaultFullName;
      }
      if (profileData['avatar_url'] == null && avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }
      if (updates.isNotEmpty) {
        await _client.from('profiles').update(updates).eq('id', user.id);
      }
    }

    final userModel = await getCurrentUser(role);
    if (userModel == null) {
      throw Exception('Kullanıcı profili alınamadı.');
    }
    return userModel;
  }

  Future<void> sendPasswordResetOTP(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.supabase.cekici://login-callback',
    );
  }

  Future<void> verifyOTP(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }

  Future<UserModel?> getCurrentUser(UserRole expectedRole) async {
    if (_client.auth.currentSession == null) {
      return null;
    }

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

    Map<String, dynamic>? profileData = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final rawPhone = user.phone ?? (user.userMetadata?['phone'] as String?);
    // Fallback: If profile is not found by Auth user.id, search by phone number (last 10 digits)
    if (profileData == null && rawPhone != null && rawPhone.trim().isNotEmpty) {
      final phoneStr = rawPhone.trim();
      final digits = phoneStr.replaceAll(RegExp(r'\D'), '');
      final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

      final matches = await _client
          .from('profiles')
          .select()
          .ilike('phone', '%$last10')
          .limit(1);

      if (matches.isNotEmpty) {
        profileData = Map<String, dynamic>.from(matches.first);
        final oldId = profileData['id'] as String;
        if (oldId != user.id) {
          try {
            await _client.from('profiles').update({'id': user.id}).eq('id', oldId);
            if (expectedRole == UserRole.driver) {
              await _client.from('drivers').update({'id': user.id}).eq('id', oldId);
            }
            profileData['id'] = user.id;
          } catch (e) {
            debugPrint('Failed to migrate profile ID to Auth user ID: $e');
          }
        }
      }
    }

    if (profileData == null) {
      final metadataName = (user.userMetadata?['full_name'] ?? user.userMetadata?['name']) as String? ?? '';
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        fullName: metadataName,
        phone: user.phone ?? '',
        role: expectedRole,
        createdAt: DateTime.now(),
        isProfileComplete: metadataName.isNotEmpty,
      );
    }

    // Auto-upgrade customer to driver if accessing driver app
    if (expectedRole == UserRole.driver) {
      final roleStr = profileData['role'] as String?;
      if (roleStr == 'customer') {
        try {
          await _client.from('profiles').update({'role': 'driver'}).eq('id', user.id);
          profileData['role'] = 'driver';

          final driverData = await _client
              .from('drivers')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (driverData == null) {
            await _client.from('drivers').insert({
              'id': user.id,
              'vehicle_plate': '',
              'is_onboarding_completed': false,
              'is_verified': false,
            });
          }
        } catch (e) {
          debugPrint('getCurrentUser: Failed to auto-upgrade customer to driver: $e');
        }
      }
    }

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

  @Deprecated('SMS ile giriş devre dışı bırakılmıştır.')
  Future<void> signInWithPhone(String phone) async {
    throw Exception('SMS ile giriş devre dışı bırakılmıştır. Lütfen E-posta, Google veya Apple ile giriş yapınız.');
  }

  @Deprecated('SMS ile giriş devre dışı bırakılmıştır.')
  Future<void> verifyPhoneOTP(String phone, String token) async {
    throw Exception('SMS ile doğrulama devre dışı bırakılmıştır. Lütfen E-posta, Google veya Apple ile giriş yapınız.');
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

    // Check if profile already exists to preserve existing verification & name status
    final existingProfile = await _client
        .from('profiles')
        .select('is_verified, full_name, phone, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    final isAlreadyVerified = existingProfile != null && (existingProfile['is_verified'] as bool? ?? false);
    final existingName = existingProfile != null ? existingProfile['full_name'] as String? : null;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': email ?? user.email ?? '$normalizedPhone@phone.user',
      'full_name': (fullName.isNotEmpty) ? fullName : (existingName ?? ''),
      'phone': normalizedPhone,
      'role': role.dbValue,
      'is_verified': isAlreadyVerified,
    }, onConflict: 'id');

    final userModel = UserModel(
      id: user.id,
      email: user.email ?? '$normalizedPhone@phone.user',
      fullName: (fullName.isNotEmpty) ? fullName : (existingName ?? ''),
      phone: normalizedPhone,
      role: role,
      createdAt: DateTime.now(),
      isVerified: isAlreadyVerified,
    );

    // If driver, check existing driver record to preserve onboarding completion & document status
    if (role == UserRole.driver) {
      final existingDriver = await _client
          .from('drivers')
          .select('is_onboarding_completed, vehicle_plate, is_verified')
          .eq('id', user.id)
          .maybeSingle();

      final isOnboardingDone = existingDriver != null && (existingDriver['is_onboarding_completed'] as bool? ?? false);
      final driverVerified = existingDriver != null && (existingDriver['is_verified'] as bool? ?? false);
      final existingPlate = existingDriver != null ? existingDriver['vehicle_plate'] as String? : null;

      await _client.from('drivers').upsert({
        'id': user.id,
        'vehicle_plate': (vehiclePlate != null && vehiclePlate.isNotEmpty)
            ? vehiclePlate
            : (existingPlate ?? ''),
        'is_onboarding_completed': isOnboardingDone,
        'is_verified': driverVerified,
      }, onConflict: 'id');

      return DriverModel(
        id: user.id,
        email: user.email ?? '$normalizedPhone@phone.user',
        fullName: (fullName.isNotEmpty) ? fullName : (existingName ?? ''),
        phone: normalizedPhone,
        role: role,
        createdAt: DateTime.now(),
        vehiclePlate: (vehiclePlate != null && vehiclePlate.isNotEmpty)
            ? vehiclePlate
            : (existingPlate ?? ''),
        isOnboardingCompleted: isOnboardingDone,
        isVerified: driverVerified,
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

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'is_verified': true,
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

  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Oturum açmış kullanıcı bulunamadı.');

    try {
      await _client.from('drivers').delete().eq('id', user.id);
    } catch (e) {
      debugPrint('Error deleting driver record: $e');
    }

    try {
      await _client.from('profiles').delete().eq('id', user.id);
    } catch (e) {
      debugPrint('Error deleting profile record: $e');
    }

    await signOut();
  }
}
