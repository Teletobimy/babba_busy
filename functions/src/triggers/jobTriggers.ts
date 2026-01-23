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
        // 트랜잭션으로 원자적 처리 (race condition 방지)
        const shouldSend = await admin.firestore().runTransaction(async (transaction) => {
          const doc = await transaction.get(change.after.ref);
          if (doc.data()?.notificationSent) return false;
          transaction.update(change.after.ref, { notificationSent: true });
          return true;
        });

        if (!shouldSend) {
          console.log(`Notification already sent for job ${jobId} (transaction check)`);
          return;
        }

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
          tag: `analysis_${jobType}_${userId}`,
        });

        console.log(`Sent completion notification for job ${jobId} to user ${userId}`);
      }

      // failed 상태로 변경된 경우
      if (afterStatus === "failed" && beforeStatus !== "failed") {
        // 트랜잭션으로 원자적 처리 (race condition 방지)
        const shouldSend = await admin.firestore().runTransaction(async (transaction) => {
          const doc = await transaction.get(change.after.ref);
          if (doc.data()?.notificationSent) return false;
          transaction.update(change.after.ref, { notificationSent: true });
          return true;
        });

        if (!shouldSend) {
          console.log(`Notification already sent for job ${jobId} (transaction check)`);
          return;
        }

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
          tag: `analysis_${jobType}_${userId}`,
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

// NOTE: cleanupOldAnalysisJobs 스케줄 함수는 Cloud Scheduler API 활성화 필요
// GCP 콘솔에서 cloudscheduler.googleapis.com 활성화 후 추가 가능
// https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com

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
