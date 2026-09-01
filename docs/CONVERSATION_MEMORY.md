# Family Business Conversation Memory

## Purpose and Authority

This file preserves durable historical context, working principles, and recurring misunderstandings from project conversations. It is a concise memory, not a chat transcript and not a duplicate of the GDD.

Authority rules:

1. The canonical Google Docs GDD is the authoritative gameplay design source.
2. The current repository is the factual source for what is implemented now.
3. `PENDING_DECISIONS.md` contains only confirmed decisions awaiting GDD synchronization.
4. This conversation memory provides historical context and does not override any of the above.

When sources appear to conflict, identify the conflict before changing implementation.

## Durable Working Principles

- Separate chats may be used for separate project subjects.
- The project's persistent memory lives in project documents, not in assumed chat recall.
- At the start of a new chat, read the relevant project documents instead of relying on conversational memory alone.
- Read the relevant canonical GDD section before implementing or changing a gameplay system.
- Inspect the existing manager, JSON, scenes, integrations, and tests before changing an existing system.
- Keep systems as simple as the confirmed design permits; do not add unnecessary complexity.
- Do not invent gameplay decisions that are absent from the canonical GDD or a confirmed pending decision.
- Preserve the current manager/autoload and JSON-driven architecture unless a documented reason requires a change.
- Large systems must be implemented in bounded, documented phases so Work tasks remain reviewable, but the complete approved system scope must remain tracked until finished. A phase is not complete if agreed parts of that phase are intentionally omitted as an MVP shortcut.
- Event System work follows `docs/EVENT_SYSTEM_SPEC.md` and `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`; backend, integration, and UI phases must not be collapsed into one oversized task unless the user explicitly requests it.

## Important Historical Distinctions

### Worker NPCs and Relationship NPCs

- Worker NPCs and Relationship NPCs are different concepts and must not be confused.
- Worker NPCs exist for staffing purchased family businesses and are managed separately from full character relationship candidates.
- Relationship NPCs participate in relationship/family flows and use the character-based model.

### Family Businesses

- Family businesses belong to the family, not to an individual character.
- Do not confuse family-owned businesses with external companies used by the playable-character career system.

### Event System

- The approved Event design is category-based under `Resources/Json/Events/`, not one monolithic `event.json`.
- Event `category`, gameplay `domain`, `trigger`, and `presentation.template` are separate concepts.
- Trigger cadence is authored in Event data; EventManager does not hardcode category-wide frequency.
- Story history preserves choices/outcomes/context for later eligibility.
- Lifestyle and Family Agency are manual Event flows.
- Family Agency cooldown is per Event/option, never global, and every Agency Event uses at least a 60-month cooldown.
- Paid Event experiences may be entitlement-gated and launched from Family Agency. Player-selected Event groups use a dedicated selection modal/bottom sheet rather than Family Tree multi-select.
- Applied Event effects must produce player-facing feedback using the actual applied result.

## Recurring Misunderstandings to Avoid

- Do not treat `CONVERSATION_MEMORY.md` as more authoritative than the GDD.
- Do not copy the canonical Google Docs GDD into the repository merely to make it locally available.
- Do not treat `PENDING_DECISIONS.md` as a place for unconfirmed ideas or unresolved questions.
- Do not assume an asset or JSON file means a system is implemented; verify that code or scenes actually consume it.
- Do not assume a backend signal has a player-facing flow; verify that a scene or script consumes it.
- Do not declare the Event System implemented because one sample Event opens; use the full implementation plan and completion audit.

## Memory Maintenance

Keep this file concise and project-relevant. Add only durable context that will prevent future confusion. Implementation facts belong in `DEVELOPMENT_STATUS.md`, architecture facts in `ARCHITECTURE.md`, schema facts in `DATA_SCHEMA.md`, and confirmed unsynchronized gameplay decisions in `PENDING_DECISIONS.md`.
