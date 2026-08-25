# Family Business Pending Confirmed Decisions

## Purpose

This file is only for decisions that:

1. have been explicitly confirmed by the project owner; and
2. have not yet been synchronized to the canonical Google Docs GDD.

It is not a backlog, idea list, question list, speculative design space, or substitute GDD. When a recorded decision is synchronized to the GDD, remove it from this file or mark and archive it clearly.

If an entry conflicts with the GDD or current implementation, identify the conflict before changing behavior and flag the GDD synchronization need. Do not silently redesign the system.

## Current Decisions

### Business visuals are static and channel-specific

- Confirmed on: 2026-08-25
- Confirmed by: project owner
- Affected system(s): Family businesses, Business Modal, Map
- Decision: `BusinessTypes.json` is authoritative for the 12-type roster and its economy/slot values. Each type has independent `map_visual_path` and `modal_visual_path` fields. Business level does not change either visual, visual variants no longer exist, and runtime business instances do not store visual state. Auto Service, Hotel, and Cruise are fully configured through the generic lifecycle.
- Reason/context: The project owner supplied the completed type data and explicitly requested migration away from variant/level-specific building art without changing the GDD in this task.
- Current implementation impact: `BusinessManager` resolves map and modal paths separately from static type data; Business Modal and reusable Map property lookup use their respective paths; runtime creation no longer stores a visual variant.
- GDD section to synchronize: 11.2 Family-Owned Businesses (the visual-variant/level-art sentence) and 13.1 Map Direction (the upgrade-visual sentence).
- Synchronization status: pending

## Entry Template

```markdown
### Decision title

- Confirmed on: YYYY-MM-DD
- Confirmed by: project owner
- Affected system(s):
- Decision:
- Reason/context:
- Current implementation impact:
- GDD section to synchronize:
- Synchronization status: pending
```
