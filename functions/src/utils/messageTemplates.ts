/**
 * 알림 메시지 템플릿
 */

export const MessageTemplates = {
  // Chat 알림
  chatMessage: (senderName: string, message: string): { title: string; body: string } => ({
    title: senderName,
    body: message.length > 100 ? `${message.substring(0, 100)}...` : message,
  }),

  // Todo 알림
  todoAssigned: (title: string, assignerName: string): { title: string; body: string } => ({
    title: "새 할일이 할당되었습니다",
    body: `${assignerName}님이 "${title}"을(를) 할당했습니다`,
  }),

  todoCompleted: (title: string, completerName: string): { title: string; body: string } => ({
    title: "할일이 완료되었습니다",
    body: `${completerName}님이 "${title}"을(를) 완료했습니다`,
  }),

  todoDueSoon: (title: string, hoursLeft: number): { title: string; body: string } => ({
    title: "할일 마감 임박",
    body: `"${title}"의 마감까지 ${hoursLeft}시간 남았습니다`,
  }),

  // Event 알림
  eventCreated: (title: string, creatorName: string): { title: string; body: string } => ({
    title: "새 일정이 추가되었습니다",
    body: `${creatorName}님이 "${title}" 일정을 만들었습니다`,
  }),

  eventStartingSoon: (title: string, minutesLeft: number): { title: string; body: string } => ({
    title: "일정 시작 임박",
    body: `"${title}"이(가) ${minutesLeft}분 후 시작됩니다`,
  }),

  // Business Review 알림
  businessReviewCompleted: (ideaTitle: string): { title: string; body: string } => ({
    title: "사업 분석 완료",
    body: `"${ideaTitle}" 아이디어 분석이 완료되었습니다`,
  }),
};
