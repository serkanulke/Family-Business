# Family Business Development Status

## Snapshot

- Inspected: 2026-09-01
- Branch: `main`
- HEAD: `30a55ad` (`house manager fix`, 2026-09-01)
- Engine configuration: Godot 4.7
- Startup scene: `Scenes/MainMenu/MainMenu.tscn`

This status is derived only from files present in the inspected working tree. Unrelated files were preserved. Fresh Character Card, Item List / Shop, Map, property modal, House, and Event System Phase 1–3 validation results are recorded below; other test scenes remain inventory evidence unless separately noted.

## Status Definitions

- **Implemented:** executable manager or UI behavior and integration are present in the repository; related tests often exist.
- **Partial:** substantial code exists, but the player-facing flow, broader integration, or scene coverage is incomplete.
- **Not implemented / not found:** only a stub, data-only placeholder, visual-only control, or no consuming code was found. This is a repository observation, not a statement about GDD scope.

## Implemented

| System | Repository evidence |
| --- | --- |
| Core game and family state | `GameManager` owns settings, family name, money, diamonds, and new-game orchestration. |
| Simulation time | `TimeManager` advances a shared Gregorian calendar, including leap years, and supports pause plus x1/x2/x3 speed; family-tree HUD controls are connected. |
| Starting character creation | New-game modal selects gender and skin tone, resolves a canonical Male/Female + skin + YoungAdult portrait, persists `portrait_variant_id`, generates names, creates a young-adult character, initializes family state, and enters the gameplay scene. |
| Character lifecycle | Age is derived from birth date; life stages, retirement, pension, health-adjusted death checks, skin-only active genetics, biological children, donor conception, adoption, persistent portrait variants, and life-stage portrait transitions exist. |
| Parent/family model | Integer parent/partner/child links, legacy parent migration, family membership, and child finalization exist. |
| Relationship NPC backend | Candidate generation, education/career history, family conversion, marriage eligibility, divorce, cooldown, returning candidates, remarriage, and child routes exist. |
| Family tree | Runtime layout, spouse/parent relationships, reference links, character nodes, pan/zoom bounds, HUD, family-name binding, and manager-signal refresh exist. |
| Character Card | A scrollable 1080 x 1920 overlay modal opens above the existing Family Tree instance; Family Tree and its CanvasLayer HUD remain visible through a 76% black dim layer but cannot receive pointer/touch input. The inset panel preserves the supplied Profile, Attributes, Lifestyle/Items, Education/Career, and Event History hierarchy. X hides the overlay without scene reload; background clicks do not close it. Accessory/Outfit/Vehicle controls show empty slot icons or edge-to-edge, rounded-clipped equipped ItemInstance thumbnails, live-refresh from `equipment_changed`, and pass character ID plus distinct slot context to the reusable Item List bottom sheet. |
| Item List / Shop UI | A CanvasLayer 40, full-screen input-blocking bottom sheet opens at reference y=320 above the Family Tree/Character Card. It provides manager-backed Current Balance, Equipped/Owned/More Items hierarchy, two-column reusable SHOP/OWNED/EQUIPPED cards, empty Equipped presentation, information panel, accessory-only conceptual filters, computed Show X More expansion, and vertical scrolling. The shared information panel uses identical icon plus left-aligned title/description rows, centers each icon against its complete text block, and places thin dividers only between its three sections. Owned renders only unequipped/available family ItemInstances by subtracting family-wide equipped `instance_id` values; equipped instances remain in the canonical family inventory. Scrim tap and `ui_cancel` close only this sheet; one instance is reused without stale character/slot/filter state. Shared card layout reserves the durability row for permanent Heirlooms, keeping Buy/Wear/Unequip baselines fixed while showing no durability content. |
| Item catalog, pricing, inventory, equipment, and monthly shop backend | `ItemCatalogGenerator` scans 261 existing PNGs into stable definitions with deterministic Lifestyle, lifespan, Money, Legendary Diamond, and Heirloom Diamond values. `ItemManager` owns shared family inventory, single-owner character-slot assignments, expiration, Lifestyle calculation, purchase validation, and three persisted monthly stocks with independent six-item limits. Family Tree binds the sheet to this manager for production Buy/Wear/Unequip and balance refresh. |
| Education backend | School loading, birthday event queue, enrollment/cost/stat changes, stage graduation, university decline, major choice, and graduation checks exist. |
| External career backend | Company/job loading, requirement matching, unemployment and advancement offer pools, cooldowns, offer acceptance/rejection, and company assignment exist. |
| Economy backend | Monthly external salary payments, family-business settlement, fixed expenses, and family-money updates exist. |
| Family-business backend | The approved 12-type roster is fully configured. Type loading, acquisition cost, instance creation, plot occupancy, upgrades, slots, family/Worker NPC assignment and replacement, performance tiers, income, expense, net profit, and independent static map/modal visual resolution exist. Runtime instances contain no visual variant state. |
| Worker NPC backend | Config-driven generation, age filters, candidate ranking, availability, slot assignment, retirement, and business-income contribution exist as a system separate from Relationship NPCs. |
| Business staffing modal flow | Business data adapter, financial/staff display, upgrade action, worker-type choice, candidate sheets, assignment, replacement, and integration tests exist. The adapter uses only `modal_visual_path`; missing modal assets are handled without crashing or falling back to map art. The redundant small business-type icon is removed from every Business Modal header, and unaffordable upgrades use the approved disabled CTA presentation. |
| Family-business purchase modal flow | Authored family-business selection routes `Property Tag -> MapProperty -> MapScreen -> Main`. Owned plots open the shared BusinessModal; unowned plots open one shared BuyBuildingModal. The approved purchase card binds authoritative Level 1 gross potential, fixed expense, slot count, ready-made acquisition cost, and `modal_visual_path`; insufficient funds keep the price visible inside the cream bordered disabled CTA. The modal revalidates plot/funds and delegates creation to `BusinessManager`. Success refreshes the Map tag and shared HUD, then opens BusinessModal for the new instance. |
| House backend and economy | `HouseManager` loads the five canonical levels and four roles, owns Map-linked House instances, combined role/resident capacity, role-relative tiers, importance-weighted hidden score, five statuses, Head-derived data-driven perks, Unhoused queries/monthly -2 Happiness, upgrades, ready-made/new-construction costs, death cleanup, and state-change signals. Monthly fixed expenses run through the existing first-day economy cycle with same-date protection. |
| House Modal and property flow | The shared 1080×1920 House Modal binds an exact owned House instance and renders the approved identity/level/capacity, status, expense, text-only perk tags, role cards, resident management, next upgrade, and functional information overlay. The information overlay now uses one approved X close action and 20 px-or-larger explanatory copy. A House-only playable-family bottom sheet supports Assign/Replace, role-relative tier evidence, cancellation, and `Remove from House`. House selection uses only the floating Property Tag; the building footprint/sprite cannot open it. Unowned authored Houses open the Buy Building-derived ready-made House purchase modal; owned Houses open management. `house_01` is the deterministic free starting House. |
| Save/load/autosave | Version 5 adds House ownership/level/assignments, the next House ID, Unhoused processing date, and House economy settlement state. Versions 2–4 migrate safely to one deterministic starting House; existing Item version migrations remain compatible. Unique save IDs, dynamic save listing, Continue/Load Game flows, delete API, and deferred autosaves tied to manager signals exist. |
| Main menu and load-game UI | Main menu, new-game modal, runtime save-slot list, continue/load navigation, and gameplay scene transitions exist. |
| Authored Map and runtime infrastructure | `UI/Map.tscn` contains manually authored TileMapLayer ground/road/environment content and building sprites inside a `6200 x 4200` rectangular MapWorld. All 68 authored interactive parents use explicit MapProperty metadata: 52 family businesses, 10 houses, and 6 land plots. Authored-existing visual mode reuses each original Sprite2D and adds only tag/interaction children. Business, House, and Land property selection is exclusively through the floating Property Tag; all building footprint collisions remain non-pickable. The fixed-zoom camera supports desktop mouse and one-finger touch drag; wheel zoom remains disabled. TileSets, artwork, and all 68 interactive Sprite2D position/scale/texture records remain unchanged. |
| Family Tree / Map navigation | Main owns the persistent Family Tree, lazily created and reused Map, and one shared Main HUD. Screen changes now explicitly isolate visibility, processing, CanvasLayer state, and the active Camera2D: only the active screen camera remains enabled/current. Date/Money/Diamond and navigation do not duplicate, while Family Tree time controls remain Family Tree-only. |
| Event System Phase 1 static data foundation | All 12 approved empty category files exist under `Resources/Json/Events/`. Autoload-free `EventDataRegistry` and `EventDataValidator` provide safe JSON loading, atomic global/category/pool lookup publication, source/Event/path diagnostics, complete Phase 1 static schema/reference/effect/graph validation, Family Agency per-Event cooldown enforcement, and optional `Job.event_tags` validation. No production Event content was authored. |
| Event System Phase 2 runtime eligibility backend | Runtime services provide indexed definition lookup, immutable-in-practice Event instances, recursive live requirement evaluation with structured failure reasons, authoritative manager-backed queries for all 47 approved requirement types, participant candidate resolution/revalidation, direct and pool-based manual discovery, and non-mutating availability checks. The Phase 2 APIs remain intact and are composed by Phase 3. |
| Event System Phase 3 timing/orchestration backend | `EventManager` is registered after `ItemManager` and before `SaveManager`. It implements semantic system dispatch with minimal truthful manager adapters, Event-defined Gregorian calendar cadence, all five trigger families, seeded pools/exclusive groups, priority/stable queueing, duplicate suppression, blocking pause/restore, all repeat and cooldown modes/scopes, deterministic scheduling, and due-date revalidation/expiry. Completion commits session repeat/cooldown state; cancellation/expiry do not. Runtime export is serializable, but no Event save integration, effect/outcome resolution, final story history, UI, or production content exists. |

