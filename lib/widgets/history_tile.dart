/// =====================================================
/// ملف: history_tile.dart
/// الوصف: عنصر قائمة لعرض سجل عملية حضور واحدة
/// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/theme/app_theme.dart';

class HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const HistoryTile({
    super.key,
    required this.data,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = data['success'] as bool? ?? false;
    final DateTime timestamp = data['timestamp'] as DateTime? ?? DateTime.now();
    final String tagCode = data['tag_code'] as String? ?? 'غير معروف';
    final String attendanceType = data['attendance_type'] as String? ?? 'دخول';
    final String timeStr = DateFormat('HH:mm:ss').format(timestamp);
    final String dateStr = DateFormat('d MMM', 'ar').format(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuccess
              ? AppColors.success.withOpacity(0.2)
              : AppColors.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // --- أيقونة النتيجة ---
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSuccess
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSuccess ? Icons.check_rounded : Icons.close_rounded,
              color: isSuccess ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          // --- المعلومات ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // نوع الحضور (دخول/خروج)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        attendanceType,
                        style: const TextStyle(
                          
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // الوقت
                    Text(
                      '$timeStr | $dateStr',
                      style: const TextStyle(
                        
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // كود الشريحة
                Text(
                  tagCode,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }
}
