# Hardpoint system: implementation plan

Add a third objective tier between side missions and zone capture. A **hardpoint** is a small
garrisoned emplacement — one destructible *core object*, a handful of guards, some cover — that
the player clears on foot. Two flavours, differing only in where they sit and what they are for:

| Flavour | Sited | Purpose |
|---|---|---|
| **Zone hardpoints** | inside an enemy zone, count scaled to its radius | all of them must be cleared before the zone can be captured |
| **Normal hardpoints** | on the corridors between enemy zones and BLUFOR-held ground | standalone CP objectives; a few exist at start, the enemy director builds more |

Zone hardpoints turn zone capture from "stand in the circle until the trigger fires" into a
sequence of small fights whose length the zone's own radius already decides. Normal hardpoints
are the tier that gives a CP-starved player something to do that also *takes something away
from the enemy*, because clearing one debits the OPFOR Army Power pool the enemy director
spends on escalation.

Hardpoints run on their own state and their own clear handler. They must not pass through
`fnc_createZone` or `fnc_zone_control_set`, for reasons set out under
[§Why hardpoints cannot be small zones](#why-hardpoints-cannot-be-small-zones).

Background on how zones are placed, captured and consumed:
[`info/zone_and_town_generation.md`](info/zone_and_town_generation.md).

## Why hardpoints cannot be small zones

`fnc_createZone` writes five campaign registries in its first fourteen lines
(`server/init_zones/fnc_createzone.sqf:19-32`) and `fnc_zone_control_set` moves four globals
as one atomic transition (`server/server_fnc_init.sqf:81-120`). Both are all-or-nothing.
Routing a hardpoint through either puts it into every consumer of zone state at once:

| Global | Written by | What breaks if a hardpoint increments it |
|---|---|---|
| `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-20` | The campaign never ends. The win condition is `zoneundercontrolblu >= amount_zones_created` (`server/misc/fnc_capture_zones_task.sqf:33`). FOB cap inflates too (`client/supports/fnc_request_fob.sqf:16`) |
| `zoneundercontrolblu` | `server/server_fnc_init.sqf:97,110` | Passive income becomes `(zones + hardpoints) * 6` per 30 min (`server/misc/fnc_zonesundercontrol.sqf:11`) — the largest balance blow-up available |
| `WARCOM_zones_controled_by_OPFOR` | `server/server_fnc_init.sqf:95,107-108` | Index 0 is the OPFOR primary assault target. A lost hardpoint redirects the entire enemy war effort. 25+ read sites |
| `zone_namePOS_pairs` | `server/init_zones/fnc_createzone.sqf:28-29` | Intel reveals pick a random entry (`client/misc/fnc_found_intel.sqf:5`), so hardpoints dilute what intel is worth |
| `zone_spawn_array` | `:32` | Lookup is positional — `find [_zone_num,false,false]` (`:221`) — so a duplicate number matches the wrong entry |

The hardpoint tier therefore gets parallel state built to the same template, and touches none
of the above. The one deliberate coupling is a *read*: the zone capture trigger reads a
per-zone hardpoint counter, covered in [§The capture gate](#the-capture-gate).

## Hardpoint types

One core object per hardpoint. The core is what the player is told to destroy, what the map
icon marks, and the only thing the clear rule looks at.

| Type | Core | Garrison | Effect while alive | Clear pays |
|---|---|---|---|---|
| MG nest | `opfor_TURRET_HMG` + sandbags | gunner + 1-2 | covers an approach | 2 CP zone / 5 CP normal |
| Observation post | vanilla tower or radar prop | 2-3 | `reveal`s BLUFOR within ~800 m to EAST, so patrols and QRF react to what it sees | 2 / 5 CP |
| AA position | `opfor_TURRET_AA` | gunner + 1-2 | denies the air corridor — taxi, helolift, CAS | 3 / 8 CP |
| Artillery position | `opfor_TURRET_MORTAR` | gunner + 2 | shells BLU-held zones and FOBs in range ([§Artillery hardpoints](#artillery-hardpoints)) | 3 / 8 CP |

Unit classnames come from the `opfor_*_X` faction globals exactly as
`server/init_zones/fnc_createopfortified.sqf:14,23,43` does. Hardcoding unit or turret
classnames is the single change that would break mod-free operation and faction
auto-detection; hardcoding vanilla `Land_*` structures is fine, and the zone code already does
it (`fnc_createzone.sqf:145-151`).

**`opfor_TURRET_HMG` already exists and is used nowhere.** Every faction file defines it
(`shared/factions/MODERN/*_opfor.sqf:35-36`, `AUTODETECT_opfor.sqf:115`) and no script reads
it. The MG nest is its first consumer.

**`opfor_TURRET_AA` and `opfor_TURRET_MORTAR` do not exist yet, but the data does.**
`fnc_parseFaction` already returns `_turretAA` and `_turretMortar`
(`shared/factions/MODERN/fn_factionAutoDetect.sqf:583-586`); the OPFOR generator discards both,
while the BLUFOR one keeps its equivalents (`AUTODETECT_blufor.sqf:118-121`). Two lines in each
autodetect generator plus an entry in `o_arraysToRandomize` (`AUTODETECT_opfor.sqf:186`) closes
the gap.

The 132 hand-authored faction files must **not** be swept to add the new globals. Read them as
`missionNamespace getVariable ["opfor_TURRET_AA", "O_static_AA_F"]` — a vanilla fallback, which
is what the `fnc_selectNonEmpty` chains in autodetect already end in, and which keeps a faction
file that predates this feature working untouched.

## Zone hardpoints

### Where the pass runs

Inside `fnc_createZone`, not in a separate siting pass off `serv_zones_array`. Three reasons,
all decisive:

- **Radius only exists there.** `serv_zones_array` entries are two-element `[x,y]`
  (`fnc_locatorzones_random.sqf:180`); the radius is a script local, rolled at `:52-56` and
  never stored. Scaling the count to radius from outside is impossible until the
  `zone_meta_array` prerequisite in
  [`campaign_persistence_plan.md`](campaign_persistence_plan.md) lands.
- **Both locators already funnel through it.** Random placement `spawn`s it (`:185`); manual
  placement `remoteExec`s it to target 2 (`fnc_locatorzones_manual.sqf:94`). A pass inside
  `fnc_createZone` is server-side in both cases and needs no wait on a client-published array.
- **The zone index is in hand.** `_zone_num` keys the per-zone counter the capture trigger
  reads, and it is unique by construction, unlike the coordinate-derived names used elsewhere.

Placement point: after the fortification ring (`fnc_createzone.sqf:199`), before the QRF object
(`:201`). That is upstream of the `zones_buildout_done` increment at `:221`, so the "Building
zones..." prompt and the civilian-generation gate keep describing reality
(`fnc_init_OPFOR_WARCOM.sqf:39-49`).

### Count and siting

Radius is in `(zones_min_radius, zones_max_radius]` — `(200, 1000]` as shipped
(`server/server_var_init.sqf:216-220`):

```sqf
private _count = ((1 + floor (_size / 220)) + floor (random 2)) min 6;
```

200 m gives 1-2, 500 m gives 3-4, 1000 m gives 5-6. The `min 6` matters: `zones_max_radius` is
player-settable and a 6-zone campaign at 5 hardpoints each is already 30 extra emplacements.

Sited in the annulus between `0.35 * _size` and `0.9 * _size`: outside the 35 m the prefab pass
clears (`:66`), inside the capture trigger, whose area is `[_size, _size]` — `_size` is the
*radius* of a circular trigger, not a diameter (`:267`).

Rejection rules, cheapest first: 120 m from another hardpoint, 40 m from a placed fortification
(the ring stores its objects at `:198`), not on water.

**Do not reuse the fortification ring's collision test.** `:188-189` rejects a spot if
`nearestObjects [_safePos, [], 8]` finds anything, and the empty type filter makes that include
terrain objects, so in the dense towns `moreUrban` targets almost every spot is rejected — the
documented reason fortification towers barely appear in towns
([`info/zone_and_town_generation.md`](info/zone_and_town_generation.md#defects-subsystem-a)).
Inheriting it here would silently produce zones with zero hardpoints, which is worse than a
missing tower: it makes the whole gate transparent. Filter to the classes that actually block
placement.

### The capture gate

One broadcast number per zone, `zone_hp_left_<zone_num>`, read directly in the capture
trigger's condition (`fnc_createzone.sqf:266-270`):

```sqf
_trg setTriggerStatements [
    format ["this && ((missionNamespace getVariable ['zone_hp_left_%1', 1]) <= 0)", _zone_num],
    format ["[""%1"",%2,""%3"",""%4"",%5,%6] spawn fnc_captured", …], ""];
```

Single quotes inside the condition, so the `format` needs no doubled-quote escaping — the
activation statement below it shows what the alternative reads like.

**The gate has to live in the condition, not in the handler.** A trigger fires on a false→true
transition. If `fnc_captured` instead refused a capture while hardpoints remained, the condition
would stay true for as long as the player stood in a cleared zone, so it would never re-fire:
the zone would become permanently uncapturable until everyone left and came back.

**The default is `1`, not `0`.** A global trigger is evaluated on every machine, which is why
`fnc_captured` asserts `isServer` at all (`fnc_captured.sqf:12-14`). Defaulting to "one left"
means a machine that has not yet received the broadcast cannot evaluate the gate as satisfied.

**A zone with zero placed hardpoints is capturable immediately.** That is the intended failure
mode: siting can legitimately place nothing (a zone centred on a lake shore), and the counter is
written from what was actually placed, never from the rolled count. A zone that cannot be
captured is unrecoverable; a zone that is slightly easier is not.

### Reveal

Markers are created at alpha 0 and revealed when the player first enters the zone, alongside the
existing zone-entry notification (`server/misc/fnc_enterlocation.sqf:15`). Two reasons: 30 red
icons at campaign start reads as a map covered in noise rather than a war to explore, and the
count remaining is the useful readout, so it goes in the notification body rather than being
inferred from icons. In hardcore mode hardpoint markers follow the zone's own rule — hidden
until `fnc_zone_reveal` reveals the parent — and since hardpoints stay out of
`zone_namePOS_pairs`, that file needs no change.

## Normal hardpoints

### Siting

Anchored on a *pair*: an OPFOR zone (`WARCOM_zones_controled_by_OPFOR`) and the nearest
BLUFOR-held position. Placed 35-65% along the segment between them with lateral jitter, so
hardpoints appear on the ground the player has to cross rather than at either end.

BLUFOR anchors available today: `WARCOM_zones_controled_by_BLUFOR`, `PosOfBLUHQ`, and FOBs.
`Array_of_FOBS` holds *objects*, not positions (`server/supports/fnc_fob_server.sqf:78`), so
read it as `Array_of_FOBS apply {getPos _x}` until the `Array_of_FOBpos` prerequisite in
[`campaign_persistence_plan.md`](campaign_persistence_plan.md) lands.

Rejection rules: 800 m from `PosOfBLUHQ` and from any FOB, `zones_max_radius * 0.9` from any
zone centre (a hardpoint inside a zone would be a zone hardpoint that does not gate it), 400 m
from another hardpoint, 1000 m from any player, not on water. The player keep-out reads
`allPlayers`, never `player` — a bare `player` read server-side is `objNull` on a dedicated
server and the distance test then always passes, which is exactly the bug
`fnc_WARCOM_blu_patrol.sqf` shipped with
([`info/server_client_authority.md`](info/server_client_authority.md#dedicated-server-compatibility)).

**The civilian-town anchor is a named seam, not a dependency.** The design intent is corridors
between enemy zones and *enemy-held towns*, but towns have no ownership today:
`fnc_civ_init_Tomata.sqf:163-164` registers `civ_locations` / `civ_radii` with no side, and the
registry is server-local rather than broadcast — which is fine here, because siting is
server-side anyway. When town ownership exists it appends to the anchor list and nothing else
changes. Building on it now would mean inventing the ownership model inside this plan.

### The director and its budget

`WARCOM_opfor_ap` is the price. It is already the enemy's escalation ladder — patrol and assault
composition step up at 10/40/65/100/136 AP (`fnc_WARCOM_opf_assault.sqf:8-21`,
`fnc_WARCOM_opf_patrol.sqf:8-14`) — and it has a single server-side writer, `fnc_ap_adjust`
(`server/server_fnc_init.sqf:41`). Using it means hardpoint construction competes with enemy
armour for the same pool, which is the first genuine *decision* the OPFOR side has.

Spending AP is safe against the ladder: each threshold is a one-shot `waitUntil` that latches
the wave type and never re-tests it, and the one loop that does re-roll exits for good at 136 AP
(`fnc_WARCOM_opf_assault.sqf:21-31`). So spending delays future escalation and cannot roll back
escalation already reached.

| Knob | Value | Why |
|---|---|---|
| Seed subset | 2-3 at WARCOM init, free | The player should meet the mechanic before the director has any AP to spend |
| Build price | OP 8, MG 10, AA 20, artillery 25 AP | Ordered by how much each one costs the player to deal with |
| Build tick | one candidate every 20-30 min | Slower than the 45-90 min patrol cadence (`fnc_WARCOM_opf_patrol.sqf:178`), faster than the 30 min assault cycle |
| Live cap | `3 + count WARCOM_zones_controled_by_BLUFOR`, hard max 8 | Pressure scales with the player's success, and the cap bounds the unit budget |
| Clear debit | −10 AP, −15 for artillery | Clearing one attrits the enemy's escalation budget, not just a CP payout |

The director is one thread, `spawn`ed from `fnc_WARCOM_init.sqf` beside the four that already
launch there (`:51-63`). It runs after both side lists exist (`:38-45`), which is what its
anchor pairs read.

## Artillery hardpoints

The type that justifies the tier: a persistent enemy asset that acts on the campaign, so
destroying it changes the player's situation rather than incrementing a counter.

A real crewed static mortar, not a virtual effect. `doArtilleryFire` must be issued from the
machine where the gun is local, and the gun is server-spawned, so the server issues it — the
same locality rule that silently broke `fnc_helolift`
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)).

| Property | Rule |
|---|---|
| Target set | BLU-held zone centres and FOB positions. **Not** `PosOfBLUHQ` |
| Range gate | `_gun inRangeOfArtillery [[_pos], _mag]`, so a gun threatens its own corridor and nothing else |
| Cadence | one fire mission per gun every 25-40 min, 4-8 rounds |
| Ammo | finite (`setVehicleAmmo`); a gun that runs dry goes quiet |
| Telegraph | Allseer radio line plus a temporary marker ~20 s before impact |

HQ is excluded on purpose. Shelling the one position the player cannot abandon, from a gun they
may not have found, is a difficulty the player cannot answer; assault waves already pressure the
HQ and can be fought.

The telegraph is not politeness. Without it the mechanic reads as random damage rather than as
"there is a mortar out there and I should find it", which is the entire point of making the gun
a real object.

Finite ammo also gives the existing OPFOR ammo-truck patrol (`fnc_WARCOM_opf_patrol.sqf:141-175`)
something to be for: intercepting it silences guns the player cannot reach. That is a follow-on,
not part of this plan.

**Fallback if AI static-mortar fire proves unreliable:** spawn the shells directly, as the
player's own artillery support does (`client/supports/fnc_arty.sqf` creates rounds at 800 m
altitude with a downward velocity). Player-facing behaviour is identical and the AI dependency
disappears, at the cost of the gun becoming scenery. Try the real gun first;
[§Open questions](#open-questions) records what has to be verified.

## Clearance

Latched per hardpoint, evaluated by the shared monitor. Cleared when **any** of:

```
isNull _core || !alive _core || damage _core >= 0.9
             || (_core unmanned && no live EAST within 60 m)
```

- `isNull _core` is the important one. `fnc_mission_cleanup.sqf:24-40` deletes every non-WEST,
  non-civilian object within `_radius * 1.2` of a finished side mission, and only skips the sweep
  when an OPFOR zone is within `zones_max_radius * 1.2`. A normal hardpoint in a corridor is
  squarely in scope. Without this clause a deleted core would leave its parent zone permanently
  uncapturable — the single worst failure this design can produce.
- The unmanned-and-clear clause is what makes the tier playable with rifles. A zone gated on
  *destroying* five static weapons is uncappable for a squad without explosives, and an
  observation-post core built from a `Land_*` prop cannot be destroyed by small arms at all.
  Explosives remain the fast path.
- Latched, so a QRF re-manning an abandoned gun cannot un-clear a hardpoint and re-lock a zone
  the player already captured.

Detection is polling, not a `Killed` event handler. The unmanned clause is a state, not an
event, so a poll is needed regardless, and one mechanism means one place for the idempotency
guard. Polling is also the codebase's existing idiom for exactly this
(`shared/functions/fnc_MHQ_destroyed.sqf:4`).

## State

Broadcast parallel arrays, indexed together, all entries numbers or strings — which keeps them
serialisable, since the mission namespace is the save file
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).

| Variable | Shape | Broadcast |
|---|---|---|
| `hardpoint_pos_array` | `[[x,y,0], …]` | on placement |
| `hardpoint_type_array` | `"MG"` / `"OP"` / `"AA"` / `"ARTY"` | on placement |
| `hardpoint_zone_array` | zone number, or `-1` for a normal hardpoint | on placement |
| `hardpoint_state_array` | `0` live, `1` cleared | on every transition |
| `zone_hp_left_<n>` | number per zone | on every transition (the trigger condition reads it) |

Core objects and garrison groups are **not** in the broadcast registry. They go in server-local
namespace keys, `hardpoint_core_<i>`, the way the zone code holds its triggers and fortifications
(`fnc_createzone.sqf:198,274`). Nothing publicVariables an object handle.

One writer, `fnc_hardpoint_state_set [_index, _state]`, in `server/server_fnc_init.sqf` beside
`fnc_zone_control_set` (`:81-120`). It owns `hardpoint_state_array` and `zone_hp_left_<n>`
together, broadcasts both, and pays the reward through the existing delta writers
`fnc_cp_adjust` and `fnc_ap_adjust` (`:12,41`) — never `x = x + n; publicVariable "x"` from a
trigger or monitor body. It is idempotent on an already-cleared index, because two clauses of the
clear rule can become true in the same tick.

## Spawn, despawn and cost

**One monitor thread for all hardpoints**, ticking every 20-30 s over the registry: clear
detection, garrison spawn on player proximity, artillery cadence. Not one thread each. The server
already runs 39 `while {true}` loops across 23 files
([`campaign_persistence_plan.md`](campaign_persistence_plan.md)), and up to 40 hardpoints would
double that for work that is a single pass over two short arrays.

Zone hardpoint garrisons ride the zone's existing spawn/despawn cycle
(`server/init_zones/fnc_spawnWait.sqf`), whose radius is `_size + 400` and therefore already
covers the whole annulus. Two properties of its cleanup at `:107-121` decide the design:

- It skips `StaticWeapon`, so hardpoint **cores survive a despawn**. The re-spawn path must
  re-crew the existing core, never create a second one, or a zone accumulates a fresh turret on
  every despawn cycle.
- A crewman inside a static is caught by neither delete clause — the first excludes
  `StaticWeapon`, the second requires `vehicle _x == _x` — so **gunners survive too**. Only the
  loose garrison despawns, which is the desired behaviour and costs nothing to implement.

Normal hardpoints sit outside every zone, so nothing despawns them. The live cap of 8 is what
bounds them: 8 hardpoints at 2-4 guards is roughly one zone garrison's worth of units.

## Markers

Named `hardpoint_<i>` and `hardpoint_<i>_ellipse`. They must not use the coordinate-derived
scheme: zones use `<round x><round y>` (`fnc_createzone.sqf:38,52`), side missions use
`<markerText><round x><round y>` (`server/missions/fnc_missionMarkerData.sqf:7,17`), and
`createMarker` on a taken name returns `""` with no error. A hardpoint sited within a metre of
either would fail silently.

Icon by type, so the map can be read before committing: `o_hq` for an OP, `o_support` for
artillery, `o_installation` for MG and AA. `ColorRed` while live; deleted, not recoloured, on
clear — a cleared hardpoint is not a holding the player keeps, and a green icon would imply it
is.

## Files touched

| File | Change |
|---|---|
| `server/init_zones/fnc_hardpoint_place.sqf` | New. Builds one hardpoint of a given type at a given position: core, cover, garrison; returns the core. Shared by both flavours. |
| `server/init_zones/fnc_hardpoint_zone_pass.sqf` | New. Count from radius, siting inside the zone, writes `zone_hp_left_<n>` from what was actually placed. |
| `server/warcom/fnc_WARCOM_opf_hardpoints.sqf` | New. Director: seed subset, corridor picking, AP spend, live cap. |
| `server/misc/fnc_hardpoint_monitor.sqf` | New. The single shared loop: clear detection, proximity garrison spawn, artillery cadence. |
| `server/server_fnc_init.sqf` | New `fnc_hardpoint_state_set` beside `fnc_zone_control_set:81-120`; registry lines for the new functions. |
| `server/server_var_init.sqf` | Declare and broadcast the four hardpoint arrays. |
| `server/init_zones/fnc_createzone.sqf:199,266-270` | Call the zone pass; extend the capture trigger condition. |
| `server/warcom/fnc_WARCOM_init.sqf:51-63` | Spawn the director beside the existing four. |
| `server/misc/fnc_enterlocation.sqf:15` | Reveal this zone's hardpoint markers and report the count remaining. |
| `shared/factions/MODERN/AUTODETECT_opfor.sqf:115,186`, `AUTODETECT_RANDOM_opfor.sqf:81,129` | Define `opfor_TURRET_AA` / `opfor_TURRET_MORTAR` from the already-parsed `_turretAA` / `_turretMortar`. |
| `client/missions/fnc_stratmap.sqf:147-155` | Add a 250 m hardpoint keep-out to side-mission siting. Missions already keep out of zones; without this they spawn on top of a hardpoint — and then the cleanup sweep deletes its core. |
| `shared/includes/notifications.hpp` | One notification class for a hardpoint cleared, beside `CPadded:87`. |
| `stringtable.xml` | Hardpoint type names, clear notification, artillery warning line (Allseer), marker labels. |
| `info/zone_and_town_generation.md` | Document the tier, the capture gate and its state contract. |
| `info/cp_economy.md` | Two faucet rows and one AP-sink note. |

## Task list

- [ ] Write `fnc_hardpoint_place.sqf` for the MG type only, called by hand from the debug console. Verify: core, cover and garrison appear, and no hardcoded unit classname is used with a faction mod loaded.
- [ ] Add `fnc_hardpoint_zone_pass.sqf` and call it from `fnc_createZone`. Verify: `bash tests/run.sh` passes the path lint; hardpoint count per zone tracks radius; nothing lands on water or inside the prefab's 35 m.
- [ ] Add the registry, `fnc_hardpoint_state_set` and the monitor's clear detection. Verify: destroying a core decrements `zone_hp_left_<n>` exactly once, and so does killing the crew and walking away.
- [ ] Extend the capture trigger condition. Verify: a zone with hardpoints left cannot be captured; the last clear makes it capturable *without* the players leaving and re-entering; `zoneundercontrolblu` and `amount_zones_created` are unchanged by any clear.
- [ ] Delete a core with `deleteVehicle` mid-campaign. Verify: the zone still becomes capturable. This is the `fnc_mission_cleanup` failure mode and must be tested directly rather than waited for.
- [ ] Add the remaining three types and the faction-global fallbacks. Verify: an AA hardpoint engages a heli taxi; an OP's `reveal` reaches the QRF.
- [ ] Add the director, seed subset and AP accounting. Verify: OPFOR AP drops by the build price, and the live cap holds as BLUFOR takes zones.
- [ ] Add artillery fire missions. Verify: rounds land only on BLU-held zones and FOBs within `inRangeOfArtillery`, the warning precedes impact, and a dry gun stops.
- [ ] In-game: capture every zone and confirm the campaign still ends.
- [ ] In-game: repeat with manual zone placement, where `fnc_createZone` arrives by `remoteExec` from a client.
- [ ] On a dedicated server: confirm the capture gate and the director both work. A hosted session is both server and client and will mask locality faults.
- [ ] Update `info/zone_and_town_generation.md` and `info/cp_economy.md`.

## Decided trade-offs

**Hardpoints cannot be retaken.** Clearing is one-way; there is no `EAST SEIZED` re-arm as zones
have (`fnc_captured.sqf:66-71`). The director builds *new* hardpoints instead, which gives the
enemy a way to reapply pressure without teaching WARCOM's assault, QRF and patrol logic — all of
which read `WARCOM_zones_controled_by_*` — about a second kind of holding.

**There is no passive income term.** Zone capture pays `radius/10` halved plus `zones_held * 6`
every 30 min; side missions pay 5-45 CP. A third recurring faucet would feed the snowball the
economy review already flags
([`info/cp_economy.md`](info/cp_economy.md#balance-concerns)), and it is not needed: what makes a
hardpoint worth clearing is the zone it unlocks and the AP it costs the enemy.

**Zone hardpoints pay less than normal ones.** Clearing a zone hardpoint is work the zone payout
already prices, so 2 CP is an acknowledgement rather than a wage — it exists so a player who
clears three and then dies has something to show. Normal hardpoints are the whole objective, so
they carry the whole reward.

**Zone capture gets slower, deliberately.** Every zone now needs 1-6 emplacements cleared first,
and the biggest zones need the most. The campaign lengthens and a single zone stops being a
ten-minute errand. If that reads as too slow in play, the lever is the divisor in the count
formula, not the gate.

**The count is a formula, not a setting.** `zones_number` already ranges widely and the hardpoint
count multiplies it; a separate knob invites 6 zones x 8 hardpoints and 48 extra garrisons. The
`min 6` clamp is there because `zones_max_radius` *is* player-settable.

**No dependency on town ownership or on the civilian system.** The corridor anchors are the zone
lists, the HQ and FOBs — all broadcast, all present with civilians switched off. Towns join the
anchor list when they have an owner.

## Open questions

Both are in-game observations that decide implementation details, not design choices.

**Does an unmanned EAST static weapon block `WEST SEIZED`?** Zone capture fires on a
`["WEST SEIZED","PRESENT",true]` trigger (`fnc_createzone.sqf:268`). If an empty enemy-sided
static counts as enemy presence, a cleared MG nest whose turret still stands would hold its own
zone, and the clear rule would additionally have to delete or re-side the core. The tree offers
no evidence either way: the statics in the prefabs are BLUFOR- and independent-classed
(`server/init_zones/prefabs/modern/*.sqf`), and `opfor_TURRET_HMG` has never been spawned by
anything. Test before writing the clear handler.

**Will an AI gunner in a static mortar reliably execute `doArtilleryFire`?** If not, the
shell-spawn fallback above becomes the implementation, and the gun is a target rather than a
weapon.
