# Family Business — Map Art & Building Standard

**Status:** current production geometry/asset standard  
**Gameplay authority:** GDD v3.8 Sections 13 and 20  
**Runtime:** Godot 2D, portrait mobile

This document standardizes Map/building geometry and asset preparation. It does not authorize new Map mechanics or building types.

## 1. Projection

Family Business uses a fixed **2:1 isometric/dimetric game projection**.

Main grid:

- tile width: **200 px**
- tile height: **100 px**
- ratio: **2:1**
- vertical building edges remain screen-vertical
- ground-plane axes follow the same 2:1 projection everywhere

Grid conversion:

```text
screen_x = (grid_x - grid_y) * 100
screen_y = (grid_x + grid_y) * 50
```

Equivalent:

```text
screen_x = (grid_x - grid_y) * TILE_WIDTH / 2
screen_y = (grid_x + grid_y) * TILE_HEIGHT / 2
```

A secondary **50 × 25** detail grid is aligned to the exact same origin/axes as a 4 × 4 subdivision of one 200 × 100 main tile.

## 2. Structural Axis Rule

Building architecture must remain consistent with the main isometric axes:

- roof edges
- wall bases
- window rows
- awnings
- parapets
- garage lintels
- major façade divisions

Vertical edges stay vertical:

- wall corners
- columns
- door/window sides
- towers
- pipes/sign supports

Do not rotate a finished building to fake compatibility with the Map. Correct the building geometry.

## 3. Approved Footprints

Current authoritative main-grid footprints:

| Object | Footprint |
| --- | --- |
| House | 2×2 |
| Cafe | 2×2 |
| Bank | 2×2 |
| Gym | 2×2 |
| Restaurant | 2×2 |
| Auto Service | 2×2 |
| Cruise | 1×3 |
| Hotel | 3×2 |
| Tech Company | 3×2 |
| Skyscrapers | 3×2 |
| Hospital | 3×3 |
| School | 3×3 |
| Warehouse | 4×3 |
| Factory | 4×4 |
| Stadium | 4×4 |

City Hall is not current city content.

School and Skyscrapers are `city_decor` and non-purchasable. Hospital is a normal purchasable family business. Cruise is a 1×3 open-sea property.

Do not use older footprint tables that list Gym/Restaurant as 3×3, Factory as 4×3, or other superseded dimensions.

## 4. Projected Footprint Bounds

For an `N × M` footprint:

```text
projected_width  = (N + M) * 100
projected_height = (N + M) * 50
```

Examples:

| Footprint | Projected width | Projected height |
| --- | ---: | ---: |
| 1×3 | 400 | 200 |
| 2×2 | 400 | 200 |
| 3×2 | 500 | 250 |
| 3×3 | 600 | 300 |
| 4×3 | 700 | 350 |
| 4×4 | 800 | 400 |

These are projected ground-footprint bounds, not required texture-canvas sizes.

## 5. Ground Separation

Building textures normally contain:

- building artwork;
- attached architecture;
- optional controlled contact/cast shadow;
- transparent background.

They normally do not contain:

- generic grass/asphalt;
- road tiles;
- generic sidewalk;
- unrelated trees/benches/lights;
- environment backdrop.

Ground, roads, coast, paved walks and reusable city dressing belong to separate Map layers/assets.

## 6. Business Visual Rule

Family-business artwork **does not change with level**.

Each Business type has:

- one `map_visual_path`;
- one independent `modal_visual_path`.

Upgrading changes gameplay state only: level, slots, cost, fixed expense and resulting economy.

Do not produce `business_<type>_l1/l2/l3...` replacement map sprites for current gameplay.

## 7. House Visual Rule

House gameplay has five levels, but House artwork behavior across levels is **OPEN under GDD OD-018**.

Until that decision is resolved:

- do not invent level-specific replacement House art;
- do not define a House level-file naming system;
- do not make code expect art swaps on House upgrade.

Existing House art remains usable as the current property visual.

## 8. Building Asset Naming

Use descriptive current names without obsolete level suffixes for static business art.

Examples:

```text
cafe.png
cafe_modal.png
auto_service.png
auto_service_modal.png
hotel.png
hotel_modal.png
```

Exact existing repository paths remain authoritative; do not rename assets merely to match examples.

Avoid version clutter such as `final_v2`.

## 9. Map Composition

The city is manually authored. Do not implement random building placement or automatic city generation.

Current composition rules include:

- Stadium appears once.
- Cruise appears once.
- Other approved family-business types may appear four or five times according to authored composition.
- Roughly 20–30 Houses may be used for density; only 10 are purchasable.
- Three 2×2 and three 4×4 purchasable land plots exist.
- Use existing environment assets only; do not invent missing road/parking/park/coast tiles.

Cruise is placed in open sea without an invented pier/terminal.

## 10. Road / Coast / Environment Separation

Use the existing:

- road family with sidewalks;
- road family without sidewalks;
- existing transition tiles;
- sea / sand-to-sea / sand;
- `paved_tile` / `paved_tile_small`;
- existing bicycle/environment assets where available.

Bicycle paths must not overlap normal vehicle-road tiles.

## 11. Building Anchor / Placement

Use a consistent ground-contact anchor that is reproducible from the footprint and existing Map implementation. Do not manually compensate every building with arbitrary positional corrections.

When introducing a new asset:

1. overlay it on the correct footprint;
2. verify both ground axes;
3. verify verticals;
4. compare door/window scale to approved neighboring buildings;
5. verify the Sprite can be placed without changing the canonical footprint.

## 12. Export Standard

Map building art:

- transparent PNG where the current asset pipeline uses raster building art;
- no baked UI frame;
- no full Map backdrop;
- no guide pixels;
- preserve approved isometric camera/lighting/style.

UI/simple vector assets may remain SVG according to project UI standards.

## 13. QA Checklist

### Geometry
- [ ] Ground edges use the same 2:1 axes.
- [ ] Vertical edges are vertical.
- [ ] Roof and façade perspective matches neighboring approved assets.
- [ ] Human-scale doors/windows are compatible.

### Footprint
- [ ] Asset matches the approved footprint table.
- [ ] Decorative overhang does not silently expand gameplay footprint.
- [ ] Ground is not baked into the building art unless it is an intentional building-attached feature.

### Business level behavior
- [ ] No level-specific business replacement sprite was introduced.
- [ ] Map/modal visuals remain independent.

### House level behavior
- [ ] No unapproved level-specific House replacement art was introduced.

### Export
- [ ] Transparent background where required.
- [ ] No accidental guides/background.
- [ ] Existing repository naming/path conventions are respected.

## 14. Godot Map Layer Principle

Keep the authored city separable:

```text
Map
├── Ground
├── Roads
├── Plots / property metadata
├── Buildings
├── Decorations
└── UI/property tags
```

Exact node names in the current scene are implementation details; do not restructure the Map solely to match this illustrative hierarchy.

The Map screen is authored content, not a procedural placement system.
