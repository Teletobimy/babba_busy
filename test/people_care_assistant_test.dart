import 'package:babba/shared/models/person.dart';
import 'package:babba/shared/utils/people_care_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('people_care_assistant', () {
    test(
      'assigns high care score for imminent birthday and long inactivity',
      () {
        final now = DateTime(2026, 1, 10);
        final person = _buildPerson(
          id: 'p1',
          name: '엄마',
          relationship: PersonRelationship.family,
          birthday: DateTime(1980, 1, 12),
          lastContactAt: now.subtract(const Duration(days: 40)),
          lifeContextSummary: '최근 병원 치료 중',
        );

        final score = calculateCarePriorityScore(person, now: now);

        expect(score, greaterThanOrEqualTo(85));
      },
    );

    test('removes taboo gift keywords and appends budget range', () {
      final now = DateTime(2026, 3, 5);
      final person = _buildPerson(
        id: 'p2',
        name: '친구',
        relationship: PersonRelationship.friend,
        birthday: DateTime(1995, 3, 10),
        mbti: 'INFP',
        giftPreference: const GiftPreference(
          likes: ['커피'],
          taboo: ['꽃'],
          budgetMin: 30000,
          budgetMax: 50000,
        ),
      );

      final ideas = recommendGiftIdeas(person, max: 6, now: now);

      expect(ideas, isNotEmpty);
      expect(ideas.first, contains('커피 관련 선물'));
      expect(ideas.every((idea) => idea.contains('(3만원~5만원)')), isTrue);
      expect(ideas.any((idea) => idea.contains('꽃')), isFalse);
    });

    test('buildTopCareTargets returns sorted targets with limit', () {
      final now = DateTime(2026, 6, 1);
      final people = [
        _buildPerson(
          id: 'high',
          name: '가족A',
          relationship: PersonRelationship.family,
          birthday: DateTime(1988, 6, 2),
          lastContactAt: now.subtract(const Duration(days: 30)),
        ),
        _buildPerson(
          id: 'mid',
          name: '친구B',
          relationship: PersonRelationship.friend,
          birthday: DateTime(1992, 6, 20),
          lastContactAt: now.subtract(const Duration(days: 5)),
        ),
        _buildPerson(
          id: 'low',
          name: '동료C',
          relationship: PersonRelationship.colleague,
          birthday: DateTime(1990, 12, 20),
          lastContactAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final targets = buildTopCareTargets(people, limit: 2, now: now);

      expect(targets.length, 2);
      expect(targets.first.person.id, 'high');
      expect(targets.first.score, greaterThanOrEqualTo(targets.last.score));
    });
  });
}

Person _buildPerson({
  required String id,
  required String name,
  String? relationship,
  DateTime? birthday,
  DateTime? lastContactAt,
  String? lifeContextSummary,
  String? mbti,
  GiftPreference? giftPreference,
}) {
  return Person(
    id: id,
    familyId: 'f1',
    name: name,
    relationship: relationship,
    birthday: birthday,
    lastContactAt: lastContactAt,
    lifeContextSummary: lifeContextSummary,
    mbti: mbti,
    giftPreference: giftPreference,
    createdAt: DateTime(2026, 1, 1),
    createdBy: 'u1',
  );
}
