# RFC-002 Unified Dataset Ownership

## Status

- Status: `Draft`
- Program: `Project SpaceLift`
- Owner: `Data Platform`

## 1. Purpose

This RFC defines where each major dataset belongs after the merge.

The goal is to remove ambiguity between:

- user-owned data
- shared space data
- channel communication data
- system operational data

## 2. Current-State Signals

### BABBA

- user-scoped datasets already exist for todos, memos, reviews, tests, and albums
- shared datasets are anchored to `families/{groupId}`
- access is mediated by `memberships`

### BABBAAI

- user-scoped datasets include todos, notes, calendar events, contacts, ai memory, usage
- communication is largely top-level `channels` and `messages`
- some advanced collaboration features use `workspaces/{workspaceId}`
- reminders, scheduled messages, and usage limits are top-level operational datasets

## 3. Target Dataset Placement

### User-Owned Datasets

Keep under `users/{uid}`:

- profile
- private todos
- private notes
- ai memory
- personal usage
- personal notification preferences
- personal keyword alerts
- business review results
- psychology results

Rationale:

- personal privacy boundary
- straightforward ownership
- lower coordination cost

### Space-Owned Datasets

Keep or move under `spaces/{spaceId}`:

- members
- shared todos
- shared calendar events
- shared transactions and budgets
- albums shared with the space
- shared people/contact records
- shared summaries and knowledge derived from space activity
- workflows
- drive items
- audit log

Rationale:

- explicit tenant isolation
- easier authorization and export
- clearer collaboration semantics

### Channel-Owned Datasets

Keep under channel subcollections inside space:

- messages
- read state
- pinned items
- message reactions
- channel-level reminder state
- channel summary caches

Rationale:

- keeps communication artifacts local to the communication boundary
- avoids global top-level message sprawl

### System-Owned Datasets

Keep under a dedicated operational namespace:

- reminders queue
- scheduled messages queue
- migration checkpoint data
- analytics export jobs
- background processing state

Rationale:

- separates business data from operational execution state
- allows easier retention and cleanup policies

## 4. Dataset Classification Rules

Rule:

- if the primary owner is a single person and visibility is private, it is `user-owned`
- if multiple members share and govern access, it is `space-owned`
- if the data exists only inside communication history, it is `channel-owned`
- if the data exists to execute the platform, it is `system-owned`

## 5. Specific Mapping Decisions

### Todos

- private todo: `users/{uid}/todos`
- shared todo: `spaces/{spaceId}/shared_todos`

Migration note:

- BABBA already uses `users/{uid}/todos` plus `sharedGroups`
- phase 1 should preserve this with adapters
- phase 2 may materialize explicit `space` copies or views if query complexity requires it

### Calendar

- private calendar item: `users/{uid}/calendar_events`
- shared calendar item: `spaces/{spaceId}/calendar_events`

### Notes and Memos

- private notes remain user-owned
- shared summaries derived from notes may be stored in space-owned AI output datasets

### Chat and Channel Data

- BABBA family chat and BABBAAI channel chat should converge to `spaces/{spaceId}/channels/{channelId}/messages`
- phase 1 may keep legacy BABBA chat path and wrap it as the default channel

### AI Memory

- personal preferences and memory remain user-owned
- space memory is separate and explicitly labeled
- no silent promotion from user memory to space memory

### Usage and Billing

- release 1: user-owned
- future option: add space plan if collaboration monetization becomes necessary

### Workflows and Drive

- not in release 1 feature scope
- if retained later, they should be space-owned

## 6. Migration Principles

- prefer adapters before document moves
- do not create duplicate source-of-truth datasets without a deprecation plan
- every new dataset must declare its ownership scope
- every migration step must be observable and reversible

## 7. Required Platform Capabilities

- dataset registry with owner scope
- migration scripts with idempotent checkpoints
- audit entries for side-effecting AI actions
- usage counters tied to tool and scope
- retention rules for system datasets

## 8. Exit Criteria

- every in-scope dataset has an assigned ownership scope
- target paths are documented
- legacy path dependencies are identified
- dual-read strategy exists for each migrated dataset
- release 1 datasets are approved by architecture and app leads
