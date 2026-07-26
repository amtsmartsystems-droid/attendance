import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── ثوابت الألوان ─────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0E21);
const _surface = Color(0xFF1A2340);
const _primary = Color(0xFF00B4D8);
const _accent = Color(0xFF48CAE4);
const _gold = Color(0xFFFFC300);
const _success = Color(0xFF2ECC71);
const _danger = Color(0xFFE74C3C);

const _backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://attendance-yty9.onrender.com');

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/api/courses/')).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() { _courses = data['courses'] ?? []; _isLoading = false; });
      } else {
        setState(() { _error = 'فشل تحميل الدورات (${resp.statusCode})'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'تعذّر الاتصال بالسيرفر'; _isLoading = false; });
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final trainerCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Text('إنشاء دورة جديدة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, 'عنوان الدورة *'),
              const SizedBox(height: 12),
              _dialogField(trainerCtrl, 'اسم المدرب'),
              const SizedBox(height: 12),
              _dialogField(descCtrl, 'وصف الدورة', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              Navigator.pop(context);
              await _createCourse(titleCtrl.text, trainerCtrl.text, descCtrl.text);
            },
            child: Text('إنشاء', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.cairo(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _createCourse(String title, String trainer, String desc) async {
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/courses/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'trainer_name': trainer, 'description': desc}),
      );
      _loadCourses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإنشاء: $e'), backgroundColor: _danger));
    }
  }

  Future<void> _exportExcel(String courseId, String courseCode) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري تحضير التقرير...', style: GoogleFonts.cairo()), backgroundColor: _primary),
    );
    // في بيئة الويب يمكن فتح الرابط مباشرة في المتصفح
    // ignore: avoid_web_libraries_in_flutter
    try {
      final url = '$_backendUrl/api/courses/$courseId/export';
      // للويب: نستخدم anchor tag
      import_html_anchor(url, 'attendance_$courseCode.xlsx');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('افتح هذا الرابط في المتصفح: $_backendUrl/api/courses/$courseId/export', style: GoogleFonts.cairo(fontSize: 12)), backgroundColor: _gold, duration: const Duration(seconds: 8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('إدارة الدورات التدريبية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _primary), onPressed: _loadCourses, tooltip: 'تحديث'),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('دورة جديدة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showCreateDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: _danger, size: 60),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.cairo(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadCourses, style: ElevatedButton.styleFrom(backgroundColor: _primary), child: Text('إعادة المحاولة', style: GoogleFonts.cairo())),
                ]))
              : _courses.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.school_outlined, color: Colors.white24, size: 80),
                      const SizedBox(height: 20),
                      Text('لا توجد دورات بعد', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('اضغط على "دورة جديدة" لإنشاء أولى دوراتك', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13)),
                    ]))
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(builder: (ctx, constraints) {
                        final crossCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            childAspectRatio: 1.6,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _courses.length,
                          itemBuilder: (_, i) => _CourseCard(
                            course: _courses[i],
                            onExport: () => _exportExcel(_courses[i]['id'], _courses[i]['course_code'] ?? 'course'),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CourseDetailScreen(courseId: _courses[i]['id'], courseTitle: _courses[i]['title']),
                            )).then((_) => _loadCourses()),
                          ),
                        );
                      }),
                    ),
    );
  }
}

