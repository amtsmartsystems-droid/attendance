import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================================================================
// نموذج بيانات سجل الحضور
// ================================================================
class AttendanceLog {
  final String id;
  final String empName;
  final String empId;
  final String department;
  final String movementType;
  final String doorName;
  final DateTime recordedAt;
  final bool isOffline;

  AttendanceLog({
    required this.id,
    required this.empName,
    required this.empId,
    required this.department,
    required this.movementType,
    required this.doorName,
    required this.recordedAt,
    required this.isOffline,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    final emp = json['employees'] ?? {};
    final door = json['doors'] ?? {};
    return AttendanceLog(
      id: json['id']?.toString() ?? '',
      empName: emp['full_name'] ?? 'غير معروف',
      empId: emp['emp_id'] ?? '-',
      department: emp['department'] ?? '-',
      movementType: json['movement_type'] ?? '-',
      doorName: door['door_name'] ?? 'غير معروف',
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at']).toLocal()
          : DateTime.now(),
      isOffline: json['is_offline_sync'] == true,
    );
  }
}

// ================================================================
// شاشة سجلات الحضور الرئيسية
// ================================================================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  static const String _apiUrl = 'https://attendance-yty9.onrender.com/api';

  // Live Feed
  List<AttendanceLog> _liveFeed = [];
  Timer? _liveTimer;

  // Historical Table
  List<AttendanceLog> _allLogs = [];
  List<AttendanceLog> _filteredLogs = [];
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _pageSize = 15;
  String _searchQuery = '';
  String _filterType = 'الكل';

  // Heatmap
  Map<String, int> _heatmapData = {};

