# Sprint 0-1 Execution Plan

## Status

- Status: `Working Draft`
- Time window: `First 4 weeks`

## 1. Goal

Convert the merge program from planning into controlled implementation without starting irreversible migration work too early.

## 2. Capacity Assumptions

- Squad A effective capacity: `2.5 engineers`
- Squad B effective capacity: `2.5 engineers`
- Squad C effective capacity: `2 engineers`

## 3. Sprint 0

### Sprint 0 Outcome

- frozen vocabulary
- approved request context
- approved release 1 tool surface
- agreed app insertion points

### Week 1

#### Squad A

- PLAT-001-A
- PLAT-002-A
- PLAT-003-A
- PLAT-003-LIVE-A

#### Squad B

- AI-001-A
- AI-001-B
- AI-002-A

#### Squad C

- APP-001-A
- APP-002-A
- APP-002-B
- APP-002-C

#### Required End-of-Week Outputs

- request context draft
- release 1 tool inventory
- feature flag list
- app entry-point map
- live production schema sampling plan
- first draft of `PLAT-003-LIVE_SCHEMA_AUDIT_CHECKLIST.md`
- first draft of `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`

### Week 2

#### Squad A

- PLAT-003-B
- PLAT-003-C
- PLAT-004-A
- PLAT-003-LIVE-B

#### Squad B

- AI-002-B
- AI-003-A
- AI-004-A

#### Squad C

- APP-001-B
- APP-002 final review package
- APP-003-A1 spike

#### Required End-of-Week Outputs

- dataset registry published
- migration checkpoint draft
- tool envelope adapter draft
- consent schema draft
- audit schema draft
- live data divergence report draft
- first draft of `QA-004_RECONCILIATION_QUERY_SPEC.md`
- first draft of `QA-004_RECONCILIATION_WORKBOOK.md`

### Sprint 0 Review Gate

Must be true:

- RFC-001 approved
- RFC-002 approved
- RFC-003 approved
- release 1 cutline unchanged or explicitly re-approved

## 4. Sprint 1

### Sprint 1 Outcome

- unified runtime contract implemented
- compatibility adapters in place
- first BABBA-integrated AI slice working behind flags

### Week 3

#### Squad A

- PLAT-001-B
- PLAT-002-B
- PLAT-004-B
- QA-004-A1

#### Squad B

- AI-002-C
- AI-003-B
- AI-004-B

#### Squad C

- APP-003-A2
- APP-003-A3
- APP-004-A1

#### Required End-of-Week Outputs

- context resolution layer merged
- family-to-space compatibility adapter working
- side-effect consent wired in runtime
- audit writer active in staging
- home summary using new envelope in dev path
- first reconciliation query draft for live canary verification

### Week 4

#### Squad A

- PLAT-001-C
- PLAT-002-C
- PLAT-006-A1
- QA-004-A2

#### Squad B

- AI-007-A1
- AI-007-A2
- QA-001-A1
- QA-001-A2

#### Squad C

- APP-004-A2
- APP-004-A3
- APP-005-A1

#### Required End-of-Week Outputs

- tenant-context tests passing
- todo adapter works on BABBA dataset
- consent UI usable for todo actions
- first shared-scope safety checks validated
- field-level reconciliation checks drafted against live production shapes

### Sprint 1 Review Gate

Must be true:

- side-effecting tools cannot bypass consent
- audit records are written for staging executions
- BABBA can consume the new contract without parsing instability
- no unresolved tenant-boundary blocker remains for release 1 work

## 5. Explicit Handoffs

- Squad A hands `RequestContext` and dataset registry to Squad B before Week 3
- Squad B hands contract DTOs and consent payloads to Squad C before Week 3
- Squad C hands UI response requirements back to Squad B before APP-004 starts

## 6. Things We Will Not Start In Sprint 0-1

- physical collection moves
- generalized workflow automation
- drive/file migration
- broad web search integration
- advanced multi-channel collaboration features

## 7. Blockers That Stop The Train

- unresolved scope ownership for shared todos
- missing decision on default family chat channel abstraction
- ambiguous audit retention policy
- no agreed rollback format for migration writes

## 8. PM Tracking View

### Red

- PLAT-001 not approved
- AI-003 consent path incomplete
- AI-004 audit path incomplete

### Yellow

- APP entry points approved but not wired
- dataset registry published but not signed off

### Green

- release 1 tool scope frozen
- contract adapter stable
- first flagged BABBA integration slice operational
