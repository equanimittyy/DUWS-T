# Zone and town generation

Two placement subsystems that both "put things at towns". They are no longer independent:
civilian selection consumes the zone system's output, and the dependency runs one way.

- **Enemy zone siting** ("More Urban"): chooses where OPFOR objectives spawn. These are
  the red `"N. Outpost"` markers you capture.
- **Civilian town selection**: picks a subset of the map's real towns near the fighting and
  seeds a persistent civilian population in each. Purely civilian — not an objective.

Both are server-only and run near campaign start; civilians are registered once zone
build-out has finished. This doc covers what each does, who authored it, and the defects to
fix. For the `exitWith` trap cited below see
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

**The civilian population system is 5U5's own work**, layered on Tomata's
civilian-presence concept, and rewritten again since: the map-wide building-cluster scan
and the synthetic "Dynamic Town N" locations it invented are gone, replaced by the
selection pass in `fnc_civ_selectTowns.sqf`.

So the honest summary for a reviewer: the classic DUWS objective placement was tweaked and
decorated, not overhauled; the substantial new system is civilian population.

## Subsystem A: enemy zone siting ("More Urban")

Default-on (`moreUrban = 1`, `src/duws/server/server_var_init.sqf:140`; campaign menu can set
`0`, `fnc_process_campaign_menu.sqf:189-203`). Three stages during `server_init.sqf`.

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

> `getPos` on a Location is *not* a bug. The civilian system relies on it throughout
> (`fnc_civ_selectTowns.sqf`, `fnc_civ_init_Tomata.sqf`, `fnc_civ_handler.sqf:26`) and the
> towns render, so it resolves a Location's position fine; it is only stylistically
> inconsistent with the `position`/`locationPosition` used elsewhere. Whichever is chosen,
> selection and the runtime must use the *same* one or a town's trigger and its eligibility
> test measure different points.

## Subsystem B: civilian town selection

Selects real map towns near the fighting and gives each a persistent civilian population
with map markers. Gated on `CIV_PRESENCE`; no synthetic locations are created.

| Stage | File | Produces |
|---|---|---|
| 1. Selection | `server/misc/fnc_civ_selectTowns.sqf` | ranked shortlist of `[Location, buildingCount]` |
| 2. Registration | `server/misc/fnc_civ_init_Tomata.sqf` | `civ_locations` / `civ_radii`, per-town trigger and markers |
| 3. Runtime | `server/misc/fnc_civ_handler.sqf` (`_wbk` twin) | spawn on entry, cleanup, population tracking |

**Selection** takes the BLUFOR HQ plus every entry of `serv_zones_array` as anchors and pulls
city/village/local Locations with one `nearestLocations` call, keeping those within 5,000 m of
*any* anchor that holds at least three usable buildings within 350 m. Anchors then draw in
turn: each ranks its own disc by that building count, takes three, and skips whatever earlier
anchors took. A second wave adds `count serv_zones_array` more, drawn at random across the
whole union. What is left over comes back alongside the selection as a replacement queue. No
side effects; the caller owns everything else.

Size is measured in standing buildings, not `size _loc`: a Location's `radiusA`/`radiusB` come
out of `CfgWorlds`, are hand-authored per map, and routinely put a hamlet level with a city, so
an extent-ranked pass spent slots on empty ground. Distance is a gate only — inside a disc the
bigger town wins however far back it sits, because blending in closeness let roadside hamlets
outrank the cities behind them. Anchors draw in turn rather than from one ranking over the
union because a global top-N let the densest cluster of anchors win every slot, leaving a
remote zone with no civilian town in reach. The random second wave exists so the result does
not read as exactly three towns ringing every objective.

The count travels with the location rather than being recounted downstream: it is the heaviest
engine work in the civilian pass, and both stages need the same figure over the same `getPos`
centre.

**Registration** derives radius and starting population from the count selection handed over,
drops any town whose disc overlaps the 100 m keep-out around `PosOfBLUHQ` and pulls a stand-in
off the replacement queue in its place, resolves overlapping towns by shrinking or dropping the
smaller, then creates the
presence trigger, ellipse marker and population icon. The overlap loser is dropped from the
registry only — never
`deleteLocation`d, because these are the map's own Locations and removing one takes it away
from side-mission siting (`fnc_findSafeMissionPos.sqf:30`) and the player's location readout
(`fnc_bottom_right_message.sqf:152`) for the rest of the mission.

The HQ keep-out is disc-against-disc, not centre-against-centre: a civilian area whose edge
reaches the base still spawns civilians inside it. It sits in registration because that is
where the radius formula lives. Enemy zones get no such gate; a contested town is the point.

