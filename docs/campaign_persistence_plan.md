# Campaign persistence: implementation plan

Make a campaign survive a server restart. The mission saves a data-only snapshot to
`missionProfileNamespace` and, on the next start, rebuilds the world by feeding that snapshot
back through the **existing** builders rather than through a second construction path.

Live units are not persisted. Zones, the HQ and FOBs are rebuilt and re-garrisoned from scratch;
what carries over is campaign state — pools, zone ownership, placement, reputation, unlocks.

## What the current save does not cover

Whether `saveGame` produces anything in a multiplayer session is **untested** — see
[`KNOWN_ISSUES.md`](../KNOWN_ISSUES.md#does-a-multiplayer-save-happen-at-all). This plan takes no
position on it. Every row below is read off the source and holds either way.

| Problem | Where |
|---|---|
| The only save is vanilla `saveGame`, reached from one place: the SITREP support | `server/misc/fnc_autoSave.sqf:11`, sole caller `server/supports/fnc_sitrep_support.sqf` |
| Engine autosave and the save menu are switched off at boot | `server/server_init.sqf:113` |
| `civ_locations` stores Location objects in the mission namespace, which the mission's own rule forbids because the namespace is what a save serialises | `server/misc/fnc_civ_init_Tomata.sqf:163-164`, rule in [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) |
| Support unlocks are client-local by design — *"Supports are local to players. No need for publicVariable"* — so there is no server-side copy of what the player paid for | `client/includes/supports_init.hpp` |

The last two rows are why an engine save cannot be the mechanism even in the case where it
works. A server-side save has no access to unlocks the client paid for and never broadcast, and
a namespace holding Location handles is a serialisation hazard *because* something is trying to
serialise it. A working `saveGame` would make those two worse, not better.

## What a naive restore gets wrong

Writing the snapshot is the easy half. These are the properties of the existing builders that
punish a restore which simply assigns the saved globals and lets boot proceed. Each is current
behaviour, correct for a fresh campaign, and each is resolved in the design below.

| Problem | Where | Consequence for a restore |
|---|---|---|
| `fnc_createZone` appends to `zone_namePOS_pairs`, `Array_of_OPFOR_zones` and `zone_spawn_array`, and increments `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-32` | Restoring those globals *and* replaying the builder counts every zone twice |
| `fnc_WARCOM_init` clears the BLUFOR zone list and hands every zone back to OPFOR | `server/warcom/fnc_WARCOM_init.sqf:38-45` | Ownership applied before it runs is wiped; every capture is lost |
| The setup-screen waits block on globals a *client* publishes | `server/server_init.sqf:46,52` | A restore has no player at those screens, so boot never gets past them |
| The locator `spawn`s `fnc_createZone` per zone, so builds finish out of order | `server/init_zones/fnc_locatorzones_random.sqf:181` | Registration order is not zone order, so anything keyed by array position is keyed to the wrong zone. `zone_meta_array` carries `_zone_num` for this reason |
| `fnc_fob_server` rolls a fresh name and announces the FOB over radio behind a 5 s sleep | `server/supports/fnc_fob_server.sqf:7,20-24` | Replaying it renames every FOB and queues one callout per FOB at boot |
| Zone names are localised at creation | `server/init_zones/fnc_locatorzones_random.sqf:181` | A stored name pins a restored campaign to the language it was created in |
| Campaign settings are set *and* broadcast by a client | `client/dialog/fnc_process_enviro_menu.sqf:118-122,172` | A restore that only assigns them server-side leaves every client on defaults |
| Arsenal contents are resolved at boot from whatever mods are loaded | `server/misc/fnc_create_ammo_lists.sqf` | Storing the resolved classnames pins the campaign to that mod set |
| Hardpoints are sited inside `fnc_createZone`, if [`hardpoint_system_plan.md`](hardpoint_system_plan.md) lands | — | Replaying zones re-rolls every hardpoint position and orphans its cleared state |

One thing that looks like a blocker and is not: `fnc_fob_server` takes a `_fob_owner` object
(`:5`) and hands it to `fnc_FOBactions.sqf:3`, which reads it and never uses it. Restore needs no
substitute for it. That dead parameter pre-dates this plan and is left alone here.

## Prerequisites

None of these is persistence work, and all of them must land first. Each is independently
worth doing.

1. **Make `fnc_fob_server` replayable.** It needs an optional name and a silent flag, for the
   naming and announcement reasons in the table above. The position registry it needs is already
   in place: `Array_of_FOBpos` (`server/supports/fnc_fob_server.sqf:84`).
2. **Mirror support unlocks server-side.** One broadcast array; the client keeps its local copy
   as the fast path. Players spend CP on these, so losing them across a restart is losing
   currency.

**Taking Locations out of `civ_locations` is not one of them.** The civilian rewrite has landed
and deliberately kept them: the entries are the map's own Locations, never deleted so that the
`nearestLocations` consumers keep seeing them (`server/misc/fnc_civ_init_Tomata.sqf:145-164`).
That still breaks the mission-namespace rule and is still worth fixing, but it does not block
this plan. The snapshot stores town positions, and restore re-resolves each one to a Location
through the same `nearestLocations` filter the selector uses
(`server/misc/fnc_civ_selectTowns.sqf:42-44`); the world guard pins the map, so the lookup
returns what it stored.

## Design

### Store

`missionProfileNamespace` with `saveMissionProfileNamespace`. It is server-side, per-mission,
and survives a restart. `profileNamespace` would work but pollutes the server profile shared by
every mission on the box. `saveGame` is not a candidate: it saves a whole session rather than a
data snapshot, so it cannot be replayed through the builders, which is what the restore below
depends on. That holds whether or not it works in multiplayer.

Only serialisable types go in: numbers, strings, booleans and arrays of those. No objects, no
groups, no triggers, no Locations, no netIds — netIds are strings but resolve to nothing after a
restart, which is worse than a type error because it fails silently.

### Snapshot

One key, `DUWST_save`, holding a single array with a version number first so a future format
change can be detected rather than misread.

Entries split into **inputs**, fed to the builders before they run, and **outcomes**, applied
after the builders have run and reset what they own. The split answers the first two rows of the
table above: anything the replay rebuilds must not also be restored, or it is double-counted.

| Group | Kind | Contents |
|---|---|---|
| Identity | — | format version, world name |
| Settings | input | `zones_number`, radii, spacing, `moreUrban`, `hardcore_mode_enable`, `enemyunitMultiplier`, `CIV_PRESENCE` |
| Placement | input | `PosOfBLUHQ`, `AO_direction`, `serv_zones_array`, `zone_meta_array` |
| Player build | input | `Array_of_FOBpos`, `Array_of_FOBname`, the support-unlock mirror |
| Civilians | input | town positions, names, radii and populations; `civ_town_rep` and `civ_town_ap` if [`per_town_reputation_plan.md`](per_town_reputation_plan.md) has landed |
| Escalation | outcome | the destroyed-building count, if [`per_town_reputation_plan.md`](per_town_reputation_plan.md) has landed. One integer; the census re-runs on the restored world |
| Hardpoints | input | `hardpoint_pos_array`, `hardpoint_type_array`, `hardpoint_zone_array`, `hardpoint_state_array` and the `zone_hp_left_<n>` counters, if [`hardpoint_system_plan.md`](hardpoint_system_plan.md) has landed |
| Pools | outcome | `commandpointsblu1`, `WARCOM_blufor_ap`, `WARCOM_opfor_ap`, `Player_Reputation` |
| Ownership | outcome | the positions of BLUFOR-held zones, and nothing else |
| Loadouts | — | `getUnitLoadout` per player UID. Already data — `client/client_init.sqf:408` stores it on the player object, which dies with the session |

Hardpoints are an input for the same reason zones are: that plan sites them inside
`fnc_createZone`, so the siting pass has to accept a restored registry instead of rolling fresh
positions, or a restore moves every hardpoint and orphans its cleared state.

`civ_town_ap` is stored rather than recomputed, against this plan's usual preference for
rebuilding derived state. It is a rank within the kept set's building counts, so recomputing it
needs the whole set to rank against and produces the right answer only while the ranking
function is unchanged — a tuning edit between the save and the load would silently repay every
town differently. It is one integer per town beside a number array the save already carries.

None of these three exists under `CIV_PRESENCE` of `RAVAGE` or `WBK`, where per-town reputation
and escalation do not run at all. `CIV_PRESENCE` is already an input in the Settings row, so a
restore knows which shape to expect and reads the group as absent rather than empty.

**Zone names are not stored.** `fnc_locatorzones_random.sqf:181` builds them as
`format [localize "STR_DUWS_T_39z6pg7y", _i]`, so storing the string pins a restored campaign to
the language it was created in. The index is already in `zone_meta_array`; the name re-localises
from it.

**The arsenal is not stored.** Faction init rebuilds the virtual cargo from scratch
(`server/misc/fnc_create_ammo_lists.sqf`), so all a restore loses is gear added during play by
`server/misc/fnc_addNearbyUnitsGearToArsenal.sqf`. Storing those classnames would pin the
campaign to the mod set that produced them, which is exactly what the faction trade-off below
refuses to do.

**The settings group has to be re-broadcast, not just assigned.** Those globals are normally set
*and* `publicVariable`'d by the setup screens on a client
(`client/dialog/fnc_process_enviro_menu.sqf:118-122,172`), and restore skips those screens.

Written by one function, on a timer and on the sitrep action. The server is the only writer.

### Restore

The restore path must not rebuild anything itself. It sets state, then lets the normal builders
run. There is exactly one code path that builds a zone, and it stays that way.

Three hooks, in boot order.

**An early gate in `server_init.sqf`, between `:9` and `:15`.** After `server_var_init` so the
snapshot overwrites the defaults, before the terrain survey so it can be skipped. It decides
whether a valid snapshot exists, publishes the settings and placement inputs, and raises a
`DUWST_restoring` flag the later hooks read. It has to sit this early because the setup-screen
waits at `:46,52` block on globals a *client* publishes, and on a restore no client is coming to
publish them.

**Zone replay, at `server/warcom/fnc_init_OPFOR_WARCOM.sqf:7-15`,** where the guard already is:

```sqf
if (!manually_chosen) then {
    if (!zones_created) then { [50,0.2] spawn fnc_locatorZones_random; };
} else { … };
```

Restore branches past it and spawns `fnc_createZone` once per saved zone with the saved metadata.
The locator never runs, so no new placement is rolled. Note that `zones_created` is set by
`fnc_createZone` itself (`:21-22`), not by the locator — but `serv_zones_array` *is* the locator's
(`fnc_locatorzones_random.sqf:203`), so the wait at `fnc_init_OPFOR_WARCOM.sqf:22` only clears
because the snapshot restored it.

**Ownership replay, after the `WARCOM_init_done` wait at `fnc_init_OPFOR_WARCOM.sqf:88`.**
`fnc_WARCOM_init.sqf:38-45` hands every zone back to OPFOR, so ownership can only be applied
after it has run. Apply it as `["BLU", _pos] call fnc_zone_control_set` per saved BLUFOR zone
rather than assigning the arrays directly: that writer moves both side lists and both counters
together and broadcasts them atomically (`server/server_fnc_init.sqf:81-120`), which is why the
snapshot stores held positions and nothing derived from them.

Civilians restore inside the same file at `:54`, where `fnc_civ_init_Tomata` is called: the saved
towns replace the `fnc_civ_selectTowns` roll — which is not deterministic, it shuffles its
top-up wave (`fnc_civ_selectTowns.sqf:110-115`) and rolls population (`fnc_civ_init_Tomata.sqf:75`)
— and the rest of that function runs unchanged.

| Boot step | On restore |
|---|---|
| `server/server_var_init.sqf` (`server_init.sqf:9`) | Runs, then the snapshot overwrites |
| `fnc_moreUrban_locations` (`:15`) | **Skipped** — a terrain scan that has been recorded taking 140 s, and placement is already decided |
| Setup screens, `chosen_hq_placement` / `createzone_server` waits (`:46,52`) | **Skipped** |
| Faction init (`:70,88`) | Runs — classnames must be re-resolved against whatever mods are loaded now |
| `fnc_bluHQinit` (`:108`) | Runs, from the saved `PosOfBLUHQ`. It rebuilds the whole HQ deterministically, which is why persisting one position is enough |
| `fnc_init_OPFOR_WARCOM` (`:129`) | Runs, with the locator bypassed as above |
| `fnc_intro_heli` (`:430`) | **Skipped** |

FOBs restore the same way: call `fnc_fob_server` per saved position — silently, and with the
saved name — rather than reimplementing what it builds.

### What is deliberately not saved

Live AI, spawned garrisons, active side missions, in-flight support, vehicle positions and
damage. Zone garrisons and composition props both spawn and despawn on player distance
(`server/init_zones/fnc_spawnWait.sqf`), so a restored campaign regenerates them the first time a
player approaches — the same code path a fresh campaign uses.

Composition streaming adds nothing here. Its stow records are built when a composition leaves the
map and dropped when it returns ([`composition_streaming_plan.md`](composition_streaming_plan.md)),
so they never outlive the session and a restore rebuilds every composition deployed.

This is the decision that keeps the plan finite. The server runs 40 `while {true}` loops across 23
files, each holding script locals; persisting live state would mean relaunching every one with
reconstructed arguments. Regenerating instead means they start the way they always do.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_campaign_save.sqf` | New. Builds the snapshot array and writes `missionProfileNamespace`. |
| `server/misc/fnc_campaign_restore.sqf` | New. Reads it, validates version and world, sets globals, replays builders. |
| `server/misc/fnc_autoSave.sqf` | Rewritten to call the new save; drop `saveGame`. |
| `server/supports/fnc_sitrep_support.sqf:8-11` | Remove the server-side dialog gate. |
| `server/server_init.sqf` | Early restore gate before `:15`, skipping the setup-screen waits at `:46,52`. Keep `enableSaving [false,false]` at `:113`; the engine save is no longer the mechanism. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:7-15,54,88` | Branch to the restore path for zones; feed saved towns to civilian init; replay ownership after `WARCOM_init_done`. |
| `server/supports/fnc_fob_server.sqf:7,20-24` | Accept a name and a silent flag. |
| `server/misc/fnc_civ_init_Tomata.sqf:163-164` | Accept a restored town set in place of the `fnc_civ_selectTowns` roll. |
| `client/client_init.sqf:408` | Loadout save keys on player UID, not the player object. |
| `server/server_fnc_init.sqf` | Registry lines; support-unlock mirror writer. |
| `info/architecture.md:122` | Replace the "vanilla `saveGame` only" line. |
| `KNOWN_ISSUES.md` | Drop the save/reload row once it passes. |

## Task list

- [ ] Prerequisites 1-2 above, each as its own change.
- [ ] Write `fnc_campaign_save.sqf` and dump a snapshot to the log without restoring. Verify: every value in it is a number, string, boolean or array of those.
- [ ] Write `fnc_campaign_restore.sqf` covering pools and ownership only. Verify: restart mid-campaign and confirm CP, AP and reputation return.
- [ ] Add zone replay through `fnc_createZone`, then the ownership pass after `WARCOM_init_done`. Verify: restored zones sit in the same places with the same radii, a captured zone comes back captured, and `amount_zones_created` matches the zone count instead of double it.
- [ ] Add HQ, FOB and civilian-town replay. Verify: HQ actions work, FOB triggers fire, FOB names and towns come back where they were, and the restore replays no FOB radio announcements.
- [ ] Add loadouts and support unlocks.
- [ ] Version and world guards: refuse a snapshot from a different map or format version and start fresh with a logged warning.
- [ ] On a dedicated server: play, restart, confirm the campaign continues. This cannot be validated by a hosted session — a host is both server and client and will mask locality faults.

## Decided trade-offs

**A restore is a fresh world with an old ledger.** Enemy garrisons, side missions and support in
flight are all lost. A player who restarts mid-firefight reappears with the zone unclaimed and
the garrison regenerated. Persisting the fight itself is a different and much larger project.

**Save on a timer, not on every change.** Writing the snapshot per CP change would put a
serialisation on the hot path of the most frequently written global in the mission. A periodic
write plus the existing sitrep action loses at most one interval of progress.

**The snapshot is versioned and map-locked.** Restoring a snapshot into a different world or an
incompatible format silently produces a broken campaign. Refusing it and starting fresh is worse
for the player in that moment and better every other time.

**Faction classnames are re-resolved, not restored.** A player who removes a faction mod between
sessions gets whatever auto-detection now picks, not a campaign full of missing classnames.
Storing resolved classnames would pin the campaign to a mod set, which is exactly what the
mission's no-hard-dependency rule exists to avoid.

**There is no virtual garage to persist.** The collaborator's notes list one as shipped; this
tree has vehicle texture and animation customisation
(`client/supports/fnc_client_addRepairActions.sqf:54-56`) and no garage. If a garage is wanted it
is a new feature, and it should be built with a data-shaped store so it persists for free.
