import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _leaveType = 'مرضي';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  String _reason = '';
  bool _isLoading = false;

  final List<String> _leaveTypes = ['مرضي', 'سنوي', 'طارئ', 'بدون راتب'];

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? empId = prefs.getString('employee_uuid'); // The UUID of the employee
      
      if (empId == null) {
        throw Exception("Employee ID not found. Please login again.");
      }

      // Backend URL
      final response = await http.post(
        Uri.parse('https://attendance-yty9.onrender.com/api/leaves'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_id': empId,
          'leave_type': _leaveType,
          'start_date': _startDate.toIso8601String().substring(0, 10),
          'end_date': _endDate.toIso8601String().substring(0, 10),
          'reason': _reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الإجازة بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        throw Exception("فشل في إرسال الطلب: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب إجازة'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      backgroundColor: const Color(0xFF1E293B),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Leave Type
                    DropdownButtonFormField<String>(
                      value: _leaveType,
                      decoration: const InputDecoration(
                        labelText: 'نوع الإجازة',
                        filled: true,
                        fillColor: Color(0xFF334155),
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF334155),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                      items: _leaveTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _leaveType = val!);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Start Date
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: const Color(0xFF334155),
                      leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      title: const Text('من تاريخ', style: TextStyle(color: Colors.white70)),
                      subtitle: Text(_startDate.toString().substring(0, 10), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onTap: () => _selectDate(context, true),
                    ),
                    const SizedBox(height: 16),

                    // End Date
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: const Color(0xFF334155),
                      leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      title: const Text('إلى تاريخ', style: TextStyle(color: Colors.white70)),
                      subtitle: Text(_endDate.toString().substring(0, 10), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onTap: () => _selectDate(context, false),
                    ),
                    const SizedBox(height: 20),

                    // Reason
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'السبب (اختياري)',
                        filled: true,
                        fillColor: Color(0xFF334155),
                        border: OutlineInputBorder(),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      onSaved: (val) => _reason = val ?? '',
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitRequest,
                      child: const Text('إرسال الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
