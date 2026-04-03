# BABBA Sub-Agent Import Week 1 Board v1

## Status

- Status: `Working Draft`
- Horizon: `Week 1`
- Wave: `Phase 0 + Phase 1 kickoff`

## 1. Week 1 Goal

By the end of Week 1 the team must have:

- frozen the sub-agent import boundary
- defined the BABBA-owned contract skeleton
- mapped the first host entry points
- defined the first read-only slice
- documented the safety gates for later write-capable imports

## 2. Weekly Seat Board

| Seat | Monday | Tuesday | Wednesday | Thursday | Friday | Weekly Deliverable |
|---|---|---|---|---|---|---|
| T10-01 | freeze cutline | review scope drift | clear blockers | freeze review set | issue verdict | `Week 1 Cutline Note` |
| T10-02 | define import boundary | freeze scope classes | publish context rules | review exceptions | sign off boundary | `Import Inventory v1` |
| T10-03 | draft envelope DTOs | draft request examples | draft error model | align future tool hooks | publish contract draft | `BABBA Agent Contract Draft v1` |
| T10-04 | confirm source datasets | confirm summary fields | mark shape drift | align with QA | publish data note | `Read-Only Source Dataset Note v1` |
| T10-05 | map result-card variants | map host components | define consent shell location | align fallback states | publish UI map | `Host Component Mapping v1` |
| T10-06 | map host entry points | map feature flags | order integration slices | align route ownership | publish trigger map | `Host Trigger Map v1` |
| T10-07 | define summary output shape | define empty states | define fallback wording | define action review rule | publish interaction spec | `AI Read-Only Slice Spec v1` |
| T10-08 | define wrong-scope cases | define missing-membership cases | define read-only leak checks | align with backend draft | publish gate checklist | `Isolation Gate Checklist v1` |
| T10-09 | list impacted host screens | define build gate | define regression retest list | align read-only QA order | publish regression gate list | `Regression Gate List v1` |
| T10-10 | define kill switches | define audit minimums | define no-ship rules | review safety dependencies | publish guardrail addendum | `Rollout Guardrail Addendum v1` |

## 3. Daily Required Outputs

Each seat must post:

- today target
- dependency on another seat
- blocker if any
- whether blocker is `scope`, `contract`, `data`, `ui`, `qa`, or `release`

## 4. Day-by-Day Gates

### Day 1

- import boundary draft exists
- first host entry-point list exists
- first contract DTO draft exists

### Day 2

- release-1 imported capability list is frozen
- non-import list is frozen
- source dataset ownership for read-only slice is known

### Day 3

- result-card states are defined
- summary output shape is defined
- isolation checks are written

### Day 4

- all seat deliverables are cross-reviewed
- unresolved scope drift is escalated
- kill switch rules are written

### Day 5

- Week 1 verdict issued
- Phase 2 read-only import work can start

## 5. Hard Escalation Table

| Trigger | Escalate To | Response Window |
|---|---|---|
| scope drift into full BABBAAI product import | T10-01, T10-02, T10-06 | same day |
| contract draft assumes BABBAAI repo edits | T10-01, T10-03 | same day |
| read-only slice has no fallback | T10-05, T10-07, T10-09 | same day |
| summary path risks cross-family read | T10-02, T10-08, T10-10 | same day |

## 6. Week 1 Completion Rule

Week 1 is not complete unless:

- all 10 seat deliverables exist
- no deliverable requires editing the `BABBAAI` repository
- the first read-only slice is fully specified
- Phase 2 can start without reopening scope

## Companion Docs

- `BABBA_SUBAGENT_IMPORT_PHASE_PLAN_V1.md`
- `BABBA_SUBAGENT_IMPORT_EXECUTION_BOARD_V1.md`
- `BABBA_HOST_INTEGRATION_MAP_V1.md`
- `BACKEND_INTEGRATION_DELTA_PLAN_V1.md`
- `FRONTEND_TOOL_DELTA_PLAN_V1.md`
- `AI_INTERACTION_FLOW_REPORT_V1.md`
