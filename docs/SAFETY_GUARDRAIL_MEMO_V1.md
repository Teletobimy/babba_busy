# Safety Guardrail Memo v1

## Status

- Status: `Evidence Collected`
- Owner seat: `T10-10`

## Guardrail Summary

Allowed in the current wave:

- backend and frontend hardening for personal-scope tool paths
- regression testing on current adapter behavior
- documentation and QA execution using local, staging, and masked data

Blocked in the current wave:

- live-data rollout
- canary write enablement
- shared family-write enablement from the current frontend tool surfaces

## Verified Signals

| Signal | Result | Notes |
|---|---|---|
| backend automated tests | Pass | `49 passed` |
| frontend production build | Pass | authoritative release validation |
| targeted frontend lint | Pass | clean targeted lint gate |

## Current Risk Posture

### 1. Shared-scope writes are not yet safe to enable

Reason:

- `agent-chat` surfaces now propagate `spaceId` or `familyId` from auth or channel context
- current reviewed todo and calendar dialogs can now store family-share metadata when explicitly enabled
- current reviewed todo and calendar surfaces can read shared items in read-only mode
- direct tool write checks are now centralized so non-owner edits and deletes are blocked even if a UI path regresses
- direct frontend tool surfaces still do not implement approved cross-user shared write rules
- minimum shared-write contract is now documented in `SHARED_WRITE_CONTRACT_V1.md`, but not yet enforced in rules or write paths
- feature-gated backend shared-write routes now exist for future server-mediated writes, but they remain disabled by default and are not wired to the frontend

Rule:

- do not enable shared family-write behavior until direct tool surfaces also adopt approved cross-user write rules, consent rules, and reconciliation evidence

### 2. Live-data rollout remains blocked

Reason:

- production read-only sample evidence is not yet attached

Rule:

- no canary, no rollout, and no live write enablement until reconciliation evidence exists

### 3. Lint gate is restored and usable

Reason:

- targeted lint now runs because `eslint.config.mjs` exists

Rule:

- use targeted lint as a valid quality signal for the current hardening wave

### 4. Bare `tsc --noEmit` is not the canonical frontend gate right now

Reason:

- direct `tsc` currently hits a generated `.next/types/validator.ts` import edge
- Next.js production build completes successfully and is the authoritative type gate in this repository state

Rule:

- use `npm run build` as the release type-check signal for the current wave

## Required Next Actions

- attach approved production read-only samples
- execute `reconcile_babba_merge_firestore.py` against an approved read-only cohort and attach the artifact bundle
- implement approved cross-user shared write behavior for direct frontend tool surfaces
- decide whether the future shared-write path should stay backend-mediated and migrate the frontend to that path instead of opening raw client cross-user writes
- revisit standalone TypeScript validation strategy if the repo wants both `build` and `tsc` gates
