import * as admin from "firebase-admin";

export interface NotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>;
  tag?: string; // PWA 알림 덮어쓰기용 tag
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

const BATCH_LIMIT = 500;

/**
 * 여러 사용자에게 알림 전송 (배치 최적화 + 분할 처리)
 */
export async function sendNotification(
  userIds: string[],
  payload: NotificationPayload
): Promise<void> {
  if (userIds.length === 0) return;

  const db = admin.firestore();
  const notifType = payload.data.type;

  try {
    // 1. 모든 사용자 문서 한번에 조회 (getAll 사용)
    const userRefs = userIds.map((id) => db.collection("users").doc(id));
    const userDocs = await db.getAll(...userRefs);

    // 2. 알림 전송 대상 필터링 및 FCM 전송 (배치 분할 지원)
    const historyBatches: admin.firestore.WriteBatch[] = [db.batch()];
    const tokenBatches: admin.firestore.WriteBatch[] = [db.batch()];
    let historyBatchCount = 0;
    let tokenBatchCount = 0;

    for (let i = 0; i < userDocs.length; i++) {
      const userDoc = userDocs[i];
      const userId = userIds[i];

      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        continue;
      }

      const userData = userDoc.data() as admin.firestore.DocumentData;

      // 알림 설정 확인 (기본값: true)
      const notificationSettings = userData.notificationSettings || {};
      const enabled = notificationSettings.enabled !== false;
      if (!enabled) {
        console.log(`Notifications disabled for user ${userId}`);
        continue;
      }

      // 타입별 설정 확인 (기본값: true)
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

      // FCM 토큰으로 전송
      const tokens: string[] = userData.fcmTokens || [];
      if (tokens.length === 0) {
        console.log(`No FCM tokens for user ${userId}`);
        continue;
      }

      try {
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
          webpush: payload.tag ? {
            notification: {
              tag: payload.tag,
              renotify: true,
            },
          } : undefined,
        });

        console.log(
          `Sent notification to user ${userId}: ` +
          `${response.successCount} succeeded, ${response.failureCount} failed`
        );

        // 실패한 토큰 제거 (배치 분할 처리)
        if (response.failureCount > 0) {
          const failedTokens: string[] = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push(tokens[idx]);
            }
          });

          if (failedTokens.length > 0) {
            if (tokenBatchCount >= BATCH_LIMIT) {
              tokenBatches.push(db.batch());
              tokenBatchCount = 0;
            }
            tokenBatches[tokenBatches.length - 1].update(userDoc.ref, {
              fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
            });
            tokenBatchCount++;
          }
        }

        // 알림 히스토리 저장 (배치 분할 처리)
        if (historyBatchCount >= BATCH_LIMIT) {
          historyBatches.push(db.batch());
          historyBatchCount = 0;
        }
        const historyRef = userDoc.ref.collection("notificationHistory").doc();
        historyBatches[historyBatches.length - 1].set(historyRef, {
          type: notifType,
          title: payload.title,
          body: payload.body,
          data: payload.data,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          readAt: null,
          actionTaken: false,
        });
        historyBatchCount++;
      } catch (fcmError) {
        console.error(`FCM error for user ${userId}:`, fcmError);
      }
    }

    // 3. 모든 배치 커밋 (빈 배치 제외)
    const commits: Promise<admin.firestore.WriteResult[]>[] = [];
    for (const batch of historyBatches) {
      commits.push(batch.commit());
    }
    for (const batch of tokenBatches) {
      commits.push(batch.commit());
    }
    if (commits.length > 0) {
      await Promise.all(commits);
    }
  } catch (error) {
    console.error("Error in sendNotification:", error);
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
