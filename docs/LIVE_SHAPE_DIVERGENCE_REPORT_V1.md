# Live Shape Divergence Report v1

## Status

- Status: `Blocked`
- Owner seat: `T10-04`

## Block Reason

This report cannot be completed in a defensible way until approved read-only production samples or an anonymized export are attached.

## Required Datasets

- `users/*/todos`
- `users/*/memos`
- `users/*/notes`
- `users/*/calendar_events`

## What Must Be Collected

- field inventory by dataset
- type drift by field
- nullability drift by field
- legacy-only fields still present in production
- fields required by current adapters but missing in production shapes

## Current Assumptions Only

These are assumptions and not yet verified against live data:

- target todo reads may encounter mixed `status`, `isCompleted`, and integer `priority`
- target memo reads may encounter legacy-only `notes` documents without matching primary `memos`
- target calendar reads may encounter legacy `calendar_events` without primary `todos(schedule)`

## Current Decision

- keep live-data rollout blocked
- keep canary blocked
- continue only with local, staging, and masked-data verification until production evidence arrives

## Next Required Inputs

- approved production read-only sampling session
or
- approved anonymized export with real document shapes
