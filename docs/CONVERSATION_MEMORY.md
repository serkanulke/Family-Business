# Family Business Conversation Memory

## Purpose and Authority

This file preserves only durable historical context and recurring misunderstandings that are useful across separate project chats.

Authority order:

1. Canonical Google Docs GDD — gameplay design.
2. Current repository — factual implementation state.
3. Event Authoring Guide — production Event authoring contract.
4. Repository architecture/schema/status docs — technical description.
5. `PENDING_DECISIONS.md` — confirmed but not-yet-synchronized decisions only.
6. This file — historical context only.

This file never overrides the GDD or current repository.

## Durable Working Principles

- The repository/project documents are persistent project memory; do not depend on assumed chat recall.
- Read the relevant GDD section and current code before changing a gameplay system.
- Do not invent missing gameplay decisions.
- Family Business is Event-driven, not an autonomous simulation framework.
- Prefer the smallest manager-aligned implementation that satisfies approved gameplay.
- Before changing the GDD, report exact intended edits in Turkish and obtain explicit approval.
- Approved visual references are authoritative; do not redesign them.
- If a legacy JSON exists but has no consumer, do not automatically reconnect or delete it without understanding its intended role.

## Event System Lessons

### Factual Events are not ordinary random Events

Education due, Job Offer, Retirement and confirmed death/Farewell are core factual flows. Their owning manager creates the fact; EventManager presents/orchestrates it. Do not force them through ordinary save-level random pacing.

### Ordinary random pacing is save-scoped

Family size increases candidate variety, not the number of independent random activation rolls. `weight` is relative selection weight, not an occurrence percentage.

### Job Offer is one generic Career Event

Do not create one Event per Job.

CareerManager remains authoritative for Job Offer generation, probability, cooldown, Job/Company selection, salary, active offer and accept/reject behavior.

Current dynamic copy tokens:

```text
{character_name}
{job}
{company_name}
{salary}
```

### Production Event workflow

Core production order:

Education -> Age/Lifecycle -> Job Offer -> Career -> Relationship -> Household -> Business -> Health -> Finance -> General -> Lifestyle -> Family Agency.

Education, Age/Lifecycle and Job Offer core sets are complete. Career is next.

Do not reopen Event architecture unless real production content exposes a concrete blocker.

## NPC Distinction

### Worker NPC
Lightweight record for family-business staffing. Owned by NPCManager.

### Relationship candidate
Full Character record with lifecycle/education/career/family fields. Generated/managed through RelationshipNpcManager + CharacterManager.

Never merge these concepts because both are called NPCs.

## Family Business vs External Company

- External Companies belong to Career/Job Offer data.
- Family Businesses are player-family-owned Map properties.
- Business staffing never becomes an Event-controlled autonomous process.

## Static Data Lessons

### GameData.json
The original intent — data-authored gameplay defaults/tuning instead of unnecessary hardcoding — remains valid.

The current old file is not usable as-is because it mixes stale configuration and mutable save/runtime values. Economy Index is a real approved gameplay rule, not a reason to reconnect the old whole schema unchanged.

### Avatar.json
The file came from the purchasable avatar-theme concept, but the current schema predates the active portrait system. Future avatar-theme work requires a new compatible schema.

### Relationship names
Active Worker and Relationship configs duplicate name data. A future shared Names.json cleanup should migrate both consumers together rather than leaving duplicate canonical lists.

## Recurring Mistakes to Avoid

- Do not equate “file exists” with “system implemented”.
- Do not equate `weight: 5` with 5% occurrence chance.
- Do not roll an ordinary random Event independently for every family Character.
- Do not move Job Offer generation out of CareerManager.
- Do not add Career Level, numeric Relationship meters, generic House assignment, Event-controlled staffing, or Item damage without an approved design.
- Do not treat old Event Phase documents as future architecture requirements; the backend exists and current work is production content.
- Do not use GDD implementation snapshots as the source of repository status; that belongs in `DEVELOPMENT_STATUS.md`.

## Maintenance

Keep this file short. Implementation facts belong in `DEVELOPMENT_STATUS.md`; schema facts in `DATA_SCHEMA.md`; architecture in `ARCHITECTURE.md`; current Event authoring rules in the Event docs/Guide.
