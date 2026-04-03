# Backend Integration Delta Plan v1

## Status

- Status: `Working Draft`
- Owner Seat: `T10-03`
- Companion Seats: `T10-02`, `T10-08`, `T10-10`

## 1. Purpose

This document defines the next backend slice required to bring selected
`BABBAAI` sub-agent capabilities into `BABBA` owned backend paths without
modifying the `BABBAAI` repository itself.

## 2. Current Confirmed Signals

- request context resolution already accepts `spaceId` and `familyId`
- `spaceId == familyId` compatibility validation already exists
- `manage_todos`, `manage_calendar`, and `manage_notes` already have
  BABBA-compatible adapter behavior and tests in the source `BABBAAI` backend
- consent, usage metering, reminders, and tool audit logging already exist

This means the next step is not greenfield runtime work. The next step is to
extract only the needed behavior into a `BABBA` owned runtime slice and expose
it through a BABBA-safe release-1 contract.

## 3. Release 1 Backend Scope

### Read-only

- `get_current_time`
- `search_space_chat`
- `summarize_space_channel`
- `list_todos`
- `list_calendar_events`
- `list_notes`

### Side-effecting

- `manage_todos`
- `manage_calendar`
- `manage_notes`
- `create_reminder`

### Explicitly Deferred

- broad web search
- knowledge base search
- send message to other channels
- channel creation and moderation
- image generation
- code execution
- general workflow automation

## 4. Required Deltas

### Delta 1: Add a BABBA release-1 tool filter

Problem:

- the current runtime exposes a larger tool surface than BABBA release 1 should
  allow

Required change:

- add a BABBA release-1 allowlist layer in the `BABBA` owned runtime slice
- block all deferred tools at contract level, not only at UI level

Acceptance:

- no deferred tool can be selected from the release-1 agent entry points

### Delta 2: Add unified request and response envelopes

Problem:

- the current runtime behavior is event-rich but not yet fully normalized to the
  release-1 BABBA contract

Required change:

- every tool call resolves a server-generated `requestId`
- every side-effecting completion returns an `auditId`
- every error maps to stable codes and messages
- every response carries `tool`, `scope`, `ok`, and normalized `result`

Acceptance:

- BABBA Flutter client can parse all release-1 tool responses with one contract
  adapter

### Delta 3: Implement BABBA family chat channel adapter

Problem:

- BABBA chat data lives under `families/{familyId}/chat_messages`
- the imported sub-agent behavior expects a channel-like abstraction

Required change:

- add a family-chat reader adapter that treats each BABBA family as the default
  release-1 channel
- normalize message DTOs for summary and action extraction
- keep the adapter read-only in release 1

Acceptance:

- channel summary can execute against BABBA family chat without importing the
  BABBAAI messenger data model

### Delta 4: Freeze shared writes behind explicit server policy

Problem:

- adapter logic exists, but cross-user family writes are still rollout-blocked

Required change:

- keep personal writes available where ownership is clear
- keep shared family writes feature-gated and server-mediated only
- reject ambiguous shared writes even if the client sends `familyId`

Acceptance:

- no side-effecting tool can write shared family data without approved policy
  and explicit context resolution

### Delta 5: Keep dedicated APIs outside the generic agent path

Problem:

- business review and psychology flows already exist in BABBA and do not need
  to be re-modeled as generic tools in release 1

Required change:

- retain current dedicated endpoints for:
  - business review
  - psychology test
  - memo category analysis

Acceptance:

- no release-1 migration work blocks on converting those domains into agent
  tools

## 5. Proposed Endpoint Shape

Target release-1 paths in `BABBA` owned backend:

- `POST /api/v2/agent/chat`
- `POST /api/v2/agent/tools/execute`
- `POST /api/v2/agent/tools/consent/{requestId}`
- `GET /api/v2/agent/tools/audit`
- `GET /api/v2/agent/reminders`

Transition rule:

- keep the current BABBA dedicated AI endpoints alive until the host app has
  migrated each surface

## 6. Execution Bundles

### Bundle B1: Contract Wrapper In BABBA Backend

- add release-1 tool allowlist
- add envelope DTOs
- normalize release-1 error codes
- attach `requestId` and `auditId`

### Bundle B2: Family Chat Adapter

- map `familyId -> spaceId`
- define release-1 channel identity for family chat
- normalize chat message payloads for summary
- add empty-history and missing-membership behavior

### Bundle B3: Safety and Policy Gate

- keep shared writes disabled by default
- require consent for all side-effecting release-1 tools
- persist consent outcome to audit linkage
- hard-fail on context mismatch

### Bundle B4: Verification

- contract tests for release-1 tools
- family-chat summary tests
- wrong-scope denial tests
- audit linkage tests

## 7. Test Matrix Additions

- tool denied when `spaceId` and `familyId` conflict
- tool denied when user is not a member of the resolved family
- summary returns read-only result against family chat
- todo create works in personal scope with consent
- shared todo write remains blocked when feature gate is off
- audit record includes consent outcome and request identifier

## 8. Risks

- accidental exposure of deferred tools through legacy tool discovery
- mixed envelope shapes during transition
- family chat adapter returning incomplete or unbounded history
- shared writes being enabled through a direct tool path before policy signoff

## 9. Stop Conditions

- any cross-family data read caused by scope confusion
- any side-effecting write that does not produce an audit record
- any release-1 response path that still requires BABBA client parsing hacks

## 10. Exit Criteria

- release-1 tool surface is hard-filtered server-side
- family chat summary works on BABBA datasets
- consent and audit are linked for every side-effecting release-1 tool
- Flutter host can consume one stable contract for integrated surfaces
- no release-1 backend step requires editing the `BABBAAI` repository
