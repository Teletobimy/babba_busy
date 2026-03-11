# QA Team 8 Execution Plan

## Status

- Status: `Working Draft`
- Staffing model: `seat-based`
- Team size: `8`
- Goal: multi-angle QA coverage for the BABBA + BABBAAI merge-in-progress

## Scope In This QA Wave

Current implemented slices that must be verified now:

- unified backend request context with `spaceId` and `familyId` compatibility
- backend adapters for `manage_todos`, `manage_calendar`, `manage_notes`
- frontend dual-read and dual-write behavior for `todo`, `calendar`, `memo`
- AI action-item creation path in tool result cards
- live production data protection and reconciliation readiness

Primary code and evidence targets:

- `BABBAAI/backend/middleware/user_context.py`
- `BABBAAI/backend/routers/agent.py`
- `BABBAAI/backend/services/agent_service.py`
- `BABBAAI/backend/tests/test_user_context.py`
- `BABBAAI/backend/tests/test_agent_safety.py`
- `BABBAAI/backend/tests/test_agent_todos.py`
- `BABBAAI/backend/tests/test_agent_calendar.py`
- `BABBAAI/backend/tests/test_agent_notes.py`
- `BABBAAI/frontend/components/tools/calendar-card.tsx`
- `BABBAAI/frontend/components/tools/memo-card.tsx`
- `BABBAAI/frontend/components/tools/todo-card.tsx`
- `BABBAAI/frontend/components/tools/tools-dashboard.tsx`
- `BABBAAI/frontend/components/ai/ai-tool-card.tsx`
- `BABBAAI/frontend/lib/tool-data-adapters.ts`

## Team Shape

| Seat | QA Angle | Primary Scope | Secondary Scope | Main Deliverable |
|---|---|---|---|---|
| QA-01 | Tenant Isolation Lead | auth, context, scope denial | security regression | tenant-boundary verdict |
| QA-02 | Live Data and Reconciliation Lead | production shape audit | drift detection | live-data readiness memo |
| QA-03 | Backend Tool Contract Lead | todo/calendar/note tool actions | API response stability | backend adapter defect report |
| QA-04 | Frontend Tool Regression Lead | tools UI, dual-read, dual-write | UI fallback and rendering | frontend regression report |
| QA-05 | Shared Scope and Family Domain Lead | family-safe behavior | shared dataset bleed checks | family-scope safety memo |
| QA-06 | Chat and AI Action Flow Lead | AI result cards, extracted actions | summary-to-action handoff | AI interaction QA pack |
| QA-07 | Performance and Observability Lead | latency, query cost, logging | canary telemetry | perf and telemetry baseline |
| QA-08 | Release Gate and Defect Command Lead | triage, severity, signoff | daily coordination | release go/no-go board |

## Seat Charters

### QA-01 Tenant Isolation Lead

Owns:

- `QA-001-A1` through `QA-001-A4`
- validation of `userId`, `spaceId`, `familyId`, `channelId` resolution
- forbidden cross-scope requests and denial responses

Checks:

- `familyId -> spaceId` compatibility is deterministic
- side-effecting actions do not cross tenant boundaries
- personal routes do not expose shared or foreign documents

Exit artifact:

- `Tenant Isolation Verdict v1`

### QA-02 Live Data and Reconciliation Lead

Owns:

- `PLAT-003-LIVE-*`
- `QA-004-A1` through `QA-004-B3`
- workbook completion for real production document shapes

Checks:

- production shapes for `users/*/todos`, `memos`, `notes`, `calendar_events`
- nullability drift, type drift, legacy-only field drift
- pre-write reconciliation and canary stop conditions

Exit artifact:

- `Live Data Readiness Memo v1`

### QA-03 Backend Tool Contract Lead

Owns:

- `AI-007-D1` through `AI-007-D3`
- adapter correctness for `manage_todos`, `manage_calendar`, `manage_notes`
- return payload stability for create, list, update, delete

Checks:

- created documents match expected BABBA-compatible shape
- status and priority normalization remain stable
- legacy-only data still returns usable responses

Exit artifact:

- `Backend Tool Contract Report v1`

### QA-04 Frontend Tool Regression Lead

Owns:

- tools dashboard and tool cards
- dual-read merge order and duplicate suppression
- dual-write and delete path regression

Checks:

- dashboard hides schedule items from todo counts
- calendar uses primary `todos(schedule)` while preserving legacy visibility
- memo reads `memos` first and backfills legacy-only paths correctly

