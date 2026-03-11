# Migration Backlog v1 Detail

## Status

- Status: `Working Draft`
- Program: `Project SpaceLift`

## 1. How To Use This Document

- `Epic`: top-level backlog ID from `MIGRATION_BACKLOG_V1.md`
- `Bundle`: a 2 to 4 day execution packet that can be assigned to one owner
- `Task Slice`: a 0.5 to 1.5 day implementation step

Companion execution docs:

- `PLAT-003-LIVE_SCHEMA_AUDIT_CHECKLIST.md`
- `QA-004_RECONCILIATION_QUERY_SPEC.md`
- `PLAT-003-LIVE_SCHEMA_AUDIT_WORKBOOK.md`
- `QA-004_RECONCILIATION_WORKBOOK.md`

This document intentionally keeps the original IDs stable.

## 2. Detailed Breakdown

### PLAT-001 Define Canonical Request Context

#### Bundle PLAT-001-A Context Schema

- PLAT-001-A1: define `RequestContext` fields for `userId`, `spaceId`, `channelId`, `role`, `scope`, `requestId`
- PLAT-001-A2: define context resolution precedence rules
- PLAT-001-A3: define missing-context and forbidden-context error codes
- PLAT-001-A4: publish context examples for user, space, and channel operations

#### Bundle PLAT-001-B Backend Resolution Layer

- PLAT-001-B1: add auth-to-user resolver abstraction
- PLAT-001-B2: add membership-to-role resolver abstraction
- PLAT-001-B3: add channel-to-space parent resolver abstraction
- PLAT-001-B4: add context validation helper for side-effecting calls

#### Bundle PLAT-001-C Verification

- PLAT-001-C1: create unit tests for valid context permutations
- PLAT-001-C2: create tests for invalid cross-space requests
- PLAT-001-C3: add logging fields for resolved context

### PLAT-002 Implement `familyId -> spaceId` Compatibility Adapter

#### Bundle PLAT-002-A Mapping Rules

- PLAT-002-A1: define canonical mapping `spaceId = familyId` for phase 1
- PLAT-002-A2: define backward-compatible payload rules for `familyId` and `spaceId`
- PLAT-002-A3: define response normalization rules

#### Bundle PLAT-002-B Adapter Implementation

- PLAT-002-B1: add helper to translate incoming BABBA requests to `spaceId`
- PLAT-002-B2: add helper to annotate legacy dataset reads with `spaceId`
- PLAT-002-B3: add adapter for family chat as release 1 default channel
- PLAT-002-B4: add fallback behavior when family membership is missing

#### Bundle PLAT-002-C Verification

- PLAT-002-C1: test family-scoped read paths
- PLAT-002-C2: test family-scoped write authorization
- PLAT-002-C3: document adapter sunset conditions

### PLAT-003 Produce Dataset Registry

#### Bundle PLAT-003-A BABBA Inventory

- PLAT-003-A1: list user-scoped BABBA datasets
- PLAT-003-A2: list family-scoped BABBA datasets
- PLAT-003-A3: mark source of truth and write owner for each

#### Bundle PLAT-003-B BABBAAI Inventory

- PLAT-003-B1: list user-scoped BABBAAI datasets
- PLAT-003-B2: list channel-scoped BABBAAI datasets
- PLAT-003-B3: list workspace-scoped and system-scoped BABBAAI datasets

#### Bundle PLAT-003-C Registry Publication

- PLAT-003-C1: classify each release 1 dataset as `user`, `space`, `channel`, or `system`
- PLAT-003-C2: mark retained, adapted, deferred, or deprecated status
- PLAT-003-C3: secure architecture signoff

### PLAT-003-LIVE Inventory Real Production Data Shapes

#### Bundle PLAT-003-LIVE-A Live Schema Sampling