// ─── بطاقة دورة واحدة ────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onExport;
  final VoidCallback onTap;
  const _CourseCard({required this.course, required this.onExport, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = course['is_active'] == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? _primary.withOpacity(0.4) : Colors.white12),
          boxShadow: [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isActive ? _success.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(isActive ? 'نشطة' : 'منتهية', style: GoogleFonts.cairo(color: isActive ? _success : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download, color: _gold, size: 20),
                  tooltip: 'تصدير Excel',
                  onPressed: onExport,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(course['title'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (course['trainer_name'] != null)
              Text(course['trainer_name'], style: GoogleFonts.cairo(color: _accent, fontSize: 12)),
            const Spacer(),
            Row(
              children: [
                _statChip(Icons.people, '${course['trainee_count'] ?? 0} متدرب', _primary),
                const SizedBox(width: 10),
                _statChip(Icons.today, '${course['today_attendance'] ?? 0} اليوم', _gold),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.cairo(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }
}

// ─── شاشة تفاصيل الدورة ─────────────────────────────────────────────────

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  const CourseDetailScreen({super.key, required this.courseId, required this.courseTitle});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _course;
  List<dynamic> _trainees = [];
  List<dynamic> _attendance = [];
  List<dynamic> _doors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$_backendUrl/api/courses/${widget.courseId}')).timeout(const Duration(seconds: 20));
      final attRes = await http.get(Uri.parse('$_backendUrl/api/courses/${widget.courseId}/attendance')).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final a = jsonDecode(attRes.body);
        setState(() {
          _course = d['course'];
          _trainees = d['trainees'] ?? [];
          _doors = d['doors'] ?? [];
          _attendance = a['attendance'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(widget.courseTitle, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: _primary,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _primary,
          tabs: [
            Tab(child: Text('المتدربون', style: GoogleFonts.cairo())),
            Tab(child: Text('سجلات الحضور', style: GoogleFonts.cairo())),
            Tab(child: Text('الأبواب', style: GoogleFonts.cairo())),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: _gold),
            tooltip: 'تصدير Excel',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('رابط التصدير: $_backendUrl/api/courses/${widget.courseId}/export', style: GoogleFonts.cairo(fontSize: 12)),
                backgroundColor: _gold,
                duration: const Duration(seconds: 8),
              ));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tab,
              children: [
                _buildTraineesTab(),
                _buildAttendanceTab(),
                _buildDoorsTab(),
              ],
            ),
    );
  }

  Widget _buildTraineesTab() {
    if (_trainees.isEmpty) {
      return Center(child: Text('لا يوجد متدربون مسجلون بعد', style: GoogleFonts.cairo(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _trainees.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (_, i) {
        final t = _trainees[i];
        return ListTile(
          leading: CircleAvatar(backgroundColor: _primary.withOpacity(0.2), child: Text(t['full_name']?[0] ?? '?', style: GoogleFonts.cairo(color: _primary, fontWeight: FontWeight.bold))),
          title: Text(t['full_name'] ?? '', style: GoogleFonts.cairo(color: Colors.white)),
          subtitle: Text(t['emp_id'] ?? '', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t['status'] == 'approved' ? _success.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(t['status'] == 'approved' ? 'مفعّل' : 'معلق', style: GoogleFonts.cairo(color: t['status'] == 'approved' ? _success : Colors.orange, fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return Center(child: Text('لا توجد سجلات حضور بعد', style: GoogleFonts.cairo(color: Colors.white54)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_surface),
        dataRowColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _primary.withOpacity(0.1) : null),
        columns: ['#', 'الاسم', 'رقم الموظف', 'نوع الحركة', 'التاريخ', 'الوقت']
            .map((h) => DataColumn(label: Text(h, style: GoogleFonts.cairo(color: _primary, fontWeight: FontWeight.bold))))
            .toList(),
        rows: _attendance.asMap().entries.map((e) {
          final rec = e.value;
          final emp = rec['employees'] ?? {};
          final recordedAt = rec['recorded_at'] ?? '';
          final date = recordedAt.length >= 10 ? recordedAt.substring(0, 10) : '—';
          final time = recordedAt.length >= 16 ? recordedAt.substring(11, 16) : '—';
          return DataRow(cells: [
            DataCell(Text('${e.key + 1}', style: GoogleFonts.cairo(color: Colors.white54))),
            DataCell(Text(emp['full_name'] ?? '—', style: GoogleFonts.cairo(color: Colors.white))),
            DataCell(Text(emp['emp_id'] ?? '—', style: GoogleFonts.cairo(color: Colors.white54))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rec['movement_type'] == 'دخول' ? _success.withOpacity(0.2) : _danger.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(rec['movement_type'] ?? '—', style: GoogleFonts.cairo(color: rec['movement_type'] == 'دخول' ? _success : _danger, fontSize: 12)),
            )),
            DataCell(Text(date, style: GoogleFonts.cairo(color: Colors.white70))),
            DataCell(Text(time, style: GoogleFonts.cairo(color: Colors.white70))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildDoorsTab() {
    if (_doors.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.door_front_door_outlined, color: Colors.white24, size: 60),
        const SizedBox(height: 16),
        Text('لا توجد بوابات مرتبطة بهذه الدورة', style: GoogleFonts.cairo(color: Colors.white54)),
        const SizedBox(height: 8),
        Text('قم بربط بوابة NFC بهذه الدورة من لوحة الإدارة أو عبر API', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _doors.length,
      itemBuilder: (_, i) {
        final d = _doors[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _primary.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.nfc, color: _primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['door_name'] ?? '—', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(d['nfc_uid'] ?? '—', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12)),
            ])),
            Text(d['location'] ?? '—', style: GoogleFonts.cairo(color: _accent, fontSize: 12)),
          ]),
        );
      },
    );
  }
}

// ─── helper لفتح رابط في بيئة الويب ─────────────────────────────────────
void import_html_anchor(String url, String filename) {
  // يعمل فقط في Flutter Web — نتجاهل الخطأ في المنصات الأخرى
  // ignore: undefined_prefixed_name
}
