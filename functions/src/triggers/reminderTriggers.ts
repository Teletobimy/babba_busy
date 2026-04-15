import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 다음 알림 시간 계산 (미발송 알림 중 가장 빠른 시간)
 */
function calculateNextReminderAt(
  eventTime: Date,
  reminderMinutes: number[],
  remindersSent: number[]
): Date | null {
  const pendingMinutes = reminderMinutes.filter((m) => !remindersSent.includes(m));
  if (pendingMinutes.length === 0) return null;

  // 미발송 알림 중 가장 빠른 시간 찾기 (가장 큰 minutes 값)
  const maxMinutes = Math.max(...pendingMinutes);
  return new Date(eventTime.getTime() - maxMinutes * 60 * 1000);
}

/**
 * Firestore Timestamp / 문자열 / Date 값을 Date로 정규화
 */
function normalizeDateValue(value: unknown): Date | null {
  if (!value) return null;

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  if (typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  if (typeof value === "object") {
    const maybeToDate = (value as { toDate?: () => Date }).toDate;
    if (typeof maybeToDate === "function") {
      const parsed = maybeToDate.call(value);
      return parsed instanceof Date && !Number.isNaN(parsed.getTime()) ? parsed : null;
    }

    const seconds = (value as { seconds?: unknown }).seconds;
    if (typeof seconds === "number") {
      const parsed = new Date(seconds * 1000);
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    }
  }

  return null;
}

/**
 * reminder 문서의 발송 예정 시각 추출
 */
function getReminderDueAt(reminder: admin.firestore.DocumentData): Date | null {
  return (
    normalizeDateValue(reminder.remindAt) ||
    normalizeDateValue(reminder.remind_at) ||
    normalizeDateValue(reminder.scheduledAt)
  );
}

/**
 * 알림 대상자 결정
 */
function getNotificationTargets(todo: admin.firestore.DocumentData): string[] {
  const targets = new Set<string>();

  const addTarget = (value: unknown): void => {
    if (typeof value === "string" && value.trim()) {
      targets.add(value.trim());
    }
  };

  // 개인 리마인더
  addTarget(todo.userId);

  // 소유자
  addTarget(todo.ownerId);

  // 참여자
  if (Array.isArray(todo.participants)) {
    for (const participant of todo.participants) {
      addTarget(participant);
    }
  }

  // 담당자 (하위 호환성)
  addTarget(todo.assigneeId);

  return Array.from(targets);
}

/**
 * 개인 리마인더용 알림 메시지 생성
 */
function buildStandaloneReminderNotification(
  reminder: admin.firestore.DocumentData
): { title: string; body: string } {
  const reminderLabel = String(
    reminder.message ||
    reminder.title ||
    reminder.note ||
    "설정한 시간"
  ).trim();

  return {
    title: "리마인더 알림",
    body: reminderLabel,
  };
}

type StandaloneReminderRecurrence = "daily" | "weekly" | "monthly";

/**
 * 반복 리마인더 유형 정규화
 */
function getStandaloneReminderRecurrence(
  reminder: admin.firestore.DocumentData
): StandaloneReminderRecurrence | null {
  const recurrence = String(reminder.recurrence || "").trim().toLowerCase();
  if (recurrence === "daily" || recurrence === "weekly" || recurrence === "monthly") {
    return recurrence;
  }
  return null;
}

/**
 * UTC 기준 월 단위 증가 (말일 보정 포함)
 */
function addUtcMonths(base: Date, months: number): Date {
  const year = base.getUTCFullYear();
  const month = base.getUTCMonth();
  const day = base.getUTCDate();
  const hours = base.getUTCHours();
  const minutes = base.getUTCMinutes();
  const seconds = base.getUTCSeconds();
  const milliseconds = base.getUTCMilliseconds();

  const targetMonth = month + months;
  const lastDayOfTargetMonth = new Date(Date.UTC(year, targetMonth + 1, 0)).getUTCDate();
  const targetDay = Math.min(day, lastDayOfTargetMonth);

  return new Date(
    Date.UTC(year, targetMonth, targetDay, hours, minutes, seconds, milliseconds)
  );
}

/**
 * 다음 반복 시각 계산
 */
function calculateNextStandaloneReminderAt(
  remindAt: Date,
  recurrence: StandaloneReminderRecurrence,
  nowDate: Date
): Date {
  let nextReminderAt = new Date(remindAt.getTime());

  const advance = (current: Date): Date => {
    if (recurrence === "daily") {
      return new Date(current.getTime() + 24 * 60 * 60 * 1000);
    }
    if (recurrence === "weekly") {
      return new Date(current.getTime() + 7 * 24 * 60 * 60 * 1000);
    }
    return addUtcMonths(current, 1);
  };

  nextReminderAt = advance(nextReminderAt);

  while (nextReminderAt.getTime() <= nowDate.getTime()) {
    nextReminderAt = advance(nextReminderAt);
  }

  return nextReminderAt;
}

/**
 * 매 분 실행: 알림 발송 대상 확인 및 발송
 * Cloud Scheduler API 활성화 필요
 *
 * 최적화: nextReminderAt 필드를 사용하여 시간 범위 쿼리로 변경
 * - 기존: 모든 미완료 todos 전체 스캔 (O(n))
 * - 개선: 현재 시간 기준 ±1분 범위만 조회 (O(1) ~ O(log n))
 */
export const checkReminders = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const nowDate = now.toDate();
    const db = admin.firestore();

    // 시간 범위: 현재 시간 ±1분 (스케줄러 지연 고려)
    const oneMinuteAgo = new Date(nowDate.getTime() - 60 * 1000);
    const oneMinuteLater = new Date(nowDate.getTime() + 60 * 1000);

    try {
      const BATCH_LIMIT = 500;
      const batches: admin.firestore.WriteBatch[] = [db.batch()];
      const notifications: Promise<void>[] = [];
      let processedCount = 0;
      let batchOperationCount = 0;
      const processedStandaloneOccurrences = new Set<string>();

      const processTodoReminders = async (): Promise<void> => {
        // 최적화된 쿼리: nextReminderAt 시간 범위로 필터링
        const todosSnapshot = await db.collectionGroup("todos")
          .where("isCompleted", "==", false)
          .where("nextReminderAt", ">=", admin.firestore.Timestamp.fromDate(oneMinuteAgo))
          .where("nextReminderAt", "<=", admin.firestore.Timestamp.fromDate(oneMinuteLater))
          .get();

        for (const doc of todosSnapshot.docs) {
          const todo = doc.data();
          const reminderMinutes: number[] = todo.reminderMinutes || [];
          const remindersSent: number[] = todo.remindersSent || [];

          // 이벤트 시간 결정 (startTime 우선, 없으면 dueDate)
          const eventTime =
            normalizeDateValue(todo.startTime) || normalizeDateValue(todo.dueDate);
          if (!eventTime) continue;

          const updatedRemindersSent = [...remindersSent];

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
                    tag: `reminder_${doc.id}`, // 같은 할일은 최신 알림으로 덮어쓰기
                  })
                );

                updatedRemindersSent.push(minutes);
                processedCount++;
              }
            }
          }

          // remindersSent 업데이트 및 nextReminderAt 재계산
          if (updatedRemindersSent.length > remindersSent.length) {
            // 배치 500개 제한 체크
            if (batchOperationCount >= BATCH_LIMIT) {
              batches.push(db.batch());
              batchOperationCount = 0;
            }

            const currentBatch = batches[batches.length - 1];
            const nextReminderAt = calculateNextReminderAt(
              eventTime,
              reminderMinutes,
              updatedRemindersSent
            );

            currentBatch.update(doc.ref, {
              remindersSent: updatedRemindersSent,
              nextReminderAt: nextReminderAt ?
                admin.firestore.Timestamp.fromDate(nextReminderAt) :
                null,
            });
            batchOperationCount++;
          }
        }
      };

      const processStandaloneReminders = async (): Promise<void> => {
        const remindersSnapshot = await db.collection("reminders")
          .where("status", "==", "pending")
          .get();

        for (const doc of remindersSnapshot.docs) {
          const reminder = doc.data();
          const remindAt = getReminderDueAt(reminder);
          if (!remindAt) continue;

          const completedAt = normalizeDateValue(reminder.completedAt);
          if (completedAt) continue;

          const processedAt = normalizeDateValue(reminder.processedAt);
          if (processedAt && processedAt.getTime() >= remindAt.getTime()) continue;

          const timeDiff = Math.abs(nowDate.getTime() - remindAt.getTime());
          if (timeDiff > 30000) continue;

          const occurrenceKey = `${doc.ref.path}:${remindAt.getTime()}`;
          if (processedStandaloneOccurrences.has(occurrenceKey)) continue;
          processedStandaloneOccurrences.add(occurrenceKey);

          const targetUserIds = getNotificationTargets(reminder);
          if (targetUserIds.length === 0) continue;

          const { title, body } = buildStandaloneReminderNotification(reminder);
          const recurrence = getStandaloneReminderRecurrence(reminder);
          const nextReminderAt = recurrence ?
            calculateNextStandaloneReminderAt(remindAt, recurrence, nowDate) :
            null;

          notifications.push(
            sendNotification(targetUserIds, {
              title,
              body,
              data: {
                type: "reminder",
                reminderId: doc.id,
                route: "/home",
              },
              tag: `reminder_${doc.id}`,
            })
          );

          if (batchOperationCount >= BATCH_LIMIT) {
            batches.push(db.batch());
            batchOperationCount = 0;
          }

          if (recurrence && nextReminderAt) {
            batches[batches.length - 1].update(doc.ref, {
              remindAt: admin.firestore.Timestamp.fromDate(nextReminderAt),
              status: "pending",
              processedAt: admin.firestore.Timestamp.fromDate(remindAt),
              completedAt: null,
              updatedAt: now,
              lastError: null,
            });
          } else {
            batches[batches.length - 1].update(doc.ref, {
              status: "completed",
              processedAt: now,
              completedAt: now,
              updatedAt: now,
              lastError: null,
            });
          }
          batchOperationCount++;
          processedCount++;
        }
      };

      await processTodoReminders();
      await processStandaloneReminders();

      if (processedCount > 0) {
        // 모든 배치 커밋
        const batchCommits = batches.map((batch) => batch.commit());
        await Promise.all([
          ...batchCommits,
          ...notifications,
        ]);
        console.log(`Sent ${processedCount} reminder notifications (${batches.length} batches)`);
      }
    } catch (error) {
      console.error("Error checking reminders:", error);
    }
  });

