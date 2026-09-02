# Family Business Event System Specification

## Status and Authority

- Status: **APPROVED DESIGN / NOT YET IMPLEMENTED**
- Confirmed: 2026-09-01
- Canonical gameplay authority: Google Docs GDD, Section 14 and Decisions D-147 through D-153.
- This file is the detailed technical contract for the approved Event System. It does not claim that the repository already implements these structures.
- `docs/DATA_SCHEMA.md`, `docs/ARCHITECTURE.md`, and `docs/DEVELOPMENT_STATUS.md` remain descriptive of implemented repository state and must be updated phase by phase as this specification becomes real code/data.

The Event System is not considered complete until every approved backend and player-facing behavior in this specification is implemented, integrated, saved/restored, validated, and tested. Work may be split into bounded phases, but unfinished approved scope must remain explicitly tracked rather than silently deferred.

## 1. Static Event Data Layout

Replace the former single-file `event.json` direction with category files under:

```text
Resources/Json/Events/
  relationship.json
  education.json
  job_offer.json
  career.json
  household.json
  lifestyle.json
  family_agency.json
  age_lifecycle.json
  business.json
  health.json
  finance.json
  general.json
```

Every category file uses the same root contract:

```text
{
  schema_version: int,
  category: String,
  pools: PoolDefinition[],
  events: EventDefinition[]
}
```

Category files may initially contain no production Events, but the shared schema and validation rules are identical across categories.

### Classification boundaries

These are separate concepts and must not be conflated:

- `category`: which Event content family/file owns the definition.
- `domain`: which gameplay system the Event principally concerns or changes.
- `trigger`: why/when the Event is evaluated or started.
- `presentation.template`: which approved Event UI template/scene renders it.

A `family_agency` Event may therefore have `domain: relationship` or `domain: business`. A Relationship Event may use more than one presentation template. UI template choice must never be inferred only from category.

## 2. Event Definition

Approved top-level shape:

```text
EventDefinition {
  event_id: String,
  category: String,
  domain: String,
  subtype: String,
  enabled: bool,

  rarity: "common" | "uncommon" | "rare" | "epic" | "legendary",
  weight: number,
  priority: int,
  exclusive_group: String | null,

  trigger: TriggerDefinition,
  participants: Dictionary,
  requirements: RequirementGroup,

  repeat: RepeatDefinition,
  cooldown: CooldownDefinition | null,

  behavior: {
    blocking: bool,
    pause_game: bool
  },

  content: {
    title: String,
    description: String,
    subtitle?: String | null
  },

  presentation: {
    template: String,
    art_path?: String | null,
    header_icon?: String | null
  },

  cost?: CostDefinition | null,
  choices: ChoiceDefinition[],
  default_resolution?: ResolutionDefinition | null,
  metadata?: Dictionary
}
```

`event_id` is globally unique and persistent. It must not be regenerated because display copy, art, or balance values change.

Presentation data may contain content/resource references, but must not contain scene geometry such as font sizes, padding, margins, corner radii, card dimensions, or modal positions. Approved UI references/scenes own those values.

Dynamic text may resolve approved placeholders such as:

```text
{primary.first_name}
{primary.last_name}
{target.first_name}
{context.name}
```

## 3. Pools and Selection

Category roots may define named pools:

```text
PoolDefinition {
  pool_id: String,
  selection_mode: "weighted_one" | "weighted_multiple" | "all_eligible",
  max_events?: int | null
}
```

Selection rules:

- `weight` affects selection among eligible Event definitions in the relevant pool/exclusive selection.
- `exclusive_group` identifies mutually exclusive variants; only one eligible definition from the same exclusive group may be selected for the same trigger occurrence/context.
- `priority` controls queue order after eligibility/selection, not probability.
- Deterministic/system Events are not discarded merely because several become due together. All eligible selected deterministic Events may enter the queue and resolve by priority.

## 4. Trigger Model

Supported trigger families are exactly:

```text
system
calendar
manual
chain
scheduled
```

### 4.1 System

System triggers react to semantic gameplay occurrences rather than raw Godot signal names.

