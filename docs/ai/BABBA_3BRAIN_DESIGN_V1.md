# BABBA 3-Brain Architecture v1

> **작성일**: 2026-05-01
> **상태**: Working Draft (B1 phase 진입 직전)
> **참조 원본**: SUPERWORK `docs/ai/phase11/PLATFORM_BRAIN_SCHEMA.md`, `docs/ai/PROACTIVE_AI_DESIGN.md`, `services/tier0_orchestrator.py`
> **선행**: `RFC-001~004`, `MIGRATION_BACKLOG_V1.md`, AI consent + audit infra (2026-04-30 라이브)

---

## 0. Executive Summary

BABBA를 단일 AI 챗봇이 아니라 **3-tier brain 시스템**으로 재구성. SUPERWORK가 B2B SaaS에서 검증한 Platform/Company/User 위계를 가족 앱(B2C) 컨텍스트로 변형:

| Tier | 책임 | 데이터 소유 | 응답 대상 | reflection 주기 |
|---|---|---|---|---|
| 🌐 **Platform Brain** | 전체 시스템 분석, 운영자 보조, 모듈/문서 자동 셋업 | `_system/platform_brain_*` | **운영자(`khk9462`)** 전용 | 주1회 (일요일 02:00 KST) |
| 👨‍👩‍👧 **Group Brain** | 가족 단위 패턴 → 가족 proactive 제안 | `families/{fid}/ai_brain/*` | 가족 멤버 전체 | 일1회 (03:30 KST) |
| 👤 **User Brain** | 개인 일정/할일/메모/감정 패턴 → 개인 proactive | `users/{uid}/ai_brain/*` | 본인 1명 | 매 60s tick (active user only) |

핵심 원칙:
1. **격리**: 가족 데이터가 다른 가족에게 노출되지 않음. Platform Brain은 운영자 외 비공개.
2. **Cascade injection**: 위 tier에서 만든 응축 지식을 아래 tier로 매일/매주 주입.
3. **3단 비용 게이트**: rule → keyword → LLM-judge ≥0.7. AI 호출 90% 절감 목표.
4. **3단 kill switch**: global / per-family / emergency fallback. 폭주/오작동 시 즉시 정지.
5. **새 인프라 0**: 옵션 B 하이브리드(Cloud Run min_instances=1 + Functions trigger) 위에 모든 brain이 올라감.

---

## 1. 3개 Brain의 Capability 매트릭스

### 👤 User Brain — 가장 활동적 (매 tick)

**Capability**:
- 다음날/이번 주 일정 정리 + 우선순위 추천
- "이번 주 완료율 60% — 격려 + 분석" (격려 메시지)
- "내일 마감 todo 3개 — reminder 미설정" (rule-based 즉시 제안)
- 메모 카테고리 분석 (LLM 호출, 무거운 것)
- 감정/리듬 패턴 (이번 주 평균 기상 시간, 활동 시간대)

**Knowledge base 필드** (`users/{uid}/ai_brain/main`):
- `personalKnowledge`: 본인이 명시적으로 알린 선호/제약 (예: "우유 알러지", "주말은 가족 시간")
- `inferredPatterns`: 행동 데이터에서 추론한 패턴 (예: "주로 21시~23시 todo 처리")
- `currentState`: 현재 상태 스냅샷 (active todos, upcoming events count, last reflection)
- `platformContext`: Platform Brain이 주입한 외부 신호 (공휴일/계절/트렌드)
- `groupContext`: 본인이 속한 가족들의 상태 요약

### 👨‍👩‍👧 Group Brain — 중간 빈도 (일1회)

**Capability**:
- "이번 주 화요일 저녁 모두 비어있어요. 가족 시간?"
- "엄마/아빠/지수 이번 달 가계부 외식 비중 ↑ — 다음 주 줄여볼까?"
- "공유 할일 중 3주째 멈춘 항목 있어요 — 분담 재조정?"
- "지수 시험 기간 (캘린더 감지) — 외식/외출 일정 자제 제안"
- 가족 행사 D-day 자동 정리 + 사전 준비 체크리스트

