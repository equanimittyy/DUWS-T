# Structure-aware building furnishing

Furnish an arbitrary building so it reads lived-in, with no per-building-class template and no mod
dependency, on vanilla or modded maps alike. The design splits along the one line that keeps that promise:

- **Building geometry is inferred, never keyed on class.** A modded map's building classes are unknown, so
  nothing may branch on them (`CLAUDE.md` §Principles). The interior is reconstructed from class-agnostic
  engine probes into a floor-plan grid.
- **Furniture is ours, so its metadata is authored.** The furniture classes we place are a finite set we
  ship. A per-class catalog — each piece's front, role, and placement rule — is therefore fair game, and is
  the only place class-specific knowledge is allowed to live.

This supersedes the earlier probe-ranked-slots approach that placed one cluster per interior nav point. That
shape furnished only the AI nav lattice — a sparse combat grid, not a room map — so houses read empty and
furniture landed exactly where garrison troops stand. The grid below furnishes the floor itself and reserves
what it fills, which is what makes the result dense, clip-free, and out of the garrison's way at once.

Two approaches were considered and rejected. Hand-authored compositions keyed to each building class (as
ZEI, Tinter, and Phronk all do) furnish nothing on an unrecognised building — the portability rule forbids
it as a sole strategy. Ingesting those mods' composition libraries is licence-blocked: DUWS_T is
CC BY-NC-SA 3.0 ([`src/license.TXT`](../../src/license.TXT)), whose NonCommercial and Share-Alike terms are
irreconcilable with Tinter's GPL-3.0, and Phronk's is unlicensed. Using either would need the authors'
written permission. So placement is computed, not authored per building.

The seating primitive is unchanged: [`fnc_place_settled`](../../src/duws/server/init_zones/fnc_place_settled.sqf)
already seats a row of objects flush on an anchor at rest (align, base-seat, zero velocity, no freeze). The
system below decides *where* and *which way*; `fnc_place_settled` does the *how* of each placement.

## Pillar 1 — the floor-plan grid

No command reports rooms, walls, or doorways. The grid reconstructs the interior from geometry, per storey.

- **Seeds.** `_building buildingPos -1` returns the AI nav points — guaranteed-interior, on walkable floor.
  Their bounding box (not the building footprint, which includes roof overhang) gives the interior extent;
  clustering their heights splits storeys, a ~3 m Z gap being a floor boundary.
- **Cells.** Lay a grid of ~0.5 m cells across that extent at each storey's floor height. Each cell earns
  its place by two probes, so the grid matches the real (concave) rooms rather than the convex seed box:
  - **Floor test** — a short ray straight down from just above floor Z. A hit at floor height means real
    floor here; a miss or a far hit means a hole or outside the room, and the cell is dropped. The LOD that
    reports the walkable surface (`ROADWAY`) is the first candidate; the working LOD is settled in playtest
    and recorded in the gotchas doc.
  - **Wall ring** — eight rays at chest height (~1.1 m) on `GEOM` LOD, the same probe the current code and
    [`fnc_garrison_reserve.sqf:30`](../../src/duws/server/init_zones/fnc_garrison_reserve.sqf) already use.
    Yields each cell's nearest-wall distance and the bearings of walls within a cell's reach.
- **Cell state.** Each surviving cell is tagged `open` (no wall within reach), `near-wall` (with the wall
  bearings recorded, for backing furniture on), or `blocked` (too tight to hold anything).

Cost is the design's main risk and is bounded deliberately: the seed bounding box is tight, cell count is
capped (the grid coarsens rather than exceeding it), and the finished grid is cached on the building via
`setVariable` so it is built once and reused. It runs server-side, once per building, never in a loop.

## Pillar 2 — room segmentation

A house is many rooms; one furniture set across the whole interior looks wrong (a bed in the kitchen). After
the grid exists, flood-fill the connected `open`/`near-wall` cells into **rooms**, each cell tagged with a
room id. A wall line between two fills separates two rooms; a gap in the wall (a doorway) keeps them one
fill, which is acceptable — an open-plan pair furnished as one room reads fine.

Segmentation lands as its own phase, before any furniture is placed, so the room labelling can be inspected
on the debug overlay on its own. A furniture set is then chosen per room, not per building — but the set-to-
room assignment (which room becomes a bedroom) is left simple at first: assign by room size or at random.
Smarter assignment is a later refinement, not a first-cut requirement.

## Pillar 3 — the furniture catalog

Everything class-specific about furniture lives in one authored catalog, an `.hpp` array-literal table in
the style of [`mission_types.hpp`](../../src/duws/shared/includes/mission_types.hpp) (`#include`d as the body
of an SQF array), validated by a lint the way the composition fences are
([`fnc_BluHQinit.sqf:38`](../../src/duws/server/init_hq/fnc_BluHQinit.sqf)): every catalog class must resolve
in `CfgVehicles`/`CfgMagazines`/`CfgWeapons` and name a known role.