## Partial

| System | Missing or limited integration observed |
| --- | --- |
| Overall gameplay shell | Family Tree and Map are integrated. Lifestyle remains a visual navigation entry because no Lifestyle screen exists. |
| Education player flow | Backend emits education and major-selection events, but no player-facing education choice scene or signal consumer was found outside tests/autosave hooks. |
| Career player flow | Backend emits job offers, but no player-facing offer scene or signal consumer was found outside tests/autosave hooks. |
| Relationship player flow | Candidate/family logic is extensive, but no player-facing relationship event or candidate-selection UI was found. |
| Event System | Phases 1–3 are implemented: static validation, live eligibility/participant resolution, and session timing/orchestration. Phase 4 outcomes, effect execution, final story history, and Event save/load integration are not implemented. Event UI, participant-selection UI, category-flow migration, and production Event content also remain later work. |
| Settings | Settings values and setter methods exist in `GameManager`, and menu/HUD settings visuals exist, but no settings screen or connected editing flow was found. |
| Building visuals | Manually placed building and road artwork exists in `UI/Map.tscn`. Gameplay wiring does not recreate or reposition authored Sprite2D visuals; the before/after interactive Sprite2D position/scale/texture manifest remains identical. |
| Land construction flow | House ownership and ready-made purchase are implemented. The approved 2×2/4×4 Land purchase-to-construction selection flow remains deferred; House backend already exposes the shared 1.40 new-construction cost for that later integration. |
| Legacy Bookshop save migration | Bookshop is removed from current `BusinessTypes.json` and authored map data. No GDD decision identifies how an already purchased Bookshop in an older save should be converted or compensated, so existing save records are preserved as unsupported legacy instances rather than silently deleted or mapped to an unrelated type. |
| Lifestyle class label | Equipped-item Lifestyle score and star presentation are implemented. The optional cosmetic class label remains hidden because no canonical label resolver/text set was found; this does not block Lifestyle gameplay. |
| Playable portrait asset coverage | Canonical discovery/resolution and missing-asset fallback are implemented, but the inspected asset tree contains only `Male/Mixed/YoungAdult/character_001.png` and `Female/Light/YoungAdult/character_001.png`. The other gender/skin/life-stage pools are absent, so affected Characters correctly use `default_avatar.png` and log development warnings until matching assets are supplied. |

