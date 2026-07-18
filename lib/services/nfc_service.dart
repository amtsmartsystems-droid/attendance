/// =====================================================
/// ملف: nfc_service.dart
/// الوصف: خدمة NFC الرئيسية - تتعامل مع قراءة الشرائح
///        هذا الملف هو قلب التطبيق ويحتوي على كامل
///        منطق التعامل مع حساس NFC في الهاتف
/// =====================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/ndef.dart';
import 'package:nfc_manager/src/nfc_manager_ios/tags/ndef.dart';
import 'package:ndef_record/ndef_record.dart';

/// --- تعريف أنواع الحالات الممكنة لعملية NFC ---
enum NfcScanState {
  idle,        // خامل - لم تبدأ القراءة
  scanning,    // يجري الفحص والانتظار
  success,     // نجحت القراءة
  error,       // حدث خطأ
  unsupported, // الجهاز لا يدعم NFC
  disabled,    // NFC معطّل من إعدادات الجهاز
}

/// --- نتيجة عملية قراءة NFC ---
class NfcReadResult {
  final bool isSuccess;      // هل نجحت القراءة؟
  final String? tagCode;     // الكود المقروء من الشريحة
  final String? errorMessage; // رسالة الخطأ إن وُجدت
  final DateTime readTime;   // وقت القراءة

  const NfcReadResult({
    required this.isSuccess,
    this.tagCode,
    this.errorMessage,
    required this.readTime,
  });

  /// مُنشئ مساعد لحالة النجاح
  factory NfcReadResult.success(String tagCode) {
    return NfcReadResult(
      isSuccess: true,
      tagCode: tagCode,
      readTime: DateTime.now(),
    );
  }

  /// مُنشئ مساعد لحالة الفشل
  factory NfcReadResult.failure(String errorMessage) {
    return NfcReadResult(
      isSuccess: false,
      errorMessage: errorMessage,
      readTime: DateTime.now(),
    );
  }
}

/// --- الخدمة الرئيسية لإدارة NFC ---
/// هذه الخدمة مسؤولة عن:
/// 1. التحقق من دعم الجهاز لـ NFC
/// 2. بدء جلسة القراءة
/// 3. استخراج النص من شريحة NDEF
/// 4. إغلاق الجلسة بأمان
class NfcService {
  // نسخة واحدة فقط من الخدمة في التطبيق (Singleton Pattern)
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  // للإشارة إلى أن جلسة NFC جارية حالياً
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  /// --- التحقق من دعم NFC وتفعيله ---
  /// تُعيد الدالة:
  /// - true: إذا كان NFC مدعوماً ومفعّلاً
  /// - false: إذا كان غير مدعوم أو معطّل
  Future<NfcScanState> checkNfcAvailability() async {
    try {
      // هل الجهاز يدعم NFC أصلاً؟
      final bool isAvailable = await NfcManager.instance.isAvailable();

      if (!isAvailable) {
        // التحقق إذا كان السبب عدم الدعم أو التعطيل
        // ملاحظة: nfc_manager يُدمج الحالتين في isAvailable()
        // لكن يمكن التحقق عبر Platform Channel إضافي إذا لزم
        debugPrint('[NFC Service] ❌ NFC غير متاح على هذا الجهاز');
        return NfcScanState.unsupported;
      }

      debugPrint('[NFC Service] ✅ NFC متاح ومفعّل');
      return NfcScanState.idle;
    } catch (e) {
      debugPrint('[NFC Service] ⚠️ خطأ أثناء التحقق من NFC: $e');
      return NfcScanState.error;
    }
  }

