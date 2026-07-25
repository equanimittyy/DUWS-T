# Civilian town generation: rewrite plan

Replace the map-wide building-cluster scan with a selection pass that reads the zone
system's own output. Civilian towns become a subset of the map's real towns, chosen for
being near the fighting, and the "Dynamic Town N" synthetic locations go away entirely.

The zone system does not learn about civilians. The dependency runs one way: civilian
selection consumes `serv_zones_array` and `PosOfBLUHQ`, both already published by the zone
locators for other reasons.

Background on the two subsystems and their current defects:
[`info/zone_and_town_generation.md`](info/zone_and_town_generation.md).

## Why the current system is replaced

| Problem | Where |
|---|---|
| Invents towns the map does not have (`createLocation` labelled "Dynamic Town N") | `server/misc/fnc_civ_detectClusters.sqf:143-147` |
| Scans the whole map indiscriminately: every `House` on Altis, each probed with `BIS_fnc_buildingPositions`, then distance-tested against ~1,500 grid candidates with no yield | `:37-41`, `:104-120` |
| Takes every map location regardless of distance, plus factory/airfield/military points that are not towns | `server/misc/fnc_civ_locator_Tomata.sqf:14-37` |
| Reads the zone arrays for its military keep-out behind a wait that returns immediately, so it can place towns before zones exist | `:56-58` |

The last one is the structural fault: the scan is *supposed* to know about zones and
doesn't. Making zone placement the input rather than an afterthought removes the race and
the scan in one move.

## Design

### Anchors

An anchor is a point the fighting revolves around: the BLUFOR HQ plus every enemy zone.

```sqf
private _anchors = [PosOfBLUHQ] + serv_zones_array;
```

Both are published by the zone locators once placement finishes —
`server/init_zones/fnc_locatorzones_random.sqf:212-213` for random placement,
`server/init_zones/fnc_locatorzones_manual.sqf:121-122` for manual. FOBs are not anchors:
they are built after generation and would require re-selection.

`BIS_fnc_findSafePos` returns a two-element `[x,y]`, so `PosOfBLUHQ` and every entry in
`serv_zones_array` are 2D. Normalise to `[_p select 0, _p select 1, 0]` and compare with
`distance2D`; passing a bare two-element array to `distance` is not reliable.

### Eligibility

A map town is eligible if it lies within 5,000 m of **at least one** anchor — the union of
the discs, not their intersection. Strict intersection is empty in any campaign whose zones
are more than 10 km apart, which is most of them.

The candidate pool is one config-backed engine call, not a terrain scan:

```sqf
nearestLocations [_mapCentre, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], worldSize]
```

### Cap and ranking

The cap is three per anchor: `3 * count _anchors`. HQ plus four enemy zones gives 15. The
cap is a ceiling, not a target — when fewer towns are eligible, fewer are produced.

When the eligible set exceeds the cap, rank by a score that favours large towns and towns
close to an anchor, and take the top slice. Both terms normalise to 0..1 so neither can
dominate by unit choice:

| Term | Value |
|---|---|
| `_sizeScore` | town extent / largest extent in the eligible set |
| `_proxScore` | `1 - (distance to nearest anchor / 5000)` |
| `_score` | `0.5 * _sizeScore + 0.5 * _proxScore` |

Keep the two weights as named constants at the top of the file. They are the tuning knob:
raising the proximity weight pulls civilians onto the front line, raising the size weight
sends players to the population centres wherever they happen to be.

Town extent comes from `size _loc`, which reads `radiusA`/`radiusB` out of `CfgWorlds` and
costs nothing. Some map entries define no radius and return zero; fall back to a nominal
extent from the location type, which is always present:

| `type _loc` | Fallback extent (m) |
|---|---|
| `NameCityCapital` | 300 |
| `NameCity` | 200 |
| `NameVillage` | 120 |
| `NameLocal` | 80 |

### Sizing runs on the shortlist only

This is where the cost goes. Building counts drive both the town radius and its population,
and today they are computed for every location on the map. Compute them **after** the cap is
applied, for the selected towns only — at the default six zones that is 21 calls to
`fnc_usableBuildings` instead of a full-map sweep plus 160 per-town scans.

The sizing arithmetic itself is unchanged from
`server/misc/fnc_civ_init_Tomata.sqf:50-77`: radius `buildings * 10` clamped to 100..500,
population `buildings * 2` capped at 280 with a per-town random floor of 6..12, doubled
under `CIV_PRESENCE == "RAVAGE"`.

The overlap-resolution pass (`:85-137`) is kept as written. It is O(n²) but n is now the
cap, not the whole map, and real map towns rarely overlap at a 500 m radius.

### Ordering

`fnc_civ_init_Tomata` is still kicked off from `client/dialog/fnc_callsign_confirm.sqf:32`
at final commit — that is what makes the setup screens' Back navigation safe, and it is
where `CIV_PRESENCE` is known. It now waits for zones before selecting:

```sqf
["CIV", "serv_zones_array populated by the zone locator", {count serv_zones_array > 0}, 300] call fnc_waitLogged
```

`fnc_waitLogged` returns false on timeout and lets the caller continue
(`shared/functions/fnc_log_init.sqf:36-68`). On timeout, fall back to HQ-only anchors: three
towns around the HQ beats no civilians at all, and a campaign that never publishes
`serv_zones_array` has already failed elsewhere.

Civilian spawning still enables 120 s after init completes, which is now later in the boot
than before. That is the intended consequence of ordering civilians behind zones.

## Separation of concerns

Spawn-on-entry is already separate and stays untouched: `fnc_civ_handler.sqf` (and its WBK
twin) owns unit creation, waypoints, hostile conversion, cleanup and the population monitor.
What is mixed today is inside `fnc_civ_init_Tomata.sqf`, which does selection, sizing,
runtime wiring, and two background economy loops in one file.

