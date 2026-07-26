/// =====================================================
/// ملف: attendance_provider.dart
/// الوصف: مزود حالة التطبيق (State Management)
///        يربط خدمة NFC بخدمة API ويُحدّث واجهة المستخدم
/// =====================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/nfc_service.dart';
import '../services/api_service.dart';
import '../services/security_service.dart';
import '../services/offline_sync_service.dart';

/// --- حالة التطبيق الكاملة ---
/// هذا الكلاس يحتوي على كل البيانات التي تحتاجها الواجهة
class AttendanceProvider extends ChangeNotifier {
  // الخدمات المستخدمة
  final NfcService _nfcService = NfcService();
  final ApiService _apiService = ApiService();
  final SecurityService _securityService = SecurityService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  String _deviceId = ''; // جهاز المستخدم (Device Binding ID)

  // --- التخزين الآمن المشفر (Android Keystore) ---
  // يحل ثغرة #7: لا يمكن قراءة البيانات حتى مع Root
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // --- حالة NFC ---
  NfcScanState _scanState = NfcScanState.idle;
  NfcScanState get scanState => _scanState;

  // --- رسالة الحالة للمستخدم ---
  String _statusMessage = 'اضغط على زر البدء لتسجيل حضورك';
  String get statusMessage => _statusMessage;

  // --- آخر كود تم قراءته ---
  String? _lastReadCode;
  String? get lastReadCode => _lastReadCode;

  // --- آخر استجابة من السيرفر ---
  AttendanceResponse? _lastResponse;
  AttendanceResponse? get lastResponse => _lastResponse;

  // --- معرف الموظف ---
  String _employeeId = 'emp_105'; // افتراضي - يُحمَّل من SharedPreferences
  String get employeeId => _employeeId;

  // --- هل يجري الإرسال للسيرفر؟ ---
  bool _isSendingToServer = false;
  bool get isSendingToServer => _isSendingToServer;

  // --- هل NFC مدعوم؟ ---
  bool _isNfcSupported = true;
  bool get isNfcSupported => _isNfcSupported;

  // --- عدد السجلات المعلقة (Offline) ---
  int _pendingOfflineCount = 0;
  int get pendingOfflineCount => _pendingOfflineCount;

  // --- سجل العمليات (آخر 10 تسجيلات) ---
  final List<Map<String, dynamic>> _attendanceHistory = [];
  List<Map<String, dynamic>> get attendanceHistory =>
      List.unmodifiable(_attendanceHistory);

  /// --- مُنشئ الكلاس ---
  AttendanceProvider() {
    _initialize();
  }

  /// --- التهيئة الأولية ---
  Future<void> _initialize() async {
    // تحميل معرف الموظف المحفوظ
    await _loadEmployeeId();

    // التحقق من دعم NFC
    await _checkNfcSupport();

    // تهيئة خدمة الأوفلاين والمزامنة التلقائية
    await _offlineSync.initialize();
    await _refreshPendingCount();
  }

  /// --- تحديث عداد السجلات المعلقة ---
  Future<void> _refreshPendingCount() async {
    _pendingOfflineCount = await _offlineSync.getPendingCount();
    notifyListeners();
  }

  /// --- مزامنة يدوية (يستدعيها المستخدم) ---
  Future<int> syncOfflineRecords() async {
    final count = await _offlineSync.syncPendingRecords();
    await _refreshPendingCount();
    return count;
  }

  /// --- تحميل معرف الموظف من التخزين الآمن (Android Keystore) ---
  Future<void> _loadEmployeeId() async {
    try {
      final storedId = await _secureStorage.read(key: 'emp_id');
      _employeeId = storedId ?? 'emp_105';
      // ✅ تحميل device_id للتحقق من التضارب عند السينك
      _deviceId = await _secureStorage.read(key: 'device_id') ?? '';
      debugPrint('[Provider] 🔑 تم تحميل معرف الموظف: $_employeeId | device: $_deviceId');
      notifyListeners();
    } catch (e) {
      debugPrint('[Provider] خطأ في تحميل معرف الموظف: $e');
    }
  }

  /// --- حفظ معرف الموظف في التخزين الآمن (Android Keystore) ---
  Future<void> saveEmployeeId(String id) async {
    try {
      // حفظ في Keystore المشفر — لا يمكن قراءته حتى مع Root
      await _secureStorage.write(key: 'emp_id', value: id);
      _employeeId = id;
      debugPrint('[Provider] 🔑 تم حفظ معرف الموظف في Keystore: $id');
      notifyListeners();
    } catch (e) {
      debugPrint('[Provider] خطأ في حفظ معرف الموظف: $e');
    }
  }

  /// --- التحقق من دعم NFC ---
  Future<void> _checkNfcSupport() async {
    final state = await _nfcService.checkNfcAvailability();

    if (state == NfcScanState.unsupported) {
      _isNfcSupported = false;
      _scanState = NfcScanState.unsupported;
      _statusMessage = 'جهازك لا يدعم تقنية NFC';
      notifyListeners();
    } else if (state == NfcScanState.disabled) {
      _scanState = NfcScanState.disabled;
      _statusMessage = 'يرجى تفعيل NFC من إعدادات الجهاز';
      notifyListeners();
    }
  }

