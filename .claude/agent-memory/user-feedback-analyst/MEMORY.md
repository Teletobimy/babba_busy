# BABBA User Feedback Analyst Memory

## 반복 발견되는 UX 패턴

### 1. 정보 과부하 문제 (Information Overload)
- AddTodoSheet: 1400줄 이상, 너무 많은 옵션이 한 화면에
- 사용자는 간단한 작업도 복잡하게 느낌
- **권장 패턴**: "퀵 모드" + "상세 모드" 분리

### 2. 타입 시스템 혼란
- todo/schedule/event 구분이 직관적이지 않음
- 각 타입별 완료/반복 규칙이 다른데 설명 없음
- **권장 패턴**: 타입 선택 시 짧은 설명 또는 툴팁

### 3. 조건부 UI 발견성 문제
- 날짜 선택해야 시간/반복/알림 옵션 표시
- 사용자가 옵션 존재를 모를 수 있음

### 4. 반복 일정 제한
- 인스턴스 개별 완료/삭제 불가 (동적 생성)
- 자주 요청되는 기능

## 주요 코드 위치

### 할일 관련
- `lib/features/todo/widgets/add_todo_sheet.dart` - 추가/수정 시트
- `lib/features/todo/widgets/todo_item_card.dart` - 할일 카드
- `lib/features/home/widgets/compact_todo_card.dart` - 홈 컴팩트 카드
- `lib/shared/models/todo_item.dart` - 데이터 모델

### Provider 구조
- `smartTodosProvider` - 홈 화면 기본
- `selectedMemberFilterProvider` - 멤버 필터
- `completedSectionExpandedProvider` - 완료 섹션 상태

## 온보딩/인증 UX 패턴

### 5. 첫 사용자 경험 문제
- 로그인 화면: 앱 가치 전달 부족 ("바쁜 일상을 함께" 한 줄만)
- 온보딩 화면: 기능 설명 없이 바로 그룹 선택으로 진입
- **권장 패턴**: 기능 소개 슬라이드 또는 인터랙티브 투어

### 6. 그룹 설정 혼란
- "혼자 시작하기" vs "그룹 만들기" 차이 불명확
- 초대 코드 공유 방법 안내 부족 (클립보드 복사 버튼 없음)
- 닉네임/색상이 왜 필요한지 설명 없음

### 7. 인증 흐름 개선점
- 회원가입에서 닉네임 수집 없음 (온보딩에서 별도 입력)
- Google 로그인 후 바로 그룹 설정으로 넘어가 당황
- 비밀번호 규칙(6자 이상) 사전 안내 없음

### 주요 코드 위치 - 인증/온보딩
- `lib/features/auth/login_screen.dart` - 로그인 화면
- `lib/features/auth/signup_screen.dart` - 회원가입 화면
- `lib/features/auth/onboarding_screen.dart` - 그룹 설정 (759줄)
- `lib/features/auth/widgets/group_setup_dialog.dart` - 그룹 추가 다이얼로그
- `lib/app/router.dart` - 인증 상태 기반 리다이렉트

## 분석 시 체크리스트
- [ ] 기존 기능인지 확인 (사용자가 모르는 경우 안내)
- [ ] CLAUDE.md의 규칙과 충돌하지 않는지 확인
- [ ] Provider 패턴 일관성 확인
- [ ] 다크모드 대응 확인 (isDark)
- [ ] AppColors, AppTheme 사용 확인

## 최근 개발 컨텍스트 (2026-02-11)

### 심리검사 안정화
- 답변 순서/인덱스 서버 검증 추가 (`cloud-run/routers/psychology.py`)
- 완료 세션 재전송 idempotent 처리, 질문 순서 충돌 시 409 처리
- 비동기 분석 후 동기 재분석 경로 제거로 중복 비용 방지 (`lib/features/tools/psychology/psychology_test_screen.dart`)
- 결과 동기화 시 빈 answers 덮어쓰기 방지 (`lib/shared/providers/psychology_result_provider.dart`)

### 메모 카테고리 분석 파이프라인 신규 도입
- 3-에이전트 구조:
  1. Planner (분석 축/검증 기준 수립)
  2. Compactor (청크별 문맥 압축 + evidence)
  3. Synthesizer (통합 리포트/액션/리스크 도출)
- 구현 위치: `cloud-run/agents/memo_category_agents.py`
- 비동기 job 타입 추가: `memo_category_analysis`
- submit endpoint: `POST /api/jobs/memo/category/submit`
- result endpoint: `GET /api/memo/category-analysis/{analysis_id}`
- history endpoint: `GET /api/memo/category-analysis/history`

### 운영/비용 방어
- 메모 단건 분석 API 입력 길이 상한 추가 (`MAX_MEMO_ANALYZE_CHARS = 20000`)
- 분석 job 생성은 Firestore transaction 기반 유지
