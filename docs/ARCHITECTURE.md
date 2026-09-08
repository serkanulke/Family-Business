# Family Business Architecture

**Repository baseline audited:** `main` at `d22047481c4c0f15161b197ae2dda881bc99b54a` (4 September 2026)  
**Gameplay authority:** canonical GDD v3.8  
**Purpose:** describe current technical ownership and boundaries. This file does not redefine gameplay.

## 1. Product Shape

- Godot 4.7 project, Android/mobile target.
- Reference viewport: 1080 × 1920, portrait.
- Startup scene: `Scenes/MainMenu/MainMenu.tscn`.
- Core runtime is manager/autoload driven.
- Static definitions live primarily under `Resources/Json/`.
- Mutable state is owned by managers and serialized by `SaveManager`.
- Family Business is Event-driven and must not be expanded into an autonomous simulation framework.

## 2. Autoload Order

Current `project.godot` order:

1. `GameManager`
2. `TimeManager`
3. `CharacterManager`
4. `EducationManager`
5. `CareerManager`
6. `HouseManager`
7. `EconomyManager`
8. `BusinessManager`
9. `NPCManager`
10. `RelationshipNpcManager`
11. `ItemManager`
12. `EventManager`
13. `SaveManager`

Later managers may depend on earlier managers. Do not reorder autoloads without checking `_ready()` and runtime dependencies.

## 3. Manager Ownership

### GameManager
Owns global gameplay settings, family identity, pooled Money/Diamonds, and new-game orchestration.

### TimeManager
Owns the Gregorian game date, pause/play/speed state, and date-change signals. Calendar helpers are shared with Event timing.

### CharacterManager
Owns full Character records for player-family members and external Relationship candidates. It owns age/life stage, retirement/pension, death, parent/child/spouse links, current Character stats/flags, active skin-tone genetics, portrait variant identity, and full-Character creation.

### EducationManager
Owns school enrollment, school costs/bonuses, education stage state, university choice, major selection, graduation state, and the factual birthday-driven Education requests.

### CareerManager
Owns external Job/Company eligibility, active Job Offers, unemployed/employed offer cadence and probabilities, Job/Company selection, offer salary, accept/reject, external employment mutation, removal, and salary increase.

### HouseManager
Owns House instances, role/resident assignment, capacity, Household Score/Status/Perks, House upgrades, Unhoused detection/penalty integration, and House cleanup.

### EconomyManager
Owns currently implemented family-economy settlement helpers such as external salary payment, family-business settlement, House monthly expenses, and the 1.40 new-construction multiplier.

**Known implementation gap:** GDD v3.8 defines Economy Index as an active time-based multiplier for applicable Money expenses, including school enrollment cost. The current EconomyManager does not yet calculate/advance/apply Economy Index, and EducationManager currently consumes `School.json.base_cost` directly. This is an implementation gap, not an open design permission to remove Economy Index.

### BusinessManager
Owns family-business type lookup, family-business instances, purchase/upgrade, slots, staffing, worker performance, income/expense, and business map/modal visual lookup.

### NPCManager
Owns lightweight Worker NPC generation, availability, retirement, and Worker NPC records used for family-business staffing.

### RelationshipNpcManager
Owns the reusable Relationship NPC pool, fallback generation/config use, per-family rejection history, assignment/release, relationship eligibility helpers, marriage family-entry, divorce/remarriage cleanup/cooldown, donor/adoption helpers, and active candidate indexing. Relationship NPCs themselves are persistent full Character records in CharacterManager; ending or rolling back a candidate interaction releases that Character rather than deleting it.

### ItemManager
Owns stable item-definition lookup, family ItemInstances, equipment, expiration, exact Lifestyle Score, purchases, and monthly slot-specific shop stock.

### EventManager
Owns Event orchestration only: trigger dispatch, random/save-level pool evaluation, queue/active/scheduled runtime, repeat/cooldown, resolution/effect orchestration, story history, and Event save state. It does not become a second Character/Education/Career/House/Business/etc. model.

### SaveManager
Owns save/load of mutable manager state and Event runtime state.

## 4. Event Architecture

### Static layer

`EventDataRegistry` loads the approved category files under `Resources/Json/Events/`. `EventDataValidator` validates the shared schema, references, requirements, participants, repeat/cooldown, resolution/effects, and graph references.

Current category roots:

- `relationship`
- `education`
- `job_offer`
- `career`
- `household`
- `lifestyle`
- `family_agency`
- `age_lifecycle`
- `business`
- `health`
- `finance`
- `general`

