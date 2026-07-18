/// =====================================================
/// ملف: status_card.dart
/// الوصف: بطاقة عرض حالة التطبيق الحالية
///        تتغير تلقائياً حسب حالة NFC
/// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/nfc_service.dart';
import '../core/theme/app_theme.dart';

class StatusCard extends StatelessWidget {
  final NfcScanState state;
  final String message;
  final String? lastCode;

  const StatusCard({
    super.key,
    required this.state,
    required this.message,
    this.lastCode,
  });

  /// --- إعدادات كل حالة ---
  _StateConfig get _config {
    switch (state) {
      case NfcScanState.scanning:
        return _StateConfig(
          icon: Icons.wifi_tethering_rounded,
          color: AppColors.scanning,
          title: 'جاري الفحص',
          gradient: LinearGradient(
            colors: [
              AppColors.scanning.withOpacity(0.15),
              AppColors.scanning.withOpacity(0.05),
            ],
          ),
        );
      case NfcScanState.success:
        return _StateConfig(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          title: 'تم التسجيل',
          gradient: LinearGradient(
            colors: [
              AppColors.success.withOpacity(0.15),
              AppColors.success.withOpacity(0.05),
            ],
          ),
        );
      case NfcScanState.error:
        return _StateConfig(
          icon: Icons.error_rounded,
          color: AppColors.error,
          title: 'حدث خطأ',
          gradient: LinearGradient(
            colors: [
              AppColors.error.withOpacity(0.15),
              AppColors.error.withOpacity(0.05),
            ],
          ),
        );
      case NfcScanState.unsupported:
        return _StateConfig(
          icon: Icons.nfc_outlined,
          color: AppColors.textHint,
          title: 'NFC غير مدعوم',
          gradient: LinearGradient(
            colors: [
              AppColors.textHint.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        );
      default:
        return _StateConfig(
          icon: Icons.touch_app_rounded,
          color: AppColors.primary,
          title: 'جاهز',
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: config.gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: config.color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // --- أيقونة الحالة ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(state),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                config.icon,
                color: config.color,
                size: 28,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // --- النصوص ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    config.title,
                    key: ValueKey('title_$state'),
                    style: TextStyle(
                      
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: config.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: const TextStyle(
                      
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // عرض كود الشريحة عند النجاح
                if (lastCode != null && state == NfcScanState.success) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      lastCode!,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: AppColors.success,
                        letterSpacing: 1,
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).scale(),
                ],
              ],
            ),
          ),

          // --- نقطة الحالة المتحركة ---
          if (state == NfcScanState.scanning)
            _buildScanningDot(config.color),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// --- نقطة الحالة المتحركة ---
  Widget _buildScanningDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 600.ms)
        .then()
        .fadeOut(duration: 600.ms);
  }
}

/// --- كلاس مساعد لإعدادات الحالة ---
class _StateConfig {
  final IconData icon;
  final Color color;
  final String title;
  final LinearGradient gradient;

  const _StateConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.gradient,
  });
}
