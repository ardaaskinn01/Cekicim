import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrorHandler {
  /// Converts any raw exception or Supabase error into a clean, human-friendly Turkish message.
  static String parse(dynamic error) {
    if (error == null) return 'Bilinmeyen bir hata oluştu.';

    if (error is AuthException) {
      return _parseAuthException(error);
    }

    if (error is PostgrestException) {
      return _parsePostgrestException(error);
    }

    if (error is SocketException || error is TimeoutException) {
      return 'İnternet bağlantınızı kontrol ediniz. Sunucuya ulaşılamıyor.';
    }

    final msg = error.toString().replaceAll('Exception: ', '').trim();

    if (msg.contains('Invalid login credentials') || msg.contains('invalid_grant')) {
      return 'Giriş bilgileri hatalı. Lütfen kontrol edip tekrar deneyiniz.';
    }
    if (msg.contains('User not found') || msg.contains('404')) {
      return 'Bu bilgilere ait kayıtlı kullanıcı bulunamadı.';
    }
    if (msg.contains('phone') && (msg.contains('invalid') || msg.contains('short') || msg.contains('format'))) {
      return 'Lütfen geçerli bir telefon numarası giriniz (Örn: 5551234567).';
    }
    if (msg.contains('Email not confirmed')) {
      return 'E-posta adresiniz henüz doğrulanmamış. Lütfen gelen kutunuzu kontrol edin.';
    }
    if (msg.contains('Rate limit exceeded') || msg.contains('429')) {
      return 'Çok fazla istekte bulunuldu. Lütfen 1 dakika bekleyip tekrar deneyin.';
    }
    if (msg.contains('Password should be at least')) {
      return 'Şifreniz en az 6 karakter olmalıdır.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Doğrulama kodu hatalı veya oturum süresi dolmuş. Lütfen tekrar deneyin.';
    }

    return msg;
  }

  static String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final status = e.statusCode;

    if (status == '400' || msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
      return 'Giriş bilgileri hatalı. Lütfen e-posta ve şifrenizi kontrol edin.';
    }
    if (status == '401' || msg.contains('unauthorized')) {
      return 'Doğrulama kodu hatalı veya süresi dolmuş. Lütfen yeni kod isteyiniz.';
    }
    if (status == '404' || msg.contains('user not found')) {
      return 'Kayıtlı kullanıcı bulunamadı.';
    }
    if (msg.contains('phone') && (msg.contains('invalid') || msg.contains('format') || msg.contains('short'))) {
      return 'Lütfen telefon numaranızı 10 hane olarak eksiksiz giriniz (Örn: 5551234567).';
    }
    if (msg.contains('email already in use') || msg.contains('user_already_exists') || msg.contains('already registered')) {
      return 'Bu e-posta adresi veya telefon numarası zaten başka bir hesaba kayıtlı.';
    }
    if (msg.contains('password')) {
      return 'Şifre en az 6 karakterden oluşmalıdır.';
    }
    if (status == '429' || msg.contains('rate limit')) {
      return 'Çok fazla hatalı deneme yapıldı. Lütfen 1 dakika bekleyiniz.';
    }

    return e.message;
  }

  static String _parsePostgrestException(PostgrestException e) {
    if (e.code == '23505') {
      return 'Bu kayıt veritabanında zaten mevcut.';
    }
    if (e.code == 'PGRST301' || e.message.contains('JWT')) {
      return 'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapınız.';
    }
    return 'Veritabanı işlemi sırasında hata oluştu: ${e.message}';
  }
}
