# Family Business Project Instructions

These instructions apply to the entire repository.

## Project Identity and Hard Scope Boundary

Family Business is an intentionally simple, portrait-oriented, Android, Event-driven family-management game. It is **not** a life-simulation sandbox, autonomous simulation project, or general simulation framework.

The normal gameplay shape is:

`Event/factual trigger -> player choice -> existing manager state changes -> optional authored chain/schedule -> Event ends.`

Do not introduce continuous hidden simulation, autonomous NPC behavior, new meters, parallel progression/state machines, extra managers, background systems, or new persistent gameplay fields unless the project owner explicitly approves them first. Existing time progression, managers, NPC records, or genre terminology do not authorize new simulation layers.

## Authority Order

### 1. Canonical GDD

The authoritative gameplay design source is the existing Google Docs GDD:

https://docs.google.com/document/d/1HZtUIWQbsv9_jlnWxuWCbPhk4MviQm9bTuiMSxqBVCE/edit?tab=t.0

Before implementing or changing gameplay:

1. Read the relevant GDD section.
2. Treat DECIDED rules as binding.
3. Do not invent missing gameplay rules, values, mechanics, exceptions, or future systems.
4. OPEN and DEFERRED items are not permission to choose a solution.
5. Do not recreate a local GDD or overwrite the canonical Google Doc.

Before editing the GDD itself, first report the exact proposed changes to the project owner in Turkish and wait for explicit approval. Do not silently add, reinterpret, or resolve gameplay decisions.

### 2. Event Authoring Guide

For production Event JSON/schema authoring, use the current Event Authoring Guide together with GDD Section 14:

https://docs.google.com/document/d/15hkCdEh04VpaqxRUfah1BY7yeuijAgLFRMQz47k3Ldg/edit

The Guide describes the approved authoring contract. Repository code remains the factual source for what the validator/runtime actually supports.

### 3. Current Repository

The current `main` branch is the factual source for implemented code, data, scenes, assets, and tests. Inspect the actual manager, JSON, scene/UI adapter, and tests before changing an existing system.

### 4. Repository Documentation

- `docs/ARCHITECTURE.md` — current technical boundaries and responsibilities.
- `docs/DATA_SCHEMA.md` — current static/runtime/save schemas and known legacy-data status.
- `docs/DEVELOPMENT_STATUS.md` — implemented/partial/missing state and known gaps.
- `docs/EVENT_SYSTEM_SPEC.md` — current Event backend/authoring technical contract.
- `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md` — current production Event/content roadmap, not a historical phase checklist.
- `docs/MAP_ART_STANDARD.md` — current Map/building art geometry and footprint rules.
- `docs/PENDING_DECISIONS.md` — only confirmed decisions not yet synchronized to the GDD.
- `docs/CONVERSATION_MEMORY.md` — durable historical context only.

Repository documentation never overrides a newer confirmed GDD decision.

## Before Changing Code or Data

- Explain the exact proposed behavior/files before making a foundation-preserving code/data change when the project owner has not already approved that concrete change.
- Read the relevant GDD and project docs first.
- Inspect current implementation and tests before editing.
- Prefer the smallest change that satisfies approved gameplay.
- Preserve existing manager ownership; do not duplicate canonical state in EventManager, UI, or another manager.
- Static/tunable data should remain data-driven when the GDD assigns it to JSON/configuration. Mutable save state remains manager/SaveManager-owned.
- Do not reconnect a legacy JSON file merely because it exists. Confirm its current design purpose and migrate it deliberately.
- Do not confuse Worker NPCs (`NPCManager`) with full Character-based Relationship candidates (`RelationshipNpcManager` / `CharacterManager`).
- Family businesses are family-owned and distinct from external Career companies.

## Event System Production Rules

The Event backend core already exists. Production work must **not** restart a broad architecture audit or redesign the Event system unless a real production Event exposes a concrete blocker.

### Ordinary random Events

