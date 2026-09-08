# Family Business Event System Production Plan

**Status:** backend core complete; production Event authoring in progress  
**Gameplay authority:** GDD v3.8  
**Authoring authority:** current Event Authoring Guide  
**Purpose:** track current production content work. This is no longer a historical Phase 0–9 architecture checklist.

## 1. Working Rule

The Event backend is already established.

For each production category:

1. Read the relevant GDD section.
2. Read the current Event Authoring Guide.
3. Inspect the current owning manager/static JSON.
4. Inspect the current category JSON and relevant tests.
5. Author **core/mandatory playable-loop Events first**.
6. Use existing manager behavior instead of duplicating it.
7. Use save-scoped pacing only for ordinary random Events.
8. Keep factual/core Events outside ordinary random pacing.
9. Add production-category tests.
10. Run Phase 1 / relevant runtime regression tests.
11. Update docs/status.
12. Change Event backend only if production content exposes a concrete blocker.

Do not invent balance values merely to fill a schema.

## 2. Backend Status

Complete and in active use:

- static Event registry/validator;
- requirements and participant resolution;
- system/calendar/manual/chain/scheduled triggers;
- queue/priority/deduplication;
- repeat/cooldown;
- scheduling;
- deterministic/weighted/score-check resolution;
- manager-delegated effects and EffectResult feedback;
- story history;
- save/load Event runtime;
- activation-time Relationship candidate materialization;
- save-scoped ordinary random Event pacing;
- dynamic Event presentation resolution helper.

Recent verified local regressions:

- Event Random Pacing: **8 passed / 0 failed**
- Event Phase 3: **123 / 0**
- Event Phase 1: **89 / 0**
- Job Offer production: **11 / 0**

## 3. Production Category Order

### 1. Education — COMPLETE

Core Events:

1. Primary School choice at age 6.
2. Middle School transition at age 12.
3. High School transition at age 15.
4. University choice at age 18, including decline.
5. Major selection at age 21.

These are factual Education flows. EducationManager remains canonical for school/major/graduation state.

### 2. Age / Lifecycle — COMPLETE

Core Events:

1. Retirement.
2. Farewell after confirmed death.

Retirement state already exists before the Event presents. Farewell adds no separate funeral-state system.

### 3. Job Offer — COMPLETE

One generic factual Event:

`job_offer_external_offer`

CareerManager remains authoritative for offer generation, probability/cooldown, Job/Company/salary and acceptance/rejection.

Presentation resolves:

```text
{character_name}
{job}
{company_name}
{salary}
```

Do not split this into one Event per Job.

### 4. Career — NEXT

`career.json` currently has no production Events.

Before authoring random Career Events, production values must be explicitly decided for any balance that is not already in GDD, including:

- save-level activation chance(s);
- effect amounts such as salary increase.

`weight` must not be used as a disguised occurrence percentage.

Approved narrow salary mutation exists:

```text
salary_increase
```

It changes only current external salary through CareerManager and does not create Career Level/progression.

### 5. Relationship

The current production set contains 27 definitions covering the 23 numbered Relationship Events. It uses the approved eligibility, probability, relative weight, cooldown, and chain values without adding a relationship meter/state machine.

Meet Someone uses ordinary save-scoped random pacing and activation-time candidate assignment: reuse an eligible unassigned persistent Relationship NPC first, generate only when the pool is empty, and release rather than delete on rejection or failed activation.

### 6. Household

Use current House/Household Status/Perk state as eligibility/context. Do not create a second household simulation.

### 7. Business

Events may query owned Business/type/level. Staffing remains player-controlled and must not be changed by Event effects.

### 8. Health

Use existing Character Health/stat state and approved Event effects only. Do not invent a health-condition simulation layer unless separately approved.

### 9. Finance

Use pooled family Money and existing economy ownership. Do not invent debt/tax/recurring-bill systems that are not approved.

### 10. General

Ordinary life/flavor content. Use save-scoped pacing where random.

### 11. Lifestyle

Player-initiated manual flow. Eligibility uses exact backend Lifestyle Score, not star count.

### 12. Family Agency

Player-initiated manual flow. Preserve per-Event Agency cooldown and entitlement rules.

## 4. Shared Event Presentation Work

`EventPresentationResolver` currently resolves dynamic Job Offer content.

A complete common player-facing Event modal still needs to consume:

- resolved title/subtitle/description;
- participants;
- art/icon/template metadata;
- choices;
- choice cost/locked state;
- EffectResult feedback;
- blocking pause lifecycle.

Do not design the visual treatment independently when an approved reference exists.

## 5. Final Category Completion Checklist

A category is complete only when:

- required production Event JSON exists;
- eligibility/participants/context are correct;
- factual/random pacing type is correct;
- manager mutation is canonical;
- repeat/cooldown is correct;
- copy/tags resolve;
- tests pass;
- save/load does not break the flow;
- docs are updated.

Rendering one modal alone does not complete a category.

## 6. Separate Non-Event Gap

Economy Index is a current gameplay implementation gap discovered during documentation/GDD audit. It must be handled as a separate bounded Economy/Education task and must not be mixed into Career Event authoring.
