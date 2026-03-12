import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/report_provider.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/utils/color_utils.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 멤버별 기여도 카드
class MemberStatsCard extends ConsumerWidget {
  const MemberStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(smartMembersProvider);
    final memberCompletion = ref.watch(memberCompletionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCompleted = memberCompletion.values.fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
      ),
      child: Column(
        children: members.map((member) {
          final count = memberCompletion[member.id] ?? 0;
          final ratio = totalCompleted > 0 ? count / totalCompleted : 0.0;
          final memberColor = parseHexColor(member.color, fallback: AppColors.memberColors[0]);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: Row(
              children: [
                MemberAvatar(member: member, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            member.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$count개 (${(ratio * 100).toInt()}%)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(memberColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
