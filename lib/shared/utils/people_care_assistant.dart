import '../models/person.dart';

class PeopleCareTarget {
  final Person person;
  final int score;
  final List<String> reasons;
  final List<String> giftSuggestions;

  const PeopleCareTarget({
    required this.person,
    required this.score,
    required this.reasons,
    required this.giftSuggestions,
  });
}

int calculateCarePriorityScore(Person person, {DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  var score = 0;

  final relationshipWeight = switch (person.relationship) {
    PersonRelationship.family => 20,
    PersonRelationship.friend => 15,
    PersonRelationship.colleague => 8,
    PersonRelationship.school => 8,
    PersonRelationship.neighbor => 6,
    _ => 5,
  };
  score += relationshipWeight;

  final daysUntilBirthday = _daysUntilBirthday(person.birthday, now: baseNow);
  if (daysUntilBirthday != null) {
    if (daysUntilBirthday <= 3) {
      score += 40;
    } else if (daysUntilBirthday <= 7) {
      score += 25;
    } else if (daysUntilBirthday <= 14) {
      score += 15;
    } else if (daysUntilBirthday <= 30) {
      score += 8;
    }
  }

  final lastTouch = person.lastContactAt ?? person.lastCareActionAt;
  if (lastTouch != null) {
    final gapDays = baseNow.difference(lastTouch).inDays;
    if (gapDays >= 30) {
      score += 15;
    } else if (gapDays >= 14) {
      score += 8;
    }
  } else {
    score += 10;
  }

  if (person.nextCareDueAt != null && !person.nextCareDueAt!.isAfter(baseNow)) {
    score += 20;
  }

  final context = [
    person.lifeContextSummary ?? '',
    person.note ?? '',
    ...person.lifeEvents.map((e) => '${e.title} ${e.note ?? ''} ${e.type}'),
  ].join(' ').toLowerCase();

  if (_containsAny(context, const ['아프', '병원', '치료', '수술', '입원'])) {
    score += 18;
  }
  if (_containsAny(context, const ['출산', '임신', '산모', '육아'])) {
    score += 16;
  }
  if (_containsAny(context, const ['시험', '면접', '이직', '프로젝트', '마감'])) {
    score += 12;
  }

  for (final event in person.lifeEvents) {
    score += (event.importance - 2).clamp(0, 3) * 2;
  }

  final explicit = person.carePriority;
  if (explicit != null) {
    score = ((score * 0.7) + (explicit * 0.3)).round();
  }

  return score.clamp(0, 100);
}

List<String> buildCareReasons(Person person, {DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  final reasons = <String>[];

  final daysUntilBirthday = _daysUntilBirthday(person.birthday, now: baseNow);
  if (daysUntilBirthday != null && daysUntilBirthday <= 14) {
    reasons.add(
      daysUntilBirthday == 0 ? '오늘 생일입니다' : '생일이 $daysUntilBirthday일 남았습니다',
    );
  }

  final lastTouch = person.lastContactAt ?? person.lastCareActionAt;
  if (lastTouch != null) {
    final gap = baseNow.difference(lastTouch).inDays;
    if (gap >= 14) {
      reasons.add('최근 $gap일 동안 챙기지 못했습니다');
    }
  } else {
    reasons.add('최근 연락 기록이 없습니다');
  }

  if (person.lifeContextSummary != null &&
      person.lifeContextSummary!.trim().isNotEmpty) {
    reasons.add('현재 상황: ${person.lifeContextSummary!.trim()}');
  }

  if (person.nextCareDueAt != null && !person.nextCareDueAt!.isAfter(baseNow)) {
    reasons.add('챙김 예정일이 지났습니다');
  }

  if (reasons.isEmpty) {
    reasons.add('관계 유지를 위해 정기적으로 챙기면 좋습니다');
  }

  return reasons.take(4).toList();
}

List<String> recommendGiftIdeas(Person person, {int max = 5, DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  final suggestions = <String>[];
  final context = [
    person.lifeContextSummary ?? '',
    person.note ?? '',
    ...person.lifeEvents.map((e) => '${e.title} ${e.note ?? ''} ${e.type}'),
  ].join(' ').toLowerCase();

  if (_containsAny(context, const ['아프', '병원', '치료', '입원'])) {
    suggestions.addAll(const ['건강식/영양 보충 세트', '보온용품 + 손편지', '병문안 과일/꽃']);
  }

  if (_containsAny(context, const ['출산', '임신', '산모', '육아'])) {
    suggestions.addAll(const ['산모 케어 선물 세트', '출산 축하 꽃 + 간식', '육아 지원 기프트카드']);
  }

  final daysUntilBirthday = _daysUntilBirthday(person.birthday, now: baseNow);
  if ((daysUntilBirthday ?? 999) <= 14) {
    suggestions.addAll(const ['생일 케이크 + 카드', '맞춤형 꽃다발', '취향 기반 소형 선물']);
  }

  final mbti = (person.mbti ?? '').toUpperCase();
  if (mbti.isNotEmpty) {
    if (mbti.startsWith('I')) {
      suggestions.addAll(const ['조용히 즐길 수 있는 취미 키트', '고급 차/커피 세트']);
    }
    if (mbti.startsWith('E')) {
      suggestions.addAll(const ['경험형 선물(식사/전시)', '함께 즐길 티켓']);
    }
    if (mbti.endsWith('J')) {
      suggestions.addAll(const ['실용형 정리/다이어리 아이템', '계획형 기프트 세트']);
    }
    if (mbti.endsWith('P')) {
      suggestions.addAll(const ['자유 선택형 상품권', '감성 소품']);
    }
    if (mbti.contains('F')) {
      suggestions.add('감정 표현이 담긴 손편지 + 소형 선물');
    }
    if (mbti.contains('T')) {
      suggestions.add('실용적인 전자/업무 보조 아이템');
    }
  }

  if (person.giftPreference != null && !person.giftPreference!.isEmpty) {
    final pref = person.giftPreference!;
    for (final like in pref.likes.take(3)) {
      suggestions.insert(0, '${like.trim()} 관련 선물');
    }

    final tabooSet = pref.taboo.map((e) => e.trim().toLowerCase()).toSet();
    if (tabooSet.isNotEmpty) {
      suggestions.removeWhere((item) {
        final lowered = item.toLowerCase();
        for (final taboo in tabooSet) {
          if (taboo.isNotEmpty && lowered.contains(taboo)) {
            return true;
          }
        }
        return false;
      });
    }
  }

  // 중복 제거
  final deduped = <String>[];
  for (final item in suggestions) {
    final normalized = item.trim();
    if (normalized.isEmpty || deduped.contains(normalized)) continue;
    deduped.add(normalized);
    if (deduped.length >= max) break;
  }

  if (deduped.isEmpty) {
    deduped.addAll(const ['감사 손편지 + 커피 기프트', '실용적인 소형 선물', '함께 식사 약속']);
  }

  final pref = person.giftPreference;
  if (pref != null && (pref.budgetMin != null || pref.budgetMax != null)) {
    final budget = _formatBudgetRange(pref.budgetMin, pref.budgetMax);
    return deduped.map((item) => '$item ($budget)').toList();
  }

  return deduped;
}

List<PeopleCareTarget> buildTopCareTargets(
  List<Person> people, {
  int limit = 3,
  DateTime? now,
}) {
  final targets =
      people
          .map(
            (person) => PeopleCareTarget(
              person: person,
              score: calculateCarePriorityScore(person, now: now),
              reasons: buildCareReasons(person, now: now),
              giftSuggestions: recommendGiftIdeas(person, max: 4, now: now),
            ),
          )
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  return targets.take(limit).toList();
}

bool _containsAny(String source, List<String> keywords) {
  for (final keyword in keywords) {
    if (source.contains(keyword)) return true;
  }
  return false;
}

String _formatBudgetRange(int? min, int? max) {
  if (min == null && max == null) return '예산 자유';
  if (min != null && max != null) {
    return '${_shortMoney(min)}~${_shortMoney(max)}';
  }
  if (min != null) return '${_shortMoney(min)} 이상';
  return '${_shortMoney(max!)} 이하';
}

String _shortMoney(int amount) {
  if (amount >= 10000) {
    final asManwon = (amount / 10000).toStringAsFixed(
      amount % 10000 == 0 ? 0 : 1,
    );
    return '$asManwon만원';
  }
  return '$amount원';
}

int? _daysUntilBirthday(DateTime? birthday, {required DateTime now}) {
  if (birthday == null) return null;

  final today = DateTime(now.year, now.month, now.day);
  var nextBirthday = DateTime(today.year, birthday.month, birthday.day);
  if (nextBirthday.isBefore(today)) {
    nextBirthday = DateTime(today.year + 1, birthday.month, birthday.day);
  }
  return nextBirthday.difference(today).inDays;
}
