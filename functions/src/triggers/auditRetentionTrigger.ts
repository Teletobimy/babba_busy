import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// AI tool audit retention 정책 (RFC-003 §8)
const AUDIT_RETENTION_DAYS = 30;
// pending/finalized AI 요청은 별도 짧은 retention — 사용자가 sheet를 영영 안 닫은 잔재 정리
const ACTION_REQUEST_RETENTION_DAYS = 7;
const BATCH_LIMIT = 500;

/**
 * 매일 03:00 KST에 실행되어 stale audit 로그와 action 요청 문서를 정리합니다.
 * - users/{uid}/tool_audit_log/* : createdAt < (now - 30d) 삭제
 * - users/{uid}/ai_action_requests/* : updated_at < (now - 7d) 삭제
 *
 * 한 회당 최대 500개씩 (Firestore batch 한계). 남은 건 다음 날 회차에서 처리.
 * 한 번에 모두 못 비워도 retention 정책은 지켜짐 (오래된 것부터 순차 삭제).
 */
export const cleanupAuditLogs = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 3 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const db = admin.firestore();
    const now = Date.now();

    let totalDeleted = 0;

    // 1. tool_audit_log — 30일 이상 된 audit 로그
    try {
      const auditCutoff = admin.firestore.Timestamp.fromMillis(
        now - AUDIT_RETENTION_DAYS * 24 * 60 * 60 * 1000
      );
      const stale = await db
        .collectionGroup("tool_audit_log")
        .where("createdAt", "<", auditCutoff)
        .limit(BATCH_LIMIT)
        .get();

      if (!stale.empty) {
        const batch = db.batch();
        stale.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted += stale.size;
        console.log(
          `[auditRetention] tool_audit_log: ${stale.size} docs deleted (cutoff=${AUDIT_RETENTION_DAYS}d)`
        );
      }
    } catch (e) {
      console.error("[auditRetention] tool_audit_log cleanup failed:", e);
    }

    // 2. ai_action_requests — 7일 이상 된 요청 문서 (status 무관)
    try {
      const requestCutoff = admin.firestore.Timestamp.fromMillis(
        now - ACTION_REQUEST_RETENTION_DAYS * 24 * 60 * 60 * 1000
      );
      const stale = await db
        .collectionGroup("ai_action_requests")
        .where("updated_at", "<", requestCutoff)
        .limit(BATCH_LIMIT)
        .get();

      if (!stale.empty) {
        const batch = db.batch();
        stale.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted += stale.size;
        console.log(
          `[auditRetention] ai_action_requests: ${stale.size} docs deleted (cutoff=${ACTION_REQUEST_RETENTION_DAYS}d)`
        );
      }
    } catch (e) {
      console.error("[auditRetention] ai_action_requests cleanup failed:", e);
    }

    console.log(`[auditRetention] total deleted: ${totalDeleted}`);
    return null;
  });
