/// =====================================================
/// ملف: home_screen.dart
/// الوصف: الشاشة الرئيسية للتطبيق - واجهة المستخدم
///        الكاملة مع زر المسح وعرض الحالة والسجلات
/// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/attendance_provider.dart';
import '../services/nfc_service.dart';
import '../services/admin_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/nfc_scan_button.dart';
import '../widgets/status_card.dart';
import '../widgets/history_tile.dart';
import 'leave_request_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;

  // متغيرات وضع الإدارة المخفي
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  @override
  void initState() {
    super.initState();

    // انيميشن الخلفية المتحركة
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- الهيدر (العنوان والمعلومات) ---
              _buildHeader(context),

              // --- بانر الأوفلاين (يظهر فقط عند وجود سجلات معلقة) ---
              Consumer<AttendanceProvider>(
                builder: (context, provider, _) {
                  if (provider.pendingOfflineCount == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${provider.pendingOfflineCount} سجل محفوظ أوفلاين — سيُرفع تلقائياً',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final count = await provider.syncOfflineRecords();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(count > 0
                                    ? 'تمت مزامنة $count سجل ✅'
                                    : 'لا يوجد إنترنت — حاول لاحقاً'),
                              ));
                            }
                          },
                          child: const Text('مزامنة الآن',
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // --- المحتوى القابل للتمرير ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // --- بطاقة الحالة ---
                      Consumer<AttendanceProvider>(
                        builder: (context, provider, _) {
                          return StatusCard(
                            state: provider.scanState,
                            message: provider.statusMessage,
                            lastCode: provider.lastReadCode,
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // --- أيقونة NFC الرئيسية وزر المسح ---
                      Consumer<AttendanceProvider>(
                        builder: (context, provider, _) {
                          return NfcScanButton(
                            scanState: provider.scanState,
                            onScan: () => _handleScanButton(context, provider),
                            onStop: () => provider.stopScan(),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // --- زر تقديم الإجازة ---
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          foregroundColor: Colors.blueAccent,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.blueAccent),
                          ),
                        ),
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('تقديم طلب إجازة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LeaveRequestScreen()),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // --- سجل الحضور ---
                      _buildHistorySection(context),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// --- بناء الهيدر ---
  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // --- الشعار والاسم ---
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleLogoTap,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نظام AMT للحضور',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // --- الساعة وأيقونة لوحة التحكم ---
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.dashboard_rounded, color: AppColors.primary),
                tooltip: 'لوحة التحكم',
                onPressed: () => Navigator.pushNamed(context, '/dashboard'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _buildLiveTime(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  /// --- ساعة حية تتحدث كل ثانية ---
  Widget _buildLiveTime() {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Text(
          DateFormat('HH:mm:ss').format(now),
          style: const TextStyle(
            
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        );
      },
    );
  }

  /// --- بناء قسم سجل الحضور ---
  Widget _buildHistorySection(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        final history = provider.attendanceHistory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'سجل العمليات',
                  style: TextStyle(
                    
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (history.isNotEmpty)
                  Text(
                    '${history.length} سجلات',
                    style: const TextStyle(
                      
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              _buildEmptyHistory()
            else
              ...history.asMap().entries.map((entry) {
                return HistoryTile(
                  data: entry.value,
                  index: entry.key,
                );
              }),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
      },
    );
  }

  /// --- حالة السجل الفارغ ---
  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد سجلات بعد',
            style: TextStyle(
              
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// --- معالجة الضغط على زر المسح ---
  Future<void> _handleScanButton(
    BuildContext context,
    AttendanceProvider provider,
  ) async {
    // التحقق من دعم NFC قبل البدء
    if (!provider.isNfcSupported) {
      _showSnackbar(
        context,
        'جهازك لا يدعم تقنية NFC',
        isError: true,
        icon: Icons.warning_rounded,
      );
      return;
    }

    // بدء المسح
    await provider.startScan();

    // مراقبة الحالة وعرض Snackbar مناسب
    if (context.mounted) {
      final state = provider.scanState;

      if (state == NfcScanState.error) {
        _showSnackbar(
          context,
          provider.statusMessage,
          isError: true,
          icon: Icons.error_outline_rounded,
        );
      } else if (state == NfcScanState.success) {
        _showSnackbar(
          context,
          'تم تسجيل الحضور بنجاح ✅',
          isError: false,
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  /// --- عرض Snackbar بتصميم مخصص ---
  void _showSnackbar(
    BuildContext context,
    String message, {
    required bool isError,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              icon,
              color: isError ? AppColors.error : AppColors.success,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError
                ? AppColors.error.withOpacity(0.5)
                : AppColors.success.withOpacity(0.5),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // 🔐 دوال وضع الإدارة المخفي (Hidden Admin Mode)
  // ==========================================

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap == null || now.difference(_lastLogoTap!).inSeconds > 2) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    _lastLogoTap = now;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _showAdminPinDialog();
    }
  }

  void _showAdminPinDialog() {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('وضع الإدارة', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'أدخل رمز PIN (1234)',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == '1234') {
                Navigator.pop(context);
                _showAddDoorDialog();
              } else {
                Navigator.pop(context);
                _showSnackbar(context, 'رمز غير صحيح', isError: true, icon: Icons.error);
              }
            },
            child: const Text('دخول', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAddDoorDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('إضافة بوابة جديدة', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'اسم البوابة (مثال: الباب الرئيسي)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'موقع البوابة (مثال: الدور الأول)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _startAssignNfcSession(nameController.text, locationController.text);
              }
            },
            child: const Text('التالي: مسح الشريحة', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _startAssignNfcSession(String doorName, String location) async {
    _showSnackbar(context, 'يرجى تمرير الشريحة لتعيينها...', isError: false, icon: Icons.nfc);
    
    await NfcService().startNfcSession(
      onSuccess: (result) async {
        if (result.tagCode == null) return;
        
        _showSnackbar(context, 'جاري ربط البوابة...', isError: false, icon: Icons.sync);
        
        final success = await AdminService.assignNewDoor(
          doorName: doorName,
          doorLocation: location,
          nfcUid: result.tagCode!,
          adminPin: '1234',
        );

        if (context.mounted) {
          if (success) {
            _showSnackbar(context, 'تمت إضافة البوابة بنجاح! ✅', isError: false, icon: Icons.check_circle);
          } else {
            _showSnackbar(context, 'فشل في إضافة البوابة', isError: true, icon: Icons.error);
          }
        }
      },
      onError: (msg) {
        if (context.mounted) {
          _showSnackbar(context, msg, isError: true, icon: Icons.error);
        }
      },
    );
  }
}
