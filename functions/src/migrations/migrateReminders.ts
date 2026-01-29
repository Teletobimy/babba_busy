import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

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

  const maxMinutes = Math.max(...pendingMinutes);
  return new Date(eventTime.getTime() - maxMinutes * 60 * 1000);
}

/**
 * 기존 todos에 nextReminderAt 필드 마이그레이션
 *
 * 실행 방법:
 * 1. firebase deploy --only functions:migrateRemindersToNextReminderAt
 * 2. HTTP 요청: GET https://[region]-[project].cloudfunctions.net/migrateRemindersToNextReminderAt
 *
 * 주의: 한 번만 실행해야 함. 중복 실행해도 안전하지만 불필요한 쓰기 발생.
 */
export const migrateRemindersToNextReminderAt = functions
  .runWith({
    timeoutSeconds: 540, // 9분 (최대 허용)
    memory: "512MB",
  })
  .https.onRequest(async (req, res) => {
    // 인증 확인 (필수: MIGRATION_SECRET 환경변수 설정 필요)
    const authHeader = req.headers.authorization;
    const expectedToken = process.env.MIGRATION_SECRET;
    if (!expectedToken) {
      console.error("MIGRATION_SECRET environment variable not set");
      res.status(500).send({ error: "Server configuration error" });
      return;
    }
    if (authHeader !== `Bearer ${expectedToken}`) {
      res.status(401).send({ error: "Unauthorized" });
      return;
    }

    const db = admin.firestore();
    const batchSize = 100;
    let totalMigrated = 0;
    let totalSkipped = 0;
    let totalErrors = 0;
    let hasMore = true;
    let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

    console.log("Starting migration: nextReminderAt field");

    try {
      while (hasMore) {
        // reminderMinutes가 있는 미완료 todos 조회 (nextReminderAt 필드 유무 상관없이)
        let query = db.collectionGroup("todos")
          .where("isCompleted", "==", false)
          .limit(batchSize);

        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();

        if (snapshot.empty) {
          hasMore = false;
          break;
        }

        const batch = db.batch();
        let batchCount = 0;

        for (const doc of snapshot.docs) {
          const todo = doc.data();
          const reminderMinutes: number[] = todo.reminderMinutes || [];

          // reminderMinutes가 없으면 스킵
          if (reminderMinutes.length === 0) {
            totalSkipped++;
            continue;
          }

          // 이미 nextReminderAt이 설정되어 있으면 스킵 (멱등성)
          if (todo.nextReminderAt != null) {
            totalSkipped++;
            continue;
          }

          // 이벤트 시간 결정
          const eventTime = todo.startTime?.toDate() || todo.dueDate?.toDate();
          if (!eventTime) {
            totalSkipped++;
            continue;
          }

          // nextReminderAt 계산
          const remindersSent: number[] = todo.remindersSent || [];
          const nextReminderAt = calculateNextReminderAt(
            eventTime,
            reminderMinutes,
            remindersSent
          );

          // 미래 알림만 설정 (과거 알림은 이미 지남)
          const now = new Date();
          if (nextReminderAt && nextReminderAt > now) {
            batch.update(doc.ref, {
              nextReminderAt: admin.firestore.Timestamp.fromDate(nextReminderAt),
            });
            batchCount++;
          } else {
            // 모든 알림이 과거인 경우 null로 명시적 설정
            batch.update(doc.ref, {
              nextReminderAt: null,
            });
            batchCount++;
          }
        }

        if (batchCount > 0) {
          try {
            await batch.commit();
            totalMigrated += batchCount;
            console.log(`Migrated batch: ${batchCount} documents (total: ${totalMigrated})`);
          } catch (batchError) {
            console.error("Batch commit error:", batchError);
            totalErrors += batchCount;
          }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];

        // 다음 배치가 있는지 확인
        if (snapshot.docs.length < batchSize) {
          hasMore = false;
        }
      }

      const result = {
        success: true,
        totalMigrated,
        totalSkipped,
        totalErrors,
        message: `Migration completed. Migrated: ${totalMigrated}, Skipped: ${totalSkipped}, Errors: ${totalErrors}`,
      };

      console.log("Migration completed:", result);
      res.status(200).json(result);
    } catch (error) {
      console.error("Migration error:", error);
      res.status(500).json({
        success: false,
        error: String(error),
        totalMigrated,
        totalSkipped,
        totalErrors,
      });
    }
  });

/**
 * 드라이런: 실제 변경 없이 마이그레이션 대상 확인
 */
export const dryRunMigrateReminders = functions
  .runWith({
    timeoutSeconds: 300,
    memory: "256MB",
  })
  .https.onRequest(async (req, res) => {
    // 인증 확인 (필수: MIGRATION_SECRET 환경변수 설정 필요)
    const authHeader = req.headers.authorization;
    const expectedToken = process.env.MIGRATION_SECRET;
    if (!expectedToken) {
      console.error("MIGRATION_SECRET environment variable not set");
      res.status(500).send({ error: "Server configuration error" });
      return;
    }
    if (authHeader !== `Bearer ${expectedToken}`) {
      res.status(401).send({ error: "Unauthorized" });
      return;
    }

    const db = admin.firestore();
    let needsMigration = 0;
    let alreadyMigrated = 0;
    let noReminders = 0;
    let noEventTime = 0;

    const snapshot = await db.collectionGroup("todos")
      .where("isCompleted", "==", false)
      .get();

    for (const doc of snapshot.docs) {
      const todo = doc.data();
      const reminderMinutes: number[] = todo.reminderMinutes || [];

      if (reminderMinutes.length === 0) {
        noReminders++;
        continue;
      }

      if (todo.nextReminderAt != null) {
        alreadyMigrated++;
        continue;
      }

      const eventTime = todo.startTime?.toDate() || todo.dueDate?.toDate();
      if (!eventTime) {
        noEventTime++;
        continue;
      }

      needsMigration++;
    }

    res.status(200).json({
      total: snapshot.size,
      needsMigration,
      alreadyMigrated,
      noReminders,
      noEventTime,
    });
  });
