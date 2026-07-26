import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'employee_management_screen.dart';
import 'attendance_screen.dart';
import 'schedules_screen.dart';
import 'leaves_screen.dart';
import 'onboarding_screen.dart';
import 'courses_screen.dart';
import 'login_screen.dart';

const _backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://attendance-yty9.onrender.com');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://oiyoeftvpwpiwovqqhum.supabase.co');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_gg37Prs1Z7HW9jKRIVnelQ_8M9Oiz8T');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لوحة تحكم AMT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00B4D8),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        fontFamily: 'Cairo',
      ),
      home: const AuthGate(),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}

// ─── بوابة المصادقة — تتحقق من حالة الدخول ────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// ─── الشاشة الرئيسية بعد الدخول ──────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CoursesScreen(),          // ✅ جديد
    const AttendanceScreen(),
    const EmployeeManagementScreen(),
    const OnboardingScreen(backendUrl: _backendUrl),
    const SchedulesScreen(backendUrl: _backendUrl),
    const LeavesScreen(backendUrl: _backendUrl),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ─ القائمة الجانبية ─
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              border: Border(right: BorderSide(color: Color(0xFF1A2B4A), width: 1)),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Color(0xFF00B4D8)),
              unselectedIconTheme: const IconThemeData(color: Colors.white38),
              selectedLabelTextStyle: GoogleFonts.cairo(color: const Color(0xFF00B4D8), fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelTextStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 11),
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Column(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF00B4D8), Color(0xFF0077B6)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.4), blurRadius: 12)]),
                    child: const Icon(Icons.nfc, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text('AMT', style: GoogleFonts.cairo(color: const Color(0xFF00B4D8), fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white38),
                  tooltip: 'تسجيل الخروج',
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('الإحصائيات')),
                NavigationRailDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: Text('الدورات')),
                NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: Text('الحضور')),
                NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('المتدربون')),
                NavigationRailDestination(icon: Icon(Icons.app_registration_outlined), selectedIcon: Icon(Icons.app_registration), label: Text('التسجيل')),
                NavigationRailDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: Text('الجداول')),
                NavigationRailDestination(icon: Icon(Icons.beach_access_outlined), selectedIcon: Icon(Icons.beach_access), label: Text('الإجازات')),
              ],
            ),
          ),
          // ─ المحتوى ─
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}

// ─── شاشة الإحصائيات الرئيسية ────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/api/dashboard/stats')).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        setState(() { _stats = jsonDecode(resp.body); _loading = false; });
      } else {
        setState(() { _error = 'فشل التحميل (${resp.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'تعذّر الاتصال بالسيرفر'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8)))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 60),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.cairo(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)), child: Text('إعادة المحاولة', style: GoogleFonts.cairo())),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مرحباً 👋  لوحة التحكم الرئيسية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('إليك نظرة عامة على النظام اليوم', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 14)),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16, runSpacing: 16,
                        children: [
                          _statCard('إجمالي المتدربين', '${_stats?['total_employees'] ?? 0}', Icons.people, const Color(0xFF00B4D8)),
                          _statCard('حضور اليوم', '${_stats?['today_attendance'] ?? 0}', Icons.how_to_reg, const Color(0xFF2ECC71)),
                          _statCard('إجمالي البوابات', '${_stats?['total_doors'] ?? 0}', Icons.door_sliding_outlined, const Color(0xFFFFC300)),
                          _statCard('الدورات النشطة', '${_stats?['total_courses'] ?? 0}', Icons.school, const Color(0xFF9B59B6)),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 200, height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2340),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}
