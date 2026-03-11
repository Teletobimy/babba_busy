# Team 10 Weekly Board

## Status

- Status: `Working Draft`
- Horizon: `Week 1`
- Model: `seat-based execution board`

## 1. Weekly Seat Board

| Seat | Monday | Tuesday | Wednesday | Thursday | Friday | Weekly Deliverable |
|---|---|---|---|---|---|---|
| T10-01 | open cutline board | review blockers | sync stream owners | freeze changes for review | issue weekly verdict | `Cutline Board v1` |
| T10-02 | review context decisions | inspect edge cases | approve scope boundaries | resolve exceptions | publish decision log | `Tenancy Decision Log v1` |
| T10-03 | inspect backend adapter behavior | replay adapter scenarios | classify defects | define next backend delta | publish backend plan | `Backend Integration Delta Plan v1` |
| T10-04 | populate live sample inventory | mark drift by dataset | draft severity tags | align reconciliation thresholds | publish divergence report | `Live Shape Divergence Report v1` |
| T10-05 | verify dashboard counts | verify todo and calendar CRUD | verify memo merged reads | define frontend follow-up deltas | publish UI plan | `Frontend Tool Delta Plan v1` |
| T10-06 | review BABBA insertion points | map feature flags | mark shared-scope dependencies | align host integration order | publish host map | `BABBA Host Integration Map v1` |
| T10-07 | verify AI todo action flow | verify AI calendar action flow | verify bulk-create safety | define next AI UX slice | publish AI flow report | `AI Interaction Flow Report v1` |
| T10-08 | execute tenant tests | execute wrong-scope write tests | review live-data blockers | retest fixes | publish isolation verdict | `Isolation Verdict v1` |
| T10-09 | collect build evidence | run regression pass | capture perf symptoms | retest regressions | publish regression memo | `Regression Memo v1` |
| T10-10 | review logging and audit linkage | review rollback needs | validate canary guardrails | align stop conditions | publish safety memo | `Safety Guardrail Memo v1` |

## 2. Current Checkpoint Table

| Area | Current State | Owner | Required Next Proof | Status |
|---|---|---|---|---|
| backend context | first pass implemented | T10-02, T10-03 | tenant-boundary evidence | Evidence Collected |
| todo adapter | implemented | T10-03, T10-09 | create/list/complete parity proof | Evidence Collected |
| calendar adapter | implemented | T10-03, T10-09 | dual-write ID parity proof | Evidence Collected |
| notes adapter | implemented | T10-03, T10-09 | legacy-backfill proof | Evidence Collected |
| frontend dual-read | implemented | T10-05, T10-09 | merged view correctness proof | Evidence Collected |
| AI action-item create | implemented | T10-07, T10-09 | single-create and bulk-create proof | Evidence Collected |
| agent-chat shared scope | implemented on direct AI and channel AI surfaces | T10-02, T10-05 | request payload proof with auth or channel-derived scope | Evidence Collected |
| direct tool shared metadata | todo and calendar dialogs can store family-share metadata on opt-in, ACL fields scaffolded, owner-only direct-write guard centralized | T10-05, T10-06 | create or edit payload proof | Evidence Collected |
| backend shared-write path | feature-gated server-mediated todo and calendar patch routes exist, still disabled by default | T10-03, T10-10 | explicit editor access proof and disabled-by-default proof | Evidence Collected |
| direct tool shared read-only view | todo, calendar, dashboard can read shared items without cross-user writes | T10-05, T10-06 | shared query and read-only guard proof | Evidence Collected |
| live-data audit | script and runbook ready, dry-run artifact validated, backend automation tests added, awaiting approved production read-only execution | T10-04, T10-08 | first artifact bundle from approved read-only sample | Blocked |
| canary guardrails | memo published, rollout still blocked by live-data evidence | T10-10, T10-01 | production read-only sample evidence | Evidence Collected |

## 3. Daily Sync Inputs

Each seat must post:

- yesterday result
- today target
- blocker
- whether the blocker is `implementation`, `data`, `qa`, or `release`

## 4. Hard Escalation Table

| Trigger | Escalate To | Response Window |
|---|---|---|
| tenant leak or wrong-scope write | T10-01, T10-02, T10-10 | same day |
| live-data drift with rollout impact | T10-01, T10-04, T10-10 | same day |
| repeated adapter mismatch after retest | T10-01, T10-03, T10-09 | same day |
| build break on tool surfaces | T10-01, T10-05, T10-09 | same day |

## 5. Weekly Completion Rule

Week 1 is not complete unless:

- all 10 deliverables exist
- no open Sev-1 remains
- all P0 adapter and UI checks have a recorded outcome
- live-data workbooks contain first-pass production evidence
- next implementation wave has named seat ownership

## Companion Docs

- `TEAM_10_EXECUTION_PLAN.md`
- `QA_TEAM_8_EXECUTION_PLAN.md`
- `QA_MULTI_ANGLE_TEST_MATRIX.md`
- `LIVE_DATA_AUDIT_RUNBOOK_V1.md`
- `SHARED_WRITE_CONTRACT_V1.md`
