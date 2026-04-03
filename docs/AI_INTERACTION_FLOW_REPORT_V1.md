# AI Interaction Flow Report v1

## Status

- Status: `Working Draft`
- Owner Seat: `T10-07`
- Companion Seats: `T10-05`, `T10-06`, `T10-09`

## 1. Purpose

This document defines the release-1 AI interaction behavior for the `BABBA`
host app. It focuses on how AI should appear to users, not only where it should
be wired.

Repository boundary:

- interaction behavior may be inspired by `BABBAAI` sub-agent capabilities
- release-1 implementation still happens inside `BABBA` owned code only
- no user-facing flow in this document requires editing the `BABBAAI`
  repository

## 2. Product Rule

Release 1 is contextual AI, not a second chat product.

Users should encounter AI as:

- a summary
- a helper action
- a save or create assistant
- a family chat summarizer

Users should not encounter AI as:

- a new primary app mode
- a replacement for manual forms
- a hidden automation layer

## 3. Flow A: Home Summary

Trigger:

- open home screen
- expand the existing summary card if needed

Behavior:

- call read-only summary path
- render concise text
- optionally show up to three structured hints:
  - top todo
  - urgent schedule
  - suggested next focus

Fallback:

- keep the existing local summary behavior if runtime call fails or flag is off

Consent:

- none

## 4. Flow B: Todo and Calendar Assist

Trigger:

- user taps an AI action near the existing create path on calendar or related
  host surface

Behavior:

1. user enters natural language
2. runtime resolves intended tool
3. UI shows parsed preview
4. if action writes data, consent is required
5. on approval, runtime executes tool
6. result card links back to the existing BABBA detail or edit surface

Fallback:

- user can always continue with the current manual bottom-sheet flow

Consent:

- required for create, update, delete, and complete actions

## 5. Flow C: Memo Assist

Trigger:

- user opens memo detail or memo list action menu

Behavior:

- summarize current memo
- suggest title, tags, or category
- optionally extract action items from memo content
- only write changes after explicit consent if the action modifies stored data

Fallback:

- user remains in the current memo edit flow and can ignore the AI result

Consent:

- required for note create or update
- not required for read-only summarize

## 6. Flow D: Family Chat Summary

Trigger:

- user opens the current family chat and taps summary

Behavior:

- summarize recent chat history from the active family context
- render a result card in the chat context or adjacent panel
- allow optional follow-up actions later, but do not default to writes in the
  first slice

Edge cases:

- empty history
- history too short
- membership mismatch

Consent:

- not required for summary
- required if action extraction later creates todos, calendar events, or notes

## 7. Flow E: Action Extraction

Trigger:

- available after summary on memo or family chat once feature flag is enabled

Behavior:

- extract structured items
- classify each as:
  - todo
  - calendar
  - reminder
  - note
- show a review list before any write occurs

Release-1 rule:

- no silent bulk create
- no one-tap multi-write without a review and consent step

## 8. Interaction Language Rules

- keep summaries concise
- keep side-effect descriptions explicit
- say whether the action affects only me or shared family data
- blocked actions must explain the policy block, not fail silently

## 9. Release-1 UX Boundaries

- no global free-form AI inbox
- no exported conversation workflow
- no tool browser as a primary destination
- no premium-only hidden behavior that bypasses safety

## 10. Success Signals

- users understand what AI will do before approval
- users can recover to the manual flow without losing work
- users can tell the difference between read-only help and data-changing actions
- family chat summary feels native to BABBA, not transplanted from another app

## 11. Exit Criteria

- every release-1 AI entry point has a defined trigger, result state, and
  fallback
- every write-capable interaction has an explicit consent step
- no contextual AI flow requires a separate BABBAAI-style navigation shell
