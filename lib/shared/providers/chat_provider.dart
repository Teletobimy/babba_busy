import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 현재 그룹의 채팅 메시지 목록 (최근 100개)
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('chat_messages')
      .orderBy('createdAt', descending: false)
      .limitToLast(100)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
});

/// 읽지 않은 메시지 수
final unreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(chatMessagesProvider).value ?? [];
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  return messages.where((msg) => !msg.isReadBy(user.uid)).length;
});

/// 마지막 메시지
final lastChatMessageProvider = Provider<ChatMessage?>((ref) {
  final messages = ref.watch(chatMessagesProvider).value ?? [];
  if (messages.isEmpty) return null;
  return messages.last;
});

/// 채팅 서비스
final chatServiceProvider = Provider<ChatService>((ref) => ChatService(ref));

class ChatService {
  final Ref _ref;
  ChatService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  /// 메시지 전송
  Future<void> sendMessage({
    required String content,
    String? imageUrl,
    MessageType type = MessageType.text,
  }) async {
    final membership = _ref.read(currentMembershipProvider);
    final user = _ref.read(currentUserProvider);
    final userData = _ref.read(currentUserDataProvider).value;
    final firestore = _firestore;

    if (membership == null || user == null || firestore == null) return;

    final senderName = membership.name.isNotEmpty
        ? membership.name
        : (userData?.name ?? user.displayName ?? '사용자');

    final message = ChatMessage(
      id: '',
      familyId: membership.groupId,
      senderId: user.uid,
      senderName: senderName,
      senderAvatarUrl: userData?.avatarUrl ?? user.photoURL,
      content: content,
      imageUrl: imageUrl,
      type: type,
      createdAt: DateTime.now(),
      readBy: [user.uid], // 보낸 사람은 자동으로 읽음 처리
    );

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('chat_messages')
        .add(message.toFirestore());
  }

  /// 시스템 메시지 전송 (입장/퇴장 등)
  Future<void> sendSystemMessage(String content) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    final message = ChatMessage(
      id: '',
      familyId: membership.groupId,
      senderId: 'system',
      senderName: '시스템',
      content: content,
      type: MessageType.system,
      createdAt: DateTime.now(),
      readBy: [],
    );

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('chat_messages')
        .add(message.toFirestore());
  }

  /// 메시지 읽음 처리
  Future<void> markAsRead(String messageId) async {
    final membership = _ref.read(currentMembershipProvider);
    final user = _ref.read(currentUserProvider);
    final firestore = _firestore;
    if (membership == null || user == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('chat_messages')
        .doc(messageId)
        .update({
      'readBy': FieldValue.arrayUnion([user.uid]),
    });
  }

  /// 모든 메시지 읽음 처리 (Batch 사용으로 성능 최적화)
  Future<void> markAllAsRead() async {
    final messages = _ref.read(chatMessagesProvider).value ?? [];
    final user = _ref.read(currentUserProvider);
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (user == null || membership == null || firestore == null) return;

    final unreadMessages = messages.where((msg) => !msg.isReadBy(user.uid)).toList();
    if (unreadMessages.isEmpty) return;

    // Firestore batch 사용: 최대 500개 작업을 한 번의 네트워크 요청으로 처리
    // 500개 초과 시 여러 batch로 분할
    const batchLimit = 500;
    for (var i = 0; i < unreadMessages.length; i += batchLimit) {
      final batch = firestore.batch();
      final end = (i + batchLimit < unreadMessages.length)
          ? i + batchLimit
          : unreadMessages.length;

      for (var j = i; j < end; j++) {
        final docRef = firestore
            .collection('families')
            .doc(membership.groupId)
            .collection('chat_messages')
            .doc(unreadMessages[j].id);
        batch.update(docRef, {
          'readBy': FieldValue.arrayUnion([user.uid]),
        });
      }

      await batch.commit();
    }
  }

  /// 메시지 삭제
  Future<void> deleteMessage(String messageId) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('chat_messages')
        .doc(messageId)
        .delete();
  }
}
