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

## Authoritative Visual References

When the user supplies an approved screen, modal, mockup, screenshot, or other visual UI reference, that reference is authoritative for presentation. Reproduce it as closely as Godot permits at the project's reference resolution. Do not redesign, improve, reinterpret, normalize, simplify, restyle, or substitute independent UI conventions unless the user explicitly grants visual-design freedom for that specific area.

Required fidelity includes layout and geometry; component dimensions; margins, padding, gaps, and alignment; text centering; typography size, weight, line height, and placement; colors; borders and separators; shadows; icon size and placement; button geometry and enabled or disabled states; pill or tag treatment; and every corner radius, including asymmetric or per-corner radii. Preserve referenced image and portrait aspect ratio, crop, mask, silhouette, and edge treatment. Do not arbitrarily round, crop, mask, reframe, recolor, or otherwise restyle an existing asset unless the approved reference shows that treatment or the user explicitly requests it.

Treat visual deviations as implementation defects rather than design alternatives. If a referenced detail is ambiguous, technically impossible, or depends on a missing asset, preserve every unambiguous detail, report the unresolved point, and request direction instead of guessing. Fit functional implementation to the approved visual design rather than changing the approved design for implementation convenience.

When no direct visual reference is supplied for a required UI element, inspect the project's existing user-approved Family Business screens and reuse the closest established component and design language. This applies to modals, bottom sheets, cards, buttons, tags, pills, icons, character selectors, empty states, headers, information panels, typography, spacing, corner radii, colors, and separators. Do not invent a new design language. If neither a direct approved reference nor an approved existing precedent resolves the presentation, stop and report the ambiguity instead of making an independent visual-design decision.

## Before Changing Code or Data

- Read the relevant project documentation first: `docs/ARCHITECTURE.md`, `docs/DATA_SCHEMA.md`, `docs/DEVELOPMENT_STATUS.md`, `docs/PENDING_DECISIONS.md`, and `docs/CONVERSATION_MEMORY.md` as applicable.
- Inspect the current implementation before changing an existing system. Read the relevant manager/autoload, JSON files, scenes, UI adapters, and tests.
- Preserve the current manager/autoload and JSON-driven architecture unless there is a specific, documented reason to change it.
- Keep solutions as simple as the confirmed design permits. Do not add unnecessary systems, abstractions, or mechanics.
- Do not confuse Worker NPCs managed by `NPCManager` with Relationship NPCs managed by `RelationshipNpcManager`.
- Treat family businesses as family-owned systems. Do not model them as property of an individual character unless the canonical GDD is explicitly changed.

## Large-System Implementation Phasing

For large, cross-cutting systems, especially the Event System, do not combine data architecture, backend lifecycle, integrations, UI, and category content into one oversized task unless the user explicitly requests that scope.

- Use approved project documentation as the contract before starting each phase.
- For Event System work, read GDD Section 14 plus `docs/EVENT_SYSTEM_SPEC.md` and `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`.
- Finish the complete approved scope of the current phase, including tests and required documentation updates. Do not replace the phase with a small demo, MVP shortcut, or placeholder implementation and call it complete.
- Do not silently forget remaining approved scope. The implementation plan remains the checklist until the final completion audit passes.
- Stop at the defined phase boundary, report exact completed/remaining work and test results, and wait for the next user instruction before starting the next phase.
- Do not mix unrelated UI/category implementation into a backend/data phase.
- The overall system may be marked implemented only after every required phase and final audit are complete.

## Documentation Maintenance

After any implementation or behavior change:

- Always update `docs/DEVELOPMENT_STATUS.md` so it matches the repository.
- Update `docs/ARCHITECTURE.md` when managers, autoloads, dependencies, scene boundaries, or system responsibilities change.
- Update `docs/DATA_SCHEMA.md` when JSON, runtime dictionaries, save data, identifiers, or relationships change.
- Update `docs/PENDING_DECISIONS.md` only for confirmed decisions that have not yet been synchronized to the canonical GDD. Do not use it for ideas, guesses, or open questions.
- Update `docs/CONVERSATION_MEMORY.md` only when durable historical context, working principles, or recurring misunderstandings need to be preserved.

Documentation must describe observed repository state. When evidence is missing, say that it was not found; do not guess.
