# Family Business Data Schema

## Scope

This document records schemas observed in the current JSON files, manager-created runtime dictionaries, and save snapshots. It is descriptive, not a replacement for the canonical GDD. Optional and nullable fields are shown where the implementation explicitly permits them.

## Static JSON Catalog

| File | Root shape | Current code usage |
| --- | --- | --- |
| `Character.json` | `{ "characters": [] }` | Loaded by `CharacterManager`; currently an empty seed collection. Runtime changes remain in memory/save data. |
| `Major.json` | `majors[]` (16 records) | Loaded by `CharacterManager`. |
| `Job.json` | `jobs[]` (88 records) | Loaded by `CharacterManager`. |
| `School.json` | `schools[]` (12 records) | Loaded by `EducationManager`. |
| `Companies.json` | `companies[]` (90 records) | Loaded by `CareerManager`. |
| `Business.json` | `{ "businesses": [] }` | Loaded by `BusinessManager`; currently an empty seed collection. Runtime changes remain in memory/save data. |
| `BusinessTypes.json` | `performance_model` plus `business_types[]` (12 approved types) | Loaded by `BusinessManager`; all 12 types contain complete five-level economy and slot definitions. |
| `npc.json` | `generation`, `names`, and `portraits` | Loaded by `NPCManager` for Worker NPCs. |
| `relationship_npc.json` | `generation` and `names` | Loaded by `RelationshipNpcManager`. |
| `ItemCatalog.json` | `catalog_version`, `pricing_status`, and `items[]` (261 generated definitions) | Generated explicitly from existing PNG paths and loaded by `ItemManager`; it is stable source data and is not regenerated when the shop opens. |
| `Avatar.json` | `themes[]` (1 record) | No code or scene reference found. Character portraits are currently resolved by `CharacterManager` from resource folders/paths. |
| `Flag.json` | `flags[]` (30 records) | No code or scene reference found. Character records do contain `flag_ids`. |
| `GameData.json` | `game` object | No code or scene reference found. |
| `House.json` | `houses[]` (1 record) | No code or scene reference found. |
| `RelationshipNPC.json` | `{ "relationship_npcs": [] }` | No code or scene reference found; active relationship candidates are full character records. |

Filename case matters in the current repository: both `relationship_npc.json` and `RelationshipNPC.json` exist and have different roles/statuses.

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

## Save Snapshot Version 4

`SaveManager` writes JSON files named `save_<id>.json` under `user://saves`. The snapshot root is:

```text
save_version: 4
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
  last_family_business_breakdown
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

The loader requires all version 4 manager sections. Version 2 snapshots remain supported with an empty item-state migration. Version 3 snapshots are also supported: their former global `monthly_stock_ids` array is distributed into canonical slot arrays using catalog definitions, without changing the referenced item IDs.

## Identifier and Relationship Conventions

| Concept | Identifier/link |
| --- | --- |
| Character and Relationship NPC | Positive integer `character_id` |
| Worker NPC | String `id` with `npc_` prefix |
| Family business instance | String `business_instance_id` with `business_` prefix |
| Business type | String `business_type_id` |
| Business plot | String `plot_id` |
| External company | String `company_id` |
| Job, major, school | Integer ID |
| Item definition | Stable string `id` derived from the canonical PNG filename stem |
| Item instance | String `instance_id` with `item_` prefix |
| Parent/child relationships | `parent_ids` and `children_ids` integer arrays |
| Current partner | Nullable integer `partner_id` |

Do not interchange Worker NPC IDs with character IDs, and do not interchange family-business identifiers with external company identifiers.