## Not Implemented / Not Found

| Area | Repository evidence |
| --- | --- |
| Lifestyle screen | The family-tree HUD draws a Lifestyle navigation entry, but no Lifestyle scene, script, or click behavior was found. |
| General Flag system | `Flag.json` and character `flag_ids` exist, and House perks now consume the approved musician/painter IDs through `HouseholdPerks.json`; no broader flag-award/removal manager or other flag-driven gameplay was found. |
| `GameData.json` runtime integration | The file exists, but no code or scene reference was found. Active state is held by autoload managers and save snapshots. |
| `Avatar.json` integration | The file exists, but no code or scene reference was found; current portrait resolution uses resource paths and `CharacterManager`. |
| `RelationshipNPC.json` integration | The empty uppercase-named collection exists, but no code or scene reference was found. Relationship candidates are stored in `CharacterManager.characters`. |
| Event category content | The 12 production category roots intentionally contain empty `pools` and `events` arrays; production Event definitions/copy/art/weights/effects/tag assignments have not been authored or approved in this phase. |

## Test Inventory

The repository contains 47 `.tscn` test scenes covering:

- business manager, economy, modal integration, family and Worker NPC assignment;
- Worker NPC generation, slot rules, and retirement;
- career eligibility/offers and education events;
- relationship candidates, marriage/divorce/remarriage, adoption/donor conception, and parent links;
- family-tree layout, complex structures, relationship display, camera, pan bounds, runtime UI, and main-scene integration;
- new-game character selection and dynamic/runtime save behavior.
- portrait-folder mapping, skin-only genetics, persistent variants, parent exclusions, aging, legacy path recovery, donor/adoption behavior, and missing-asset safety;
- Character Card data binding, GDD Lifestyle star thresholds, item-slot signal routing, and Family Tree modal integration;
- Item List / Shop slot isolation, Accessory conceptual filters, card pricing/presentation, durability derivation, interaction context, modal behavior, scroll/expand behavior, and rendered reference comparison.
- Event Phase 1 production-category loading; valid schema representation; malformed roots; duplicate IDs; pools/triggers/calendar dates; participants; every requirement family and canonical stat/reference checks; repeat/cooldown and Family Agency limits; presentation/costs; all resolution/effect families; Event-flow references/cycles; and optional Job event tags.
- Event Phase 2 recursive live requirements and all operators; all 47 approved runtime requirement types; participant sources, cardinality, duplicate prevention, and revalidation; manual direct/pool discovery; availability states and readable reasons; minimal Event-instance creation; and proof that discovery/activation does not mutate gameplay state.
- Event Phase 3 Gregorian calendar math/cadence; all trigger families; semantic occurrence context; seeded pool/exclusive selection; stable-priority queueing and deduplication; blocking pause restoration; every repeat mode and cooldown scope/unit; Agency cooldown isolation/durations; scheduling/revalidation/expiry; serializable runtime shape; and proof that no gameplay effect executes.

Fresh Character portrait/genetics migration validation on 2026-08-25:

- Godot 4.7.1 editor/project scan completed with exit code 0 and no script parse error.
- `Tests/PortraitGeneticsMigrationTest.tscn`: 22 passed / 0 failed.
- `Tests/NewGameCharacterSelectionTest.tscn`: 18 passed / 0 failed.
- `Tests/ParentModelTest.tscn`: 3 passed / 0 failed.
- `Tests/FamilyCreationTest.tscn`: 5 passed / 0 failed.
- `Tests/RelationshipNPCManagerTest.tscn`: 5 passed / 0 failed.
- `Tests/RelationshipDivorceRemarriageTest.tscn`: 8 passed / 0 failed.
- `Tests/FamilyTreeRelationshipDisplayTest.tscn`: 7 passed / 0 failed.
- `Tests/FamilyTreeLayoutTest.tscn`: 5 passed / 0 failed.
- `Tests/FamilyTreeComplexStructureTest.tscn`: 5 passed / 0 failed.
- `Tests/CharacterCardTest.tscn`: 85 passed / 0 failed.
- `Tests/FamilyCandidateTest.tscn`: 7 passed / 0 failed.
- `Tests/WorkerAssignmentFlowTest.tscn`: 7 passed / 0 failed.
- `Tests/DynamicSaveManagerTest.tscn`: 19 passed / 0 failed.
- `Tests/FamilyTreeVisualTest.tscn` and `Tests/FamilyTreeVisualUITest.tscn` completed their headless smoke runs without a script/runtime crash; these visual scenes do not print assertion totals.
- Expected warnings identify absent canonical portrait pools and confirm fallback to the existing default avatar. The ordinary Windows root-certificate-store warning remains unrelated to gameplay.

Fresh Character Card validation on 2026-08-20:

- Godot editor/project scan completed with exit code 0 and registered `CharacterCard` without a parse error.
- `Tests/CharacterCardTest.tscn`: 85 passed / 0 failed in the current headless regression run. Coverage includes CanvasLayer ordering, Full Rect modal root, 0.76 dim opacity, inset panel, modal-only scroll ownership, pointer blocking, background-click behavior, X-button close, manager-backed opening, Accessory/Outfit/Vehicle thumbnail resolution, zero-inset slot fill, shared rounded clipping, cover behavior, empty-slot fallback, live equip/unequip refresh, slot click context, and preservation of the same Family Tree scene instance.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 7 passed / 0 failed, including Family Tree to Map and Map to Family Tree process/input isolation.
- Real-renderer capture mode passed 86 / 86 and wrote `Tests/Artifacts/character_card_item_thumbnail.png`. The 1080 x 1920 output keeps the three-slot layout, shows edge-to-edge real Accessory and Outfit PNGs with the Vehicle empty icon, preserves slot radius/border, and leaves each full slot button clickable.

