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
  });

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
    );
  }
}
