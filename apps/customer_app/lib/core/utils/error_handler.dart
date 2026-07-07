import 'package:flutter/material.dart';
import 'package:shared_ui/app_colors.dart';

abstract class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([super.message = 'İnternet bağlantısı kurulamadı.']);
}

class AuthException extends AppException {
  AuthException([super.message = 'Kimlik doğrulama hatası oluştu.']);
}

class LocationException extends AppException {
  LocationException([super.message = 'Konum servisine erişilemedi.']);
}

class DatabaseException extends AppException {
  DatabaseException([super.message = 'Veritabanı işlemi başarısız.']);
}

class ErrorHandler {
  static AppException handleError(Object error) {
    if (error is AppException) return error;
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socket') || errStr.contains('network') || errStr.contains('connection')) {
      return NetworkException();
    }
    if (errStr.contains('auth') || errStr.contains('password') || errStr.contains('jwt')) {
      return AuthException(error.toString().replaceAll('Exception: ', ''));
    }
    if (errStr.contains('location') || errStr.contains('gps') || errStr.contains('permission')) {
      return LocationException();
    }
    return DatabaseException(error.toString().replaceAll('Exception: ', ''));
  }

  static void showErrorSnackbar(BuildContext context, AppException exception) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(exception.message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
