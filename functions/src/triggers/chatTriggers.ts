import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

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
      const messageText = messageData.message || "";
      const readBy = messageData.readBy || [];

      // 발신자 정보 조회
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const senderData = senderDoc.data();
      const senderName = senderData?.displayName || "사용자";

      // 그룹 멤버 조회
      const membershipsSnapshot = await admin.firestore()
        .collection("memberships")
        .where("groupId", "==", familyId)
        .get();

      const memberIds = membershipsSnapshot.docs
        .map((doc) => doc.data().userId as string)
        .filter((userId) => userId !== senderId && !readBy.includes(userId));

      if (memberIds.length === 0) {
        console.log(`No members to notify for chat message in family ${familyId}`);
        return;
      }

      // 알림 전송
      const { title, body } = MessageTemplates.chatMessage(senderName, messageText);
      await sendNotification(memberIds, {
        title,
        body,
        data: {
          type: "chat",
          familyId,
          messageId: snapshot.id,
          route: "/chat",
        },
      });

      console.log(`Sent chat notification to ${memberIds.length} members in family ${familyId}`);
    } catch (error) {
      console.error(`Error in chat trigger for family ${familyId}:`, error);
    }
  });
