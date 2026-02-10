# BABBA Firestore Data Structure

이 문서는 BABBA 앱의 전체 Firestore 데이터 구조를 정리합니다.

---

## 1. 컬렉션 구조 개요

```
Firestore Root
|
+-- users/{userId}                          # 사용자 정보
|   +-- /todos/{todoId}                     # Phase 2: 사용자 레벨 할일
|   +-- /business_reviews/{reviewId}        # 사업 검토 결과
|   +-- /psychology_tests/{testId}          # 심리검사 결과
|   +-- /memos/{memoId}                     # 메모
|   +-- /memo_categories/{categoryId}       # 메모 카테고리
|   +-- /albums/{albumId}                   # 앨범
|
+-- families/{groupId}                      # 그룹(가족) 정보
|   +-- /todos/{todoId}                     # 그룹 레벨 할일 (Legacy)
|   +-- /chat_messages/{messageId}          # 채팅 메시지
|   +-- /transactions/{txId}                # 가계부 거래
|   +-- /persons/{personId}                 # 연락처/인맥
|   +-- /calendar_groups/{groupId}          # 캘린더 그룹
|
+-- memberships/{membershipId}              # 사용자-그룹 관계
|
+-- analysis_jobs/{jobId}                   # AI 분석 작업 큐
|
+-- ai_cache/{userId}/...                   # AI 캐시 데이터
```

---

## 2. 주요 모델 상세

### 2.1 User (사용자)

