# RFC-001 Unified Tenancy Model

## Status

- Status: `Draft`
- Program: `Project SpaceLift`
- Owner: `Architecture Lead`

## 1. Problem

The current projects use different tenancy anchors.

- `BABBA` is primarily organized around `family/group`
- `BABBAAI` uses a mixture of `user`, `channel`, and `workspace`

This causes ambiguity in:

- permission boundaries
- data ownership
- AI tool scope
- audit and usage attribution
- migration sequencing

We need a single canonical tenancy model before importing BABBAAI capabilities into BABBA.

## 2. Decision

The canonical tenant boundary will be `space`.

Phase 1 mapping:

- `spaceId = familyId`

Additional rules:

- `user` remains the authentication and personal data root
- `membership` is the only source of user-to-space access
- `channel` is always subordinate to a `space`
- AI tool execution always resolves a `userId` and may additionally resolve `spaceId` and `channelId`
- datasets with no end-user ownership remain in `system` scope

## 3. Canonical Scope Model

### User Scope

Used for private or personal data.

Examples:

- profile
- private todos
- private notes
- ai memory
- usage and billing state

Target path examples:

- `users/{uid}`
- `users/{uid}/todos/{todoId}`
- `users/{uid}/notes/{noteId}`
- `users/{uid}/ai_memory/{memoryId}`
- `users/{uid}/usage/{period}`

### Space Scope

Used for shared collaboration and shared family/lifestyle data.

Examples:

- memberships summary
- shared todos
- shared calendar events
- budgets
- albums
- shared people/contact datasets
- shared AI summaries

Target path examples:

- `spaces/{spaceId}`
- `spaces/{spaceId}/members/{uid}`
- `spaces/{spaceId}/shared_todos/{todoId}`
- `spaces/{spaceId}/calendar_events/{eventId}`
- `spaces/{spaceId}/transactions/{txId}`
- `spaces/{spaceId}/albums/{albumId}`

### Channel Scope

Used for communication artifacts inside a space.

Examples:

- messages
- read state
- channel notifications
- channel-level AI summaries

Target path examples:

- `spaces/{spaceId}/channels/{channelId}`
- `spaces/{spaceId}/channels/{channelId}/messages/{messageId}`
- `spaces/{spaceId}/channels/{channelId}/read_state/{uid}`

### System Scope

Used for operational processing that is not owned as primary business data by a single user or space.

Examples:

- scheduled jobs
- reminder queue
- analytics exports
- migration state

Target path examples:

- `system/reminders/{jobId}`
- `system/scheduled_messages/{jobId}`
- `system/migrations/{migrationId}`

## 4. Compatibility Rules

### Rule 1: No Immediate Physical Rename

We will not rename `families` to `spaces` in storage in phase 1.

Instead:

- application and backend code adopt the term `space`
- adapters translate `spaceId <-> familyId`
- physical relocation is deferred until after feature validation

### Rule 2: Channel Is Not a Tenant

Any backend logic that currently treats `channelId` as the top-level authority must resolve:

- requesting user
- parent space
- permission derived from membership

### Rule 3: Workspace Is Collapsed Into Space Unless Proven Otherwise

BABBAAI `workspace` datasets will map to `space` unless there is a strong reason to keep a separate abstraction.

This avoids parallel tenancy hierarchies.

### Rule 4: Mixed-Scope Tooling Must Declare Scope

Every AI tool must declare its scope type:

- `user-scoped`
- `space-scoped`
- `channel-scoped`
- `system-executed`

This becomes part of the tool contract and audit record.

## 5. Target Permission Model

### Membership Roles

Minimum role set:

- `owner`
- `admin`
- `member`

Optional later:

- `viewer`
- `guest`

### Permission Categories

- personal write
- shared content write
- channel moderation
- automation management
- billing and plan management

### Enforcement

- client hints are insufficient
- authoritative checks must happen in server-side runtime and security rules
- every side-effecting tool operation must check membership and role

## 6. Target Request Context

All backend requests and tool invocations should resolve a standard context object:

```json
{
  "userId": "uid",
  "spaceId": "space_123",
  "channelId": "channel_456",
  "role": "member",
  "scope": "space"
}
```

Rules:

- `userId` is required for all authenticated calls
- `spaceId` is required for any shared operation
- `channelId` is required only for channel-bound operations
- `role` is derived, never trusted from client input

## 7. Migration Strategy

### Stage A: Semantic Alignment

- add `spaceId` fields where absent
- keep legacy fields for compatibility
- introduce backend adapters

### Stage B: Runtime Alignment

- update AI runtime and service layers to require explicit scope
- attach audit and usage metadata to the resolved context

### Stage C: Dataset Alignment

- introduce new space-scoped paths for shared data where needed
- dual-read legacy and target paths
- validate parity

### Stage D: Legacy Freeze

- stop writing to legacy-only paths
- retain read fallback temporarily
- remove once telemetry confirms stability

## 8. Open Questions

- Should BABBA chat remain under `families/*/chat_messages` during phase 1 or gain a `channels` abstraction immediately?
- Which shared BABBA datasets should become channel-aware in release 1?
- Does billing attach to `user` only, or do we need space-level plans later?
- Which BABBAAI workflow and drive features should remain out of scope for release 1?

## 9. Acceptance Criteria

- every new integrated backend feature can resolve `userId` and `spaceId`
- no side-effecting tool can execute without a valid scope classification
- shared operations are authorized by membership, not by raw document IDs alone
- pilot rollout completes without tenant-boundary incidents
