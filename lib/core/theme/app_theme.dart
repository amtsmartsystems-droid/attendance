/// =====================================================
/// ملف: app_theme.dart
/// الوصف: نظام الألوان والخطوط والسمات للتطبيق
///        يستخدم خط النظام الافتراضي (يدعم العربية)
/// =====================================================

import 'package:flutter/material.dart';

/// --- ألوان التطبيق ---
class AppColors {
  // الألوان الرئيسية
  static const Color primary = Color(0xFF00D4FF);       // أزرق سماوي
  static const Color primaryDark = Color(0xFF0099BB);   // أزرق غامق
  static const Color secondary = Color(0xFF7C3AED);     // بنفسجي
  static const Color accent = Color(0xFF00FF9D);        // أخضر نيون

  // ألوان الحالات
  static const Color success = Color(0xFF00C896);       // أخضر نجاح
  static const Color error = Color(0xFFFF4757);         // أحمر خطأ
  static const Color warning = Color(0xFFFFBD00);       // أصفر تحذير
  static const Color scanning = Color(0xFF00D4FF);      // أزرق فحص

  // ألوان الخلفية
  static const Color background = Color(0xFF050A18);    // أسود داكن جداً
  static const Color surface = Color(0xFF0D1526);       // أزرق داكن
  static const Color card = Color(0xFF111D35);          // بطاقة داكنة
  static const Color cardBorder = Color(0xFF1E3A5F);    // حدود البطاقة

  // ألوان النصوص
  static const Color textPrimary = Color(0xFFE8F4FF);   // أبيض مائل للأزرق
  static const Color textSecondary = Color(0xFF7B9FC0); // رمادي مائل للأزرق
  static const Color textHint = Color(0xFF3D5A7A);      // رمادي خافت

  // تدرجات الألوان
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF050A18), Color(0xFF0A1628), Color(0xFF050A18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00A878)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFCC2233)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// --- سمة التطبيق الداكنة ---
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // --- نستخدم خط النظام الافتراضي (يدعم العربية) ---
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),

      // --- سمة AppBar ---
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // --- سمة ElevatedButton ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),

      // --- سمة SnackBar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
