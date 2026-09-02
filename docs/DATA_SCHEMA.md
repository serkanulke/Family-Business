# Family Business Data Schema

## Scope

This document records schemas observed in the current JSON files, manager-created runtime dictionaries, and save snapshots. It is descriptive, not a replacement for the canonical GDD. Optional and nullable fields are shown where the implementation explicitly permits them.

## Static JSON Catalog

| File | Root shape | Current code usage |
| --- | --- | --- |
| `Character.json` | `{ "characters": [] }` | Loaded by `CharacterManager`; currently an empty seed collection. Runtime changes remain in memory/save data. |
| `Major.json` | `majors[]` (16 records) | Loaded by `CharacterManager`. |
| `Job.json` | `jobs[]` (88 records); each record may optionally contain `event_tags: String[]` | Loaded by `CharacterManager`; Phase 1 Event validation checks optional tags without requiring or auto-authoring them. Existing 88 records remain unchanged and omit the field. |
| `School.json` | `schools[]` (12 records) | Loaded by `EducationManager`. |
| `Companies.json` | `companies[]` (90 records) | Loaded by `CareerManager`. |
| `Business.json` | `{ "businesses": [] }` | Loaded by `BusinessManager`; currently an empty seed collection. Runtime changes remain in memory/save data. |
| `BusinessTypes.json` | `performance_model` plus `business_types[]` (12 approved types) | Loaded by `BusinessManager`; all 12 types contain complete five-level economy and slot definitions. |
| `npc.json` | `generation`, `names`, and `portraits` | Loaded by `NPCManager` for Worker NPCs. |
| `relationship_npc.json` | `generation` and `names` | Loaded by `RelationshipNpcManager`. |
| `ItemCatalog.json` | `catalog_version`, `pricing_status`, and `items[]` (261 generated definitions) | Generated explicitly from existing PNG paths and loaded by `ItemManager`; it is stable source data and is not regenerated when the shop opens. |
| `Avatar.json` | `themes[]` (1 record) | No code or scene reference found. Character portraits are currently resolved by `CharacterManager` from resource folders/paths. |
| `Flag.json` | `flags[]` (30 records) | Character records contain `flag_ids`; `HouseholdPerks.json` references the existing musician/painter IDs for Head-of-Household perk resolution. No general flag manager was found. |
| `GameData.json` | `game` object | No code or scene reference found. |
| `House.json` | `house_definitions[]` (1 definition) | Loaded by `HouseManager`; defines visuals, five levels, prices/capacities/expenses, roles/required stats/importance, role-performance contributions, score bounds, and status thresholds. |
| `HouseholdPerks.json` | `household_perks[]` | Loaded by `HouseManager`; maps existing Character flag IDs/names to event-queryable household perk IDs and display labels. |
| `RelationshipNPC.json` | `{ "relationship_npcs": [] }` | No code or scene reference found; active relationship candidates are full character records. |
| `Events/*.json` | `{ schema_version: 1, category, pools[], events[] }` across 12 approved category files | Loaded and atomically validated by the Autoload-free `EventDataRegistry`; production pools/Events are currently empty. |

Filename case matters in the current repository: both `relationship_npc.json` and `RelationshipNPC.json` exist and have different roles/statuses.

## Static Event Definitions — Phase 1

The implemented category files are `relationship`, `education`, `job_offer`, `career`, `household`, `lifestyle`, `family_agency`, `age_lifecycle`, `business`, `health`, `finance`, and `general`. Their filenames must match `category`, and the root accepts exactly:

```text
{
  schema_version: 1,
  category: String,
  pools: PoolDefinition[],
  events: EventDefinition[]
}
```

Pool IDs and Event IDs are global registry keys. A pool is:

```text
{
  pool_id: String,
  selection_mode: "weighted_one" | "weighted_multiple" | "all_eligible",
  max_events?: positive int | null
}
```

`weighted_multiple` requires `max_events`; `weighted_one` may only use `1`. An Event may join a pool through its optional `pool_id` or a calendar/manual trigger `pool_id`.

