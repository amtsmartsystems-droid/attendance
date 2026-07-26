import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SchedulesScreen extends StatefulWidget {
  final String backendUrl;
  const SchedulesScreen({Key? key, required this.backendUrl}) : super(key: key);

  @override
  _SchedulesScreenState createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<dynamic> schedules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      final response = await http.get(Uri.parse('${widget.backendUrl}/api/schedules'));
      if (response.statusCode == 200) {
        setState(() {
          schedules = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching schedules: $e');
    }
  }

  void _showAddScheduleDialog() {
    // Basic dialog to add a new schedule
    String name = '';
    String type = 'recurring';
    String startTime = '08:00:00';
    String endTime = '17:00:00';
    int gracePeriod = 15;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('إضافة وردية/جلسة جديدة', style: TextStyle(fontFamily: 'Cairo')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'اسم الوردية (مثال: دوام صباحي)'),
                  onChanged: (val) => name = val,
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(value: 'recurring', child: Text('متكرر (شركة)')),
                    DropdownMenuItem(value: 'temporary', child: Text('مؤقت (دورة)')),
                  ],
                  onChanged: (val) => type = val!,
                  decoration: InputDecoration(labelText: 'النوع'),
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'وقت البدء (HH:MM:SS)'),
                  onChanged: (val) => startTime = val,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'وقت الانتهاء (HH:MM:SS)'),
                  onChanged: (val) => endTime = val,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'فترة السماح (دقائق)'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => gracePeriod = int.tryParse(val) ?? 15,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response = await http.post(
                  Uri.parse('${widget.backendUrl}/api/schedules'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'name': name,
                    'schedule_type': type,
                    'start_time': startTime,
                    'end_time': endTime,
                    'grace_period_minutes': gracePeriod
                  }),
                );
                Navigator.pop(context);
                fetchSchedules();
              },
              child: Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الجداول والورديات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        icon: Icon(Icons.add),
        label: Text('إضافة وردية', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final s = schedules[index];
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: s['schedule_type'] == 'recurring' ? Colors.blue : Colors.orange,
                      child: Icon(s['schedule_type'] == 'recurring' ? Icons.loop : Icons.event, color: Colors.white),
                    ),
                    title: Text(s['name'], style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    subtitle: Text('من ${s['start_time']} إلى ${s['end_time']} | سماحية: ${s['grace_period_minutes']} دقيقة', style: TextStyle(fontFamily: 'Cairo')),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await http.delete(Uri.parse('${widget.backendUrl}/api/schedules/${s['id']}'));
                        fetchSchedules();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
