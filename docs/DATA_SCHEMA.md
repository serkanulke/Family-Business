# Family Business Data Schema

**Repository baseline audited:** `main` at `d22047481c4c0f15161b197ae2dda881bc99b54a`  
**Gameplay authority:** canonical GDD v3.8  
**Purpose:** document current static/runtime/save data ownership. This file is descriptive of repository reality and does not invent schema.

## 1. Data Ownership Rules

- GDD owns approved gameplay behavior and design values.
- Domain JSON owns static definitions/config assigned to that domain.
- Managers own mutable runtime state.
- SaveManager serializes mutable state.
- Event JSON must not duplicate canonical School/Job/Company/House/Business/Item values.
- A legacy JSON file is not authoritative merely because it exists.

## 2. Static JSON Catalog

| File | Current role |
| --- | --- |
| `Character.json` | Empty seed collection loaded by CharacterManager; runtime Characters are manager/save state. |
| `Major.json` | Canonical major definitions. |
| `Job.json` | Canonical external Job definitions and base salaries; optional deliberate `event_tags` may be added when approved. |
| `School.json` | Canonical school definitions. `base_cost` is the base enrollment price, not the final time-adjusted price once Economy Index integration is restored. |
| `Companies.json` | Canonical external Company identity and Job mapping. |
| `Business.json` | Empty seed collection; runtime owned family businesses are manager/save state. |
| `BusinessTypes.json` | Canonical 12 family-business type definitions, five levels, slots, performance, fixed expenses, map/modal visual paths. |
| `House.json` | Canonical House definition, five levels, roles, costs/capacity/expenses, score/status rules. |
| `HouseholdPerks.json` | Canonical mapping from existing Character flags to household perk IDs/display labels. |
| `Flag.json` | Canonical flag catalog. |
| `ItemCatalog.json` | Stable generated Item definitions used by ItemManager. |
| `npc.json` | Active Worker NPC generation config, names, and portrait paths. |
| `relationship_npc.json` | Active Relationship candidate generation config and names. |
| `GameData.json` | **Legacy/stale and currently unconsumed.** Intended config purpose is valid, but current schema mixes mutable runtime state with config and contains stale values. Do not reconnect as-is. |
| `Avatar.json` | **Legacy/stale and currently unconsumed.** Represents an older avatar-theme schema incompatible with current portrait selection. |
| `RelationshipNPC.json` | **Legacy/stale empty uppercase collection with no current consumer.** |
| `Events/*.json` | Current Event category definitions loaded by EventDataRegistry. |

### Planned cleanup, not yet implemented

- Shared `Names.json` should eventually remove duplicated first-name data from `npc.json` and `relationship_npc.json`, with both consumers/tests migrated in one bounded change.
- GameData/config migration must be redesigned before reconnecting.
- Avatar theme data must be redesigned against the current portrait system when that product work is implemented.

## 3. Character Records

`CharacterManager.characters` stores player-family Characters and external Relationship candidates.

Core fields include:

```text
character_id
first_name
gender
birth_date
life_stage
is_alive
death_date
is_retired
last_salary
pension
is_player_family
parent_ids
partner_id
children_ids
is_adopted
school_id
major_id
education_status
education_start_date
major_selection_date
expected_graduation_date
graduation_date
job_id
company_id
salary
unemployment_start_date
job_offer_cooldown_until
health
happiness
logic
attractiveness
social
confidence
discipline
creativity
flag_ids
event_log
genetics.skin_tone
portrait_variant_id
portrait_path
avatar_theme
```

Relationship candidates additionally use current relationship fields such as:

```text
character_type = "relationship_npc"
linked_character_id
relationship_status
relationship_cooldown_until
```

Age is derived from `birth_date`; it is not a mutable stored age field.

Current active visual genetics are only `skin_tone` (`light`, `mixed`, `dark`). Hair/Eye genetics are deferred.

## 4. Worker NPC Records

Worker NPCs are separate lightweight records owned by `NPCManager`:

```text
{
  id,
  first_name,
  last_name,
  gender,
  birth_date,
  portrait_path,
  stats: {
    health,
    logic,
    discipline,
    creativity,
    social,
    confidence,
    attractiveness,
    happiness
  },
  is_retired
}
```

Do not convert Worker NPCs into full Characters merely for Event convenience.

## 5. Business Definitions and Instances

### `BusinessTypes.json`

Each type contains:

```text
business_type_id
display_name
max_level
map_visual_path
modal_visual_path
slot_definitions[]
levels[]
```

`slot_definitions[]` contain:

```text
slot_id
role_name
unlock_level
base_gross_contribution
required_stats
```

`levels[]` contain:

```text
level
cost
fixed_monthly_expense
slot_ids[]
```

