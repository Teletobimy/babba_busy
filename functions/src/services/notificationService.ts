import * as admin from "firebase-admin";

export interface NotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

/**
 * FCM 채널 ID 반환
 */
function getChannelForType(type: string): string {
  switch (type) {
  case "chat":
    return "babba_chat_channel";
  case "todo":
  case "event":
    return "babba_todo_channel";
  case "business_review":
    return "babba_business_channel";
  case "analysis_complete":
  case "analysis_failed":
    return "babba_analysis_channel";
  default:
    return "babba_default_channel";
  }
}

/**
 * 여러 사용자에게 알림 전송
 */
export async function sendNotification(
  userIds: string[],
  payload: NotificationPayload
): Promise<void> {
  for (const userId of userIds) {
    try {
      // 1. 사용자 문서 조회
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      const userData = userDoc.data();

      if (!userData) {
        console.log(`User ${userId} not found`);
        continue;
      }

      // 2. 알림 설정 확인 (기본값: true)
      const notificationSettings = userData.notificationSettings || {};
      const enabled = notificationSettings.enabled !== false; // undefined는 true로 처리
      if (!enabled) {
        console.log(`Notifications disabled for user ${userId}`);
        continue;
      }

      // 3. 타입별 설정 확인 (기본값: true)
      const notifType = payload.data.type;
      const chatEnabled = notificationSettings.chatEnabled !== false;
      const todoEnabled = notificationSettings.todoEnabled !== false;
      const eventEnabled = notificationSettings.eventEnabled !== false;

      if (notifType === "chat" && !chatEnabled) {
        console.log(`Chat notifications disabled for user ${userId}`);
        continue;
      }
      if (notifType === "todo" && !todoEnabled) {
        console.log(`Todo notifications disabled for user ${userId}`);
        continue;
      }
      if (notifType === "event" && !eventEnabled) {
        console.log(`Event notifications disabled for user ${userId}`);
        continue;
      }

      // 4. FCM 토큰으로 전송
      const tokens = userData.fcmTokens || [];
      if (tokens.length === 0) {
        console.log(`No FCM tokens for user ${userId}`);
        continue;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: {
          priority: "high",
          notification: {
            channelId: getChannelForType(notifType),
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      console.log(
        `Sent notification to user ${userId}: ` +
        `${response.successCount} succeeded, ${response.failureCount} failed`
      );

      // 5. 실패한 토큰 제거
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
          }
        });

        if (failedTokens.length > 0) {
          const updatedTokens = tokens.filter((token: string) => !failedTokens.includes(token));
          await userDoc.ref.update({ fcmTokens: updatedTokens });
          console.log(`Removed ${failedTokens.length} invalid tokens from user ${userId}`);
        }
      }

      // 6. 알림 히스토리 저장
      await userDoc.ref.collection("notificationHistory").add({
        type: notifType,
        title: payload.title,
        body: payload.body,
        data: payload.data,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        readAt: null,
        actionTaken: false,
      });
    } catch (error) {
      console.error(`Error sending notification to user ${userId}:`, error);
    }
  }
}

/**
 * 단일 사용자에게 알림 전송
 */
export async function sendNotificationToUser(
  userId: string,
  payload: NotificationPayload
): Promise<void> {
  await sendNotification([userId], payload);
}