Each entry carries `[class, role, frontYaw, set[], seats, maxPerRoom?]`:

| Field | Meaning |
|---|---|
| `role` | one of five placement categories, each its own pass: `anchor` / `seat` / `wall` / `rug` / `clutter` |
| `frontYaw` | degrees subtracted from a target bearing so the model's real front lands on it (`heading = target − frontYaw`); it is the bearing the model's front points at when placed at heading 0 |
| `set[]` | which furniture sets the piece belongs to (`living` / `sleeping` / `work`) |
| `seats` | anchors only: `-1` = a seat on every open side (dining table); `N` = exactly `N` on the front (a desk is `1`); `0` (ignored) otherwise |
| `maxPerRoom` | optional cap on how many of this class a room gets across the distinct-piece passes (wall/anchor/rug); absent or `0` = no limit (a bed is `1`) |

The five categories: **anchor** needs open floor and takes seats beside it (table, desk); **seat** sits at
an anchor's edge, never standalone; **wall** stands back-flush and perpendicular to a wall (sofa, bed,
cabinet); **rug** lies on any free floor; **clutter** sits on an anchor's top. `backToWall` and a `wants`
list are not stored — they are exactly `role == "wall"` and `role == "anchor"`, so the role carries them.

Footprint is read from `boundingBoxReal` at runtime, not stored — it is exact and free.

**Obtaining the front is honest hand-calibration, not runtime derivation.** No SQF command reports a model's
semantic front: memory points are unreadable, no config field carries it, and bounding-box asymmetry is too
fragile. `frontYaw` is authored once per class with a calibration debug tool that spawns each catalog class
at heading 0 beside a north reference, so the dev reads the model's front bearing and records the offset. A
furniture class absent from the catalog is skipped, not guessed — an unknown *furniture* class is our own
gap to fill, distinct from an unknown *building* class, which the grid still handles.

## Pillar 4 — the dynamic placer

Runtime, over the cached grid, per room. Ordered passes, each reserving the cells it fills in an **occupancy
grid** — the reservation is what makes clip-avoidance deterministic rather than luck: two pieces can never be
handed the same cell.

1. **Wall pass.** `near-wall` cells take `wall` furniture (sofa, bed, cabinet), placed back-flush and
   perpendicular to the wall — its front points into the room, `heading = wallBearing + 180 − frontYaw` —
   with the footprint checked against neighbouring cells before reserving.