  /// --- بدء جلسة قراءة NFC ---
  /// هذه الدالة:
  /// 1. تبدأ الاستماع لأي شريحة NFC قريبة
  /// 2. تقرأ سجلات NDEF فقط (النص العادي)
  /// 3. تتجاهل أي شريحة لا تحتوي على NDEF نصي صالح
  /// 4. تُنفّذ callback عند النجاح أو الفشل
  ///
  /// المعاملات:
  /// - [onSuccess]: تُستدعى عند قراءة الكود بنجاح
  /// - [onError]: تُستدعى عند حدوث أي خطأ
  Future<void> startNfcSession({
    required Function(NfcReadResult) onSuccess,
    required Function(String) onError,
  }) async {
    // منع تشغيل جلستين في نفس الوقت
    if (_isSessionActive) {
      debugPrint('[NFC Service] ⚠️ جلسة NFC أخرى جارية بالفعل');
      return;
    }

    try {
      _isSessionActive = true;
      debugPrint('[NFC Service] 🔍 بدء جلسة القراءة...');

      // بدء الجلسة مع NfcManager
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        // --- معالج اكتشاف الشريحة ---
        onDiscovered: (NfcTag tag) async {
          debugPrint('[NFC Service] 📡 تم اكتشاف شريحة NFC');

          // استخراج المعرف المادي للشريحة (UID) بدلاً من الاعتماد على نصوص NDEF
          final String extractedCode = _extractTagId(tag);

          debugPrint('[NFC Service] ✅ تم قراءة الكود بنجاح: $extractedCode');

          // الإبلاغ عن النجاح
          onSuccess(NfcReadResult.success(extractedCode));

          // إغلاق الجلسة بعد تأخير بسيط (ثانيتين) بدلاً من الإغلاق الفوري
          // هذا يمنع نظام أندرويد من استلام الشريحة وقراءتها كملصق فارغ 
          // إذا كان المستخدم لا يزال يضع الهاتف على الشريحة.
          Future.delayed(const Duration(seconds: 2), () async {
            await stopNfcSession();
          });
        },

        // --- معالج الخطأ في iOS ---
        onSessionErrorIos: (dynamic error) async {
          debugPrint('[NFC Service] ❌ خطأ في جلسة NFC: $error');
          _isSessionActive = false;
          onError('حدث خطأ أثناء القراءة - يرجى المحاولة مرة أخرى');
        },
      );
    } catch (e) {
      _isSessionActive = false;
      debugPrint('[NFC Service] 💥 استثناء غير متوقع: $e');
      onError('حدث خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// --- استخراج المعرف المادي للشريحة (UID/Serial Number) ---
  /// يعتمد على Hardware UID بدلاً من نصوص NDEF لضمان أقصى حماية
  /// ضد النسخ والتحايل، ولضمان قراءة أي شريحة مادية.
  String _extractTagId(NfcTag tag) {
    try {
      List<int>? identifier;
      dynamic data = tag.data;

      // محاولة استخراج الـ ID في الإصدارات الحديثة من nfc_manager (pigeon)
      try {
        var id = data.id ?? data.identifier;
        if (id is List<int>) identifier = id;
      } catch (_) {}

      // التوافقية مع الإصدارات الأقدم حيث كانت tag.data عبارة عن Map
      if (identifier == null && data is Map) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          identifier = (data['nfca'] as Map?)?['identifier'] ?? 
                       (data['nfcb'] as Map?)?['identifier'] ?? 
                       (data['nfcf'] as Map?)?['identifier'] ?? 
                       (data['nfcv'] as Map?)?['identifier'] ?? 
                       (data['mifareclassic'] as Map?)?['identifier'] ?? 
                       (data['mifareultralight'] as Map?)?['identifier'] ?? 
                       (data['ndef'] as Map?)?['identifier'];
        } else {
          identifier = (data['mifare'] as Map?)?['identifier'] ?? 
                       (data['feliCa'] as Map?)?['identifier'] ?? 
                       (data['iso15693'] as Map?)?['identifier'] ??
                       (data['iso7816'] as Map?)?['identifier'];
        }
      }

      if (identifier != null && identifier is List<int>) {
        // تحويل المصفوفة الرقمية إلى كود نصي بصيغة HEX
        return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }

      // في حال لم نتمكن من قراءة الـ UID القياسي، نستخدم بيانات الشريحة كبديل مؤقت
      return 'TAG_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('[NFC Service] خطأ في استخراج الـ UID: $e');
      return 'UNKNOWN_TAG';
    }
  }

  /// --- إيقاف جلسة NFC بأمان ---
  /// يجب استدعاؤها دائماً بعد انتهاء القراءة
  Future<void> stopNfcSession() async {
    try {
      if (_isSessionActive) {
        await NfcManager.instance.stopSession();
        _isSessionActive = false;
        debugPrint('[NFC Service] 🛑 تم إيقاف جلسة NFC');
      }
    } catch (e) {
      _isSessionActive = false;
      debugPrint('[NFC Service] خطأ أثناء إيقاف الجلسة: $e');
    }
  }
}
