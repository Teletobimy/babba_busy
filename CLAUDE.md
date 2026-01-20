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
