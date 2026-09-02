# Family Business Event System Implementation Plan

## Purpose

This plan prevents the Event System from becoming one oversized Work task and prevents approved scope from being forgotten between tasks. The system is implemented in bounded phases, but it is **not** considered complete until every phase marked REQUIRED below is finished, integrated, documented, and tested.

Canonical gameplay decisions are in the Google Docs GDD Section 14 / D-147–D-158. Detailed technical target is `docs/EVENT_SYSTEM_SPEC.md`; D-154–D-158 replace the earlier generic effect/requirement contract with manager-aligned operations.

## Working Rule

For every phase:

1. Read GDD Section 14 and `docs/EVENT_SYSTEM_SPEC.md` first.
2. Inspect the current repository and existing managers/tests before editing.
3. Implement the complete scope of that phase; do not substitute a demo/MVP shortcut.
4. Do not begin unrelated UI/category work in the same task.
5. Add/adjust regression tests for all behavior introduced by the phase.
6. Run relevant Godot tests and report exact results.
7. Update `docs/DEVELOPMENT_STATUS.md` after the phase.
8. Update `docs/ARCHITECTURE.md` and `docs/DATA_SCHEMA.md` only for architecture/schema that is actually implemented by that phase.
9. Stop at the phase boundary and report what is complete, what remains, and any blocker before the next phase starts.

## Phase 0 — Documentation Contract — REQUIRED

Status: design discussion complete; GDD synchronized on 2026-09-01. Repository spec/plan files still need to be added if they are not already present.

Deliverables:

- Canonical GDD Section 14 reflects the approved Event architecture.
- `docs/EVENT_SYSTEM_SPEC.md` exists in the repository.
- This implementation plan exists in the repository.
- `AGENTS.md` contains the large-system phasing rule.

No gameplay code/UI is changed in this phase.

## Phase 1 — Static Event Data Foundation and Validator — REQUIRED

Scope is data infrastructure only. Do **not** build Event UI or gameplay resolution here.

Deliverables:

- Create `Resources/Json/Events/`.
- Create all approved category JSON roots with `schema_version`, `category`, `pools`, and `events`.
- Implement the shared Event definition loader/registry and complete static validator described in the spec.
- Validate unique Event IDs across all category files.
- Validate category/file consistency, pools, triggers, participants, requirements, operators, repeat/cooldown, presentation/resource references, choices, resolutions/outcomes, effects, and queued/scheduled Event references.
- Enforce Family Agency per-Event cooldown minimum of 60 calendar months and event scope.
- Add schema-level support for optional `Job.json.event_tags`; do not invent job-to-tag assignments that have not been explicitly approved.
- Add complete regression coverage for loader and validator failures/success cases.

Completion test: all approved static schema constructs can be loaded/validated even if category `events` arrays are still empty.

## Phase 2 — Event Runtime Model, Requirements, Participants, and Manual Discovery — REQUIRED

Scope is eligibility/discovery/runtime context. Do not add full trigger scheduling or outcome/effect execution yet.

Deliverables:

- Implement Event runtime definition lookup and EventInstance creation primitives.
- Implement the complete recursive `all` / `any` / `none` RequirementEvaluator and all approved requirement types/operators.
- Implement participant/context resolution for trigger, player-selected, relation, Relationship NPC, House, Business, and named Character groups.
- Implement player-readable failure reasons from the evaluator for later UI use.
- Implement manual Event discovery for direct and pool-based sources without UI ownership.
- Implement availability states needed by Relationship/Lifestyle/Family Agency consumers.
- Provide an entitlement ownership query boundary/provider expected by the requirement engine; EventManager does not own purchases. Tests may use a controlled provider/fake until the purchase system implements the authoritative provider.
- Revalidate participant/context/requirements before creating an activatable instance.
- Add comprehensive tests.

Completion test: code can correctly answer which manual Events are available/locked for supplied runtime context and can resolve all approved participant patterns without opening UI.

## Phase 3 — Triggers, Pools, Queue, Repeat, Cooldown, and Scheduling — REQUIRED

Scope is Event timing and orchestration. Do not add final outcome/effect mutation UI here.

Deliverables:

