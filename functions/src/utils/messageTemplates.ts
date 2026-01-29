/**
 * 알림 메시지 템플릿
 */

export const MessageTemplates = {
  // Chat 알림
  chatMessage: (senderName: string, message: string): { title: string; body: string } => ({
    title: senderName,
    body: message.length > 100 ? `${message.substring(0, 100)}...` : message,
  }),

  chatImageMessage: (senderName: string): { title: string; body: string } => ({
    title: senderName,
    body: "📷 사진을 보냈습니다",
  }),

  // 미리 알림
  todoReminder: (title: string, minutesBefore: number): { title: string; body: string } => {
    let timeLabel: string;
    if (minutesBefore === 0) {
      timeLabel = "지금";
    } else if (minutesBefore < 60) {
      timeLabel = `${minutesBefore}분 후`;
    } else if (minutesBefore < 1440) {
      const hours = Math.floor(minutesBefore / 60);
      timeLabel = `${hours}시간 후`;
    } else {
      const days = Math.floor(minutesBefore / 1440);
      timeLabel = `${days}일 후`;
    }

    return {
      title: "일정 알림",
      body: `"${title}"이(가) ${timeLabel} 시작됩니다`,
    };
  },

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

  // Analysis Job 알림
  analysisJobCompleted: (jobType: string): { title: string; body: string } => {
    const typeNames: Record<string, string> = {
      business_review: "사업 검토",
      psychology_test: "심리 검사",
    };
    const typeName = typeNames[jobType] || "분석";
    return {
      title: `${typeName} 결과가 도착했어요`,
      body: "지금 확인해보세요!",
    };
  },

  analysisJobFailed: (jobType: string): { title: string; body: string } => {
    const typeNames: Record<string, string> = {
      business_review: "사업 검토",
      psychology_test: "심리 검사",
    };
    const typeName = typeNames[jobType] || "분석";
    return {
      title: `${typeName} 중 문제가 발생했어요`,
      body: "다시 시도하시거나 나중에 확인해주세요",
    };
  },

  // 앨범 공유
  albumShared: (albumTitle: string, creatorName: string): { title: string; body: string } => ({
    title: "새 앨범 공유됨",
    body: `${creatorName}님이 '${albumTitle}' 앨범을 공유했습니다`,
  }),

  // 앨범에 사진 추가
  albumPhotosAdded: (
    albumTitle: string,
    adderName: string,
    count: number
  ): { title: string; body: string } => ({
    title: "앨범에 사진 추가됨",
    body: `${adderName}님이 '${albumTitle}' 앨범에 사진 ${count}장을 추가했습니다`,
  }),
};
