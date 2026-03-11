# Team 10 Execution Plan

## Status

- Status: `Working Draft`
- Staffing model: `seat-based`
- Team size: `10`
- Operating mode: `implementation + QA + live-data readiness`

## Why This Team Exists Now

Current state already completed:

- backend request-context unification first pass
- BABBA-compatible adapters for todo, calendar, and notes
- frontend dual-read and dual-write first pass
- QA team 8 design and test matrix

This 10-seat team is the execution layer for the next phase:

- harden the current integration
- connect shared scope explicitly
- validate against live production shapes
- prepare canary-safe rollout conditions

## Team Seats

| Seat | Role | Primary Area | Secondary Area | Owns |
|---|---|---|---|---|
| T10-01 | Program and Cutline Lead | scope, sequencing, launch gate | dependency clearing | weekly cutline and go/no-go |
| T10-02 | Architecture and Tenancy Lead | `spaceId`, `familyId`, request context | exception handling | tenancy decisions and contract approval |
| T10-03 | Backend Runtime Lead | agent runtime and router wiring | tool response stability | backend integration slices |
| T10-04 | Data and Live-Shape Lead | dataset registry, schema drift | reconciliation | live-data readiness |
| T10-05 | Frontend Tools Lead | tools dashboard and cards | dual-read UI parity | web tool integration |
| T10-06 | BABBA Integration Lead | BABBA-side insertion path planning | feature flags | host-product integration |
| T10-07 | AI Interaction Lead | AI result cards and action flows | summary-to-action UX | AI interaction behavior |
| T10-08 | QA Isolation Lead | tenant isolation and auth denial | shared-scope safety | hard-stop defect detection |
| T10-09 | QA Regression Lead | tool regression, perf, build | telemetry | regression signoff |
| T10-10 | SRE and Security Lead | observability, rollback, safe rollout | secrets and auditability | production guardrails |

## Execution Focus For The Next Wave

### Stream 1 Context and Shared Scope

Owned by:

- `T10-02`
- `T10-03`
- `T10-06`
- `T10-08`

Targets:

- keep `familyId -> spaceId` compatibility stable
- make frontend propagate shared scope intentionally
- define which current writes remain personal-only and which must be blocked until consent exists

### Stream 2 Productivity Tool Hardening

Owned by:

- `T10-03`
- `T10-05`
- `T10-07`
- `T10-09`

Targets:

- stabilize todo, calendar, memo behavior across legacy and target datasets
- verify action-item creation paths
- remove regressions in merged read views

### Stream 3 Live Data and Reconciliation

Owned by:

- `T10-04`
- `T10-08`
- `T10-09`
- `T10-10`

Targets:

- execute real production shape sampling under read-only rules
- fill schema audit workbook and reconciliation workbook
- define canary stop conditions and release evidence

### Stream 4 Rollout Safety

Owned by:

- `T10-01`
- `T10-09`
- `T10-10`

Targets:

- maintain blocker board
- connect telemetry to rollout gates
- define rollback and auto-stop triggers

## Immediate Seat Assignments

### T10-01 Program and Cutline Lead

- freeze the next 5-day implementation cutline
- require evidence from engineering and QA before status changes
- maintain dependency log across streams

Exit:

- `Cutline Board v1`

### T10-02 Architecture and Tenancy Lead

- review all current request-context paths
- approve the boundary between personal-only writes and future shared writes
- open unresolved edge cases for `spaceId`, `familyId`, and channel inheritance

Exit:

- `Tenancy Decision Log v1`

### T10-03 Backend Runtime Lead

- verify current adapters against release-1 contract behavior
- prepare next backend slice for explicit shared-scope handling
- align error and success envelopes for tool operations

Exit:

- `Backend Integration Delta Plan v1`

### T10-04 Data and Live-Shape Lead

- execute `PLAT-003-LIVE` workbook population against real production samples
- enumerate drift for `todos`, `memos`, `notes`, `calendar_events`
- define highest-risk shape incompatibilities

Exit:

- `Live Shape Divergence Report v1`

### T10-05 Frontend Tools Lead

- verify merged dashboard correctness
- verify `todo-card`, `calendar-card`, `memo-card` read and write parity
- prepare follow-up fixes for shared-scope propagation on frontend

Exit:

- `Frontend Tool Delta Plan v1`

### T10-06 BABBA Integration Lead

- map where BABBA will consume the current backend adapters
- list required host-side flags and insertion points
- mark integration blockers that depend on scope or consent

Exit:

- `BABBA Host Integration Map v1`

### T10-07 AI Interaction Lead

- verify action-item creation from AI result cards
- inspect bulk-create and repeated-click behavior
- define next interaction slice for family chat summary to action

Exit:

- `AI Interaction Flow Report v1`

### T10-08 QA Isolation Lead

- execute tenant-boundary checks on current backend and frontend flows
- validate that personal writes stay inside `users/{uid}` datasets
- hard-stop any wrong-scope or cross-user write

Exit:

- `Isolation Verdict v1`

### T10-09 QA Regression Lead

- execute regression pass for current tool screens
- capture build, TypeScript, and runtime evidence
- track defects for duplicates, wrong counts, and legacy parity breaks

Exit:

- `Regression Memo v1`

### T10-10 SRE and Security Lead

- define minimum logging and audit linkage requirements
- review whether current changes are safe for staging and future canary
- confirm rollback expectations for dual-write paths

Exit:

- `Safety Guardrail Memo v1`

## 5-Day Delivery Board

| Day | Primary Goal | Required Seats | Gate |
|---|---|---|---|
| Day 1 | freeze scope and collect current evidence | T10-01, T10-02, T10-03, T10-05, T10-09 | cutline approved |
| Day 2 | validate current adapters and UI flows | T10-03, T10-05, T10-07, T10-08, T10-09 | no Sev-1 found |
| Day 3 | execute live-shape audit and drift capture | T10-04, T10-08, T10-10 | workbook populated |
| Day 4 | define next implementation deltas and rollout blocks | T10-02, T10-03, T10-05, T10-06, T10-10 | blocker list published |
| Day 5 | issue combined implementation and QA verdict | all seats | go/no-go memo ready |

## Defect Routing Rules

| Defect Type | First Owner | Must Review | Blocking Rule |
|---|---|---|---|
| tenant leak | T10-08 | T10-02, T10-10 | hard stop |
| wrong-scope write | T10-08 | T10-02, T10-03 | hard stop |
| live-data drift above threshold | T10-04 | T10-08, T10-10 | hard stop |
| tool create/update/delete mismatch | T10-03 | T10-09 | blocks pilot |
| UI parity regression | T10-05 | T10-09 | blocks signoff if P0 |
| missing observability or rollback story | T10-10 | T10-01 | blocks canary |

## Exit Criteria For This Team Wave

- current adapter behavior is documented and verified
- live-data shape drift is explicitly recorded
- hard-stop risks are either closed or escalated
- next engineering slice is assigned with seat ownership
- combined implementation and QA memo is ready for the next phase

## Companion Docs

- `TEAM_10_WEEKLY_BOARD.md`
- `CUTLINE_BOARD_V1.md`
- `ISOLATION_VERDICT_V1.md`
- `REGRESSION_MEMO_V1.md`
- `LIVE_SHAPE_DIVERGENCE_REPORT_V1.md`
- `SAFETY_GUARDRAIL_MEMO_V1.md`
- `QA_TEAM_8_EXECUTION_PLAN.md`
- `QA_MULTI_ANGLE_TEST_MATRIX.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`
- `QA-004_RECONCILIATION_WORKBOOK.md`
