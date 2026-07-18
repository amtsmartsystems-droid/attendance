/// =====================================================
/// ملف: main.dart
/// الوصف: نقطة البداية الرئيسية للتطبيق
/// المطور: فريق AMT
/// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/attendance_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة بيانات التاريخ واللغات
  await initializeDateFormatting('ar', null);

  // ⭐ تهيئة Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E21),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AMTAttendanceApp());
}

/// الكلاس الرئيسي للتطبيق
class AMTAttendanceApp extends StatelessWidget {
  const AMTAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // توفير مزودات الحالة لكامل شجرة الـ Widget
      providers: [
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        title: 'نظام AMT للحضور',
        debugShowCheckedModeBanner: false,

        // تطبيق السمة (Theme) المخصصة للتطبيق
        theme: AppTheme.darkTheme,

        // الشاشة الأولى هي شاشة البداية (Splash)
        home: const SplashScreen(),

        // تعريف المسارات داخل التطبيق
        routes: {
          '/home':      (context) => const HomeScreen(),
          '/splash':    (context) => const SplashScreen(),
          '/dashboard': (context) => const AdminDashboardScreen(),
          '/login':     (context) => const LoginScreen(),
          '/qr_scanner':(context) => const QRScannerScreen(),
        },

        // دعم اللغة العربية من اليمين لليسار
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
      ),
    );
  }
}
