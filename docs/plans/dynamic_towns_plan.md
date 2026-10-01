# Dynamic civilian towns: implementation plan

A lobby parameter selects how the campaign chooses its civilian towns. **Ranked** (the default) is the
current selection: three towns for each anchor, plus a random top-up. **Dynamic** brings back the
earlier building-cluster generation inside the current reach. It takes every map town near the
fighting that holds enough buildings. It then adds up to 100 building clusters that the map does not
name, and each cluster becomes a town called "Civilian Sector KILO".

Only the selection stage branches. Registration, the runtime, reputation, vendors and persistence
stay one pipeline for both modes. The current stages are described in
[`zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#civilian-town-selection).

## The parameter

| Item | Value |
|---|---|
| Lobby class | `DUWS_TownGeneration`, after `DUWS_LoseConditions` in `src/duws/shared/includes/params_modern.hpp` |
| Title | `Civilian Towns` |
| Values | `0` `Ranked (largest towns near the fighting)`, `1` `Dynamic (every town and building cluster near the fighting)` |
| Default | `0` |
| Global | `DUWS_paramTownGen`, read in `server_var_init.sqf` beside `DUWS_paramLoseConditions` (`:80`) and broadcast |
| Persistence | A row in `DUWS_campaignParams` (`server/persistence/fnc_campaign_store.sqf:24-31`) |
| Readout | A row in the mission-parameters block of `client/misc/fnc_duws_config.sqf` (`:101`) |

The parameter is a campaign rule, so the snapshot outranks the lobby for it. A load replays the
saved towns whatever the parameter says. The restored value keeps the settings readout true to the
campaign that the player loaded.

## Selection

`server/civilian/fnc_civ_selectTowns.sqf` keeps its shared front half: the anchors, the candidate map
towns, the in-reach filter and the building survey (up to `:90`). The Dynamic branch starts after the
survey loop and returns before wave 1:

1. Take the HQ quota: the three pool towns with the most buildings within `_ANCHOR_RADIUS` of the HQ.
   This is the same draw as the HQ's turn in wave 1, so a hardcore start shows the same towns in both
   modes.
2. Select every pool town. There is no quota for each anchor and no top-up.
3. Append the clusters from `[_anchors, _hqPos, _candidates] call fnc_civ_detectClusters`.
4. Return `[_selected, []]`. The spare queue is empty, because every qualifying town is in the queue
   already. A town that the HQ keep-out rejects has no stand-in.
5. Write one log line: the anchor count, the map towns selected, the clusters found, the grid points
   scanned and the scan time. This line replaces the Ranked selection line for the Dynamic branch.

### Building clusters

New file `server/civilian/fnc_civ_detectClusters.sqf`, registered beside `fnc_civ_selectTowns` in
`server_fnc_init.sqf` (`:337`). It returns quads in the shape that registration reads:
`[location, buildingCount, false, usableBuildings]`.

1. Lay a grid with a spacing of `_GRID` metres over the map, from `[0, 0]`.
2. Keep a grid point only when all of these are true:
   - The point is on land.
   - The point is within `_ANCHOR_RADIUS` of an anchor.
   - The point is at least `_TOWN_CLEARANCE` from the centre of every candidate map town.
   - The point is at least `_MILITARY_CLEARANCE` from every entry of `serv_zones_array` and from the HQ.
3. Shuffle the kept points.
4. For each point, count the usable buildings within `_CLUSTER_RADIUS`
   (`[_pos, 2, _CLUSTER_RADIUS] call fnc_usableBuildings`). Stop when `_MAX_CLUSTERS` clusters exist.
5. A point with at least `_MIN_BUILDINGS` usable buildings becomes a cluster:
   - `createLocation ["NameVillage", _pos, 0, 0]`, with `DUWS_cluster` set to `true` on the Location.
   - The building list in the quad is `[_pos, 2, 350] call fnc_usableBuildings`. This is the same
     350 m survey that a map town and a restored town use, so registration trims the same list in all
     three cases.
6. Ping the map prompt during the scan with the same throttle and wording as the town survey.

| Constant | Value | Use |
|---|---|---|
| `_GRID` | 800 | Spacing of the sample grid |
| `_CLUSTER_RADIUS` | 100 | Disc in which a grid point counts its buildings |
| `_MIN_BUILDINGS` | 3 | Smallest cluster; the same floor as a map town |
| `_TOWN_CLEARANCE` | 200 | Distance from the centre of a map town |
| `_MILITARY_CLEARANCE` | 800 | Distance from a zone centre or the HQ |
| `_MAX_CLUSTERS` | 100 | Cap on clusters per campaign |

The centre of a cluster is its grid point, not the centroid of its buildings. The town disc is at
least 100 m, so it covers every building that the count found.

### Differences from the earlier scan

| Topic | Earlier scan | This plan | Reason |
|---|---|---|---|
| Building count | An SQF distance loop over every `House` on the map, for each candidate | One engine query of 100 m for each candidate | The loop was O(candidates × map buildings) and took minutes on Altis |
| Building rule | A `House` with one building position or more | `fnc_usableBuildings`: at least four building positions | The crowd and the vendors use only usable buildings, so a cluster of sheds would hold nobody |
| Reach | The whole map | The union of the anchor discs | Civilians stay near the fighting, as in Ranked mode |
| Map towns | Every map Location of the town types with no building floor, plus factory, airfield and military points | The current candidate types and the current floor of three usable buildings | Factories and airfields are not towns, and the floor drops quarries and salt flats |
| Adaptive radius and de-duplication | 50 m, then 100 m; a new cluster rejected within 80 % of that radius of an older one | Removed | Grid points are 800 m apart, so the de-duplication never fired, and registration sizes a town from its count |
| Military keep-out | Read the zone arrays behind a wait that returned at once | Reads `serv_zones_array` | Civilians now generate after zone build-out, so the zones exist |
| Name | `Dynamic Town N` | `Civilian Sector <word>` | A spoken name in the style of the zone callsigns; see [Registration](#registration) |

Clusters avoid zones, and map towns do not. A map town in a zone opens at `-20` because the enemy
holds the ground. A cluster that opened there would put a synthetic hamlet on OPFOR's books.

## Registration

Three changes in `server/civilian/fnc_civ_init_Tomata.sqf`:

1. **Dispatch** (`:30`). Ranked or Dynamic selection by `DUWS_paramTownGen`. The restore path does
   not change.
2. **Delete the dropped clusters.** A cluster that the HQ keep-out rejects, or that the overlap cull
   drops (`:99-160`), gets `deleteLocation`. A map Location stays in the engine, as now. A dropped
   cluster that stayed in the engine would be a town to server-side `nearestLocations` readers that
   no registry holds.
3. **Name the kept clusters** after the cull. A kept Location with `DUWS_cluster` and no
   `DUWS_sector` draws a word from `fnc_zone_name` (`init_zones/fnc_zone_state_init.sqf:24`). The
   Location gets `DUWS_sector` set to the word, and
   `setText format [localize "STR_DUWS_T_civ_sector", _word]`.
   - Naming runs after the cull so that a dropped cluster does not use a word.
   - `fnc_zone_name` draws from the zone pool, `DUWS_zoneNames`. Every zone has its name before
     civilians generate, so no sector shares a word with a zone or with another sector.
   - After 26 names, the pool pairs two words (`KILO-BRAVO`), as it does for zones.
   - The word prints in capitals, as a zone name does.

New stringtable key `STR_DUWS_T_civ_sector`, English `Civilian Sector %1`, with every language tag
that the file carries. The `%1` stays, and the phonetic word is never translated.

The radius formula, the HQ keep-out, the overlap cull, the reputation and AP worth, the markers and
the vendor draft do not change.

## Persistence

| Item | Change |
|---|---|
| Parameter | A row in `DUWS_campaignParams`, as in [The parameter](#the-parameter) |
| Town row | `[pos, radius, pop]` becomes `[pos, radius, pop, sector]` in `fnc_campaign_save.sqf:140-148`; `sector` is `""` for a map town |
| Town restore | `DUWS_fnc_restoreTownQueue` (`fnc_campaign_restore.sqf:322`): a row with a sector word creates its Location directly, with `DUWS_cluster`, `DUWS_sector` and the formatted text, and logs no "no town at" warning. A row without one resolves as now |
| Older saves | A row with no fourth element reads `""` through a `params` default, so every row in an older save is a map town. The format version stays `1` |
| Sector words | `DUWS_zoneNames` already saves and restores (`fnc_campaign_save.sqf:135`, `fnc_campaign_restore.sqf:272`), and now holds the sector words too |

The snapshot holds the word, not the text. The server localises the text, so a load on a host in
another language renders the name in that language.

## Effects of the larger town count

Dynamic mode registers more towns than Ranked's `4 × zones + 3`. On Altis it can pass the 160 towns
that `zones_and_civilians.md` uses as its large-campaign case. `_MAX_CLUSTERS` is the lever for the
total.

| Consumer | Effect |
|---|---|
| Town streaming thread (`fnc_civ_handler`) | One presence test for each town on each tick |
| Overlap cull at registration | A pair pass over every town, once at generation |
| Vendor draft (`fnc_vendor_init`) | One draft for each town, so the campaign has more shops |
| Town income | More towns can enter a band. Dynamic takes every map town that overlaps a zone, not only the three largest for each anchor, so OPFOR opens with more towns at `-20` and more town income. A cluster opens neutral |
| OPCOM | One town site and its grid cells for each town |
| Hardcore | More hidden towns to find |
| Server-side place names | `fnc_place_name` and `fnc_hardpoint_stream` can name a position after a sector when they run on the server |
| Client-side lookups | `createLocation` is local to the server, so the bottom-right location readout and the side-mission picker snap (`fnc_site_cluster`) do not see clusters |

## Files touched

| File | Change |
|---|---|
| `src/duws/shared/includes/params_modern.hpp` | Add `DUWS_TownGeneration` |
| `src/duws/server/server_var_init.sqf` | Read and broadcast `DUWS_paramTownGen` |
| `src/duws/server/persistence/fnc_campaign_store.sqf` | Add the row to `DUWS_campaignParams` |
| `src/duws/client/misc/fnc_duws_config.sqf` | Add the readout row |
| `src/duws/server/civilian/fnc_civ_detectClusters.sqf` | New: the cluster scan |
| `src/duws/server/server_fnc_init.sqf` | Register `fnc_civ_detectClusters` |
| `src/duws/server/civilian/fnc_civ_selectTowns.sqf` | Add the Dynamic branch after the survey |
| `src/duws/server/civilian/fnc_civ_init_Tomata.sqf` | Dispatch, delete dropped clusters, name kept clusters |
| `src/stringtable.xml` | Add `STR_DUWS_T_civ_sector` with every language tag |
| `src/duws/server/persistence/fnc_campaign_save.sqf` | Add the sector word to the town row |
| `src/duws/server/persistence/fnc_campaign_restore.sqf` | Restore a sector row as a cluster |
| `docs/info/gameplay/zones_and_civilians.md` | Describe Dynamic mode in §Civilian town selection; make "no synthetic locations" and the `deleteLocation` note conditional on the mode |
| `docs/plans/campaign_persistence_plan.md` | Civilians row: positions, radii, populations and the sector word of a generated town. The row lists names now, but the save stores none |

## Steps

1. Wire the parameter: the lobby class, the global, the `DUWS_campaignParams` row and the readout
   row. Verify: `bash tests/run.sh` passes.
2. Write `fnc_civ_detectClusters.sqf` and register it. Verify: `bash tests/run.sh` passes the path
   lint, and the sqf-vm parse check reports no error on the file.
3. Add the Dynamic branch to `fnc_civ_selectTowns.sqf`. Verify: the parse check passes. In Ranked
   mode the selection log line does not change.
4. Change the registration: dispatch, cluster deletion, cluster naming and the stringtable key.
   Verify: the parse check passes, and every language tag on the new key keeps `%1`.
5. Add the sector word to the save and the restore. Verify: the parse check passes on both files.
6. Update `zones_and_civilians.md` with the code change, and the persistence plan in its own
   `docs(plans)` commit.

In a Dynamic campaign, the RPT shows the Dynamic selection line with the cluster count and the scan
time, and one `Created markers` line for each kept town, clusters by their sector names.