**Knowledge base 필드** (`families/{fid}/ai_brain/main`):
- `familyKnowledge`: 가족 명시적 정보 (구성원 역할, 가족 규칙, 알러지/건강)
- `sharedRhythms`: 공유 리듬 (저녁 시간, 가족 시간, 청소 로테이션 패턴)
- `currentState`: 활성 공유 todo, upcoming 공유 일정, 최근 활동 피드 요약
- `platformContext`: Platform Brain 주입 (한국 공휴일/계절/트렌드)
- `memberStates`: 각 멤버 User Brain의 currentState 압축본 (private 필드 제외)

### 🌐 Platform Brain — 가장 메타 (주1회 + 운영자 호출 시)

**Capability**:
- 운영자 Daily Briefing (매일 09:00 KST FCM/이메일)
  - DAU/MAU, retention, accept rate
  - 어제 발생 에러/예외/성능 이슈
  - 어제 첫 가입 / 첫 accept 사용자
  - 자동 추천 1개 ("X 모듈 사용률 낮음 → A안 / B안")
- 주간 Strategic Review (일요일)
  - 7일 패턴 분석 + KPI 트렌드
  - RFC 백로그 우선순위 재계산 (사용자 데이터 반영)
  - 다음 주 추천 작업 3개
- 자동 docs 생성 (Phase 진입 시 → execution board, 새 feature 도입 시 → design memo)
- 하위 brain 셋업 관리 (새 가족/사용자 가입 시 brain 시드)

**Knowledge base 필드** (`_system/platform_brain_knowledge_base/main`):
- `productKnowledge`: BABBA 도메인 지식 (한국 가족 모델, 명절/계절 룰, 학사 일정)
- `operationsKnowledge`: 시스템 운영 지식 (배포/모니터링/롤백 패턴)
- `rfcBacklog`: 백로그 우선순위 + 데이터 기반 재계산
- `version`, `lastUpdated`, `bytesUsed` (1MB 제한 모니터링)

---

## 2. Firestore 데이터 구조

### 2.1 Platform Brain (운영자 전용, `_system/`)

```
_system/
├── platform_brain_knowledge_base/main         # 단일 doc, 주1회 reflection으로 업데이트
├── platform_brain_signals/{signalId}          # 외부 신호 (공휴일/날씨/뉴스). TTL 30d
├── platform_brain_analytics/{type_period}     # daily/weekly KPI. type=benchmark|reflection|daily
├── platform_brain_directives/{directiveId}    # ⭐ 운영자에게 보낼 작업 큐 (BABBA 특화)
└── platform_brain_playbooks/{playbookId}      # 잘 동작한 패턴 (Phase B8에서 활성화)
```

**`platform_brain_directives` 스키마** (BABBA 특화):
```typescript
interface PlatformDirective {
  id: string;
  type: "alert" | "suggestion" | "auto_action_proposal";
  priority: "high" | "med" | "low";
  title: string;                                // 예: "APP-003 home summary cache miss 80%"
  body: string;                                 // 분석 + 제안
  detectedAt: Timestamp;
  resolvedAt?: Timestamp;
  resolvedBy?: "user" | "auto";
  proposedAction?: {
    type: "redeploy" | "create_doc" | "modify_setting" | "manual";
    payload: object;                            // 자동 처리 가능 시 사용
    requiresApproval: boolean;
  };
}
```

### 2.2 Group Brain (가족별, `families/{fid}/ai_brain/`)

```
families/{fid}/ai_brain/
├── main                                       # KB
├── reflections/{period}                       # 일1회 reflection (예: weekly_2026W18)
├── suggestions/{suggestionId}                 # 가족 단위 proactive 제안
├── exposures/{exposureId}                     # impression 기록. TTL 90d
└── traces/{traceId}                           # lifecycle stamped timeline. TTL 90d
```

### 2.3 User Brain (개인별, `users/{uid}/ai_brain/`)

```
users/{uid}/ai_brain/
├── main                                       # KB
├── reflections/{period}                       # 매tick 또는 일1회
├── suggestions/{suggestionId}                 # 개인 proactive 제안
├── exposures/{exposureId}                     # TTL 90d
└── traces/{traceId}                           # TTL 90d
```

### 2.4 기존 인프라 재사용 (변경 없음)

