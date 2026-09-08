# Structure-aware building furnishing

Furnish an arbitrary building so it reads lived-in, without a per-building-class template and without a
mod. The problem the safehouse raid exposed: a house full of hidden guards and a house full of innocent
locals must look identical, and both must look occupied — but the current furnishing drops one prop per
interior position on a flat `setVectorUp [0,0,1]` seat
([`fnc_raid_safehouse_mission.sqf:120`](../../src/duws/server/missions/mission_threads/raid_safehouse/fnc_raid_safehouse_mission.sqf)),
which clips on uneven floors and never groups into anything that reads as a room.

The mod that does this well — ZEI (Zeus and Eden Interiors) — keys a hand-authored composition to each
building **classname**. That is a non-starter here: it is a mod, it is unmaintained, and a class-keyed
template leaves every unrecognised or modded building bare, breaking the mission's portability rule
(`CLAUDE.md` §Principles). So the furnishing has to *infer* a building's interior from what the engine can
be asked at runtime, place composition **clusters** into it, and fall back gracefully when the inference
comes back empty.

This builds directly on
[`fnc_place_settled`](../../src/duws/server/init_zones/fnc_place_settled.sqf), which already seats a row of
objects flush on an anchor's surface at rest (align, base-seat, zero velocity, no freeze). The furnishing
decides *where* and *which way*; `fnc_place_settled` does the *how* of each cluster.

## What the engine can tell us about a building

No command reports rooms, walls, or doorways directly. Four class-agnostic signals stand in:

- **Interior positions** — `_building buildingPos -1` / `BIS_fnc_buildingPositions`: the AI nav points, one
  per usable interior spot, already spread through the rooms. These are the only "where furniture goes"
  the engine volunteers.
- **Inner vs perimeter** — the mission's `_fnc_innerSlots`
  ([`fnc_raid_safehouse_mission.sqf:55`](../../src/duws/server/missions/mission_threads/raid_safehouse/fnc_raid_safehouse_mission.sqf))
  sorts those positions by distance to their own centroid. Inner slots sit in open floor; outer slots sit
  against walls. A free clearance proxy before a single ray is cast.
- **Model axis** — `getDir _building`. Interior walls run along the model's own axes, so a cluster turned
  to `getDir` (or +90°) sits parallel to the walls rather than skew.
- **Solid geometry** — `lineIntersectsSurfaces` against the building's `GEOM` LOD reports walls and their
  range along a ray. This is the Tier 2 signal that turns "probably clear" into "clear for 1.8 m, wall to
  the north". Already used elsewhere in the tree for the same kind of structure query
  ([`fnc_garrison_reserve.sqf:30`](../../src/duws/server/init_zones/fnc_garrison_reserve.sqf),
  [`fnc_recon_observe_mission.sqf:67`](../../src/duws/server/missions/mission_threads/recon/fnc_recon_observe_mission.sqf)).

What stays invisible: **doorway positions.** `fnc_house_doors`
([`fnc_house_doors.sqf`](../../src/duws/shared/functions/fnc_house_doors.sqf)) returns door *animation
sources*, not their world positions, and there is no clean command for the latter. A doorway reads to the
raycast as an open direction like any other gap, so the placement cannot deliberately keep clear of one.
It is mitigated, not solved, below.

## The algorithm

Server-side, run once when the building is furnished — no loop. Per building:

1. **Collect candidate slots.** `_fnc_innerSlots` of the building. Group them by floor first (cluster the
   `select 2` heights; a 3 m gap is a storey) so a ray never treats the floor above as a wall and a cluster
   never lands half in a ceiling.
2. **Probe each candidate** (Tier 2 core). From the slot raised to chest height (~1.1 m, so a floor or a
   low threshold is not read as a wall), cast `lineIntersectsSurfaces` in 8 compass directions out to a
   short reach (~2.5 m), `GEOM` LOD, the building not ignored (its walls are what we want to hit). For each
   ray record the hit range; missing = open past the reach. From the 8:
   - **clearance** = the minimum hit range (how much open floor the slot has),
   - **wall bearing** = the direction of the nearest hit (what the cluster backs onto),
   - **open bearing** = the direction of the farthest hit (what the cluster faces).
3. **Rank and pick.** Sort candidates by clearance descending. Place clusters into the best slots until the
   building's quota is met (quota scales with slot count — a one-room hut takes one cluster, a big house
   three or four). Skip any slot whose clearance is below the chosen cluster's footprint radius, and any
   slot within a spacing minimum of an already-placed cluster, so clusters never overlap or crowd.
4. **Orient and seat.** Back the cluster onto the wall bearing (its rear edge toward the wall, front to the
   open bearing) and hand the rows to `fnc_place_settled` with the slot as anchor — base-seated on the
   floor, velocity zeroed. Snap the facing to the nearer of `getDir _building` / +90° when a wall was found,
   so a cluster reads as aligned to the room rather than to an arbitrary ray.
5. **Clutter pass.** For a cluster that carries a flat surface (a table), scatter 2–4 small items across its
   top as offset rows on the *cluster's table object* as anchor — so the clutter travels and turns with the
   table. This is ZEI's "object fill" idea, kept to surfaces we placed ourselves rather than trying to find
   a map building's own shelves.

