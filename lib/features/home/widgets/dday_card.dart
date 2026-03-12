import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/utils/date_utils.dart' as date_utils;

/// 다가오는 기념일/이벤트 D-day 카드
class DdayCard extends ConsumerWidget {
  const DdayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingTodos = ref.watch(smartUpcomingExpandedTodosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 이벤트 타입만 필터 + 7일 이내
    final now = date_utils.normalizeDate(DateTime.now());
    final events = upcomingTodos.where((t) {
      if (t.eventType != TodoEventType.event) return false;
      final date = t.dueDate ?? t.startTime;
      if (date == null) return false;
      final diff = date_utils.normalizeDate(date).difference(now).inDays;
      return diff >= 0 && diff <= 30; // 30일 이내 이벤트
    }).toList()
      ..sort((a, b) {
        final aDate = a.dueDate ?? a.startTime ?? DateTime.now();
        final bDate = b.dueDate ?? b.startTime ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

    if (events.isEmpty) return const SizedBox.shrink();

    // 최대 3개만 표시
    final displayEvents = events.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '다가오는 기념일',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingS),
        ...displayEvents.map((event) {
          final date = event.dueDate ?? event.startTime!;
          final diff = date_utils.normalizeDate(date).difference(now).inDays;
          final ddayText = diff == 0 ? 'D-Day' : 'D-$diff';
          final ddayColor = diff == 0
              ? AppColors.errorLight
              : diff <= 3
                  ? Colors.orange
                  : AppColors.primaryLight;

          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
            ),
            child: Row(
              children: [
                // D-day 뱃지
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: ddayColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: ddayColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ddayText,
                        style: TextStyle(
                          color: ddayColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 이벤트 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('M월 d일 (E)', 'ko_KR').format(date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // 아이콘
                Icon(
                  Iconsax.cake,
                  size: 20,
                  color: ddayColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
