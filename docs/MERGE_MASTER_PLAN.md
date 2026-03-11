# BABBA x BABBAAI Merge Master Plan

## 1. Program Summary

- Program name: `Project SpaceLift`
- Primary product host: `BABBA`
- Platform ingestion target: `BABBAAI` agent/runtime/tooling capabilities
- Strategy: keep `BABBA` as the user-facing product and absorb selected `BABBAAI` backend capabilities behind a unified tenancy and dataset model
- Delivery style: phased migration, no big-bang merge

## 2. Why This Direction

`BABBA` already owns the core product surface for family and lifestyle management.
`BABBAAI` contributes the stronger agent/runtime layer, tool orchestration, reminder pipeline, usage tracking, auditability, and future automation primitives.

The merge therefore optimizes for:

- preserving the existing BABBA mobile experience
- avoiding a full Flutter-to-web product rewrite
- reusing BABBAAI backend strengths without importing its entire product scope
- redefining tenancy once, then attaching AI features incrementally

## 3. Goals

- Define a canonical multi-tenant domain model for the combined system
- Standardize dataset ownership across user, space, channel, and system scopes
- Integrate agent-backed features into BABBA without breaking existing flows
- Create an execution plan that allows dual-read and controlled cutover
- Establish clear team boundaries and accountable owners
- Protect existing live BABBA production data throughout the merge program

## 4. Non-Goals

- Rebuilding the entire BABBAAI messenger product inside BABBA in phase 1
- Physically renaming every existing Firestore path before feature validation
- Migrating every historical dataset at once
- Shipping workflow automation, drive, and advanced collaboration in the first release
- Using fabricated or dummy production datasets to validate migration safety

## 5. Canonical Domain Terms

- `user`: authenticated end user
- `space`: tenant boundary for shared activity; phase 1 maps current `family` to `space`
- `membership`: user-to-space relationship including role and policy
- `channel`: communication unit inside a space
- `tool execution`: an AI action performed by a user with optional space and channel context
- `system dataset`: queues, scheduled jobs, analytics, and operational datasets

## 6. Team Topology

Recommended core team: `10 people`

### Program Leadership

- `Program Lead / PM (1)`: scope, sequencing, launch gates, decision log owner
- `Architecture Lead (1)`: tenancy model, dataset ownership, API contracts, review authority

### Squad A: Core Platform

- `Data Platform Engineer (2)`: Firestore model, migration jobs, indexes, backfill, dual-read strategy
- `SRE / Security Engineer (1)`: Cloud Run, secrets, rollout safety, monitoring, incident runbooks

Mission:

- define and enforce the canonical tenancy model
- own migration and production hardening
- own policy, audit, and operational safeguards

### Squad B: AI Capability Platform

- `AI Platform Engineer (2)`: agent runtime, consent pipeline, audit logging, usage controls, reminders, tool adapters
- `QA / Release Engineer (1)`: regression, tool safety, tenant isolation, rollout verification

Mission:

- extract reusable BABBAAI backend capabilities
- re-scope them around `spaceId`
- expose BABBA-safe tool contracts

### Squad C: BABBA App Integration

- `Flutter Engineer (2)`: BABBA client integration, feature flags, UX insertion points, fallback flows

Mission:

- integrate AI features into BABBA screens
- preserve app performance and product coherence
- ship progressive release slices

## 7. Governance Cadence

- Daily squad standup: per squad
- Architecture sync: 2 times per week
- Merge program review: weekly
- Risk and launch review: bi-weekly
- RFC process: architecture lead approves, PM tracks unresolved decisions

## 8. Workstreams

### Workstream 1: Tenancy and Dataset Redefinition

Deliverables:

- canonical domain model
- unified dataset ownership map
- migration rules for family-to-space abstraction
- access policy matrix

### Workstream 2: Agent Platform Extraction

Deliverables:

- BABBA tool contract
- consent and audit framework
- reminder and scheduled execution model
- usage metering and entitlement model

### Workstream 3: BABBA Feature Integration

Deliverables:

- AI summary in home and chat contexts
- AI-assisted todo and calendar actions
- AI memo summarization and action extraction
- rollout flags and fallback UX

### Workstream 4: Data Migration and Cutover

