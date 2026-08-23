# Family Business — Map Art & Building Perspective Standard

**Status:** Canonical production standard, implemented for Map (GDD v3.5 D-131)  
**Purpose:** Keep every map building geometrically compatible before import into Godot.  
**Primary drawing tools:** Adobe Illustrator and Figma  
**Runtime target:** Godot 2D, mobile  

---

## 1. Core Projection

Family Business map buildings use a fixed **2:1 dimetric/isometric game projection**.

### Runtime grid

- Base tile width: **200 px**
- Base tile height: **100 px**
- Tile ratio: **2:1**
- Screen-space axis slope: **1 vertical : 2 horizontal**
- Screen-space axis angle: approximately **±26.565°**
- Vertical building edges: **90° / screen vertical**

### Source-art grid

For vector drawing, use a 4× working scale:

- Source tile width: **800 px**
- Source tile height: **400 px**
- Source-to-runtime ratio: **4:1**

Because Illustrator and Figma are vector-based, the source art can remain resolution-independent. The 800×400 tile is the shared construction reference, not a requirement that every exported building use the same canvas size.

---

## 2. Projection Rules

Every structural edge in a building must belong to one of three axis families.

### Axis A — X direction

- Screen direction: down-right / up-left
- Source-grid delta per tile: **(+400, +200)**
- Runtime-grid delta per tile: **(+100, +50)**

### Axis B — Y direction

- Screen direction: down-left / up-right
- Source-grid delta per tile: **(-400, +200)**
- Runtime-grid delta per tile: **(-100, +50)**

### Axis C — Height

- Screen direction: perfectly vertical
- Building height never changes the X/Y projection angle.

### Must follow Axis A or B

- roof edges
- wall bases
- window rows
- balcony edges
- awnings
- garage lintels
- platforms
- stairs aligned to the building shell
- parapets
- major façade divisions

### Must follow Axis C

- wall corners
- columns
- door sides
- window sides
- vertical signs
- drainpipes
- towers and shafts

Decorative curves and organic props may depart from the axes, but the supporting architecture may not.

---

## 3. Mathematical Grid Formula

For a runtime tile size of `200 × 100`:

```text
screen_x = (grid_x - grid_y) * 100
screen_y = (grid_x + grid_y) * 50
```

Equivalent form:

```text
screen_x = (grid_x - grid_y) * TILE_WIDTH  / 2
screen_y = (grid_x + grid_y) * TILE_HEIGHT / 2
```

For the 4× source-art grid (`800 × 400`):

```text
source_x = (grid_x - grid_y) * 400
source_y = (grid_x + grid_y) * 200
```

This formula is the authority when visual judgment and a generated image disagree.

---

## 4. Footprint System

A building occupies a rectangular area in grid coordinates even though its screen projection is a diamond/parallelogram.

Recommended footprint classes:

| Footprint | Typical use |
|---|---|
| 1×1 | kiosk, small prop, utility object |
| 2×2 | house, cafe, auto service, small bank |
| 3×2 | medium commercial building |
| 3×3 | gym, restaurant, hospital, tech company |
| 4×3 | factory, warehouse, larger hotel |
| 4×4 | stadium / major landmark |

### Correct projected footprint bounds

For an `N × M` footprint:

```text
projected_width  = (N + M) * tile_width  / 2
projected_height = (N + M) * tile_height / 2
```

Therefore, at runtime scale:

| Footprint | Projected bounding width | Projected bounding height |
|---|---:|---:|
| 1×1 | 200 px | 100 px |
| 2×2 | 400 px | 200 px |
| 3×2 | 500 px | 250 px |
| 3×3 | 600 px | 300 px |
| 4×3 | 700 px | 350 px |
| 4×4 | 800 px | 400 px |

At the 4× source-art scale, multiply these values by four.

> Important: a rectangular footprint such as 3×2 does **not** project to 600×200. Its correct 2:1 projected bounding box is 500×250 at runtime scale.

---

## 5. Building Origin / Anchor Standard

