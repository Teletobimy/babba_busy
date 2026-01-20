import 'package:cloud_firestore/cloud_firestore.dart';

/// 메모 모델
class Memo {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String? categoryId;
  final String? categoryName;
  final List<String> tags;
  final bool isPinned;
  final String? aiAnalysis;
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  Memo({
    required this.id,
    required this.userId,
    required this.title,
    this.content = '',
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.isPinned = false,
    this.aiAnalysis,
    this.analyzedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory Memo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Memo(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      categoryId: data['categoryId'],
      categoryName: data['categoryName'],
      tags: List<String>.from(data['tags'] ?? []),
      isPinned: data['isPinned'] ?? false,
      aiAnalysis: data['aiAnalysis'],
      analyzedAt: (data['analyzedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'tags': tags,
      'isPinned': isPinned,
      'aiAnalysis': aiAnalysis,
      'analyzedAt': analyzedAt != null ? Timestamp.fromDate(analyzedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  Memo copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    bool? isPinned,
    String? aiAnalysis,
    DateTime? analyzedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Memo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// 제목이 없으면 내용의 첫 줄을 제목으로 사용
  String get displayTitle {
    if (title.isNotEmpty) return title;
    final firstLine = content.split('\n').first;
    if (firstLine.length > 30) {
      return '${firstLine.substring(0, 30)}...';
    }
    return firstLine.isEmpty ? '제목 없음' : firstLine;
  }

  /// 미리보기 텍스트 (제목 제외 내용의 일부)
  String get previewText {
    final lines = content.split('\n');
    final startIndex = title.isEmpty && lines.isNotEmpty ? 1 : 0;
    final preview = lines.skip(startIndex).take(3).join(' ').trim();
    if (preview.length > 100) {
      return '${preview.substring(0, 100)}...';
    }
    return preview;
  }
}
