/// =====================================================
/// ملف: splash_screen.dart
/// الوصف: شاشة البداية (Splash Screen)
///        تُعرض عند فتح التطبيق مع انيميشن جميل
/// =====================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    // إعداد انيميشن النبض
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // إعداد انيميشن الدوران
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // الانتظار للأنيميشن
    await Future.delayed(const Duration(milliseconds: 3200));
    
    if (!mounted) return;
    
    final deviceId = await _storage.read(key: 'device_id');
    debugPrint('========= DEVICE ID CHECK =========');
    debugPrint('deviceId: $deviceId');
    
    if (deviceId != null && deviceId.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
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
        child: Stack(
          children: [
            // --- خلفية الجسيمات ---
            ..._buildBackgroundParticles(),

            // --- المحتوى الرئيسي ---
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- أيقونة NFC الرئيسية ---
                  _buildNfcIcon(),

                  const SizedBox(height: 40),

                  // --- اسم الشركة ---
                  Text(
                    'AMT',
                    style: const TextStyle(
                      
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 8,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  // --- الشعار الفرعي ---
                  Text(
                    'نظام تسجيل الحضور الذكي',
                    style: TextStyle(
                      
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 80),

                  // --- مؤشر التحميل ---
                  _buildLoadingIndicator()
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 600.ms),
                ],
              ),
            ),

            // --- رقم الإصدار ---
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'الإصدار 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ).animate().fadeIn(delay: 1200.ms),
            ),
          ],
        ),
      ),
    );
  }

  /// --- بناء أيقونة NFC المتحركة ---
  Widget _buildNfcIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // حلقات النبض الخارجية
            for (int i = 3; i >= 1; i--)
              Opacity(
                opacity: (1 - _pulseController.value) * (0.3 / i),
                child: Container(
                  width: 80.0 + (i * 40) * _pulseController.value,
                  height: 80.0 + (i * 40) * _pulseController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5 / i,
                    ),
                  ),
                ),
              ),

            // الدائرة الرئيسية
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.secondary.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.nfc_rounded,
                size: 60,
                color: AppColors.primary,
              ),
            ),
          ],
        );
      },
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1));
  }

  /// --- بناء مؤشر التحميل ---
  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: AppColors.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'جاري التهيئة...',
          style: TextStyle(
            
            fontSize: 13,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  /// --- بناء جسيمات الخلفية الزخرفية ---
  List<Widget> _buildBackgroundParticles() {
    return [
      Positioned(
        top: -50,
        right: -50,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.secondary.withOpacity(0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -80,
        left: -80,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