Use one universal anchor convention for every building:

### Anchor = front/south footprint vertex

The front/south vertex is the grid corner reached after traversing the full footprint width and depth from the building's back/north grid origin.

Why use this point:

- it exists for square and rectangular footprints;
- it stays stable when a building becomes taller;
- it makes Y-based draw ordering predictable;
- it avoids the ambiguity of “visual bottom center” on non-square footprints;
- it can be reproduced mathematically in Godot.

### Asset rule

In the source template, keep a locked `ANCHOR` marker at this exact footprint vertex. Before export, the marker is hidden, but the artwork is never moved relative to it.

### Godot rule

The `Building` root node is positioned at the map-space location of this front/south vertex. The Sprite2D is offset so its hidden source anchor coincides with the root node at `(0, 0)`.

---

## 6. Building Level Rules

For `Level 1`, `Level 2`, and `Level 3` variants:

- projection must remain identical;
- anchor must remain identical;
- footprint should remain identical unless gameplay explicitly changes it;
- the building may grow upward;
- roof complexity may increase;
- façade depth/detail may increase;
- small attachments may be added only if they remain within the assigned footprint or are explicitly marked as visual overhangs.

### Do not

- change the ground-plane angle between levels;
- widen the base simply because the level is higher;
- move the doorway to fake a new perspective;
- change the relative scale of windows/doors between levels without an architectural reason.

If a higher level truly needs a larger footprint, treat it as a **gameplay footprint upgrade**, not an art-only change.

---

## 7. Ground Separation Rule

Runtime building textures should normally contain:

- building artwork;
- architecture-attached objects;
- optional contact shadow / controlled cast shadow;
- transparent background.

They should normally **not** contain:

- grass field;
- road tile;
- map pavement system;
- large sidewalk patches;
- generic trees that belong to the map;
- unrelated benches/lights;
- full environment backdrop.

Ground, roads, generic pavement, and reusable environment decoration belong to separate map layers in Godot.

A building may include a dedicated entrance slab, stairs, ramp, loading bay, or building-specific landscaping when these are part of the building's footprint and design identity.

---

## 8. Illustrator Production Template

Recommended layer stack:

```text
00_GUIDES_LOCKED
    ISO_GRID
    AXIS_A
    AXIS_B
    VERTICAL_REFERENCE
    FOOTPRINT_BOUNDARY
    ANCHOR
    SAFE_EXPORT_LIMIT

01_FOOTPRINT_REFERENCE

10_BUILDING_BASE
20_BUILDING_STRUCTURE
30_WINDOWS_DOORS
40_ROOF
50_ARCHITECTURAL_DETAILS
60_PROPS_ATTACHED
70_SHADOW

90_EXPORT_CHECK
```

### Illustrator setup

1. Set document units to **pixels**.
2. Build the master grid from exact vector coordinates, not hand-drawn diagonals.
3. Draw the 2:1 diamond with straight vector segments.
4. Convert construction lines to guides where useful, or keep them on a locked non-printing layer.
5. Keep **Smart Guides** and **Snap to Point** available for structural alignment.
6. Reuse the same template file for every building instead of recreating the projection.
7. Never rotate the complete finished building to “make it look more isometric.” Correct individual geometry against the grid instead.

### Recommended master references

- `ISO_1x1`
- `ISO_2x2`
- `ISO_3x2`
- `ISO_3x3`
- `ISO_4x3`
- `ISO_4x4`

These can be saved as locked groups or symbols in the template.

---

## 9. Figma Production Template

Figma does not provide the same native arbitrary-angle guide workflow as Illustrator, so use a **locked vector guide component**.

Recommended page structure:

```text
Page: MAP ART SYSTEM
    Component: ISO_GRID_4X4
    Component: FOOTPRINT_1X1
    Component: FOOTPRINT_2X2
    Component: FOOTPRINT_3X2
    Component: FOOTPRINT_3X3
    Component: FOOTPRINT_4X3
    Component: FOOTPRINT_4X4
    Component: ANCHOR_MARKER

Page: BUILDINGS
    Frame: house_l1
    Frame: house_l2
    Frame: house_l3
    Frame: cafe_l1
    ...
```