2. **Anchor pass.** `open` cells with clearance take anchors (tables and desks alike, in the open, not
   backed to a wall); then the anchor's seats per its `seats` rule (a table a seat on each open side, a desk
   one on its front), each seat faced at the anchor by construction (its heading is the bearing from its
   offset back to the anchor centre, minus the seat's own `frontYaw`).
3. **Surface pass.** Clutter grid-packed across an anchor's top, seated on the anchor object so it travels
   and turns with the table. This pass already exists in
   [`fnc_furnish_building.sqf`](../../src/duws/server/init_zones/fnc_furnish_building.sqf) and is kept.
4. **Rug pass.** Flat floor covers on any free floor cell, open or near-wall.
5. **Path preservation.** The straight-line cells linking consecutive `buildingPos` are never reserved, so a
   walk path stays clear. This doubles as the garrison-conflict fix: the nav lattice's connectivity is left
   open, so a trooper is not sealed behind a sofa. Doorway-exact avoidance is not attempted (door world
   positions are not exposed — [`fnc_house_doors.sqf`](../../src/duws/shared/functions/fnc_house_doors.sqf)
   returns animation sources only); the path-cell rule is the approximation.

Density is a fill target — a fraction of a room's cells, or until cells run out — the single honest knob for
"too empty / too cluttered".

## Data shapes

A **grid cell**, per storey:

```
[posASL, state, nearBearing, clearance, roomId, occupied, i, j, storey]
//  state       "open" | "near" | "blocked"
//  nearBearing bearing of the nearest wall, or -1 if none within reach
//  clearance   nearest wall distance, metres
//  roomId      set by Pillar 2; -1 before segmentation (blocked cells stay -1)
//  occupied    reservation flag, set during placement
//  i, j        storey grid coords, for room adjacency
```

A **catalog entry** — an SQF-array row `[class, role, frontYaw, set[], seats]`:

```
["Land_TableBig_01_F",  "anchor", 0, ["living"], -1],   // a seat on every open side
["OfficeTable_01_new_F", "anchor", 0, ["work"],    1]    // one seat, on the front
```

Placed rows are still `[class, offX, offY, offZ, dir]` in the anchor's model frame, the
[`fnc_place_settled`](../../src/duws/server/init_zones/fnc_place_settled.sqf) contract; `offZ` for a
tabletop clutter row is the anchor's `boundingBoxReal` top.

## Reused vs new

- **Reused:** `fnc_place_settled` (base-seating + teardown key), the eight-ray `GEOM` wall probe, the
  surface grid-pack, the `game_master`-gated debug-menu harness
  ([`fnc_debug_menu.sqf`](../../src/duws/client/debug/fnc_debug_menu.sqf),
  [`fnc_debug_furnish_menu.sqf`](../../src/duws/client/debug/fnc_debug_furnish_menu.sqf)).
- **New:** the grid builder + cache, the floor probe, room segmentation, the `.hpp` catalog + its lint, the
  calibration tool, and the ordered occupancy placer. `fnc_furnish_building`'s guts are rewritten around
  these; its current inline `_lib` becomes the catalog.
- **Not used:** the composition system ([`fnc_composition_place.sqf`](../../src/duws/server/init_zones/fnc_composition_place.sqf))
  seats at ground z=0 and is composition-based, not algorithmic.

## Engine specifics and gotchas

Log these in [`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) as they are hit, per
`CLAUDE.md`.

- **`lineIntersectsSurfaces` is ASL.** Begin/end and hits are ASL; a `buildingPos` is AGL, so `AGLToASL`
  before probing. Probe walls from chest height, not the floor, or the floor plane and low sills read as
  walls.
- **Floor LOD is unsettled.** The down-ray floor test needs the LOD that carries the walkable surface;
  `ROADWAY` is the first candidate, `GEOM` the fallback. Record which one works.
- **Query `GEOM` for walls, building un-ignored.** A view-LOD probe walks through thin walls a body cannot;
  the building must not be ignored, or its own walls do not register.
- **Multi-floor.** `buildingPos -1` spans every storey; bucket by height before gridding so a ray never
  treats the floor above as a wall.
- **Grid cost.** Worst case is (cells × 9 rays) per building; capped, cached, and one-shot on the server.
  Watch the RPT on a large building; coarsen the cell size if a build spikes a frame.
- **Base-seat, never origin-seat.** `fnc_place_settled` backs the model's `boundingBoxReal` base out along
  the surface up and sets `allowDamage false`, so props neither sink nor scatter under fire.

## Risks and fallbacks

- **No usable `GEOM`/floor geometry** (a ruin, a view-only prop) → the grid comes back empty → furnish falls
  back to the seed nav points, flat and aligned to `getDir`, and logs the degrade so a silently-empty grid
  is visible rather than mistaken for a bare building.
- **Concave rooms and interior walls** are handled by per-cell probing, but a building with no interior
  walls between areas segments as one room — furnished as one set, which reads acceptably.
- **A modded building with a strange interior** degrades to fewer valid cells and a sparser room, never to
  clipping — the occupancy grid refuses overlap by construction.
- **Calibration is manual**, so a new furniture class looks wrong (faces askew) until its `frontYaw` is
  recorded. The lint catches an unresolved class, not an uncalibrated front; a mis-faced piece is a visual
  bug found in playtest, not a crash.

## Phases

Each phase is independently testable, and the two geometry phases land and are inspected before any
furniture is placed.

1. **Grid builder + debug overlay.** Build and cache the per-storey cell grid; a debug overlay draws each
   cell (open / near-wall / blocked) on the pointed-at building. No furniture. Proves the floor plan.
2. **Room segmentation + overlay colouring.** Flood-fill cells into rooms; the overlay colours cells by room
   id. Still no furniture. Proves the room split.
3. **Catalog + calibration tool.** The `.hpp` schema and its lint, the calibration debug tool, and
   `frontYaw`/`role`/`rule` filled for the ~30 classes already supplied.
4. **Dynamic placer.** The ordered occupancy passes, per room, replacing the current placement in
   `fnc_furnish_building`.
5. *(later)* Garrison cell-reservation: expose the occupied cells / nav indices so the garrison spawner
   skips furnished positions. Wiring the garrison side is a separate change to garrison code.

## Verification

- Phase 1: the overlay's cells match the visible interior across common Altis houses
  (`Land_i_Stone_HouseSmall_V1/2/3`, `Land_i_House_Small_02_*`, `Land_i_House_Big_01_*`) — floor cells on
  floor, wall cells on walls, nothing outside the shell.
- Phase 2: the overlay's room ids match the eye's reading of the rooms.
- Phase 4: furniture sits on the floor, backs to walls where the rule says, seats face their anchors, no two
  pieces overlap, the walk path between doorways stays clear, and density reads lived-in rather than sparse.
- A building with no usable geometry falls back rather than erroring, and says so in the RPT.
