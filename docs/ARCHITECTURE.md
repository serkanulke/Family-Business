# Family Business Architecture

## Scope and Evidence

This document describes the repository state inspected through 2026-08-23 at branch `main`, commit `86a220c` (`Ui elements`), plus the current working-tree Item List / Shop and Map integrations. It is based on `project.godot`, the GDScript files, JSON resources, scenes, UI files, and test scenes present in the working tree. It does not reproduce or reinterpret the canonical GDD.

The working tree already contained modified and untracked project assets before these support documents were added. Those files were inspected as current repository state and were not changed by this documentation task.

## Project Shape

- Engine configuration: Godot 4.7, mobile renderer, Jolt Physics.
- Display baseline: 1080 x 1920 with `canvas_items` stretch and `expand` aspect.
- Startup scene: `res://Scenes/MainMenu/MainMenu.tscn`.
- Gameplay scene: `res://Scenes/Main/Main.tscn`; it owns the persistent Family Tree instance and lazily instantiates the Map screen when requested.
- Persistent runtime state is held by autoload managers and serialized by `SaveManager` to `user://saves`.
- Static gameplay data is primarily loaded from `res://Resources/Json` into manager-owned arrays and dictionaries.

## Repository Layout

| Path | Observed responsibility |
| --- | --- |
| `Autoload/` | Global gameplay state and manager logic. |
| `Resources/Json/` | Static definitions, empty seed collections, and several currently unreferenced data files. |
| `Scenes/` | Main menu, new-game modal, load-game UI, main gameplay root, family tree, character nodes, and business modal scenes. |
| `UI/CharacterCard/` | Runtime-built, scrollable Character Card overlay and its manager-backed presentation script. |
| `UI/ItemListShop/` | Reusable Accessory/Outfit/Vehicle Item List bottom sheet, display-only item cards, information panel, filter bar, and filename/path-based Accessory category classifier. |
| `Scripts/FamilyTree/` | Family-tree layout, rendering, character nodes, link nodes, and camera behavior. |
| `Scripts/Map/` | Isometric coordinate conversion, authored map loading/validation, property/tag presentation, camera input, and map-screen integration. |
| `UI/Map/` | Reusable floating property-tag scene used by map properties. |
| `Scripts/UI/Business/` | Business modal, manager-to-UI adapter, and worker-flow connector. |
| `UI/Business/WorkerSelection/` | Worker source selection and candidate assignment flow. |
| `Tests/` | Standalone Godot test scenes and scripts for manager logic and UI integration. |
| `Resources/` | Fonts, icons, portraits, school images, and building images. |
| `Data/Saves/` | Present but empty in the inspected tree; runtime saves use `user://saves` instead. |
| `Themes/` | Business modal, Character Card, and Item List / Shop theme resources. |

Several directories under `Scenes/` and `Scripts/` exist but are currently empty, including building/event/manager-oriented placeholders.

## Autoload Managers

Autoload order in `project.godot` is significant because later managers use earlier ones during `_ready()` and at runtime.

| Autoload name | File | Observed responsibility and collaborations |
| --- | --- | --- |
| `GameManager` | `Autoload/GameManager.gd` | Global settings, family name, money and diamonds, plus new-game orchestration. Resets time and characters, creates the starting character, and assigns an external company when applicable. |
| `TimeManager` | `Autoload/TimeManager.gd` | Simulation date, pause/play, x1/x2/x3 speed, and `date_changed` signaling. Starts paused. |
| `CharacterManager` | `Autoload/CharacterManager.gd` | Loads characters, majors, and jobs; owns playable and relationship-character records; calculates age/life stage; handles creation, genetics, parent links, retirement, pensions, and death checks. |
| `EducationManager` | `Autoload/EducationManager.gd` | Loads schools; queues birthday education events; handles enrollment, cost/stat effects, graduation, university choice, major selection, and time pause/resume around queued events. |
| `CareerManager` | `Autoload/CareerManager.gd` | Loads companies; matches jobs and companies; checks eligibility; generates, accepts, and rejects external job offers; maintains offer cooldowns. |
| `EconomyManager` | `Autoload/EconomyManager.gd` | Applies the new-construction multiplier, pays eligible external salaries, and settles family-business income and expense on the first day of a month. |
| `BusinessManager` | `Autoload/BusinessManager.gd` | Loads family-business instances and type definitions; creates and upgrades businesses; manages family/Worker NPC slots; computes worker performance and monthly business results. |
| `NPCManager` | `Autoload/NPCManager.gd` | Owns the separate Worker NPC pool; generates workers from configuration, filters and ranks candidates, detects assignment, and retires workers. |
| `RelationshipNpcManager` | `Autoload/RelationshipNPCManager.gd` | Creates relationship candidates as character records, generates their education/career history, converts candidates into family members, handles divorce/remarriage rules, and creates biological/donor/adopted children through `CharacterManager`. |
| `ItemManager` | `Autoload/ItemManager.gd` | Loads the generated stable item catalog, owns the shared family inventory and character-specific equipment assignments, creates separate Accessory/Outfit/Vehicle monthly stocks, validates purchases, removes expired items, calculates equipped-item Lifestyle, and exposes slot-filtered UI queries. |
| `SaveManager` | `Autoload/SaveManager.gd` | Saves and restores a versioned snapshot of all manager state including `ItemManager`, creates dynamic save IDs, lists/deletes saves, and requests deferred autosaves from gameplay signals. |