The approved type roster is exactly:

Cafe, Gym, Restaurant, Warehouse, Factory, Hospital, Tech Company, Bank, Stadium, Auto Service, Cruise, Hotel.

Business visuals do not vary by level.

### Runtime instance

```text
{
  business_instance_id,
  business_type_id,
  plot_id,
  level,
  slots: [
    {
      slot_id,
      assigned_character_id,
      assigned_npc_id
    }
  ]
}
```

No runtime visual variant is stored.

## 6. House Runtime Records

HouseManager owns:

```text
{
  house_instance_id,
  house_definition_id,
  property_id,
  level,
  role_assignments: {
    head_of_household,
    cook,
    housekeeper,
    caregiver
  },
  resident_character_ids
}
```

Household Score/Status, role performance, occupancy, current expense, and perks are derived from canonical state.

## 7. Item Definitions and ItemInstances

### Static item definition

```text
{
  id,
  display_name,
  slot,
  rarity,
  image_path,
  is_heirloom,
  lifestyle_value,
  durability_months,
  money_price,
  diamond_price
}
```

### Runtime ItemInstance

```text
{
  instance_id,
  item_id,
  purchase_date,
  expiration_date?
}
```

Normal items expire by calendar date. Heirlooms have no expiration date. Equipped assignments reference ItemInstances; family inventory remains shared.

## 8. Event Category Root

Every Event category file uses:

```text
{
  schema_version: 1,
  category: String,
  pools: PoolDefinition[],
  events: EventDefinition[]
}
```

Current category files:

```text
relationship
education
job_offer
career
household
lifestyle
family_agency
age_lifecycle
business
health
finance
general
```

### PoolDefinition

Base pool contract:

```text
{
  pool_id: String,
  selection_mode: "weighted_one" | "weighted_multiple" | "all_eligible",
  max_events?: int,
  selection_scope?: "save",
  activation_chance?: number
}
```

For ordinary save-scoped random pacing:

- `selection_scope` must be `"save"`.
- `activation_chance` is 0..1.
- `max_events` must be explicit and positive.
- `weight` on Events is relative candidate-selection weight only.

Factual/system Events are not required to use save-scoped random pools.

### EventDefinition

The validator supports the current shared contract:

```text
event_id
category
domain
subtype
enabled
rarity
weight
priority
exclusive_group
pool_id
trigger
participants
requirements
repeat
cooldown
behavior
content
presentation
cost
choices
default_resolution
metadata
```

The Event Authoring Guide is authoritative for full field-level authoring rules.

## 9. Event Runtime Structures

`EventInstance` stores runtime identity and bindings, not duplicated display definitions:

```text
instance_id
event_id
definition_version
trigger_type
created_date
started_date
completed_date
status
participants
context
choice_id
outcome_id
effect_results
source_instance_id
```

EventManager also persists:

- active/queued Event instances
- scheduled Events
- story history
- repeat records
- cooldown records
- deterministic counters/RNG state
- occurrence/selection ledgers
- pause ownership/runtime state

## 10. Event Presentation Tokens

`EventPresentationResolver` currently supports these player-facing content tags:

```text
{character_name}
{job}
{company_name}
{salary}
```

They resolve from bound participants/context and canonical managers. Unknown/unresolved tags remain unchanged so authoring errors are visible.

Do not duplicate Job/Company/Character names into one Event per Job.

## 11. Production Event Data

Current production Event content:

- `education.json`: 5 core factual Education Events.
- `age_lifecycle.json`: 2 factual Events — Retirement and Farewell.
- `job_offer.json`: 1 generic factual external Job Offer Event.
- `career.json` and remaining categories: no production content yet.

## 12. Economy Index / GameData Status

GDD v3.8 defines Economy Index as a DECIDED time-based multiplier for applicable Money expenses. School enrollment is explicitly included; House/Land/Business acquisition and House/Business upgrades are explicitly excluded.

Current repository state:

- `GameData.json` contains `economy_index` and `economy_growth_rate`, but no runtime code consumes them.
- Current `EconomyManager` does not calculate or advance Economy Index.
- Current `EducationManager` reads/spends `School.json.base_cost` directly.

Therefore Economy Index is an **implementation gap**, not an unused design.

Do not use the old `GameData.json` fields as the new schema automatically. The current file also contains mutable/stale fields (`current_date`, `family_money`, next IDs, obsolete pool size) that must remain outside static gameplay configuration.

## 13. Save Data

SaveManager currently uses save version 6 and serializes manager-owned mutable state plus one `event_system` payload.

Important ownership rule: static config must not store current date, current Money, current runtime IDs, assignments, or active Event instances.

Any future config migration must keep save/runtime state separate from static defaults/tuning values.
