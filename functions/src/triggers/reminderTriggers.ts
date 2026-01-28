import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 매 분 실행: 알림 발송 대상 확인 및 발송
 * Cloud Scheduler API 활성화 필요
 */
export const checkReminders = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const nowDate = now.toDate();
    const db = admin.firestore();

    try {
      // CollectionGroup 쿼리: 모든 사용자의 todos에서 알림 설정된 미완료 항목
      const todosSnapshot = await db.collectionGroup("todos")
        .where("isCompleted", "==", false)
        .get();

      const batch = db.batch();
      const notifications: Promise<void>[] = [];
      let processedCount = 0;

      for (const doc of todosSnapshot.docs) {
        const todo = doc.data();
        const reminderMinutes: number[] = todo.reminderMinutes || [];
        const remindersSent: number[] = todo.remindersSent || [];

        // 알림 설정이 없으면 스킵
        if (reminderMinutes.length === 0) continue;

        // 이벤트 시간 결정 (startTime 우선, 없으면 dueDate)
        const eventTime = todo.startTime?.toDate() || todo.dueDate?.toDate();
        if (!eventTime) continue;

        for (const minutes of reminderMinutes) {
          // 이미 발송된 알림 스킵
          if (remindersSent.includes(minutes)) continue;

          // 알림 발송 시점 계산
          const reminderTime = new Date(eventTime.getTime() - minutes * 60 * 1000);

          // 현재 시각이 알림 시점 +-30초 범위 내인지 확인
          const timeDiff = Math.abs(nowDate.getTime() - reminderTime.getTime());
          if (timeDiff <= 30000) { // 30초 허용 오차
            // 알림 대상자 결정
            const targetUserIds = getNotificationTargets(todo);
            if (targetUserIds.length > 0) {
              const { title, body } = MessageTemplates.todoReminder(
                todo.title || "일정",
                minutes
              );

              notifications.push(
                sendNotification(targetUserIds, {
                  title,
                  body,
                  data: {
                    type: todo.eventType === "event" ? "event" : "todo",
                    todoId: doc.id,
                    route: "/home",
                  },
                  tag: `reminder_${doc.id}_${minutes}`,
                })
              );

              // remindersSent 업데이트
              batch.update(doc.ref, {
                remindersSent: admin.firestore.FieldValue.arrayUnion(minutes),
              });

              processedCount++;
            }
          }
        }
      }

      if (processedCount > 0) {
        await Promise.all([
          batch.commit(),
          ...notifications,
        ]);
        console.log(`Sent ${processedCount} reminder notifications`);
      }
    } catch (error) {
      console.error("Error checking reminders:", error);
    }
  });

/**
 * 알림 대상자 결정
 */
function getNotificationTargets(todo: admin.firestore.DocumentData): string[] {
  const targets: string[] = [];

  // 소유자
  if (todo.ownerId) targets.push(todo.ownerId);

  // 참여자
  if (todo.participants?.length > 0) {
    for (const p of todo.participants) {
      if (!targets.includes(p)) targets.push(p);
    }
  }

  // 담당자 (하위 호환성)
  if (todo.assigneeId && !targets.includes(todo.assigneeId)) {
    targets.push(todo.assigneeId);
  }

  return targets;
}

/**
 * Todo 완료 시 remindersSent 초기화 (반복 일정 재사용 대비)
 */
export const cleanupRemindersOnComplete = functions.firestore
  .document("users/{userId}/todos/{todoId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // 완료 상태로 변경된 경우 remindersSent 초기화
    if (!before.isCompleted && after.isCompleted) {
      await change.after.ref.update({
        remindersSent: [],
      });
    }
  });