The Phase 1 Event definition contract implemented by the validator is:

```text
{
  event_id: String,                 # globally unique
  category: String,                 # must match the owning file
  domain: String,
  subtype: String,
  enabled: bool,
  rarity: common | uncommon | rare | epic | legendary,
  weight: positive number,
  priority: int,
  exclusive_group: String | null,
  pool_id?: String | null,

  trigger: TriggerDefinition,
  participants: { participant_name: ParticipantDefinition },
  requirements: RequirementGroup,
  repeat: { mode: RepeatMode },
  cooldown: { scope, unit, value } | null,
  behavior: { blocking: bool, pause_game: bool },
  content: { title: String, description: String, subtitle?: String | null },
  presentation: {
    template: String,
    art_path?: res:// path | null,
    header_icon?: res:// path | null
  },
  cost?: { currency: money | diamonds, amount: non-negative number } | null,
  choices: ChoiceDefinition[],
  default_resolution?: ResolutionDefinition | null,
  metadata?: Dictionary
}
```

`presentation` contains only a template identifier and optional existing resources. Scene geometry/style fields are rejected. Phase 1 validates the template identifier's required String shape; template scene routing does not exist until the approved UI phase.

Supported triggers are `system`, `calendar`, `manual`, `chain`, and `scheduled`. Calendar definitions contain exactly one of a positive `cadence { unit: day|week|month|year, interval }`, `exact_date`, or `date_window { start, end }`. Date points are `YYYY-MM-DD` or `{ month, day, year? }`; omitting `year` represents an annual date/window. Manual definitions require `source` and `mode: direct|pool`; pool mode requires a valid pool reference.

Participant types are `character`, `character_group`, `relationship_npc`, `house`, `business`, and `context`. Sources are `trigger`, `player_selected`, `relation`, `relationship_npc`, `primary_house`, `owned_business`, and `context`. Relation definitions name an existing participant in `from` and use `spouse`, `child`, `parent`, or `family_member`. Player-selected character groups use positive `min`/`max`, `min <= max`, optional recursive requirements, and optional `selection_ui { title, description, show_ineligible, show_relevant_stats? }`.

Requirement groups recursively contain `all`, `any`, and/or `none` arrays. Leaf requirements use `{ type, target?, operator, value, ... }`. The implemented whitelist covers Character/stat/flag/lifecycle, family structure, employment/Job/Job-tag, concrete education state, Lifestyle/items, economy, House/status/perk, family Business, Event story memory, entitlement, and world/date. `career_level`, `education_level`, `relationship_exists`, `relationship_status`, and `relationship_level` are unsupported under D-156/D-157. Existing spouse links use `has_spouse`; Relationship candidates remain runtime participants/context. Valid operators are restricted by value domain. Canonical stat names are `happiness`, `health`, `logic`, `attractiveness`, `social`, `confidence`, `discipline`, and `creativity`. Statically resolvable IDs/names are checked against existing authoritative JSON catalogs. `choice_made` and `outcome_reached` use `{ event_id, choice_id|outcome_id }` and are checked against the referenced Event definition.

Repeat modes are `once`, `once_per_character`, `once_per_character_pair`, `once_per_family`, `once_per_house`, `once_per_business`, and `repeatable`. Cooldowns use scopes `event`, `character`, `character_pair`, `family`, `house`, or `business`, calendar units `day`, `week`, `month`, or `year`, and a positive integer value. Every `family_agency` definition requires `scope: event` and at least `60` months or `5` years; arbitrary day/week conversions do not satisfy this calendar rule.

Choices have a per-Event unique `choice_id`, title, optional description/icon/requirements/cost, and required resolution. Resolution modes are:

- `deterministic`: `effects[]`;
- `weighted`: non-empty unique `outcomes[]` with positive `weight`, optional requirement-based numeric `add_weight` modifiers, and `effects[]`;
- `score_check`: non-empty weighted numeric `sources[]`, numeric `threshold`, and unique `success`/`failure` outcome blocks with effects.

