import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final String backendUrl = 'http://127.0.0.1:8000';
  List<dynamic> employees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$backendUrl/api/employees'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            employees = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء جلب الموظفين', style: TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final deptController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة موظف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deptController,
                    decoration: const InputDecoration(labelText: 'القسم'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.isEmpty || deptController.text.isEmpty) return;
                          
                          setDialogState(() => isSubmitting = true);
                          
                          try {
                            final response = await http.post(
                              Uri.parse('$backendUrl/api/employees'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'full_name': nameController.text,
                                'department': deptController.text,
                              }),
                            );
                            
                            if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              if (data['success']) {
                                Navigator.pop(context);
                                _fetchEmployees();
                                _showSuccessDialog(data['pin'], data['data']['emp_id']);
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('خطأ أثناء الإضافة')),
                            );
                          } finally {
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ وتوليد بيانات الدخول'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSuccessDialog(String pin, String empId) {
    final String loginLink = 'https://amt-attendance.app/login?pin=$pin&emp_id=$empId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تمت الإضافة بنجاح', style: TextStyle(color: Colors.green, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('بإمكان الموظف الدخول لأول مرة بإحدى الطرق الثلاث:', style: TextStyle(fontFamily: 'Cairo')),
              const SizedBox(height: 20),
              
              // 1. PIN
              const Text('1. الرمز السري (PIN)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pin,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.black87),
                ),
              ),
              const Divider(),
              
              // 2. QR Code
              const Text('2. مسح رمز الاستجابة السريعة (QR)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  width: 150.0,
                  height: 150.0,
                  child: QrImageView(
                    data: loginLink,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
              ),
              const Divider(),
              
              // 3. Link
              const Text('3. رابط الدخول المباشر', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        loginLink,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ الرابط',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: loginLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرابط!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          )
        ],
      ),
    );
  }

  Future<void> _resetEmployeeDevice(String id, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162032),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: Colors.amber),
            const SizedBox(width: 10),
            Text('إعادة ضبط جهاز $name',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'سيتم إلغاء ربط الجهاز الحالي وتوليد رمز PIN جديد.\nيمكن للموظف تسجيل الدخول من جديد بالرمز الجديد.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => Navigator.pop(context, true),
            label: const Text('إعادة الضبط', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/employees/$id/reset-device'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final newPin = data['new_pin'];
          final empId = data['emp_id'];
          _fetchEmployees();
          _showSuccessDialog(newPin, empId);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إعادة الضبط', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ أثناء الاتصال بالخادم', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  Future<void> _deleteEmployee(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الموظف نهائياً؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(Uri.parse('$backendUrl/api/employees/$id'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _fetchEmployees();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الموظف بنجاح')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف من الخادم')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف', style: TextStyle(fontFamily: 'Cairo')),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
              ? const Center(child: Text('لا يوجد موظفين حالياً', style: TextStyle(fontFamily: 'Cairo')))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(emp['full_name'][0].toUpperCase()),
                        ),
                        title: Text(emp['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        subtitle: Text('${emp['emp_id']} - ${emp['department']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: emp['is_device_bound'] == true ? 'حساب مرتبط بجهاز' : 'بانتظار الدخول الأول',
                              child: Icon(
                                emp['is_device_bound'] == true ? Icons.lock : Icons.lock_open,
                                color: emp['is_device_bound'] == true ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // زر إعادة ضبط الجهاز (يظهر فقط للمرتبطين)
                            if (emp['is_device_bound'] == true)
                              Tooltip(
                                message: 'إعادة ضبط الجهاز (تغيير الهاتف أو الضياع)',
                                child: IconButton(
                                  icon: const Icon(Icons.phone_android, color: Colors.amber),
                                  onPressed: () => _resetEmployeeDevice(emp['id'], emp['full_name']),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'حذف الموظف',
                              onPressed: () => _deleteEmployee(emp['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
