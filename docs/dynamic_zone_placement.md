# Dynamic zone placement ("More Urban")

How DUWS_T decides *where* on the map to spawn enemy-held zones at campaign start.
This is 5U5's rework of the DUWS/DUWS_X zone locator: instead of scattering zones at
random safe positions, it detects the map's towns and building clusters at runtime and
anchors zones onto them. The path is on by default (`moreUrban = 1`,
`src/duws/init/server_var_init.sqf:137`; the campaign menu can set it to `0`,
`src/duws/functions/dialog/fnc_process_campaign_menu.sqf:188-203`).

For where this sits in the boot flow see [`architecture.md`](architecture.md#boot-flow);
for the `exitWith` scoping trap called out below see
[`arma_engine_gotchas.md`](arma_engine_gotchas.md#exitwith-exits-the-nearest-loop-or-call-scope-not-the-enclosing-ifthen).

## Pipeline

Three stages, server-only, run in order during `server_init.sqf`.

| Stage | File | Produces |
|---|---|---|
| 1. Location survey | `functions/misc/fnc_moreUrban_locations.sqf` | `MASTER_allLocations_filtered` (candidate Locations, town-weighted, shuffled) |
| 2. Zone siting | `functions/init_zones/fnc_locatorzones_random.sqf` | one `_zonePos` per zone, passed to `fnc_createZone` |
| 3. Zone build-out | `functions/init_zones/fnc_createzone.sqf` | markers, prefab, fortifications, spawn/capture triggers |

### Stage 1 — survey (`fnc_moreUrban_locations.sqf`)

Enumerates every `CfgLocationTypes` class, pulls all map Locations within
`sqrt 2 * (worldSize / 2.2)` of map centre (`:20-28`), and separately pulls
cities/towns/villages (`:34-36`). Both lists are then filtered to within
`zones_max_dist_from_hq` of the player HQ (`:53-64`) and, when an `AO_direction` is set,
to a 135-degree arc from HQ (`:97-126`). Non-town locations are additionally required to
carry more than five `House` objects within 100 m (`:132-137`) — the "urban" test.

The result is `MASTER_allLocations_filtered = towns ++ filtered-locations` (`:147`), with
towns concatenated first. Towns are exempt from the building-count filter, so a town that
also survives as a filtered location appears twice, which is the only actual "weighting"
(the concatenation *order* is inert — Stage 2 picks uniformly at random, see defects).

### Stage 2 — siting (`fnc_locatorzones_random.sqf`)

Waits for the Stage 1 list (`:6`), then loops `zones_number` times, each iteration
placing one zone. The `moreUrban` branch (`:92-142`):

1. Pick a random anchor Location from the list (`:94`).
2. Gather `House`/`Building` objects within 400 m and take their **centroid** (`:96-117`);
   if none are found, fall back to `findSafePos` + `nearestBuilding` (`:98-102`).
3. `findSafePos` 0-10 m around the centroid for the final `_zonePos` (`:113`).
4. Nudge 5 m off the nearest road (`:119-123`); in `DOMINATION` mode reject anchors within
   1500 m of an existing FOB or zone (`:126-140`).

The position is then gated on distance from HQ (`> zones_max_radius + 1000` and
`<= zones_max_dist_from_hq`, `:184`), on `zones_spacing` from already-placed zones
(`:188-198`), and on a 500 m keep-out from map origin `[0,0,0]` (`:200-206`). On success
it spawns `fnc_createZone` (`:214`) and records the position.

The `else` branch (`:144-179`) is the older "less urban" behaviour: fully random
map-wide `findSafePos`, snapped to the nearest building, with a 10-try validation loop.

### Stage 3 — build-out (`fnc_createzone.sqf`)

Places the objective marker/ellipse, clears obstacles around the centre for prefab zones
(`:61-87`), spawns a randomly-weighted prefab (`:89-139`), scatters 3-4 fortification
towers inside 70% of the zone radius (`:141-195`), then wires the QRF, spawn-wait, and
capture triggers.

## Known defects and risks

Ordered by severity. The first three change what the player sees; the rest are risks to
confirm. None are fixed — this section is the future-work list.

### Origin keep-out drops the zone instead of retrying it

`fnc_locatorzones_random.sqf:200-206`. When a candidate lands within 500 m of `[0,0,0]`,
the guard runs `exitWith`. In SQF `exitWith` exits the nearest enclosing **loop** —
`if/then` blocks are transparent to it — so this terminates the `while {!_found}` loop
for that zone with `_found` still `false`. The `for` loop then advances to the next zone.
Net effect: the zone slot is silently lost, so the campaign generates **fewer than
`zones_number` zones** whenever the guard fires. The inline comment ("don't set
`_found = true`, let the outer loop keep searching") describes what a plain `if/then`
would do; `exitWith` does the opposite. Fix is to re-roll within the loop (leave `_found`
false and `continue`/fall through) rather than exit it.

### The `moreUrban` branch can hand `[0,0,0]` downstream

`fnc_locatorzones_random.sqf:92-142`. Unlike the "less urban" branch, this path sets
`_Posfound = true` unconditionally (`:142`) with no per-candidate validity retry. The
no-buildings fallback takes `getPos (nearestBuilding _randomPos)` (`:100-102`); if
`nearestBuilding` returns `objNull`, `getPos` yields `[0,0,0]`. That `[0,0,0]` is exactly
what the origin guard above then eats — so the two defects compound: a failed building
lookup becomes a dropped zone. The branch needs the same "reject and retry" the less-urban
path already has, so a bad position never leaves the branch.

### Fortification towers almost never spawn in towns

`fnc_createzone.sqf:185-186`. Each of the 3-4 candidate tower spots is rejected if
`nearestObjects [_safePos, [], 8]` finds anything within 8 m. An empty type filter makes
`nearestObjects` include terrain/map objects (houses, walls, rocks), so in the dense
building areas `moreUrban` deliberately targets, the guard rejects nearly every spot and
the loop `continue`s without placing a tower. The feature reads as "every zone gets a ring
of fortifications" but in practice urban zones get few or none. The guard should filter to
the object types that actually block placement, not all map geometry.

### `getPos` on a Location deviates from the codebase convention

`fnc_locatorzones_random.sqf:94-95` calls `getPos` on a **Location** handle. Everywhere
else Locations use `position` / `locationPosition` (`fnc_moreUrban_locations.sqf:27,106`;
`fnc_stratmap.sqf:135`). If `getPos` does not resolve a Location's position on the running
engine build, every anchor collapses to `[0,0,0]` and the whole branch degenerates into the
origin-guard drop above. Confirm `getPos`-on-Location in-game, or switch to the
`locationPosition` used by the rest of the pipeline.

### Unbounded, no-yield retry loop with a heavy per-iteration cost

`fnc_locatorzones_random.sqf:62-184`. When the distance/spacing gates reject a position the
`while {!_found}` loop re-rolls with no `sleep`, and each `moreUrban` iteration calls
`nearestTerrainObjects` over a 400 m radius plus a centroid pass. On a cramped map or with
a large `zones_spacing`, this can busy-spin and stall the server until the 90 s failsafe
(`:24-33,64-84`) swaps in a looser candidate list. The older branch had a lighter
per-iteration cost; the new one needs a yield and/or an attempt cap.

### Prefab obstacle-clear hides terrain buildings permanently

`fnc_createzone.sqf:61-87`. For prefab zones this deletes/hides every object within 35 m of
the centre except men, pads, flags, HQ, and FOBs. `deleteVehicle` cannot remove terrain
(map-config) buildings, so the `hideObjectGlobal true` fallback is what actually clears
them — a global, non-restored change to the town `moreUrban` just selected for being dense.
The `_deletedCount` / `_hiddenCount` bookkeeping (`:76-80`) double-counts because it runs
both operations on the same object. Worth deciding whether hiding real town buildings is
intended, and simplifying the counters if so.

### Centroid can land in dead space; road nudge is not re-checked

`fnc_locatorzones_random.sqf:103-123`. Averaging building positions across two sub-clusters
inside the 400 m radius yields a point *between* them — possibly an empty field — and the
0-10 m `findSafePos` keeps it there. Separately, the 5 m `BIS_fnc_relPos` road nudge
(`:119-123`) is applied once with a random heading and never re-validated, so a wide road or
a parallel nudge can leave the zone centre on the road. Both are placement-quality issues,
not crashes.