- PLAT-003-LIVE-A1: identify all in-scope production collections currently receiving reads or writes
- PLAT-003-LIVE-A2: sample real document shapes from production using approved read-only access
- PLAT-003-LIVE-A3: anonymize sampled outputs for engineering review

#### Bundle PLAT-003-LIVE-B Divergence Analysis

- PLAT-003-LIVE-B1: list nullability and type drift by dataset
- PLAT-003-LIVE-B2: list legacy-only fields still present in production
- PLAT-003-LIVE-B3: classify incompatible shapes that will break adapters or tools

#### Bundle PLAT-003-LIVE-C Publication

- PLAT-003-LIVE-C1: publish live-shape inventory with severity tags
- PLAT-003-LIVE-C2: feed divergence issues into migration and adapter work
- PLAT-003-LIVE-C3: secure architecture and QA signoff

### PLAT-004 Migration Checkpoints and Rollback Metadata

#### Bundle PLAT-004-A Checkpoint Design

- PLAT-004-A1: define migration record schema
- PLAT-004-A2: define idempotency key format for migration jobs
- PLAT-004-A3: define rollback metadata fields

#### Bundle PLAT-004-B Execution Utilities

- PLAT-004-B1: create migration status writer
- PLAT-004-B2: create migration heartbeat and checkpoint helper
- PLAT-004-B3: create dry-run mode conventions

#### Bundle PLAT-004-C Ops Readiness

- PLAT-004-C1: define alert conditions for migration failure
- PLAT-004-C2: define rollback checklist template

### PLAT-005 Firestore Indexes

#### Bundle PLAT-005-A Query Review

- PLAT-005-A1: enumerate release 1 queries
- PLAT-005-A2: identify missing compound and collection-group indexes
- PLAT-005-A3: estimate query cost and hotspot risk

#### Bundle PLAT-005-B Index Rollout

- PLAT-005-B1: update index manifest
- PLAT-005-B2: deploy indexes to staging
- PLAT-005-B3: verify no release 1 query depends on console-created hidden indexes

### PLAT-006 Dual-Read Adapters

#### Bundle PLAT-006-A Shared Todo Dual-Read

- PLAT-006-A1: define legacy read path and target read path
- PLAT-006-A2: implement normalization to common DTO
- PLAT-006-A3: add parity checks for counts and selected fields

#### Bundle PLAT-006-B Chat Dual-Read

- PLAT-006-B1: wrap BABBA family chat as release 1 default channel reader
- PLAT-006-B2: normalize message DTOs for summarization
- PLAT-006-B3: add parity and missing-data diagnostics

### AI-001 Freeze Release 1 Tool List

#### Bundle AI-001-A Tool Inventory

- AI-001-A1: list reusable BABBAAI tools
- AI-001-A2: remove messenger-only and high-risk tools from release 1
- AI-001-A3: tag read-only vs side-effecting

#### Bundle AI-001-B Scope and Gate Policy

- AI-001-B1: assign scope class per tool
- AI-001-B2: assign consent policy per tool
- AI-001-B3: assign entitlement tier per tool

### AI-002 Unified Tool Envelope

#### Bundle AI-002-A Contract Models

- AI-002-A1: define request payload schema
- AI-002-A2: define success response schema
- AI-002-A3: define error response schema
- AI-002-A4: define tool result rendering hints for BABBA client

#### Bundle AI-002-B Runtime Integration

- AI-002-B1: wrap existing runtime with contract adapter
- AI-002-B2: normalize legacy errors into contract codes
- AI-002-B3: attach request and audit IDs to all responses

#### Bundle AI-002-C Verification

- AI-002-C1: contract tests for each release 1 tool
- AI-002-C2: client parsing tests for happy path and failure path

### AI-003 Consent Flow

#### Bundle AI-003-A Consent Schema

- AI-003-A1: define consent request payload
- AI-003-A2: define consent response payload
- AI-003-A3: define consent timeout and auto-deny policy

#### Bundle AI-003-B Runtime Handling

