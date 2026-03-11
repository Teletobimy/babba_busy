# RFC-003 BABBA Agent Tool Contract

## Status

- Status: `Draft`
- Program: `Project SpaceLift`
- Owner: `AI Capability Platform`

## 1. Purpose

This RFC defines the release 1 AI tool contract for integrating BABBAAI runtime capabilities into BABBA.

The contract must:

- fit BABBA's family and lifestyle product model
- respect the unified `space` tenancy model
- support safe side effects
- preserve auditability and usage controls

## 2. Current-State Signals

### BABBA Current AI Surface

BABBA currently calls dedicated API endpoints for:

- daily summary
- weekly summary
- business analysis
- psychology flows
- async analysis jobs

See:

- `babba/lib/services/ai/ai_api_service.dart`
- `babba/cloud-run/main.py`

### BABBAAI Current Runtime Surface

BABBAAI already exposes and validates tools including:

- `search_chat_history`
- `summarize_channel`
- `manage_calendar`
- `manage_todos`
- `manage_notes`

Current side-effecting tools already require consent in the runtime.

See:

- `BABBAAI/backend/routers/agent.py`
- `BABBAAI/backend/services/agent_service.py`

## 3. Decision

Release 1 keeps the tool surface intentionally narrow.

### Release 1 Read-Only Tools

- `get_current_time`
- `search_space_chat`
- `summarize_space_channel`
- `list_todos`
- `list_calendar_events`
- `list_notes`

### Release 1 Side-Effecting Tools

- `manage_todos`
- `manage_calendar`
- `manage_notes`
- `create_reminder`

### Deferred

- broad web search
- workflow automation
- drive/file operations
- generalized channel creation and moderation
- image generation and code execution

## 4. Canonical Tool Scope

Every tool must declare one scope:

- `user`
- `space`
- `channel`
- `system`

Examples:

- `manage_notes`: usually `user`
- `manage_todos`: `user` or `space`
- `manage_calendar`: `user` or `space`
- `summarize_space_channel`: `channel`
- `create_reminder`: `user`

No tool may infer its tenant scope only from raw identifiers supplied by the client.

## 5. Request Context Contract

Every invocation must resolve:

```json
{
  "requestId": "uuid",
  "userId": "uid",
  "spaceId": "space_123",
  "channelId": "channel_456",
  "role": "member",
  "tool": "manage_todos",
  "scope": "space"
}
```

Rules:

- `requestId` is always generated server-side
- `userId` comes from verified auth
- `spaceId` is required for shared operations
- `channelId` is required for channel-scoped reads
- `role` is server-derived from membership

## 6. Tool Envelope

### Request Envelope

```json
{
  "tool": "manage_todos",
  "scope": "space",
  "params": {
    "action": "create",
    "title": "장보기",
    "dueDate": "2026-03-11T09:00:00+09:00"
  }
}
```

### Response Envelope

```json
{
  "ok": true,
  "tool": "manage_todos",
  "scope": "space",
  "requestId": "uuid",
  "result": {},
  "auditId": "audit_123",
  "consent": {
    "required": false
  }
}
```

### Error Envelope

```json
{
  "ok": false,
  "tool": "manage_todos",
  "requestId": "uuid",
  "error": {
    "code": "forbidden",
    "message": "space write is not allowed"
  }
}
```

## 7. Consent Rules

Consent is mandatory for:

- create
- update
- delete
- complete
- any action that writes shared data

Consent is not required for:

- read-only list
- summarize
- search
- get current time

Consent payload must include:

- tool name
- action
- target scope
- summarized side effect
- human-readable object preview

## 8. Audit Rules

Every side-effecting tool call must write an audit record containing:

- requestId
- auditId
- userId
- spaceId when applicable
- channelId when applicable
- tool name
- action
- params hash
- consent result
- execution result
- timestamp

Retention:

- release 1 default: 30 days hot retention

## 9. Usage and Entitlement

Usage accounting must be tool-aware.

Minimum tracked fields:

- userId
- tool
- scope
- success or failure
- latency bucket
- token or cost estimate

Entitlement policy:

- read-only assistive tools can be free-tier eligible
- side-effecting productivity tools can remain premium-gated if desired
- no premium gate may bypass safety controls

## 10. Idempotency

Side-effecting requests must support idempotency.

Rules:

- client may pass `clientRequestId`
- server stores the final decision keyed by `userId + tool + clientRequestId`
- duplicate retries return the original outcome

Required for:

- `manage_todos`
- `manage_calendar`
- `manage_notes`
- `create_reminder`

## 11. Release 1 Action Matrix

### manage_todos

Allowed actions:

- `create`
- `list`
- `complete`
- `delete`

### manage_calendar

Allowed actions:

- `create`
- `list`
- `update`
- `delete`

### manage_notes

Allowed actions:

- `create`
- `list`
- `search`
- `update`
- `delete`

### create_reminder

Allowed actions:

- `create`
- `list`
- `delete`

## 12. BABBA-Specific Adaptation Rules

- `familyId` is treated as `spaceId`
- existing BABBA family chat is treated as the default release 1 channel
- BABBA personal todo and memo datasets remain user-owned
- shared write actions must resolve actual membership before execution
- business analysis and psychology flows remain dedicated APIs in release 1, not generic agent tools

## 13. Proposed Endpoints

- `POST /api/v2/agent/chat`
- `POST /api/v2/agent/tools/execute`
- `POST /api/v2/agent/tools/consent/{requestId}`
- `GET /api/v2/agent/tools/audit`
- `GET /api/v2/agent/reminders`

The existing BABBA dedicated AI endpoints remain valid during transition.

## 14. Acceptance Criteria

- every in-scope tool has explicit scope classification
- every side-effecting call supports consent, audit, and idempotency
- BABBA can consume the response envelope without product-specific parsing hacks
- no release 1 tool requires direct access to legacy BABBAAI messenger-only datasets
