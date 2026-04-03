enum PersonalAiActionType {
  todoCreate,
  todoComplete,
  calendarCreate,
  calendarUpdate,
  noteCreate,
  noteUpdate,
  reminderCreate,
}

String? getPersonalScopeBlockedMessage(
  String prompt,
  PersonalAiActionType actionType,
) {
  final normalized = prompt.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (normalized.isEmpty) {
    return null;
  }

  final phrases = switch (actionType) {
    PersonalAiActionType.todoCreate ||
    PersonalAiActionType.todoComplete => const <String>[
      '공유 할 일',
      '공유 할일',
      '가족 할 일',
      '가족 할일',
      '그룹 할 일',
      '그룹 할일',
      '우리 할 일',
      '우리 할일',
      'shared todo',
      'family todo',
      'group todo',
    ],
    PersonalAiActionType.calendarCreate ||
    PersonalAiActionType.calendarUpdate => const <String>[
      '공유 일정',
      '공유 캘린더',
      '가족 캘린더',
      '그룹 캘린더',
      '우리 캘린더',
      'shared calendar',
      'family calendar',
      'group calendar',
    ],
    PersonalAiActionType.noteCreate ||
    PersonalAiActionType.noteUpdate => const <String>[
      '공유 메모',
      '가족 메모',
      '그룹 메모',
      '우리 메모',
      '공동 메모',
      'shared note',
      'shared memo',
    ],
    PersonalAiActionType.reminderCreate => const <String>[
      '공유 알림',
      '공유 리마인더',
      '가족 알림',
      '가족 리마인더',
      '모두에게 알림',
      '전원에게 알림',
      '단톡방에 알림',
      'shared reminder',
      'group reminder',
    ],
  };

  for (final phrase in phrases) {
    if (normalized.contains(phrase)) {
      return switch (actionType) {
        PersonalAiActionType.todoCreate || PersonalAiActionType.todoComplete =>
          '개인 할 일 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.',
        PersonalAiActionType.calendarCreate ||
        PersonalAiActionType.calendarUpdate =>
          '개인 일정 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.',
        PersonalAiActionType.noteCreate || PersonalAiActionType.noteUpdate =>
          '개인 메모 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.',
        PersonalAiActionType.reminderCreate =>
          '개인 리마인더 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.',
      };
    }
  }

  return null;
}
