import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/models/family_member.dart';
import '../../shared/models/recurrence.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/utils/color_utils.dart';
import '../../shared/widgets/member_avatar.dart';

/// 로테이션 주기
enum RotationInterval { daily, weekly }

/// 로테이션 주기 provider
final rotationIntervalProvider = StateProvider<RotationInterval>((ref) => RotationInterval.weekly);

/// 집안일 로테이션 화면
class ChoreRotationScreen extends ConsumerWidget {
  const ChoreRotationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(smartMembersProvider);
    final allTodos = ref.watch(smartTodosProvider);
    final interval = ref.watch(rotationIntervalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 반복 할일만 필터 (집안일 후보)
    final recurringTodos = allTodos.where((t) =>
      t.recurrenceType != RecurrenceType.none
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('집안일 로테이션'),
        centerTitle: true,
        actions: [
          SegmentedButton<RotationInterval>(
            segments: const [
              ButtonSegment(value: RotationInterval.daily, label: Text('매일')),
              ButtonSegment(value: RotationInterval.weekly, label: Text('매주')),
            ],
            selected: {interval},
            onSelectionChanged: (s) =>
                ref.read(rotationIntervalProvider.notifier).state = s.first,
            style: SegmentedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: recurringTodos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.broom, size: 48, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  const SizedBox(height: 16),
                  Text(
                    '반복 할일이 없어요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '반복 할일을 추가하면 로테이션을 설정할 수 있어요',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              itemCount: recurringTodos.length,
              itemBuilder: (context, index) {
                final todo = recurringTodos[index];
                return _ChoreRotationTile(
                  todo: todo,
                  members: members,
                  interval: interval,
                  isDark: isDark,
                );
              },
            ),
    );
  }
}

class _ChoreRotationTile extends ConsumerWidget {
  final TodoItem todo;
  final List<FamilyMember> members;
  final RotationInterval interval;
  final bool isDark;

  const _ChoreRotationTile({
    required this.todo,
    required this.members,
    required this.interval,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 현재 담당자
    final currentAssignee = members.where((m) => todo.isAssignedTo(m.id)).toList();
    final assigneeColor = currentAssignee.isNotEmpty
        ? parseHexColor(currentAssignee.first.color, fallback: AppColors.memberColors[0])
        : AppColors.memberColors[0];

    // 다음 담당자 (로테이션 시뮬레이션)
    final memberIds = members.map((m) => m.id).toList();
    final currentIndex = currentAssignee.isNotEmpty
        ? memberIds.indexOf(currentAssignee.first.id)
        : 0;
    final nextIndex = (currentIndex + 1) % memberIds.length;
    final nextMember = members.isNotEmpty ? members[nextIndex] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        border: Border(
          left: BorderSide(color: assigneeColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  todo.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  todo.recurrenceType.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryOnWhite,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 현재 → 다음 담당자
          Row(
            children: [
              if (currentAssignee.isNotEmpty) ...[
                MemberAvatar(member: currentAssignee.first, size: 24),
                const SizedBox(width: 6),
                Text(
                  currentAssignee.first.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                Text(
                  '미지정',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3,
                size: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 8),
              if (nextMember != null) ...[
                MemberAvatar(member: nextMember, size: 24),
                const SizedBox(width: 6),
                Text(
                  nextMember.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 로테이션 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (nextMember == null) return;
                final resolvedId = todo.parentTodoId ?? todo.id;
                ref.read(todoServiceProvider).updateTodo(
                  resolvedId,
                  assigneeId: nextMember.id,
                  participants: [nextMember.id],
                );
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${todo.title} → ${nextMember.name}에게 넘김'),
                  duration: const Duration(seconds: 8),
                ));
              },
              icon: const Icon(Iconsax.refresh, size: 16),
              label: Text(
                '${interval == RotationInterval.daily ? '오늘' : '이번 주'} 넘기기',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
