import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification, sendNotificationToUser } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * Todo 생성 시 알림 전송 (할당된 사용자에게)
 */
export const onTodoCreated = functions.firestore
  .document("families/{familyId}/todos/{todoId}")
  .onCreate(async (snapshot, context) => {
    const familyId = context.params.familyId;
    const todoData = snapshot.data();

    try {
      const creatorId = todoData.createdBy;
      const title = todoData.title || "할일";
      const assigneeId = todoData.assigneeId;
      const participants = todoData.participants || [];

      // 알림 대상자 결정
      let targetUserIds: string[] = [];
      if (participants.length > 0) {
        targetUserIds = participants.filter((id: string) => id !== creatorId);
      } else if (assigneeId && assigneeId !== creatorId) {
        targetUserIds = [assigneeId];
      }

      if (targetUserIds.length === 0) {
        console.log(`No users to notify for todo ${snapshot.id}`);
        return;
      }

      // 생성자 정보 조회
      const creatorDoc = await admin.firestore().collection("users").doc(creatorId).get();
      const creatorData = creatorDoc.data();
      const creatorName = creatorData?.displayName || "사용자";

      // 알림 전송
      const { title: notifTitle, body } = MessageTemplates.todoAssigned(title, creatorName);
      await sendNotification(targetUserIds, {
        title: notifTitle,
        body,
        data: {
          type: "todo",
          familyId,
          todoId: snapshot.id,
          route: "/home",
        },
      });

      console.log(`Sent todo creation notification to ${targetUserIds.length} users`);
    } catch (error) {
      console.error(`Error in todo creation trigger for ${snapshot.id}:`, error);
    }
  });

/**
 * Todo 업데이트 시 알림 전송 (완료 시)
 */
export const onTodoUpdated = functions.firestore
  .document("families/{familyId}/todos/{todoId}")
  .onUpdate(async (change, context) => {
    const familyId = context.params.familyId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    try {
      // 완료 상태 변경 확인
      if (!beforeData.isCompleted && afterData.isCompleted) {
        const creatorId = afterData.createdBy;
        const completerId = afterData.completedBy || afterData.assigneeId;
        const title = afterData.title || "할일";

        // 완료자가 생성자와 다른 경우에만 알림
        if (completerId && completerId !== creatorId) {
          const completerDoc = await admin.firestore().collection("users").doc(completerId).get();
          const completerData = completerDoc.data();
          const completerName = completerData?.displayName || "사용자";

          const { title: notifTitle, body } = MessageTemplates.todoCompleted(title, completerName);
          await sendNotificationToUser(creatorId, {
            title: notifTitle,
            body,
            data: {
              type: "todo",
              familyId,
              todoId: change.after.id,
              route: "/home",
            },
          });

          console.log(`Sent todo completion notification to creator ${creatorId}`);
        }
      }
    } catch (error) {
      console.error(`Error in todo update trigger for ${change.after.id}:`, error);
    }
  });

/**
 * Event 생성 시 알림 전송 (참여자에게)
 */
export const onEventCreated = functions.firestore
  .document("families/{familyId}/events/{eventId}")
  .onCreate(async (snapshot, context) => {
    const familyId = context.params.familyId;
    const eventData = snapshot.data();

    try {
      const creatorId = eventData.createdBy;
      const title = eventData.title || "일정";
      const participants = eventData.participants || [];

      // 생성자 제외한 참여자들에게 알림
      const targetUserIds = participants.filter((id: string) => id !== creatorId);

      if (targetUserIds.length === 0) {
        console.log(`No participants to notify for event ${snapshot.id}`);
        return;
      }

      // 생성자 정보 조회
      const creatorDoc = await admin.firestore().collection("users").doc(creatorId).get();
      const creatorData = creatorDoc.data();
      const creatorName = creatorData?.displayName || "사용자";

      // 알림 전송
      const { title: notifTitle, body } = MessageTemplates.eventCreated(title, creatorName);
      await sendNotification(targetUserIds, {
        title: notifTitle,
        body,
        data: {
          type: "event",
          familyId,
          eventId: snapshot.id,
          route: "/home",
        },
      });

      console.log(`Sent event creation notification to ${targetUserIds.length} participants`);
    } catch (error) {
      console.error(`Error in event creation trigger for ${snapshot.id}:`, error);
    }
  });