The effect whitelist is `stat_change`, `stat_set`, `add_flag`, `remove_flag`; `relationship_marry`, `relationship_divorce`; `money_change`, `diamond_change`; `accept_job_offer`, `reject_job_offer`, `job_remove`, `salary_increase`; `education_enroll`; `add_item`, `remove_item`, `equip_item`, `unequip_item`; `remove_from_house`; `business_upgrade`; and `queue_event`, `schedule_event`, `cancel_scheduled_event`. Each effect validates its participant/context target and statically available data/Event references. `salary_increase.amount` is a positive integer; `education_enroll.school_id` is a canonical School reference. Executable code, scripts, callables, raw methods, and signal paths are forbidden. D-154/D-157 remove generic Business mutations and staffing changes; future Business-specific mutations require separately approved authoritative behavior.

An effect may optionally define `feedback: { mode: auto|custom, text?: String, icon_path?: String|null }`. `custom` requires non-empty player-facing text. Runtime `EffectResult.display` never exposes a technical flag ID; auto feedback reports actual applied values after canonical clamp/validation.

D-155 removes `damage_item`: normal Item durability remains derived from `purchase_date + durability_months = expiration_date`, while Family Heirlooms remain non-expiring. Static Item effects store catalog `item_id` and a target Character, never a runtime `instance_id`. At runtime, `equip_item` excludes instances equipped by another Character; `unequip_item` can affect only the target's matching equipped instance; and `remove_item` prefers that target-equipped match before an unequipped match. Eligible duplicate instances use nearest `expiration_date`, then oldest `purchase_date`, then ascending `instance_id`, with non-expiring instances after expiring ones. Another Character's equipped instance is never transferred or removed implicitly.

D-156 removes generic relationship effects and pair-state requirements. `relationship_marry` and `relationship_divorce` carry `primary` and `target` participant references and delegate to the existing Relationship manager operations. D-157 removes generic career assignment/progression, education change/completion, House assignment, and Business staffing effects. The remaining Career effects carry only a target Character, except positive-integer `salary_increase.amount`; active offer data remains manager-owned.

These are static definition schemas. Phase 2–4A add the runtime structures below without changing the production JSON roots.

## Event Runtime Query Structures — Phases 2 and 4A

`EventInstance` remains outside save version 5 in Phase 4A:

```text
{
  instance_id: String,              # evt_00000001
  event_id: String,                 # lookup key into EventDataRegistry
  definition_version: int,
  trigger_type: String,
  created_date: YYYY-MM-DD,
  started_date: YYYY-MM-DD | null,
  completed_date: YYYY-MM-DD | null,
  status: queued | active | completed | cancelled | expired,
  participants: Dictionary,         # character IDs, Character-ID arrays, House/Business IDs
  context: Dictionary,
  choice_id: String | null,
  outcome_id: String | null,
  effect_results: EffectResult[],
  source_instance_id: String | null
}
```

The instance never stores duplicated title, description, art, or presentation data. Runtime IDs increment deterministically within the current service session. Phase 3 exports the next counter in a serializable runtime snapshot, but does not connect that snapshot to `SaveManager`.

Requirement evaluation returns:

```text
{
  eligible: bool,
  failure_reasons: [{
    code: String,
    message: String,                # player-readable
    requirement_type?: String,
    target?: String,
    operator?: String,
    expected_display?: String
  }]
}
```

Participant resolution returns resolved IDs/context plus `pending_selections`, `failure_reasons`, and `candidate_groups`. A Character-group candidate is:

```text
{
  character_id: int,
  eligible: bool,
  failure_reasons: Array
}
```

Group results also retain the definition's minimum, maximum, and non-visual `selection_ui` content metadata. No UI geometry is included.

