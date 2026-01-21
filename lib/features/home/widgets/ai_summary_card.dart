import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/providers/smart_provider.dart';

/// AI 요약 상태
final aiSummaryExpandedProvider = StateProvider<bool>((ref) => true);

/// AI 요약 카드
class AiSummaryCard extends ConsumerWidget {
  const AiSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(aiSummaryExpandedProvider);
    
    // Smart Provider 사용
    final todos = ref.watch(smartTodosProvider);
    final upcomingTodos = ref.watch(smartUpcomingTodosProvider);

    final pendingCount = todos.where((t) => !t.isCompleted).length;
    final completedToday = todos.where((t) => t.isCompleted).length;
    final upcomingCount = upcomingTodos.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientCard(
      gradient: isDark
          ? AppColors.primaryGradientDark
          : AppColors.primaryGradientLight,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 헤더
          InkWell(
            onTap: () {
              ref.read(aiSummaryExpandedProvider.notifier).state = !isExpanded;
            },
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      Iconsax.magic_star5,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 오늘의 요약',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '할 일 $pendingCount개 남음 • 다가오는 일정 $upcomingCount개',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 확장된 내용
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM,
                0,
                AppTheme.spacingM,
                AppTheme.spacingM,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _generateSummary(pendingCount, completedToday, upcomingCount),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 통계 미니 카드
                    Row(
                      children: [
                        _StatChip(
                          icon: Iconsax.task_square,
                          label: '남은 할일',
                          value: '$pendingCount',
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Iconsax.tick_circle,
                          label: '완료',
                          value: '$completedToday',
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Iconsax.calendar_1,
                          label: '일정',
                          value: '$upcomingCount',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _generateSummary(int pending, int completed, int events) {
    final List<String> messages = [];
    
    if (pending == 0 && completed == 0) {
      messages.add('오늘의 할 일이 아직 없어요. 새로운 할 일을 추가해보세요! 🌟');
    } else if (pending == 0 && completed > 0) {
      messages.add('대단해요! 오늘 할 일을 모두 완료했어요. 잘 쉬세요! 🎉');
    } else if (pending <= 3) {
      messages.add('오늘 할 일이 $pending개 남았어요. 조금만 더 힘내세요! 💪');
    } else {
      messages.add('오늘 할 일이 $pending개 있어요. 중요한 것부터 하나씩 해결해보아요! 📝');
    }
    
    if (events > 0) {
      messages.add('이번 주 $events개의 일정이 예정되어 있어요. 📅');
    }
    
    return messages.join('\n');
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label $value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
