/// =====================================================
/// ملف: biometric_service.dart
/// الوصف: خدمة التحقق البيومتري قبل تسجيل الحضور
///        تستخدم local_auth لطلب البصمة أو Face ID
/// =====================================================

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// هل يدعم الجهاز البيومترية؟
  Future<bool> isAvailable() async {
    try {
      if (kIsWeb) return false;
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('[Biometric] ⚠️ خطأ في التحقق من الدعم: $e');
      return false;
    }
  }

  /// جلب أنواع البيومترية المتاحة
  Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// ✅ طلب التحقق البيومتري قبل تسجيل الحضور
  /// Returns true إذا نجح، false إذا فشل أو رُفض
  Future<bool> authenticate({String reason = 'أكّد هويتك لتسجيل الحضور'}) async {
    try {
      final available = await isAvailable();
      if (!available) {
        // إذا لم يدعم الجهاز البيومترية، نتجاوزها مباشرةً
        debugPrint('[Biometric] ℹ️ الجهاز لا يدعم البيومترية — تم التجاوز');
        return true;
      }

      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // يسمح بـ PIN كخيار بديل
          stickyAuth: true,       // يستمر حتى ينجح أو يُلغي المستخدم
          sensitiveTransaction: true,
        ),
      );

      debugPrint('[Biometric] ${result ? "✅ نجح التحقق" : "❌ فشل التحقق"}');
      return result;

    } on PlatformException catch (e) {
      debugPrint('[Biometric] ❌ PlatformException: ${e.code} - ${e.message}');
      // في حالة أخطاء معينة (مثل NotEnrolled)، اسمح بالمرور
      if (e.code == 'NotEnrolled' || e.code == 'NotAvailable') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Biometric] ❌ خطأ غير متوقع: $e');
      return true; // fallback آمن
    }
  }
}