Manual discovery returns one availability entry per matching definition. `status` is `available`, `locked_requirements`, `locked_cooldown`, `locked_cost`, `completed_non_repeatable`, `requires_participants`, or `disabled`. Each entry includes Event ID, structured failure reasons, resolved participants/context, pending selections/candidates, and registry-backed content/presentation/definition data. The Phase 2 discovery call remains non-selecting; Phase 3 `EventManager.invoke_manual_pool` performs the pool selection and queueing step after discovery eligibility.

`EventHistoryQueryProvider`, `EntitlementQueryProvider`, and `EventAvailabilityStateProvider` are query contracts. Entitlement remains neutral by default. `EventManager` supplies `EventStoryHistory` and the session-local repeat/cooldown provider. No Event field is added to save version 5.

## Event Orchestration Runtime Structures — Phase 3

A trigger occurrence is a session structure used for dispatch and duplicate suppression:

```text
{
  occurrence_id: String,
  trigger_type: system | calendar | manual | chain | scheduled,
  semantic_event: String,
  game_date: YYYY-MM-DD,
  source: String,
  primary_character_id: int,
  context: Dictionary
}
```

The queue state is `{ active_event: EventInstance | {}, queued_events: EventInstance[] }`. Priority sorts queued instances descending and an internal insertion number preserves stable equal-priority order. Occurrence/participant/context identities are normalized for duplicate suppression; Character-ID arrays are order-independent in identity comparisons.

A scheduled runtime record is:

```text
{
  scheduled_event_id: String,       # sched_00000001
  event_id: String,
  due_date: YYYY-MM-DD,
  participants: Dictionary,
  context: Dictionary,
  source_instance_id: String | null,
  status: scheduled | queued | cancelled | expired,
  queued_instance_id: String | null,
  failure_reasons: Array
}
```

Repeat consumption is recorded only on completion:

```text
{
  event_id: String,
  mode: once | once_per_character | once_per_character_pair | once_per_family | once_per_house | once_per_business,
  repeat_key: String,
  completed_date: YYYY-MM-DD
}
```

Cooldowns are also committed only on completion:

```text
{
  event_id: String,
  scope: event | character | character_pair | family | house | business,
  scope_key: String,
  started_date: YYYY-MM-DD,
  available_date: YYYY-MM-DD
}
```

Character-pair keys are numerically normalized. The `available_date` is calculated with Gregorian day/week/month/year arithmetic; months and years preserve the original day when possible and clamp to the target month end otherwise.

## Event Resolution Runtime Structures — Phase 4A

Every successful gameplay effect produces `{ success, effect_type, effect_index, target/context identifiers as applicable, requested/applied/before/after values as applicable, display: { mode, text, icon_path } }`. A preflight failure returns a structured failed result and commits no Event/choice cost, prior effect, completed history, repeat record, or cooldown.

Story history is an array of terminal `EventInstance` dictionaries. It preserves instance/Event IDs, lifecycle dates/status, participant/context bindings, choice/outcome IDs, EffectResults, and source-chain ID. It answers `event_seen`, `event_completed`, `event_not_completed`, `choice_made`, and `outcome_reached` using requested participant/context bindings.

`EventManager.export_runtime_state()` and `import_runtime_state()` symmetrically cover active/queued/scheduled instances; story history; repeat/cooldown and temporary-flag records; deterministic Event/schedule/queue counters; outcome/pool RNG state; occurrence, calendar, selection, queue-order, and duplicate-rebuild data; and blocking pause ownership. Import reconstructs runtime instances without replaying effects. This remains session/in-memory integration only: there is no `SaveManager` field or save-version change until Phase 4B.

## Character Records

`CharacterManager.characters` contains both family/playable characters and relationship candidates. Core fields created by `CharacterManager` are:

| Group | Fields |
| --- | --- |
| Identity | `character_id: int`, `first_name: String`, `gender: "female" \| "male"` |
| Appearance | `avatar_theme: String`, `genetics: { skin_tone }`, `portrait_variant_id: String`, derived/current `portrait_path: String` |
| Lifecycle | `is_alive: bool`, `birth_date: YYYY-MM-DD`, `death_date: String \| null`, `life_stage: String`, `is_retired: bool` |
| Family links | `is_player_family: bool`, `parent_ids: int[]`, `is_adopted: bool`, `partner_id: int \| null`, `children_ids: int[]` |
| Education | `school_id: int \| null`, `major_id: int \| null`, `education_status: String`, `education_start_date`, `major_selection_date`, `expected_graduation_date`, `graduation_date` (date string or null) |
| Career | `job_id: int \| null`, `company_id: String \| null`, `salary: int`, `last_salary: int`, `pension: int`, `unemployment_start_date`, `job_offer_cooldown_until` (date string or null) |
| Stats | Top-level integer fields: `health`, `happiness`, `logic`, `attractiveness`, `social`, `confidence`, `discipline`, `creativity` |
| History | `flag_ids: Array`, `event_log: Array` |

Relationship candidates add:

- `character_type: "relationship_npc"`
- `linked_character_id: int`
- `relationship_status: String`
- `relationship_cooldown_until: String | null`

The code derives age from `birth_date`; no stored `age` field is created for characters. Life stages returned by the current implementation are baby 0-5, child 6-11, teen 12-17, young adult 18-34, adult 35-59, and elder 60+.

Legacy `mother_id` and `father_id` values are migrated into `parent_ids` and then erased during normalization.

`skin_tone` is the only active inherited visual genetic field and uses `light`, `mixed`, or `dark`. Legacy records may still contain `hair_color` and `eye_color`; loading preserves/ignores those deferred fields, while new Character creation, validation, inheritance, and portrait selection do not require or generate them.

`portrait_variant_id` stores the persistent filename stem (for example `character_001`) rather than a resource path. `portrait_path` is a current derived compatibility field resolved from gender, `skin_tone`, `life_stage`, and `portrait_variant_id`. Playable portraits use `Resources/Characters/Male|Female/Light|Mixed|Dark/Baby|Child|Teen|YoungAdult|Adult|Elder/<variant>.png`. Save loading normalizes legacy `Man`/`Woman` paths and derives a missing variant from the legacy filename when possible.

## Worker NPC Records

Worker NPCs are stored separately in `NPCManager.worker_npcs`:

```text
{
  id: String,                 # generated as npc_000001, ...
  first_name: String,
  last_name: String,
  gender: "female" | "male",
  birth_date: YYYY-MM-DD,
  portrait_path: String,
  stats: {
    health, logic, discipline, creativity,
    social, confidence, attractiveness, happiness
  },
  is_retired: bool
}
```

Worker NPC stats are nested under `stats`; character stats are top-level. `BusinessManager` explicitly supports both shapes when calculating slot performance.

## Business Data

### Type definition (`BusinessTypes.json`)

```text
performance_model: {
  eligibility_rule: String,
  score_rule: String,
  tiers: [{ tier, min_score, max_score, multiplier }]
}

business_types[]: {
  business_type_id: String,
  display_name: String,
  max_level: int,
  map_visual_path: String,
  modal_visual_path: String,
  slot_definitions: [{
    slot_id: String,
    role_name: String,
    unlock_level: int,
    base_gross_contribution: int,
    required_stats: { <stat_name>: int }
  }],
  levels: [{
    level: int,
    cost: int,
    fixed_monthly_expense: int,
    slot_ids: String[]
  }]
}
```

The current performance model averages the named required stats and maps the result to S/A/B/C/D multiplier tiers. `required_stats` are used as performance references; the manager checks for the presence of those stats rather than enforcing their listed numbers as hiring thresholds.

The approved roster contains Auto Service, Bank, Cafe, Cruise, Factory, Gym, Hospital, Hotel, Restaurant, Stadium, Tech Company, and Warehouse. Bookshop is not a type. Auto Service, Cruise, and Hotel use the same complete, generic five-level lifecycle as every other type; there is no `configuration_status` gate.