Fresh Item List / Shop validation on 2026-08-20:

- Godot project parsing completed with exit code 0 and registered the new Item List / Shop scenes and scripts without parse errors.
- `Tests/ItemListShopTest.tscn`: 109 passed / 0 failed in the current headless behavior run. Coverage includes the three slot routes and strict scope separation, family-wide equipped-instance exclusion from Owned, post-filter counts, filters, empty/equipped states, shared left-aligned information rows, icon/text-block centering, two information dividers, section dividers, circular information icons, rounded dashed empty frame and tint, vertically centered durability content, scrim/Cancel close behavior, context restoration, shared-owned/monthly-shop boundaries, scrolling, Heirloom durability-space reservation, equal action baselines in all three modes, price presentation, and exact interaction context.
- Rendered capture mode: 111 passed / 0 failed using the real renderer. The refreshed 1080 x 1920 captures `Tests/Artifacts/item_list_shop_reference_recreation.png` and `Tests/Artifacts/item_list_shop_empty_equipped.png` confirm the left-aligned information columns, block-centered icons, visible separators, and existing reference styling.
- `Tests/ItemManagerTest.tscn`: 189 passed / 0 failed. Coverage includes deterministic 261-item generation; detailed Common/Rare/Epic/Legendary/Heirloom pricing components and interpolation boundaries; three independent stocks; production sheet binding; balance rejection and deduction; duplicate-Buy prevention; ItemInstance dates; save v4 and v3 migration; instance-ID Owned projection; two instances of one definition; replace/unequip projection; family-wide equipped detection; cross-character ownership; Lifestyle cap; calendar durability; expiration cleanup; and Heirloom permanence.
- `Tests/DynamicSaveManagerTest.tscn`: 17 passed / 0 failed with real `user://` writes after the Save version 4 slot-stock integration.
- The renderer reported no Item List / Shop runtime error. The headless run still prints the existing Windows root-certificate-store warning, which is unrelated to this UI.

Fresh Map infrastructure validation on 2026-08-25:

- Godot 4.7 editor/project scan completed without Map-related parser or missing-resource errors.
- `Tests/MapScreenTest.tscn`: 8 passed / 0 failed. Coverage confirms the empty hierarchy, absence of TileMapLayer/TileSet/static Map data/local HUD, fixed rectangular `6200 x 4200` limits, unlocked startup, all-edge clamping, fixed zoom, desktop left-mouse drag, one-finger touch drag, and sensitivity `2.0`.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 9 passed / 0 failed. Coverage confirms one shared top/navigation HUD, Map/Family Tree active states, Family Tree-only time controls, real Main input dispatch to Map camera, repeated screen reuse, and no duplicate UI accumulation.
- Real-renderer 1080 x 1920 capture `Tests/Artifacts/map_empty_navigation.png` confirms the existing 800 x 144 Family Tree navigation presentation with Map active against the empty authoring canvas.

Fresh Business Type migration validation on 2026-08-25:

- Godot 4.7 editor/project scan completed with exit code 0 and registered `MapProperty`, `BusinessModal`, and `BusinessModalDataAdapter` without parser errors.
- `Tests/BusinessManagerTest.tscn`: 25 passed / 0 failed. Coverage includes the exact unique 12-type roster, Bookshop removal, full five-level schema integrity, absent legacy visual fields, independent map/modal resolvers, level-independent map paths, simplified runtime instances, generic Auto Service/Hotel/Cruise purchase-construction-upgrade-slot lifecycles, and Cruise-versus-Stadium cost/expense comparisons.
- `Tests/BusinessEconomyTest.tscn`: 8 passed / 0 failed; existing performance tiers, gross, fixed expense, net, and monthly settlement behavior remains unchanged.
- `Tests/BusinessModalIntegrationTest.tscn`: 2 passed / 0 failed; the adapter uses `modal_visual_path` at Levels 1 and 5, and an absent modal PNG leaves the image empty without a map-art fallback or crash.
- `Tests/FamilyCandidateTest.tscn`, `Tests/WorkerAssignmentFlowTest.tscn`, `Tests/WorkerNPCRetirementTest.tscn`, and `Tests/WorkerNPCSlotTest.tscn`: 28 passed / 0 failed after removing obsolete visual state from their runtime fixtures.
- Supplemental `Tests/MapScreenTest.tscn`: 7 passed / 1 failed because its empty-map assertion conflicts with the already-authored `TileMapLayer` content currently present in `UI/Map.tscn`. The Business Type migration did not modify Map layout or that test.

Fresh Map runtime bugfix validation on 2026-08-28:

- Real editor F5 from `Scenes/MainMenu/MainMenu.tscn` reproduced the original failures before the repair: Map drag changed the Map camera position but the viewport still used the Family Tree camera; returning to Family Tree left building sprites visible through non-CanvasItem grouping nodes.
- `Tests/MapScreenTest.tscn`: 9 passed / 0 failed. Coverage confirms the authored layer structure, continuous CanvasItem visibility containers, fixed `6200 x 4200` limits, all-edge clamping, fixed zoom, mouse drag, one-finger touch drag, and sensitivity `2.0`.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 9 passed / 0 failed. Coverage now checks the actual viewport camera, disables the inactive camera, verifies MapWorld/Backdrop/building canvas items are hidden on Family Tree, and confirms screen/HUD instance reuse.
- Post-fix editor F5 and Remote Scene Tree verification confirmed visible two-axis Map pan, unchanged wheel zoom, clean Map to Family Tree rendering, repeated Map/Family Tree reuse with one MapScreen and one shared HUD, and no new parser/runtime, invalid-path, null-instance, or duplicate-signal errors. Family Tree camera code was not modified.

Fresh authored Map property/gameplay-routing validation on 2026-08-28:

- Canonical GDD v3.6 D-131 through D-136 and the approved footprint table were checked before implementation; the implemented footprints match the canonical values, and School/Skyscrapers remain non-interactive `city_decor`.
- Godot 4.7 editor/project scan completed with exit code 0 and no Map property, Main, or BusinessModal parser/resource errors.
- `Tests/MapScreenTest.tscn`: 19 passed / 0 failed. Coverage includes the 52/10/6 category counts, unique stable IDs, authoritative business type IDs, authored-existing and runtime-generated visual modes, no decorative interaction, no duplicate Sprite2D creation, transformed south-anchor collisions including scaled Cruise, Business/House/Land selection, drag-threshold suppression, tag refresh, camera bounds, pan, and fixed zoom.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 11 passed / 0 failed. Coverage includes Family Tree/Map reuse and render isolation plus owned-business modal routing, unowned-business/House no-modal behavior, and one shared modal instance.
- `Tests/DynamicSaveManagerTest.tscn`: 19 passed / 0 failed with real `user://` writes; a business using `plot_id = "cafe_01"` retained the same stable Map link after save/load.
- The 68 interactive Sprite2D position/scale/texture manifest remained byte-for-byte equivalent before and after wiring (SHA-256 `8D4E91E1991DD1243DF9CA63821B378CA9C5C07D41E4EFD838C3DCED9DA7CCE9`).

Fresh Buy Building Modal validation on 2026-08-29:

- Canonical GDD v3.6 Section 11.2 was checked before implementation. The modal uses the ready-made Level 1 base cost; it does not apply the 1.40 new-construction multiplier. Potential income is the Level 1 maximum gross from active slot contributions, and monthly expense is the Level 1 fixed expense.
- Godot 4.7.1 editor scan and `Scenes/Main/Main.tscn` startup smoke both completed with exit code 0 and no BuyBuildingModal/Main parser, missing-resource, null-instance, or runtime error. The restricted headless editor still reported its environment-only certificate/editor-settings warnings.
- `Tests/BuyBuildingModalTest.tscn`: 22 passed / 0 failed. Coverage includes full-screen input blocking, reusable centered scene structure, all 12 authoritative business-type bindings, independent modal visuals, Hospital Level 1 values, insufficient funds, X-without-purchase, correct instance/plot/slot creation, single deduction, success signal, and duplicate-request prevention.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 15 passed / 0 failed. Coverage includes owned versus unowned routing, House/Land exclusion, one shared instance of each business modal, Map-pan blocking while BuyBuildingModal is open, success refresh of Map tag and shared money HUD, and automatic transition to the existing BusinessModal.
- Regression suites passed: `MapScreenTest` 19/19, `BusinessManagerTest` 25/25, `BusinessEconomyTest` 8/8, `BusinessModalIntegrationTest` 2/2, and `DynamicSaveManagerTest` 19/19 with real `user://` writes. Stable `plot_id` save/load behavior remains intact.
- Real-renderer 1080 x 1920 captures `Tests/Artifacts/buy_building_modal_hospital.png` and `Tests/Artifacts/buy_building_modal_after_purchase.png` verify the dimmed authored Map composition, Hospital purchase presentation, post-purchase balance change, and automatic owned BusinessModal handoff.

Fresh MapPropertyTag readability, interaction, and staffing-state validation on 2026-08-29:

- Canonical GDD v3.6 business staffing and reusable Map property-tag requirements were checked before implementation. The work adds no gameplay value, ownership rule, or save field.
- `MapPropertyTag` now renders a 24 px title and 20 px state line in a 240 x 92 full-card target. Understaffed owned businesses use the warning treatment; fully staffed owned businesses and unowned `For Sale` properties use the normal treatment. House and Land state/selection behavior is unchanged.
- Business footprint diamonds remain generated from their authored visuals but are no longer input-pickable. A full tag-card tap routes the stable property ID, a drag beyond 14 px does not select, and consumed tag pointer events do not reach Map camera pan.
- `MapScreen` now reacts to the existing `BusinessManager` family-character slot, Worker NPC slot, business-created, and business-upgraded signals. It resolves the stable `plot_id` and re-reads current runtime slots, so assignment and removal update the displayed count without reopening Map; `Main` also refreshes after shared-modal close as a safe boundary fallback.
- `Tests/MapScreenTest.tscn`: 27 passed / 0 failed. New coverage checks effective 24/20 px rendering, real-viewport full-card business selection, disabled business-footprint selection, unchanged House/Land routing, tag drag suppression, real viewport input isolation from Map pan, `0/3 -> 1/3 -> 3/3 -> 2/3` event-driven staffing refresh, warning/normal transitions, unowned `For Sale`, and the existing authored-map invariants.
- Regression suites passed: `MainFamilyTreeIntegrationTest` 15/15, `BuyBuildingModalTest` 22/22, `BusinessManagerTest` 25/25, `BusinessEconomyTest` 8/8, `BusinessModalIntegrationTest` 2/2, `WorkerAssignmentFlowTest` 7/7, `WorkerNPCSlotTest` 7/7, and `DynamicSaveManagerTest` 19/19 with real `user://` writes. Stable business `plot_id` save/load remains intact.
- The real Godot 4.7.1 renderer produced the 1080 x 1920 capture `Tests/Artifacts/map_property_tag_readability.png`; it verifies the normal and red warning treatments in the unchanged authored Map composition. This pass did not edit `UI/Map.tscn`, business sprites, building transforms, or JSON/save schemas.

Fresh BuyBuildingModal and MapPropertyTag visual/UX follow-up on 2026-08-29:

- Canonical GDD v3.6 Sections 11 and 13.1/D-136 were rechecked. This follow-up changes presentation only and introduces no purchase, staffing, ownership, economy, JSON, or save-schema rule.
- Insufficient funds continue to disable the Buy Building CTA while leaving its acquisition price visible. The redundant `Not enough money` helper text was removed from every affordability path; backend affordability validation remains in place. The feedback row stays reserved for actual unavailable-property or generic purchase failures and is hidden when empty.
- `MapPropertyTag` now guarantees geometric center alignment: equal 18 px horizontal and 11 px vertical margins, a full-width centered VBox, full-width title/state labels, and centered vertical content. The understaffed StyleBox uses a clearly visible pastel-red fill (`#FCC8C3FA`) and stronger red border; fully staffed and unowned `For Sale` states retain the normal cream style.
- `Tests/BuyBuildingModalTest.tscn`: 22 passed / 0 failed. Coverage confirms a visibly distinct disabled CTA, visible price, hidden/empty affordability feedback, and unchanged backend rejection with no deduction or business creation.
- `Tests/MapScreenTest.tscn`: 28 passed / 0 failed. Coverage now proves both label centers equal the card's geometric center, warning states use the red filled StyleBox for `0/3`, `1/3`, and `2/3`, `3/3` returns to the normal StyleBox, and unowned `For Sale` remains normal. Existing click, drag, pan-isolation, House/Land, authored-sprite, and stable-ID checks remain green.
- Routing regressions passed: `MainFamilyTreeIntegrationTest` 15/15 and `BusinessModalIntegrationTest` 2/2. The Godot 4.7.1 editor scan completed without parser or resource errors; restricted-environment certificate/editor-settings warnings remain non-project warnings.
- Real-renderer 1080 x 1920 captures `Tests/Artifacts/buy_building_modal_insufficient_funds.png` and `Tests/Artifacts/map_property_tag_readability.png` visually confirm the simplified disabled modal and the centered, filled warning tag. Authored Map layout, property selection routing, business sprites, and `UI/Map.tscn` were not changed in this follow-up.

## Documentation Follow-up Rule

Fresh House system validation on 2026-08-31:

- Canonical Google Docs GDD v3.6 Section 13.2 and D-145 were read before implementation. `docs/PENDING_DECISIONS.md` contained no newer House decision.
- Godot 4.7.1 editor scan and Main scene smoke completed without House parser, missing-resource, null-instance, or runtime errors.
- `Tests/HouseManagerTest.tscn`: 55 passed / 0 failed after final query/cost coverage. It covers starting ownership/Head/one-slot occupancy, every level/cost/expense, one-slot and one-role constraints, life-stage rules, employment independence, slot-relative tiers, importance/weighting, score/status thresholds and clamping, perk recalculation/IDs, Unhoused monthly behavior, explicit removal, upgrades, death cleanup, save restoration, ready-made purchase, and monthly expense deduplication.
- `Tests/HouseModalTest.tscn`: 15 passed / 0 failed. It verifies exact-instance binding, input blocking, real summary/role/perk/upgrade data, immediate signal refresh, information-layer isolation, affordability, and close behavior.
- `Tests/MainFamilyTreeIntegrationTest.tscn`: 17 passed / 0 failed, including exact owned-House routing and separation from the unowned purchase flow. `Tests/MapScreenTest.tscn`: 28 passed / 0 failed.
- Regression suites passed: `EconomyManagerTest` 7/7, `BusinessEconomyTest` 8/8, `BusinessManagerTest` 25/25, `BuyBuildingModalTest` 22/22, `BusinessModalIntegrationTest` 2/2, `ItemManagerTest` 189/189, `FamilyCreationTest` 5/5, `DynamicSaveManagerTest` 19/19, and `NewGameCharacterSelectionTest` 18/18. Save-writing suites used an isolated writable Godot user-data directory because the restricted runner cannot write its default Windows `user://` location.
- The real OpenGL renderer produced `Tests/Artifacts/house_modal_reference.png` at 1080×1920. Visual review confirmed the approved cream hierarchy, existing House/portrait/status/info/coin assets, readable role/stat/perk text, scroll-owned household content, and fixed upgrade footer without Map input leakage.

Fresh authoritative House Modal visual-reference correction on 2026-08-31:

- Canonical Google Docs GDD v3.6 D-146 was read before the correction. The matching authoritative-reference rule was added to repository-wide `AGENTS.md` because it was not previously present there.
- The current modal was rendered through the production Main -> Map -> owned House path at 1080 x 1920 before editing, compared section by section with the approved `house-screen-1080.jpg`, then rendered and compared again after each correction pass.
- `HouseModal` now matches the approved outer bounds, rounded modal geometry, blue-to-cream header gradient, 24 px content inset, header illustration/title/detail/close placement, 119 px summary block, summary column dividers, Household divider, fixed household-card rhythm, 116 px portrait/empty-slot areas, square-left/rounded-right action segments, arrow presentation, 66 px Next Upgrade building icon, and fixed upgrade footer/button geometry.
- House-specific reusable style helpers now own the asymmetric action segment, stat/perk pill padding and radius, summary/role/upgrade dividers, modal gradient, and shared rounded panels. Existing source assets are consumed unchanged; no PNG or SVG source bytes were edited.
- Dynamic gameplay content remains authoritative: the rendered test shows the selected Character's current portrait, role-relative tier, JSON-defined required stats, and D-145 Level 2 upgrade price of 35,000 rather than hard-coding the example portrait/text or the reference image's obsolete 20,000 value.
- `Tests/HouseModalTest.tscn`: 19 passed / 0 failed, including new outer-geometry, 162 px role-card, compact overflow-pill, asymmetric action-corner, and 66 px upgrade-icon assertions. Regressions passed: `HouseManagerTest` 55/55, `MainFamilyTreeIntegrationTest` 17/17, and `MapScreenTest` 28/28.
- The final real OpenGL render is `Tests/Artifacts/house_modal_reference.png`. Final visual comparison found no remaining avoidable layout/style discrepancy; only data-bound sample content differs where the approved reference conflicts with current Character/House state or canonical D-145 values.

Fresh authoritative House assignment bottom-sheet replacement on 2026-08-31:

- The three user-approved House UI references supersede the previous House assignment presentation. Canonical Google Docs GDD v3.6 Section 13.2, D-145, and D-146 were rechecked before implementation; no House balance, eligibility, capacity, role-performance, perk, upgrade, Unhoused, Map, or save rule changed.
- `HouseAssignmentSheet` now uses the approved 1080 x 1920 geometry: a dimmed House Modal remains visible behind a 1000 px wide sheet beginning at y=502, with 40 px top corners, a 201 x 9 drag handle, centered title/subtitle, 24 px two-column gap, and 446 x 658 candidate cards. The previous full-height list, separate top Remove action, close button, textual tier line, and list-style candidate rows were removed.
- Candidate cards follow the established approved `WorkerSelectionSheet` card language while remaining House-specific because the Business component is coupled to business slots, source filters, hire actions, and income. Cards use the existing portrait assets without an additional mask; actual `Resources/Icons/performance-tier/S.svg` through `D.svg`; and the eight existing `Resources/Icons/stats/` SVGs. JSON-defined role-required stats receive the reference's red value emphasis.
- The current role holder appears in the candidate grid with `Remove from House`; other eligible family members use `Assign`. The existing manager operations remain authoritative, so replacement/removal refreshes House state immediately and the former occupant becomes Unhoused rather than being auto-added to a generic resident slot.
- The no-candidate state reuses the identical sheet shell and displays only `No eligible family member is available.` at the approved centered position. No warning icon, fake card, close control, or substitute visual asset was added.
- `Tests/HouseAssignmentSheetTest.tscn`: 17 passed / 0 failed. Coverage verifies sheet/card geometry, two-column structure, exact copy, existing tier/stat assets, required-stat emphasis, current-occupant removal, replacement/Unhoused behavior, and the empty state. Regressions passed: `HouseModalTest` 19/19, `HouseManagerTest` 55/55, `MainFamilyTreeIntegrationTest` 17/17, and `MapScreenTest` 28/28.
- Real OpenGL captures `Tests/Artifacts/house_assignment_eligible.png` and `Tests/Artifacts/house_assignment_empty.png` were produced through the production Main -> Map -> owned House path at 1080 x 1920 and compared directly with the two approved bottom-sheet references. `Tests/Artifacts/house_modal_reference.png` was also refreshed for the unchanged approved House Modal state.

Fresh approved property-modal and Property Tag consistency pass on 2026-08-31:

- Canonical Google Docs GDD v3.6 D-136, D-145, and D-146 were rechecked before implementation. The approved disabled House and Buy Building references controlled presentation; canonical manager values still control prices, expenses, capacity, and upgrade behavior.
- `BuyBuildingModal` now matches the approved compact 670 px card, gradient header, Level 1 hierarchy, two-column financial card, supplied employee-slot icon, information card, 20 px supporting copy, and cream bordered disabled CTA with visible price. `BuyHouseModal` uses the same structure and adapts only House image/title/level/capacity/expense/action/price content.
- House information now uses the shared gradient/cream/card language, exactly one X close action, and 21–22 px explanatory copy while preserving all existing House-system wording.
- Business and House upgrade CTAs use the same cream bordered disabled state and dimmed label/coin/price presentation. The redundant small business-type icon was removed from the Business Modal header for every business type; the main building illustration remains data-bound.
- Family-business, House, and Land building footprints are non-pickable. All three categories route stable IDs exclusively through their floating Property Tags. Land still opens no modal because its purchase/construction flow remains deferred.
- Focused tests passed: `BuyBuildingModalTest` 22/22, `BuyHouseModalTest` 3/3, `HouseModalTest` 21/21, `MapScreenTest` 28/28, `MainFamilyTreeIntegrationTest` 17/17, and `BusinessModalIntegrationTest` 2/2. Backend regressions passed: `HouseManagerTest` 55/55, `BusinessManagerTest` 25/25, and `HouseAssignmentSheetTest` 17/17.
- Real OpenGL 1080 x 1920 captures were produced for disabled Buy Building, disabled Buy House, House information, disabled House upgrade, and disabled Business upgrade states. These were visually reviewed against the supplied references through the production Main/Map paths.
- The project startup scene was also run with the real OpenGL compatibility renderer for 120 frames and exited 0 without project parser, missing-resource, or runtime errors. The Windows certificate-store warning is environment-only and unchanged.

Fresh Event System Phase 1 static-data validation on 2026-09-01:

- Canonical Google Docs GDD v3.6 Section 14 and D-147–D-153, `EVENT_SYSTEM_SPEC.md`, and `EVENT_SYSTEM_IMPLEMENTATION_PLAN.md` were read before implementation. No newer Event decision exists in `PENDING_DECISIONS.md`.
- `Resources/Json/Events/` now contains exactly the 12 approved category roots with schema version 1 and empty production pools/Events. No production Event, Job tag assignment, gameplay value, EventManager, Autoload, runtime evaluator, queue, scheduler, effect executor, save field, adapter, or UI was added.
- `EventDataRegistry` loads all required files, rejects malformed/incomplete sets, publishes lookups atomically, and exposes source/category/Event/path diagnostics. `EventDataValidator` covers the full Phase 1 root, pool, Event core, trigger/date, participant, recursive requirement, operator/value/reference, repeat/cooldown, Family Agency, presentation/resource, choice/cost, resolution/outcome/modifier, effect-whitelist, Event-reference, and static cycle contracts. Optional Job `event_tags` is valid when absent and validated as unique non-empty Strings when present.
- `Tests/EventDataValidationTest.tscn`: 63 passed / 0 failed. Coverage includes all requested valid/invalid categories and proves every approved trigger, repeat, cooldown scope/unit, requirement family (with Job tags separately fixture-validated), resolution mode, and effect family can be represented statically. Calendar validation rejects structurally valid-looking but impossible annual and ISO dates, and optional Event metadata is type-checked.
- Godot 4.7.1 headless editor project/script scan exited 0 without parser or missing-resource errors. The Windows certificate-store and restricted editor-settings warnings remain environment-only and pre-existing.
- The real project startup scene completed a 120-frame headless smoke with exit code 0 and no project parser, missing-resource, or runtime errors. Focused shared-data regressions passed for `CareerManagerTest` 14/14, `BusinessManagerTest` 25/25, and `ItemManagerTest` 189/189. `HouseManagerTest` reproduced 53/55 twice, with the existing `Caregiver follows adult-count plus Baby/Child rule` and `Full role contribution applies from five occupants` failures; no House implementation/data was changed in this phase. Event System Phase 2 was not started.

