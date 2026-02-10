import 'package:cloud_firestore/cloud_firestore.dart';

/// 채팅 메시지 타입
enum MessageType { text, image, file, system }

/// 채팅 메시지 모델
class ChatMessage {
  final String id;
  final String familyId;
  final String senderId;
  final String senderName; // 캐싱된 발신자 이름
  final String? senderAvatarUrl;
  final String content;
  final String? imageUrl;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.imageUrl,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
    required this.type,
    required this.createdAt,
    required this.readBy,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatarUrl: data['senderAvatarUrl'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      attachmentUrl: data['attachmentUrl'],
      attachmentName: data['attachmentName'],
      attachmentMimeType: data['attachmentMimeType'],
      attachmentSizeBytes: (data['attachmentSizeBytes'] as num?)?.toInt(),
      type: _parseMessageType(data['type']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'content': content,
      'imageUrl': imageUrl,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentMimeType': attachmentMimeType,
      'attachmentSizeBytes': attachmentSizeBytes,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? familyId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? content,
    String? imageUrl,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    MessageType? type,
    DateTime? createdAt,
    List<String>? readBy,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes ?? this.attachmentSizeBytes,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      readBy: readBy ?? this.readBy,
    );
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  /// 현재 사용자가 보낸 메시지인지 확인
  bool isSentBy(String userId) => senderId == userId;

  /// 메시지를 읽었는지 확인
  bool isReadBy(String userId) => readBy.contains(userId);

  /// 시간 포맷 (오전/오후 시:분)
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period $displayHour:$minute';
  }
}
