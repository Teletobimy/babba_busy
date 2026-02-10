import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 그룹 멤버 ID 목록 조회 (최적화: memberIds 배열 우선, fallback으로 memberships 쿼리)
 */
async function getGroupMemberIds(familyId: string): Promise<string[]> {
  const db = admin.firestore();

  // 1. families 문서에서 memberIds 배열 확인 (최적화된 경로)
  const familyDoc = await db.collection("families").doc(familyId).get();
  const familyData = familyDoc.data();

  if (familyData?.memberIds && Array.isArray(familyData.memberIds)) {
    // null/undefined 요소 필터링
    return familyData.memberIds.filter(
      (id: unknown): id is string => typeof id === "string" && id.length > 0
    );
  }

  // 2. fallback: memberships 컬렉션 쿼리 (기존 그룹 호환성)
  const membershipsSnapshot = await db
    .collection("memberships")
    .where("groupId", "==", familyId)
    .get();

  return membershipsSnapshot.docs.map((doc) => doc.data().userId as string);
}

/**
 * Chat 메시지 생성 시 알림 전송
 */
export const onChatMessageCreated = functions.firestore
  .document("families/{familyId}/chat_messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const familyId = context.params.familyId;
    const messageData = snapshot.data();

    try {
      const senderId = messageData.senderId;
      const senderName = messageData.senderName || "사용자";
      const messageType = messageData.type || "text";
      const messageContent = messageData.content || "";
      const attachmentName = messageData.attachmentName || "파일";
      const readBy = messageData.readBy || [];

      // 그룹 멤버 조회 (최적화됨)
      const allMemberIds = await getGroupMemberIds(familyId);

      const memberIds = allMemberIds
        .filter((userId) => userId !== senderId && !readBy.includes(userId));

      if (memberIds.length === 0) {
        console.log(`No members to notify for chat message in family ${familyId}`);
        return;
      }

      // 알림 전송 (tag로 같은 채팅방 알림 덮어쓰기)
      let notification;
      if (messageType === "image") {
        notification = MessageTemplates.chatImageMessage(senderName);
      } else if (messageType === "file") {
        notification = MessageTemplates.chatFileMessage(senderName, attachmentName);
      } else {
        notification = MessageTemplates.chatMessage(senderName, messageContent);
      }

      const { title, body } = notification;
      await sendNotification(memberIds, {
        title,
        body,
        data: {
          type: "chat",
          familyId,
          messageId: snapshot.id,
          route: "/home", // 채팅 전용 화면이 없으므로 홈으로 이동
        },
        tag: `chat_${familyId}`, // PWA: 같은 채팅방 알림은 최신 것으로 덮어씀
      });

      console.log(`Sent chat notification to ${memberIds.length} members in family ${familyId}`);
    } catch (error) {
      console.error(`Error in chat trigger for family ${familyId}:`, error);
    }
  });
