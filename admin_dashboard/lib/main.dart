import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'employee_management_screen.dart';
import 'attendance_screen.dart';
import 'schedules_screen.dart';
import 'leaves_screen.dart';

void main() {
  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لوحة تحكم AMT',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF0B101E),
        fontFamily: 'Cairo',
      ),
      home: const MainScreen(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const AttendanceScreen(),
    const EmployeeManagementScreen(),
    const SchedulesScreen(backendUrl: 'https://attendance-yty9.onrender.com'),
    const LeavesScreen(backendUrl: 'https://attendance-yty9.onrender.com'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF162032),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00E5FF)),
                label: Text('الإحصائيات'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check, color: Color(0xFF00E5FF)),
                label: Text('سجل الحضور'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: Color(0xFF00E5FF)),
                label: Text('الموظفين'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule, color: Color(0xFF00E5FF)),
                label: Text('الجداول'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_ind_outlined),
                selectedIcon: Icon(Icons.assignment_ind, color: Color(0xFF00E5FF)),
                label: Text('الإجازات'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF2C3E50)),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String apiUrl = 'http://localhost:8000/api';
  bool isLoading = true;
  Map<String, dynamic>? stats;
  List<dynamic>? attendanceLogs;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final statsRes = await http.get(Uri.parse('$apiUrl/stats'));
      final logsRes = await http.get(Uri.parse('$apiUrl/attendance'));

      if (statsRes.statusCode == 200 && logsRes.statusCode == 200) {
        setState(() {
          stats = jsonDecode(statsRes.body)['data'];
          attendanceLogs = jsonDecode(logsRes.body)['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  void exportExcel() {
    // Open the backend URL to download the file directly in the browser
    html.window.open('$apiUrl/reports/excel', 'Download');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم إدارة الحضور', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF162032),
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                    child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('أحمد محمد تأخر عن الدوام | محمد علي قدم طلب إجازة')),
              );
            },
            tooltip: 'الإشعارات',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: 'تحديث البيانات',
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard('إجمالي الموظفين', stats?['total_employees']?.toString() ?? '0', Icons.people),
                      const SizedBox(width: 20),
                      _buildStatCard('حضور اليوم', stats?['today_attendance']?.toString() ?? '0', Icons.how_to_reg),
                      const SizedBox(width: 20),
                      _buildStatCard('البوابات النشطة', stats?['total_doors']?.toString() ?? '0', Icons.door_front_door),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  // Header and Export Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل الحضور الحي',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: exportExcel,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('تصدير Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Data Table
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF162032),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('الموظف')),
                              DataColumn(label: Text('رقم الوظيفة')),
                              DataColumn(label: Text('نوع الحركة')),
                              DataColumn(label: Text('البوابة')),
                              DataColumn(label: Text('الوقت والتاريخ')),
                            ],
                            rows: (attendanceLogs ?? []).map((log) {
                              final emp = log['employees'] ?? {};
                              final door = log['doors'] ?? {};
                              final type = log['movement_type'] ?? '';
                              final time = log['recorded_at'] != null 
                                ? DateTime.parse(log['recorded_at']).toLocal().toString().substring(0, 19)
                                : '';
                              
                              return DataRow(cells: [
                                DataCell(Text(emp['full_name'] ?? 'غير معروف')),
                                DataCell(Text(emp['emp_id'] ?? '-')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: type == 'دخول' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        color: type == 'دخول' ? Colors.greenAccent : Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(door['door_name'] ?? 'غير معروف')),
                                DataCell(Text(time)),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C3E50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00E5FF), size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
