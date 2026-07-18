/// =====================================================
/// ملف: app_config.dart
/// الوصف: تكوين التطبيق - يُحمَّل من بيئة البناء الآمنة
///
/// ✅ المفاتيح لا تُخزَّن كنص صريح في الكود
/// ✅ يتم حقنها أثناء البناء عبر --dart-define
/// ✅ في حالة عدم وجودها (للتطوير) تُستخدم قيم فارغة
/// =====================================================
class AppConfig {
  // ── Supabase ─────────────────────────────────────────
  // تُحقَن من البيئة: flutter run --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '', // فارغ = لا تعمل في الإنتاج بدون تكوين
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ── HMAC Secret ──────────────────────────────────────
  static const String hmacSecret = String.fromEnvironment(
    'HMAC_SECRET',
    defaultValue: '',
  );

  // ── Backend API ──────────────────────────────────────
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000', // للمحاكي: localhost
  );

  // ── التحقق من اكتمال الإعداد ─────────────────────────
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      hmacSecret.isNotEmpty;

  // ── نقطة نهاية تسجيل الحضور ──────────────────────────
  static String get attendanceEndpoint =>
      '$supabaseUrl/functions/v1/record-attendance';
}