- Implement semantic system-trigger dispatch/adapters without storing raw Godot signal paths in JSON.
- Implement Event-defined calendar cadence using real TimeManager calendar math.
- Implement system/calendar/manual/chain/scheduled trigger handling.
- Implement pools: weighted_one, weighted_multiple, all_eligible, max selection.
- Implement `weight`, `exclusive_group`, and `priority` rules.
- Implement Event queue and duplicate suppression.
- Implement one-blocking-Event-at-a-time behavior and pre-Event time-state preservation/restoration.
- Implement all repeat modes.
- Implement all cooldown scopes and real-calendar expiry.
- Enforce Meet Someone as data-driven rather than hardcoded; Gala family 12-month rule remains content data; Agency cooldown remains per Event only.
- Implement scheduled Event persistence model, due processing, and revalidation/expiry behavior.
- Add comprehensive timing/queue/collision/cooldown tests.

Completion test: eligible Events reach the correct queue at the correct time and in the correct order, survive timing state, and scheduled/cooldown behavior is deterministic through simulated calendar progression.

## Phase 4 — Resolution, Effects, EffectResult Feedback, Story History, and Save/Load — REQUIRED

Scope is state mutation and persistence. This phase completes the Event backend core.

Implementation boundary: Phase 4A (resolution/effects/history plus symmetric runtime export/import) and Phase 4B (`SaveManager` version 6 integration, migration, restore integrity, and disk round-trip verification) are complete in the current working tree. Phase 4 is complete; Phase 5 remains separate and has not started.

Deliverables:

- [x] Implement deterministic, weighted, and score_check resolution.
- [x] Implement weighted outcome modifiers.
- [x] Implement the complete whitelist effect dispatcher from the spec.
- [x] Delegate authoritative changes to existing managers; do not duplicate School/Character/Relationship/Business/Item rules.
- [x] Implement temporary/permanent Event-added flag duration behavior without silently resolving unrelated open flag-taxonomy decisions.
- [x] Implement actual applied EffectResult generation for every gameplay effect, including clamp-aware stat feedback.
- [x] Implement auto/custom player-facing feedback payloads while hiding internal flag IDs.
- [x] Implement complete story history records with instance, participant/context, choice, outcome, effects/results, dates, and chain source.
- [x] Implement queue/schedule/cancel Event effects.
- [x] Implement symmetric in-memory runtime export/import and reset without effect replay.
- [x] Integrate EventManager mutable state into SaveManager with a new save-schema version and backwards migration.
- [x] Prove that load does not replay effects, reset cooldowns, reroll scheduled context, or lose history.
- [x] Add comprehensive backend and save/load regression tests.

Completion test: backend Event lifecycle is complete end-to-end without requiring a visual Event screen; tests can trigger, choose/resolve, mutate state, report real results, save, reload, and continue chains correctly.

## Phase 5 — Existing-System Event Adapters and Data Migration — REQUIRED

Scope is integrating already-existing gameplay systems into the common Event backend, one domain at a time with regression protection.

Recommended order and current boundary:

1. [x] Education birthday/enrollment/major flow — Phase 5A backend semantic adapter complete; legacy Education interaction queue/pause contract intentionally retained until its later Event UI migration.
2. [x] External job offers — Phase 5B backend semantic adapter complete; CareerManager offer generation/storage/acceptance/rejection remains authoritative and no presentation migration is included.
3. [x] Age/lifecycle/death/Funeral trigger contract — Phase 5C backend semantic adapter complete; future Funeral Event content uses `character_died` or an Event chain and no Funeral domain system/UI is added.
4. [ ] House/Unhoused/Household Status/Perk bridge.
5. [ ] Family Business trigger/context bridge.
6. [ ] Relationship candidate/event bridge.
7. [ ] Lifestyle manual discovery bridge.
8. [ ] Family Agency manual discovery/entitlement bridge.

Phase 5A implements `education_stage_due`, `school_enrolled`, and `school_graduated` adapters around successful canonical EducationManager operations. It does not migrate the existing Education presentation flow, add production Event content, or complete Phase 5 as a whole. The canonical GDD/spec does not approve a separate `major_selected` or university-decline semantic trigger, so Phase 5A adds neither.

Phase 5B implements `job_offer_requested`, `job_started`, `job_changed`, and `job_lost` adapters around the existing CareerManager active-offer and external-employment operations. It adds only narrow post-success acceptance/removal domain signals; offer eligibility, probability, cooldown, selection, validation, storage, acceptance/rejection, external removal, and salary increase remain CareerManager-owned. It does not add Job Offer/Event UI, production Event definitions, Job tags, rejection/salary semantic triggers, Career Level/XP/progression, or complete Phase 5 as a whole.