`job_offer` remains a separate category/file for now; gameplay domain is Career.

### Runtime layer

Event runtime uses:

- `EventRuntimeService`
- `EventRuntimeQueryProvider`
- `RequirementEvaluator`
- `EventParticipantResolver`
- `EventPoolSelector`
- `EventResolutionResolver`
- `EventEffectResolver`
- `EventStoryHistory`
- `EventInstance`
- `EventPresentationResolver`

The runtime queries canonical managers instead of copying their mutable state.

### Random pacing

Ordinary random Events use save-scoped pacing. `EventManager` gathers eligible Event+Character candidates for a save-scoped pool, evaluates one pool activation roll, then performs relative weighted selection. Family size enlarges the candidate set but does not multiply activation rolls.

`EventPoolSelector.passes_activation()` applies `activation_chance`. `weight` is used only for relative selection after activation.

Factual/system Events are not suppressed by ordinary random pacing.

### Factual core flows

Education due, Job Offer request, Retirement, and confirmed death/Farewell are factual/core flows. Their owning manager creates the fact; EventManager presents/orchestrates it.

Job Offer is intentionally special:

`CareerManager offer generation -> job_offer_requested -> one generic Job Offer Event -> Accept/Decline -> CareerManager mutation`

CareerManager's existing daily/monthly offer probability logic remains authoritative.

### Presentation data

`EventPresentationResolver` currently resolves player-facing Event content from canonical runtime data. Supported dynamic tags are:

- `{character_name}`
- `{job}`
- `{company_name}`
- `{salary}`

Unknown/unresolved tags remain visible rather than being silently deleted.

There is not yet a complete shared player-facing Event modal/presentation scene wired for all production Event categories.

## 5. Production Event Content

Current production content on the audited baseline:

- Education: 5 core factual Events.
- Age / Lifecycle: 2 core factual Events — Retirement and Farewell.
- Job Offer: 1 generic factual Event.
- Career: empty production category; next authoring target.
- Remaining categories: no production content yet.

Backend architecture should be changed only when real production authoring exposes a concrete blocker.

## 6. Map and Property Architecture

- Map uses an authored 2:1 isometric TileMap/TileMapLayer foundation.
- Main tile reference: 200 × 100.
- Detail grid reference: 50 × 25 aligned to the same axes/origin.
- Map composition is manually authored; runtime does not randomly generate city placement.
- Ground/roads/environment are separate from building sprites.
- Property tags are independent UI/interaction objects.
- Family-business visuals are static across levels and resolved from `BusinessTypes.json` through `map_visual_path` and `modal_visual_path`.
- House level artwork behavior is still an explicit GDD open decision; code/art must not invent replacement level art.

## 7. Character / NPC Boundary

### Full Characters
Player-family members and Relationship candidates share the full Character model. Relationship candidates have `is_player_family = false` until marriage.

### Worker NPCs
Worker NPCs are lightweight staffing records in NPCManager. They are not playable Characters and do not use the playable Education/Career/Relationship pipeline.

Do not merge these two models.

## 8. Static Config and Legacy Data Boundary

The presence of a JSON file is not enough to make it authoritative.

- `GameData.json`: current file is stale/unconsumed. Its intended role as gameplay configuration is valid, but it mixes mutable save state and obsolete values. Redesign before reconnecting.
- `Avatar.json`: stale/unconsumed schema from the older portrait-theme model. Future purchasable avatar themes remain a product idea, but this file must not be reconnected as-is.
- `RelationshipNPC.json` (uppercase): empty legacy collection with no current runtime consumer.
- `relationship_npc.json` (lowercase): active generation/config source for RelationshipNpcManager.
- `npc.json`: active Worker NPC generation/config source.
- Name lists are duplicated between active NPC configs; a shared `Names.json` migration is planned but not implemented yet.

## 9. Save Boundary

Mutable per-save state stays in manager snapshots and Event runtime state. Static JSON must not contain changing values such as:

- current game date
- current family Money
- next runtime IDs
- active assignments
- active Event instances

Configuration migration must keep this distinction.

## 10. Change Discipline

Before adding architecture:

1. Confirm the gameplay need in GDD.
2. Inspect the current owning manager.
3. Prefer a narrow helper/delegation over a new manager/state model.
4. Preserve existing factual/core flows.
5. Add/adjust tests.
6. Update architecture/schema/status docs only for changes actually implemented.
