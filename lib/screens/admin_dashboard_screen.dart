/// =====================================================
/// ملف: admin_dashboard_screen.dart
/// الوصف: لوحة تحكم المدير — تعرض سجلات الحضور
///        من Supabase مع فلترة وبحث
/// =====================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  String _filterType = 'الكل'; // الكل / دخول / خروج
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _loadAttendanceLogs();
  }

  /// جلب السجلات من Supabase
  Future<void> _loadAttendanceLogs() async {
    setState(() { _isLoading = true; _error = ''; });

    try {
      var query = _supabase
          .from('attendance_view')
          .select()
          .order('recorded_at', ascending: false)
          .limit(500);

      final data = await query;
      setState(() {
        _logs = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'خطأ في جلب البيانات: $e';
        _isLoading = false;
      });
    }
  }

  /// فلترة السجلات محلياً
  List<Map<String, dynamic>> get _filteredLogs {
    return _logs.where((log) {
      // فلتر البحث بالاسم أو القسم
      final matchesSearch = _searchQuery.isEmpty ||
          (log['employee_name'] ?? '').toString().contains(_searchQuery) ||
          (log['department'] ?? '').toString().contains(_searchQuery) ||
          (log['emp_id'] ?? '').toString().contains(_searchQuery);

      // فلتر نوع الحركة
      final matchesType = _filterType == 'الكل' ||
          log['movement_type'] == _filterType;

      // فلتر التاريخ
      final matchesDate = _filterDate == null ||
          (log['date'] ?? '') ==
              DateFormat('yyyy-MM-dd').format(_filterDate!);

      return matchesSearch && matchesType && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'لوحة تحكم الحضور والانصراف',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadAttendanceLogs,
            icon: const Icon(Icons.refresh, color: Colors.cyan),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- شريط الإحصائيات ---
          _buildStatsBar(),

          // --- شريط الفلاتر ---
          _buildFiltersBar(),

          // --- الجدول أو رسالة الخطأ ---
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyan))
                : _error.isNotEmpty
                    ? Center(
                        child: Text(_error,
                            style: const TextStyle(color: Colors.redAccent)))
                    : _filteredLogs.isEmpty
                        ? const Center(
                            child: Text('لا توجد سجلات',
                                style: TextStyle(color: Colors.white54)))
                        : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  /// إحصائيات سريعة
  Widget _buildStatsBar() {
    final todayLogs = _logs.where((l) =>
        (l['date'] ?? '') ==
        DateFormat('yyyy-MM-dd').format(DateTime.now())).toList();

    final entries = todayLogs.where((l) => l['movement_type'] == 'دخول').length;
    final exits   = todayLogs.where((l) => l['movement_type'] == 'خروج').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCard('إجمالي اليوم', '${todayLogs.length}', Colors.cyan),
          _statCard('دخول', '$entries', Colors.greenAccent),
          _statCard('خروج', '$exits', Colors.orangeAccent),
          _statCard('إجمالي الكل', '${_logs.length}', Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  /// شريط الفلاتر
  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.background,
      child: Row(
        children: [
          // بحث
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث باسم الموظف أو القسم...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.cyan),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // فلتر النوع
          DropdownButton<String>(
            value: _filterType,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white),
            items: ['الكل', 'دخول', 'خروج']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _filterType = v!),
          ),
          const SizedBox(width: 12),

          // فلتر التاريخ
          IconButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              setState(() => _filterDate = date);
            },
            icon: Icon(
              Icons.calendar_today,
              color: _filterDate != null ? Colors.cyan : Colors.white38,
            ),
            tooltip: _filterDate != null
                ? DateFormat('yyyy-MM-dd').format(_filterDate!)
                : 'فلتر التاريخ',
          ),

          if (_filterDate != null)
            IconButton(
              onPressed: () => setState(() => _filterDate = null),
              icon: const Icon(Icons.clear, color: Colors.redAccent),
              tooltip: 'مسح التاريخ',
            ),
        ],
      ),
    );
  }

  /// جدول البيانات
  Widget _buildDataTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              Colors.cyan.withOpacity(0.15)),
          columnSpacing: 24,
          columns: const [
            DataColumn(
                label: Text('رقم الموظف',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('الاسم',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('القسم',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('الباب',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('النوع',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('التاريخ',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('الوقت',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold))),
          ],
          rows: _filteredLogs.map((log) {
            final isEntry = log['movement_type'] == 'دخول';
            return DataRow(
              cells: [
                DataCell(Text(log['emp_id'] ?? '',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Text(log['employee_name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
                DataCell(Text(log['department'] ?? '',
                    style: const TextStyle(color: Colors.white54))),
                DataCell(Text(log['door_name'] ?? '',
                    style: const TextStyle(color: Colors.white54))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEntry
                          ? Colors.greenAccent.withOpacity(0.15)
                          : Colors.orangeAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      log['movement_type'] ?? '',
                      style: TextStyle(
                        color: isEntry
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(log['date'] ?? '',
                    style: const TextStyle(color: Colors.white54))),
                DataCell(Text(log['time'] ?? '',
                    style: const TextStyle(
                        color: Colors.cyanAccent, fontWeight: FontWeight.w500))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
