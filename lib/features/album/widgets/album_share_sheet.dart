import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/group_provider.dart';

/// 앨범 공유 설정 바텀 시트
class AlbumShareSheet extends ConsumerStatefulWidget {
  final List<String> selectedGroupIds;

  const AlbumShareSheet({
    super.key,
    required this.selectedGroupIds,
  });

  @override
  ConsumerState<AlbumShareSheet> createState() => _AlbumShareSheetState();
}

class _AlbumShareSheetState extends ConsumerState<AlbumShareSheet> {
  late List<String> _selectedGroupIds;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds = List.from(widget.selectedGroupIds);
  }

  void _toggleGroup(String groupId) {
    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
    });
  }

  void _selectAll() {
    final memberships = ref.read(filteredUserMembershipsProvider).value ?? [];
    setState(() {
      _selectedGroupIds = memberships.map((m) => m.groupId).toList();
    });
  }

  void _clearAll() {
    setState(() {
      _selectedGroupIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberships = ref.watch(filteredUserMembershipsProvider).value ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '공유할 그룹 선택',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('전체 해제'),
                    ),
                    TextButton(
                      onPressed: _selectAll,
                      child: const Text('전체 선택'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),

          // 나만 보기 옵션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Container(
              decoration: BoxDecoration(
                color: _selectedGroupIds.isEmpty
                    ? AppColors.memoryColor.withValues(alpha: 0.1)
                    : (isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: _selectedGroupIds.isEmpty
                    ? Border.all(color: AppColors.memoryColor)
                    : null,
              ),
              child: ListTile(
                leading: Icon(
                  Iconsax.lock,
                  color:
                      _selectedGroupIds.isEmpty ? AppColors.memoryColor : null,
                ),
                title: Text(
                  '나만 보기 (비공개)',
                  style: TextStyle(
                    fontWeight: _selectedGroupIds.isEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _selectedGroupIds.isEmpty
                        ? AppColors.memoryColor
                        : null,
                  ),
                ),
                subtitle: const Text('이 앨범은 나만 볼 수 있어요'),
                trailing: _selectedGroupIds.isEmpty
                    ? Icon(Iconsax.tick_circle5, color: AppColors.memoryColor)
                    : null,
                onTap: _clearAll,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // 구분선
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                  child: Text(
                    '그룹에 공유',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // 그룹 목록
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              itemCount: memberships.length,
              itemBuilder: (context, index) {
                final membership = memberships[index];
                final isSelected =
                    _selectedGroupIds.contains(membership.groupId);

                return Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.memoryColor.withValues(alpha: 0.1)
                        : (isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border:
                        isSelected ? Border.all(color: AppColors.memoryColor) : null,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(
                              membership.color.replaceFirst('#', '0xFF')))
                          .withValues(alpha: 0.2),
                      child: Icon(
                        Iconsax.people,
                        color: Color(int.parse(
                            membership.color.replaceFirst('#', '0xFF'))),
                      ),
                    ),
                    title: Text(
                      membership.groupName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.memoryColor : null,
                      ),
                    ),
                    subtitle: Text(
                      membership.role == 'owner' ? '관리자' : '멤버',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: isSelected
                        ? Icon(Iconsax.tick_circle5, color: AppColors.memoryColor)
                        : Icon(
                            Iconsax.add_circle,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    onTap: () => _toggleGroup(membership.groupId),
                  ),
                );
              },
            ),
          ),

          // 하단 버튼
          Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spacingL,
              right: AppTheme.spacingL,
              top: AppTheme.spacingM,
              bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingL,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selectedGroupIds),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.memoryColor,
                ),
                child: Text(
                  _selectedGroupIds.isEmpty
                      ? '나만 보기로 저장'
                      : '${_selectedGroupIds.length}개 그룹에 공유',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
