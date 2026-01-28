import * as admin from "firebase-admin";

// Firebase Admin 초기화
admin.initializeApp();

// Chat 트리거
export { onChatMessageCreated } from "./triggers/chatTriggers";

// Todo/Event 트리거
export { onTodoCreated, onTodoUpdated, onEventCreated } from "./triggers/todoTriggers";

// 알림 스케줄 트리거
export { checkReminders, cleanupRemindersOnComplete } from "./triggers/reminderTriggers";

// Analysis Job 트리거 (비동기 분석 완료/실패 알림)
export {
  onAnalysisJobUpdated,
  onAnalysisJobCreated,
} from "./triggers/jobTriggers";