**Fallback (no walls found).** An open-plan structure, or one whose `GEOM` LOD the rays miss, returns no
hits. Then drop to the Tier 1 shape: place at the innermost slots, orient to `getDir _building` with a
random 0/90° flip, no clearance skip. Worse alignment, but never bare — and logged, because a building that
silently furnishes to the fallback everywhere is the tell that the probe reach or LOD is wrong.

## Data shapes

A **cluster** is a `fnc_place_settled` row list plus the metadata the placement needs:

```
["living",                        // set name
 1.4,                             // footprint radius, metres -- the clearance gate and spacing minimum
 [["Land_CampingTable_F",  0,    0,   0, 0],
  ["Land_CampingChair_V1_F", 0.6, 0.2, 0, 200],
  ["Land_WoodenBox_TarpAll_F", -0.7, -0.3, 0, 45]],
 [["ItemWatch", 0, 0, <tabletop-Z>, 0], ...]]   // clutter rows, seated on the table object
```

Rows are `[class, offX, offY, offZ, dir]` in the anchor's model frame, exactly the
[`fnc_place_settled`](../../src/duws/server/init_zones/fnc_place_settled.sqf) contract; `offZ` for a
tabletop clutter row is the table's `boundingBoxReal` top. A small **library** holds a few sets — a living
set, a sleeping set, a work/desk set — each a handful of clusters, picked from by the caller's eligible-set
list so a civilian home and a command post draw different furniture from one mechanism.

## New helper

`fnc_furnish_building` — server-only (createVehicle and the raycasts run where the building is), registered
in `server_fnc_init.sqf` ahead of its callers, alongside `fnc_place_settled`.

```
// Contract: [_building, _key, _sets, _quota] -> [_objs placed]
//   _building  the structure to furnish
//   _key       teardown key filed through fnc_duws_keep
//   _sets      eligible cluster-set names (e.g. ["living","sleeping"]); [] = all
//   _quota     max clusters; default scales from interior slot count
```

Reusable by any mission or zone prefab that wants a building furnished, per the house rule that reusable
placement logic lives in a shared `fnc_*` and the mission holds only the call and its data (see the memory
on extracting placement helpers). The cluster library is data it reads, not logic each caller repeats.

## Integration

The safehouse mission drops its `FURNITURE` define and per-slot loop
([`fnc_raid_safehouse_mission.sqf:94`,`:119`](../../src/duws/server/missions/mission_threads/raid_safehouse/fnc_raid_safehouse_mission.sqf))
for one `[_bldg, "mission_raid_safehouse", ["living"], _quota] call fnc_furnish_building` per candidate
house. The intel crate stays its own placement (it is a functional objective, seated at a back slot), but
moves onto `fnc_place_settled` so it base-seats like everything else rather than the current raw
`createVehicle` + `setPosATL`.

## Engine specifics and gotchas

Log these in [`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) as they are hit during
implementation, per `CLAUDE.md`.

- **`lineIntersectsSurfaces` is ASL.** Its begin/end are ASL positions and hits come back ASL; a
  `buildingPos` is AGL, so convert (`AGLToASL`) before probing. Probe from chest height, not the floor, or
  the floor plane and low sills read as walls.
- **Query `GEOM`, not `VIEW`/`FIRE`.** Physical clearance is the geometry LOD; a view-LOD probe walks
  through thin walls a body cannot. Pass the building un-ignored so its own walls register.
- **Base-seat, never origin-seat.** `fnc_place_settled` already backs the model's `boundingBoxReal` base
  out along the surface up — this is why the flat `setPosATL` it replaces let props sink or float.
- **Multi-floor.** `buildingPos -1` spans every storey. Bucket by height before probing so a cluster is
  placed and cleared within one floor.
- **No PhysX freeze.** `fnc_place_settled` zeroes velocity and leaves the object unfrozen; furniture is set
  `allowDamage false` there, so stray fire does not scatter a room mid-raid.
- **Cost is bounded and one-shot.** Worst case per house is (candidate slots × 8 rays); it runs once at
  furnish time on the server, never in a loop. Cap the probe to the slots actually in contention (rank by
  the free inner/outer proxy first, probe only the top handful) so a 60-position building does not cast
  hundreds of rays. For the safehouse that is up to 8 houses at mission start — acceptable, but the cap
  keeps a future 30-building caller honest.

## Risks and fallbacks

- **A building with no usable `GEOM` walls** (a ruin, a prop with only a view LOD) → every ray misses → the
  Tier 1 fallback furnishes it flat and aligned to `getDir`. Never bare, and the fallback count is logged.
- **A doorway faced by a cluster.** Not preventable without door positions; the cluster still backs onto a
  real wall (the raycast guarantees that), so at worst it faces an opening rather than blocks one.
- **A modded building with a bizarre interior.** The probe is geometry-driven, so it degrades to "less
  clearance found, fewer clusters placed" rather than clipping — the failure mode is a sparse room, not a
  broken one.

## Verification

- Playtest across the common Altis house classes the safehouse already surveys
  (`Land_i_Stone_HouseSmall_V1/2/3`, `Land_i_House_Small_02_*`, `Land_i_House_Big_01_*`): clusters sit on the
  floor, back to a wall, no clipping, no two clusters overlapping, clutter on the tabletops.
- A house with no interior geometry falls back rather than erroring, and says so in the RPT.
- Decoy and real houses furnish from the same call, so neither reads different from the other — the
  concealment the raid depends on.