Phase 5C implements `age_reached`, `life_stage_changed`, and `retired` adapters around normal `CharacterManager` date transitions and verifies the existing `character_died`/`character_born` bridges. Age/life-stage/retirement/death calculations and mutations remain CharacterManager-owned. Canonical retirement now delegates existing Family Business slot removal to `BusinessManager` after pension/salary state is final. Load normalization applies that domain correction without lifecycle semantic replay. A `character_died` system Event may retain its already-dead primary trigger Character, while ordinary Character participant revalidation still requires a living Character. Phase 5C adds no persistent lifecycle markers, Funeral state/manager/UI, production Event content, or Phase 5D work.

Rules:

- Existing source-of-truth data remains authoritative. Example: `School.json.stat_bonus` stays in School.json.
- Existing managers continue owning their domain state.
- Do not remove proven backend behavior until equivalent Event integration is covered by tests.
- Category integration tasks may be separated into individual Work tasks; each one must fully migrate its own approved scope and update status before the next domain begins.

Completion test: no existing education/career/lifecycle/domain behavior is lost, duplicated, or applied twice after Event integration.

## Phase 6 — Event Presentation Framework — REQUIRED

Start only after the backend lifecycle is stable enough to drive UI and after the relevant visual references are approved.

Deliverables:

- Event UI listens to EventManager signals/state; EventManager never directly edits specific UI nodes.
- Implement approved presentation-template routing.
- Implement blocking modal orchestration above current gameplay screens.
- Render dynamic title/description/participants/art/icons/choices from Event data.
- Render locked-choice requirement reasons from backend evaluation.
- Render EffectResult feedback using actual applied results.
- Preserve authoritative supplied visual references exactly; no independent redesign.
- Add rendering/interaction tests where practical.

Do not create every category-specific UI in one Work task. Each approved template can be implemented and visually validated as a separate bounded task.

## Phase 7 — Participant Selection UI — REQUIRED

Deliverables:

- Dedicated modal/bottom sheet for player-selected participants.
- Supports exact and ranged min/max selection.
- Shows selected count and prevents over-selection.
- Supports configured display of ineligible Characters with backend-provided reasons.
- Supports relevant-stat display when Event metadata requests it.
- Final confirmation revalidates participants, requirements, cost, and entitlement before Event start.
- Cancel performs no cost, cooldown, entitlement-consumption, or completed-history mutation.
- Family Tree is never repurposed as a temporary multi-select mode.
- Visual treatment must use an approved reference or the closest already-approved Family Business selection-sheet language; ambiguous design details require user direction.

## Phase 8 — Player-Facing Category Flows — REQUIRED

Implement category flows as separate Work tasks rather than one combined UI project. Each task uses the common backend and approved templates.

Potential sequence, subject to the user's implementation priority at that time:

- Education Event UI.
- Job Offer Event UI.
- Relationship Event UI/progression.
- Lifecycle/death/funeral UI.
- Household Event UI.
- Business Event UI.
- Lifestyle screen and Lifestyle Event flow.
- Family Agency screen integration and Agency Event flow.

A category is not complete merely because a modal renders; eligibility, participant/context binding, effects, feedback, history, cooldown, save/load, and all approved category-specific behavior must be verified.

## Phase 9 — Final Event-System Completion Audit — REQUIRED

Before declaring Event System complete:

- Audit every item in `docs/EVENT_SYSTEM_SPEC.md` against real code/data/tests.
- Search for legacy duplicated event queues/rules that should now route through the common system.
- Verify all five trigger types.
- Verify all requirement and cooldown scopes.
- Verify deterministic/weighted/score-check outcomes.
- Verify all supported effect families and EffectResult feedback.
- Verify story memory and scheduled revalidation across save/load.
- Verify Family Agency cooldown affects only the selected Agency Event and is never global.
- Verify Agency minimum 60-month rule.
- Verify participant selector does not use Family Tree selection mode.
- Verify Event UI follows approved visual references.
- Update GDD only if a new gameplay decision was explicitly approved; otherwise update repository docs to observed final implementation state.

Only after this audit passes should `DEVELOPMENT_STATUS.md` mark the Event System implemented.

## Content Decisions Still Separate from Architecture

The architecture is approved, but content authoring remains its own task. In particular:

- Exact `Job.json.event_tags` assignment per job must be explicitly authored/approved before career-tag-dependent production Events are populated.
- Exact Event copy, art paths, choice text, individual stat/flag effects, weights, and cooldown values (except already decided rules such as Gala/Agency limits) are Event-content decisions.
- Final UI references must be supplied/approved per Event presentation template before Work is allowed to improvise a new visual design.