`map_visual_path` and `modal_visual_path` are independent static type-definition fields. Neither path falls back to the other, and neither depends on business level. A missing modal asset remains a valid configured path and is handled safely by the UI.

### Runtime family-business instance

```text
{
  business_instance_id: String,  # generated as business_0001, ...
  business_type_id: String,
  plot_id: String,
  level: int,
  slots: [{
    slot_id: String,
    assigned_character_id: int | null,
    assigned_npc_id: String | null
  }]
}
```

A slot may reference either a family character or a Worker NPC. Manager logic prevents both occupant fields from representing simultaneous occupants.

Runtime instances do not duplicate visual state. Map and modal paths are always resolved from the static type definition through `business_type_id`.

### Map authoring state

The production Map currently stores manually authored TileMapLayer cells, TileSet subresources, and building sprite placement directly in `UI/Map.tscn`. No `Map.json` static layout schema is loaded or present, and no map placement data is generated at runtime. The fixed `6200 x 4200` world boundary, camera settings, and screen-activation state are scene/script infrastructure rather than gameplay save data. Reusable property/tag helpers do not define active runtime records until authored content is connected to them in a later task.

The approved roster removes Bookshop from static type data. A pre-existing save that already contains a Bookshop instance has no confirmed conversion target in GDD v3.5; the loader therefore does not silently convert it to another business or delete purchased state. Such a legacy instance remains unsupported/orphaned until a migration policy is confirmed.

## Career and Education Definitions

- Job: `{ job_id: int, job_name: String, required_major_id: int | null, required_stats: Dictionary, base_salary: int }`.
- Major: `{ major_id: int, major_name: String, required_stats: Dictionary, duration_years: int, is_fallback?: bool }`.
- Company: `{ company_id: String, company_name: String, logo_path: String, jobs: int[] }`.
- School: `{ school_id: int, school_name: String, education_stage: String, school_type: String, icon_path: String, base_cost: int, stat_bonus: Dictionary }`.

Education queue records observed in `EducationManager` use `character_id`, `event_type`, and `education_stage`; selections and logs can also carry `school_id`, `major_id`, and `date`.

## Item Catalog and Runtime Item State

Each generated `ItemCatalog.json` definition has this shape:

```text
{
  id: String,
  display_name: String,
  slot: "accessory" | "outfit" | "vehicle",
  rarity: "common" | "uncommon" | "rare" | "epic" | "legendary",
  image_path: String,
  is_heirloom: bool,
  lifestyle_value: int,
  durability_months: int,
  money_price: int,
  diamond_price: int
}
```

The slot and rarity come from resource folders. Heirloom comes from the canonical filename marker. Accessory Ring/Glasses/Watch/Necklace is classified at UI/helper level and is not a persistent schema field. Lifestyle and normal-item durability are deterministically generated within confirmed GDD bands. Heirlooms have `durability_months = 0`. Money and Diamond prices are deterministically generated from GDD v3.4 D-127, and the catalog root records `pricing_status: "configured_gdd_v3_4"`.

Purchased family inventory entries are references to definitions rather than full copies:

```text
{
  instance_id: String,
  item_id: String,
  purchase_date: YYYY-MM-DD,
  expiration_date?: YYYY-MM-DD
}
```

Normal instances receive `expiration_date = purchase_date + durability_months` in game-calendar months. Heirlooms omit `expiration_date`. `ItemManager.equipped_assignments` is keyed by character ID and then slot; family inventory itself is shared. An ItemInstance may appear in at most one character assignment. Equipped items remain in `family_inventory`; the player-facing Owned list is a runtime projection that excludes every family-wide equipped `instance_id`. The projection does not compare `item_id`, so another instance of the same catalog definition remains available. `monthly_stock_by_slot` contains separate `accessory`, `outfit`, and `vehicle` arrays of at most six distinct catalog IDs, accompanied by one `monthly_stock_month_key` and configurable `monthly_stock_target_per_slot`.

## House Data

