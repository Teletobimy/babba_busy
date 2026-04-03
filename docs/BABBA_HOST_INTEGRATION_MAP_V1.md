# BABBA Host Integration Map v1

## Status

- Status: `Working Draft`
- Owner Seat: `T10-06`
- Companion Seats: `T10-03`, `T10-05`, `T10-07`, `T10-08`

## 1. Purpose

This document maps the current `BABBA` product surfaces to the release-1 AI
integration points that should consume selected `BABBAAI` sub-agent
capabilities after they are brought into a `BABBA`-owned runtime path.

The goal is to keep `BABBA` as the host product and attach contextual AI entry
points where users already work today.

## 2. Host Principle

- do not import the full `BABBAAI` messenger product into `BABBA`
- do not make release 1 depend on `BABBAAI` web UI shells
- copy or reimplement selected `BABBAAI` sub-agent logic inside `BABBA` owned
  backend paths
- do not require direct code changes inside the `BABBAAI` repository for
  release 1
- keep existing `BABBA` dedicated business and psychology flows intact
- prefer contextual AI entry points over a new global AI mode in release 1

## 3. Confirmed Host Surfaces

| Host Surface | Current BABBA Anchor | Current Behavior | Release 1 AI Injection | Scope |
|---|---|---|---|---|
| Home | `HomeScreen` + `AiSummaryCard` | local Gemini daily summary and todo preview | unified home summary via `BABBA`-owned agent read-only path | `user` |
| Calendar | `CalendarScreen` | date browsing plus existing create/edit bottom sheets | AI calendar and todo actions from contextual entry point | `user` then `space` later |
| Memo list/detail | `MemoScreen`, `MemoDetailScreen` | direct memo CRUD and memo analysis API | memo summarize, note create/update assist, action extraction | `user` |
| Family chat | tools hub chat content | group chat send/read inside family context | family chat summary and action extraction | `channel` |
| Tools tab | `ToolsHubScreen` | mixed utilities and dedicated AI tools | release-1 AI surfaces grouped under existing tools/navigation structure | mixed |

## 4. Release 1 Entry Points

### Home

Current anchors:

- `lib/features/home/home_screen.dart`
- `lib/features/home/widgets/ai_summary_card.dart`

Release-1 behavior:

- replace the current summary generation path with a unified runtime-backed read
  endpoint
- keep the card shape and fallback tone already familiar to BABBA users
- render summary text plus structured hints for:
  - top priorities
  - due-soon todos
  - upcoming schedules

Do not add in release 1:

- free-form AI chat session from home
- automatic writes from the home summary card

### Calendar

Current anchors:

- `lib/features/calendar/calendar_screen.dart`
- existing `AddTodoSheet` bottom-sheet flow

Release-1 behavior:

- add one AI trigger near the existing create path instead of replacing the
  current bottom sheet
- support:
  - create calendar event
  - list upcoming events
  - create todo from natural language
  - update calendar event after consent
- return users to existing create or detail surfaces when manual correction is
  needed

Guardrail:

- shared family writes remain rollout-blocked until approved consent and
  cross-user write rules are signed off

### Memo

Current anchors:

- `lib/features/memo/memo_screen.dart`
- `lib/features/memo/memo_detail_screen.dart`

Release-1 behavior:

- keep the current memo CRUD screen as source of truth
- add AI actions for:
  - summarize memo
  - suggest note title or tags
  - extract action items
  - save extracted result as memo content after consent when needed

Guardrail:

- do not replace manual memo editing with generated content by default

### Family Chat

Current anchors:

- `lib/features/tools/tools_hub_screen.dart`
- `lib/shared/providers/chat_provider.dart`

Release-1 behavior:

- treat `families/{familyId}/chat_messages` as the default release-1 channel
- add a summary action for the current family chat context
- optionally allow "extract action items" from chat once consent UI is wired
- keep existing send and attachment behavior unchanged

Do not add in release 1:

- full `BABBAAI` conversation sessions UI
- standalone AI session sidebar
- channel creation or advanced moderation flows

### Tools Tab

Current anchors:

- `lib/features/tools/tools_hub_screen.dart`
- `lib/app/router.dart`
- `lib/app/main_shell.dart`

Release-1 behavior:

- use the existing tools navigation as the main location for AI entry-point
  discovery outside the home card
- keep business and psychology as dedicated routes and APIs
- expose only contextual AI affordances that map to existing host workflows

## 5. Explicit Non-Imports For Release 1

Do not port these `BABBAAI` frontend surfaces into `BABBA` release 1:

- AI session sidebar
- share conversation modal
- skill browser
- memory dashboard as a standalone page
- full AI messenger page
- workflows page
- drive or workspace UI

Reason:

- they introduce a second product model instead of strengthening the current
  host product

## 6. Feature Flag Registry

Initial host flags:

- `ai_home_summary_v2`
- `ai_todo_actions_r1`
- `ai_calendar_actions_r1`
- `ai_memo_actions_r1`
- `ai_family_chat_summary_r1`
- `ai_extract_action_items_r1`

Default guidance:

- default `off` in production until contract, consent, and audit evidence is
  complete
- home summary may be staged first because it is read-only

## 7. Integration Order

1. Home summary
2. Family chat summary
3. Memo summarize and note assist
4. Todo actions
5. Calendar actions
6. Action extraction from family chat

Rationale:

- read-only surfaces land first
- existing user habits remain intact
- highest-risk side effects land after consent and audit wiring

## 8. Seat Ownership

| Seat | Responsibility | Output |
|---|---|---|
| T10-06 | host trigger placement, route ownership, flag registry | host integration map |
| T10-03 | endpoint shape, request context, runtime behavior | backend delta plan |
| T10-05 | result cards, consent UI shell, state wiring | frontend delta plan |
| T10-07 | wording, interaction sequencing, summary-to-action UX | AI interaction flow report |
| T10-08 | wrong-scope denial checks on all integrated triggers | isolation verdict evidence |

## 9. Immediate Build Sequence

- wire a BABBA-side AI service abstraction that can call the new `BABBA` owned
  agent contract without breaking existing dedicated APIs
- land read-only home summary behind `ai_home_summary_v2`
- land family chat summary behind `ai_family_chat_summary_r1`
- land consent shell before any side-effecting todo, calendar, or memo action
- keep business and psychology flows on their current endpoints during release 1

## 10. Exit Criteria

- every release-1 AI feature has a concrete host trigger
- every trigger has a fallback when the flag is off or the runtime fails
- no release-1 host flow depends on `BABBAAI` web-only UI components
- no shared write path is enabled without consent, audit, and isolation signoff
