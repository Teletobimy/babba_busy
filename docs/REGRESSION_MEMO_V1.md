# Regression Memo v1

## Status

- Status: `Evidence Collected`
- Owner seat: `T10-09`

## Automated Results

| Check | Result | Notes |
|---|---|---|
| backend `pytest -q` | Pass | `49 passed in 2.52s` |
| frontend targeted lint | Pass | no error and no warning in targeted files |
| frontend `npm run build` | Pass | Next.js production build completed successfully |

## Current Regression Read

Green:

- backend adapter test pack
- frontend compile and build path
- current tool-surface code integration
- agent-chat shared-scope transport on direct AI and channel AI surfaces
- direct todo and calendar dialogs now emit family-share metadata when explicitly enabled
- direct todo and calendar surfaces now render shared items as read-only
- firestore shared-read rules and indexes are prepared for tool collection-group queries

Amber:

- manual click-path verification is still needed for full UI confidence
- live-data drift has not yet been validated
- bare `npx tsc --noEmit` currently hits a generated `.next/types/validator.ts` edge and is not the canonical signal in this repo state

Red:

- no active red finding inside the currently targeted build and lint gates

## Known Non-Blocking Risks

- current reviewed direct tool writes are personal-only and do not yet exercise shared family-write behavior
- memo surfaces remain personal-only by schema
- dual-read screens may still require runtime perf sampling under staging load

## Blocking Risks

- no live production sample evidence
- no approved cross-user shared write proof yet for direct tool surfaces

## Recommendation

Accept current regression state for:

- continued adapter hardening
- QA execution on the present implementation

Do not accept current regression state for:

- rollout signoff
- canary write enablement
