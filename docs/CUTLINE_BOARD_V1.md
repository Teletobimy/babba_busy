# Cutline Board v1

## Status

- Status: `Active`
- Window: `Current Team-10 Wave`
- Owner seat: `T10-01`

## Included In Current Cutline

- backend request-context first pass
- backend `manage_todos` adapter
- backend `manage_calendar` adapter
- backend `manage_notes` adapter
- frontend tool adapter layer
- frontend dual-read for calendar and memo
- frontend todo normalization
- frontend AI action-item create path alignment
- frontend agent-chat scope propagation from auth/channel context
- frontend todo and calendar dialog shared-metadata opt-in
- frontend read-only shared todo and calendar reads
- firestore shared-read rules and collection-group indexes for tools
- tool ACL scaffolding and centralized direct-write guard
- feature-gated backend shared-write API skeleton
- live-data reconciliation script and runbook
- shared-write contract v1
- QA team-8 design and multi-angle test matrix
- Team-10 execution and weekly board

## Verified Evidence Collected

- backend automated tests: `49 passed`
- frontend TypeScript validation: passed
- frontend targeted lint: passed
- frontend production build: passed
- live-data reconciliation dry-run artifact bundle: passed
- live-data reconciliation backend tests: passed
- tool adapter sharing unit tests: passed
- direct-write guard unit tests: passed
- feature-gated backend shared-write tests: passed
- backend full regression suite: `57 passed`

## Deferred From This Cutline

- live production shape sampling execution
- canary write enablement
- cross-user shared write behavior for direct frontend tool surfaces
- consent flow for future shared or destructive operations

## Current Hard Gates

- no approved production read-only sample export attached yet
- no approved cross-user shared write path exists for direct frontend tool surfaces yet

## Blocker Register

| ID | Blocker | Impact | Owner Seat | Status |
|---|---|---|---|---|
| BLK-01 | no production read-only sample attached | reconciliation automation exists, but live-shape divergence report cannot be completed without a real artifact bundle | T10-04 | Open |
| BLK-02 | agent-chat shared-scope propagation | direct AI and channel AI now send `spaceId` or `familyId` from auth or channel context | T10-02, T10-05 | Closed |
| BLK-03 | targeted lint cleanup | lint quality gate restored and clean | T10-05, T10-09 | Closed |
| BLK-04 | direct tool surfaces support read-only shared views but not shared writes | cannot sign off cross-user shared write behavior | T10-05, T10-06 | Open |

## Decision

Current cutline is accepted for:

- personal-scope adapter hardening
- backend and frontend regression verification
- documentation and QA preparation

Current cutline is not accepted for:

- live-data rollout
- canary traffic
- shared family-write enablement

## Next Required Outputs

- `Isolation Verdict v1`
- `Regression Memo v1`
- `Live Shape Divergence Report v1`
- `LIVE_DATA_AUDIT_RUNBOOK_V1.md`
- `SHARED_WRITE_CONTRACT_V1.md`
