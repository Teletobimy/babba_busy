import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/widgets/member_avatar.dart';
import 'widgets/time_overlap_chart.dart';

/// 선택된 멤버 필터 (함께하는 시간 찾기용)
final togetherSelectedMembersProvider = StateProvider<Set<String>>((ref) => {});

/// 선택된 날짜
final togetherSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 함께하는 시간 찾기 화면
class TogetherTimeScreen extends ConsumerWidget {
  const TogetherTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(smartMembersProvider);
    final selectedMemberIds = ref.watch(togetherSelectedMembersProvider);
    final selectedDate = ref.watch(togetherSelectedDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 선택된 날짜의 모든 할일
    final allTodos = ref.watch(smartTodosForDateProvider(selectedDate));

    // 멤버별 busy 시간대 계산
    final busySlots = <String, List<TimeSlotData>>{};
    for (final member in members) {
      final memberTodos = allTodos
          .where((t) => t.isAssignedTo(member.id) && t.hasTime && t.startTime != null)
          .toList();
      busySlots[member.id] = memberTodos.map((t) {
        final end = t.endTime ?? t.startTime!.add(const Duration(hours: 1));
        return TimeSlotData(
          start: t.startTime!.hour + t.startTime!.minute / 60,
          end: end.hour + end.minute / 60,
          title: t.title,
        );
      }).toList();
    }

    // 선택된 멤버들의 겹치는 빈 시간 계산
    final freeSlots = _calculateFreeSlots(
      selectedMemberIds.isEmpty ? members.map((m) => m.id).toSet() : selectedMemberIds,
      busySlots,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('함께하는 시간 찾기'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 날짜 선택
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    ref.read(togetherSelectedDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1));
                  },
                  icon: const Icon(Iconsax.arrow_left_2, size: 20),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      ref.read(togetherSelectedDateProvider.notifier).state = picked;
                    }
                  },
                  child: Text(
                    DateFormat('M월 d일 (E)', 'ko_KR').format(selectedDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(togetherSelectedDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1));
                  },
                  icon: const Icon(Iconsax.arrow_right_3, size: 20),
                ),
              ],
            ),
          ),

          // 멤버 선택 칩
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingL,
              vertical: AppTheme.spacingS,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((member) {
                final isSelected = selectedMemberIds.isEmpty || selectedMemberIds.contains(member.id);
                return FilterChip(
                  avatar: MemberAvatar(member: member, size: 20),
                  label: Text(member.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    final current = Set<String>.from(selectedMemberIds);
                    if (current.isEmpty) {
                      // 첫 토글: 모두 선택 → 해당 멤버만 해제
                      current.addAll(members.map((m) => m.id));
                      current.remove(member.id);
                    } else if (selected) {
                      current.add(member.id);
                    } else {
                      current.remove(member.id);
                    }
                    if (current.length == members.length) current.clear(); // 모두 선택 = 필터 없음
                    ref.read(togetherSelectedMembersProvider.notifier).state = current;
                  },
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // 타임라인 차트
          Expanded(
            child: TimeOverlapChart(
              members: members,
              selectedMemberIds: selectedMemberIds,
              busySlots: busySlots,
              freeSlots: freeSlots,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  /// 선택된 멤버들의 공통 빈 시간 계산
  List<TimeSlotData> _calculateFreeSlots(
    Set<String> memberIds,
    Map<String, List<TimeSlotData>> busySlots,
  ) {
    if (memberIds.isEmpty) return [];

    // 모든 선택된 멤버의 busy 시간 합치기
    final allBusy = <TimeSlotData>[];
    for (final id in memberIds) {
      allBusy.addAll(busySlots[id] ?? []);
    }

    if (allBusy.isEmpty) {
      return [TimeSlotData(start: 8, end: 22, title: '종일 가능')];
    }

    // busy 구간 정렬 및 병합
    allBusy.sort((a, b) => a.start.compareTo(b.start));
    final merged = <TimeSlotData>[];
    var current = allBusy.first;
    for (var i = 1; i < allBusy.length; i++) {
      if (allBusy[i].start <= current.end) {
        current = TimeSlotData(
          start: current.start,
          end: current.end > allBusy[i].end ? current.end : allBusy[i].end,
          title: '',
        );
      } else {
        merged.add(current);
        current = allBusy[i];
      }
    }
    merged.add(current);

    // 8시~22시 사이의 빈 구간 찾기
    final free = <TimeSlotData>[];
    var lastEnd = 8.0;
    for (final busy in merged) {
      if (busy.start > lastEnd && busy.start > 8) {
        final freeStart = lastEnd < 8 ? 8.0 : lastEnd;
        if (busy.start - freeStart >= 0.5) {
          free.add(TimeSlotData(start: freeStart, end: busy.start, title: '가능'));
        }
      }
      if (busy.end > lastEnd) lastEnd = busy.end;
    }
    if (lastEnd < 22) {
      free.add(TimeSlotData(start: lastEnd, end: 22, title: '가능'));
    }

    return free;
  }
}

