# Zone and town generation

Two independent placement subsystems that both "put things at towns" and are easy to
confuse — the map even labels one of them "Dynamic Town N":

- **Enemy zone siting** ("More Urban"): chooses where OPFOR objectives spawn. These are
  the red `"N. Outpost"` markers you capture.
- **Civilian Dynamic Town system**: at runtime, scans the map for building clusters,
  drops a `NameVillage` location labelled `"Dynamic Town N"` on each, and seeds a
  civilian population there. Purely civilian — not an objective.

Both are server-only and run near campaign start. This doc covers what each does, who
authored it, and the defects to fix. For the `exitWith` trap cited below see
[`arma_engine_gotchas.md`](arma_engine_gotchas.md#exitwith-exits-the-nearest-loop-or-call-scope-not-the-enclosing-ifthen);
for the boot order see [`architecture.md`](architecture.md#boot-flow).

## Provenance: what 5U5 changed vs inherited

The fork chain is Kibot's DUWS -> Tomata's DUWS_X -> 5U5's DUWS_T. 5U5's additions carry
Chinese comments; DUWS-era code is English. Comment language is a proxy, not proof, but
here it lines up with explicit author annotations (`// LESS URBAN 保持不变` = "keep
unchanged", `修复` = "fix", `改进版` = "improved version"):

**Enemy zone placement is largely inherited.** 5U5 did *not* rewrite the core siting.
The "More Urban" survey (`fnc_moreUrban_locations.sqf`) is untouched Tomata code. In the
siting loop 5U5 replaced only the `moreUrban == 1` branch (building-cluster centroid) and
added the origin guard; the less-urban branch, the outer loop, the distance/spacing gates,
and the failsafes are inherited. Manual placement is untouched. `fnc_createzone.sqf` keeps
its inherited core (markers, prefab, triggers, spawn loop) with 5U5 features *bolted on*:
obstacle clearing, the fortification ring, heli reinforcement, and the offset flag.

**The civilian Dynamic Town system is 5U5's own work**, layered on Tomata's
civilian-presence concept. `fnc_civ_detectClusters.sqf` is new; `fnc_civ_init_Tomata.sqf`
and `fnc_civ_locator_Tomata.sqf` are heavily reworked. This is where the "Dynamic Town N"
labels come from — nothing in the enemy-zone path produces them.

So the honest summary for a reviewer: the classic DUWS objective placement was tweaked and
decorated, not overhauled; the substantial new system is civilian population.

## Subsystem A: enemy zone siting ("More Urban")

Default-on (`moreUrban = 1`, `src/duws/server/server_var_init.sqf:140`; campaign menu can set
`0`, `fnc_process_campaign_menu.sqf:188-203`). Three stages during `server_init.sqf`.

| Stage | File | Produces |
|---|---|---|
| 1. Survey | `server/misc/fnc_moreUrban_locations.sqf` | `MASTER_allLocations_filtered` (Locations, town-weighted, shuffled) |
| 2. Siting | `server/init_zones/fnc_locatorzones_random.sqf` | one `_zonePos` per zone -> `fnc_createZone` |
| 3. Build-out | `server/init_zones/fnc_createzone.sqf` | markers, prefab, fortifications, triggers |

**Survey** enumerates `CfgLocationTypes`, pulls map Locations and towns within
`zones_max_dist_from_hq` of HQ (optionally a 135-degree arc), and requires non-town
locations to hold >5 `House` objects within 100 m (`:132-137`). Result is
`towns ++ filtered-locations` (`:147`); towns can appear in both lists, which is the only
real "weighting" (the concatenation order is inert — siting picks uniformly at random).

**Siting** loops `zones_number` times. The `moreUrban` branch (`:92-126`): pick a random
anchor, take the centroid of `House`/`Building` objects within 400 m (`:96-117`),
`findSafePos` 0-10 m around it (`:113`), nudge 5 m off the nearest road (`:119-123`). Then
distance-from-HQ (`:155`), spacing (`:159-169`), and 500 m origin keep-out (`:171-177`)
gates, then `spawn fnc_createZone` (`:185`). The `else` branch (`:127-150`) is the older
random-then-snap-to-building behaviour, with a 10-try validation loop.

**Build-out** places markers, clears obstacles for prefab zones (`:61-87`), spawns a
weighted prefab (`:89-139`), scatters 3-4 fortification towers (`:141-195`), and wires the
QRF, spawn-wait, and capture triggers.

### Defects (Subsystem A)

**Origin keep-out drops the zone instead of retrying it.** `fnc_locatorzones_random.sqf:172-177`.
When a candidate lands within 500 m of `[0,0,0]`, the guard runs `exitWith`. In SQF
`exitWith` exits the nearest enclosing **loop** (`if/then` is transparent to it), so it
terminates `while {!_found}` with `_found` still false and the `for` loop advances — the
zone slot is silently lost, yielding **fewer than `zones_number` zones**. The comment
("let the outer loop keep searching") describes what a plain `if/then` would do. Fix:
re-roll inside the loop instead of exiting it.

**The `moreUrban` branch can emit `[0,0,0]`.** `:92-126`. It sets `_Posfound = true`
unconditionally with no validity retry; its no-buildings fallback takes
`getPos (nearestBuilding …)` (`:100-102`), which is `[0,0,0]` when `nearestBuilding`
returns `objNull`. That `[0,0,0]` is exactly what the origin guard then eats, so the two
defects compound. The branch needs the reject-and-retry the less-urban path already has.

**Fortification towers almost never spawn in towns.** `fnc_createzone.sqf:185-186`. Each
tower spot is rejected if `nearestObjects [_safePos, [], 8]` finds anything within 8 m;
the empty type filter makes that include terrain/map objects (houses, walls, rocks), so in
the dense areas `moreUrban` targets nearly every spot is rejected. Filter to the types that
actually block placement.

**Prefab obstacle-clear hides real town buildings permanently.** `:61-87`. For prefab
zones it deletes/hides everything within 35 m of centre except men/pads/flags/HQ/FOBs.
`deleteVehicle` cannot remove terrain buildings, so the `hideObjectGlobal true` fallback is
what actually clears them — a global, unrestored change to the town just selected for being
dense. The `_deletedCount`/`_hiddenCount` counters double-count (both ops per object).

**Unbounded, no-yield retry with a heavy per-iteration cost.** `:62-155`. Rejected
positions re-roll with no `sleep`, and each `moreUrban` pass calls `nearestTerrainObjects`
over 400 m plus a centroid pass; on a cramped map or large `zones_spacing` this can busy-spin
until the 90 s failsafe. Needs a yield and/or an attempt cap.

**Centroid can land in dead space; road nudge not re-checked.** `:103-123`. Averaging two
sub-clusters inside 400 m yields a point between them (possibly an empty field), kept by
the 0-10 m `findSafePos`; the single 5 m `relPos` road nudge is never re-validated.
Placement-quality only.

> Correction to an earlier draft: `getPos` on a Location is *not* a bug. 5U5 relies on it
> throughout (`fnc_civ_detectClusters.sqf:51,139`) and the towns render, so it resolves a
> Location's position fine; it is only stylistically inconsistent with the
> `position`/`locationPosition` used elsewhere.

## Subsystem B: civilian Dynamic Town system

Runs from `fnc_civ_init_Tomata.sqf` (gated on `CIV_PRESENCE`). Produces the "Dynamic Town N"
labels and a persistent, per-town civilian population with map markers.

1. **Static towns** — `fnc_civ_locator_Tomata.sqf` returns all map city/village Locations
   plus special `FACTORY`/`AIRFIELD`/`MILITARY` points (`:12-40`).
2. **Dynamic towns** — `fnc_civ_detectClusters.sqf` grid-samples the map every 800 m
   (`:68-80`) and, at each candidate, grows a 50->100 m radius looking for >=3 enterable
   buildings (`:104-120`), excluding existing towns and military positions. Each hit becomes
   `createLocation ["NameVillage", …]` labelled `"Dynamic Town N"` (`:143-144`), tagged
   `isDynamic`/`buildingCount`/`clusterRadius` (`:145-147`).
3. **Population setup** — `fnc_civ_init_Tomata.sqf` merges both lists (`:24`), sizes each
   town (radius and initial pop from building count, `:57-64`), resolves overlaps by
   shrinking/deleting the smaller town (`:80-137`), then per town creates a presence
   trigger, an ellipse area marker, and a population-count icon (`:145-193`). Civilian
   spawning enables 120 s after init (`:222`) — the "Activates in 120 sec" notification.

### Defects (Subsystem B)

**The military-exclusion wait is a no-op.** `fnc_civ_detectClusters.sqf:56`:
`waitUntil { sleep 0.1; !isNil "createzone_server" || time > time + 5 }`. `createzone_server`
is initialised to `false` at boot (`server_var_init.sqf:88`), so `!isNil` is true from the
start and the wait returns immediately; the `time > time + 5` "timeout" is always false
(dead code). The intent was `waitUntil { createzone_server }` with a real timeout. Because
it doesn't wait, the WARCOM zone arrays read for exclusion (`:57-58,129-134`) may still be
empty, so **dynamic towns can spawn on top of enemy zones**. Note that even fixed, the flag
only means "settings confirmed," not "zones placed" (zones spawn asynchronously with
`sleep`s), so the exclusion is inherently racy against zone generation.

**O(candidates x buildings) brute force, no yield.** `:104-120`. For each of ~1,400 grid
candidates on a large map, it distance-tests every enterable house (tens of thousands on
Altis) at each radius step — tens of millions of checks on the server with no `sleep`. This
is the "may take minutes" scan and can stall the server; the `_maxClusters` early-exit only
helps after 100 towns are found. Replace the inner loop with a per-candidate
`nearestTerrainObjects`.

**`createLocation` labels may not reach clients in MP.** `:143`. The "Dynamic Town N" text
is a location created server-side; locations are not broadcast, so on a dedicated server
clients may see the ellipse and population markers (made with `createMarker`, which is
global) but not the town-name label. Cosmetic MP asymmetry — verify on a dedicated host.

**Origin/`[0,0,0]` proximity keeps recurring.** The civ init filters locations with
`distance2D [0,0] > 100` (`fnc_civ_init_Tomata.sqf:19`) and detectClusters skips
near-origin/near-town candidates — the same corner-of-map hazard the enemy-zone origin
guard exists for. Worth tracing why placement drifts to origin rather than patching each
site.

_Minor:_ inside the grid loops `_x`/`_y` are rebound by nested `forEach` (`:74,110`); it
works only because `_pos` captures the coordinates first — a foot-gun if edited. Dedup uses
the `arr arrayIntersect arr` idiom (`:121`, `fnc_civ_locator_Tomata.sqf:40`).