- `users/{uid}/tool_audit_log/{auditId}` — AI tool 실행 audit (이미 라이브)
- `users/{uid}/ai_action_requests/{id}` — pending consent 문서 (이미 라이브)

---

## 3. firestore.rules 추가 블록 (B1 phase에서 적용)

```
match /users/{userId}/ai_brain/{document=**} {
  allow read: if isOwner(userId);
  allow write: if false;                       // Cloud Run admin SDK 전용
}

match /families/{familyId}/ai_brain/{document=**} {
  allow read: if isMemberOfGroup(familyId);    // 가족 멤버는 read 가능
  allow write: if false;                       // 서버만
}

// Platform Brain — 클라 모두 차단, 별도 Admin API로만 접근
match /_system/{document=**} {
  allow read, write: if false;
}
```

> 운영자 Admin UI는 Cloud Run의 `/api/admin/platform-brain` 라우트를 통해 접근 (Firebase Auth + custom claim `level=admin` 검증).

---

## 4. firestore.indexes.json 신규 인덱스 (B1~B7 단계적)

| # | collectionGroup | scope | fields | 사용처 |
|---|---|---|---|---|
| 1 | `suggestions` | COLLECTION_GROUP | `userId ASC, createdAt DESC` | 사용자 최근 제안 피드 |
| 2 | `suggestions` | COLLECTION_GROUP | `familyId ASC, createdAt DESC` | 가족 최근 제안 피드 |
| 3 | `exposures` | COLLECTION_GROUP | `userId ASC, shownAt DESC` | TTFV/CTR 분석 |
| 4 | `traces` | COLLECTION_GROUP | `createdAt ASC` (TTL anchor) | retention cleanup |
| 5 | `platform_brain_signals` | COLLECTION | `category ASC, createdAt DESC` | Platform 신호 피드 |
| 6 | `platform_brain_directives` | COLLECTION | `priority ASC, detectedAt DESC` | 운영자 우선순위 큐 |

fieldOverrides (collectionGroup TTL 쿼리용):
- `exposures.createdAt` ASCENDING (cleanup)
- `traces.createdAt` ASCENDING (cleanup)
- `platform_brain_signals.expiresAt` ASCENDING

---

## 5. Orchestrator Loop 설계 (Cloud Run APScheduler)

```
┌─────────────────────────────────────────────────────────────┐
│ babba-ai-api (Cloud Run, asia-northeast3, min_instances=1) │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  매 60s tick (orchestrator_loop):                           │
│  ┌─────────────────────────────────────────┐                │
│  │ 1. global kill switch check (캐시 30s)  │                │
│  │ 2. emergency fallback check             │                │
│  │ 3. active users 조회 (지난 5분 활동)    │                │
│  └────────────┬────────────────────────────┘                │
│               │                                             │
│               ▼ for each active user                        │
│  ┌─────────────────────────────────────────┐                │
│  │ User Brain tick:                        │                │
│  │ a. family kill switch check             │                │
│  │ b. state_hash 비교 → 변경 없으면 skip   │                │
│  │ c. rule_based_dispatch (게이트 1단)     │                │
│  │ d. keyword filter (게이트 2단)          │                │
│  │ e. LLM-judge ≥0.7 (게이트 3단)          │                │
│  │ f. suggestion 생성 + lifecycle trace    │                │
│  └─────────────────────────────────────────┘                │
│                                                             │
│  매일 03:30 KST (daily reflection cron):                    │
│  ┌─────────────────────────────────────────┐                │
│  │ for each active family:                 │                │
│  │   Group Brain reflection (Gemini)       │                │
│  │   → families/{fid}/ai_brain/reflections │                │
│  └─────────────────────────────────────────┘                │
│                                                             │
│  매주 일요일 02:00 KST:                                     │
│  ┌─────────────────────────────────────────┐                │
│  │ Platform Brain reflection                │                │
│  │   → _system/platform_brain_analytics    │                │
│  │ → cascade injection 다음 일1회/매tick   │                │
│  └─────────────────────────────────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 3단 비용 게이트 (SUPERWORK 검증된 패턴)

| Stage | 종류 | 비용 | 통과율 (목표) |
|---|---|---|---|
| **Stage 1** | Rule-based registry (template + 조건문) | LLM 호출 0 | 입력의 50% |
| **Stage 2** | Keyword 사전 필터 (한국어 도메인) | LLM 호출 0 | 남은 30% |
| **Stage 3** | LLM-judge `relevanceScore ≥ 0.7` | Gemini Flash 1회 (~$0.0001) | 남은 20% → 진짜 LLM 작업으로 |

### Stage 1 예시 규칙 (BABBA)

```python
# cloud-run/services/suggestion_rules.py (B2 phase 신설)

