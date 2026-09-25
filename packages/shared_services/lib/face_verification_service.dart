import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';

class FaceVerificationResult {
  final bool isMatch;
  final double similarityScore;
  final String? message;
  final String? error;

  FaceVerificationResult({
    required this.isMatch,
    this.similarityScore = 0.0,
    this.message,
    this.error,
  });
}

class FaceVerificationService {
  static final FaceVerificationService instance = FaceVerificationService._internal();
  factory FaceVerificationService() => instance;
  FaceVerificationService._internal();

  /// Captures a live selfie using the front camera and verifies it against the stored driver license photo via AWS Rekognition
  Future<FaceVerificationResult> captureAndVerifySelfie(String driverId) async {
    try {
      final picker = ImagePicker();
      final XFile? selfie = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (selfie == null) {
        return FaceVerificationResult(
          isMatch: false,
          error: 'Selfie çekimi iptal edildi.',
        );
      }

      final bytes = await File(selfie.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Invoke Supabase Edge Function running AWS Rekognition CompareFaces
      final response = await SupabaseService.instance.client.functions.invoke(
        'verify_driver_face',
        body: {
          'driver_id': driverId,
          'selfie_base64': base64Image,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        return FaceVerificationResult(
          isMatch: false,
          error: data?['error'] as String? ?? 'Yüz doğrulama yanıtı alınamadı.',
        );
      }

      final isMatched = (data['matched'] as bool?) ?? false;
      final similarity = (data['similarity'] as num?)?.toDouble() ?? 0.0;
      final msg = data['message'] as String?;

      return FaceVerificationResult(
        isMatch: isMatched,
        similarityScore: similarity,
        message: msg,
      );
    } catch (e) {
      debugPrint('FaceVerificationService Exception: $e');
      return FaceVerificationResult(
        isMatch: false,
        error: 'Yüz doğrulama servisinde hata: $e',
      );
    }
  }
}
