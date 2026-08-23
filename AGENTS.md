# Family Business Project Instructions

These instructions apply to the entire repository.

## Canonical GDD

The canonical and authoritative Game Design Document (GDD) is the existing Google Docs file:

https://docs.google.com/document/d/1HZtUIWQbsv9_jlnWxuWCbPhk4MviQm9bTuiMSxqBVCE/edit?tab=t.0

Before implementing or modifying any gameplay system:

1. Read the relevant section of the canonical GDD.
2. Treat confirmed GDD decisions as the authoritative gameplay design source.
3. Do not create, copy, or regenerate a local GDD unless the user explicitly requests it.
4. Do not replace or overwrite the existing Google Docs GDD with a newly generated document.
5. Do not invent gameplay rules, values, mechanics, or exceptions that the GDD does not establish.
6. If `docs/PENDING_DECISIONS.md` contains a confirmed decision that has not yet been synchronized to the GDD, treat it as newer confirmed project context, flag it for GDD synchronization, and do not silently resolve any conflict.
7. If the GDD, a pending confirmed decision, and the current implementation appear to conflict, identify the conflict before changing behavior. Do not silently redesign the system.

`docs/CONVERSATION_MEMORY.md` is historical context only. It never overrides the canonical GDD, a confirmed pending decision, or the factual state of the repository.

## Before Changing Code or Data

- Read the relevant project documentation first: `docs/ARCHITECTURE.md`, `docs/DATA_SCHEMA.md`, `docs/DEVELOPMENT_STATUS.md`, `docs/PENDING_DECISIONS.md`, and `docs/CONVERSATION_MEMORY.md` as applicable.
- Inspect the current implementation before changing an existing system. Read the relevant manager/autoload, JSON files, scenes, UI adapters, and tests.
- Preserve the current manager/autoload and JSON-driven architecture unless there is a specific, documented reason to change it.
- Keep solutions as simple as the confirmed design permits. Do not add unnecessary systems, abstractions, or mechanics.
- Do not confuse Worker NPCs managed by `NPCManager` with Relationship NPCs managed by `RelationshipNpcManager`.
- Treat family businesses as family-owned systems. Do not model them as property of an individual character unless the canonical GDD is explicitly changed.

## Documentation Maintenance

After any implementation or behavior change:

- Always update `docs/DEVELOPMENT_STATUS.md` so it matches the repository.
- Update `docs/ARCHITECTURE.md` when managers, autoloads, dependencies, scene boundaries, or system responsibilities change.
- Update `docs/DATA_SCHEMA.md` when JSON, runtime dictionaries, save data, identifiers, or relationships change.
- Update `docs/PENDING_DECISIONS.md` only for confirmed decisions that have not yet been synchronized to the canonical GDD. Do not use it for ideas, guesses, or open questions.
- Update `docs/CONVERSATION_MEMORY.md` only when durable historical context, working principles, or recurring misunderstandings need to be preserved.

Documentation must describe observed repository state. When evidence is missing, say that it was not found; do not guess.
