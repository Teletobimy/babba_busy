import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import 'auth_provider.dart';

/// 이벤트 목록 스트림
final eventsProvider = StreamProvider<List<Event>>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(member.familyId)
      .collection('events')
      .orderBy('startAt')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
});

/// 특정 날짜의 이벤트
final eventsForDateProvider = Provider.family<List<Event>, DateTime>((ref, date) {
  final events = ref.watch(eventsProvider).value ?? [];
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return events.where((event) {
    return event.startAt.isBefore(endOfDay) && event.endAt.isAfter(startOfDay);
  }).toList();
});

/// 이번 주 이벤트
final thisWeekEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsProvider).value ?? [];
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return events.where((event) {
    return event.startAt.isBefore(endOfWeek) && event.endAt.isAfter(startOfWeek);
  }).toList();
});

/// 다가오는 이벤트 (7일 이내)
final upcomingEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsProvider).value ?? [];
  final now = DateTime.now();
  final weekLater = now.add(const Duration(days: 7));

  return events.where((event) {
    return event.startAt.isAfter(now) && event.startAt.isBefore(weekLater);
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
});

/// 이벤트 서비스
final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(ref);
});

class EventService {
  final Ref _ref;

  EventService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _familyId => _ref.read(currentMemberProvider).value?.familyId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _eventsRef {
    if (_familyId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_familyId).collection('events');
  }

  /// 이벤트 추가
  Future<void> addEvent({
    required String title,
    String? description,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
    required List<String> participants,
    String? location,
    String? color,
  }) async {
    final eventsRef = _eventsRef;
    if (eventsRef == null || _userId == null) return;

    await eventsRef.add({
      'familyId': _familyId,
      'title': title,
      'description': description,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'isAllDay': isAllDay,
      'participants': participants,
      'location': location,
      'color': color,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 이벤트 수정
  Future<void> updateEvent(String eventId, {
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    List<String>? participants,
    String? location,
    String? color,
  }) async {
    final eventsRef = _eventsRef;
    if (eventsRef == null) return;
    
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (startAt != null) updates['startAt'] = Timestamp.fromDate(startAt);
    if (endAt != null) updates['endAt'] = Timestamp.fromDate(endAt);
    if (isAllDay != null) updates['isAllDay'] = isAllDay;
    if (participants != null) updates['participants'] = participants;
    if (location != null) updates['location'] = location;
    if (color != null) updates['color'] = color;

    if (updates.isNotEmpty) {
      await eventsRef.doc(eventId).update(updates);
    }
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String eventId) async {
    final eventsRef = _eventsRef;
    if (eventsRef == null) return;
    await eventsRef.doc(eventId).delete();
  }
}