```text
trigger: {
  type: "system",
  event: String,
  parameters?: Dictionary
}
```

Examples of semantic events include:

```text
character_born
age_reached
life_stage_changed
character_died
education_stage_due
school_enrolled
school_graduated
job_started
job_changed
job_lost
retired
relationship_started
relationship_changed
relationship_ended
house_assignment_changed
character_became_unhoused
house_upgraded
business_purchased
business_upgraded
business_role_changed
```

EventManager/adapters map existing manager signals/state changes to these semantic names. Static JSON does not depend on a literal signal path such as `CharacterManager.character_died`.

### 4.2 Calendar

Calendar cadence belongs to the Event definition; EventManager must not hardcode a frequency by category.

```text
trigger: {
  type: "calendar",
  cadence: {
    unit: "day" | "week" | "month" | "year",
    interval: int
  },
  pool_id?: String | null
}
```

The schema must also support exact annual dates and approved calendar/month windows. All calendar math uses `TimeManager`'s real game calendar rather than treating one month as a fixed 30-day duration.

### 4.3 Manual

```text
trigger: {
  type: "manual",
  source: "relationship" | "lifestyle" | "family_agency" | String,
  mode: "direct" | "pool",
  pool_id?: String | null
}
```

- `direct`: the player chooses the visible Event itself.
- `pool`: the player chooses an action and EventManager chooses from the eligible pool.

Lifestyle and Family Agency are manual flows. A Relationship action such as Meet Someone may also be manual/pool-based.

### 4.4 Chain

```text
trigger: { type: "chain" }
```

A chain-only Event does not enter ordinary calendar/manual discovery pools. It starts only because another Event result queues it.

### 4.5 Scheduled

```text
trigger: { type: "scheduled" }
```

A scheduled Event is created for a future date by an Event effect. Its participants/context and source instance are persisted. It is fully revalidated on the due date.

## 5. Participant Model

Participants belong to runtime Event context. Static definitions describe how they are resolved.

Approved participant concepts include:

```text
primary
target
secondary
context
named character groups
```

A participant may be sourced from:

```text
trigger
player_selected
relation (spouse / child / parent / other approved relation)
relationship NPC generation/pool
primary House assignment
owned Business
other resolved Event context
```

Examples:

```text
primary: {
  type: "character",
  source: "trigger"
}
```

```text
target: {
  type: "character",
  source: "relation",
  relation: "spouse",
  from: "primary"
}
```

```text
context: {
  type: "business",
  source: "owned_business",
  requirements: RequirementGroup
}
```

### Player-selected groups

An Event may require an exact or ranged number of family participants:

```text
travel_group: {
  type: "character_group",
  source: "player_selected",
  min: 5,
  max: 5,
  requirements: RequirementGroup,
  selection_ui: {
    title: String,
    description: String,
    show_ineligible: bool,
    show_relevant_stats?: String[]
  }
}
```

The player stays in the current Event/Family Agency context. Selection uses a dedicated modal/bottom sheet; Family Tree must not be converted into a temporary multi-select mode.

Ineligible Characters may remain visible in disabled form when configured, with reasons produced from the common requirement evaluator. The selection UI must not duplicate eligibility logic.

Participant/context validity and all requirements are checked again immediately before Event activation. Scheduled Events repeat this validation when due. A scheduled Event whose required participant/context is no longer valid becomes `expired` rather than executing stale effects.

## 6. Requirement Language

All categories share one recursive evaluator:

```text
RequirementGroup {
  all?: (Requirement | RequirementGroup)[],
  any?: (Requirement | RequirementGroup)[],
  none?: (Requirement | RequirementGroup)[]
}
```

Requirements may target a resolved participant/context. Supported requirement families are:

### Character

```text
stat
flag
age
life_stage
gender
is_alive
is_family_member
```

### Family structure

```text
has_child
has_parent
has_spouse
family_member_count
```

### Career

```text
employment_status
job
job_tag
```

There is no Career Level requirement. External career eligibility uses the implemented employment, Job, and deliberately authored Job-tag state.

### Education

```text
education_stage
school
school_type
major
```

