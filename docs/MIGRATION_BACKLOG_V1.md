# Migration Backlog v1

## Status

- Status: `Proposed`
- Program: `Project SpaceLift`

## Companion Docs

- `MIGRATION_BACKLOG_V1_DETAIL.md`
- `SPRINT_0_1_EXECUTION_PLAN.md`
- `RFC-004_LIVE_DATA_MIGRATION_POLICY.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_CHECKLIST.md`
- `QA-004_RECONCILIATION_QUERY_SPEC.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`
- `QA-004_RECONCILIATION_WORKBOOK.md`

## 1. Sequencing Rules

- do not move physical datasets before adapters exist
- do not enable shared AI writes before consent and audit exist
- do not cut legacy reads until pilot parity is proven

## 2. Backlog

| ID | Priority | Work Item | Owner Squad | Depends On | Acceptance Criteria |
|---|---|---|---|---|---|
| PLAT-001 | P0 | Define canonical request context with `userId`, `spaceId`, `channelId`, `role` | Squad A | RFC-001 | context schema approved and reusable in all new backend paths |
| PLAT-002 | P0 | Implement `familyId -> spaceId` compatibility adapter | Squad A | PLAT-001 | backend can resolve BABBA family requests as space-scoped requests |
| PLAT-003 | P0 | Produce in-scope dataset registry with ownership class | Squad A | RFC-002 | all release 1 datasets classified as user, space, channel, or system |
| PLAT-003-LIVE | P0 | Inventory real production data shapes and divergence cases | Squad A | RFC-004 | anonymized live-schema inventory exists for all in-scope datasets |
| PLAT-004 | P0 | Define migration checkpoints and rollback metadata format | Squad A | PLAT-003 | every migration task can record progress and rollback state |
| PLAT-005 | P1 | Add required Firestore indexes for release 1 queries | Squad A | PLAT-003 | staging queries run without missing-index failures |
| PLAT-006 | P1 | Create dual-read adapters for shared todo and chat data | Squad A | PLAT-002 | release 1 services can read both legacy and target shapes |
| AI-001 | P0 | Freeze release 1 tool list and scope classes | Squad B | RFC-003 | tool catalog approved by architecture lead |
| AI-002 | P0 | Implement unified tool envelope and error contract | Squad B | AI-001, PLAT-001 | backend returns stable request, result, and error envelopes |
| AI-003 | P0 | Implement consent flow for all side-effecting tools | Squad B | AI-002 | create, update, delete, and complete actions cannot run without consent |
| AI-004 | P0 | Implement audit log schema and writer | Squad B | AI-002 | every side-effecting execution writes an auditable record |
| AI-005 | P1 | Add idempotency support for side-effecting tool calls | Squad B | AI-002 | duplicate requests return stable prior outcomes |
| AI-006 | P1 | Re-scope reminder and scheduled execution jobs under system policy | Squad B | PLAT-001 | reminders and scheduled jobs are attributable and safe to retry |
| AI-007 | P1 | Adapt `manage_todos`, `manage_calendar`, `manage_notes` to BABBA datasets | Squad B | PLAT-006, AI-002 | release 1 tools operate on BABBA-owned datasets |
| AI-008 | P1 | Implement channel summary against BABBA family chat default channel | Squad B | PLAT-002 | channel summary works on BABBA chat without BABBAAI messenger dependency |
| APP-001 | P0 | Add feature-flag framework for integrated AI slices | Squad C | none | every new AI surface can be enabled or disabled independently |
| APP-002 | P0 | Define BABBA AI entry points for home, todo, calendar, memo, chat | Squad C | APP-001 | design and trigger points approved |
| APP-003 | P1 | Integrate home summary with new tool envelope | Squad C | AI-002 | BABBA home summary works through the integrated platform path |
| APP-004 | P1 | Integrate AI todo actions | Squad C | AI-007 | users can create, list, and complete todos through AI entry points |
| APP-005 | P1 | Integrate AI calendar actions | Squad C | AI-007 | users can create and update calendar items through AI entry points |
| APP-006 | P1 | Integrate AI memo summarization and note actions | Squad C | AI-007 | memo assist flows work with fallback UX |
| APP-007 | P1 | Integrate chat summary for family chat | Squad C | AI-008 | users can request chat summary in BABBA chat context |
| QA-001 | P0 | Build tenant-isolation test suite | Squad B | PLAT-001, RFC-001 | tests fail on cross-space access violations |
| QA-002 | P0 | Build tool safety regression suite | Squad B | AI-003, AI-004 | consent, audit, and error regressions are covered |
| QA-003 | P1 | Define pilot launch gates and observability dashboard | Squad A | PLAT-004, AI-004 | pilot can be approved with explicit SLO and incident thresholds |
| QA-004 | P0 | Define live-data reconciliation queries and drift thresholds | Squad A | PLAT-003-LIVE, PLAT-004 | every migrated dataset has reconciliation checks before canary writes |
| OPS-001 | P0 | Define secrets and service-account boundary for integrated runtime | Squad A | none | production access paths are documented and least-privilege |
| OPS-002 | P1 | Create rollout and rollback runbook | Squad A | QA-003 | operational runbook approved before pilot |
| DATA-001 | P1 | Map legacy BABBAAI operational datasets to target ownership model | Squad A | RFC-002 | reminders, scheduled jobs, usage, and audit datasets have target homes |
| DATA-002 | P2 | Design target channel path under `spaces/{spaceId}/channels/{channelId}` | Squad A | PLAT-001 | future channel model approved even if not physically migrated yet |
| DATA-003 | P2 | Design post-pilot path deprecation plan | Squad A | pilot results | legacy reads have measurable removal criteria |

## 3. Release 1 Cutline

Must ship in release 1:

- PLAT-001
- PLAT-002
- PLAT-003
- PLAT-003-LIVE
- AI-001
- AI-002
- AI-003
- AI-004
- AI-007
- AI-008
- APP-001
- APP-002
- APP-003
- APP-004
- APP-005
- APP-006
- APP-007
- QA-001
- QA-002
- QA-004
- OPS-001

Can slip after release 1 if needed:

- PLAT-005
- AI-005
- AI-006
- QA-003
- OPS-002
- DATA-002
- DATA-003

## 4. Pilot Readiness Checklist

- unified context resolver deployed
- consent and audit enforced in production-like environment
- release 1 tool set feature-flagged
- dual-read validation completed on target datasets
- live-data reconciliation queries passing on canary candidates
- tenant isolation tests passing
- rollback runbook reviewed

## 5. Ownership Notes

- Squad A owns schema and migration safety
- Squad B owns tool safety and runtime adaptation
- Squad C owns end-user workflow integration
- Program Lead owns cutline changes and launch approval
