# Team Execution Board

## 1. Program Frame

- Program: `Project SpaceLift`
- Product host: `BABBA`
- Platform source: `BABBAAI` agent/runtime/tooling
- Execution mode: `parallel squads + architecture gate + phased rollout`

## 2. Squad Structure

### Leadership

- `Program Lead`: scope, sequencing, launch decision, stakeholder alignment
- `Architecture Lead`: tenancy, dataset ownership, API contracts, exception approval

### Squad A: Core Platform

- `Data Platform Engineer 1`
- `Data Platform Engineer 2`
- `SRE / Security Engineer`

Owns:

- tenancy model implementation
- Firestore schema and adapter layer
- migration jobs, indexes, observability, rollback safety

### Squad B: AI Capability Platform

- `AI Platform Engineer 1`
- `AI Platform Engineer 2`
- `QA / Release Engineer`

Owns:

- agent runtime extraction
- tool contract
- consent, audit, usage, reminders, scheduled execution

### Squad C: BABBA App Integration

- `Flutter Engineer 1`
- `Flutter Engineer 2`

Owns:

- BABBA client-side feature integration
- feature flagging
- fallback UX and regression control

## 3. Squad Charters

### Squad A Charter

- establish `spaceId` as the canonical tenant context
- classify all in-scope datasets by ownership
- support dual-read and migration checkpoints
- prevent tenant leakage and query regressions

### Squad B Charter

- reduce BABBAAI runtime to a BABBA-safe tool set
- make every side-effecting tool consented, auditable, and attributable
- keep the release 1 tool surface intentionally narrow

### Squad C Charter

- integrate AI where BABBA workflows already exist
- avoid product bloat and preserve app responsiveness
- ship feature slices that can be disabled independently

## 4. Decision and Escalation Rules

- Any new shared dataset requires `Architecture Lead` approval
- Any side-effecting tool requires `AI Platform + Security` review
- Any migration that writes legacy and target paths needs rollback documentation
- Any release slice touching shared scope needs tenant-isolation test signoff

## 5. Ceremonies

- Daily standup: 15 minutes per squad
- Architecture sync: Tuesday and Friday
- Integration sync: Wednesday
- Program review: Thursday
- Risk review: Friday

## 6. RACI Summary

| Deliverable | Accountable | Responsible | Consulted | Informed |
|---|---|---|---|---|
| Unified tenancy model | Architecture Lead | Squad A | Squad B, Squad C | Program Lead |
| Dataset ownership map | Data Platform | Squad A | Architecture Lead | All squads |
| Agent tool contract | AI Platform | Squad B | Architecture Lead, Security | Squad C |
| Consent and audit pipeline | AI Platform | Squad B | SRE / Security | Program Lead |
| BABBA feature flags | App Integration | Squad C | Squad B | Program Lead |
| Migration jobs and cutover | Data Platform | Squad A | Squad B, Squad C | Program Lead |
| Pilot launch decision | Program Lead | Program Lead | Architecture Lead, QA, SRE | All squads |

## 7. Sprint Plan

### Sprint 0

Objective:

- freeze vocabulary, scope, and contracts

Squad A:

- inventory in-scope datasets
- define `spaceId` compatibility rules
- list required indexes and adapter surfaces

Squad B:

- inventory reusable BABBAAI tools
- classify tools by `read-only` vs `side-effecting`
- define audit, usage, and consent baseline

Squad C:

- identify BABBA insertion points for release 1 AI features
- define feature flags and fallback UX

Exit criteria:

- RFC-001, RFC-002, RFC-003 ready for review

### Sprint 1

Objective:

- implement unified request context

Squad A:

- backend context resolver for `userId`, `spaceId`, `channelId`, `role`
- family-to-space adapter

Squad B:

- tool invocation envelope
- consent request/response and audit schema

Squad C:

- app-side context propagation
- AI entry points behind flags

Exit criteria:

- shared operations can resolve tenant context consistently

### Sprint 2

Objective:

- align datasets and service boundaries

Squad A:

- dual-read for target datasets
- migration checkpoints

Squad B:

- release 1 tool set wired to BABBA-safe adapters

Squad C:

- home summary, todo, memo, calendar UI integration

Exit criteria:

- release 1 integrated flows function in non-production environments

### Sprint 3

Objective:

- pilot hardening

Squad A:

- observability dashboards
- migration validation reports

Squad B:

- usage and entitlement enforcement
- cron and reminder hardening

Squad C:

- polish, fallback states, regression fixes

Exit criteria:

- pilot-ready build

## 8. Integration Handshakes

- Squad A -> Squad B: canonical context resolver and dataset map
- Squad B -> Squad C: tool contract, consent schema, error envelope
- Squad C -> Squad B: feature trigger points and UX requirements
- Squad A -> All: migration readiness and rollback protocol

## 9. Definition of Done

An item is not done unless:

- owner and scope are explicit
- telemetry exists
- failure mode is documented
- rollback path exists for shared-scope writes
- tests cover tenant boundary and authorization

## 10. Week 1 Checklist

- create decision log
- assign owners to all RFCs
- freeze release 1 tool scope
- approve target context schema
- enumerate top 10 migration risks
- define pilot cohort and launch gates

## Companion Docs

- `TEAM_WEEKLY_ASSIGNMENT.md`
- `TEAM_10_EXECUTION_PLAN.md`
- `TEAM_10_WEEKLY_BOARD.md`
- `SPRINT_0_1_EXECUTION_PLAN.md`
- `RFC-004_LIVE_DATA_MIGRATION_POLICY.md`
- `QA_TEAM_8_EXECUTION_PLAN.md`
- `QA_MULTI_ANGLE_TEST_MATRIX.md`