There is no numeric Education Level requirement.

Generic pair-level Relationship requirements are not supported. Existing spouse/family links use `has_spouse` and the participant/context model; Relationship-candidate context is resolved as a participant rather than an invented relationship meter or status requirement.

### Lifestyle / Items

```text
lifestyle_score
equipped_item
item_type
item_rarity
item_flag
```

`lifestyle_score` always reads the exact hidden 0-100 backend score. Stars/class/level labels are presentation-only and never satisfy an Event requirement.

### Economy

```text
money
diamonds
```

### House

```text
house_assignment
house_level
household_status
household_perk
```

### Family Business

```text
business_owned
business_type
business_level
business_role
```

### Event story memory

```text
event_seen
event_completed
event_not_completed
choice_made
outcome_reached
```

### Ownership / Monetization

```text
entitlement
```

### World / Time

```text
date
year
month
```

General operators, where meaningful for the requirement type:

```text
==
!=
>
>=
<
<=
in
not_in
contains
not_contains
```

Validator rules determine which operators are valid for each requirement type.

### Job event tags

`Job.json` may add:

```text
event_tags: String[]
```

This supports career-specific Events without maintaining large job-ID lists. Examples of useful concepts include `artist`, `visual_art`, `performer`, `music`, and `medical`, but exact tag assignment for every job must be deliberately authored/approved rather than inferred automatically by UI or EventManager.

## 7. Repeat and Cooldown

Repeat and cooldown are independent.

```text
RepeatDefinition {
  mode: "once" |
        "once_per_character" |
        "once_per_character_pair" |
        "once_per_family" |
        "once_per_house" |
        "once_per_business" |
        "repeatable"
}
```

```text
CooldownDefinition {
  scope: "event" |
         "character" |
         "character_pair" |
         "family" |
         "house" |
         "business",
  unit: "day" | "week" | "month" | "year",
  value: int
}
```

Cooldown uses the real game calendar.

Approved special rules:

- A manual Meet Someone relationship Event may define a 1-calendar-month `character` cooldown in Event data. The duration is not hardcoded into EventManager.
- Attend Gala uses `family` scope and 12 calendar months.
- Family Agency cooldown is **not global**. Every Family Agency Event/option locks only itself with `scope: event`.
- Every Family Agency Event must have a cooldown equivalent to at least 60 calendar months. Longer periods such as 120, 240, or 360 months are valid.
- Currency balance or entitlement ownership never bypasses cooldown.

## 8. Choices and Costs

```text
ChoiceDefinition {
  choice_id: String,
  title: String,
  description?: String,
  icon_path?: String | null,
  requirements?: RequirementGroup,
  cost?: CostDefinition | null,
  resolution: ResolutionDefinition
}
```

```text
CostDefinition {
  currency: "money" | "diamonds",
  amount: number
}
```

Choice requirements are separate from Event-level requirements. A locked choice may remain visible when the approved presentation calls for it, with player-readable requirement reasons generated by the evaluator.

For manual Events that require participant selection, cost is not committed when the selector opens. Cost/consumable use, cooldown start, and completed history are committed only after final participant selection, final revalidation, and confirmation. Cancelling selection performs none of these changes.

## 9. Resolution and Outcomes

Supported modes:

```text
deterministic
weighted
score_check
```

### Deterministic

Always applies the authored result/effects when selected and valid.

### Weighted

Contains multiple outcomes with authored weights. Outcomes may contain requirement-based weight modifiers.

```text
OutcomeDefinition {
  outcome_id: String,
  weight: number,
  weight_modifiers?: [{
    requirements: RequirementGroup,
    add_weight: number
  }],
  effects: EffectDefinition[]
}
```

### Score check

May combine approved numeric sources, such as Character stats, using authored weights and a threshold. It is a deterministic score comparison; use `weighted` when authored randomness is desired.

## 10. Effects

Event JSON never stores executable code. Effects are whitelist-based structured operations resolved by Event System code and delegated to authoritative domain managers.

Supported effect families:

### Character

```text
stat_change
stat_set
add_flag
remove_flag
```

