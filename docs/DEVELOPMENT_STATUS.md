# Family Business Development Status

**Audited gameplay baseline:** `main` at `d22047481c4c0f15161b197ae2dda881bc99b54a`  
**Audit date:** 4 September 2026  
**Engine:** Godot 4.7  
**Gameplay authority:** canonical GDD v3.8

This document reports repository reality. It does not create gameplay decisions.

## Status Definitions

- **Implemented** — executable behavior is present in current code/data and has a working integration/test path.
- **Partial** — substantial implementation exists but an approved player-facing or data integration remains incomplete.
- **Missing / known gap** — approved design exists but the current repository does not yet implement it.
- **Legacy / inactive** — file/data remains in the repo but is not a current gameplay authority.

## Implemented

### Core runtime
- Autoload manager structure through SaveManager is active.
- Gregorian calendar/time state is active.
- New game, starting Character creation, save/load, pooled family Money/Diamonds, and multiple manager state restoration exist.
- Character age/life-stage, retirement/pension, health-adjusted death, family links, current portrait selection, and active skin-tone genetics exist.

### Education backend
- School loading, birthday stage requests, compulsory stage handling, university choice, major selection, graduation, School cost/stat application, and Education event integration helpers exist.
- Production Education Event file contains 5 core factual Events.

### Career / Job Offer backend
- CareerManager owns Job/Company eligibility, unemployed daily offer chances, seven-day unemployed offer cooldown, employed monthly better-offer checks, active offers, accept/reject, external job replacement/removal, and salary mutation.
- Production Job Offer uses one generic factual Event.
- Dynamic Job Offer presentation resolution is implemented through `{character_name}`, `{job}`, `{company_name}`, `{salary}`.
- Dedicated Job Offer production tests passed locally: **11 passed / 0 failed**.
- Event Phase 1 regression passed locally after Job Offer update: **89 / 0**.
- Event Phase 3 regression passed locally after Job Offer update: **123 / 0**.

### Age / Lifecycle production Events
- Retirement factual Event exists.
- Confirmed death opens the factual Farewell Event with Private / Small / Large Farewell choices and approved Money costs.
- No separate funeral-state system exists.

### Event backend core
- Static registry/validator exists.
- Runtime requirement/participant resolution exists.
- All five trigger families exist.
- Queue, priority, repeat, cooldown, scheduling, save/load, resolution, effects, story history, and EffectResult behavior exist.
- Save-scoped ordinary random Event pacing is implemented.
- Random pacing regression passed locally: **8 / 0**.
- Ordinary random family size expands candidates without multiplying pool activation rolls.
- `weight` is relative selection weight only.

### Relationship backend
- Relationship candidates are full Characters.
- Meet Someone reuses an eligible unassigned Relationship NPC from the persistent Character pool before generating a new one.
- Per-family rejection history, assignment/release, family entry, marriage, divorce, remarriage cooldown, donor/adoption helpers, active candidate indexing, and marriage cleanup exist.
- Explicit Event rejection/end choices release the candidate or dating link without deleting the external Character; failed activation rollback does the same without recording a rejection.

### House / Household backend
- Five House levels, roles, role/resident capacity, Household Score/Status, Household Perks, Unhoused handling, upgrade and House economy hooks exist.
- Owned/unowned House Map flows and House management UI exist.

### Family Business / Worker NPC backend
- The approved 12 family-business types are configured.
- Purchase, instance creation, upgrades, slots, staffing, Worker NPC assignment/replacement, performance tiers, income/fixed expense settlement, and independent map/modal visuals exist.
- Business artwork does not change by level.
- Worker NPC generation, availability, retirement, and staffing records exist.

### Items / Lifestyle backend
- Stable Item catalog definitions, family inventory, ItemInstances, equipment, exact Lifestyle Score, expiration, purchases, and monthly slot-specific shop stock exist.
- Item List / Shop bottom-sheet flow exists.
- Dedicated Lifestyle gameplay screen and production Lifestyle Event content are not yet complete.

### Map / property infrastructure
- Authored isometric Map scene and property-tag interaction infrastructure exist.
- City placement is manually authored rather than generated randomly.
- Business/House purchase/management flows are connected for authored properties.
- Land construction flow remains separate/incomplete.

## Production Event Progress

| Category | Status |
| --- | --- |
| Education | **Complete core production set** — 5 factual Events |
| Age / Lifecycle | **Complete core production set** — Retirement + Farewell |
| Job Offer | **Complete core production set** — 1 generic factual Event |
| Career | **Next** — production content not authored yet |
| Relationship | **Production set authored** — 27 definitions covering 23 numbered Events; pool/rejection cleanup implemented |
| Household | Not authored |
| Business | Not authored |
| Health | Not authored |
| Finance | Not authored |
| General | Not authored |
| Lifestyle | Not authored |
| Family Agency | Not authored |

