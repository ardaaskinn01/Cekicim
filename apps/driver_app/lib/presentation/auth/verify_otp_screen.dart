import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';

/// Bu ekran artık kullanılmamaktadır.
/// SMS ile doğrulama devre dışı bırakılmıştır.
/// Giriş için login_screen.dart'a yönlendirme yapılır.
@Deprecated('SMS ile doğrulama devre dışı bırakılmıştır. login_screen.dart kullanınız.')
class VerifyOtpScreen extends StatelessWidget {
  final String phone;
  const VerifyOtpScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/login');
    });
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
