# RFC-004 Live Data Migration Policy

## Status

- Status: `Draft`
- Program: `Project SpaceLift`
- Owner: `Data Platform + Architecture`

## 1. Purpose

`BABBA` is already serving real users and real family data.

This RFC defines the mandatory rules for any merge, adapter, migration, validation, or canary activity that touches existing BABBA production data.

## 2. Core Principle

Production migration decisions must be based on:

- real production document shapes
- approved anonymized exports
- read-only schema inspection
- reconciliation against live counts and critical fields

They must not be based only on fabricated fixtures or dummy datasets.

## 3. Allowed Validation Inputs

- read-only production schema inspection
- anonymized production exports
- replayable staging snapshots derived from production
- synthetic fixtures only as supplemental edge-case coverage

## 4. Forbidden Practices

- treating synthetic data as the primary source of migration truth
- writing directly to live production for exploratory testing
- changing source-of-truth ownership without rollback metadata
- enabling shared AI writes before reconciliation queries exist
- assuming Firestore field consistency without verifying live shape drift

## 5. Required Live-Data Workflow

### Step 1: Inventory

- identify all in-scope production collections and subcollections
- classify user, space, channel, and system ownership

### Step 2: Shape Sampling

- collect read-only samples of real production documents
- anonymize user-identifiable content before broad engineering review
- record type drift, nullability drift, and legacy-field presence

### Step 3: Contract Hardening

- design adapters and DTOs against real observed shapes
- explicitly handle null, missing, and legacy-only fields

### Step 4: Reconciliation Query Design

- define count-level reconciliation
- define field-level reconciliation for critical data
- define stop conditions when drift exceeds threshold

### Step 5: Shadow Validation

- run read-only shadow evaluation on canary candidates
- compare old and new read outputs before any write enablement

### Step 6: Canary Write Enablement

- enable writes only for selected existing production spaces and users
- measure drift and error rates
- auto-stop on reconciliation failure

## 6. Backup and Rollback Rules

Before any live write-path change:

- source datasets must have recoverable export or replay strategy
- migration run must have checkpoint metadata
- rollback owner must be named
- rollback query and verification steps must be documented

## 7. Reconciliation Minimums

Every in-scope migrated dataset must have:

- source count query
- target count query
- critical field parity checks
- missing-document detection
- duplicate-document detection where applicable

Examples of critical fields:

- `ownerId`
- `familyId` or `spaceId`
- `sharedGroups`
- `visibility`
- `createdAt`
- `updatedAt`
- `status`

## 8. Canary Policy

Canary must use:

- existing active BABBA users
- existing active BABBA families or spaces
- low-blast-radius cohorts selected by explicit criteria

Canary must not use:

- fake tenants
- fake family datasets as the only acceptance path

## 9. Audit and Monitoring

For any canary write period:

- all side-effecting AI calls must have audit IDs
- all failures must be attributable to user, space, and tool
- dashboards must track drift, error, latency, and write volume

## 10. Acceptance Criteria

- live-shape inventory exists for every release 1 dataset
- reconciliation queries exist before canary write enablement
- rollback metadata exists before any source-of-truth change
- no production write path is enabled on assumption-only schema knowledge
