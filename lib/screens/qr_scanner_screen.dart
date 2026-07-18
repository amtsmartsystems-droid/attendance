import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final url = barcode.rawValue!;
        // استخراج الـ PIN من الرابط (https://amt-attendance.app/login?pin=123456&emp_id=EMP_4481)
        final uri = Uri.tryParse(url);
        if (uri != null && uri.queryParameters.containsKey('pin')) {
          _isScanned = true;
          controller.stop();
          Navigator.pop(context, uri.queryParameters['pin']);
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الرمز (QR)', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // مربع التحديد (Overlay)
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: const Text(
              'قم بتوجيه الكاميرا نحو رمز الـ QR',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}