**컬렉션 경로**: `users/{userId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| name | string | O | 사용자 이름 |
| email | string | O | 이메일 주소 |
| avatarUrl | string | - | 프로필 사진 URL |
| defaultGroupId | string | - | 기본 선택 그룹 ID |
| fcmTokens | array<string> | - | FCM 토큰 목록 (여러 기기 지원) |
| notificationSettings | map | - | 알림 설정 (하위 구조 참조) |
| createdAt | timestamp | O | 생성 시간 |

**notificationSettings 구조**:
```
{
  enabled: boolean,      // 전체 알림 on/off
  chatEnabled: boolean,  // 채팅 알림
  todoEnabled: boolean,  // 할일 알림
  eventEnabled: boolean  // 일정 알림
}
```

---

### 2.2 FamilyGroup (그룹)

**컬렉션 경로**: `families/{groupId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| name | string | O | 그룹 이름 |
| inviteCode | string | O | 초대 코드 |
| photoUrl | string | - | 그룹 사진 URL |
| createdAt | timestamp | O | 생성 시간 |

---

### 2.3 Membership (멤버십)

**컬렉션 경로**: `memberships/{userId}_{groupId}`

사용자와 그룹 간의 N:M 관계를 관리합니다.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 사용자 ID |
| groupId | string | O | 그룹 ID |
| groupName | string | O | 캐시된 그룹 이름 |
| name | string | O | 그룹 내 닉네임 |
| color | string | O | 그룹 내 색상 (Hex) |
| role | string | O | 역할 ('admin' / 'member') |
| avatarUrl | string | - | 프로필 사진 URL |
| sharedEventTypes | array<string> | - | 공유할 일정 타입 ['todo', 'schedule', 'event'] |
| joinedAt | timestamp | O | 가입 시간 |

---

### 2.4 TodoItem (할일/일정/이벤트)

**컬렉션 경로**:
- Phase 1 (Legacy): `families/{groupId}/todos/{todoId}`
- Phase 2 (Current): `users/{userId}/todos/{todoId}`

가장 복잡한 모델로, 할일/일정/이벤트를 통합 관리합니다.

#### 기본 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| familyId | string | O | 그룹 ID |
| title | string | O | 제목 |
| note | string | - | 메모/설명 |
| isCompleted | boolean | O | 완료 여부 |
| priority | int | - | 우선순위 (0: 낮음, 1: 보통, 2: 높음) |
| createdAt | timestamp | O | 생성 시간 |
| createdBy | string | O | 생성자 ID |

#### 타입 및 가시성

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| eventType | string | - | 'todo' / 'schedule' / 'event' |
| visibility | string | - | 'private' / 'shared' |
| ownerId | string | - | 소유자 ID (Phase 2) |
| sharedGroups | array<string> | - | 공유된 그룹 ID 목록 |
| isPersonal | boolean | - | 개인 일정 여부 |

#### 날짜/시간

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| dueDate | timestamp | - | 마감일/이벤트 날짜 |
| startTime | timestamp | - | 시작 시간 |
| endTime | timestamp | - | 종료 시간 |
| hasTime | boolean | - | 시간 정보 유무 |
| completedAt | timestamp | - | 완료 시간 |

#### 할당/참여

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| assigneeId | string | - | 담당자 ID (Legacy) |
| participants | array<string> | - | 참여자 ID 목록 |
| location | string | - | 위치 |
| calendarGroupId | string | - | 캘린더 그룹 ID |
| color | string | - | 색상 (Hex) |

#### 반복 설정

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| repeatType | string | - | Legacy: 'daily' / 'weekly' / 'monthly' |
| recurrenceType | string | - | 'none' / 'daily' / 'weekly' / 'monthly' / 'yearly' |
| recurrenceDays | array<int> | - | 반복 요일 (1=월 ~ 7=일) |
| recurrenceEndDate | timestamp | - | 반복 종료일 |
| excludeHolidays | boolean | - | 공휴일 제외 여부 |
| parentTodoId | string | - | 반복 인스턴스의 부모 ID |

#### 알림 설정

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| reminderMinutes | array<int> | - | 알림 시간 목록 (분 단위) |
| remindersSent | array<int> | - | 발송 완료된 알림 |
| nextReminderAt | timestamp | - | 다음 알림 시간 (인덱스용) |

#### EventType 값

| 값 | 설명 | 완료 가능 | 반복 가능 |
|----|------|----------|----------|
| todo | 할일 | O | X |
| schedule | 일정 | 비반복만 | O |
| event | 이벤트 (기념일) | X | O |

---

### 2.5 Album (앨범)

**컬렉션 경로**: `users/{userId}/albums/{albumId}`

Memory를 대체하며 멀티 그룹 공유를 지원합니다.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| title | string | O | 앨범 제목 |
| description | string | - | 설명 |
| date | timestamp | O | 앨범 날짜 |
| photoUrls | array<string> | O | 사진 URL 목록 |
| createdBy | string | O | 생성자 ID |
| createdAt | timestamp | O | 생성 시간 |
| sharedGroups | array<string> | O | 공유된 그룹 ID 목록 |
| visibility | string | - | 'private' / 'shared' |
| albumType | string | - | 'kids' / 'family' / 'event' / 'moment' |
| hasLocation | boolean | - | 위치 정보 유무 |
| latitude | number | - | 위도 |
| longitude | number | - | 경도 |
| placeName | string | - | 장소명 |
| participants | array<string> | - | 사진에 나오는 사람 ID |
| tags | array<string> | - | 태그 목록 |

**AlbumComment (서브컬렉션)**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| albumId | string | O | 앨범 ID |
| userId | string | O | 작성자 ID |
| text | string | O | 댓글 내용 |
| createdAt | timestamp | O | 작성 시간 |

---

### 2.6 BudgetTransaction (가계부)

**컬렉션 경로**: `families/{groupId}/transactions/{txId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| familyId | string | O | 그룹 ID |
| type | string | O | 'income' / 'expense' |
| amount | int | O | 금액 |
| category | string | O | 카테고리 |
| memo | string | - | 메모 |
| date | timestamp | O | 거래 날짜 |
| userId | string | O | 등록자 ID |
| isRecurring | boolean | - | 반복 거래 여부 |
| recurringType | string | - | 'monthly' / 'yearly' |
| createdAt | timestamp | O | 생성 시간 |

**카테고리 목록**:
- 지출: food, transport, shopping, entertainment, health, education, housing, utilities, other
- 수입: income

---

### 2.7 ChatMessage (채팅)

**컬렉션 경로**: `families/{groupId}/chat_messages/{messageId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| familyId | string | O | 그룹 ID |
| senderId | string | O | 발신자 ID |
| senderName | string | O | 발신자 이름 (캐시) |
| senderAvatarUrl | string | - | 발신자 프로필 사진 |
| content | string | O | 메시지 내용 |
| imageUrl | string | - | 이미지 URL (이미지 메시지) |
| attachmentUrl | string | - | 첨부 파일 URL |
| attachmentName | string | - | 첨부 파일 이름 |
| attachmentMimeType | string | - | 첨부 파일 MIME 타입 |
| attachmentSizeBytes | number | - | 첨부 파일 크기 (byte) |
| type | string | O | 'text' / 'image' / 'file' / 'system' |
| createdAt | timestamp | O | 전송 시간 |
| readBy | array<string> | O | 읽은 사용자 ID 목록 |

---

### 2.8 Person (연락처/인맥)

**컬렉션 경로**: `families/{groupId}/persons/{personId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| familyId | string | O | 그룹 ID |
| name | string | O | 이름 |
| profilePhotoUrl | string | - | 프로필 사진 URL |
| birthday | timestamp | - | 생일 |
| mbti | string | - | MBTI 유형 |
| phone | string | - | 전화번호 |
| email | string | - | 이메일 |
| address | string | - | 주소 |
| personality | string | - | 성격 메모 |
| relationship | string | - | 관계 (family/friend/colleague/school/neighbor/other) |
| company | string | - | 회사/학교 |
| note | string | - | 자유 메모 |
| events | array<map> | - | 기념일 목록 (PersonEvent) |
| customFields | map | - | 커스텀 필드 |
| tags | array<string> | - | 태그 |
| createdAt | timestamp | O | 생성 시간 |
| createdBy | string | O | 생성자 ID |

**PersonEvent 구조**:
```
{
  id: string,
  title: string,
  date: timestamp,
  isYearly: boolean,
  note: string
}
```

---

### 2.9 Memo (메모)

**컬렉션 경로**: `users/{userId}/memos/{memoId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 사용자 ID |
| title | string | O | 제목 |
| content | string | - | 내용 |
| categoryId | string | - | 카테고리 ID |
| categoryName | string | - | 카테고리 이름 (캐시) |
| tags | array<string> | - | 태그 목록 |
| isPinned | boolean | - | 고정 여부 |
| aiAnalysis | string | - | AI 분석 결과 |
| analyzedAt | timestamp | - | 분석 시간 |
| createdAt | timestamp | O | 생성 시간 |
| updatedAt | timestamp | O | 수정 시간 |
| createdBy | string | O | 생성자 ID |

---

### 2.10 MemoCategory (메모 카테고리)

**컬렉션 경로**: `users/{userId}/memo_categories/{categoryId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 사용자 ID |
| name | string | O | 카테고리 이름 |
| icon | string | - | 아이콘 이름 |
| color | string | O | 색상 (Hex) |
| sortOrder | int | O | 정렬 순서 |
| createdAt | timestamp | O | 생성 시간 |

**기본 카테고리**: 일기, 간단메모, 아이디어, 할일메모

---

### 2.11 CalendarGroup (캘린더 그룹)

**컬렉션 경로**: `families/{groupId}/calendar_groups/{calendarGroupId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| name | string | O | 그룹 이름 |
| type | string | O | 'personal' / 'family' / 'friends' / 'work' / 'other' |
| color | string | O | 색상 (Hex) |
| memberIds | array<string> | O | 멤버 ID 목록 |
| ownerId | string | O | 생성자 ID |
| isDefault | boolean | - | 기본 캘린더 여부 |
| createdAt | timestamp | O | 생성 시간 |

---

### 2.12 AnalysisJob (AI 분석 작업)

**컬렉션 경로**: `analysis_jobs/{jobId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 요청자 ID |
| jobType | string | O | 'business_review' / 'psychology_test' |
| status | string | O | 'pending' / 'processing' / 'completed' / 'failed' / 'cancelled' |
| priority | int | - | 우선순위 (기본 5) |
| input | map | O | 입력 데이터 |
| progress | map | O | 진행 상황 |
| resultId | string | - | 결과 문서 ID |
| error | map | - | 에러 정보 |
| retryCount | int | - | 재시도 횟수 |
| maxRetries | int | - | 최대 재시도 횟수 |
| createdAt | timestamp | O | 생성 시간 |
| startedAt | timestamp | - | 시작 시간 |
| completedAt | timestamp | - | 완료 시간 |
| updatedAt | timestamp | O | 수정 시간 |
| notificationSent | boolean | - | 알림 전송 여부 |

**progress 구조**:
```
{
  currentStep: int,
  totalSteps: int,
  percentage: double,
  currentStepName: string
}
```

---

### 2.13 BusinessReview (사업 검토 결과)

**컬렉션 경로**: `users/{userId}/business_reviews/{reviewId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 사용자 ID |
| groupId | string | - | 공유 그룹 ID |
| isShared | boolean | - | 공유 여부 |
| businessIdea | string | O | 사업 아이디어 |
| industry | string | - | 산업 분야 |
| budget | string | - | 예산 |
| score | int | O | 점수 (0-100) |
| summary | string | O | 요약 |
| strengths | array<string> | O | 강점 |
| weaknesses | array<string> | O | 약점 |
| opportunities | array<string> | O | 기회 |
| threats | array<string> | O | 위협 |
| nextSteps | array<string> | O | 다음 단계 |
| marketResearch | map | - | 시장 조사 결과 |
| createdAt | timestamp | O | 생성 시간 |

---

### 2.14 PsychologyTestResult (심리검사 결과)

**컬렉션 경로**: `users/{userId}/psychology_tests/{testId}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| userId | string | O | 사용자 ID |
| familyId | string | - | 공유 그룹 ID |
| testType | string | O | 검사 유형 |
| answers | array<int> | O | 응답 목록 |
| result | map | O | 검사 결과 |
| completedAt | timestamp | O | 완료 시간 |
| isShared | boolean | - | 공유 여부 |

**testType 값**: big5, mbti, attachment, love_language, stress, anxiety, depression

---

### 2.15 Holiday (공휴일)

**컬렉션 경로**: `families/{groupId}/holidays/{holidayId}` (커스텀 공휴일만)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| name | string | O | 공휴일 이름 |
| date | timestamp | O | 날짜 |
| isLunar | boolean | - | 음력 여부 |
| isCustom | boolean | - | 사용자 정의 여부 |
| familyId | string | - | 그룹 ID |

> 참고: 한국 공휴일은 앱 내 `KoreanHolidays` 클래스에서 하드코딩됨

---

## 3. 모델 간 관계 다이어그램

```
                                    +------------------+
                                    |      User        |
                                    +------------------+
                                    | id               |
                                    | name             |
                                    | email            |
                                    +--------+---------+
                                             |
                                             | 1:N
                                             |
                     +-----------------------+-----------------------+
                     |                       |                       |
                     v                       v                       v
          +------------------+    +------------------+    +------------------+
          |    Membership    |    |     TodoItem     |    |      Album       |
          +------------------+    | (users/todos)    |    +------------------+
          | userId           |    +------------------+    | sharedGroups[]   |
          | groupId          |    | ownerId          |    | createdBy        |
          | name (nickname)  |    | sharedGroups[]   |    +------------------+
          | color            |    +------------------+
          +--------+---------+
                   |
                   | N:1
                   v
          +------------------+
          |   FamilyGroup    |
          +------------------+
          | id               |
          | name             |
          | inviteCode       |
          +--------+---------+
                   |
                   | 1:N (서브컬렉션)
                   |
     +-------------+-------------+-------------+
     |             |             |             |
     v             v             v             v
+----------+ +----------+ +----------+ +----------+
| TodoItem | |  Message | |Transaction|  Person  |
| (legacy) | +----------+ +----------+ +----------+
+----------+


CollectionGroup Query (todos):
+------------------+
| users/*/todos    | ---> sharedGroups[]로 접근
+------------------+
```

---

## 4. 인덱스 요구사항

### 4.1 현재 정의된 인덱스 (firestore.indexes.json)

```json
{
  "indexes": [
    {
      "collectionGroup": "albums",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "sharedGroups", "arrayConfig": "CONTAINS" },
        { "fieldPath": "date", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "todos",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "sharedGroups", "arrayConfig": "CONTAINS" },
        { "fieldPath": "visibility", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "todos",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "isCompleted", "order": "ASCENDING" },
        { "fieldPath": "nextReminderAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "analysis_jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "analysis_jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "analysis_jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### 4.2 권장 추가 인덱스

```json
// 할일 날짜별 조회
{
  "collectionGroup": "todos",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "ownerId", "order": "ASCENDING" },
    { "fieldPath": "dueDate", "order": "ASCENDING" }
  ]
}

// 메모 카테고리별 조회
{
  "collectionGroup": "memos",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "categoryId", "order": "ASCENDING" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
}

// 거래 날짜별 조회
{
  "collectionGroup": "transactions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "familyId", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "DESCENDING" }
  ]
}
```

---

## 5. 보안 규칙 요약

### 5.1 주요 규칙

| 컬렉션 | 읽기 | 쓰기 | 비고 |
|--------|------|------|------|
| users/{userId} | 본인만 | 본인만 | |
| users/{userId}/todos | 본인 + 공유 멤버 | 본인만 | CollectionGroup으로 공유 읽기 |
| families/{familyId} | 인증된 사용자 | 인증된 사용자 | |
| families/{familyId}/* | 인증된 사용자 | 인증된 사용자 | 서브컬렉션 포함 |
| memberships | 인증된 사용자 | 인증된 사용자 | |
| analysis_jobs | 본인 작업만 | 취소만 가능 | 서버에서 생성 |
| ai_cache/{userId} | 본인만 | 본인만 | |

### 5.2 CollectionGroup 특별 규칙

```javascript
// 공유된 todos 읽기
match /{path=**}/todos/{todoId} {
  allow read: if isAuthenticated()
    && resource.data.visibility == 'shared';
}
```

---

## 6. 데이터 마이그레이션 히스토리

### Phase 1 -> Phase 2 (진행 중)

**변경 내용**:
- Todo 저장 위치: `families/{groupId}/todos` -> `users/{userId}/todos`
- 그룹 공유: `familyId` 단일 값 -> `sharedGroups` 배열
- 가시성 추가: `visibility` 필드 ('private' / 'shared')
- 소유권 추가: `ownerId` 필드

**하위 호환성**:
- `eventType`: 'personal' -> 'schedule' 자동 변환
- `repeatType`: `recurrenceType`으로 폴백
- `assigneeId`: `participants`로 폴백

---

## 7. 쿼리 패턴 예시

### 7.1 현재 그룹의 공유된 할일 조회

```dart
// CollectionGroup 쿼리로 모든 사용자의 todos에서 검색
FirebaseFirestore.instance
    .collectionGroup('todos')
    .where('sharedGroups', arrayContains: currentGroupId)
    .where('visibility', isEqualTo: 'shared')
    .get();
```

### 7.2 특정 날짜의 할일 조회

```dart
final normalizedDate = DateTime(date.year, date.month, date.day);
final nextDay = normalizedDate.add(Duration(days: 1));

FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('todos')
    .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate))
    .where('dueDate', isLessThan: Timestamp.fromDate(nextDay))
    .get();
```

### 7.3 사용자의 모든 멤버십 조회

```dart
FirebaseFirestore.instance
    .collection('memberships')
    .where('userId', isEqualTo: currentUserId)
    .get();
```

### 7.4 리마인더 알림 대상 조회 (서버)

```dart
FirebaseFirestore.instance
    .collectionGroup('todos')
    .where('isCompleted', isEqualTo: false)
    .where('nextReminderAt', isLessThanOrEqualTo: Timestamp.now())
    .get();
```

---

## 8. 주의사항

### 8.1 문서 크기 제한
- Firestore 문서 최대 크기: 1MB
- `photoUrls`, `participants` 등 배열 필드 증가 주의
- 대량 데이터는 서브컬렉션으로 분리

### 8.2 배열 필드 무한 증가 방지
- `remindersSent`: 완료된 알림 삭제 로직 필요
- `readBy`: 채팅 메시지별로 분리 (서브컬렉션 고려)

### 8.3 오프라인 지원
- Smart Provider 패턴으로 데모 데이터 제공
- 실시간 리스너 사용 시 `enablePersistence` 활성화

### 8.4 날짜 처리
- 모든 날짜 비교 시 `normalizeDate()` 사용
- Timestamp <-> DateTime 변환 주의

---

*최종 업데이트: 2026-01-28*
