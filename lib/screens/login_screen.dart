import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_theme.dart';
import '../core/config/app_config.dart';
import '../services/nfc_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  bool _isLoading = false;

  // State 0: Scan NFC, State 1: Select Name, State 2: Walk-in Form
  int _currentStep = 0;

  // Scanned Tag Info
  String? _scannedNfcUid;
  List<dynamic> _maskedEmployees = [];

  // ✅ بيانات الدورة المرتبطة بالـ NFC
  Map<String, dynamic>? _courseInfo;

  // Fast Track Info
  String? _selectedEmployeeId;
  final _pinController = TextEditingController();

  // Walk-in Form Info
  final _walkinNameController = TextEditingController();
  final _walkinPhoneController = TextEditingController();
  final _walkinPinController = TextEditingController();

  Future<void> _startNfcScan() async {
    setState(() => _isLoading = true);

    await NfcService().startNfcSession(
      onSuccess: (result) async {
        if (result.tagCode == null) return;
        _scannedNfcUid = result.tagCode;

        try {
          final response = await http.get(
            Uri.parse('${AppConfig.backendUrl}/api/onboarding/list/$_scannedNfcUid'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              _maskedEmployees = data['masked_employees'] ?? [];
              _courseInfo = data['course'];   // ✅ حفظ بيانات الدورة
              _currentStep = 1;
              _isLoading = false;
            });
          } else {
            _showError('هذه البوابة غير مسجلة. كود الشريحة هو: $_scannedNfcUid');
            setState(() => _isLoading = false);
          }
        } catch (e) {
          _showError('خطأ في الاتصال بالسيرفر');
          setState(() => _isLoading = false);
        }
      },
      onError: (msg) {
        _showError(msg);
        setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _fastTrackLogin() async {
    if (_selectedEmployeeId == null || _pinController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final deviceId = _generateDeviceId();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/onboarding/fast-track'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee_id': _selectedEmployeeId,
          'pin_code': _pinController.text.trim(),
          'device_id': deviceId,
          'course_id': _courseInfo?['id'],   // ✅ إرسال course_id
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final emp = data['employee'];
        await _storage.write(key: 'emp_id', value: emp['emp_id']);
        await _storage.write(key: 'employee_uuid', value: emp['id']);
        await _storage.write(key: 'full_name', value: emp['full_name']);
        await _storage.write(key: 'device_id', value: deviceId);
        // ✅ حفظ بيانات الدورة
        if (_courseInfo != null) {
          await _storage.write(key: 'course_id', value: _courseInfo!['id'] ?? '');
          await _storage.write(key: 'course_title', value: _courseInfo!['title'] ?? '');
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(data['detail'] ?? 'الرمز السري غير صحيح أو الجهاز مربوط مسبقاً');
      }
    } catch (e) {
      _showError('حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWalkIn() async {
    if (_walkinNameController.text.isEmpty || _walkinPhoneController.text.isEmpty || _walkinPinController.text.isEmpty) {
      _showError('يرجى تعبئة جميع الحقول');
      return;
    }

    setState(() => _isLoading = true);
    final deviceId = _generateDeviceId();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/onboarding/walk-in'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _walkinNameController.text.trim(),
          'phone_number': _walkinPhoneController.text.trim(),
          'pin_code': _walkinPinController.text.trim(),
          'department': _courseInfo?['title'] ?? 'Walk-in / Guest',
          'device_id': deviceId,
          'course_id': _courseInfo?['id'],   // ✅ إرسال course_id
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final emp = data['employee'];
        await _storage.write(key: 'emp_id', value: emp['emp_id']);
        await _storage.write(key: 'employee_uuid', value: emp['id']);
        await _storage.write(key: 'full_name', value: emp['full_name']);
        await _storage.write(key: 'device_id', value: deviceId);
        // ✅ حفظ بيانات الدورة
        if (_courseInfo != null) {
          await _storage.write(key: 'course_id', value: _courseInfo!['id'] ?? '');
          await _storage.write(key: 'course_title', value: _courseInfo!['title'] ?? '');
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(data['detail'] ?? 'خطأ في إرسال الطلب');
      }
    } catch (e) {
      _showError('حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
    );
  }

  String _generateDeviceId() {
    final rand = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List.generate(4, (_) => rand.nextInt(10).toString()).join();
    return 'DEV-$timestamp-$randomPart';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.nfc, size: 80, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text('نظام الدخول السريع', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 10),
          const Text('يرجى تمرير هاتفك على جهاز الـ NFC الخاص بالدورة أو الشركة لبدء الإعداد السريع', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startNfcScan,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.wifi_tethering, color: Colors.white),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('مسح الشريحة الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 60, color: Colors.greenAccent),
          const SizedBox(height: 20),
          // ✅ عرض اسم الدورة إذا كانت موجودة
          if (_courseInfo != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    _courseInfo!['title'] ?? 'دورة تدريبية',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  if (_courseInfo!['trainer_name'] != null)
                    Text(
                      _courseInfo!['trainer_name'],
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('اختر اسمك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('تم التعرف على الدورة! يرجى اختيار اسمك من القائمة وإدخال الرمز السري', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16),
            hint: const Text('اضغط لاختيار اسمك', style: TextStyle(color: Colors.white54)),
            value: _selectedEmployeeId,
            items: _maskedEmployees.map((emp) {
              return DropdownMenuItem<String>(
                value: emp['id'],
                child: Text(emp['masked_name']),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedEmployeeId = val),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'الرمز السري',
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _fastTrackLogin,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد وتسجيل الدخول', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
          TextButton(
            onPressed: () => setState(() => _currentStep = 2),
            child: const Text('لم أجد اسمي! تسجيل كضيف جديد', style: TextStyle(color: Colors.amber, fontSize: 16, decoration: TextDecoration.underline)),
          )
        ],
      );
    } else {
      // Step 2: Walk-in Form
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_add_alt_1, size: 60, color: Colors.amber),
          const SizedBox(height: 20),
          const Text('تسجيل متدرب جديد', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          if (_courseInfo != null)
            Text(
              'سيتم تسجيلك في: ${_courseInfo!['title'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 8),
          const Text('يرجى إدخال بياناتك للانضمام للدورة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 30),
          TextField(
            controller: _walkinNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'الاسم الرباعي', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _walkinPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'رقم الجوال', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _walkinPinController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'ابتكر رمزاً سرياً (PIN)', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitWalkIn,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('انضم للدورة الآن', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('رجوع للقائمة', style: TextStyle(color: Colors.white54)),
          )
        ],
      );
    }
  }
}
