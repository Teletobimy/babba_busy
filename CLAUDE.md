# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BABBA (바빠) - 바쁜 일상 관리 및 공유 앱. Flutter 기반 가족/그룹 공유 애플리케이션으로 할일, 일정, 추억 지도, 가계부 기능을 제공합니다.

## Build & Run Commands

```bash
# 의존성 설치
flutter pub get

# 앱 실행
flutter run

# 코드 분석
flutter analyze

# 코드 생성 (Riverpod, JSON serializable)
dart run build_runner build
dart run build_runner watch  # 감시 모드
```

## Architecture

### State Management: Riverpod

Provider 계층 구조:
1. **Auth Layer**: `authStateProvider` → `currentUserProvider` → `currentUserDataProvider`
2. **Group Layer**: `userMembershipsProvider` → `selectedGroupIdProvider` → `currentGroupProvider`
3. **Feature Layer**: `todosProvider`, `eventsProvider`, `memoriesProvider`, `transactionsProvider`
4. **Smart Layer**: `smartTodosProvider` 등 - 데모/실제 데이터 자동 전환

### Smart Provider 패턴

`lib/shared/providers/smart_provider.dart`에서 Firebase 연결 상태에 따라 데모 데이터와 실제 Firestore 데이터를 자동 전환합니다. 오프라인 개발 및 테스트 시 유용합니다.

### Navigation: GoRouter

`lib/app/router.dart`에서 인증 상태 기반 리다이렉트:
- 미인증 → `/auth/login`
- 인증됨, 그룹 없음 → `/onboarding`
- 인증됨, 그룹 있음 → `/home`

### Feature Module 구조

각 feature는 다음 구조를 따릅니다:
```
features/{feature_name}/
├── {feature}_screen.dart      # 메인 화면
├── widgets/                   # feature 전용 위젯
└── (services/)                # feature 전용 서비스
```

공유 리소스는 `shared/` 아래:
- `providers/`: Riverpod 상태 관리
- `models/`: Firestore 데이터 모델 (fromFirestore/toFirestore 패턴)
- `widgets/`: 공통 UI 컴포넌트

### Firestore 데이터 구조

```
users/{userId}
families/{groupId}
memberships/{membershipId}  # userId + groupId 조합
families/{groupId}/todos/{todoId}
families/{groupId}/events/{eventId}
families/{groupId}/memories/{memoryId}
families/{groupId}/transactions/{txId}
```

## Key Patterns

### Firestore Model

```dart
class Model {
  factory Model.fromFirestore(DocumentSnapshot doc) { ... }
  Map<String, dynamic> toFirestore() { ... }
  Model copyWith({ ... }) { ... }
}
```

### Service Pattern

```dart
final myServiceProvider = Provider<MyService>((ref) => MyService(ref));

class MyService {
  final Ref _ref;
  MyService(this._ref);
  // _ref.read()로 다른 provider 접근
}
```

## Configuration

- Firebase 설정 파일: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- Gemini API 키: `.env` 파일 또는 `--dart-define`으로 주입
- 테마 색상: `lib/core/theme/app_colors.dart` (Coral, Sage, Lavender 파스텔 톤)

## Multi-Group Support

사용자는 여러 그룹에 소속 가능하며, 그룹별로 다른 닉네임/색상 사용 가능. `Membership` 모델이 user-group 관계를 관리합니다.

## Todo/Event Data Model Rules

### 1. 데이터 필드 사용 규칙

#### 날짜/시간 필드
- `dueDate`: 마감일 (할일) 또는 이벤트 날짜 (시간 미정)
- `startTime`: 이벤트 시작 시간 (시간 정보 있을 때)
- `endTime`: 이벤트 종료 시간 (optional)
- `hasTime`: 시간 정보 유무 플래그
  - `true`: startTime 필수, dueDate는 날짜 기준
  - `false`: dueDate만 사용, startTime/endTime 무시

#### 할당/참여자 필드
- `assigneeId`: 담당자 (단일, legacy)
- `participants`: 참여자 목록 (다중, 권장)
- **필터링 시 둘 다 확인**: `isAssignedTo(userId)` 사용

