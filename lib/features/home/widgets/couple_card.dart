import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/utils/date_utils.dart' as date_utils;
import '../providers/home_filters.dart';

/// 커플 전용 대시보드 카드 (2인 그룹일 때만 표시)
///
/// 파트너의 오늘 할일 진행 상황, 함께하는 할일, 응원 메시지를 표시합니다.
/// 탭하면 파트너 할일 필터를 토글합니다.
class CoupleCard extends ConsumerWidget {
  const CoupleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(smartMembersProvider);
    if (members.length != 2) return const SizedBox.shrink();

    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final partner = members.firstWhere(
      (m) => m.id != currentUser.uid,
      orElse: () => members.last,
    );

    final allTodos = ref.watch(smartTodosProvider);
    final today = date_utils.normalizeDate(DateTime.now());

    // -- Partner's today stats --
    final partnerTodosToday = allTodos.where((t) {
      if (!t.isAssignedTo(partner.id)) return false;
      final dueDate = t.dueDate;
      if (dueDate == null) return false;
      return date_utils.normalizeDate(dueDate).isAtSameMomentAs(today);
    }).toList();
    final partnerCompletedToday =
        partnerTodosToday.where((t) => t.isCompleted).length;
    final partnerTotalToday = partnerTodosToday.length;
    final todayProgress =
        partnerTotalToday > 0 ? partnerCompletedToday / partnerTotalToday : 0.0;

    // -- Partner's overall pending count --
    final partnerAllPending =
        allTodos.where((t) => t.isAssignedTo(partner.id) && !t.isCompleted).length;

    // -- Shared todos (both assigned) --
    final sharedTodos = allTodos
        .where(
          (t) =>
              t.participants.length > 1 &&
              t.isAssignedTo(currentUser.uid) &&
              t.isAssignedTo(partner.id),
        )
        .toList();
    final sharedPending = sharedTodos.where((t) => !t.isCompleted).length;
    final sharedCompleted = sharedTodos.where((t) => t.isCompleted).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFilteredToPartner =
        ref.watch(selectedMemberFilterProvider) == partner.id;

    return GestureDetector(
      onTap: () {
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
                    ref.read(selectedMemberFilterProvider.notifier).state = null,
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
            // -- Header: avatar + name + shared badge --
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
                        _buildSubtitle(
                          partnerTotalToday,
                          partnerCompletedToday,
                          partnerAllPending,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Shared todos badge
                if (sharedPending > 0 || sharedCompleted > 0)
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
                          '함께 ${sharedPending + sharedCompleted}개',
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

            // -- Progress bar (today) --
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: todayProgress,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(
                  todayProgress >= 1.0
                      ? AppColors.successLight
                      : AppColors.accentLight,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // -- Stats row --
            Row(
              children: [
                // Today progress text
                Expanded(
                  child: Text(
                    partnerTotalToday > 0
                        ? '$partnerCompletedToday/$partnerTotalToday 완료 (${(todayProgress * 100).toInt()}%)'
                        : '오늘 할일 없음',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                // Motivational message
                Text(
                  _motivationalMessage(
                    todayProgress,
                    partnerTotalToday,
                    sharedCompleted,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: todayProgress >= 1.0
                        ? AppColors.successLight
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a subtitle showing today's count plus overall pending.
  String _buildSubtitle(int totalToday, int completedToday, int allPending) {
    if (totalToday == 0 && allPending == 0) {
      return '할일이 비어있어요';
    }
    if (totalToday == 0) {
      return '전체 $allPending개 남음';
    }
    final pendingToday = totalToday - completedToday;
    return '오늘 $pendingToday개 남음';
  }

  /// A short motivational message based on partner's progress.
  String _motivationalMessage(
    double progress,
    int totalToday,
    int sharedCompleted,
  ) {
    if (totalToday == 0) return '';
    if (progress >= 1.0) return '모두 완료!';
    if (progress >= 0.7) return '거의 다 했어요';
    if (sharedCompleted > 0) return '함께 잘하고 있어요';
    if (progress >= 0.3) return '열심히 하는 중';
    return '화이팅!';
  }
}
