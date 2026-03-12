import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/activity_provider.dart';

/// 최근 활동 피드 카드
class ActivityFeedCard extends ConsumerWidget {
  const ActivityFeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(recentActivityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 활동',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingS),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
          ),
          child: Column(
            children: activities.take(5).map((activity) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      activity.type == ActivityType.completed
                          ? Iconsax.tick_circle
                          : Iconsax.add_circle,
                      size: 16,
                      color: activity.type == ActivityType.completed
                          ? AppColors.successLight
                          : AppColors.primaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text: activity.memberName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: activity.type == ActivityType.completed
                                  ? '님이 '
                                  : '님이 생성: ',
                            ),
                            TextSpan(
                              text: '"${activity.todoTitle}"',
                            ),
                            if (activity.type == ActivityType.completed)
                              const TextSpan(text: ' 완료'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(activity.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
