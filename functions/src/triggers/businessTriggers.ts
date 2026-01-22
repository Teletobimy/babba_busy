import * as functions from "firebase-functions";
import { sendNotificationToUser } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 사업검토 완료 시 알림 전송
 */
export const onBusinessReviewCompleted = functions.firestore
  .document("users/{userId}/business_reviews/{reviewId}")
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const reviewId = context.params.reviewId;

    try {
      // 문서가 삭제된 경우 무시
      if (!change.after.exists) {
        return;
      }

      const afterData = change.after.data();
      if (!afterData) {
        return;
      }

      // 상태가 completed로 변경된 경우에만 알림
      const beforeData = change.before.exists ? change.before.data() : null;
      const beforeStatus = beforeData?.status || "";
      const afterStatus = afterData.status || "";

      if (afterStatus === "completed" && beforeStatus !== "completed") {
        const ideaTitle = afterData.ideaTitle || afterData.title || "사업 아이디어";

        const { title, body } = MessageTemplates.businessReviewCompleted(ideaTitle);
        await sendNotificationToUser(userId, {
          title,
          body,
          data: {
            type: "business_review",
            reviewId,
            route: "/tools/business",
          },
        });

        console.log(`Sent business review completion notification to user ${userId}`);
      }
    } catch (error) {
      console.error(`Error in business review trigger for ${reviewId}:`, error);
    }
  });
