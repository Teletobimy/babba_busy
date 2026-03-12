import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/utils/color_utils.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 시간 겹침 차트 위젯
class TimeOverlapChart extends StatelessWidget {
  final List<FamilyMember> members;
  final Set<String> selectedMemberIds;
  final Map<String, List<TimeSlotData>> busySlots;
  final List<TimeSlotData> freeSlots;
  final bool isDark;

  const TimeOverlapChart({
    super.key,
    required this.members,
    required this.selectedMemberIds,
    required this.busySlots,
    required this.freeSlots,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeMemberIds = selectedMemberIds.isEmpty
        ? members.map((m) => m.id).toSet()
        : selectedMemberIds;
    final activeMembers = members.where((m) => activeMemberIds.contains(m.id)).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 빈 시간 요약
            if (freeSlots.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppColors.successLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.clock, size: 18, color: AppColors.successLight),
                        const SizedBox(width: 8),
                        Text(
                          '함께 가능한 시간',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.successLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: freeSlots.map((slot) {
                        final duration = slot.end - slot.start;
                        return Chip(
                          avatar: const Icon(Iconsax.timer_1, size: 14),
                          label: Text(
                            '${_formatHour(slot.start)} ~ ${_formatHour(slot.end)} (${duration.toStringAsFixed(duration == duration.roundToDouble() ? 0 : 1)}시간)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: AppTheme.spacingM),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(Iconsax.warning_2, size: 18, color: AppColors.errorLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '오늘은 함께 가능한 시간이 없어요',
                        style: TextStyle(color: AppColors.errorLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.spacingL),

            // 멤버별 타임라인
            Text(
              '멤버별 일정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            ...activeMembers.map((member) => _MemberTimeline(
              member: member,
              busySlots: busySlots[member.id] ?? [],
              isDark: isDark,
            )),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _formatHour(double hour) {
    final h = hour.floor();
    final m = ((hour - h) * 60).round();
    if (m == 0) return '$h시';
    return '$h시 $m분';
  }
}

class _MemberTimeline extends StatelessWidget {
  final FamilyMember member;
  final List<TimeSlotData> busySlots;
  final bool isDark;

  const _MemberTimeline({
    required this.member,
    required this.busySlots,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final memberColor = parseHexColor(member.color, fallback: AppColors.memberColors[0]);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(member: member, size: 24),
              const SizedBox(width: 8),
              Text(
                member.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                busySlots.isEmpty ? '일정 없음' : '${busySlots.length}개 일정',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 8시~22시 타임바
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                const startHour = 8.0;
                const endHour = 22.0;
                const totalHours = endHour - startHour;

                return Stack(
                  children: [
                    // 시간 라벨
                    for (var h = 8; h <= 22; h += 2)
                      Positioned(
                        left: ((h - startHour) / totalHours) * totalWidth - 8,
                        bottom: 0,
                        child: Text(
                          '$h',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    // busy 구간
                    ...busySlots.map((slot) {
                      final left = ((slot.start.clamp(startHour, endHour) - startHour) / totalHours) * totalWidth;
                      final right = ((slot.end.clamp(startHour, endHour) - startHour) / totalHours) * totalWidth;
                      final width = right - left;
                      if (width <= 0) return const SizedBox.shrink();

                      return Positioned(
                        left: left,
                        top: 2,
                        width: width,
                        height: 18,
                        child: Tooltip(
                          message: slot.title,
                          child: Container(
                            decoration: BoxDecoration(
                              color: memberColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.centerLeft,
                            child: width > 40
                                ? Text(
                                    slot.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 시간 슬롯 데이터 (public for cross-file usage)
class TimeSlotData {
  final double start;
  final double end;
  final String title;

  const TimeSlotData({required this.start, required this.end, required this.title});
}
