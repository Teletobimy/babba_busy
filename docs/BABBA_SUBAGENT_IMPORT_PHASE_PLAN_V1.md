# BABBA Sub-Agent Import Phase Plan v1

## Status

- Status: `Working Draft`
- Goal: import selected `BABBAAI` sub-agent capabilities into `BABBA`
- Boundary: no direct code changes in the `BABBAAI` repository

## 1. Purpose

This document breaks the work into phases for the following strategy:

- take only the sub-agent AI capabilities from `BABBAAI`
- rebuild the execution path inside `BABBA` owned layers
- keep `BABBAAI` as the source reference, not the implementation target
- avoid importing the `BABBAAI` product shell, messenger shell, or workspace UI

## 2. Source vs Target Rule

### Source From BABBAAI

- tool definitions and action semantics
- consent model
- audit model
- reminder model
- sub-agent orchestration patterns
- result-card and guardrail patterns

### Build Inside BABBA

- endpoint layer
- Flutter UI shell
- host-side feature flags
- request context resolution
- family-chat adapter
- dataset adapters and DTOs

### Do Not Import In Release 1

- AI session workspace
- standalone AI messenger product
- knowledge base product
- workflow automation product
- drive and workspace collaboration product

## 3. Capability Import Set

### Release 1 Import

- home summary
- family chat summary
- memo summarize
- `manage_todos`
- `manage_calendar`
- `manage_notes`
- `create_reminder`
- action extraction from memo and family chat

### Release 1 Keep Native

- business review APIs
- psychology APIs
- memo category analysis APIs
- current manual forms and bottom sheets

## 4. Phase Breakdown

### Phase 0: Import Boundary Freeze

Objective:

- freeze exactly what is copied from `BABBAAI` and what stays inside `BABBA`

Detailed tasks:

- list reusable sub-agent functions and classify each as:
  - import now
  - defer
  - never import
- freeze the repository boundary:
  - `BABBAAI` is reference only
  - implementation happens only under `babba`
- freeze the release-1 tool set:
  - `get_current_time`
  - chat summary
  - memo summary
  - todo, calendar, note, reminder actions
- freeze non-goals for release 1

Outputs:

- import inventory
- release-1 tool allowlist
- explicit non-import list

Hard gate:

- no task begins if it still assumes editing the `BABBAAI` repository

### Phase 1: BABBA Runtime Skeleton

Objective:

- create the minimum `BABBA` owned AI execution layer that can host imported
  sub-agent behavior

Detailed tasks:

- add `BABBA` owned agent service abstraction in Flutter
- define normalized request and response envelopes
- define `requestId`, `scope`, `tool`, `result`, and `error` DTOs
- add feature flags for every imported capability
- create a `familyId -> spaceId` compatibility helper in `BABBA` backend
- define a default family-chat channel abstraction for summarization

Outputs:

- unified BABBA AI client
- contract DTOs
- feature-flag registry
- family-chat channel abstraction

Hard gate:

- no host UI may call source `BABBAAI` code or web UI directly

### Phase 2: Read-Only Capability Import

Objective:

- land the safest imported features first

Detailed tasks:

- replace current home summary generation with imported summary behavior behind
  a flag
- add family chat summary action against `families/{familyId}/chat_messages`
- add memo summary action in memo detail flow
- add result cards for summary-only experiences
- keep current local or dedicated API fallbacks alive

Outputs:

- `ai_home_summary_v2`
- `ai_family_chat_summary_r1`
- `ai_memo_summary_r1`
- read-only result-card components

Hard gate:

- every read-only AI surface must have a no-AI fallback

### Phase 3: Personal Side-Effect Import

Objective:

- import the first write-capable sub-agent features for personal scope only

Detailed tasks:

- import `manage_todos` for personal todo create, list, and complete
- import `manage_calendar` for personal event create and update
- import `manage_notes` for personal memo create and update assist
- import `create_reminder` for personal reminders
- add one shared consent component for all write-capable actions
- add audit linkage for every write-capable execution
- add idempotency rules for repeated taps and retries

Outputs:

- personal AI todo actions
- personal AI calendar actions
- personal AI memo actions
- personal AI reminders
- consent sheet
- audit writer

Hard gate:

- no write-capable feature can ship without consent, audit, and retry behavior

### Phase 4: Shared-Scope Hardening

Objective:

- make imported capabilities safe around family context without opening unsafe
  shared writes

Detailed tasks:

- keep family chat summary read-only
- verify scope resolution from auth plus family context
- add explicit wrong-scope denial tests
- keep cross-user shared todo and calendar writes blocked unless approved
- add explanatory blocked states in UI for unavailable shared actions
- verify family data never leaks across groups

Outputs:

- family-safe read-only summary paths
- shared-scope block rules
- isolation test evidence

Hard gate:

- no cross-user shared write enablement in this phase without separate approval

### Phase 5: Host Polish and Rollout

Objective:

- make the imported features feel native to `BABBA`

Detailed tasks:

- connect AI result cards to existing BABBA screens and forms
- add telemetry for trigger source, consent outcome, and render success
- define kill switches per imported capability
- run staged rollout:
  - internal
  - limited cohort
  - wider release
- keep legacy summary path and manual forms as fallback until stability is
  proven

Outputs:

- production flag strategy
- rollout checklist
- telemetry dashboard inputs

Hard gate:

- any imported AI feature must be independently disableable

## 5. Detailed Work Packets

### Packet A: Summary Import

- home summary import
- family chat summary import
- memo summary import

### Packet B: Contract and Safety

- BABBA-side envelope DTOs
- consent payloads
- audit payloads
- idempotency behavior

### Packet C: Personal Productivity Actions

- todo create and complete
- calendar create and update
- note create and update
- reminder create

### Packet D: Shared-Scope Defense

- family context resolution
- wrong-scope denial tests
- blocked-state UI
- rollout guards

## 6. Recommended Sequence

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 4
6. Phase 5

Reason:

- import boundary first
- read-only first
- personal writes second
- shared-scope hardening after that
- rollout last

## 7. Team Split

| Seat | Primary Phase |
|---|---|
| T10-02 | Phase 0, Phase 1, Phase 4 |
| T10-03 | Phase 1, Phase 3 |
| T10-05 | Phase 2, Phase 3, Phase 5 |
| T10-06 | Phase 0, Phase 2, Phase 5 |
| T10-07 | Phase 2, Phase 3 |
| T10-08 | Phase 4 |
| T10-09 | Phase 3, Phase 5 |
| T10-10 | Phase 3, Phase 5 |

## 8. Exit Criteria

- imported scope is limited to sub-agent functionality only
- all implementation lives in `BABBA` owned layers
- `BABBAAI` repository stays unchanged for release 1
- read-only AI features land before write-capable AI features
- no shared write path is enabled without separate safety approval