#### 이벤트 타입
- `eventType`: `TodoEventType.todo` | `personal` | `event`
  - `todo`: 개인 할일 (시간 미정, 체크리스트)
  - `personal`: 개인 일정 (시간 있을 수 있음)
  - `event`: 그룹 공유 일정 (시간 있을 수 있음)

#### 공유/가시성
- `visibility`: `private` (본인만) | `shared` (그룹 공유)
- `sharedGroups`: 공유된 그룹 ID 목록
- `ownerId`: 소유자 userId

### 2. Provider 사용 규칙

#### 홈 화면
- `smartTodosProvider`: 기본 할일 목록
- `smartTodayCompletedTodosProvider`: 오늘 완료한 할일 (AI 요약용)
- `smartUpcomingExpandedTodosProvider`: 다가오는 일정 (반복 확장 포함)
- `selectedMemberFilterProvider`: 멤버 필터 (그룹 변경 시 자동 리셋)

#### 캘린더 화면
- `expandedTodosForMonthProvider`: 월간 뷰 점 표시 (반복 확장 + 공유 필터)
- `smartTodosForDateProvider`: 일/주/모달 목록 (반복 확장 + 공유 필터)
- `showCompletedInCalendarProvider`: 완료 항목 표시 토글

### 3. 날짜 처리 규칙

#### 날짜 정규화
- **항상 `normalizeDate()` 사용**: 모든 날짜 비교 전에 시간 제거
- **Timezone 무시**: 로컬 시간 기준
- 위치: `lib/shared/utils/date_utils.dart`

```dart
DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
```

#### 날짜 매칭 로직
- `hasTime == true`: startTime~endTime 범위 확인 (날짜 정규화 후)
- `hasTime == false`: dueDate만 비교 (날짜 정규화 후)

### 4. 반복 일정 규칙

#### 인스턴스 ID 형식
```
{parentTodoId}_{yyyyMMdd}
예: abc123_20260123
```

#### 반복 확장 제한
- 최대 100개 인스턴스 생성
- 월 범위 기반 확장 (필요한 만큼만)
- `parentTodoId` 필드로 원본 추적

#### 반복 인스턴스 삭제 불가
- 인스턴스는 동적 생성 (Firestore에 저장 안 됨)
- 부모 todo만 삭제 가능

### 5. 완료 항목 표시 규칙

#### 홈 화면
- 완료된 할일 섹션 분리 표시
- 전체 표시 (제한 없음)

#### 캘린더 화면
- 토글 옵션 제공: `showCompletedInCalendarProvider`
- 기본값: 표시 (`true`)
- 모든 뷰에 일관되게 적용 (월/주/일/모달)

### 6. 필터링 규칙

#### 멤버 필터
- `assigneeId` AND `participants` 모두 확인
- 그룹 변경 시 자동 리셋

#### 공유 설정 필터
- 작성자의 `sharedEventTypes` 확인
- `eventType`이 포함된 경우만 표시

#### Private/Shared 필터
- Private: `ownerId` 또는 `createdBy`가 본인인 경우만
- Shared: `sharedGroups`에 현재 그룹 포함 확인

## Common Pitfalls (주의사항)

### ❌ 하지 말 것
1. `ref.read()`로 UI에서 데이터 읽기 → `ref.watch()` 사용
2. 날짜 비교 시 시간 정보 포함 → `normalizeDate()` 사용
3. `assigneeId`만 확인 → `participants`도 확인
4. 반복 인스턴스 직접 삭제 시도 → 부모 삭제만 가능
5. 완료 항목 하드코딩 필터 → 토글 provider 사용

### ✅ 할 것
1. 새 일정 타입 추가 시 `TodoEventType` enum 확장
2. 필터 추가 시 모든 관련 provider 업데이트
3. 날짜/시간 로직 변경 시 `_isTodoOnDate()` 테스트
4. Provider 변경 시 홈/캘린더 둘 다 확인
