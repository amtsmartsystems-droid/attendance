import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeavesScreen extends StatefulWidget {
  final String backendUrl;
  const LeavesScreen({Key? key, required this.backendUrl}) : super(key: key);

  @override
  _LeavesScreenState createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  List<dynamic> leaves = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLeaves();
  }

  Future<void> fetchLeaves() async {
    try {
      final response = await http.get(Uri.parse('${widget.backendUrl}/api/leaves'));
      if (response.statusCode == 200) {
        setState(() {
          leaves = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching leaves: $e');
    }
  }

  Future<void> updateStatus(String leaveId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.backendUrl}/api/leaves/$leaveId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      if (response.statusCode == 200) {
        fetchLeaves();
      }
    } catch (e) {
      print('Error updating leave status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة طلبات الإجازة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: leaves.length,
              itemBuilder: (context, index) {
                final l = leaves[index];
                final emp = l['employees'] ?? {};
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(l['status']),
                      child: Icon(Icons.assignment_ind, color: Colors.white),
                    ),
                    title: Text('${emp['full_name']} - ${l['leave_type']}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    subtitle: Text('من: ${l['start_date']} إلى: ${l['end_date']}\nالسبب: ${l['reason'] ?? 'بدون'}', style: TextStyle(fontFamily: 'Cairo')),
                    isThreeLine: true,
                    trailing: l['status'] == 'pending' ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => updateStatus(l['id'], 'approved'),
                          tooltip: 'موافقة',
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => updateStatus(l['id'], 'rejected'),
                          tooltip: 'رفض',
                        ),
                      ],
                    ) : Text(
                      l['status'] == 'approved' ? 'مقبول' : 'مرفوض',
                      style: TextStyle(color: _getStatusColor(l['status']), fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }
}
