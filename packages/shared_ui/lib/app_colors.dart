import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF10B981);       // Enerjik Nane Yeşili (Mint Green)
  static const Color secondary = Color(0xFF059669);     // Zümrüt Yeşili (Emerald)
  static const Color accent = Color(0xFF34D399);        // Açık Nane Yeşili

  // Light Theme Colors (Slate Light Palette)
  static const Color lightBackground = Color(0xFFF8FAFC);    // Slate 50
  static const Color lightCardBackground = Color(0xFFFFFFFF); // Pure White
  static const Color lightSurface = Color(0xFFF1F5F9);       // Slate 100
  static const Color lightTextPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextHint = Color(0xFF94A3B8);      // Slate 400
  static const Color lightBorder = Color(0xFFE2E8F0);        // Slate 200
  static const Color lightDivider = Color(0xFFE2E8F0);       // Slate 200

  // Dark Theme Colors (Slate Dark Palette)
  static const Color darkBackground = Color(0xFF0F172A);    // Slate 900
  static const Color darkCardBackground = Color(0xFF1E293B); // Slate 800
  static const Color darkSurface = Color(0xFF334155);       // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC);   // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextHint = Color(0xFF64748B);      // Slate 500
  static const Color darkBorder = Color(0xFF334155);        // Slate 700
  static const Color darkDivider = Color(0xFF1E293B);       // Slate 800

  // Legacy static fallbacks
  static const Color background = Color(0xFF0F172A);
  static const Color cardBackground = Color(0xFF1E293B);
  static const Color surface = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textHint = Color(0xFF64748B);
  static const Color error = Color(0xFFF43F5E);         // Gül Kırmızısı
  static const Color success = Color(0xFF10B981);       // Başarılı Yeşili
  static const Color warning = Color(0xFFF59E0B);       // Amber Sarısı
  static const Color border = Color(0xFF334155);        // Slate 700
  static const Color divider = Color(0xFF1E293B);       // Bölücü çizgi
  static const Color shadow = Colors.black38;

  // Context-aware dynamic helpers
  static bool isDark(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark;
  }

  static Color getTextPrimary(BuildContext context) {
    return isDark(context) ? darkTextPrimary : lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return isDark(context) ? darkTextSecondary : lightTextSecondary;
  }

  static Color getCardBackground(BuildContext context) {
    return isDark(context) ? darkCardBackground : lightCardBackground;
  }

  static Color getSurface(BuildContext context) {
    return isDark(context) ? darkSurface : lightSurface;
  }

  static Color getBorder(BuildContext context) {
    return isDark(context) ? darkBorder : lightBorder;
  }
}
