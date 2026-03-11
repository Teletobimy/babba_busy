import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/color_utils.dart';
import '../../shared/providers/group_provider.dart';
import '../../features/auth/widgets/group_setup_dialog.dart';

/// 그룹 선택 위젯
class GroupSelector extends ConsumerWidget {
  const GroupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(filteredUserMembershipsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final transitionState = ref.watch(groupTransitionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 로딩 중일 때 shimmer 표시
    if (membershipsAsync.isLoading) {
      return Container(
        width: 100,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey[200],
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      );
    }

    final memberships = membershipsAsync.value ?? [];
    if (memberships.isEmpty) {
      return const SizedBox.shrink();
    }

    // 전환 중일 때 로딩 인디케이터 표시
    if (transitionState.isTransitioning) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              transitionState.targetGroupName ?? '전환 중...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
            ),
          ],
        ),
      );
    }

    // 현재 선택된 그룹 찾기
    final currentGroup = memberships.firstWhere(
      (m) => m.groupId == selectedGroupId,
      orElse: () => memberships.first,
    );

    // 그룹이 하나만 있으면 드롭다운 없이 표시
    if (memberships.length == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.buildings,
              size: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              currentGroup.groupName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    // 여러 그룹이 있으면 드롭다운 표시
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.buildings,
              size: 16,
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              currentGroup.groupName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Iconsax.arrow_down_1,
              size: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        ...memberships.map((membership) {
          final isSelected = membership.groupId == selectedGroupId;
          return PopupMenuItem<String>(
            value: membership.groupId,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: parseHexColor(membership.color, fallback: AppColors.memberColors[0]),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    membership.groupName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primaryLight : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Iconsax.tick_circle,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'create_new',
          child: Row(
            children: [
              Icon(Iconsax.add_circle, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('새 그룹 만들기'),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'join_existing',
          child: Row(
            children: [
              Icon(Iconsax.key, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('초대 코드로 참여'),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'create_new') {
          showDialog(
            context: context,
            builder: (context) => const GroupSetupDialog(),
          );
        } else if (value == 'join_existing') {
          showDialog(
            context: context,
            builder: (context) => const GroupSetupDialog(isJoinOnly: true),
          );
        } else {
          // 선택한 그룹 이름 찾기
          final targetMembership = memberships.firstWhere(
            (m) => m.groupId == value,
            orElse: () => memberships.first,
          );
          await switchGroup(
            ref,
            value,
            groupName: targetMembership.groupName,
            withTransition: true,
          );
        }
      },
    );
  }

}
