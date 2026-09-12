# Side-mission site-finder consolidation: design plan

Two shared offer-time finders — `fnc_site_cluster` and `fnc_site_town` — replace the hand-copied
placement logic scattered across the mission threads' `fnc_<name>_site` files. The goal is one vetted
implementation of each recurring survey shape, so a fix or tuning change lands once instead of in three
to four near-identical copies, and so the `"map"` types that currently ship no finder at all can adopt a
real one.

This plan touches only the **offer-time** finder layer (the `fnc_<name>_site` functions that
`fnc_mission_findSite` resolves and calls in the strategic-map picker). The separate **spawn-time**
resolver (`fnc_mission_site` → `fnc_missionTargetPos`, run in the thread) is out of scope; see
[The two-layer split](#the-two-layer-split-out-of-scope).

## Why

`fnc_mission_findSite.sqf:46-47` resolves each type's finder as `fnc_<name>_site`, falling back to the
accept-all `fnc_site_generic` when none exists, then calls `[_cand] call _finder` per candidate
(`fnc_mission_findSite.sqf:322`). Three problems have accumulated in that per-type layer:

- **Cluster-snap is copied three times.** `fnc_rescue_hostage_site.sqf`, `fnc_rescue_squad_site.sqf`,
  and `fnc_protect_civ_site.sqf` each run the same shape: `nearestLocations` for the nearest
  settlements, count enterable buildings in the cluster, reject towns and zone edges, return a building
  or the cluster centre. They differ only in constants (accept radius, minimum buildings, seat size,
  zone standoff) and in whether they reject all registered towns or only side-held ones.

- **Nearest-non-enemy-town is copied four times.** `fnc_site_civ_town.sqf` (shared by escort_informant
  and deliver_supplies), `fnc_raid_safehouse_site.sqf`, `fnc_transport_IDAP_site.sqf`, and
  `fnc_informant_site.sqf` each re-read `duws_town_circles` and `DUWS_enemy_town_pos` and re-implement
  "the nearest town whose centre is not in the enemy-band list", then layer their own extra gate on top.

- **Eight `"map"` types ship no finder** and fall through to accept-all: rescue_pilot, steal_supply,
  steal_builder, destroy_cache, destroy_radar, target_sniper, target_recon, deny_armor. Most site fine
  on open ground. Two do not: `destroy_cache` and `destroy_radar` build their garrison with
  `fnc_garrisonBuildings` (`fnc_destroy_cache_mission.sqf:79`, `fnc_destroy_radar_mission.sqf:81`),
  which finds nothing on an open-ground dot, leaving that defensive layer empty. The bunker guns and
  patrols still spawn, so the mission is degraded rather than broken — but the placement is worse than
  when the More Urban toggle still forced these into towns.

## Locality and constraints

Both helpers run in the picker (`client/missions/fnc_stratmap.sqf`) on whichever machine opened the
strategic map, so they are subject to the same rules the existing finders already follow:

- **Broadcast state only.** Read `missionNamespace getVariable` on published globals
  (`duws_town_circles`, `DUWS_enemy_town_pos`, `zone_meta_array`) and pure engine queries
  (`nearestLocations`, `nearestTerrainObjects`, `buildingPos`, `locationPosition`). Server-only
  functions are unavailable on a client: `fnc_usableBuildings` (`server_fnc_init.sqf:84`),
  `fnc_civ_townAt` (`fnc_civ_state_init.sqf:6`), and the token vocabulary including
  `DUWS_fnc_tokenMenCount` (`fnc_spawn_vocab.sqf`, loaded only at `server_fnc_init.sqf:606`). None may
  be called from a finder.

- **Fixed size floors, not live counts.** Because the token vocabulary is server-only, a finder cannot
  read a mission's live squad size; `fnc_rescue_squad_site.sqf` uses a fixed seat floor sized to the
  recon roster's fixed five men. `fnc_site_cluster` keeps that pattern: the caller passes a minimum
  building-position count, not a token.

- **Unscheduled-safe.** The picker calls finders inside an unscheduled context, so no `sleep`/`waitUntil`.

- **Loop with an `isNull`/index guard, never `exitWith` inside a `then` nested in a `forEach`.** That
  nesting is ambiguous — the `exitWith` may exit only the `then` and let the loop overwrite a nearer
  result with a farther one. Guard the loop body with a "first match wins" test (`nearestLocations`
  returns settlements nearest-first) as the current cluster finders do.

Both are shared helpers, not per-type finders, so they live beside `fnc_site_generic` and
`fnc_site_civ_town` under `src/duws/server/missions/`, are compiled and `publicVariable`'d in
`server_fnc_init.sqf` (the picker needs them broadcast), and are added to `tests/unit/functions.txt` if
the unit suite references them.

## `fnc_site_cluster`

A settlement-cluster finder: from an offered dot, snap to the nearest qualifying building cluster and
return a real building's position.

**Contract:** `[_pos, _minBuildings, _minSeatSlots, _townPolicy, _zoneStandoff] -> [] | [_buildingPos]`.
Snap and accept radii stay internal constants (1500 m and 350 m, matching all three current copies)
rather than parameters, since no caller varies them.

- `_minBuildings` — enterable buildings the cluster must hold (the `buildingPos 3` test).
- `_minSeatSlots` — building positions the returned building must offer, so a caller that seats a group
  in one building gets a big enough one.
- `_townPolicy` — `"reject-all"` skips any settlement inside a registered town circle (hamlets pass);
  `"allow-neutral"` skips only side-held towns, matching rescue_hostage's covert-but-not-isolated rule.
- `_zoneStandoff` — metres of clearance the returned building keeps from every capturable-zone edge
  (`zone_meta_array`); `0` disables the check.

Returning a **building position** (not the cluster centre) serves every caller: a thread that searches a
radius around the offer still finds the building, and a thread that re-derives within a tight radius
(protect_civ's 30 m, `fnc_protect_civ.sqf:24`) gets the exact building it needs.

**Adopters** (each `fnc_<name>_site.sqf` becomes a one-line wrapper passing its constants):

- rescue_hostage — `_minBuildings 3`, `_minSeatSlots 3`, `"allow-neutral"`, `_zoneStandoff 300`.
- rescue_squad — `_minBuildings 3`, `_minSeatSlots 6`, `"reject-all"`, `_zoneStandoff 150`.
- protect_civ — `_minBuildings 1`, `_minSeatSlots 4`, `"reject-all"`, `_zoneStandoff 0`.
- destroy_cache, destroy_radar — new finders, `"reject-all"`, a modest `_minBuildings`/`_minSeatSlots`
  sized to the garrison. This is a placement-quality gain, not a crash fix (the garrison layer is
  opportunistic), so it is the lowest-priority adoption and can land after the dedup is proven on the
  three existing callers.

sabotage_laptop is **not** an adopter: it seats laptops across several buildings and needs the whole
candidate list, not one building, so its finder keeps its own cluster test.

## `fnc_site_town`

The "nearest deliverable town" primitive the four town finders share — deliberately smaller than the
finders themselves, because their extra gates genuinely differ and should stay per-mission.

**Contract:** `[_pos, _maxReach] -> [] | [_townCentre]`. Returns the nearest town centre from
`duws_town_circles` whose centre is not in `DUWS_enemy_town_pos`, within `_maxReach` metres, else `[]`.
Empty `duws_town_circles` (civilians off) returns `[]`, matching every current town finder.

**Adopters:**

- escort_informant, deliver_supplies (via `fnc_site_civ_town`) — `[_pos, 2500]`, return the centre
  directly.
- transport_idap — `[_pos, 1e9]` for the town pick, then apply its own reach-ring offset
  (`fnc_transport_IDAP_site.sqf`) so the truck sits in contested ground toward the dot.
- raid_safehouse — the town pick, then its own "≥ 5 door-having buildings" gate.
- informant — the town pick, then its own `CIV_PRESENCE` and escape-zone gates.

The extra gates stay in each `fnc_<name>_site`; only the town enumeration collapses into the helper.

## Sequencing

1. `fnc_site_cluster` + convert the three existing cluster finders to wrappers. This is a pure
   refactor with no behaviour change — the constants above reproduce today's placement — so it is
   verifiable by diffing offered positions before and after.
2. `fnc_site_town` + convert the four town finders to use it. Also behaviour-neutral.
3. New cache/radar cluster finders. This one *changes* placement (open-ground dots now snap to a
   cluster), so it ships separately and is play-tested on its own.

## The two-layer split (out of scope)

A mission is sited twice: the offer finder above, and then the thread's `fnc_mission_site` →
`fnc_missionTargetPos`, which re-resolves a building/target position around the offered dot and, finding
none, falls back to open ground behind a player-facing "finding a safe placement" hint and a `sleep 5`
(`fnc_missionTargetPos.sqf:17-25`). The two can disagree, and the fallback now fires routinely for the
accept-all `"map"` types. Making the offered position authoritative — so the thread trusts it instead of
re-deriving — would remove both the disagreement and the hint/stall, but it touches every thread that
calls `fnc_mission_site` and each thread's assumptions about what that call returns. It is a larger,
separate change and is not part of this consolidation.