The Event backend should not be broadly refactored while authoring these categories. Fix it only when real production content exposes a concrete blocker.

## Partial / Missing Approved Work

### Shared player-facing Event presentation
- `UI/EventPresentation/EventPresentation.tscn` is instantiated by `Scenes/Main/Main.tscn` and presents blocking active Events from `EventManager`.
- The shared modal supports single-Character, two-Character Relationship, and Character-group headers; data-authored Event art and choice icons; live backend-derived enabled/locked choice states; existing Character Card routing; player-selected Character-group bottom sheets; and Character stat-change result cards from applied `EffectResult` records.
- Missing `presentation.art_path` or `choice.icon_path` remains safe and visually empty. Production Event JSON asset metadata is still unauthored.
- No production Lifestyle/Family Agency Character-group Event or live caller currently exists; the shared manual-entry contract is implemented and covered by fixtures, but production group content/integration remains incomplete.

### Career production Events
- CareerManager backend is implemented.
- `career.json` has no production Career Events yet.
- Production random Career balance values such as activation chances and salary-increase amounts must come from approved design/content decisions; do not invent them.

### Relationship Event content
- `relationship.json` contains the current 27-definition production set covering the 23 numbered Meet Someone/dating/marriage Events.
- Meet Someone age-band definitions are repeatable and have no cross-band `event_seen` lock; trigger timing, pools, activation chances, weights, and cooldown values remain data-authored.
- The 13 explicit rejection/end choices release their bound NPC through `relationship_status_set.value = null` and record that family/NPC pair as rejected.

### Lifestyle / Family Agency
- Event backend supports manual flows.
- Full production screens/content remain incomplete.

### Land construction
- Plot assets/infrastructure exist.
- Complete purchase -> choose build -> construction flow is not yet finished.

## Critical Known Gameplay Gap: Economy Index

GDD v3.8 states that Economy Index is a DECIDED time-based multiplier that prevents applicable Money expenses from remaining nominally fixed across decades.

Current code does **not** implement that approved rule:

- `EconomyManager` has no current Economy Index calculation/advance logic.
- `EducationManager` currently uses `School.json.base_cost` directly rather than applying current Economy Index.
- `GameData.json` contains old `economy_index` / `economy_growth_rate` fields but is not consumed.

This must be treated as missing implementation. Do not classify Economy Index as removed or optional.

The exact growth rate/cadence and any additional expense categories not already explicitly included/excluded remain GDD OD-019 content decisions.

## Static Config / Legacy Data Status

### `GameData.json`
**Legacy schema, valid intended purpose, no current runtime integration.**

The original purpose — keeping tunable gameplay defaults/config outside hardcoded code — remains valid. The file cannot be reconnected as-is because it mixes stale config with mutable save state and obsolete values.

### `Avatar.json`
**Legacy/inactive.**

It belongs to an older purchasable avatar-theme/portrait model and points to obsolete asset paths. Current Character portrait selection does not consume it. Future avatar-theme product work requires a new schema compatible with the current portrait system.

### `RelationshipNPC.json`
**Legacy/inactive uppercase empty collection.**

No current runtime consumer was found. Active Relationship generation uses lowercase `relationship_npc.json`.

### Duplicated names
`npc.json` and `relationship_npc.json` currently duplicate first-name lists. A shared `Names.json` cleanup is planned but not implemented yet.

## Documentation Status

The previous repo docs were based mainly on the 2 September Event phase snapshot and were stale. This documentation refresh aligns:

- `AGENTS.md`
- `docs/ARCHITECTURE.md`
- `docs/CONVERSATION_MEMORY.md`
- `docs/DATA_SCHEMA.md`
- `docs/DEVELOPMENT_STATUS.md`
- `docs/EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`
- `docs/EVENT_SYSTEM_SPEC.md`
- `docs/MAP_ART_STANDARD.md`
- `docs/PENDING_DECISIONS.md`

with the 4 September 2026 production Event state and GDD v3.8.

## Next Work

1. Continue production Event authoring with Career.
2. Do not invent Career probabilities/amounts that remain undecided.
3. Keep factual Job Offer behavior unchanged.
4. Separately restore the approved Economy Index implementation after its exact growth/cadence decision is confirmed.
5. Later clean shared Names/config/legacy JSON in bounded migrations with regression tests.
