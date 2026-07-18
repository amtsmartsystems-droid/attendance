/// =====================================================
/// ملف: nfc_scan_button.dart
/// الوصف: زر المسح الرئيسي مع أيقونة NFC المتحركة
///        يتغير شكله ولونه حسب حالة التطبيق
/// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/nfc_service.dart';
import '../core/theme/app_theme.dart';

class NfcScanButton extends StatefulWidget {
  final NfcScanState scanState;
  final VoidCallback onScan;
  final VoidCallback onStop;

  const NfcScanButton({
    super.key,
    required this.scanState,
    required this.onScan,
    required this.onStop,
  });

  @override
  State<NfcScanButton> createState() => _NfcScanButtonState();
}

class _NfcScanButtonState extends State<NfcScanButton>
    with TickerProviderStateMixin {
  // انيميشن النبض للدوائر الخارجية
  late AnimationController _pulseController;
  // انيميشن الدوران للدائرة الخارجية أثناء الفحص
  late AnimationController _rotateController;
  // انيميشن الضغط
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(NfcScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimations();
  }

  /// --- تحديث الانيميشن حسب الحالة ---
  void _updateAnimations() {
    switch (widget.scanState) {
      case NfcScanState.scanning:
        _pulseController.repeat(reverse: true);
        _rotateController.repeat();
        break;
      case NfcScanState.success:
        _pulseController.stop();
        _rotateController.stop();
        break;
      case NfcScanState.error:
        _pulseController.stop();
        _rotateController.stop();
        break;
      default:
        _pulseController.stop();
        _rotateController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// --- الحصول على لون الحالة ---
  Color get _stateColor {
    switch (widget.scanState) {
      case NfcScanState.scanning:
        return AppColors.scanning;
      case NfcScanState.success:
        return AppColors.success;
      case NfcScanState.error:
        return AppColors.error;
      case NfcScanState.unsupported:
      case NfcScanState.disabled:
        return AppColors.textHint;
      default:
        return AppColors.primary;
    }
  }

  /// --- الحصول على أيقونة الحالة ---
  IconData get _stateIcon {
    switch (widget.scanState) {
      case NfcScanState.success:
        return Icons.check_rounded;
      case NfcScanState.error:
        return Icons.close_rounded;
      case NfcScanState.unsupported:
        return Icons.nfc_outlined;
      default:
        return Icons.nfc_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- الأيقونة الدائرية الرئيسية ---
        GestureDetector(
          onTapDown: (_) => _scaleController.reverse(),
          onTapUp: (_) {
            _scaleController.forward();
            if (widget.scanState == NfcScanState.scanning) {
              widget.onStop();
            } else if (widget.scanState == NfcScanState.idle) {
              widget.onScan();
            }
          },
          onTapCancel: () => _scaleController.forward(),
          child: ScaleTransition(
            scale: _scaleController,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _rotateController]),
              builder: (context, child) {
                return SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // --- حلقات النبض ---
                      if (widget.scanState == NfcScanState.scanning)
                        for (int i = 3; i >= 1; i--)
                          Opacity(
                            opacity:
                                (1 - _pulseController.value) * (0.35 / i),
                            child: Container(
                              width: 120.0 + (i * 35) * _pulseController.value,
                              height:
                                  120.0 + (i * 35) * _pulseController.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _stateColor,
                                  width: 2.0 / i,
                                ),
                              ),
                            ),
                          ),

                      // --- الحلقة الخارجية المتحركة (أثناء الفحص) ---
                      if (widget.scanState == NfcScanState.scanning)
                        RotationTransition(
                          turns: _rotateController,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.transparent,
                              ),
                              gradient: SweepGradient(
                                colors: [
                                  _stateColor.withOpacity(0.8),
                                  _stateColor.withOpacity(0.0),
                                  _stateColor.withOpacity(0.0),
                                  _stateColor.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // --- الدائرة الرئيسية ---
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.scanState == NfcScanState.success
                                ? [AppColors.success, const Color(0xFF00A878)]
                                : widget.scanState == NfcScanState.error
                                    ? [AppColors.error, const Color(0xFFCC2233)]
                                    : [
                                        _stateColor.withOpacity(0.2),
                                        AppColors.secondary.withOpacity(0.1),
                                      ],
                          ),
                          border: Border.all(
                            color: _stateColor.withOpacity(
                              widget.scanState == NfcScanState.scanning
                                  ? 0.3
                                  : 0.8,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _stateColor.withOpacity(0.4),
                              blurRadius: widget.scanState ==
                                      NfcScanState.scanning
                                  ? 40 * _pulseController.value + 10
                                  : 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _stateIcon,
                            key: ValueKey(widget.scanState),
                            size: 64,
                            color: widget.scanState == NfcScanState.success ||
                                    widget.scanState == NfcScanState.error
                                ? Colors.white
                                : _stateColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 32),

        // --- زر المسح النصي ---
        _buildActionButton(),
      ],
    );
  }

  /// --- زر الإجراء (بدء/إيقاف المسح) ---
  Widget _buildActionButton() {
    final bool isScanning = widget.scanState == NfcScanState.scanning;
    final bool isDisabled = widget.scanState == NfcScanState.unsupported ||
        widget.scanState == NfcScanState.success;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: isDisabled
              ? null
              : isScanning
                  ? LinearGradient(
                      colors: [
                        AppColors.error.withOpacity(0.8),
                        AppColors.error,
                      ],
                    )
                  : AppColors.primaryGradient,
          color: isDisabled ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: (isScanning ? AppColors.error : AppColors.primary)
                        .withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isDisabled
                ? null
                : isScanning
                    ? widget.onStop
                    : widget.onScan,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isScanning ? Icons.stop_rounded : Icons.nfc_rounded,
                    color: isDisabled ? AppColors.textHint : Colors.black,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isScanning
                        ? 'إيقاف المسح'
                        : isDisabled
                            ? 'NFC غير مدعوم'
                            : 'ابدأ المسح',
                    style: TextStyle(
                      
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDisabled ? AppColors.textHint : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.3, end: 0);
  }
}
