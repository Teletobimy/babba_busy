# BABBA (바빠)

바쁜 일상 관리 및 공유 앱 - Todolist, 공유 일정, 추억 지도, 가계부

## 기능

### 1. TodoList (메인)
- 원클릭 체크로 간편하게 완료 표시
- 각 할일에 간단 노트 첨부 가능
- 그룹 멤버에게 할일 할당 (가족, 친구, 동료)
- 반복 할일 설정 (매일/매주/매월)
- **Gemini AI 요약**: 오늘의 할일 요약

### 2. 스케줄러 (캘린더)
- 월간/주간 뷰 전환
- 일정 생성 시 참여자 선택
- 구성원별 색상으로 일정 표시
- 일정 상세에서 댓글/메모 가능

### 3. 추억 지도
- 네이버 지도 기반 추억 장소 마킹
- 각 장소에 사진 여러 장 업로드
- 가족 댓글 쓰레드 (대화형)
- 날짜/장소별 타임라인 뷰
- 장소 카테고리 (여행, 맛집, 일상 등)

### 4. 공유 가계부
- 수입/지출 기록 (금액, 날짜, 메모)
- 카테고리별 분류 (식비, 교통, 쇼핑 등)
- 고정 지출 등록 (월세, 구독 등)
- 월간/연간 통계 차트

## 기술 스택

- **프레임워크**: Flutter 3.x (Dart)
- **상태관리**: Riverpod 2.x
- **인증**: Firebase Auth
- **데이터베이스**: Cloud Firestore
- **파일 저장**: Firebase Storage
- **AI**: Google Gemini
- **지도**: 네이버 지도 SDK (연동 필요)
- **알림**: Firebase Cloud Messaging
- **차트**: fl_chart

## 시작하기

### 1. Firebase 설정

1. [Firebase Console](https://console.firebase.google.com/)에서 새 프로젝트 생성
2. FlutterFire CLI로 설정 파일 자동 생성:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. 또는 `.example` 파일을 복사하여 수동 설정:
   ```bash
   cp android/app/google-services.json.example android/app/google-services.json
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   cp web/firebase-messaging-sw.js.example web/firebase-messaging-sw.js
   cp .firebaserc.example .firebaserc
   ```
   복사한 파일의 `YOUR_*` placeholder를 실제 Firebase 프로젝트 값으로 교체하세요.

### 2. 환경 변수

프로젝트 루트에 `.env` 파일을 생성합니다 (git에 커밋되지 않음):
```bash
# .env (이 파일은 .gitignore에 포함됨)
GEMINI_API_KEY=your_gemini_api_key
```

앱 빌드 시 `--dart-define`으로 설정을 주입합니다:
```bash
flutter run \
  --dart-define=AI_API_URL=https://your-cloud-run-url \
  --dart-define=VERSION_JSON_URL=https://your-project.web.app/version.json \
  --dart-define=APP_WEB_URL=https://your-project.web.app
```

### 3. 네이버 지도 설정 (선택)

추억 지도 기능을 사용하려면 네이버 지도 SDK를 연동해야 합니다.
현재는 플레이스홀더로 구현되어 있습니다.

### 4. 실행

```bash
flutter pub get
flutter run
```

## 프로젝트 구조

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── main_shell.dart
├── core/
│   └── theme/
│       ├── app_colors.dart
│       ├── app_typography.dart
│       └── app_theme.dart
├── features/
│   ├── auth/
│   ├── home/
│   ├── todo/
│   ├── calendar/
│   ├── memory/
│   ├── budget/
│   └── settings/
├── shared/
│   ├── widgets/
│   ├── models/
│   └── providers/
└── services/
    ├── firebase/
    └── gemini/
```

## 디자인

- **테마**: 따뜻하고 포근한 파스텔톤
- **Primary Color**: Coral (#E8A87C)
- **Secondary Color**: Sage (#85DCBA)
- **Accent Color**: Lavender (#C3B1E1)
- **다크 모드 지원**: 시스템 설정 자동 감지

## 라이선스

MIT License
# babba_busy