  // Tab
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
    _startLiveFeed();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // جلب كل البيانات
  // ============================================================
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .get(Uri.parse('$_apiUrl/attendance/all'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        final logs = data.map((e) => AttendanceLog.fromJson(e)).toList();
        _buildHeatmap(logs);
        setState(() {
          _allLogs = logs;
          _filteredLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Live Feed - يتحدث كل 10 ثواني
  // ============================================================
  void _startLiveFeed() {
    _fetchLiveFeed();
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchLiveFeed();
    });
  }

  Future<void> _fetchLiveFeed() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiUrl/attendance/live'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        setState(() {
          _liveFeed = data.map((e) => AttendanceLog.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // بناء بيانات الـ Heatmap
  // ============================================================
  void _buildHeatmap(List<AttendanceLog> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      final key =
          '${log.recordedAt.year}-${log.recordedAt.month.toString().padLeft(2, '0')}-${log.recordedAt.day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + 1;
    }
    _heatmapData = map;
  }

  // ============================================================
  // فلترة وبحث
  // ============================================================
  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final matchSearch = _searchQuery.isEmpty ||
            log.empName.contains(_searchQuery) ||
            log.empId.contains(_searchQuery) ||
            log.department.contains(_searchQuery);
        final matchType =
            _filterType == 'الكل' || log.movementType == _filterType;
        return matchSearch && matchType;
      }).toList();
      _currentPage = 0;
    });
  }

  List<AttendanceLog> get _pagedLogs {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredLogs.length);
    return _filteredLogs.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredLogs.length / _pageSize).ceil().clamp(1, 9999);

  // ============================================================
  // تصدير التقارير
  // ============================================================
  void _exportExcel() {
    html.window.open('$_apiUrl/reports/excel', '_blank');
  }

  void _exportPdf() {
    html.window.open('$_apiUrl/reports/pdf', '_blank');
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101E),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoricalTab(),
                _buildLiveFeedTab(),
                _buildHeatmapTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // الهيدر
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      color: const Color(0xFF0B101E),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجلات الحضور والانصراف',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              SizedBox(height: 4),
              Text(
                'مراقبة حضور الموظفين بشكل لحظي وتاريخي',
                style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const Spacer(),
          _buildExportButton(
            label: 'Excel',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF1D7A3A),
            onTap: _exportExcel,
          ),
          const SizedBox(width: 12),
          _buildExportButton(
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFB71C1C),
            onTap: _exportPdf,
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _fetchAllData,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              'تصدير $label',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TabBar
  // ============================================================
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF00E5FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
        ),
        labelColor: const Color(0xFF00E5FF),
        unselectedLabelColor: Colors.white54,
        labelStyle:
            const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        tabs: [
          const Tab(icon: Icon(Icons.table_rows_rounded), text: 'السجل التاريخي'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stream_rounded, size: 18),
                const SizedBox(width: 6),
                const Text('النشاط المباشر', style: TextStyle(fontFamily: 'Cairo')),
                const SizedBox(width: 6),
                if (_liveFeed.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_liveFeed.length}',
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const Tab(icon: Icon(Icons.calendar_month_rounded), text: 'خريطة الحضور'),
        ],
      ),
    );
  }

  // ============================================================
  // التبويب الأول: السجل التاريخي مع Pagination وبحث
  // ============================================================
  Widget _buildHistoricalTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // شريط البحث والفلترة
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الموظف أو رقمه أو قسمه...',
                    hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF162032),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    _searchQuery = v;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    dropdownColor: const Color(0xFF162032),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    items: ['الكل', 'دخول', 'خروج']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      _filterType = v!;
                      _applyFilters();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_filteredLogs.length} سجل',
                style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // الجدول
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF162032),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _filteredLogs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('لا توجد سجلات',
                              style: TextStyle(color: Colors.white38, fontFamily: 'Cairo')),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFF0D1A2D)),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return const Color(0xFF00E5FF).withOpacity(0.05);
                          }
                          return Colors.transparent;
                        }),
                        columns: const [
                          DataColumn(
                              label: Text('الموظف',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('رقم الوظيفة',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('القسم',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('نوع الحركة',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('البوابة',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('التاريخ والوقت',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                          DataColumn(
                              label: Text('المصدر',
                                  style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo'))),
                        ],
                        rows: _pagedLogs.map((log) {
                          final isEntry = log.movementType == 'دخول';
                          return DataRow(cells: [
                            DataCell(Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                                child: Text(
                                  log.empName.isNotEmpty ? log.empName[0] : '?',
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(log.empName, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                            ])),
                            DataCell(Text(log.empId, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'))),
                            DataCell(Text(log.department, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  log.movementType,
                                  style: TextStyle(
                                    color: isEntry ? Colors.greenAccent : Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(log.doorName, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'))),
                            DataCell(Text(
                              _formatDateTime(log.recordedAt),
                              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12),
                            )),
                            DataCell(log.isOffline
                                ? const Tooltip(
                                    message: 'سُجّل أوفلاين ورُفع لاحقاً',
                                    child: Icon(Icons.wifi_off, color: Colors.amber, size: 16),
                                  )
                                : const Icon(Icons.cloud_done, color: Colors.greenAccent, size: 16)),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ),

          // Pagination
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white54),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text(
                'صفحة ${_currentPage + 1} من $_totalPages',
                style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white54),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // التبويب الثاني: النشاط المباشر Live Feed
  // ============================================================
  Widget _buildLiveFeedTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'النشاط الحي — آخر 10 دقائق',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    fontSize: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'يتحدث تلقائياً كل 10 ثوانٍ',
                style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _liveFeed.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sensors_off, size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد نشاط في آخر 10 دقائق',
                          style: TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _fetchLiveFeed,
                          icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                          label: const Text('تحديث الآن', style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _liveFeed.length,
                    itemBuilder: (ctx, i) {
                      final log = _liveFeed[i];
                      final isEntry = log.movementType == 'دخول';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162032),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.5),
                                ),
                              ),
                              child: Icon(
                                isEntry ? Icons.login_rounded : Icons.logout_rounded,
                                color: isEntry ? Colors.greenAccent : Colors.orangeAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.empName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo'),
                                  ),
                                  Text(
                                    '${log.empId} • ${log.department}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(log.recordedAt),
                                  style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo'),
                                ),
                                Text(
                                  log.doorName,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Cairo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // التبويب الثالث: خريطة الحضور (Heatmap Calendar)
  // ============================================================
  Widget _buildHeatmapTab() {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDay = DateTime(now.year, now.month, 1);
    final startWeekday = firstDay.weekday % 7; // 0=أحد

    int maxCount = _heatmapData.values.fold(0, (a, b) => a > b ? a : b);
    if (maxCount == 0) maxCount = 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خريطة الحضور — ${_monthName(now.month)} ${now.year}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'كل خلية تمثل يوماً واحداً — اللون الأخضر الداكن = حضور عالٍ',
            style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 12),
          ),
          const SizedBox(height: 24),
          // رؤوس الأيام
          Row(
            children: ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // شبكة التقويم
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (ctx, idx) {
                if (idx < startWeekday) {
                  return const SizedBox.shrink();
                }
                final day = idx - startWeekday + 1;
                final key =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                final count = _heatmapData[key] ?? 0;
                final ratio = count / maxCount;
                final isToday = day == now.day;

                Color cellColor;
                if (count == 0) {
                  cellColor = const Color(0xFF162032);
                } else if (ratio < 0.25) {
                  cellColor = Colors.green.shade900;
                } else if (ratio < 0.5) {
                  cellColor = Colors.green.shade700;
                } else if (ratio < 0.75) {
                  cellColor = Colors.green.shade500;
                } else {
                  cellColor = Colors.green.shade300;
                }

                return Tooltip(
                  message: count == 0
                      ? 'لا توجد حركات في $day/${now.month}'
                      : '$count حركة في $day/${now.month}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(color: const Color(0xFF00E5FF), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: count == 0 ? Colors.white24 : Colors.white,
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // مفتاح الألوان
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('منخفض', style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Cairo')),
              const SizedBox(width: 8),
              for (final c in [
                const Color(0xFF162032),
                Colors.green.shade900,
                Colors.green.shade700,
                Colors.green.shade500,
                Colors.green.shade300,
              ])
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const SizedBox(width: 8),
              const Text('مرتفع', style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Cairo')),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // مساعدات
  // ============================================================
  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _monthName(int m) {
    const names = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return names[m];
  }
}
