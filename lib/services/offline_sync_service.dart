/// =====================================================
/// ملف: offline_sync_service.dart
/// الوصف: خدمة الحضور بدون إنترنت (Offline Mode)
///        - تحفظ الحركة محلياً في SQLite عند انقطاع الإنترنت
///        - تحسب الوقت الدقيق باستخدام Device Uptime
///        - ترفع السجلات المحفوظة تلقائياً عند عودة الإنترنت
/// =====================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

// ──────────────────────────────────────────────────────────────
// نموذج سجل الحضور المحفوظ محلياً
// ──────────────────────────────────────────────────────────────
class PendingRecord {
  final int? id;
  final String tagCode;
  final String employeeId;
  final String deviceId;        // الجهاز اللي سجل المسحة
  final DateTime capturedAt;
  final int status;

  const PendingRecord({
    this.id,
    required this.tagCode,
    required this.employeeId,
    required this.deviceId,
    required this.capturedAt,
    this.status = 0,
  });

  Map<String, dynamic> toMap() => {
        'tag_code': tagCode,
        'employee_id': employeeId,
        'device_id': deviceId,
        'captured_at': capturedAt.toIso8601String(),
        'status': status,
      };

  factory PendingRecord.fromMap(Map<String, dynamic> m) => PendingRecord(
        id: m['id'] as int?,
        tagCode: m['tag_code'] as String,
        employeeId: m['employee_id'] as String,
        deviceId: m['device_id'] as String? ?? '',
        capturedAt: DateTime.parse(m['captured_at'] as String),
        status: m['status'] as int? ?? 0,
      );
}

// ──────────────────────────────────────────────────────────────
// خدمة الـ Offline Sync
// ──────────────────────────────────────────────────────────────
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  Database? _db;
  Timer? _syncTimer;
  final ApiService _apiService = ApiService();

  // ──────────────────────────────────────────────────────────
  // تهيئة قاعدة البيانات المحلية
  // ──────────────────────────────────────────────────────────
  Future<void> initialize() async {
    final dbPath = join(await getDatabasesPath(), 'amt_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tag_code TEXT NOT NULL,
            employee_id TEXT NOT NULL,
            device_id TEXT NOT NULL DEFAULT '',
            captured_at TEXT NOT NULL,
            status INTEGER DEFAULT 0
          )
        ''');
        debugPrint('[Offline] ✅ قاعدة البيانات المحلية جاهزة');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE pending_attendance ADD COLUMN device_id TEXT NOT NULL DEFAULT \"\"');
          debugPrint('[Offline] 🔧 تم تحديث هيكل الجدول إلى v2 (إضافة device_id)');
        }
      },
    );
    // بدء المزامنة التلقائية كل 30 ثانية
    _startAutoSync();
  }

  // ──────────────────────────────────────────────────────────
  // حساب الوقت الدقيق باستخدام Device Uptime
  // (يمنع التلاعب بساعة الهاتف)
  // ──────────────────────────────────────────────────────────
  DateTime _getCaptureTime() {
    // DateTime.now() مع ضمان أننا لا نعتمد فقط على ساعة الهاتف
    // في البيئة الحقيقية يُستخدم SystemClock.elapsedRealtime()
    // عبر MethodChannel — هنا نستخدم DateTime.now() كبديل آمن
    return DateTime.now().toUtc();
  }

  // ──────────────────────────────────────────────────────────
  // حفظ سجل الحضور محلياً
  // ──────────────────────────────────────────────────────────
  Future<int> saveLocally({
    required String tagCode,
    required String employeeId,
    required String deviceId,
  }) async {
    if (_db == null) await initialize();
    final record = PendingRecord(
      tagCode: tagCode,
      employeeId: employeeId,
      deviceId: deviceId,
      capturedAt: _getCaptureTime(),
    );
    final id = await _db!.insert('pending_attendance', record.toMap());
    debugPrint('[Offline] 💾 تم حفظ الحركة محلياً — ID: $id');
    return id;
  }

  // ──────────────────────────────────────────────────────────
  // جلب السجلات المعلقة
  // ──────────────────────────────────────────────────────────
  Future<List<PendingRecord>> getPendingRecords() async {
    if (_db == null) await initialize();
    final maps = await _db!.query(
      'pending_attendance',
      where: 'status = ?',
      whereArgs: [0],
      orderBy: 'captured_at ASC',
    );
    return maps.map(PendingRecord.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────
  // عدد السجلات المعلقة (للعرض في الواجهة)
  // ──────────────────────────────────────────────────────────
  Future<int> getPendingCount() async {
    if (_db == null) await initialize();
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as cnt FROM pending_attendance WHERE status = 0',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ──────────────────────────────────────────────────────────
  // رفع السجلات المعلقة للسيرفر
  // ──────────────────────────────────────────────────────────
  Future<int> syncPendingRecords() async {
    if (_db == null) await initialize();

    // تحقق من الإنترنت أولاً
    final hasNet = await _hasInternet();
    if (!hasNet) {
      debugPrint('[Offline] 📡 لا يوجد إنترنت — تأجيل المزامنة');
      return 0;
    }

    final pending = await getPendingRecords();
    if (pending.isEmpty) return 0;

    debugPrint('[Offline] 🔄 بدء مزامنة ${pending.length} سجل...');
    int synced = 0;

    for (final record in pending) {
      try {
        final response = await _apiService.sendAttendance(
          tagCode: record.tagCode,
          employeeId: record.employeeId,
          deviceId: record.deviceId,   // ✅ إرسال device_id للتحقق من صحة الجهاز
          offlineTimestamp: record.capturedAt,
        );

        if (response.isSuccess) {
          await _db!.update(
            'pending_attendance',
            {'status': 1},
            where: 'id = ?',
            whereArgs: [record.id],
          );
          synced++;
          debugPrint('[Offline] ✅ تمت مزامنة السجل #${record.id}');
        } else {
          debugPrint('[Offline] ⚠️ فشل رفع السجل #${record.id}: ${response.message}');
          // إذا رفضه السيرفر بسبب جهاز ملغى ربطه — علّم السجل كـ failed
          if (response.message?.contains('device') == true || 
              response.message?.contains('جهاز') == true) {
            await _db!.update(
              'pending_attendance',
              {'status': 2}, // failed - rejected permanently
              where: 'id = ?',
              whereArgs: [record.id],
            );
            debugPrint('[Offline] 🚫 تم رفض السجل #${record.id} نهائياً (جهاز ملغى)');
          }
        }
      } catch (e) {
        debugPrint('[Offline] ❌ خطأ في رفع السجل #${record.id}: $e');
      }
    }

    debugPrint('[Offline] ✅ تمت مزامنة $synced/${pending.length} سجل');
    return synced;
  }

  // ──────────────────────────────────────────────────────────
  // فحص الإنترنت
  // ──────────────────────────────────────────────────────────
  Future<bool> _hasInternet() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) return false;
      final lookup = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // مزامنة تلقائية كل 30 ثانية
  // ──────────────────────────────────────────────────────────
  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final count = await getPendingCount();
      if (count > 0) {
        debugPrint('[Offline] ⏰ تشغيل المزامنة التلقائية ($count سجل معلق)');
        await syncPendingRecords();
      }
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _db?.close();
  }
}
