import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_theme.dart';
import '../core/config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _verifyPin(String pin) async {
    if (pin.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // 1. توليد معرّف الجهاز
      final deviceId = _generateDeviceId();

      // 2. إرسال طلب تسجيل الدخول للسيرفر
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/employees/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin_code': pin,
          'device_id': deviceId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        _showError(data['detail'] ?? 'خطأ في تسجيل الدخول');
        setState(() => _isLoading = false);
        return;
      }

      // 3. الحفظ في التخزين الآمن
      final empId = data['emp_id'];
      final fullName = data['full_name'];
      
      await _storage.write(key: 'emp_id', value: empId);
      await _storage.write(key: 'full_name', value: fullName);
      await _storage.write(key: 'device_id', value: deviceId);
      
      if (!mounted) return;
      
      // 5. الدخول للتطبيق
      Navigator.pushReplacementNamed(context, '/home');
      
    } catch (e) {
      _showError('حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'يرجى إدخال الرمز السري أو مسح الباركود لربط جهازك بالنظام',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'الرمز السري (PIN)',
                    hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 0, fontSize: 16),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _verifyPin(_pinController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('أو', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pin = await Navigator.pushNamed(context, '/qr_scanner');
                      if (pin != null && pin is String) {
                        _pinController.text = pin;
                        _verifyPin(pin);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.secondary),
                    label: const Text('مسح رمز QR', style: TextStyle(fontSize: 18, color: AppColors.secondary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
