# BABBA (바빠)

가족과 소규모 그룹이 함께 쓰는 생활 운영 앱입니다. 현재 배포된 제품은 `홈`, `캘린더`, `도구`, `설정`을 중심으로, 메모/앨범/가계부/사람들/대화방/커뮤니티/사업검토/심리검사 모듈과 리포트, 함께 시간, 집안일 로테이션, 시간표 화면을 제공합니다.

## 현재 기능

- `홈`: 빠른 할 일 추가, AI 요약, 다가오는 일정, 활동 피드, D-day
- `캘린더`: 월/주/일 보기, 그룹 일정 조회, 필터, AI 일정 처리
- `도구`: `메모`, `앨범`, `가계부`, `사람들`, `대화방`, `커뮤니티`, `사업검토`, `심리검사`
- `설정`: 그룹/초대, 모듈 on/off, 테마, 알림, 업데이트, AI 진단
- 보조 화면: `리포트`, `함께 시간`, `집안일 로테이션`, `시간표`, 로그인/회원가입/온보딩

## 기술 구성

- Flutter + Riverpod + GoRouter
- Firebase Auth, Firestore, Storage, Messaging, Hosting, Cloud Functions
- Cloud Run FastAPI AI 백엔드 + Gemini
- 모바일, 웹, iOS, Android 지원

## 백엔드 분리

이 프로젝트는 AI 기능을 두 계층으로 분리합니다.

- `Firebase`: 인증, 데이터 저장, 푸시 알림, 트리거, 호스팅
- `Cloud Run`: 일일/주간 요약, 홈/가족 채팅/메모 요약, 사업 검토, 심리검사, AI 작업 처리

앱은 `AI_API_URL`을 `--dart-define`으로 받아 Cloud Run API를 호출합니다.

## 시작하기

### 1. 준비물

- Flutter SDK
- Firebase CLI
- FlutterFire CLI
- Python 3.11+
- Node.js 20+

### 2. Firebase 설정

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

생성된 `lib/firebase_options.dart`와 플랫폼별 Firebase 설정 파일을 준비합니다.

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

### 3. 환경 변수

앱 실행 시 필요한 값은 `--dart-define`으로 주입합니다.

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key \
  --dart-define=AI_API_URL=http://localhost:8080 \
  --dart-define=VERSION_JSON_URL=https://your-project.web.app/version.json \
  --dart-define=APP_WEB_URL=https://your-project.web.app \
  --dart-define=FCM_VAPID_KEY=your_fcm_vapid_key
```

Cloud Run AI 서버는 `cloud-run/.env.example`을 복사해 `.env`를 만들고 다음 값을 채웁니다.

- `GEMINI_API_KEY`
- `GCP_PROJECT_ID`
- `CORS_ORIGINS`

### 4. 로컬 실행

```bash
flutter pub get
flutter run
```

Cloud Run AI 서버를 별도로 실행하려면:

```bash
cd cloud-run
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```

Functions 에뮬레이터를 돌리려면:

```bash
cd functions
npm install
npm run serve
```

## 배포

- Cloud Run: `cd cloud-run && gcloud builds submit --config cloudbuild.yaml`
- Firebase Functions: `cd functions && npm run deploy`
- Web Hosting: `flutter build web` 후 `firebase deploy --only hosting`

## 프로젝트 구조

```text
lib/
  app/                # 라우팅, shell, 앱 진입점
  features/           # 홈, 캘린더, 도구, 메모, 앨범, 가계부, 사람들, 리포트 등
  services/           # AI, Firebase, 업데이트, 알림
  shared/             # 모델, provider, 유틸, 공용 위젯
cloud-run/            # FastAPI 기반 AI 백엔드
functions/            # Firestore 트리거, 알림, 스케줄 작업
docs/                 # 아키텍처/마이그레이션/QA 문서
```

## 라이선스

MIT License
