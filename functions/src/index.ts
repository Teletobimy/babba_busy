import * as admin from "firebase-admin";

// Firebase Admin 초기화
admin.initializeApp();

// Chat 트리거
export { onChatMessageCreated } from "./triggers/chatTriggers";

// Todo/Event 트리거
export { onTodoCreated, onTodoUpdated, onEventCreated } from "./triggers/todoTriggers";

// 알림 스케줄 트리거
export {
  checkReminders,
  cleanupRemindersOnComplete,
  cleanupRemindersOnCompleteFamily,
} from "./triggers/reminderTriggers";

// Analysis Job 트리거 (비동기 분석 완료/실패 알림)
export {
  onAnalysisJobUpdated,
  onAnalysisJobCreated,
} from "./triggers/jobTriggers";

// Business Review 트리거 (사업검토 완료 알림)
export { onBusinessReviewCompleted } from "./triggers/businessTriggers";

// Album 트리거 (앨범 공유/사진 추가 알림)
export { onAlbumCreated, onAlbumPhotosAdded } from "./triggers/albumTriggers";

// 마이그레이션 함수 (일회성 실행용)
export {
  migrateRemindersToNextReminderAt,
  dryRunMigrateReminders,
} from "./migrations/migrateReminders";
