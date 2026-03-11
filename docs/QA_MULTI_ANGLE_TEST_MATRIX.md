# QA Multi-Angle Test Matrix

## Status

- Status: `Working Draft`
- Purpose: operational matrix for the 8-seat QA team

## 1. Coverage Matrix

| Angle ID | QA Seat | Test Angle | Current Focus | Evidence Type | Gate |
|---|---|---|---|---|---|
| ANGLE-01 | QA-01 | tenant isolation | context resolution and scope denial | automated plus manual | hard gate |
| ANGLE-02 | QA-02 | live-data drift | real production schema parity | workbook and query output | hard gate |
| ANGLE-03 | QA-03 | backend adapter correctness | todo/calendar/note tool actions | automated plus payload capture | hard gate |
| ANGLE-04 | QA-04 | frontend regression | dashboard, cards, dual-read/write | manual plus build evidence | hard gate |
| ANGLE-05 | QA-05 | family-safe behavior | no accidental shared writes | manual plus code review evidence | hard gate |
| ANGLE-06 | QA-06 | AI interaction flow | action extraction and save flows | manual scenario evidence | soft to hard depending on defect |
| ANGLE-07 | QA-07 | performance and telemetry | query count, latency, logs | benchmark and trace evidence | soft to hard depending on drift |
| ANGLE-08 | QA-08 | release control | triage and signoff | memo and blocker board | hard gate |

## 2. Targeted Test Items

| Case ID | QA Seat | Surface | Scenario | Expected Result | Priority | Status | Evidence |
|---|---|---|---|---|---|---|---|
| QA-CXT-001 | QA-01 | backend context | request with `familyId` only | resolved `spaceId` matches `familyId` | P0 | Open | |
| QA-CXT-002 | QA-01 | backend context | request with mismatched tenant inputs | request denied with stable error | P0 | Open | |
| QA-CXT-003 | QA-01 | backend context | cross-scope side-effecting write | no write committed | P0 | Open | |
| QA-DATA-001 | QA-02 | live schema | production `todos` sample review | type drift captured in workbook | P0 | Open | |
| QA-DATA-002 | QA-02 | live schema | production `memos` and `notes` drift review | legacy-only fields identified | P0 | Open | |
| QA-DATA-003 | QA-02 | reconciliation | canary count parity query | within approved threshold | P0 | Open | |
| QA-BE-001 | QA-03 | tool adapter | create todo via tool | BABBA-compatible document written | P0 | Open | |
| QA-BE-002 | QA-03 | tool adapter | list todos with schedule docs present | only todo items returned in todo views | P0 | Open | |
| QA-BE-003 | QA-03 | tool adapter | create calendar via tool | primary and legacy IDs match | P0 | Open | |
| QA-BE-004 | QA-03 | tool adapter | update note from legacy-only source | primary memo backfilled correctly | P1 | Open | |
| QA-FE-001 | QA-04 | tools dashboard | open dashboard with mixed datasets | counts and previews merge correctly | P0 | Open | |
| QA-FE-002 | QA-04 | todo card | create and complete todo | payload and completion status are correct | P0 | Open | |
| QA-FE-003 | QA-04 | calendar card | create calendar item | `todos(schedule)` and `calendar_events` both written | P0 | Open | |
| QA-FE-004 | QA-04 | memo card | edit legacy-only memo | `memos` primary path appears after save | P1 | Open | |
| QA-FAM-001 | QA-05 | family safety | personal tool create | no write lands in shared family dataset | P0 | Open | |
| QA-FAM-002 | QA-05 | family safety | inspect shared field defaults | no implied shared membership is created | P1 | Open | |
| QA-AI-001 | QA-06 | AI result card | add todo from action item | new todo payload written once | P0 | Open | |
| QA-AI-002 | QA-06 | AI result card | add calendar from action item | dual-write succeeds with same ID | P0 | Open | |
| QA-AI-003 | QA-06 | AI result card | bulk create action items | duplicate click does not duplicate writes | P1 | Open | |
| QA-PERF-001 | QA-07 | tools dashboard | initial load of dual-read screen | query count and latency captured | P1 | Open | |
| QA-PERF-002 | QA-07 | logging | side-effecting tool call | request and audit linkage visible | P1 | Open | |
| QA-REL-001 | QA-08 | release gate | daily blocker review | all P0 issues have owner and ETA | P0 | Open | |
| QA-REL-002 | QA-08 | release gate | signoff review | hard-gate checklist satisfied | P0 | Open | |

## 3. Environment Matrix

| Env | Purpose | Allowed Data | Owner | Notes |
|---|---|---|---|---|
| Local | fast defect reproduction | synthetic or masked | QA-03, QA-04, QA-06 | do not use for signoff alone |
| Staging | integration verification | masked or copied-safe | QA-01 through QA-08 | required before signoff |
| Production Read-Only | live shape and reconciliation review | real production data under approval | QA-02 | no write allowed |
| Canary | guarded live verification | approved live cohort only | QA-02, QA-08 | stop on drift or Sev-1 |

## 4. Daily Reporting Template

| Seat | New Defects | Closed Defects | Hard Risks | Next Action | Blocked |
|---|---|---|---|---|---|
| QA-01 | | | | | |
| QA-02 | | | | | |
| QA-03 | | | | | |
| QA-04 | | | | | |
| QA-05 | | | | | |
| QA-06 | | | | | |
| QA-07 | | | | | |
| QA-08 | | | | | |

## 5. Hard-Stop Conditions

- any confirmed tenant leak
- any write to the wrong user or shared family scope
- any unreconciled production drift above approved threshold
- any ID mismatch between primary and legacy calendar writes
- any regression where todo views include schedule items as actionable todos

## 6. Companion Docs

- `QA_TEAM_8_EXECUTION_PLAN.md`
- `QA-004_RECONCILIATION_QUERY_SPEC.md`
- `QA-004_RECONCILIATION_WORKBOOK.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`
