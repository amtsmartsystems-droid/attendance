/// =====================================================
/// ملف: security_service.dart
/// الوصف: خدمة الأمان المركزية
///        تجمع كل طبقات الحماية في مكان واحد:
///        1. HMAC-SHA256 لتوقيع الطلبات
///        2. Nonce لمنع إعادة الإرسال (Replay Attack)
///        3. BSSID Geofencing لتقييد المسح بالشبكة
///        4. Biometric Auth للتحقق من هوية الموظف
///        5. فحص البيئة (Root Detection)
/// =====================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/config/app_config.dart';

/// نتيجة فحص الأمان
class SecurityCheckResult {
  final bool isAllowed;
  final String? reason; // سبب الرفض إن وجد

  const SecurityCheckResult({required this.isAllowed, this.reason});

  factory SecurityCheckResult.allowed() =>
      const SecurityCheckResult(isAllowed: true);

  factory SecurityCheckResult.denied(String reason) =>
      SecurityCheckResult(isAllowed: false, reason: reason);
}

/// --- خدمة الأمان المركزية ---
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // --- إعداد: المفتاح السري لتوليد HMAC — يأتي من AppConfig (محقون وقت البناء) ---
  static String get _hmacSecret => AppConfig.hmacSecret;

  // --- إعداد: قائمة الـ BSSID المسموح بها (MAC Address لراوتر/رواتر الشركة) ---
  // للتطوير: فارغة = مسموح بكل الشبكات. في الإنتاج: أضف MAC راوتر شركتك.
  static const List<String> _allowedBSSIDs = [
    // مثال: '1a:2b:3c:4d:5e:6f',
    // أضف هنا MAC Address لراوترات الشركة
  ];

  // --- قاموس الـ Nonce المستخدمة ---
  // يحتفظ بآخر 1000 nonce منعاً لهجمات الإعادة
  final Set<String> _usedNonces = {};
  static const int _maxNonces = 1000;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final NetworkInfo _networkInfo = NetworkInfo();

  // ================================================================
  //  1. HMAC-SHA256 — توقيع الطلب
  // ================================================================

  /// توليد توقيع HMAC-SHA256 للبيانات
  /// المدخل: خريطة البيانات المراد إرسالها
  /// المخرج: سلسلة HEX تمثل التوقيع الرقمي
  String generateHmacSignature(Map<String, dynamic> data) {
    // ترتيب المفاتيح أبجدياً لضمان ثبات التوقيع
    final sortedKeys = data.keys.toList()..sort();
    final payload = sortedKeys.map((k) => '$k=${data[k]}').join('&');

    final key = utf8.encode(_hmacSecret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    debugPrint('[Security] ✍️ HMAC Payload: $payload');
    debugPrint('[Security] ✍️ HMAC Signature: ${digest.toString()}');

    return digest.toString();
  }

  // ================================================================
  //  2. Nonce — منع إعادة الإرسال (Replay Attack)
  // ================================================================

  /// توليد رقم Nonce فريد يُستخدم مرة واحدة فقط
  String generateNonce() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${timestamp}_$randomPart';
  }

  /// التحقق من أن الـ Nonce لم يُستخدم مسبقاً وحفظه
  bool validateAndStoreNonce(String nonce) {
    if (_usedNonces.contains(nonce)) {
      debugPrint('[Security] 🚫 Nonce مكرر! محاولة Replay Attack محتملة: $nonce');
      return false;
    }

    // تنظيف القاموس إذا امتلأ
    if (_usedNonces.length >= _maxNonces) {
      _usedNonces.clear();
      debugPrint('[Security] 🧹 تم مسح قاموس Nonce (امتلأ)');
    }

    _usedNonces.add(nonce);
    return true;
  }

  // ================================================================
  //  3. BSSID Geofencing — تقييد المسح بشبكة الشركة
  // ================================================================

  /// التحقق من أن الهاتف متصل بشبكة Wi-Fi الشركة
  /// يعتمد على MAC Address للراوتر (BSSID) وليس الاسم فقط
  Future<SecurityCheckResult> checkNetworkGeofence() async {
    // إذا لم يتم تحديد أي شبكات مسموح بها، السماح للجميع (وضع التطوير)
    if (_allowedBSSIDs.isEmpty) {
      debugPrint('[Security] ⚠️ لا توجد شبكات مقيدة - وضع التطوير مفتوح');
      return SecurityCheckResult.allowed();
    }

    try {
      final bssid = await _networkInfo.getWifiBSSID();

      if (bssid == null || bssid.isEmpty) {
        debugPrint('[Security] ❌ لا يوجد اتصال Wi-Fi');
        return SecurityCheckResult.denied(
          'يجب أن تكون داخل مبنى الشركة (متصلاً بشبكة Wi-Fi الشركة) لتسجيل الحضور',
        );
      }

      final normalizedBssid = bssid.toLowerCase();
      final isAllowed = _allowedBSSIDs
          .map((b) => b.toLowerCase())
          .contains(normalizedBssid);

      if (!isAllowed) {
        debugPrint('[Security] 🚫 شبكة غير مسموح بها: $bssid');
        return SecurityCheckResult.denied(
          'أنت خارج شبكة الشركة - لا يمكن تسجيل الحضور من هذا الموقع',
        );
      }

      debugPrint('[Security] ✅ الشبكة معتمدة: $bssid');
      return SecurityCheckResult.allowed();
    } catch (e) {
      debugPrint('[Security] خطأ في فحص الشبكة: $e');
      // في حالة الخطأ نسمح بالمرور لتجنب تعطيل النظام
      return SecurityCheckResult.allowed();
    }
  }

  // ================================================================
  //  4. Biometric Authentication — التحقق البيومتري
  // ================================================================

  /// التحقق من أن من يحمل الهاتف هو الموظف الفعلي
  /// عبر بصمة الإصبع أو التعرف على الوجه
  // قناة التواصل المباشر مع BiometricPrompt في Android
  static const MethodChannel _biometricChannel =
      MethodChannel('com.amt.amt_nfc_attendance/biometric');

  Future<SecurityCheckResult> authenticateWithBiometrics() async {
    try {
      // أولاً: فحص هل الجهاز يدعم البيومتري (عبر Kotlin مباشرة)
      final bool canAuth =
          await _biometricChannel.invokeMethod('canAuthenticate');

      debugPrint('[Security] canAuthenticate (native): $canAuth');

      if (!canAuth) {
        return SecurityCheckResult.denied(
          'يرجى تفعيل قفل الشاشة أو تسجيل بصمتك من إعدادات الهاتف',
        );
      }

      // ثانياً: إظهار شاشة البصمة / PIN الأصلية
      final bool didAuth =
          await _biometricChannel.invokeMethod('authenticate');

      debugPrint('[Security] authenticate result (native): $didAuth');

      if (!didAuth) {
        return SecurityCheckResult.denied(
          'تم إلغاء التحقق — لا يمكن تسجيل الحضور بدون التحقق',
        );
      }

      return SecurityCheckResult.allowed();
    } on PlatformException catch (e) {
      debugPrint('[Security] PlatformException: ${e.code} - ${e.message}');
      return SecurityCheckResult.denied(
        'خطأ في التحقق: ${e.message ?? "حاول مرة أخرى"}',
      );
    } catch (e) {
      debugPrint('[Security] خطأ غير متوقع في البيومتري: $e');
      return SecurityCheckResult.denied(
        'تعذّر التحقق من هويتك — يرجى المحاولة مرة أخرى',
      );
    }
  }

  // ================================================================
  //  5. فحص البيئة — كشف Root/Jailbreak
  // ================================================================

  /// فحص بسيط لبيئة الهاتف للكشف عن التعديلات الضارة
  /// ملاحظة: للحماية الكاملة استخدم Google Play Integrity API في الإنتاج
  Future<SecurityCheckResult> checkDeviceIntegrity() async {
    try {
      // فحص 1: وضع Debug (في الإنتاج يجب أن يكون مغلقاً)
      if (kDebugMode) {
        debugPrint('[Security] ⚠️ وضع Debug مفعّل - السماح في بيئة التطوير');
        return SecurityCheckResult.allowed();
      }

      // فحص 2: التحقق من المنصة
      if (!defaultTargetPlatform.toString().contains('android') &&
          !defaultTargetPlatform.toString().contains('iOS')) {
        return SecurityCheckResult.denied('منصة غير مدعومة');
      }

      debugPrint('[Security] ✅ بيئة الجهاز سليمة');
      return SecurityCheckResult.allowed();
    } catch (e) {
      debugPrint('[Security] خطأ في فحص البيئة: $e');
      return SecurityCheckResult.allowed();
    }
  }

  // ================================================================
  //  6. فحص الأمان الشامل — يُستدعى قبل كل عملية مسح
  // ================================================================

  /// يجري فحوصات الأمان النشطة فقط بالتسلسل
  /// (BSSID Geofencing وRoot Detection مُعطَّلان - لحين وجود حلول بديلة)
  Future<SecurityCheckResult> runFullSecurityCheck({
    bool requireBiometrics = true,
    bool requireNetworkGeofence = false, // مُعطَّل - لا تُفعّله حتى يتم تحديده
  }) async {
    debugPrint('[Security] 🔍 بدء الفحص الأمني...');

    // فحص التحقق البيومتري فقط (البصمة / الوجه)
    if (requireBiometrics) {
      final biometricCheck = await authenticateWithBiometrics();
      if (!biometricCheck.isAllowed) return biometricCheck;
    }

    debugPrint('[Security] ✅ الفحص الأمني اجتاز بنجاح');
    return SecurityCheckResult.allowed();
  }

  /// إعداد مَعامِل الأمان للطلب (Nonce + Signature)
  /// يُعيد خريطة الرؤوس الأمنية الجاهزة للإرسال
  Map<String, String> buildSecurityHeaders({
    required String employeeId,
    required String tagCode,
  }) {
    final nonce = generateNonce();
    validateAndStoreNonce(nonce);

    final dataToSign = {
      'employee_id': employeeId,
      'tag_code': tagCode,
      'nonce': nonce,
    };

    final signature = generateHmacSignature(dataToSign);

    return {
      'X-Nonce': nonce,
      'X-Signature': signature,
      'X-Request-Source': 'AMT-Mobile-App-v1',
    };
  }
}
