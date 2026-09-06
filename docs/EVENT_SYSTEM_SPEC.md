# Family Business Event System Specification

**Status:** implemented backend contract + production authoring rules  
**Gameplay authority:** GDD v3.8 Section 14 / current Decision Log  
**Authoring authority:** current Event Authoring Guide  
**Repository baseline audited:** `main` at `d22047481c4c0f15161b197ae2dda881bc99b54a`

This file describes the Event system that exists now. It is not a future simulation framework design.

## 1. Core Boundary

EventManager is an orchestration layer.

It may:

- discover/validate Event definitions;
- evaluate requirements/participants;
- dispatch system/calendar/manual/chain/scheduled triggers;
- evaluate ordinary random pools;
- queue/activate/resolve Events;
- apply whitelisted effects through authoritative managers;
- record history/repeat/cooldown/schedules;
- persist Event runtime state.

It must not create parallel Character, Education, Career, Relationship, House, Business, Item, or economy models.

## 2. Category Files

Static Event definitions live under `Resources/Json/Events/`:

```text
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

Each root:

```text
{
  schema_version: 1,
  category: String,
  pools: PoolDefinition[],
  events: EventDefinition[]
}
```

`category`, `domain`, `trigger`, and `presentation.template` are separate concepts.

`job_offer` remains a separate category/file for now, while its gameplay domain is Career.

## 3. Event Definition

Current top-level contract:

```text
{
  event_id,
  category,
  domain,
  subtype,
  enabled,
  rarity,
  weight,
  priority,
  exclusive_group,
  pool_id?,
  trigger,
  participants,
  requirements,
  repeat,
  cooldown,
  behavior,
  content,
  presentation,
  cost?,
  choices,
  default_resolution?,
  metadata?
}
```

Stable IDs are persistent content identity. Do not create one Event per concrete Job/Company merely to vary copy.

Presentation geometry/style is scene/UI-owned, not JSON-owned.

## 4. Trigger Families

Exactly five trigger families are supported:

```text
system
calendar
manual
chain
scheduled
```

### System
Uses semantic gameplay occurrences rather than raw signal paths.

### Calendar
Uses Gregorian date/cadence definitions authored in Event data.

### Manual
Reserved for Lifestyle and Family Agency flows only.

### Chain
Continues only because authored Event results queue the next Event.

### Scheduled
Stores a future due date plus exact participants/context and revalidates when due.

## 5. Ordinary Random Pacing

Ordinary random Event pacing is **save-scoped**.

A save-scoped random pool uses:

```text
{
  pool_id: String,
  selection_mode: "weighted_one" | "weighted_multiple" | "all_eligible",
  selection_scope: "save",
  activation_chance: number,
  max_events: positive int
}
```

Rules:

1. Gather all eligible Event+Character candidates for the save-scoped pool.
2. Evaluate one pool activation roll.
3. If activation fails, produce no Event.
4. If activation succeeds, perform candidate selection.
5. `weight` is relative selection weight only.
6. Family size enlarges candidates; it does not multiply pool activation rolls.
7. Categories are not quotas.

`EventPoolSelector.passes_activation()` owns the activation chance roll using the existing persisted seeded RNG.

## 6. Factual / Core Event Exception

A factual Event represents a canonical gameplay fact that already occurred or became due in its owning manager. Factual Events bypass ordinary random pacing.

Current examples:

- Education stage/major due.
- CareerManager external Job Offer request.
- Retirement.
- Confirmed death -> Farewell.

Do not convert these flows to save-level random Events.

## 7. Job Offer Contract

External Job Offer is a core factual Career flow.

CareerManager owns:

- graduated/alive/family/retirement/family-business eligibility;
- unemployed daily offer probability brackets;
- seven-day unemployed offer cooldown;
- employed monthly better-offer chance;
- eligible Job calculation;
- Job-first / Company-second selection;
- canonical salary;
- active offer storage;
- accept/reject;
- external job replacement/removal.

EventManager receives the factual `job_offer_requested` occurrence and presents one generic production Event.

Current dynamic content tags:

```text
{character_name}
{job}
{company_name}
{salary}
```

`EventPresentationResolver` resolves these through bound runtime data and canonical managers.

## 8. Participants and Requirements

Participants are runtime bindings, not duplicated static Character data.

Supported participant concepts include:

- primary/target Character;
- Character groups;
- Relationship candidates;
- House;
- family Business;
- supplied context.

Requirements share one recursive `all` / `any` / `none` evaluator and query canonical manager state.

Do not invent unsupported gameplay concepts such as Career Level, Education Level, numeric Relationship Level, compatibility meter, or attraction meter.

## 9. Repeat and Cooldown

Repeat and cooldown are separate.

Supported repeat modes:

```text
once
once_per_character
once_per_character_pair
once_per_family
once_per_house
once_per_business
repeatable
```

Cooldown scopes:

```text
event
character
character_pair
family
house
business
```

Cooldown time uses Gregorian calendar arithmetic.

Meet Someone ordinary random pacing is save-scoped, while any selected Character-scoped cooldown remains scoped only to that Character.

## 10. Resolution and Effects

Resolution modes:

```text
deterministic
weighted
score_check
```

Event effects are whitelist-based data operations. JSON never contains executable code.

Current manager-aligned principles:

- stat/flag operations use Character state;
- Relationship uses narrow `relationship_status_set`, `relationship_marry`, `relationship_divorce`;
- Money/Diamond operations use family resources;
- Job Offer acceptance/rejection delegates to CareerManager active-offer behavior;
- external `job_remove` and positive `salary_increase` remain narrow Career operations;
- Education uses approved EducationManager-backed operations only;
- Item effects use catalog `item_id` plus target Character, not saved ItemInstance IDs;
- House effects do not provide generic automatic assignment;
- Event content cannot staff/replace/remove Business workers;
- Business upgrade may delegate to BusinessManager;
- Event queue/schedule/cancel operations remain Event-owned.

Explicitly absent:

- Career Level/progression state;
- generic education progression/transfer;
- numeric Relationship simulation;
- generic House assignment;
- Business role/staff mutation by Event;
- Item damage-point mechanic;
- timed/parallel flag system beyond the current approved simple flag model.

## 11. History and Persistence

Completed/terminal Event runtime records retain:

- definition/instance identity;
- dates/status;
- participants/context;
- chosen choice;
- outcome;
- applied EffectResults;
- source chain identity.

EventManager export/import preserves active, queued, scheduled, history, repeat/cooldown, counters, RNG/selection state, occurrence ledgers, and pause ownership without replaying effects.

SaveManager stores one Event runtime subsection.

## 12. Activation-time Relationship Candidate Materialization

For participant source `new_relationship_npc`:

- discovery/availability checks are read-only;
- candidate creation occurs only after the Event wins selection and passes final revalidation;
- exact generated Character ID is bound before first presentation;
- activation failure before commit discards the unpresented candidate;
- later chain/scheduled Events preserve exact participant IDs.

Marriage/rejection cleanup remains RelationshipNpcManager-owned.

## 13. Production Content State

### Complete core production sets

- Education: 5 factual Events.
- Age / Lifecycle: Retirement + Farewell.
- Job Offer: 1 generic factual Event.

### Next
- Career.

### Not yet authored
- Relationship
- Household
- Business
- Health
- Finance
- General
- Lifestyle
- Family Agency

## 14. Backend Change Rule

Production authoring is now the primary validation path.

Do not restart broad Event architecture work. Change the backend only when a real production Event demonstrates one of these concrete problems:

1. a GDD-required Event cannot be authored;
2. canonical state is mutated incorrectly;
3. state is duplicated/corrupted;
4. save/load is wrong for the intended Event flow;
5. production-scale selection/pacing demonstrably breaks player experience.

If a malformed or unnecessary Event would be required only to exercise an edge case, do not expand the backend for it.

## 15. Presentation Status

`EventPresentationResolver` exists, but the complete shared production Event modal/UI layer is still incomplete.

Future UI must consume resolved Event content and runtime choices/effects. It must not duplicate manager logic or hardcode Job/Company presentation rules.