  /// --- بدء عملية المسح (الدالة الرئيسية) ---
  /// تُستدعى عند ضغط المستخدم على زر "ابدأ المسح"
  Future<void> startScan() async {
    // التحقق من أن NFC مدعوم
    if (!_isNfcSupported) {
      _statusMessage = 'جهازك لا يدعم تقنية NFC';
      notifyListeners();
      return;
    }

    // تجنب بدء جلسة جديدة إذا كانت هناك جلسة جارية
    if (_scanState == NfcScanState.scanning) return;

    // تحديث الحالة إلى "جاري الفحص"
    _updateState(
      state: NfcScanState.scanning,
      message: 'يرجى تقريب الهاتف من بوابة NFC...',
    );

    // بدء جلسة NFC
    await _nfcService.startNfcSession(
      // --- عند نجاح القراءة ---
      onSuccess: (NfcReadResult result) async {
        _lastReadCode = result.tagCode;

        // ==============================================
        // 🔐 الفحص الأمني الشامل (تأكيد الهوية بعد قراءة الباب)
        // ==============================================
        _updateState(
          state: NfcScanState.scanning,
          message: '🔐 يرجى تأكيد هويتك...',
        );

        final securityResult = await _securityService.runFullSecurityCheck(
          requireBiometrics: true,
          requireNetworkGeofence: false, // غيّره لـ true عند إضافة BSSID الشركة
        );

        if (!securityResult.isAllowed) {
          _updateState(
            state: NfcScanState.error,
            message: '🚫 ${securityResult.reason}',
          );
          return;
        }
        // ==============================================

        _updateState(
          state: NfcScanState.scanning,
          message: 'جاري تسجيل الحضور...',
        );

        // إرسال البيانات للسيرفر
        await _sendAttendanceToServer(result.tagCode!);
      },

      // --- عند حدوث خطأ في القراءة ---
      onError: (String errorMessage) {
        _updateState(
          state: NfcScanState.error,
          message: errorMessage,
        );
      },
    );
  }

  /// --- إرسال بيانات الحضور (أونلاين أو أوفلاين) ---
  Future<void> _sendAttendanceToServer(String tagCode) async {
    _isSendingToServer = true;
    notifyListeners();

    // محاولة الإرسال المباشر
    final response = await _apiService.sendAttendance(
      tagCode: tagCode,
      employeeId: _employeeId,
      deviceId: _deviceId,    // ✅ إرسال معرف الجهاز للتحقق من عدم التضارب
    );

    _lastResponse = response;
    _isSendingToServer = false;

    // ── نجاح أونلاين ───────────────────────────────────
    if (response.isSuccess) {
      _updateState(
        state: NfcScanState.success,
        message: '✅ ${response.message}',
      );
      _addToHistory(tagCode, response);
      Future.delayed(const Duration(seconds: 4), resetToIdle);
      return;
    }

    // ── فشل بسبب انقطاع الإنترنت؟ → حفظ أوفلاين ──────
    final isNetworkError = response.message.contains('إنترنت') ||
        response.message.contains('اتصال') ||
        response.message.contains('Timeout') ||
        response.message.contains('انتهت مهلة') ||
        response.message.toLowerCase().contains('socketexception') ||
        response.message.toLowerCase().contains('clientexception') ||
        response.message.toLowerCase().contains('failed host lookup') ||
        response.message.contains('غير متوقع');

    if (isNetworkError) {
      await _offlineSync.saveLocally(
        tagCode: tagCode,
        employeeId: _employeeId,
        deviceId: _deviceId,    // ✅ حفظ device_id مع كل سجل أوفلاين
      );
      await _refreshPendingCount();

      _updateState(
        state: NfcScanState.success,
        message: '📶 تم الحفظ محلياً — سيُرفع فور عودة الإنترنت',
      );
      _addToHistory(tagCode, AttendanceResponse(
        isSuccess: true,
        message: 'محفوظ أوفلاين',
        timestamp: DateTime.now(),
        attendanceType: 'غير محدد',
      ));
      Future.delayed(const Duration(seconds: 4), resetToIdle);
      return;
    }

    // ── فشل لسبب آخر ───────────────────────────────────
    _updateState(
      state: NfcScanState.error,
      message: '❌ ${response.message}',
    );
  }

  /// --- إيقاف المسح يدوياً ---
  Future<void> stopScan() async {
    await _nfcService.stopNfcSession();
    resetToIdle();
  }

  /// --- إعادة التهيئة للحالة الخاملة ---
  void resetToIdle() {
    _updateState(
      state: NfcScanState.idle,
      message: 'اضغط على زر البدء لتسجيل حضورك',
    );
  }

  /// --- إضافة سجل للتاريخ ---
  void _addToHistory(String tagCode, AttendanceResponse response) {
    _attendanceHistory.insert(0, {
      'tag_code': tagCode,
      'employee_id': _employeeId,
      'timestamp': DateTime.now(),
      'success': response.isSuccess,
      'message': response.message,
      'attendance_type': response.attendanceType ?? 'دخول',
    });

    // الاحتفاظ بآخر 10 سجلات فقط
    if (_attendanceHistory.length > 10) {
      _attendanceHistory.removeRange(10, _attendanceHistory.length);
    }
  }

  /// --- دالة مساعدة لتحديث الحالة وإشعار المستمعين ---
  void _updateState({
    required NfcScanState state,
    required String message,
  }) {
    _scanState = state;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    // إيقاف جلسة NFC عند التخلص من المزود
    _nfcService.stopNfcSession();
    super.dispose();
  }
}