`add_flag` may include an optional real-calendar duration. No duration means permanent; a duration creates temporary story/status state. This does not by itself resolve the broader GDD-open taxonomy between personality traits, temporary statuses, chain flags, and global family flags.

### Relationship

```text
relationship_marry
relationship_divorce
```

`relationship_marry` delegates to `RelationshipNpcManager.make_candidate_family_member`; `relationship_divorce` delegates to `RelationshipNpcManager.divorce_characters`. The generic start/change/status/end operations do not exist. Pre-marriage narrative progression uses Event participants, choices, outcomes, history, chains, and scheduling without pair-level persistent state.

### Economy

```text
money_change
diamond_change
```

### Career

```text
accept_job_offer
reject_job_offer
job_remove
salary_increase
```

Offer acceptance/rejection delegates to `CareerManager`'s active-offer flow and never authors a Job, company, or salary. `job_remove` clears external employment only. `salary_increase` requires a positive integer amount and changes only the current external salary while preserving Job and company. There is no Career Level or generic progression state.

### Education

```text
education_enroll
```

Enrollment delegates to the current `EducationManager` event/enrollment flow. School transfer/change, dropout, Event-driven instant graduation, and Education Level are not supported; graduation remains calendar-owned by `EducationManager`.

### Items

```text
add_item
remove_item
equip_item
unequip_item
```

Under D-155, static Event definitions identify Items by catalog `item_id` plus the target Character; save-specific `ItemInstance.instance_id` values never appear in Event JSON. `add_item` creates a new instance through `ItemManager`, with the normal calendar-expiration rules and permanent Family Heirloom behavior. There is no `damage_item` effect because Item durability has no separate damage-point mechanic.

`equip_item` may select only a matching family-owned instance that is not equipped by another Character. `unequip_item` affects only a matching instance equipped by the target Character. `remove_item` first prefers the target Character's matching equipped instance, otherwise an unequipped matching instance; it never takes or removes an instance equipped by another Character. Multiple eligible instances are resolved deterministically by nearest `expiration_date`, then oldest `purchase_date`, then ascending `instance_id`, with non-expiring instances ordered after expiring instances. If no eligible instance exists, the effect fails with an `EffectResult`.

### House

```text
remove_from_house
```

House assignment remains a valid read-only requirement, but is not an Event effect. Events never automatically relocate a Character or assign a House role.

### Family Business

```text
business_upgrade
```

There is no generic `business_effect` or `business_role_change`. Under D-154/D-157, family-business staffing remains player-controlled; `business_upgrade` is the only current Business-specific Event mutation. Any future mutation requires a separately named and approved payload, authoritative `BusinessManager` operation, validation contract, and `EffectResult` behavior.

### Event flow

```text
queue_event
schedule_event
cancel_scheduled_event
```

A scheduled effect may define a real-calendar delay and whether participant/context bindings are inherited from the source Event instance.

### Domain-source-of-truth rule

EventManager must not duplicate another manager's gameplay rules. Examples:

- `education_enroll` delegates to EducationManager; `School.json` remains authoritative for school cost and `stat_bonus`.
- Character stat clamping remains CharacterManager/domain logic.
- Relationship marriage/divorce uses `RelationshipNpcManager`; Event code never writes partner/family-entry/divorce state directly.
- External career effects delegate to `CareerManager` and never mutate family-business staffing.
- House removal delegates to `HouseManager`; Event code does not assign Houses.
- Business upgrades delegate to `BusinessManager`; Event code never assigns or removes workers.
- Item ownership/equipment/durability remains ItemManager-owned.

## 11. Player-Facing Effect Results

Every applied gameplay effect produces a runtime `EffectResult` for presentation.

Example:

```text
EffectResult {
  effect_type: "stat_change",
  target_character_id: int,
  requested_amount: 5,
  applied_amount: 2,
  display: {
    text: "Emma gained +2 Health",
    icon_path: "res://Resources/Icons/stats/health.svg"
  }
}
```

Feedback uses the actual applied result after canonical validation/clamping. If Health is 98 and an Event requests +5, the player sees +2 Health, not +5.

Feedback modes:

```text
auto
custom
```

Static effects may use `feedback: { mode: "auto" | "custom", text?: String, icon_path?: String | null }`. Custom feedback requires non-empty player-facing text. The runtime stores only the resolved display payload in `EffectResult`; it does not copy internal flag IDs into player-facing text.

Internal technical flag IDs are not exposed to players. Hidden/story flags use appropriate custom narrative feedback when the effect must be communicated.

There are no intentionally silent gameplay effects in the approved Event flow. Technical bookkeeping that is not itself gameplay state is not an effect.

## 12. Runtime Event Instance and Story History

Static `EventDefinition` and runtime `EventInstance` are separate.

```text
EventInstance {
  instance_id: String,             # e.g. evt_00000412
  event_id: String,
  definition_version: int,
  trigger_type: String,
  created_date: YYYY-MM-DD,
  started_date?: YYYY-MM-DD | null,
  completed_date?: YYYY-MM-DD | null,
  status: "queued" | "active" | "completed" | "cancelled" | "expired",
  participants: Dictionary,
  context?: Dictionary | String | null,
  choice_id?: String | null,
  outcome_id?: String | null,
  effect_results?: EffectResult[],
  source_instance_id?: String | null
}
```

History is persistent story memory, not only a `completed` boolean. It must preserve enough stable identifiers/context to answer future requirements such as:

- Did this Character see/complete this Event?
- Which choice was made?
- Which outcome occurred?
- Did these two Characters experience the Event together?
- Which House/Business provided the Event context?
- Which prior Event instance created this chain?

History stores IDs and state, not duplicated display copy.

## 13. Scheduled Event State

```text
ScheduledEvent {
  scheduled_event_id: String,      # e.g. sched_00031
  event_id: String,
  due_date: YYYY-MM-DD,
  participants: Dictionary,
  context?: Dictionary | String | null,
  source_instance_id?: String | null
}
```

When due:

1. Load the current Event definition.
2. Confirm it is still enabled/valid.
3. Resolve/check persisted participants/context.
4. Re-evaluate requirements, repeat/history, and any applicable validity rule.
5. Queue it when valid; otherwise record/mark it `expired` without applying effects.

## 14. Cooldown Runtime State

Cooldown records must preserve enough scope identity to restore exact availability after save/load.

```text
CooldownState {
  event_id: String,
  scope: String,
  scope_key: String,
  started_date: YYYY-MM-DD,
  available_date: YYYY-MM-DD
}
```

Example scope keys may represent one Character, a normalized Character pair, family, House, Business, or Event-level access. Pair keys must be normalized so A+B and B+A cannot create separate cooldowns.

## 15. Queue and Pause Contract

Runtime Event state conceptually owns:

```text
active_event
queued_events[]
scheduled_events[]
history[]
cooldowns[]
```

Rules:

- Only one blocking Event may be active/presented at a time.
- Additional blocking Events remain queued by priority/order.
- The blocking queue preserves the time state that existed before the first blocking Event.
- Time does not resume between consecutive blocking Events.
- The prior running/speed state is restored only after the blocking queue is empty.
- Duplicate queue entries for the same Event + participants + context + trigger occurrence are rejected.
- Event UI listens to EventManager state/signals; EventManager must not directly manipulate specific UI nodes.

## 16. Manual Discovery

Lifestyle and Family Agency screens query EventManager for currently visible/available manual Events. Those screens do not reimplement requirements/cooldowns.

EventManager should return a player-facing availability result capable of distinguishing, as applicable:

```text
available
locked_requirements
locked_cooldown
locked_cost
completed/non-repeatable
```

The exact visual presentation of these states belongs to approved UI design, not this schema.

### Relationship manual action

A relationship action such as Meet Someone may invoke a manual pool. The Event data determines its requirements and per-Character cooldown. EventManager resolves eligible Events/NPC context and pool selection.

### Lifestyle

Lifestyle manual Events are direct list entries. Eligibility reads the exact backend Lifestyle score plus Event-specific job tags, age, flags, item state, history, and cooldown.

Attend Gala retains the already approved 12-month family-wide cooldown and its separately documented Lifestyle/activity scoring rules.

