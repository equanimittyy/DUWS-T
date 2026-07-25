# Campaign persistence: implementation plan

Make a campaign survive a server restart. The mission saves a data-only snapshot to
`missionProfileNamespace` and, on the next start, rebuilds the world by feeding that snapshot
back through the **existing** builders rather than through a second construction path.

Live units are not persisted. Zones, the HQ and FOBs are rebuilt and re-garrisoned from scratch;
what carries over is campaign state — pools, zone ownership, placement, reputation, unlocks.

## Why the current save does not work

| Problem | Where |
|---|---|
| The only save is vanilla `saveGame`, which is single-player and a no-op in multiplayer | `server/misc/fnc_autoSave.sqf:11` |
| Its one call site charges 1 CP, then gates the save behind `BIS_fnc_guiMessage` inside `if (isServer)`. A dedicated server has no display, so the dialog never resolves: the player is charged and nothing is saved | `server/supports/fnc_sitrep_support.sqf:1,8-11` |
| Engine autosave and the save menu are switched off at boot | `server/server_init.sqf:113` |
| `civ_locations` stores Location objects in the mission namespace, which the mission's own rule forbids because the namespace is what a save serialises | `server/misc/fnc_civ_init_Tomata.sqf:28,141`, rule in [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) |
| Per-zone radius, CP worth and prefab type exist only as script locals, baked into compiled trigger strings. Nothing can rebuild a zone correctly from stored data | `server/init_zones/fnc_createzone.sqf:7-13,213,263` |
| `Array_of_FOBS` holds objects, not positions. `fnc_FOB_cleanup.sqf:22` already works around this by comparing `str (getPos _x)` | `server/supports/fnc_fob_server.sqf:78` |
| Support unlocks are client-local by design — *"Supports are local to players. No need for publicVariable"* — so there is no server-side copy of what the player paid for | `client/includes/supports_init.hpp` |

`KNOWN_ISSUES.md` already lists "Save and reload mid-campaign" as untested. It is not untested;
it cannot work.

## Prerequisites

None of these is persistence work, and all of them must land first. Each is independently
worth doing.

1. **Take Location objects out of the mission namespace.** Store town positions and names as
   arrays; consumers already only call `getPos` and `text`.
   [`civilian_town_generation_plan.md`](civilian_town_generation_plan.md) drops `createLocation`
   for other reasons and is the natural place to finish the job.
2. **Store per-zone metadata.** Add radius, points and prefab to a `zone_meta_array` parallel to
   `zone_namePOS_pairs` (`server/init_zones/fnc_createzone.sqf:28-29`). Without it a restored zone
   has the wrong trigger area and pays the wrong capture CP.
3. **Store FOB positions.** A `Array_of_FOBpos` beside `Array_of_FOBS`, written at
   `server/supports/fnc_fob_server.sqf:78`. This also removes the `str (getPos _x)` workaround.
4. **Mirror support unlocks server-side.** One broadcast array; the client keeps its local copy
   as the fast path. Players spend CP on these, so losing them across a restart is losing
   currency.
5. **Fix the sitrep save path.** `server/supports/fnc_sitrep_support.sqf:8` must not gate a
   server-side action on a server-side dialog.

## Design

### Store

`missionProfileNamespace` with `saveMissionProfileNamespace`. It is server-side, per-mission,
and survives a restart. `profileNamespace` would work but pollutes the server profile shared by
every mission on the box. `saveGame` is a dead end in multiplayer.

Only serialisable types go in: numbers, strings, booleans and arrays of those. No objects, no
groups, no triggers, no Locations, no netIds — netIds are strings but resolve to nothing after a
restart, which is worse than a type error because it fails silently.

### Snapshot

One key, `DUWST_save`, holding a single array with a version number first so a future format
change can be detected rather than misread.

| Group | Contents |
|---|---|
| Identity | format version, world name, campaign settings (`zones_number`, radii, spacing, `moreUrban`, `hardcore_mode_enable`, `enemyunitMultiplier`, `CIV_PRESENCE`) |
| Pools | `commandpointsblu1`, `WARCOM_blufor_ap`, `WARCOM_opfor_ap`, `Player_Reputation` |
| Placement | `PosOfBLUHQ`, `AO_direction`, `serv_zones_array`, `zone_namePOS_pairs`, the new `zone_meta_array` |
| Ownership | `WARCOM_zones_controled_by_BLUFOR`, `WARCOM_zones_controled_by_OPFOR`, `zoneundercontrolblu`, `amount_zones_created`, `amount_zones_captured` |
| Player build | `Array_of_FOBpos`, `Array_of_FOBname`, the support-unlock mirror |
| Civilians | town positions, names, radii and populations; `civ_town_rep` if [`per_town_reputation_plan.md`](per_town_reputation_plan.md) has landed |
| Loadouts | `getUnitLoadout` per player UID. Already data — `client/client_init.sqf:403` stores it on the player object, which dies with the session |
| Arsenal | virtual cargo classname arrays from `BIS_fnc_addVirtualItemCargo` / `WeaponCargo` |