Deliverables:

- mapping tables and adapters
- dual-read validation
- production canary rollout on existing BABBA spaces
- old-path deprecation checklist
- live-data reconciliation report

## 9. Phase Plan

### Phase 0: Discovery and Decision Freeze

Duration: `2 weeks`

Exit criteria:

- RFC-001 approved
- RFC-002 approved
- current-state dataset inventory complete
- live production data handling policy approved
- launch KPIs and risk thresholds defined

### Phase 1: Unified Context Layer

Duration: `3 weeks`

Build:

- request context contract with `userId`, `spaceId`, `channelId`, `role`
- logical aliasing of `familyId -> spaceId`
- policy helpers for personal vs shared vs admin operations

Exit criteria:

- new backend code can resolve tenant context consistently
- BABBAAI-derived runtime components accept `spaceId`

### Phase 2: Dataset Alignment

Duration: `3 weeks`

Build:

- shared dataset ownership map applied to schema and adapters
- top-level BABBAAI datasets annotated with `spaceId` where needed
- index and query review complete

Exit criteria:

- dual-read works for target datasets
- tenant boundary tests pass

### Phase 3: AI Capability Integration

Duration: `4 weeks`

Scope:

- home summaries
- chat summaries
- todo create/update
- calendar create/update
- memo summarize and action extraction
- reminder creation

Exit criteria:

- BABBA users can invoke approved AI features safely
- audit, usage, and consent are enforced

### Phase 4: Pilot Migration

Duration: `2 weeks`

Build:

- shadow mode
- production canary cohorts selected from existing BABBA users and spaces
- observability dashboards
- rollback playbook
- reconciliation and divergence reporting

Exit criteria:

- no tenant leakage
- p95 latency and error budgets inside thresholds
- cost profile accepted

### Phase 5: Progressive Rollout

Duration: `2 weeks`

Build:

- staged release
- cleanup backlog
- legacy path freeze

Exit criteria:

- new capabilities default-on for target cohorts
- legacy adapter usage trending down

## 10. Release Scope

### Release 1

- AI daily and contextual summaries
- AI-assisted todo actions
- AI-assisted calendar actions
- memo summary and action extraction
- reminders

### Release 2

- space-aware chat intelligence
- richer memory and knowledge features
- advanced usage controls and plan gating

### Deferred

- full BABBAAI messenger parity
- generalized workflow automation
- drive and workspace collaboration suite

## 11. Key Risks

- tenant leakage across spaces
- overloading BABBA with too much collaboration surface too early
- Firestore query/index regressions from mixed legacy and new paths
- tool execution side effects without enough consent or audit
- migration complexity if physical path renames are attempted too early
- corruption or drift of existing live BABBA production data
- incomplete understanding of current production data shapes

## 12. Risk Controls

- no destructive cutover without dual-read validation
- no tool with side effects without consent and audit
- feature flags for every integrated AI capability
- production canary rollout before default enablement
- architecture review required for any new shared dataset
- no direct write against live data without backup, replay plan, and reconciliation query
- live-schema sampling must use real production shapes or anonymized exports, never fabricated fixtures as the only validation source

## 13. Success Metrics

- zero verified tenant-boundary leaks
- AI feature success rate above agreed threshold
- pilot cohort retention not lower than BABBA baseline
- latency and cost within budget
- incident count below predefined launch gates

## 14. Immediate Deliverables

- `RFC-001_UNIFIED_TENANCY_MODEL.md`
- `RFC-002_UNIFIED_DATASET_OWNERSHIP.md`
- `RFC-003_BABBA_AGENT_TOOL_CONTRACT.md`
- `RFC-004_LIVE_DATA_MIGRATION_POLICY.md`
- `TEAM_EXECUTION_BOARD.md`
- migration backlog v1
- tenant-isolation test checklist
- rollout and rollback runbook

## 15. First 2 Weeks Backlog

- inventory all top-level collections and subcollections
- classify each dataset as `user`, `space`, `channel`, or `system`
- define the target request context contract
- map BABBAAI runtime features to BABBA-safe release scope
- define metrics, logs, audit records, and usage controls
- produce production canary rollout criteria for existing BABBA spaces
