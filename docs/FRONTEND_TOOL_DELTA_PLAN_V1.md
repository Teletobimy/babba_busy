# Frontend Tool Delta Plan v1

## Status

- Status: `Working Draft`
- Owner Seat: `T10-05`
- Companion Seats: `T10-06`, `T10-07`, `T10-09`

## 1. Purpose

This document defines what should be reused from the current `BABBAAI`
frontend patterns and what should be implemented natively in `BABBA` Flutter for
release 1.

## 2. Core Decision

Do not port the `BABBAAI` web frontend wholesale.

Instead:

- reference the interaction patterns
- reference the contract assumptions
- reference the safety model
- rebuild the host UI natively in Flutter
- keep all release-1 implementation work inside the `BABBA` codebase

## 3. Reusable Frontend Patterns From BABBAAI

### Keep as design references only

- tool consent dialog pattern
- result-card rendering pattern
- tool write guard logic
- shared-read merged list pattern
- conversation/session state pattern for future phases

### Do not port in release 1

- AI session sidebar
- share conversation modal
- skill browser
- standalone memory dashboard
- standalone AI workspace pages

## 4. Required Flutter-Side Components

### A. Unified AI Client

Create one BABBA-side client abstraction that can:

- call the release-1 `BABBA` owned agent endpoints
- parse normalized envelopes
- handle consent polling or consent submit flow
- fall back to existing dedicated APIs where migration is not complete

### B. Consent Sheet

Create one reusable Flutter consent sheet for all side-effecting AI actions.

It must show:

- tool name
- target scope
- short side-effect summary
- object preview
- approve and deny actions

### C. Result Cards

Create reusable result cards for:

- summary result
- todo result
- calendar result
- memo result
- reminder result
- action-extraction result

Each card must support:

- success
- denied or blocked
- partial fallback
- deep link into existing BABBA screens

### D. Direct-Write Guard Mirror

Mirror the intent of the existing `BABBAAI` direct-write guards in Flutter:

- owner-only direct write by default
- shared cross-user writes remain blocked
- a blocked state must explain why the action is unavailable

## 5. Screen-Level Delta Map

| BABBA Screen | Current State | Needed Delta |
|---|---|---|
| Home summary card | summary text only | contract-backed summary state, fallback, telemetry |
| Calendar screen | manual create via bottom sheet | AI action trigger, consent sheet, result card |
| Memo screen/detail | manual edit plus memo analysis | summarize and save-assist cards |
| Tools chat content | message list plus composer | summary trigger and action extraction result card |
| Tools landing | mixed utility cards | lightweight discovery for release-1 AI entry points |

## 6. Interaction Rules

- never auto-run a side-effecting action from free text without showing consent
- never replace the existing manual create or edit surfaces
- always offer a fallback path to the current BABBA form or sheet
- do not expose a second navigation model just for AI
- if the runtime is disabled, the UI should degrade to the existing BABBA flow

## 7. State and Telemetry Requirements

Minimum state:

- request pending
- streaming or loading
- consent required
- completed
- denied
- failed
- fallback used

Minimum telemetry:

- feature flag state
- trigger source screen
- tool requested
- consent shown and outcome
- render success or failure

## 8. Immediate Implementation Order

1. unified AI client service
2. reusable consent sheet
3. reusable result-card widgets
4. home summary integration
5. family chat summary card
6. memo summary card
7. todo and calendar action cards

## 9. QA Focus

- flag off state does not break existing screens
- consent denial returns user to a stable state
- repeated taps do not duplicate requests
- blocked shared writes explain the block clearly
- fallback path remains available after AI failure

## 10. Exit Criteria

- BABBA Flutter owns all release-1 UI shells
- no release-1 host screen depends on BABBAAI web components
- all side-effecting AI UI goes through one consent component
- read-only and side-effecting AI results render through stable result cards
