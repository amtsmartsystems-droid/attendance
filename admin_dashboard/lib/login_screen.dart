import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // النجاح: سيُعيد توجيهنا تلقائياً عبر onAuthStateChange في main.dart
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e.message));
    } catch (e) {
      setState(() => _error = 'خطأ في الاتصال. تحقق من الإنترنت.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateError(String msg) {
    if (msg.contains('Invalid login credentials')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    if (msg.contains('Email not confirmed')) return 'البريد الإلكتروني غير مفعّل. تحقق من بريدك';
    if (msg.contains('Too many requests')) return 'محاولات كثيرة. انتظر دقيقة وأعد المحاولة';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E21), Color(0xFF0D1B2A), Color(0xFF1A2340)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2340),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─ أيقونة وعنوان ─
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF00B4D8), Color(0xFF0077B6)]),
                      boxShadow: [BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text('لوحة تحكم AMT', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('نظام الحضور الذكي', style: GoogleFonts.cairo(color: const Color(0xFF00B4D8), fontSize: 14)),
                  const SizedBox(height: 36),

                  // ─ حقل البريد ─
                  _buildField(
                    controller: _emailCtrl,
                    hint: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // ─ حقل كلمة المرور ─
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: GoogleFonts.cairo(color: Colors.white),
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور',
                      hintStyle: GoogleFonts.cairo(color: Colors.white38),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00B4D8)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white38),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00B4D8))),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4))),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: GoogleFonts.cairo(color: const Color(0xFFE74C3C), fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ─ زر الدخول ─
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text('تسجيل الدخول', style: GoogleFonts.cairo(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('للمسؤولين المعتمدين فقط', style: GoogleFonts.cairo(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.cairo(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFF00B4D8)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00B4D8))),
      ),
    );
  }
}