Registration also decides each town's starting reputation and its Army Power worth. Both run
after the overlap cull has finalised every radius, for the same reason the HQ keep-out does: the
enemy-zone test is disc-against-disc, and it reads radii out of `zone_meta_array` (entry index 2)
rather than `serv_zones_array`, which stores positions only. A town whose disc reaches into an
enemy zone opens at `-20` — the enemy already holds that ground and the civilians there start
with them. Worth is a rank within the campaign's own kept set rather than an absolute building
count, so Altis cities and a sparse map's hamlets both span 1 to 3.

### Ownership bands and the garrison

A town's reputation runs `-20 … 20` and three consumers read it as a *band* rather than a
magnitude, so the thresholds are a contract between them:

| Band | Reputation | Pays | Garrison |
|---|---|---|---|
| BLUFOR | `>= 10` | BLUFOR AP | — |
| Neutral | `-9` … `9` | nobody | — |
| OPFOR | `<= -10` | OPFOR AP | tier 1, rising to 2 at `-15` and 3 at `-20` |

Tier 1 is infantry; tier 2 adds a second team and a light vehicle; tier 3 adds armour
(`fnc_civ_garrison.sqf`). All three are built from the existing OPFOR spawners, so the garrison
inherits faction auto-detection for free. It is units only — no fortification ring and no
prefab, because static emplacements are what make a zone an objective and a town must not
compete with one.

Presence uses the same arrival test zones use (`fnc_duws_bluforNear`) rather than the town's own
presence trigger, which fires the instant anyone crosses the radius and whose handle is
discarded at creation anyway. Clearing the garrison resets that town's reputation to 0, decided
by a `WEST SEIZED` trigger rather than by counting units: the spawners are fire-and-forget and
register nothing, so no group handle exists to watch die.

The band is the condition, not a one-shot flag — a town driven back below `-10` gets a new
garrison, and a town lifted out of the band while its garrison lives loses it.

**Clearing discards the whole debt, deliberately.** A player who ruins a town to `-20` and then
kills the garrison lands back at neutral having paid nothing for the civilian deaths that got
them there. The alternative is a town the player can permanently ruin with no route back, which
is what passive recovery used to prevent. The garrison is the price, and its tiers are the dial:
if the reset proves too cheap, raise tier strength rather than introducing partial resets.

### Population is a size figure, not a head count

`civ_pop_<n>` is set once at registration to the town's usable building count and never written
again. Spawn density follows from it directly, capped by `civ_maxSpawnPerVisit` (default 50,
set from the environment menu).

Where that cap *binds* is the point. The `buildings × 2` derivation this replaced saturated from
25 buildings upward — most real Altis towns — so every settlement from a market village to
Kavala presented the same 50 concurrent civilians. Against the raw count the cap binds at 50
buildings instead, and twice as much of the map's size range shows on the ground before
flattening. The trade is fewer civilians in mid-size towns; raising `civ_maxSpawnPerVisit` is
the player's answer if they have the frames for it, which is what the setting is for.

Because the figure never decrements, nothing can reach zero, which is why the depopulation
path — ghost-town notification, black marker, and the scorched-earth CP reward that rode on it —
no longer exists.

### Ordering

Civilian generation is a step of zone generation, not a parallel system racing it. The
kick-off lives in `fnc_init_OPFOR_WARCOM.sqf` after its `serv_zones_array` wait and fires
once `zones_buildout_done >= count serv_zones_array`.

That counter exists because `amount_zones_created` cannot answer the question:
`fnc_createzone.sqf:19` bumps it on entry, so it counts zones *started*, and the function
never returns — its tail is a permanent despawn monitor. The comparison is against
`count serv_zones_array` rather than `zones_number` because the origin keep-out
(`fnc_locatorzones_random.sqf:171-177`) can silently drop a zone slot, and a `zones_number`
target would then never be reached.

Nothing in this chain times out. Everything the player reads as "the campaign has started"
blocks on `mission_init_complete`: the MISSION INITIALIZATION COMPLETE banner and settings
summary, the map closing (`client_init.sqf`), and the intro helicopter
(`server_init.sqf`). The flag is published by the same spawn that runs the kick-off, once
civilian registration returns, so an abort inside the civilian pass still releases the
start — no exit-path discipline required inside `fnc_civ_init_Tomata.sqf`.

The completion announcements were moved out of both zone locators to get this. Left there
they fired as soon as zone *positions* were final, telling the player the campaign was ready
while towns were still being placed.

The Capture the Zones task (`fnc_capture_zones_task.sqf`) sits one step further out again: it
waits on `mission_init_complete`, then on `intro_heli_done`, so orders reach the player after
the fast-rope rather than during generation. Only the first wait is retried — `fnc_intro_heli`
has exit paths that never publish the second, and a campaign with no main task has no win
condition at all, so that wait falls through on timeout with the earlier gate holding the line.
