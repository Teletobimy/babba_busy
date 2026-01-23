import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotificationToUser } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 분석 작업 완료/실패 시 알림 전송
 */
export const onAnalysisJobUpdated = functions.firestore
  .document("analysis_jobs/{jobId}")
  .onUpdate(async (change, context) => {
    const jobId = context.params.jobId;

    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!afterData) {
        return;
      }

      const beforeStatus = beforeData?.status || "";
      const afterStatus = afterData.status || "";
      const userId = afterData.userId;
      const jobType = afterData.jobType || "business_review";

      // 이미 알림을 보낸 경우 스킵
      if (afterData.notificationSent) {
        console.log(`Notification already sent for job ${jobId}`);
        return;
      }

      // completed 상태로 변경된 경우
      if (afterStatus === "completed" && beforeStatus !== "completed") {
        const { title, body } = MessageTemplates.analysisJobCompleted(jobType);

        // 알림 전송
        await sendNotificationToUser(userId, {
          title,
          body,
          data: {
            type: "analysis_complete",
            jobId,
            jobType,
            route: getRouteForJobType(jobType),
          },
        });

        // 알림 전송 완료 표시
        await change.after.ref.update({
          notificationSent: true,
        });

        console.log(`Sent completion notification for job ${jobId} to user ${userId}`);
      }

      // failed 상태로 변경된 경우
      if (afterStatus === "failed" && beforeStatus !== "failed") {
        const { title, body } = MessageTemplates.analysisJobFailed(jobType);

        // 알림 전송
        await sendNotificationToUser(userId, {
          title,
          body,
          data: {
            type: "analysis_failed",
            jobId,
            jobType,
            route: getRouteForJobType(jobType),
          },
        });

        // 알림 전송 완료 표시
        await change.after.ref.update({
          notificationSent: true,
        });

        console.log(`Sent failure notification for job ${jobId} to user ${userId}`);
      }
    } catch (error) {
      console.error(`Error in analysis job trigger for ${jobId}:`, error);
    }
  });

/**
 * 분석 작업 생성 시 처리 (선택적)
 */
export const onAnalysisJobCreated = functions.firestore
  .document("analysis_jobs/{jobId}")
  .onCreate(async (snapshot, context) => {
    const jobId = context.params.jobId;
    const data = snapshot.data();

    console.log(`Analysis job created: ${jobId}, type: ${data?.jobType}, user: ${data?.userId}`);

    // 향후 Cloud Tasks 연동 시 여기서 태스크 생성 가능
    // 현재는 Cloud Run에서 백그라운드 처리하므로 로깅만 수행
  });

/**
 * 오래된 분석 작업 정리 (선택적, 스케줄 함수)
 */
export const cleanupOldAnalysisJobs = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const db = admin.firestore();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // 30일 전

    try {
      // 30일 이상 된 완료/실패/취소 작업 삭제
      const oldJobsSnapshot = await db
        .collection("analysis_jobs")
        .where("status", "in", ["completed", "failed", "cancelled"])
        .where("createdAt", "<", cutoffDate)
        .limit(100)
        .get();

      if (oldJobsSnapshot.empty) {
        console.log("No old analysis jobs to clean up");
        return;
      }

      const batch = db.batch();
      oldJobsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Cleaned up ${oldJobsSnapshot.size} old analysis jobs`);
    } catch (error) {
      console.error("Error cleaning up old analysis jobs:", error);
    }
  });

/**
 * 작업 유형별 라우트 반환
 */
function getRouteForJobType(jobType: string): string {
  switch (jobType) {
  case "business_review":
    return "/tools/business/history";
  case "psychology_test":
    return "/tools/psychology/history";
  default:
    return "/home";
  }
}
