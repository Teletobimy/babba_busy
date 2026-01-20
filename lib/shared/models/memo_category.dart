import 'package:cloud_firestore/cloud_firestore.dart';

/// 메모 카테고리 모델
class MemoCategory {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final String color;
  final int sortOrder;
  final DateTime createdAt;

  MemoCategory({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
  });

  factory MemoCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemoCategory(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      icon: data['icon'],
      color: data['color'] ?? '#64B5F6',
      sortOrder: data['sortOrder'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  MemoCategory copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return MemoCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 기본 카테고리 정보
class DefaultMemoCategories {
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'diary',
      'name': '일기',
      'icon': 'book_1',
      'color': '#FFB74D',
      'sortOrder': 0,
    },
    {
      'id': 'note',
      'name': '간단메모',
      'icon': 'note_1',
      'color': '#64B5F6',
      'sortOrder': 1,
    },
    {
      'id': 'idea',
      'name': '아이디어',
      'icon': 'lamp_charge',
      'color': '#BA68C8',
      'sortOrder': 2,
    },
    {
      'id': 'todo_memo',
      'name': '할일메모',
      'icon': 'task_square',
      'color': '#4DB6AC',
      'sortOrder': 3,
    },
  ];

  /// userId로 기본 카테고리 목록 생성
  static List<MemoCategory> createDefaults(String userId) {
    final now = DateTime.now();
    return categories.map((c) => MemoCategory(
      id: c['id'] as String,
      userId: userId,
      name: c['name'] as String,
      icon: c['icon'] as String?,
      color: c['color'] as String,
      sortOrder: c['sortOrder'] as int,
      createdAt: now,
    )).toList();
  }
}