Fresh Event System Phase 2 runtime eligibility validation on 2026-09-01:

- Canonical Google Docs GDD v3.6 Section 14 and D-147–D-153, `EVENT_SYSTEM_SPEC.md`, `EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`, current managers, Phase 1 Event infrastructure, and applicable project documentation were read before implementation. No conflict or newer confirmed Event decision was found.
- `EventDataRegistry` now indexes enabled definitions by ID, domain, category, pool, and manual source. `EventInstance`, `RequirementEvaluator`, `EventRuntimeQueryProvider`, `EventParticipantResolver`, and `EventRuntimeService` implement only the approved Phase 2 runtime model, live eligibility, candidate resolution, direct/pool manual discovery, and activation-time revalidation. History, entitlement, cooldown, and completion checks use explicit read-only provider boundaries with neutral defaults until their later approved phases.
- All 47 approved requirement types route to authoritative manager data. Lifestyle uses the exact equipped-item backend score; House requirements use `HouseManager`; family businesses remain family-owned; optional Job tags are checked only when present and are never inferred; absent Item flags safely evaluate false; comparisons reject incompatible runtime types instead of coercing them.
- Participant resolution covers trigger Character, player-selected Character, spouse/child/parent/family member, existing Relationship NPC, primary House, owned Business, and explicit context entities. Minimum/maximum cardinality, duplicate prevention, entity eligibility, and activation-time revalidation produce structured, readable reasons.
- `Tests/EventRuntimePhase2Test.tscn`: 112 passed / 0 failed. `Tests/EventDataValidationTest.tscn`: 63 passed / 0 failed. Focused shared-manager regressions passed: `FamilyCreationTest` 5/5, `ParentModelTest` 3/3, `FamilyCandidateTest` 7/7, `NewGameCharacterSelectionTest` 18/18 with real `user://` writes, `CareerManagerTest` 14/14, `CareerManagerOfferTest` 6/6, `EducationManagerTest` 17/17, `RelationshipNPCManagerTest` 5/5, `RelationshipDivorceRemarriageTest` 8/8, `ItemManagerTest` 189/189, and `BusinessManagerTest` 25/25.
- `HouseManagerTest` reproduced 53/55 with exactly the same pre-existing `Caregiver follows adult-count plus Baby/Child rule` and `Full role contribution applies from five occupants` failures recorded during Phase 1; Phase 2 did not modify House code or data.
- Godot 4.7.1 headless editor/project scan and the real `Scenes/MainMenu/MainMenu.tscn` startup path both exited 0 without project parser, missing-resource, or runtime errors. The restricted environment still emitted only its pre-existing Windows certificate-store/editor-settings warnings.
- No production Event content, Job tag assignment, gameplay value, trigger dispatcher, weighted automatic selection, queue/pause runtime, scheduler, cooldown/repeat persistence, resolution/outcome/effect execution, save field, adapter, UI, or Autoload was added. Discovery and activation are read-only with respect to gameplay state. Phase 3 was not started.

Fresh Event System Phase 3 timing/orchestration validation on 2026-09-01:

- Canonical Google Docs GDD v3.6 Section 14 and D-147–D-153, `EVENT_SYSTEM_SPEC.md`, `EVENT_SYSTEM_IMPLEMENTATION_PLAN.md`, the completed Phase 1–2 implementation/tests, all named managers, Autoload ordering, and applicable repository documents were rechecked before implementation. No conflict or newer confirmed Event decision was found.
- `EventManager`, `GameCalendar`, `EventCalendarTriggerEvaluator`, and `EventPoolSelector` implement the complete Phase 3 boundary. Minimal adapters cover existing Character birth/death, Education due/major request, House state/upgrade, and family-Business create/upgrade/role signals; the generic semantic API supports other names without falsely mapping incomplete Career/Relationship signals. Time is Gregorian and cooldown/schedule math never substitutes fixed 30-day months or 365-day years.
- `Tests/EventRuntimePhase3Test.tscn`: 115 passed / 0 failed. `Tests/EventDataValidationTest.tscn`: 63 passed / 0 failed. `Tests/EventRuntimePhase2Test.tscn`: 112 passed / 0 failed.
- Focused regressions passed: `HouseManagerTest` 56/56; `FamilyCreationTest` 5/5; `ParentModelTest` 3/3; `FamilyCandidateTest` 7/7; `NewGameCharacterSelectionTest` 18/18 with real `user://` writes; `CareerManagerTest` 14/14; `CareerManagerOfferTest` 6/6; `EducationManagerTest` 17/17; `RelationshipNPCManagerTest` 5/5; `RelationshipDivorceRemarriageTest` 8/8; `ItemManagerTest` 189/189; and `BusinessManagerTest` 25/25. This is 643 passing assertions and zero test failures across the requested matrix.
- Godot 4.7.1 headless editor/project scan and the real startup scene path both exited 0 without project parser, missing-resource, or runtime errors. The restricted run's Windows certificate-store/editor-settings warnings remain environment-only.
- Phase 3 performs no outcome resolution or gameplay effects, creates no final story history, does not add Event fields to `SaveManager` or change save version 5, creates no Event/participant/Lifestyle/Agency/Relationship/Education UI, and leaves all 12 production category files empty. Phase 4 was not started.

After code or data changes, update this file. Also update `ARCHITECTURE.md` for responsibility/dependency changes, `DATA_SCHEMA.md` for schema/save changes, and `PENDING_DECISIONS.md` for confirmed decisions not yet synchronized to the canonical GDD.