### Figma setup

1. Put the reusable isometric grid into a component.
2. Use an instance of that component inside every building frame.
3. Lock the grid and footprint layers.
4. Keep the `ANCHOR_MARKER` instance unchanged.
5. Construct primary architecture with vectors snapped to existing grid points/edges.
6. Do not use a freehand perspective approximation for major structural edges.
7. Hide guide components before export.
8. Export the building frame as transparent PNG.

### Figma recommendation

Use Figma mainly for:

- blockout;
- proportion control;
- footprint alignment;
- UI/map composition tests;
- simpler stylized vector architecture.

Use Illustrator when a building needs:

- heavier vector path editing;
- complex roof geometry;
- precise warped details;
- more advanced vector cleanup.

Both tools must use the same master grid.

---

## 10. Export Standard

### Runtime format

- Format: **PNG**
- Background: **transparent**
- No baked UI frame
- No map background
- No accidental guide pixels

### Source vs runtime size

Keep source vectors at the 4× construction grid, but export runtime textures at the smallest size that preserves the intended visual quality on the target mobile screen.

Recommended workflow:

```text
Vector master
    ↓
4× construction reference
    ↓
export test at 2× runtime scale
    ↓
Godot visual test
    ↓
reduce to 1× where quality remains acceptable
```

Do not keep oversized textures merely because the vector master is large; mobile texture memory matters.

### Filename convention

```text
building_<type>_l<level>_<footprint>.png
```

Examples:

```text
building_house_l1_2x2.png
building_house_l2_2x2.png
building_cafe_l1_2x2.png
building_factory_l3_4x3.png
```

---

## 11. Godot Placement Logic

### Grid conversion

Example GDScript:

```gdscript
const TILE_WIDTH := 200.0
const TILE_HEIGHT := 100.0

func grid_to_screen(cell: Vector2i) -> Vector2:
    return Vector2(
        (cell.x - cell.y) * TILE_WIDTH * 0.5,
        (cell.x + cell.y) * TILE_HEIGHT * 0.5
    )
```

### Building footprint data

Each building definition should know at minimum:

```json
{
  "id": "cafe",
  "footprint": [2, 2],
  "anchor": "south_vertex"
}
```

### Placement concept

If `grid_origin` is the building's back/north footprint corner:

```gdscript
func get_building_anchor(
    grid_origin: Vector2i,
    footprint: Vector2i
) -> Vector2:
    var south_corner := grid_origin + footprint
    return grid_to_screen(south_corner)
```

Then:

```gdscript
building.position = get_building_anchor(grid_origin, footprint)
```

The building texture's source `ANCHOR` point must coincide with the Building root node origin.

### Draw order

Because the root is placed at the front/south vertex, buildings can be sorted using that map-space position. If additional overlap rules are needed later, use the same footprint/anchor data rather than hand-authored Z values wherever possible.

---

## 12. Suggested Godot Scene Structure

```text
Map
├── Ground
│   └── TileMap / TileMapLayer(s)
├── Roads
├── Buildings
│   ├── Building
│   │   ├── Sprite2D
│   │   └── InteractionArea
│   └── ...
├── Decorations
├── Characters
└── ForegroundEffects
```

Keep buildings out of the reusable ground tile textures. Building level swaps should replace the building sprite/resource without moving the Building root.

---

## 13. House Test Plan

### Canonical baseline

- Building type: **House**
- Footprint: **2×2**
- Anchor: **south vertex**
- Level 1–3 footprint: unchanged

### Runtime footprint

- projected width: **400 px**
- projected height: **200 px**

### Source-art footprint

- projected width: **1600 px**
- projected height: **800 px**

### Test requirements

- L1, L2, and L3 must share the exact same footprint guide;
- entrance position may move within the façade, but must not imply a different camera angle;
- floor additions grow vertically;
- roof edges remain locked to Axis A/B;
- no baked grass tile;
- building-specific porch/path may remain if intentionally attached to the footprint.