| Stage | File | Owns |
|---|---|---|
| Selection | `server/misc/fnc_civ_selectTowns.sqf` (new) | Anchors, eligibility, ranking, cap. The only civilian file that reads zone state. Returns Locations; no side effects. |
| Registration | `server/misc/fnc_civ_init_Tomata.sqf` (rewritten) | Sizing, overlap resolution, triggers, markers, per-town variables. |
| Runtime | `server/misc/fnc_civ_handler.sqf`, `fnc_civ_handler_wbk.sqf` | Spawn, cleanup, population tracking. Unchanged. |
| Economy | `server/misc/fnc_civ_rep_economy.sqf` (new) | Reputation recovery and the 15-minute CP reward, moved out of init (`fnc_civ_init_Tomata.sqf:196-221`, `:229-244`). Neither has anything to do with towns. |

## The registry contract

Selection and registration may change freely; this is what the runtime reads, and it must
keep working exactly as it does now. The index into `civ_locations` is the town ID used by
every consumer.

| Key | Shape | Read by |
|---|---|---|
| `civ_locations` | ordered array of Location objects; consumers call `getPos` and `text` on them | `fnc_civ_handler.sqf:20`, `fnc_civ_handler_wbk.sqf:20`, `fnc_civ_fast_travel_execute.sqf:12`, `fnc_civ_informant_system.sqf:24`, `fnc_civ_developInformantServer.sqf:72`, `fnc_disguiseAsCivilian.sqf:258`, `server_fnc_init.sqf:886` |
| `civ_radii` | parallel array of numbers | same, minus the informant system |
| `civ_pop_<i>`, `civ_max_<i>`, `civ_remaining_<i>` | numbers | `fnc_civ_handler.sqf`, `fnc_recruit_civilian_server.sqf:74` |
| `civ_area_<i>`, `civ_icon_<i>` | marker names (ellipse, population icon) | `fnc_civ_handler.sqf:117-129`, `server_fnc_init.sqf:790,881` |
| one presence trigger per town | calls `fnc_civ_handler` / `fnc_civ_handler_wbk` with `[_index, "spawn"\|"cleanup"]` | — |
| `civ_spawn_enabled_time` | number | `fnc_civ_handler.sqf:208-216` |

Dropping `createLocation` does not break this: every consumer uses `getPos` and `text`,
which work on map Locations natively. It also removes a multiplayer asymmetry — a
server-created Location's label is not broadcast, whereas map towns carry the same name on
every machine.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_civ_selectTowns.sqf` | New. Anchors, eligibility, ranking, cap. |
| `server/misc/fnc_civ_init_Tomata.sqf` | Rewritten around the new selector; sizing and registration only. |
| `server/misc/fnc_civ_rep_economy.sqf` | New. The two background loops lifted out of init. |
| `server/misc/fnc_civ_detectClusters.sqf` | Deleted. |
| `server/misc/fnc_civ_locator_Tomata.sqf` | Deleted; its one `nearestLocations` call moves into the selector. |
| `server/server_fnc_init.sqf:307-339` | Registry: drop the two deleted entries and the `publicVariable` on detectClusters, add the two new ones. |
| `shared/includes/notifications.hpp:337-360` | Drop the `dc` / `dcb` scan-progress classes. |
| `stringtable.xml:7837,7928,7935,7942` | Drop `STR_DUWS_T_DYNAMIC_TOWN`, `STR_DUWS_T_dc1`, `STR_DUWS_T_dc2`, `STR_DUWS_T_dc3`. |
| `info/zone_and_town_generation.md` | Rewrite Subsystem B and its defect list to describe what ships. |

No file under `init_zones/` is edited.

## Task list

- [ ] Write `fnc_civ_selectTowns.sqf`; register it. Verify: `bash tests/run.sh` passes the path lint.
- [ ] Rewrite `fnc_civ_init_Tomata.sqf` to call the selector, keeping the sizing and overlap passes and the full registry contract above.
- [ ] Move the reputation-recovery and CP-reward loops into `fnc_civ_rep_economy.sqf`; spawn it from init. Verify: reputation still ticks up after a quiet period.
- [ ] Delete `fnc_civ_detectClusters.sqf` and `fnc_civ_locator_Tomata.sqf` and their registry lines. Verify: `bash tests/run.sh` — a stale registry path fails the lint.
- [ ] Drop the orphaned notification classes and stringtable keys.
- [ ] Update `info/zone_and_town_generation.md`.
- [ ] In-game: start a campaign with six random zones and civilians on. Confirm at most 21 purple ellipses, every one on a named map town, none labelled "Dynamic Town", and no "may take minutes" scan pause.
- [ ] In-game: repeat with manual zone placement, which publishes `serv_zones_array` from the client rather than the server.

## Decided trade-offs

**Towns inside enemy zones are allowed.** No keep-out is applied against zone positions.
The consequence to know about: at negative reputation `fnc_civ_handler.sqf:532-560` re-sides
a share of civilians to `resistance`, which `server_init.sqf:28-31` sets hostile to west, and
a zone's capture trigger is `WEST SEIZED` (`fnc_createzone.sqf:259`). Hostile civilians
standing inside a zone therefore block its capture. Handling that is deliberately out of
scope here.

**Fewer towns than before.** The old system produced every map town plus up to 100 invented
ones; the new cap at six zones is 21. Fewer presence triggers and fewer civilian groups is
the point, but a player crossing empty country will meet nobody.

**Ranking has no spatial spread rule.** Top-N by score can cluster the selection around
whichever anchors sit in dense terrain, leaving a remote zone with no civilian town nearby.
If that shows up in play, the fix is a per-anchor quota rather than a global ranking.
