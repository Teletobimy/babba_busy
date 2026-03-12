import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/models/recurrence.dart';
import '../../shared/providers/todo_provider.dart';
import 'widgets/period_input.dart';

/// 한국 학교 기본 교시 시간
const List<Map<String, String>> defaultPeriods = [
  {'period': '1교시', 'start': '09:00', 'end': '09:50'},
  {'period': '2교시', 'start': '10:00', 'end': '10:50'},
  {'period': '3교시', 'start': '11:00', 'end': '11:50'},
  {'period': '4교시', 'start': '12:00', 'end': '12:50'},
  {'period': '점심', 'start': '12:50', 'end': '13:50'},
  {'period': '5교시', 'start': '13:50', 'end': '14:40'},
  {'period': '6교시', 'start': '14:50', 'end': '15:40'},
  {'period': '7교시', 'start': '15:50', 'end': '16:40'},
];

const _timetableStorageKey = 'timetable_data';

/// 시간표 Notifier (SharedPreferences 영속화)
class TimetableNotifier extends StateNotifier<Map<int, Map<String, String>>> {
  TimetableNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_timetableStorageKey);
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final result = <int, Map<String, String>>{};
      for (final entry in decoded.entries) {
        final weekday = int.tryParse(entry.key);
        if (weekday != null && entry.value is Map) {
          result[weekday] = Map<String, String>.from(entry.value as Map);
        }
      }
      state = result;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = <String, Map<String, String>>{};
    for (final entry in state.entries) {
      serializable[entry.key.toString()] = entry.value;
    }
    await prefs.setString(_timetableStorageKey, jsonEncode(serializable));
  }

  void setSubject(int weekday, String period, String subject) {
    final current = Map<int, Map<String, String>>.from(state);
    current[weekday] = Map<String, String>.from(current[weekday] ?? {});
    if (subject.isEmpty) {
      current[weekday]!.remove(period);
      if (current[weekday]!.isEmpty) current.remove(weekday);
    } else {
      current[weekday]![period] = subject;
    }
    state = current;
    _save();
  }
}

/// 시간표 편집 상태 (영속화)
final timetableProvider =
    StateNotifierProvider<TimetableNotifier, Map<int, Map<String, String>>>(
  (ref) => TimetableNotifier(),
);

/// 학교 시간표 화면
class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetable = ref.watch(timetableProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekdays = ['월', '화', '수', '목', '금'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('시간표'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _syncToCalendar(context, ref, timetable),
            icon: const Icon(Iconsax.calendar_add, size: 22),
            tooltip: '캘린더에 등록',
          ),
          IconButton(
            onPressed: () => _showPeriodSettings(context),
            icon: const Icon(Iconsax.setting_2, size: 22),
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(80),
              border: TableBorder.all(
                color: isDark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.2)
                    : AppColors.textSecondaryLight.withValues(alpha: 0.2),
                width: 0.5,
              ),
              children: [
                // 헤더
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : AppColors.primaryLight.withValues(alpha: 0.1),
                  ),
                  children: [
                    _headerCell('교시', context),
                    ...weekdays.map((d) => _headerCell(d, context)),
                  ],
                ),
                // 교시별 행
                ...defaultPeriods.where((p) => p['period'] != '점심').map((period) {
                  final periodLabel = period['period']!;
                  final periodTime = '${period['start']}\n${period['end']}';

                  return TableRow(
                    children: [
                      _timeCell(periodLabel, periodTime, context, isDark),
                      ...List.generate(5, (dayIndex) {
                        final weekday = dayIndex + 1;
                        final subject = timetable[weekday]?[periodLabel] ?? '';

                        return _subjectCell(
                          context: context,
                          subject: subject,
                          isDark: isDark,
                          onTap: () => _editSubject(
                            context, ref, weekday, periodLabel, subject,
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _timeCell(String label, String time, BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _subjectCell({
    required BuildContext context,
    required String subject,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        child: Text(
          subject.isEmpty ? '-' : subject,
          style: TextStyle(
            fontSize: 12,
            color: subject.isEmpty
                ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight).withValues(alpha: 0.3)
                : null,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _editSubject(
    BuildContext context,
    WidgetRef ref,
    int weekday,
    String period,
    String currentSubject,
  ) {
    final controller = TextEditingController(text: currentSubject);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$period 과목'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '과목명 입력',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(timetableProvider.notifier).setSubject(
                weekday, period, controller.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _syncToCalendar(
    BuildContext context,
    WidgetRef ref,
    Map<int, Map<String, String>> timetable,
  ) async {
    if (timetable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록할 과목이 없습니다. 먼저 시간표를 입력하세요.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캘린더에 등록'),
        content: const Text(
          '시간표의 모든 과목을 주간 반복 일정으로 캘린더에 등록합니다.\n\n이미 등록된 과목은 중복 생성될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('등록'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final todoService = ref.read(todoServiceProvider);
    int count = 0;

    for (final weekdayEntry in timetable.entries) {
      final weekday = weekdayEntry.key; // 1=Mon ~ 5=Fri
      for (final periodEntry in weekdayEntry.value.entries) {
        final periodLabel = periodEntry.key;
        final subject = periodEntry.value;
        if (subject.isEmpty) continue;

        // defaultPeriods에서 시간 찾기
        final periodInfo = defaultPeriods.firstWhere(
          (p) => p['period'] == periodLabel,
          orElse: () => {'start': '09:00', 'end': '09:50'},
        );

        final startParts = periodInfo['start']!.split(':');
        final endParts = periodInfo['end']!.split(':');

        // 다음 해당 요일 날짜 계산
        final now = DateTime.now();
        var targetDate = now;
        while (targetDate.weekday != weekday) {
          targetDate = targetDate.add(const Duration(days: 1));
        }

        final startTime = DateTime(
          targetDate.year, targetDate.month, targetDate.day,
          int.parse(startParts[0]), int.parse(startParts[1]),
        );
        final endTime = DateTime(
          targetDate.year, targetDate.month, targetDate.day,
          int.parse(endParts[0]), int.parse(endParts[1]),
        );

        await todoService.addTodo(
          title: subject,
          startTime: startTime,
          endTime: endTime,
          dueDate: targetDate,
          hasTime: true,
          eventType: TodoEventType.schedule,
          recurrenceType: RecurrenceType.weekly,
          recurrenceDays: [weekday],
        );
        count++;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count개 과목이 캘린더에 등록되었습니다')),
      );
    }
  }

  void _showPeriodSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PeriodSettingsSheet(),
    );
  }
}
