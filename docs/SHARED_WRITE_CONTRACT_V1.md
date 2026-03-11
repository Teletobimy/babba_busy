# Shared Write Contract v1

## Status

- Status: `Draft`
- Owner seats: `T10-02`, `T10-05`, `T10-10`

## Scope

This contract defines the minimum safe rule set before any cross-user shared write is enabled for:

- `users/{ownerId}/todos/{todoId}`
- `users/{ownerId}/calendar_events/{eventId}`
- future shared tool paths derived from the same personal-owner model

## Release Rule

Shared reads can exist before shared writes.

Shared writes stay blocked until all of the following are true:

- live-data reconciliation evidence exists
- explicit ACL fields exist on the document
- Firestore rules enforce the ACL fields
- consent and audit rules are approved

## Minimum Safe Permissions

- `create`: owner only
- `update`: owner or explicit doc-level `editorIds` only
- `complete` or equivalent toggle: owner or explicit `editorIds` only
- `delete`: owner only

The following must not grant write access by themselves:

- shared group membership only
- channel membership only
- participant membership only
- assignee membership only

## Immutable Fields

Non-owners must never mutate:

- `ownerId`
- `createdBy`
- `createdAt`
- `editorIds`
- `viewerIds`
- `sharedGroups`
- `familyId`
- `spaceId`
- `participantIds`
- `assigneeIds`

## Mutable Fields

Calendar content updates may change only:

- `title`
- `startTime`
- `endTime`
- `allDay`
- `description`
- `location`
- `updatedAt`
- `updatedBy`

Todo content updates may change only:

- `title`
- `description`
- `priority`
- `dueDate`
- `updatedAt`
- `updatedBy`

Todo completion updates may change only:

- `status`
- `isCompleted`
- `completedAt`
- `completedBy`
- `updatedAt`
- `updatedBy`

## Enforcement Guidance

- prefer `affectedKeys().hasOnly(...)` in Firestore rules
- keep ACL edits owner-only or server-only
- if participant self-actions are needed later, move them into per-user state instead of editing the owner root document directly
- prefer server-mediated shared writes over raw client cross-user writes

## Current Decision

For the current cutline:

- read-only shared todo and calendar views are allowed
- cross-user shared writes remain blocked
- feature-gated backend shared-write routes may exist while disabled-by-default
- rollout cannot proceed past personal-only write scope