- AI-003-B1: gate all shared writes behind consent
- AI-003-B2: gate all destructive personal writes behind consent
- AI-003-B3: persist consent state for audit linkage

#### Bundle AI-003-C Verification

- AI-003-C1: approve path tests
- AI-003-C2: deny path tests
- AI-003-C3: timeout path tests

### AI-004 Audit Log Schema and Writer

#### Bundle AI-004-A Audit Schema

- AI-004-A1: define audit record fields
- AI-004-A2: define parameter hashing/redaction rules
- AI-004-A3: define retention and cleanup policy

#### Bundle AI-004-B Runtime Writer

- AI-004-B1: write audit helper
- AI-004-B2: attach audit writes to side-effecting tool completion
- AI-004-B3: attach consent outcome to audit records

### AI-005 Idempotency Support

#### Bundle AI-005-A Idempotency Model

- AI-005-A1: choose client request key contract
- AI-005-A2: define replay response behavior
- AI-005-A3: define expiration policy

#### Bundle AI-005-B Per-Tool Support

- AI-005-B1: todo create/update replay support
- AI-005-B2: calendar create/update replay support
- AI-005-B3: note create/update replay support
- AI-005-B4: reminder create replay support

### AI-006 Reminder and Scheduled Execution Re-scope

#### Bundle AI-006-A Dataset Reclassification

- AI-006-A1: classify reminders and scheduled messages as `system` execution datasets
- AI-006-A2: define link-back fields to user and optional space or channel

#### Bundle AI-006-B Runtime Hardening

- AI-006-B1: add idempotent processing guard
- AI-006-B2: add retry and dead-letter policy
- AI-006-B3: add metrics for pending, processed, failed

### AI-007 Adapt Productivity Tools To BABBA Datasets

#### Bundle AI-007-A Todo Adapter

- AI-007-A1: map tool actions to BABBA user todo model
- AI-007-A2: add shared todo write rules for space scope
- AI-007-A3: normalize return payload for created and listed todos

#### Bundle AI-007-B Calendar Adapter

- AI-007-B1: map tool actions to BABBA calendar and event structures
- AI-007-B2: handle private vs shared calendar writes
- AI-007-B3: normalize return payload for created and listed events

#### Bundle AI-007-C Notes Adapter

- AI-007-C1: map tool actions to BABBA memo structures
- AI-007-C2: support search and update result payloads
- AI-007-C3: preserve user ownership rules

#### Bundle AI-007-D Verification

- AI-007-D1: tool-level tests per action
- AI-007-D2: cross-scope authorization tests
- AI-007-D3: fallback tests for legacy data shapes

### AI-008 Channel Summary On BABBA Family Chat

#### Bundle AI-008-A Channel Abstraction

- AI-008-A1: define release 1 default channel model for family chat
- AI-008-A2: implement chat reader for summarization context

#### Bundle AI-008-B Summary Output

- AI-008-B1: define summary payload shape
- AI-008-B2: define truncation and message-count policies
- AI-008-B3: define citation or message-anchor strategy if needed

### APP-001 Feature Flag Framework

#### Bundle APP-001-A Flag Registry

- APP-001-A1: define release 1 flag names
- APP-001-A2: define default states by environment
- APP-001-A3: define kill-switch ownership

#### Bundle APP-001-B Client Wiring

- APP-001-B1: add app-side flag checks
- APP-001-B2: add fallback behavior when flags are off

### APP-002 Define AI Entry Points

#### Bundle APP-002-A Home

- APP-002-A1: identify home summary trigger
- APP-002-A2: define loading, error, and fallback states

#### Bundle APP-002-B Todo and Calendar

- APP-002-B1: define natural-language entry point for todo actions
- APP-002-B2: define natural-language entry point for calendar actions

#### Bundle APP-002-C Memo and Chat

- APP-002-C1: define memo summary and action extraction entry point
- APP-002-C2: define family chat summary entry point

