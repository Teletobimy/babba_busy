# BABBA Sub-Agent Import Execution Board v1

## Status

- Status: `Working Draft`
- Program Mode: `seat-based execution`
- Boundary: implementation happens in `BABBA` only

## 1. Program Frame

- Host product: `BABBA`
- Source reference: selected `BABBAAI` sub-agent functionality
- Current wave: `Phase 0 + Phase 1 + read-only Phase 2 setup`
- Current non-goal: changing the `BABBAAI` repository

## 2. Current Wave Goal

Convert the phase plan into immediate execution so the team can:

- freeze the import boundary
- create the BABBA-owned runtime skeleton
- prepare the first read-only import slice

This wave is complete only when `BABBA` is ready to consume imported
sub-agent behavior without depending on `BABBAAI` code changes.

## 3. Seat Ownership

| Seat | Role | Owns In This Wave | Must Not Drift Into |
|---|---|---|---|
| T10-01 | Program and Cutline Lead | cutline, blocker ownership, review gate | implementation detail ownership |
| T10-02 | Architecture and Tenancy Lead | import boundary, `familyId -> spaceId`, scope rules | frontend UX decisions |
| T10-03 | Backend Runtime Lead | BABBA-owned contract, DTOs, backend skeleton | product-shell planning |
| T10-04 | Data and Live-Shape Lead | confirm in-scope BABBA datasets for imported features | feature-flag or UX work |
| T10-05 | Frontend Tools Lead | result-card shell, Flutter integration rules, host component map | backend contract design |
| T10-06 | BABBA Integration Lead | host trigger placement, route order, feature-flag placement | runtime internals |
| T10-07 | AI Interaction Lead | summary behavior, consent preview content, action review rules | tenancy policy |
| T10-08 | QA Isolation Lead | wrong-scope denial checks and safety gates | product copy design |
| T10-09 | QA Regression Lead | host regression target list and build gates | architecture decisions |
| T10-10 | SRE and Security Lead | audit minimums, kill switch rules, rollout guardrails | frontend interaction design |

## 4. Deliverables For This Wave

| Deliverable | Owner | Definition |
|---|---|---|
| `BABBA Sub-Agent Import Phase Plan v1` | T10-06 | phased import strategy and boundaries |
| `Import Inventory v1` | T10-02 | import now vs defer vs never-import table |
| `BABBA Agent Contract Draft v1` | T10-03 | request and response envelope for imported features |
| `Host Component Mapping v1` | T10-05 | which Flutter screens get which AI UI shell |
| `Host Trigger Map v1` | T10-06 | concrete entry points on home, calendar, memo, and family chat |
| `AI Read-Only Slice Spec v1` | T10-07 | summary behaviors and fallback rules |
| `Isolation Gate Checklist v1` | T10-08 | tests that must pass before any write-capable import |
| `Regression Gate List v1` | T10-09 | impacted screens and regression checks |
| `Rollout Guardrail Addendum v1` | T10-10 | kill switches and audit minimums |

## 5. Execution Streams

### Stream A: Boundary Freeze

Owners:

- T10-01
- T10-02
- T10-06

Scope:

- freeze imported tool set
- freeze non-import list
- freeze repository boundary
- freeze release-1 host surfaces

Exit:

- no work item still assumes `BABBAAI` repo edits

### Stream B: Runtime Skeleton

Owners:

- T10-02
- T10-03
- T10-10

Scope:

- BABBA-owned endpoint shape
- context DTOs
- scope and request IDs
- audit minimums
- reminder and consent contract placement

Exit:

- one stable contract draft exists for imported features

### Stream C: Host Integration Mapping

Owners:

- T10-05
- T10-06
- T10-07

Scope:

- host trigger map
- result-card shell plan
- summary interaction rules
- manual fallback preservation

Exit:

- each release-1 imported feature has a host trigger and fallback

### Stream D: Safety Gates

Owners:

- T10-08
- T10-09
- T10-10

Scope:

- wrong-scope checks
- host regression impact list
- audit and kill switch rules

Exit:

- read-only slice has explicit ship and no-ship conditions

## 6. Immediate Work Queue

### T10-01

- freeze the 5-day cutline for the current import wave
- reject any task that expands scope into the `BABBAAI` product shell
- maintain blocker ownership table

### T10-02

- publish import boundary rules
- publish `familyId -> spaceId` import assumptions
- classify imported feature scopes as `user`, `channel`, or blocked shared scope

### T10-03

- draft BABBA-owned contract for:
  - home summary
  - family chat summary
  - memo summary
  - future todo or calendar actions
- define envelope examples and error codes

### T10-04

- confirm source datasets for:
  - home summary
  - family chat summary
  - memo summary
  - reminders
- list any shape drift that can block read-only import

### T10-05

- define Flutter result-card shell variants
- define where consent sheet will live
- map read-only slice to current screens without navigation expansion

### T10-06

- publish trigger map for:
  - home
  - calendar
  - memo
  - family chat
- publish feature-flag names and default states

### T10-07

- define summary output shape and tone rules
- define action review rule for future write-capable imports
- define fallback text and empty-state behavior

### T10-08

- write isolation checks for:
  - wrong family context
  - missing membership
  - read-only summary crossing family boundary

### T10-09

- produce regression target list for impacted host screens
- define build gate for read-only import wave
- mark screens requiring manual retest after integration

### T10-10

- define audit minimums for future write-capable imports
- define kill switches for each imported capability
- define release rule that keeps read-only and write-capable slices separable

## 7. Dependency Rules

- T10-03 cannot finalize contract examples before T10-02 freezes scope naming
- T10-05 cannot finalize result-card states before T10-07 defines outcome states
- T10-06 cannot finalize flag order before T10-03 and T10-07 define first slice
- T10-08 signoff is required before any write-capable packet starts
- T10-10 signoff is required before any imported capability loses its kill switch

## 8. Hard Stops

- any task requiring edits inside the `BABBAAI` repository
- any imported feature that bypasses BABBA feature flags
- any write-capable import without planned consent and audit
- any shared-scope write proposal without separate approval

## 9. Completion Rule

This execution wave is not complete unless:

- imported scope is frozen
- BABBA-owned contract skeleton exists
- host trigger map exists
- read-only summary slice is specified end-to-end
- isolation and regression gates are written down
- all outputs remain inside the `BABBA` implementation boundary
