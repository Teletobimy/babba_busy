import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../providers/home_filters.dart';

/// 커플 전용 대시보드 카드 (2인 그룹일 때만 표시)
class CoupleCard extends ConsumerWidget {
  const CoupleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(smartMembersProvider);
    if (members.length != 2) return const SizedBox.shrink();

    final currentUser = ref.watch(currentUserProvider);
    final partner = members.firstWhere(
      (m) => m.id != currentUser?.uid,
      orElse: () => members.last,
    );

    final allTodos = ref.watch(smartTodosProvider);
    final partnerTodos = allTodos
        .where((t) => t.isAssignedTo(partner.id))
        .toList();
    final partnerPending = partnerTodos.where((t) => !t.isCompleted).length;
    final partnerCompleted = partnerTodos.where((t) => t.isCompleted).length;
    final partnerTotal = partnerPending + partnerCompleted;
    final progressRatio = partnerTotal > 0
        ? partnerCompleted / partnerTotal
        : 0.0;

    // 함께 완료한 할일 (둘 다 participants에 포함)
    final sharedCompleted = allTodos
        .where(
          (t) =>
              t.isCompleted &&
              t.participants.length > 1 &&
              currentUser != null &&
              t.isAssignedTo(currentUser.uid) &&
              t.isAssignedTo(partner.id),
        )
        .length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isFilteredToPartner =
        ref.watch(selectedMemberFilterProvider) == partner.id;

    return GestureDetector(
      onTap: () {
        // 파트너 필터 토글
        final current = ref.read(selectedMemberFilterProvider);
        if (current == partner.id) {
          ref.read(selectedMemberFilterProvider.notifier).state = null;
        } else {
          ref.read(selectedMemberFilterProvider.notifier).state = partner.id;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${partner.name}님의 할일만 표시 중'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '해제',
                onPressed: () =>
                    ref.read(selectedMemberFilterProvider.notifier).state =
                        null,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3D2B4D), const Color(0xFF2B3D4D)]
                : [const Color(0xFFFCE4EC), const Color(0xFFF3E5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: isFilteredToPartner
              ? Border.all(color: Colors.pink, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                MemberAvatar(member: partner, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${partner.name}님의 오늘',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '할일 $partnerPending개 남음',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (sharedCompleted > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.heart5,
                          size: 12,
                          color: Colors.pink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '함께 $sharedCompleted개',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.pink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 진행률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressRatio,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressRatio >= 1.0
                      ? AppColors.successLight
                      : AppColors.accentLight,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              partnerTotal > 0
                  ? '${(progressRatio * 100).toInt()}% 완료'
                  : '아직 할일이 없어요',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