---

## 14. Cafe Test Plan

### Canonical baseline

- Building type: **Cafe**
- Footprint: **2×2**
- Anchor: **south vertex**
- Level 1–3 footprint: unchanged unless gameplay later requires expansion

### Runtime footprint

- projected width: **400 px**
- projected height: **200 px**

### Source-art footprint

- projected width: **1600 px**
- projected height: **800 px**

### Test requirements

- awning edges must follow Axis A/B;
- window and door sides remain vertical;
- outdoor tables should be separate map decorations unless permanently included in the cafe footprint;
- signage must follow the façade plane;
- roof/parapet must not introduce a second projection angle;
- no environment backdrop.

---

## 15. First Four-Building Validation Set

Use these four buildings before converting the entire library:

| Building | Canonical footprint | Purpose of test |
|---|---|---|
| House | 2×2 | small residential mass |
| Cafe | 2×2 | storefront / awning / glass façade |
| Hospital | 3×3 | larger institutional footprint |
| Factory | 4×3 | rectangular industrial mass |

Place all four in one Godot test scene on the same grid.

The standard is accepted only if:

- all ground-contact edges feel parallel;
- all verticals agree;
- doors/windows appear at compatible human scale;
- no building appears to use a different camera tilt;
- footprint overlays match the intended occupied cells;
- level variants can swap without positional correction.

---

## 16. Perspective QA Checklist

### Geometry

- [ ] All X-direction architecture follows Axis A.
- [ ] All Y-direction architecture follows Axis B.
- [ ] All building-height edges are vertical.
- [ ] Roof projection matches wall-base projection.
- [ ] Window rows do not drift away from the main axes.
- [ ] No façade uses a conflicting vanishing/perspective system.

### Footprint

- [ ] Building matches its assigned grid footprint.
- [ ] Anchor is on the exact south footprint vertex.
- [ ] L1/L2/L3 keep the same footprint unless gameplay says otherwise.
- [ ] Decorative overhangs are clearly distinguished from occupied cells.

### Scale

- [ ] Door height is compatible with other buildings.
- [ ] Window size is compatible with other buildings.
- [ ] Floor height is consistent across the map style.
- [ ] Vehicles/characters used as scale references would fit naturally.

### Export

- [ ] Transparent background.
- [ ] No guide lines.
- [ ] No unintended grass/road tile.
- [ ] No extra empty canvas that changes placement assumptions.
- [ ] Texture dimensions are reasonable for mobile use.

### Godot

- [ ] Source anchor coincides with Building root origin.
- [ ] Sprite swap between levels does not require manual position correction.
- [ ] Footprint collision/selection matches occupied cells.
- [ ] Draw order behaves correctly against neighboring buildings and characters.

---

## 17. Production Rule for Generated / Assisted Art

Any generated or externally produced building image is treated as **concept art until it passes the master-grid check**.

Do not accept a building merely because it “looks isometric.”

Before production import:

1. overlay the correct footprint template;
2. compare roof, façade, and base edges to Axis A/B;
3. check verticals;
4. correct geometry in Illustrator/Figma;
5. align the source anchor;
6. remove generic ground/background;
7. export transparent PNG;
8. validate inside the shared Godot test scene.

The grid, not the source image, is the final authority.

---

## 18. Locked Decisions

For the current map-art prototype, use:

```text
Projection:       2:1 dimetric/isometric game projection
Runtime tile:     200 × 100 px
Detail tile:      50 × 25 px (exact 4 × 4 subdivision)
Source grid tile: 800 × 400 px
Axes:             ±26.565° screen-space, vertical height axis
Anchor:           front/south footprint vertex
Ground:           separate from buildings
Runtime building: transparent PNG
Primary tools:    Illustrator / Figma
Level variants:   same footprint by default
```

These values should not change per building. If the map projection is changed later, regenerate the templates and migrate all building assets together rather than mixing projection standards.