def rule_overdue_with_no_reminder(user_state) -> Optional[Suggestion]:
    """내일 마감 todo 있는데 reminder 미설정 — LLM 호출 0으로 즉시 제안"""
    todos = user_state.upcoming_todos
    targets = [t for t in todos if t.is_due_tomorrow and not t.has_reminder]
    if not targets:
        return None
    return Suggestion(
        type="reminder_setup",
        title=f"내일 마감 할일 {len(targets)}개에 알림 설정하기",
        action_type="bulk_set_reminder",
        confidence=0.95,
    )
```

---

## 7. 8-stage Suggestion Lifecycle + 6 Timestamp Event

### 8 stages
```
signal      → 트리거 신호 감지 (Firestore 변경, cron, message keyword)
dedup       → 중복 제거 (fingerprint 기반)
policy      → 정책 게이트 통과 (kill switch, scope, frequency)
agent       → 에이전트 실행 시작 (LLM 또는 rule)
suggestion  → 제안 객체 생성 (Firestore write)
shown       → 사용자 화면 노출 (firstShownAt)
accepted    → 사용자 수락 (firstAcceptAt) — optional
completed   → 후속 action 완료 (실제 todo 생성/일정 추가) — optional
```

### 6 timestamps (각 stage 시각 기록)
- `stages.signal`, `stages.dedup`, `stages.policy`, `stages.agent`, `stages.suggestion` — 모든 제안 필수
- `stages.shown`, `stages.accepted`, `stages.completed` — 사용자 인터랙션 시 추가

### Funnel 분석 산출
- TTFV(Time-To-First-Value): `stages.signal → stages.shown` median
- Accept rate: `accepted / shown`
- Completion rate: `completed / accepted`
- Drop-off stage: 어디서 가장 많이 빠지는지

---

## 8. Phase 단계 (B1~B8, ~8주)

| Phase | 내용 | 기간 | 산출물 |
|---|---|---|---|
| **B1** | User Brain 스켈레톤 (schemas, routes, rules, indexes) + 첫 reflection job | 1주 | `cloud-run/routers/user_brain.py`, schemas 확장, rules 락, indexes |
| **B2** | 3단 비용 게이트 (`suggestion_engine`) + lifecycle trace 인프라 | 1.5주 | `cloud-run/services/suggestion_engine/` |
| **B3** | User Brain proactive 첫 제안 1개 + Flutter UI 카드 | 1주 | 홈 화면 suggestion 카드, accept 플로우 |
| **B4** | Group Brain 도입 + 가족 단위 첫 제안 ("이번 주 가족 시간") | 1.5주 | `families/{fid}/ai_brain` 스키마 + reflection cron |
| **B5** | Platform Brain (운영자 전용) + Admin section in Settings | 1주 | `_system/platform_brain` 시드 + Admin API |
| **B6** | 6 lifecycle event instrumentation + retention dashboard | 0.5주 | TTFV/funnel 측정 + audit history 보강 |
| **B7** | Cascade injection (Platform → Group → User) | 1주 | 주1회 + 일1회 cron 연동 |
| **B8** | Playbook graduation 스키마 (활성화는 후속) | 0.5주 | 스키마만 |

---

## 9. 운영자 Brain 특화 (BABBA 차별점)

### 9.1 4가지 자동 산출물
1. **Daily Briefing** (FCM + Settings 카드, 매일 09:00 KST)
2. **Weekly Strategic Review** (일요일 18:00 KST)
3. **Auto-generated docs** (Phase 진입/feature 도입 시 자동 초안 생성)
4. **하위 brain 셋업** (새 가족/사용자 가입 시 시드)

### 9.2 운영자 인터페이스 (Settings 안 admin section)

```
/settings/admin (custom claim level=admin 가진 사용자만 보임)
├── 📊 Today's Briefing (Platform Brain Daily 산출물)
├── 📋 Active Directives (운영자 처리 큐)
├── 🤖 Suggested Auto-Actions (승인 대기)
├── 📚 Knowledge Base 편집
└── ⚙️ Kill Switches (global / per-family)
```

---

## 10. 인프라 매핑 (옵션 B 하이브리드 위에 올라감)

| 동작 | 위치 | 이유 |
|---|---|---|
| User Brain tick (60s) | Cloud Run APScheduler | always-warm, latency 0 |
| Group Brain reflection (일1회) | Cloud Run cron | 무거운 LLM, long-running |
| Platform Brain reflection (주1회) | Cloud Run cron | 동일 |
| Suggestion 노출 (사용자 화면) | Flutter + Cloud Run API | 기존 ai_*_sheet 패턴 재사용 |
| Lifecycle event 기록 (firstShownAt) | Flutter direct write to Firestore | latency 짧게 |
| Audit/idempotency | 이미 구현됨 (2026-04-30) | 그대로 재사용 |
| 운영자 Daily Briefing 발송 | Functions v2 onSchedule + FCM | 기존 알림 인프라 |
| External signals 동기화 (공휴일/날씨) | Cloud Scheduler → Cloud Run | RFC-003 §13 패턴 |

→ **새 인프라 0**. Cloud Run min_instances=1 (오늘 활성화 완료) 위에 모든 brain 동작.

---

## 11. SUPERWORK에서 가져온 검증된 패턴 (요약)

| # | 패턴 | 적용 phase |
|---|---|---|
| I1 | 3-tier brain 분리 | 전 phase |
| I2 | Reflection cascade (주1/일1/tick) | B1, B4, B7 |
| I3 | 8-stage lifecycle + 6 timestamps | B6 |
| I4 | 3단 kill switch + 30s 캐시 | B2 |
| I5 | 3단 비용 게이트 (rule → keyword → LLM-judge) | B2 |
| I6 | Shared(가족) vs Personal(개인) scope 분리 | B1, B4 |
| I7 | Post-action 제안 (도구 실행 직후) | B3 |
| I8 | 권한 L1~L3 (보호자/자녀/손님) | B4 |
| I9 | 데이터 흐름 그래프 감사 | B5 |
| I10 | Batch Sync 공용 신호원 | B5 |

---

## 12. SUPERWORK 시행착오 (BABBA 회피)

1. **TTL Policy 미등록** — 필드 추가 후 cleanup 미실행 → BABBA: 필드 추가 = TTL/cleanup 동시 등록 (오늘 audit retention 패턴)
2. **vector/composite 인덱스 미등록** — 자동 생성 누락, 프로덕션 느림 → BABBA: `firestore.indexes.json`에 사전 명시
3. **permission-denied 루프** — null companyId 416회 → BABBA: `familyId` schema required, null 차단
4. **activity_logs 무제한** — 무한 retention → BABBA: 처음부터 7~90일 retention + 별도 아카이브
5. **event_memories 고아** — 저장은 했지만 recall 안 함 → BABBA: 저장 전 "실제 read 시나리오 있나" 검증

---

## 13. BABBA에서 명시적으로 채택 안 함 (규모상 무리)

- K-anonymity 익명화 (회사 데이터 보호용 — 가족 ~30개 규모 무관)
- 멀티테넌시 3계층 (회사/부서/팀)
- 결재선/승인 체인 (비즈니스 결재용)
- AI 모델 라우팅 (Gemini 3종 — Flash 단일로 충분)
- Platform Admin 별도 페이지 (BABBA는 Settings 안 admin section만)

---

## 14. B1 Phase 즉시 시작 가능 작업 (1주)

```
Day 1-2  cloud-run/models/schemas.py:
            UserBrainKB, UserBrainReflection, UserBrainSuggestion 모델
         cloud-run/routers/user_brain.py 신설:
            GET /api/agent/brain/user/kb        (본인 KB 조회)
            GET /api/agent/brain/user/reflections (최근 reflections)
            GET /api/agent/brain/user/suggestions (최근 suggestions)
         firestore.rules: users/{uid}/ai_brain/* 락
         firestore.indexes.json: 6개 신규 인덱스

Day 3-4  cloud-run/services/user_brain_seed.py:
            새 사용자 가입 시 KB 시드 생성 (auth trigger 또는 첫 로그인)
         cloud-run/jobs/user_brain_reflection.py:
            매시간 active user 감지 → reflection 1개 작성
            (rule-based 단순 패턴 시작)

Day 5    Flutter:
            lib/services/ai/user_brain_service.dart 신설
            lib/shared/providers/user_brain_provider.dart
         settings_screen.dart에 "내 AI 패턴" 진입 (audit history 옆)

Day 6-7  통합 테스트 + 배포 + smoke
```

---

## 15. 측정 지표 (KPI)

| 지표 | 목표 | 측정 위치 |
|---|---|---|
| **Suggestion accept rate** | ≥ 35% | exposures + accepted timestamp |
| **TTFV** (signal → shown) | ≤ 500ms | traces |
| **Cost per active user (월)** | ≤ $0.30 | platform_brain_analytics.daily |
| **Stage 1 통과율 (rule-based)** | ≥ 50% | suggestion_engine logs |
| **Stage 3 LLM call rate** | ≤ 20% | suggestion_engine logs |
| **Kill switch 응답 시간** | ≤ 60s | orchestrator_loop |

---

## 16. 권한/접근 매트릭스

| 컬렉션 | 일반 사용자 read | 일반 사용자 write | Cloud Run admin | 운영자 (admin claim) |
|---|---|---|---|---|
| `users/{uid}/ai_brain/*` | 본인만 | ❌ | ✅ | ✅ (감사용) |
| `families/{fid}/ai_brain/*` | 가족 멤버만 | ❌ | ✅ | ✅ |
| `_system/platform_brain_*` | ❌ | ❌ | ✅ | ✅ via Admin API |

---

## 17. 마이그레이션 전략 (기존 데이터 무영향)

1. **신규 컬렉션**: B1부터 신규 작성, 백필 없음 (과거 데이터 무관)
2. **`tool_audit_log`/`ai_action_requests`**: 변경 없음, 그대로 재사용
3. **`Membership.role`**: 현재 admin/member → B4에서 L1/L2/L3 매핑 (admin → L1, member → L2 default)
4. **사용자 KB 시드**: 첫 reflection cron이 모든 active user에 대해 lazy 생성

---

## 18. 리스크 + 완화

| 리스크 | 원인 | 완화 |
|---|---|---|
| AI 호출 폭주 → 비용 폭발 | kill switch 미작동 | 3단 kill switch + 캐시 + 일일 cost cap alert |
| Platform Brain LLM이 잘못된 운영 제안 | 가짜 패턴 학습 | 운영자 승인 필수 (`requiresApproval=true`) |
| User Brain reflection이 개인정보 가족에게 노출 | scope 혼동 | `familyKnowledge` ≠ `personalKnowledge` 필드 분리 + scope 보안 룰 |
| Cold start (Cloud Run) | min_instances=0 시 5초 | min_instances=1 이미 적용 (2026-05-01) |
| Knowledge base 1MB 도달 | Platform KB 누적 | bytesUsed 모니터링 + 800KB 임계 시 분할 (Phase 후반) |

---

## 19. 결론

BABBA Phase 2(SpaceLift Phase 2) 진입 시점부터 본 3-brain 아키텍처를 점진 도입. **B1 (User Brain 스켈레톤)부터 시작**, 8주 후 Platform Brain까지 도착. 새 인프라 0, 옵션 B 하이브리드 위에 모두 올라감.

**다음 작업**:
- B1 즉시 착수 (이 문서 14절 참조)
- 진행 상황은 `docs/ai/BABBA_3BRAIN_PROGRESS.md`에 phase별 status 기록 (B1 시작 시 신설)

---

**End of document** — 19개 섹션, 3 brain × 4 컬렉션 + 6 인덱스 + 8 phase + 5 KPI