Written by one function, on a timer and on the sitrep action. The server is the only writer.

### Restore

The restore path must not rebuild anything itself. It sets state, then lets the normal builders
run. There is exactly one code path that builds a zone, and it stays that way.

The insertion point already exists — `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-14` is guarded on
`if (!zones_created)`:

```sqf
if (!manually_chosen) then {
    if (!zones_created) then { [50,0.2] spawn fnc_locatorZones_random; };
} else { … };
```

Restore sets `zones_created = true` and calls `fnc_createZone` once per saved zone with the saved
metadata. The locator never runs, so no new placement is rolled.

| Boot step | On restore |
|---|---|
| `server/server_var_init.sqf` (`server_init.sqf:9`) | Runs, then the snapshot overwrites |
| `fnc_moreUrban_locations` (`:15`) | **Skipped** — a terrain scan that has been recorded taking 140 s, and placement is already decided |
| Setup screens, `chosen_hq_placement` / `createzone_server` waits (`:46,52`) | **Skipped** |
| Faction init (`:70,88`) | Runs — classnames must be re-resolved against whatever mods are loaded now |
| `fnc_bluHQinit` (`:108`) | Runs, from the saved `PosOfBLUHQ`. It rebuilds the whole HQ deterministically, which is why persisting one position is enough |
| `fnc_init_OPFOR_WARCOM` (`:129`) | Runs, with the locator bypassed as above |
| `fnc_intro_heli` (`:507`) | **Skipped** |

FOBs restore the same way: call `fnc_fob_server` per saved position rather than reimplementing
what it builds.

### What is deliberately not saved

Live AI, spawned garrisons, active side missions, in-flight support, vehicle positions and
damage. Zone garrisons already spawn and despawn on player distance
(`server/init_zones/fnc_spawnWait.sqf`), so a restored campaign regenerates them the first time a
player approaches — the same code path a fresh campaign uses.

This is the decision that keeps the plan finite. The server runs 39 `while {true}` loops across 23
files, each holding script locals; persisting live state would mean relaunching every one with
reconstructed arguments. Regenerating instead means they start the way they always do.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_campaign_save.sqf` | New. Builds the snapshot array and writes `missionProfileNamespace`. |
| `server/misc/fnc_campaign_restore.sqf` | New. Reads it, validates version and world, sets globals, replays builders. |
| `server/misc/fnc_autoSave.sqf` | Rewritten to call the new save; drop `saveGame`. |
| `server/supports/fnc_sitrep_support.sqf:8-11` | Remove the server-side dialog gate. |
| `server/server_init.sqf:113` | Keep `enableSaving [false,false]`; the engine save is no longer the mechanism. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-14` | Branch to the restore path when a snapshot exists. |
| `server/init_zones/fnc_createzone.sqf:28-29` | Write `zone_meta_array`. |
| `server/supports/fnc_fob_server.sqf:78` | Write `Array_of_FOBpos`. |
| `client/client_init.sqf:403` | Loadout save keys on player UID, not the player object. |
| `server/server_fnc_init.sqf` | Registry lines; support-unlock mirror writer. |
| `info/architecture.md:122` | Replace the "vanilla `saveGame` only" line. |
| `KNOWN_ISSUES.md` | Drop the save/reload row once it passes. |

## Task list

- [ ] Prerequisites 1-5 above, each as its own change.
- [ ] Write `fnc_campaign_save.sqf` and dump a snapshot to the log without restoring. Verify: every value in it is a number, string, boolean or array of those.
- [ ] Write `fnc_campaign_restore.sqf` covering pools and ownership only. Verify: restart mid-campaign and confirm CP, AP and reputation return.
- [ ] Add zone replay through `fnc_createZone`. Verify: restored zones sit in the same places with the same radii, and a captured zone comes back captured.
- [ ] Add HQ and FOB replay. Verify: HQ actions work and FOB triggers fire after a restore.
- [ ] Add loadouts, arsenal and support unlocks.
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