Exit artifact:

- `Frontend Tool Regression Report v1`

### QA-05 Shared Scope and Family Domain Lead

Owns:

- family-safe behavior review
- proof that personal tool writes do not accidentally mutate shared family data
- future shared-path gap register

Checks:

- current personal writes stay inside `users/{uid}` paths
- no silent write lands in family datasets without consent and scope
- family migration assumptions remain explicit, not implicit

Exit artifact:

- `Family Scope Safety Memo v1`

### QA-06 Chat and AI Action Flow Lead

Owns:

- AI result card flows
- extracted action-item creation
- chat-derived todo and calendar action handoff

Checks:

- AI-created todo documents use the new payload shape
- AI-created calendar items dual-write with shared ID parity
- UI states are correct for create success, duplicate click, and failure

Exit artifact:

- `AI Interaction QA Pack v1`

### QA-07 Performance and Observability Lead

Owns:

- `QA-003-A1` through `QA-003-A3`
- query count review for dual-read screens
- latency and error baseline capture

Checks:

- dashboard dual-read does not create unacceptable load
- tool screens stay within agreed latency envelope
- logs and audit identifiers are present where expected

Exit artifact:

- `Perf and Telemetry Baseline v1`

### QA-08 Release Gate and Defect Command Lead

Owns:

- severity rubric
- defect triage
- release go or no-go decision input

Checks:

- every blocker has owner, ETA, and rollback implication
- signoff only happens after QA-01 through QA-07 evidence exists
- unresolved tenant or live-data defects block rollout automatically

Exit artifact:

- `Release Quality Memo v1`

## Immediate Assignment Grid

| Seat | Day 1 | Day 2 | Day 3 | Day 4 | Day 5 |
|---|---|---|---|---|---|
| QA-01 | review context resolver cases | run forbidden-path tests | verify tenant logs | retest fixed issues | publish verdict |
| QA-02 | open production sample inventory | record real schema drifts | fill reconciliation thresholds | validate stop conditions | publish readiness memo |
| QA-03 | replay backend todo tests | replay calendar tests | replay notes tests | inspect payload parity | publish report |
| QA-04 | verify tools page counts | verify todo card CRUD | verify calendar dual-write | verify memo dual-read | publish report |
| QA-05 | inspect family-safe write boundaries | review shared-scope assumptions | map future shared-risk gaps | confirm no shared regressions | publish memo |
| QA-06 | verify AI todo add path | verify AI calendar add path | verify action-item bulk create | verify failure UX | publish QA pack |
| QA-07 | capture build and latency baseline | count dual-read query paths | review logs and metrics | compare pre/post numbers | publish baseline |
| QA-08 | open defect board | chair daily triage | track blocker closure | draft release memo | issue go/no-go recommendation |

## Evidence Requirements

Every seat must attach evidence in one of the following forms:

- automated test result
- manual repro steps with screenshots
- query output from approved workbook
- code reference plus observed runtime behavior
- defect entry with severity and owner

No seat may close work with a verbal-only confirmation.

## Severity Rules

| Severity | Meaning | Release Rule |
|---|---|---|
| Sev-1 | tenant leak, destructive wrong-scope write, live-data corruption risk | hard stop |
| Sev-2 | incorrect create/update/delete behavior in target tools | blocks pilot |
| Sev-3 | rendering bug, fallback bug, non-critical parity drift | allowed only with owner and ETA |
| Sev-4 | cosmetic issue or low-value documentation gap | does not block |

## Signoff Gate

All of the following must be true before this QA wave can sign off:

- zero open `Sev-1`
- zero open `Sev-2` in todo, calendar, memo, or request-context paths
- backend adapter test pack passes
- frontend production build passes
- live-data reconciliation thresholds are approved
- QA-01 through QA-08 artifacts are published

## Coordination Rules

- QA-08 runs triage every day at `17:00`
- QA-01 and QA-02 can unilaterally escalate a hard stop
- QA-03 and QA-04 share one defect taxonomy for adapter mismatch issues
- QA-05 must review any issue that could later affect shared family scope
- QA-07 owns performance retest after any query-shape change

## Companion Docs

- `QA_MULTI_ANGLE_TEST_MATRIX.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`
- `QA-004_RECONCILIATION_WORKBOOK.md`
- `TEAM_EXECUTION_BOARD.md`