### APP-003 Integrate Home Summary

- APP-003-A1: wire home summary to unified contract
- APP-003-A2: preserve existing dedicated summary fallback
- APP-003-A3: add exposure and error telemetry

### APP-004 Integrate AI Todo Actions

- APP-004-A1: add prompt trigger and UI shell
- APP-004-A2: connect consent UI for side-effecting actions
- APP-004-A3: render created and updated todo results

### APP-005 Integrate AI Calendar Actions

- APP-005-A1: add prompt trigger and UI shell
- APP-005-A2: connect consent UI
- APP-005-A3: render created and updated calendar results

### APP-006 Integrate AI Memo Actions

- APP-006-A1: add memo summary trigger
- APP-006-A2: render extracted actions and save-to-note paths
- APP-006-A3: preserve direct memo editing fallback

### APP-007 Integrate Family Chat Summary

- APP-007-A1: add summary action to family chat
- APP-007-A2: show summary result card
- APP-007-A3: handle empty-history and permission edge cases

### QA-001 Tenant-Isolation Test Suite

- QA-001-A1: user-to-user isolation tests
- QA-001-A2: space-to-space isolation tests
- QA-001-A3: channel-to-channel access tests
- QA-001-A4: side-effecting denial tests

### QA-002 Tool Safety Regression Suite

- QA-002-A1: consent regression tests
- QA-002-A2: audit-write regression tests
- QA-002-A3: idempotency replay tests
- QA-002-A4: timeout and partial-failure tests

### QA-003 Pilot Gates and Observability

- QA-003-A1: define SLI and SLO set
- QA-003-A2: define pilot go or no-go thresholds
- QA-003-A3: define dashboard panels and alert routes

### QA-004 Live-Data Reconciliation and Drift Thresholds

#### Bundle QA-004-A Query Design

- QA-004-A1: define row-count reconciliation queries per in-scope dataset
- QA-004-A2: define field-level reconciliation checks for critical business fields
- QA-004-A3: define acceptable drift thresholds for canary and full rollout

#### Bundle QA-004-B Execution Rules

- QA-004-B1: define reconciliation timing before write enablement
- QA-004-B2: define reconciliation timing after canary writes
- QA-004-B3: define auto-stop conditions on drift detection

### OPS-001 Secrets and Service Boundaries

- OPS-001-A1: list required secrets
- OPS-001-A2: map runtime identities and service accounts
- OPS-001-A3: define least-privilege boundary by environment

### OPS-002 Rollout and Rollback Runbook

- OPS-002-A1: define feature-flag rollback steps
- OPS-002-A2: define backend rollback steps
- OPS-002-A3: define data migration rollback steps

### DATA-001 Legacy Operational Dataset Mapping

- DATA-001-A1: map `usage_limits`
- DATA-001-A2: map `tool_audit_log`
- DATA-001-A3: map `reminders`
- DATA-001-A4: map `scheduled_messages`
- DATA-001-A5: define retention and ownership per dataset

### DATA-002 Future Channel Path Design

- DATA-002-A1: define target space channel path
- DATA-002-A2: define message DTO compatibility rules
- DATA-002-A3: define non-release-1 migration assumptions

### DATA-003 Post-Pilot Deprecation Plan

- DATA-003-A1: measure legacy read volume
- DATA-003-A2: define deprecation gates
- DATA-003-A3: define final path retirement checklist

## 3. First Assignment Recommendations

Assign first:

- Squad A: `PLAT-001-A`, `PLAT-002-A`, `PLAT-003-A`, `PLAT-003-B`, `PLAT-003-LIVE-A`
- Squad B: `AI-001-A`, `AI-001-B`, `AI-002-A`
- Squad C: `APP-001-A`, `APP-002-A`, `APP-002-B`, `APP-002-C`

Hold until dependencies land:

- `AI-007-*`
- `APP-003` through `APP-007`
- `PLAT-006-*`
