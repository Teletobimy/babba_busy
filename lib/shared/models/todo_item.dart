import 'package:cloud_firestore/cloud_firestore.dart';

/// 할일 모델
class TodoItem {
  final String id;
  final String familyId;
  final String title;
  final String? note;
  final String? assigneeId;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? repeatType; // 'daily', 'weekly', 'monthly', null
  final int priority; // 0: 낮음, 1: 보통, 2: 높음
  final DateTime createdAt;
  final String createdBy;

  // 시간 관련 필드 (Day View 지원)
  final DateTime? startTime;    // 시작 시간
  final DateTime? endTime;      // 종료 시간
  final bool hasTime;           // 시간 정보 유무
  final DateTime? completedAt;  // 완료 시간 (UX용)

  TodoItem({
    required this.id,
    required this.familyId,
    required this.title,
    this.note,
    this.assigneeId,
    required this.isCompleted,
    this.dueDate,
    this.repeatType,
    this.priority = 1,
    required this.createdAt,
    required this.createdBy,
    this.startTime,
    this.endTime,
    this.hasTime = false,
    this.completedAt,
  });

  /// 시간이 지정된 할일인지 여부
  bool get isTimedTodo => hasTime && startTime != null;

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TodoItem(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      title: data['title'] ?? '',
      note: data['note'],
      assigneeId: data['assigneeId'],
      isCompleted: data['isCompleted'] ?? false,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      repeatType: data['repeatType'],
      priority: data['priority'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      hasTime: data['hasTime'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'title': title,
      'note': note,
      'assigneeId': assigneeId,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'repeatType': repeatType,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'hasTime': hasTime,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  TodoItem copyWith({
    String? id,
    String? familyId,
    String? title,
    String? note,
    String? assigneeId,
    bool? isCompleted,
    DateTime? dueDate,
    String? repeatType,
    int? priority,
    DateTime? createdAt,
    String? createdBy,
    DateTime? startTime,
    DateTime? endTime,
    bool? hasTime,
    DateTime? completedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      note: note ?? this.note,
      assigneeId: assigneeId ?? this.assigneeId,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      repeatType: repeatType ?? this.repeatType,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hasTime: hasTime ?? this.hasTime,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