- Ordinary random Event pacing is controlled at **save level**, not independently per Character or per category.
- Family size enlarges the eligible Event+Character candidate set; it must not linearly multiply random rolls/modals.
- Categories are organization/eligibility domains, not quotas.
- A save-scoped random pool may fail its activation roll and produce no Event.
- `weight` is relative selection weight after the pool is allowed to activate. It is never an absolute occurrence probability.
- Save-scoped random pools use the approved `selection_scope: "save"`, `activation_chance`, and positive `max_events` contract.

### Factual/core Events

Factual Events representing an already-existing authoritative gameplay fact bypass ordinary random pacing. Examples:

- Education stage due / major selection due.
- CareerManager Job Offer request.
- Retirement.
- Confirmed death -> Farewell.

Do not move factual/core flows into ordinary save-level random pacing merely to make Event categories look uniform.

### Job Offer

- External Job Offer is a core factual Career flow.
- `CareerManager` remains authoritative for eligibility, unemployed/employed offer probabilities, cooldowns, Job/Company selection, salary, active offers, accept/reject, and employment replacement.
- All Jobs use one generic production Job Offer Event; do not create one Event per Job.
- Runtime presentation resolves `{character_name}`, `{job}`, `{company_name}`, and `{salary}` from bound/canonical data.
- Do not move CareerManager's Job Offer generation into ordinary random Event pacing.

### Event effects and manager boundaries

- EventManager orchestrates; it is not a second gameplay model.
- No Career Level, Education Level, numeric Relationship Level, compatibility/attraction meter, generic House assignment, Event-controlled Business staffing, or Item damage system exists.
- Education progression, Job offers, marriage/divorce, Houses, Businesses, Items, economy, and Character lifecycle remain owned by their existing managers.
- Add a new manager/state/effect family only after explicit design approval.

## Production Event Workflow

Current production order:

1. Education — core production Events complete.
2. Age / Lifecycle — Retirement + Farewell complete.
3. Job Offer — one generic factual production Event complete.
4. Career — next production category.
5. Relationship.
6. Household.
7. Business.
8. Health.
9. Finance.
10. General.
11. Lifestyle.
12. Family Agency.

Within a category, author core/mandatory playable-loop Events first and flavor/random Events later.

Before creating a production Event, read the current GDD, Event Authoring Guide, relevant manager/data, and current Event JSON/tests. Do not guess schema or balance values. If production authoring exposes a genuine backend blocker, report the exact blocker and propose the narrowest correction before changing the core.

## Visual Implementation Rule

When the project owner supplies an approved screen, modal, mockup, screenshot, or other visual reference, it is authoritative for presentation.

Do not redesign, improve, reinterpret, normalize, simplify, restyle, or substitute independent UI conventions. Match layout, geometry, spacing, typography, colors, borders, shadows, icon placement, button states, tags/pills, corner radii, image crop/mask, and alignment as closely as Godot permits.

If a referenced detail is ambiguous or a required asset is missing, preserve all unambiguous parts and report the unresolved point instead of guessing. When no direct reference exists, reuse the closest already-approved Family Business UI language; do not invent a new design language.

## Documentation Maintenance

After implementation or behavior changes:

- Update `docs/DEVELOPMENT_STATUS.md` to match repository reality.
- Update `docs/ARCHITECTURE.md` when technical responsibilities/dependencies change.
- Update `docs/DATA_SCHEMA.md` when static/runtime/save schemas change.
- Update `docs/EVENT_SYSTEM_SPEC.md` only when the implemented Event technical contract changes.
- Update `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md` when production Event/category progress changes.
- Update `docs/PENDING_DECISIONS.md` only for an explicitly confirmed decision not yet synchronized to the GDD; remove it after GDD synchronization.
- Keep `docs/CONVERSATION_MEMORY.md` concise and historical; implementation facts belong elsewhere.

Documentation must distinguish approved design from observed implementation. When evidence is missing, say it was not found; do not guess.
