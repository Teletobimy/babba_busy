import * as admin from "firebase-admin";

// Firebase Admin 초기화
admin.initializeApp();

// Chat 트리거
export { onChatMessageCreated } from "./triggers/chatTriggers";

// Todo/Event 트리거
export { onTodoCreated, onTodoUpdated, onEventCreated } from "./triggers/todoTriggers";

// Business Review 트리거
export { onBusinessReviewCompleted } from "./triggers/businessTriggers";