`House.json` keeps immutable production definitions separate from mutable ownership. Its single current `family_house` definition contains `starting_property_id`, `map_visual_path`, `modal_visual_path`, five `levels`, four `roles`, a House-specific `performance_model`, `household_score`, and the five `status_thresholds`. Level 1 stores the ready-made purchase price; Levels 2–5 store the price required to enter that level. New construction resolves the Level 1 base price through `EconomyManager`'s shared 1.40 multiplier.

Runtime House records are owned by `HouseManager`:

```text
{
  house_instance_id: String,       # house_0001, ...
  house_definition_id: String,     # family_house
  property_id: String,             # authored Map property, e.g. house_01
  level: int,
  role_assignments: {
    head_of_household, cook, housekeeper, caregiver: int | null
  },
  resident_character_ids: int[]
}
```

Role occupants and resident IDs share one capacity and are normalized to one assignment per Character during save restoration. Performance tier, Household Score/Status, occupancy, expense, and active perks are derived rather than persisted.

`HouseholdPerks.json` currently defines `artistic`, matched by any of the existing `musician` (`1002`) or `painter` (`1003`) flags. UI reads display labels while future event code can query canonical perk IDs.

## Save Snapshot Version 5

`SaveManager` writes JSON files named `save_<id>.json` under `user://saves`. The snapshot root is:

```text
save_version: 5
metadata: { family_name, wealth, population, owned_businesses, game_date }
game_manager: {
  lifespan_setting,
  allow_same_sex_marriage,
  allow_distant_relative_marriage,
  allow_ex_spouse_remarriage,
  family_money, diamonds, family_name
}
time_manager: {
  current_day, current_month, current_year,
  is_paused, speed_multiplier, day_timer
}
character_manager: { characters, next_character_id }
house_manager: {
  houses,
  next_house_instance_number,
  last_unhoused_penalty_date
}
business_manager: { businesses, next_business_instance_number }
npc_manager: {
  worker_npcs, next_worker_npc_number,
  months_until_next_generation, last_processed_month_key
}
relationship_manager: { relationship_candidate_ids }
career_manager: { active_job_offers }
economy_manager: {
  last_external_salary_payment_date,
  last_family_business_payment_date,
  last_family_business_breakdown,
  last_house_payment_date,
  last_house_expense
}
education_manager: {
  education_event_queue, current_education_event,
  is_education_event_active, is_education_pause_active,
  should_resume_time_after_education_events
}
item_manager: {
  family_inventory,
  equipped_assignments,
  monthly_stock_by_slot: {
    accessory: item_id[],
    outfit: item_id[],
    vehicle: item_id[]
  },
  monthly_stock_month_key,
  monthly_stock_target_per_slot,
  next_instance_number
}
```

The loader requires the House section for version 5. Versions 2–4 remain supported; when House state is absent, the lowest-ID living playable family Character becomes Head of Household in deterministic `house_01`. Version 2 keeps its empty item-state migration, and Version 3 global `monthly_stock_ids` are still distributed into canonical slot arrays.

## Identifier and Relationship Conventions

| Concept | Identifier/link |
| --- | --- |
| Character and Relationship NPC | Positive integer `character_id` |
| Worker NPC | String `id` with `npc_` prefix |
| Family business instance | String `business_instance_id` with `business_` prefix |
| Family House instance | String `house_instance_id` with `house_` prefix |
| House map property | Stable String `property_id`, currently `house_01` through `house_10` |
| Business type | String `business_type_id` |
| Business plot | String `plot_id` |
| External company | String `company_id` |
| Job, major, school | Integer ID |
| Item definition | Stable string `id` derived from the canonical PNG filename stem |
| Item instance | String `instance_id` with `item_` prefix |
| Parent/child relationships | `parent_ids` and `children_ids` integer arrays |
| Current partner | Nullable integer `partner_id` |

Do not interchange Worker NPC IDs with character IDs, and do not interchange family-business identifiers with external company identifiers.