### Family Agency

Family Agency is a manual access hub for:

- special Diamond Events,
- premium relationship/candidate Event systems,
- entitlement-gated real-money Event experiences.

Agency cooldowns are per Event, not global, and are at least 60 months each.

## 17. Entitlements and Paid Event Access

The purchase/store system owns entitlement acquisition and restoration. EventManager only evaluates an `entitlement` requirement through the authoritative ownership provider.

Entitlement ownership does not:

- bypass Event requirements,
- bypass repeat policy,
- bypass cooldown,
- automatically spend currency,
- itself complete/start the Event.

Store-side entitlement products may eventually be permanent, consumable, or limited-use according to that system's product definition. Event data must not duplicate store ownership state.

### Caravan example

A paid Caravan Event may be authored as:

- category: `family_agency`
- manual/direct trigger from Family Agency
- entitlement requirement such as `caravan_event_pack`
- an event-scoped cooldown of at least 60 months
- a player-selected family `travel_group` with `min: 5`, `max: 5`
- a dedicated participant selection modal/bottom sheet before final confirmation

The Map is no longer the required entry point for this class of paid Event content.

## 18. Static Data Validation

Loading/validation must detect and clearly report development errors. Invalid definitions must not silently run.

Validation includes at least:

- supported `schema_version`,
- category/file consistency,
- globally unique `event_id`,
- valid trigger type/cadence/parameters,
- referenced pool existence,
- valid selection mode/max values,
- requirement type/operator/target compatibility,
- known stat names,
- known flag references where applicable,
- valid job/job_tag/school/major/item/business references where applicable,
- valid participant definitions and `min <= max`,
- valid repeat mode/cooldown scope/unit/value,
- Family Agency Event cooldown of at least 60 calendar months and event scope,
- valid presentation template and existing resource paths where required,
- valid choice IDs and resolution modes,
- valid outcome weights/modifiers,
- whitelist-only effect types,
- valid effect participant/context targets,
- existence of queued/scheduled target Event IDs,
- circular/invalid chain conditions where validation can determine them safely.

Development diagnostics identify the source category file and `event_id` so content errors can be corrected directly.

## 19. Save/Load Target

The currently implemented save format remains whatever `docs/DATA_SCHEMA.md` reports until EventManager is implemented.

When EventManager state is integrated, SaveManager must version/migrate the save schema and preserve at least:

```text
event_manager: {
  active_event,
  queued_events,
  scheduled_events,
  history,
  cooldowns,
  next_event_instance_number,
  next_scheduled_event_number
}
```

Loading must not replay already-applied effects, reset cooldowns, reroll persisted scheduled context, or lose story history.

## 20. Complete Processing Pipeline

The common Event pipeline is:

```text
TRIGGER RECEIVED / MANUAL REQUEST
        ↓
Find matching Event definitions
        ↓
Resolve participants and context
        ↓
Evaluate requirements
        ↓
Check story history / repeat policy
        ↓
Check cooldown
        ↓
Resolve pool / exclusive group / weight
        ↓
Create EventInstance
        ↓
Queue by priority
        ↓
Revalidate before activation
        ↓
Pause if blocking
        ↓
Present approved UI template
        ↓
Player choice / confirmation
        ↓
Revalidate choice/cost/context
        ↓
Resolve deterministic / weighted / score-check outcome
        ↓
Apply effects through domain managers
        ↓
Generate actual EffectResult feedback
        ↓
Write full story history
        ↓
Queue or schedule follow-up Events
        ↓
Continue queue; restore time only when blocking queue is empty
```

## 21. Completion Rule

The Event System must not be declared implemented because one sample Event can open. Completion requires the approved data loader/validation, participant and requirement systems, all trigger families, pools/conflict rules, queue/pause behavior, repeat/cooldown, outcomes, effect delegation, EffectResult feedback, story history, scheduling/revalidation, save/load integration, manual discovery, and player-facing Event presentation/integration to be complete and tested.

Implementation is intentionally phased so each Work task remains reviewable. The authoritative phase checklist is `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`.
