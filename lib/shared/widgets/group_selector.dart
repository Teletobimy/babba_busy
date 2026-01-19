import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/group_provider.dart';

/// 그룹 선택 위젯
class GroupSelector extends ConsumerWidget {
  const GroupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(userMembershipsProvider).value ?? [];
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (memberships.isEmpty) {
      return const SizedBox.shrink();
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
      itemBuilder: (context) => memberships.map((membership) {
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
                  color: _parseColor(membership.color),
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
      }).toList(),
      onSelected: (groupId) async {
        await switchGroup(ref, groupId);
      },
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return AppColors.memberColors[0];
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.memberColors[0];
    }
  }
}
