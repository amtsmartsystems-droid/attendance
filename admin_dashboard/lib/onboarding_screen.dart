import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OnboardingScreen extends StatefulWidget {
  final String backendUrl;
  const OnboardingScreen({Key? key, required this.backendUrl}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  List<dynamic> _pendingRequests = [];
  List<String> _selectedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingRequests();
  }

  Future<void> fetchPendingRequests() async {
    try {
      // In a real app, you'd create a specific endpoint for pending requests.
      // For now, we fetch all employees and filter by status == 'pending'.
      // Note: we can reuse employee API or build a specific one. Let's assume we use standard employee API.
      final response = await http.get(Uri.parse('${widget.backendUrl}/api/employees'));
      if (response.statusCode == 200) {
        final List<dynamic> allEmployees = json.decode(response.body);
        setState(() {
          _pendingRequests = allEmployees.where((emp) => emp['status'] == 'pending').toList();
          _selectedIds = _pendingRequests.map((e) => e['id'] as String).toList(); // Auto-select all
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching pending: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> bulkApprove() async {
    if (_selectedIds.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('${widget.backendUrl}/api/onboarding/bulk-approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'employee_ids': _selectedIds}),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة بنجاح')));
        fetchPendingRequests(); // Refresh
      }
    } catch (e) {
      print('Error approving: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموافقة على المتدربين (Walk-ins)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _selectedIds.isEmpty ? null : bulkApprove,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('موافقة جماعية (${_selectedIds.length})'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? const Center(child: Text('لا توجد طلبات معلقة', style: TextStyle(fontSize: 18, fontFamily: 'Cairo')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, index) {
                    final req = _pendingRequests[index];
                    final String id = req['id'];
                    final isSelected = _selectedIds.contains(id);
                    
                    return Card(
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          });
                        },
                        title: Text(req['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        subtitle: Text('الجوال: ${req['phone_number'] ?? 'غير متوفر'} | القسم: ${req['department']}'),
                        secondary: const CircleAvatar(child: Icon(Icons.person_add)),
                        activeColor: Colors.teal,
                      ),
                    );
                  },
                ),
    );
  }
}
