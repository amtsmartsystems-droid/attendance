/// =====================================================
/// ملف: api_service.dart
/// الوصف: خدمة API - تتواصل مع Supabase Edge Function
///        لتسجيل الحضور بأعلى مستويات الأمان
/// =====================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'security_service.dart';
import '../core/config/app_config.dart';

/// =====================================================
/// ✅ الإعدادات تأتي من AppConfig (محقونة وقت البناء)
/// =====================================================
class SupabaseConfig {
  static String get url => AppConfig.supabaseUrl;
  static String get anonKey => AppConfig.supabaseAnonKey;
  static String get attendanceEndpoint => AppConfig.attendanceEndpoint;
}

/// --- نموذج استجابة السيرفر ---
class AttendanceResponse {
  final bool isSuccess;
  final String message;
  final String? attendanceId;
  final String? attendanceType;
  final DateTime timestamp;

  const AttendanceResponse({
    required this.isSuccess,
    required this.message,
    this.attendanceId,
    this.attendanceType,
    required this.timestamp,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      isSuccess:      json['success'] as bool? ?? false,
      message:        json['message'] as String? ?? 'استجابة غير معروفة',
      attendanceId:   json['attendance_id'] as String?,
      attendanceType: json['attendance_type'] as String?,
      // ⭐ نستخدم وقت السيرفر المُعاد من Supabase
      timestamp: DateTime.tryParse(json['server_time'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory AttendanceResponse.error(String msg) => AttendanceResponse(
        isSuccess: false,
        message: msg,
        timestamp: DateTime.now(),
      );
}

/// --- خدمة API الرئيسية ---
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const Duration _timeout = Duration(seconds: 15);

  /// التحقق من الاتصال بالإنترنت
  Future<bool> hasInternetConnection() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (res == ConnectivityResult.none) return false;
      final lookup = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 5));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// --- إرسال بيانات الحضور إلى Supabase Edge Function ---
  Future<AttendanceResponse> sendAttendance({
    required String tagCode,
    required String employeeId,
    String? deviceId,            // ⭐ device_id لكشف التضارب عند السينك
    DateTime? offlineTimestamp,
  }) async {
    // 1. فحص الاتصال
    if (!await hasInternetConnection()) {
      return AttendanceResponse.error(
        'لا يوجد اتصال بالإنترنت — يرجى التحقق من الاتصال',
      );
    }

    // 2. بناء رؤوس الأمان (HMAC + Nonce) من SecurityService
    final secHeaders = SecurityService().buildSecurityHeaders(
      employeeId: employeeId,
      tagCode: tagCode,
    );

    debugPrint('[API] 📤 إرسال إلى Supabase Edge Function');
    debugPrint('[API]   - الموظف: $employeeId');
    debugPrint('[API]   - UID: $tagCode');
    debugPrint('[API]   - Nonce: ${secHeaders['X-Nonce']}');
    if (offlineTimestamp != null) {
      debugPrint('[API]   - Offline Timestamp: $offlineTimestamp');
    }

    try {
      // ⭐ بناء جسم الطلب — نُضيف offline_timestamp إذا كانت أوفلاين
      final body = <String, dynamic>{
        'emp_id':       employeeId,
        'door_nfc_uid': tagCode,
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        body['device_id'] = deviceId;  // ✅ لكشف التضارب في السيرفر
      }
      if (offlineTimestamp != null) {
        body['offline_timestamp'] = offlineTimestamp.toIso8601String();
        body['is_offline_sync'] = true;
      }

      final response = await http
          .post(
            Uri.parse(SupabaseConfig.attendanceEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              // رؤوس الأمان
              'X-Nonce':          secHeaders['X-Nonce']!,
              'X-Signature':      secHeaders['X-Signature']!,
              'X-Request-Source': 'AMT-Mobile-App-v1',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);


      debugPrint('[API] 📥 الاستجابة: ${response.statusCode}');
      debugPrint('[API]   Body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      switch (response.statusCode) {
        case 200:
          return AttendanceResponse.fromJson(data);
        case 401:
          return AttendanceResponse.error('توقيع الطلب غير صالح');
        case 404:
          return AttendanceResponse.error(
              (data['message'] ?? 'الباب أو الموظف غير موجود') + '\n\nكود بطاقتك هو: $tagCode\n(يرجى إضافته في لوحة تحكم Supabase)');
        case 409:
          return AttendanceResponse.error(
              data['message'] ?? 'طلب مكرر');
        case 429:
          return AttendanceResponse.error(
              data['message'] ?? 'تم التسجيل مؤخراً — انتظر دقيقة');
        default:
          return AttendanceResponse.error(
              data['message'] ?? 'خطأ (${response.statusCode})');
      }
    } on TimeoutException {
      return AttendanceResponse.error('انتهت مهلة الاتصال — السيرفر لا يستجيب');
    } on SocketException {
      return AttendanceResponse.error('فشل الاتصال — تحقق من الإنترنت');
    } catch (e) {
      debugPrint('[API] خطأ: $e');
      return AttendanceResponse.error('خطأ في الاتصال بالشبكة: ${e.toString()}');
    }
  }
}