## Runtime Flow

1. The main-menu scene starts the application and pauses simulation time.
2. A new game is created through `NewGameModal` and `GameManager`; a selected gender/skin tone and generated names feed `CharacterManager`.
3. Managers load static JSON definitions during `_ready()` and keep mutable gameplay state in memory.
4. `TimeManager.date_changed` drives lifecycle, education, career, Worker NPC, and economy checks.
5. Manager signals update the family-tree HUD and trigger deferred autosaves.
6. `SaveManager` serializes manager state as version 4 JSON under `user://saves` and restores it without emitting ordinary gameplay signals mid-load. Version 2 snapshots remain loadable; version 3 global item stock is migrated into slot-specific stock arrays.

## UI and Scene Boundaries

- `Scenes/MainMenu/MainMenu.tscn` provides Continue, Load Game, New Game, and Settings controls. Continue and Load Game are connected to `SaveManager`; New Game opens `NewGameModal`. Settings currently emits a signal only.
- `Scenes/LoadGame/LoadGameScreen.tscn` replaces its three legacy example slots at runtime with save summaries from `SaveManager`.
- `Scenes/Main/Main.tscn` owns a persistent `FamilyTreeScreen` and uses `MainScreenController` to lazily instantiate `UI/Map.tscn`. Screen changes toggle visibility and processing instead of rebuilding the Family Tree, so its state is preserved.
- `FamilyTreeScreen` builds its visual tree and HUD at runtime, listens to manager signals, and controls time speed. Its Family Tree and Map navigation controls request screen changes through the main controller. Lifestyle remains visual-only because no Lifestyle screen exists.
- `FamilyTreeScreen` instances `CharacterCard` once and opens that same instance when a canonical or reference portrait emits `character_selected`; no scene change or Family Tree replacement occurs. The Character Card scene uses CanvasLayer 30 above the Family Tree HUD layer, with a Full Rect `CharacterCardModal` input-blocking Control, a 76% black dim layer, and a separate centered/inset panel containing the existing scrollable content.
- `CharacterCard` reads existing character, portrait, career, education, relationship, event-log, family-business, and ItemManager data without introducing a second character model. Its Lifestyle stars, equipped count, and three item-slot thumbnails are derived from the selected character's equipped ItemInstances; each thumbnail resolves the catalog definition's existing `image_path`. It listens to `ItemManager.equipment_changed` for the selected character, so Wear/Replace/Unequip updates the slot presentation without per-frame polling or reopening the card. Accessory/Outfit/Vehicle controls emit `item_slot_requested(character_id, slot)` whether they show an empty icon or thumbnail; `FamilyTreeScreen` routes that context into its single `ItemListBottomSheet` instance, hides the Character Card while the sheet is open, and restores the same card context after close. Cosmetic class labels remain hidden because no class-label resolver is defined.
- `ItemListBottomSheet` is a CanvasLayer 40 overlay above the Character Card. It owns a Full Rect input blocker, 76% dim layer, cream rounded sheet beginning at y=320 in the 1080 x 1920 reference viewport, and a vertical ScrollContainer with two-column item grids. One reusable instance is reopened with a fresh `target_character_id` and `slot_context`; Accessory, Outfit, and Vehicle arrays are filtered before rendering, and only Accessory exposes the Ring/Glasses/Watch/Necklace filter bar.
- The Item List / Shop UI remains presentation and interaction routing rather than owning gameplay state. `ItemListShopCard` emits mode-specific Buy/Wear/Unequip actions; `FamilyTreeScreen` preserves character and slot context and delegates the operation to `ItemManager`. `ItemManager.get_owned_items(slot)` projects the shared family inventory as currently available items by subtracting the family-wide equipped `instance_id` set; it never removes equipped instances from `family_inventory` and never filters by catalog `item_id`. The sheet defensively applies the same instance-level exclusion to bound/preview data, refreshes after inventory, equipment, or monthly-stock signals, and computes counts after this projection. Test-only bound/preview data explicitly replaces the production provider and cannot become production state.
- Accessory conceptual filtering uses `AccessoryCategoryClassifier` over canonical resource paths, item IDs, and display names. It does not add a persistent `subtype` field or change save/data schemas. Item durability presentation is derived from `purchase_date` and `expiration_date`; Heirloom items bypass that progress calculation and retain their independent rarity.
- `Scripts/Items/ItemCatalogGenerator.gd` scans the existing `Resources/Items` slot/rarity folders and writes stable definitions to `Resources/Json/ItemCatalog.json` through the explicit editor/development entry point `GenerateItemCatalog.gd`. Catalog generation is not run when a shop opens or a save loads. It deterministically calculates GDD v3.4 Money and Diamond prices from slot, rarity, Lifestyle, lifespan, and Heirloom status; the generated catalog records `pricing_status = configured_gdd_v3_4`.
- `ItemManager` holds three monthly stock arrays under one manager-owned state: Accessory, Outfit, and Vehicle each select up to six distinct candidates from their own pool. `TimeManager.date_changed` triggers refresh only on day 1, purchase removes the item only from its slot stock without same-month refill, and `SaveManager` persists all arrays plus their shared month key. New-game initialization creates the current month's stock before the automatic save.
- Purchase validation checks stock membership and both canonical GameManager balances before any deduction, creates an ItemInstance reference, and prevents a repeated signal from purchasing an already removed stock item. Equip validation enforces character, slot, inventory, expiration, and single-owner constraints. Lifestyle is the equipped Accessory + Outfit + Vehicle definition values capped at 100; expiration clears both inventory and any character assignment.
- `Scripts/FamilyTree/FamilyTreeLayout.gd` derives positions and visible relationship links from `parent_ids`, `partner_id`, and family membership without mutating character data.
- `Scenes/UI/Business/BusinessModal.tscn` uses a data adapter and connector to display manager state, upgrade a business, and open family/Worker NPC assignment sheets.
- `UI/Map.tscn` is a production 2:1 isometric screen driven by the authored `Resources/Json/Map.json`. It separates main ground, roads, plot/building ground, coast, 50 x 25 detail paths, environment decoration, properties, HUD, and modal layers. The main 200 x 100 grid and detail grid share the exact 4 x 4 subdivision relationship defined by GDD v3.5 D-131.
- `MapScreen` creates TileMapLayer atlas sources from existing map assets, validates authored property placement and counts before rendering, and positions every building/property visual at the south footprint vertex. Tall objects and buildings use Y sorting; static map content is not procedurally generated.
- `MapProperty` owns one diamond-shaped input area and one reusable `MapPropertyTag`. Owned family-business plots resolve `business_instance_id`/`plot_id` through `BusinessManager` and open the existing `BusinessModal`; tag occupancy refreshes from manager signals rather than per-frame polling.
- Unowned property selection emits `property_purchase_requested`. Business creation is delegated to `BusinessManager` only when an approved Level 1 definition exists. House and land purchases, purchase confirmation UI, and balancing for Auto Service, Cruise, and Hotel remain explicitly outside this screen rather than being invented locally.
- `MapCamera` supports mouse/touch pan, wheel zoom, and pinch zoom. Its limits are derived from authored map content bounds and include viewport margins, so navigation remains bounded at every zoom level.

## Important System Boundaries

### Worker NPCs and Relationship NPCs

These are separate systems:

- Worker NPCs are lightweight records owned by `NPCManager`, use string IDs such as `npc_000001`, store stats inside a nested `stats` dictionary, and exist for family-business staffing.
- Relationship NPCs are full character dictionaries owned in `CharacterManager.characters`, use integer `character_id` values, and are tracked by `RelationshipNpcManager.relationship_candidate_ids` while they are candidates.

### Family Businesses and External Companies

- Family-owned business instances are owned by `BusinessManager` and staffed through business slots.
- External career companies are static definitions loaded by `CareerManager` from `Companies.json` and referenced through `company_id` on character records.
- Assigning a family member to a family-business slot interacts with external career state; the two concepts are not the same data model.

## Tests Present

The repository contains standalone test scenes for character/family creation, parent links, relationship candidates and divorce/remarriage, Worker NPC generation/assignment/retirement, business rules and economy, education, career offers, save/load behavior, the family-tree layout/camera/UI, authored map validation/rendering, new-game selection, and business modal integration.

The Character Card, Main/Family Tree/Map integration, Item List / Shop, business, and Map tests executed for the current working tree are recorded in `DEVELOPMENT_STATUS.md`.