/**
 * 알림 관련 필드만 변경되었는지 확인 (무한 루프 방지)
 */
function isOnlyReminderFieldChange(
  before: admin.firestore.DocumentData,
  after: admin.firestore.DocumentData
): boolean {
  // 알림 관련 필드 제외한 주요 필드들 비교
  const compareTimestamp = (
    a: admin.firestore.Timestamp | undefined,
    b: admin.firestore.Timestamp | undefined
  ): boolean => {
    if (!a && !b) return true;
    if (!a || !b) return false;
    return a.isEqual(b);
  };

  return (
    before.isCompleted === after.isCompleted &&
    before.title === after.title &&
    compareTimestamp(before.startTime, after.startTime) &&
    compareTimestamp(before.dueDate, after.dueDate) &&
    JSON.stringify(before.reminderMinutes) ===
      JSON.stringify(after.reminderMinutes)
  );
}

/**
 * Todo 완료 시 알림 필드 정리 로직 (공통)
 */
async function handleReminderCleanup(
  change: functions.Change<functions.firestore.DocumentSnapshot>
): Promise<void> {
  const before = change.before.data();
  const after = change.after.data();

  if (!before || !after) return;

  // 무한 루프 방지: 알림 관련 필드(remindersSent, nextReminderAt)만 변경된 경우 스킵
  if (isOnlyReminderFieldChange(before, after)) {
    return;
  }

  // 완료 상태로 변경된 경우 알림 관련 필드 초기화
  if (!before.isCompleted && after.isCompleted) {
    await change.after.ref.update({
      remindersSent: [],
      nextReminderAt: null, // 완료된 todo는 알림 쿼리에서 제외
    });
  }

  // 미완료로 변경된 경우 (반복 일정 재사용) nextReminderAt 재계산
  if (before.isCompleted && !after.isCompleted) {
    const reminderMinutes: number[] = after.reminderMinutes || [];
    if (reminderMinutes.length > 0) {
      const eventTime = after.startTime?.toDate() || after.dueDate?.toDate();
      if (eventTime) {
        const nextReminderAt = calculateNextReminderAt(
          eventTime,
          reminderMinutes,
          [] // remindersSent 초기화됨
        );

        await change.after.ref.update({
          nextReminderAt: nextReminderAt ?
            admin.firestore.Timestamp.fromDate(nextReminderAt) :
            null,
        });
      }
    }
  }
}

/**
 * Todo 완료 시 remindersSent, nextReminderAt 초기화 (Phase 2: 사용자 레벨)
 */
export const cleanupRemindersOnComplete = functions.firestore
  .document("users/{userId}/todos/{todoId}")
  .onUpdate(handleReminderCleanup);

/**
 * Todo 완료 시 remindersSent, nextReminderAt 초기화 (Legacy: 그룹 레벨)
 */
export const cleanupRemindersOnCompleteFamily = functions.firestore
  .document("families/{groupId}/todos/{todoId}")
  .onUpdate(handleReminderCleanup);
