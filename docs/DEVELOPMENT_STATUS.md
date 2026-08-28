# Family Business Development Status

## Snapshot

- Inspected: 2026-08-28
- Branch: `main`
- HEAD: `86a220c` (`Ui elements`, 2026-08-18)
- Engine configuration: Godot 4.7
- Startup scene: `Scenes/MainMenu/MainMenu.tscn`

This status is derived only from files present in the inspected working tree. The working tree already contained user changes and untracked assets; unrelated files were preserved. Fresh Character Card, Item List / Shop, Map, business, and main-scene validation results are recorded below; other test scenes remain inventory evidence unless separately noted.

## Status Definitions

- **Implemented:** executable manager or UI behavior and integration are present in the repository; related tests often exist.
- **Partial:** substantial code exists, but the player-facing flow, broader integration, or scene coverage is incomplete.
- **Not implemented / not found:** only a stub, data-only placeholder, visual-only control, or no consuming code was found. This is a repository observation, not a statement about GDD scope.

## Implemented

| System | Repository evidence |
| --- | --- |
| Core game and family state | `GameManager` owns settings, family name, money, diamonds, and new-game orchestration. |
| Simulation time | `TimeManager` advances calendar dates and supports pause plus x1/x2/x3 speed; family-tree HUD controls are connected. |
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
| Business staffing modal flow | Business data adapter, financial/staff display, upgrade action, worker-type choice, candidate sheets, assignment, replacement, and integration tests exist. The adapter uses only `modal_visual_path`; missing modal assets are handled without crashing or falling back to map art. |
| Save/load/autosave | Version 4 manager snapshot includes item inventory, equipment, and all three slot stocks. Version 2 loading and Version 3 global-stock migration remain compatible. Unique save IDs, dynamic save listing, Continue/Load Game flows, delete API, and deferred autosaves tied to manager signals exist. |
| Main menu and load-game UI | Main menu, new-game modal, runtime save-slot list, continue/load navigation, and gameplay scene transitions exist. |
| Authored Map and runtime infrastructure | `UI/Map.tscn` contains manually authored TileMapLayer ground/road/environment content and building sprites inside a `6200 x 4200` rectangular MapWorld. The fixed-zoom camera supports desktop mouse and one-finger touch drag; wheel zoom remains disabled. This repair changed only screen/camera/container infrastructure, not TileSets, placement, or artwork. |
| Family Tree / Map navigation | Main owns the persistent Family Tree, lazily created and reused Map, and one shared Main HUD. Screen changes now explicitly isolate visibility, processing, CanvasLayer state, and the active Camera2D: only the active screen camera remains enabled/current. Date/Money/Diamond and navigation do not duplicate, while Family Tree time controls remain Family Tree-only. |

## Partial

| System | Missing or limited integration observed |
| --- | --- |
| Overall gameplay shell | Family Tree and Map are integrated. Lifestyle remains a visual navigation entry because no Lifestyle screen exists. |
| Family-business player flow | `BusinessManager`, `BusinessModal`, and reusable Map property/tag components support all 12 configured business types, but the currently authored building sprites are not instantiated as `MapProperty` records. Map property/business wiring remains deferred while the project owner manually authors the city. |
| Education player flow | Backend emits education and major-selection events, but no player-facing education choice scene or signal consumer was found outside tests/autosave hooks. |
| Career player flow | Backend emits job offers, but no player-facing offer scene or signal consumer was found outside tests/autosave hooks. |
| Relationship player flow | Candidate/family logic is extensive, but no player-facing relationship event or candidate-selection UI was found. |
| Settings | Settings values and setter methods exist in `GameManager`, and menu/HUD settings visuals exist, but no settings screen or connected editing flow was found. |
| Building visuals | Manually placed building and road artwork exists in `UI/Map.tscn`. No artwork, TileSet, or placement was created or modified by this runtime repair. |
| House and land ownership flow | Authored properties, tags, selection, sizes, fit validation, and scattered For Sale state exist. No House/Land manager, save schema, approved prices, purchase confirmation, or construction-selection UI was found, so these selections emit requests but do not mutate ownership. |
| Legacy Bookshop save migration | Bookshop is removed from current `BusinessTypes.json` and authored map data. No GDD decision identifies how an already purchased Bookshop in an older save should be converted or compensated, so existing save records are preserved as unsupported legacy instances rather than silently deleted or mapped to an unrelated type. |
| Lifestyle class label | Equipped-item Lifestyle score and star presentation are implemented. The optional cosmetic class label remains hidden because no canonical label resolver/text set was found; this does not block Lifestyle gameplay. |
| Playable portrait asset coverage | Canonical discovery/resolution and missing-asset fallback are implemented, but the inspected asset tree contains only `Male/Mixed/YoungAdult/character_001.png` and `Female/Light/YoungAdult/character_001.png`. The other gender/skin/life-stage pools are absent, so affected Characters correctly use `default_avatar.png` and log development warnings until matching assets are supplied. |

## Not Implemented / Not Found

| Area | Repository evidence |
| --- | --- |
| Lifestyle screen | The family-tree HUD draws a Lifestyle navigation entry, but no Lifestyle scene, script, or click behavior was found. |
| Housing system | `House.json` contains one example record, but no manager, scene, or code reference was found. |
| Flag system | `Flag.json` and character `flag_ids` exist, but no manager or consuming behavior was found. |
| `GameData.json` runtime integration | The file exists, but no code or scene reference was found. Active state is held by autoload managers and save snapshots. |
| `Avatar.json` integration | The file exists, but no code or scene reference was found; current portrait resolution uses resource paths and `CharacterManager`. |
| `RelationshipNPC.json` integration | The empty uppercase-named collection exists, but no code or scene reference was found. Relationship candidates are stored in `CharacterManager.characters`. |

## Test Inventory

The repository contains 34 `.tscn` test scenes covering:

- business manager, economy, modal integration, family and Worker NPC assignment;
- Worker NPC generation, slot rules, and retirement;
- career eligibility/offers and education events;
- relationship candidates, marriage/divorce/remarriage, adoption/donor conception, and parent links;
- family-tree layout, complex structures, relationship display, camera, pan bounds, runtime UI, and main-scene integration;
- new-game character selection and dynamic/runtime save behavior.
- portrait-folder mapping, skin-only genetics, persistent variants, parent exclusions, aging, legacy path recovery, donor/adoption behavior, and missing-asset safety;
- Character Card data binding, GDD Lifestyle star thresholds, item-slot signal routing, and Family Tree modal integration;
- Item List / Shop slot isolation, Accessory conceptual filters, card pricing/presentation, durability derivation, interaction context, modal behavior, scroll/expand behavior, and rendered reference comparison.

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
- `Tests/DynamicSaveManagerTest.tscn`: 17 passed / 0 failed.
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

## Documentation Follow-up Rule

After code or data changes, update this file. Also update `ARCHITECTURE.md` for responsibility/dependency changes, `DATA_SCHEMA.md` for schema/save changes, and `PENDING_DECISIONS.md` for confirmed decisions not yet synchronized to the canonical GDD.
