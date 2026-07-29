# Campaign persistence: implementation plan

Make a campaign survive the session it was played in. The mission writes a data-only snapshot to
an external store and, on the next start, rebuilds the world by feeding that snapshot back through
the **existing** builders rather than through a second construction path.

Live units are not persisted. Zones, the HQ and FOBs are rebuilt and re-garrisoned from scratch;
what carries over is campaign state — pools, zone ownership, placement, reputation, unlocks, and
the vehicles the player parked at a base.

One rule governs everything below, including the features that are not built yet: **a thing is
persistable when a single function can build it from numbers and strings.** Zones already satisfy
it (`zone_meta_array` is exactly the argument list of `fnc_createZone`); FOBs nearly do; player
fortifications and OPFOR taskings will only if they are designed that way from the start
([§Features not built yet](#features-not-built-yet)).

## Where the save lives

Vanilla SQF cannot write an arbitrary file. The only durable write targets in the game are the
profile-backed namespaces and the clipboard, and that constraint — not a preference — decides the
design.

**Store: `missionProfileNamespace`, flushed with `saveMissionProfileNamespace`.** It is
per-mission, server-side, survives a restart, and lands in a file outside the PBO. Add
`missionGroup = "DUWS_T";` to `description.ext`: without it the file is named after the mission
folder, so `DUWS_T.Altis` and a port to another map would each get their own and a Workshop
version bump could rename it. With it there is one `DUWS_T.vars.Arma3Profile`, in the profile
directory of whichever machine is the server — the host's profile for a hosted session, the
`-profiles` directory for a dedicated one.

`profileNamespace` would also work and is rejected: it is the profile shared by every mission on
the box, so DUWS_T's campaign state would sit beside every other mission's and a player clearing
one would risk the other.

`saveGame` is not a candidate at all. It saves a whole session rather than a data snapshot, so it
cannot be replayed through the builders, which is what the restore below depends on. That holds
whether or not it works in multiplayer, which is
[still unestablished](../KNOWN_ISSUES.md#does-a-multiplayer-save-happen-at-all).

**One key per world: `DUWST_save_<worldName>`.** A player who runs a campaign on two maps keeps
both, and the world guard becomes a key lookup instead of a rejection. A second key,
`DUWST_save_<worldName>_prev`, holds the previous snapshot: writes are not atomic, and a restart
during one costs a campaign rather than an interval if there is nothing to fall back to. The
payload is small enough that doubling it is not a consideration — the profile file only becomes a
performance problem in the tens of megabytes, and this snapshot is tens of kilobytes.

### Transferring a save between machines

Two routes, and the second is the one that actually works for a player:

| Route | Mechanism | Limits |
|---|---|---|
| Copy the file | `DUWS_T.vars.Arma3Profile` out of the profile directory | Different directory on a client and a dedicated server; the player has to find it |
| Export a string | `copyToClipboard` on export, a paste-in edit box on import | Needs a dialog; edit-control length under a large snapshot is untested |

The export path costs one dialog and works because of a property the snapshot already has for a
different reason: it contains only numbers, strings, booleans and arrays of those, which is
exactly the type set `parseSimpleArray` accepts. `str` on the way out and `parseSimpleArray` on
the way back is an exact round trip, so no serialiser has to be written or kept in step.

`copyToClipboard` writes the clipboard of the machine it runs on, so on a dedicated server the
export has to be `remoteExec`'d back to the requesting client or it lands on the server box where
nobody can reach it.

**Extension-based stores are refused as the mechanism.** FileXT, extDB and iniDBI can write real
files and are what large persistent missions usually end up on, and every one of them is a mod.
The mission's no-hard-dependency rule makes them unavailable as *the* store. Nothing stops a later
optional path writing the same snapshot through an extension when one is present, because the
snapshot is a value rather than a format — but the vanilla path has to be complete on its own
first, and this plan is that path.

## When the save is written, and what happens with nobody on

The writer is the server and there is only one. Four triggers:

| Trigger | Why |
|---|---|
| Periodic timer | The only protection against a crash or an ALT-F4, neither of which fires any hook |
| SITREP action | The existing manual save, kept |
| Last player disconnecting | On a default dedicated server this is the last moment the mission exists |
| `Ended` / `MPEnded` mission event handlers | Covers a clean mission end or admin `#missions` |

Every write is gated on `mission_init_complete` (`server/server_var_init.sqf`). A snapshot taken
during zone build-out describes half a campaign, and restoring it would produce a map with some
zones and no others.

### The autosave loop

One server-side thread, replacing what `fnc_autoSave.sqf` does today.

**The interval is a mission parameter, `DUWS_AutosaveInterval`, defaulting to 15 minutes.** It is
the maximum progress a crash can cost, which makes it the one number in this design whose right
value depends on the session rather than on the mission — a public dedicated server and a
two-player campaign want different answers. Parameters are the mission's existing mechanism for
exactly that: seconds as values with human labels as texts, on the model of `DUWS_CleanupLifetime`
(`shared/includes/params_modern.hpp`), read through `BIS_fnc_getParamValue`. A dedicated server
sets it in `server.cfg` without touching the PBO, which is the whole point.

**Off means manual saves only, not no saves.** The other three triggers are not part of this loop,
so a campaign with the interval at zero still writes on the last disconnect and on a clean mission
end, and the player can still save on demand: SITREP is a comm-menu item granted at boot rather
than an unlock, and `client/client_init.sqf:453` grants it to the singleplayer player as well as
the game master. What Off actually costs is the crash case — an ALT-F4 or a hang loses the whole
session instead of one interval.

One limit of the manual path is temporary. SITREP costs 1 CP today, so a player spent down to
nothing cannot save at all — and that price is being removed, with a cooldown in its place
([`ap_economy_plan.md`](ap_economy_plan.md#sitrep-becomes-free)). Off is a second reason for that
change to land rather than a reason to withhold the option, because it promotes the manual save
from a convenience to the only in-session one. The grant itself follows the `game_master` slot
rather than the person (`server/server_var_init.sqf`), so a co-op team whose game master leaves
recovers it by someone taking that slot.

- **It always writes.** Tracking whether anything changed since the last pass would mean a dirty
  flag on every writer in the mission, and the thing it would save is one disk write per interval.
- **It does not overlap itself.** A pass that starts while one is in flight skips rather than
  queues; a queue of stale snapshots is worse than a missed interval, because the last one to land
  wins and it is the oldest.
- **It rotates `_prev` on every write**, so the fallback is always exactly one interval behind.
- **It logs what it wrote** — zone count, vehicle count, byte length — through `fnc_log`. A save
  path with no trace in the `.rpt` is one nobody can diagnose after the fact, and this one runs
  unattended on servers its author will never see.

The other three triggers call the same function. There is one writer and one code path; the timer
is not special.

**Hosted session and singleplayer.** The host — or the single player — is the server, so the save
lands in their own profile and dies with their process. There is no reliable hook for someone
closing the game, so the periodic timer is the only thing standing between an ALT-F4 and losing the
interval. Neither ever reaches zero players, so the idle gate below never fires for them.

Singleplayer is the case where this changes the most, because **there is no save there today**:
`enableSaving [false, false]` (`server/server_init.sqf:113`) removes the engine autosave *and* the
pause menu's Save & Exit, so quitting a singleplayer campaign currently loses it outright. That
line stays — an engine save and a snapshot are two sources of truth that would drift apart — which
means the snapshot has to carry the whole job, and a player pressing Escape expecting to save needs
somewhere obvious to be sent instead.

**Dedicated server, `persistent = 0` (the default).** The mission ends when the last player
disconnects and everything in memory goes with it. Saving on the last disconnect is not an
optimisation here; without it a dedicated server loses the campaign every time the server empties.

**Dedicated server, `persistent = 1`.** The mission keeps running with nobody connected. That is
the configuration this mission wants for a persistent campaign, and it raises a design question
the mission has never had to answer: the 30-minute economy tick keeps paying, WARCOM keeps
spawning waves, the side-mission generator keeps rolling and expiring missions, and — once the
[OPFOR director](ap_economy_plan.md#what-the-opfor-director-spends-on) lands — the enemy keeps
buying garrisons and hardpoints against a player who is asleep.

**Decided: the campaign idles at zero players.** A player who logs off overnight and returns to a
poorer wallet and a fully upgraded enemy has lost ground by not playing, which is not a mechanic
anyone chose; and the server burns CPU simulating a war nobody is watching. The gate goes on the
campaign clocks — the economy tick, the WARCOM wave threads, the side-mission generator, the
hardpoint and director build ticks — not on everything. The zone spawn/despawn checker and the JIP
machinery keep running; with no players they are already no-ops, and gating them would only add a
branch.

**The gate must count humans, not `allPlayers`.** That command includes headless clients, so on a
server running the [headless client](headless_client_plan.md) an HC alone would hold the campaign
open forever with nobody playing — and, worse, the transition-to-zero save would never fire, which
is the checkpoint the whole dedicated story rests on. Subtract `entities "HeadlessClient_F"`.

The gate belongs on the loops rather than on a global pause flag, because a flag has to be read
correctly by every future loop and a missed read is silent.

**Time-based state must be stored as a remaining duration, never as an absolute stamp.**
`diag_tickTime` counts from process start, so any stamp saved in one session sits in the future in
the next and wedges whatever it gates for as long as the old session ran. The mission already
carries a monitor that clears future stamps off player objects (`server/server_init.sqf:434-467`);
that stays as the backstop, and nothing new should need it.

## What the current save does not cover

| Problem | Where |
|---|---|
| The only save is vanilla `saveGame`, reached from one place: the SITREP support | `server/misc/fnc_autoSave.sqf:11`, sole caller `server/supports/fnc_sitrep_support.sqf` |
| Engine autosave and the save menu are switched off at boot | `server/server_init.sqf:113` |
| `civ_locations` stores Location objects in the mission namespace, which the mission's own rule forbids because the namespace is what a save serialises | `server/misc/fnc_civ_init_Tomata.sqf:170`, rule in [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) |
| Support unlocks are client-local by design — *"Supports are local to players. No need for publicVariable"* — so there is no server-side copy of what the player paid for | `client/includes/supports_init.hpp` |
| The MHQ is a broadcast object handle (`MHQ1 = _this; publicVariable "MHQ1"`) with no record of which vehicle it was | `client/dialog/fnc_MHQ_select.sqf:20-22` |

Rows three to five are why an engine save cannot be the mechanism even in the case where it works.
A server-side save has no access to unlocks the client paid for and never broadcast; a namespace
holding Location handles is a serialisation hazard *because* something is trying to serialise it;
and an object handle restores as `objNull` in a new session, which fails silently rather than
loudly. A working `saveGame` would make all three worse, not better.

## What a naive restore gets wrong

Writing the snapshot is the easy half. These are properties of the existing builders that punish a
restore which simply assigns the saved globals and lets boot proceed. Each is current behaviour,
correct for a fresh campaign, and each is resolved in the design below.

| Problem | Where | Consequence for a restore |
|---|---|---|
| `fnc_createZone` appends to `zone_namePOS_pairs`, `Array_of_OPFOR_zones` and `zone_spawn_array`, and increments `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-34` | Restoring those globals *and* replaying the builder counts every zone twice |
| `fnc_WARCOM_init` clears the BLUFOR zone list and hands every zone back to OPFOR | `server/warcom/fnc_WARCOM_init.sqf:38-46` | Ownership applied before it runs is wiped; every capture is lost |
| The setup-screen gates block on globals a *client* publishes | `server/server_init.sqf:46,52` | A restore has no player at those screens, so boot never gets past them |
| The locator `spawn`s `fnc_createZone` per zone, so builds finish out of order | `server/init_zones/fnc_locatorzones_random.sqf:181` | Registration order is not zone order, so anything keyed by array position is keyed to the wrong zone. `zone_meta_array` carries `_zone_num` for this reason |
| `fnc_fob_server` rolls a fresh name and announces the FOB over radio behind a 5 s sleep | `server/supports/fnc_fob_server.sqf:7,20-24` | Replaying it renames every FOB and queues one callout per FOB at boot |
| Zone names are localised at creation | `server/init_zones/fnc_locatorzones_random.sqf:181` | A stored name pins a restored campaign to the language it was created in |
| Campaign settings are set *and* broadcast by a client | `client/dialog/fnc_process_campaign_menu.sqf:480-515`, `fnc_process_enviro_menu.sqf:88-194` | A restore that only assigns them server-side leaves every client on defaults |
| Arsenal contents are resolved at boot from whatever mods are loaded | `server/misc/fnc_create_ammo_lists.sqf` | Storing the resolved classnames pins the campaign to that mod set |
| Hardpoints are sited inside `fnc_createZone`, if [`hardpoint_system_plan.md`](hardpoint_system_plan.md) lands | — | Replaying zones re-rolls every hardpoint position and orphans its cleared state |

One thing that looks like a blocker and is not: `fnc_fob_server` takes a `_fob_owner` object
(`:5`) and hands it to `fnc_FOBactions.sqf:3`, which reads it and never uses it. Restore needs no
substitute for it. That dead parameter pre-dates this plan and is left alone here.

## Prerequisites

None of these is persistence work, and all of them must land first. Each is independently worth
doing.

1. **Prove the store on a dedicated server.** Dedicated servers have historically written
   profile-namespace variables to disk correctly and failed to read them back on the next start.
   That is reported fixed, and the entire plan rests on it. Write one key, restart, read it: this
   is a ten-minute check and every other task assumes its answer.
2. **Make `fnc_fob_server` replayable.** It needs an optional name, for the naming reason in the
   table above. Silencing its announcement belongs on `fnc_duws_dialogue`, not here: a restore
   replays several builders, and a per-function flag has to be re-invented at every one of them.
   The position registry it needs is already in place: `Array_of_FOBpos`
   (`server/supports/fnc_fob_server.sqf:84`).
3. **Mirror support unlocks server-side.** One broadcast array; the client keeps its local copy as
   the fast path. Players spend CP on these, and once
   [AP buys permanent capability](ap_economy_plan.md#what-ap-buys-is-permanent-cp-buys-uses)
   losing them across a restart is losing the campaign's premium currency.

**Taking Locations out of `civ_locations` is not one of them.** The civilian rewrite deliberately
kept them: the entries are the map's own Locations, never deleted so that the `nearestLocations`
consumers keep seeing them (`server/misc/fnc_civ_init_Tomata.sqf:145-170`). That still breaks the
mission-namespace rule and is still worth fixing, but it does not block this plan. The snapshot
stores town positions, and restore re-resolves each one to a Location through the same
`nearestLocations` filter the selector uses (`server/misc/fnc_civ_selectTowns.sqf:42`); the world
guard pins the map, so the lookup returns what it stored.

## The snapshot

One array per key, with a format version first so a future change can be detected rather than
misread. Only serialisable types go in: numbers, strings, booleans and arrays of those. No
objects, no groups, no triggers, no Locations, no netIds — netIds are strings but resolve to
nothing after a restart, which is worse than a type error because it fails silently.

Entries split into **inputs**, fed to the builders before they run, and **outcomes**, applied
after the builders have run and reset what they own. The split answers the first two rows of the
table above: anything the replay rebuilds must not also be restored, or it is double-counted.

### Identity and settings

| Group | Kind | Contents |
|---|---|---|
| Identity | — | format version, `worldName`, campaign start time |
| Server config | input | every global the setup screens broadcast |
| Callsign | input | `duws_callsign` |

**The server-config group is defined by a name list, not by enumeration in prose.** The setup
screens publish roughly thirty globals across `client/dialog/fnc_process_campaign_menu.sqf:480-515`
and `fnc_process_enviro_menu.sqf:88-194` — zone counts and radii, `moreUrban`, AI skill bands,
`AttackHeli`, `HeavyArmor`, `enemyunitMultiplier`, `cp_reward_multiplier`,
`DUWSMP_CP_death_cost`, `weather_type`, `time_of_day`, `time_Multiplier`, `CIV_PRESENCE`,
`hardcore_mode_enable`, `escalation_enabled`, `insurgent_mode_enable`, `apocalypse_mode`,
`simple_zones_enable`, `restricted_arsenal`, `enable_fast_travel`, `ZeusStatus`. A single array of
those names, held in one place, is what both the save and the re-broadcast iterate. Listing them
individually in two functions guarantees that the next setting added is saved in one and not the
other.

**The settings group has to be re-broadcast, not just assigned.** Those globals are normally set
*and* `publicVariable`'d by a client, and restore skips those screens entirely.

`game_master` and `Squad_Leaders` are deliberately **not** in the group. They are a server's
permission policy (`server/server_var_init.sqf`), and an admin who trims them between sessions
must not have a snapshot put the old list back.

### World and placement

| Group | Kind | Contents |
|---|---|---|
| Placement | input | `PosOfBLUHQ`, `AO_direction`, `serv_zones_array`, `zone_meta_array` |
| Player build | input | `Array_of_FOBpos`, `Array_of_FOBname` |
| Civilians | input | town positions, names, radii and populations |

**Zone names are not stored.** `fnc_locatorzones_random.sqf:181` builds them as
`format [localize "STR_DUWS_T_39z6pg7y", _i]`, so storing the string pins a restored campaign to
the language it was created in. The index is already in `zone_meta_array`; the name re-localises
from it.

Towns go in by position even though the runtime keys them by index into `civ_locations`, because
that index is not stable across a restore: selection's top-up wave shuffles before it draws
(`server/misc/fnc_civ_selectTowns.sqf:125`) and the registration cull drops towns depending on
which radii survive. A Location's position comes out of the map's config and does not move.

### Territory, economy and escalation

| Group | Kind | Contents |
|---|---|---|
| Pools | outcome | `commandpointsblu1`, `WARCOM_blufor_ap`, `WARCOM_opfor_ap`, `Player_Reputation` |
| Ownership | outcome | the positions of BLUFOR-held zones, and nothing else |
| Zone bounty | outcome | the current bounty per zone, keyed by zone number |
| Town reputation | outcome | `civ_town_rep` and `civ_town_ap` |
| Escalation | outcome | `escalation_destroyed`. One integer; the census re-runs on the restored world |
| Tier ratchet | outcome | the AP tier reached by each side |
| Kill income | outcome | the per-player kill tally awaiting conversion, keyed by UID |

**Ownership is stored as held positions and nothing derived from them.** Restore applies each as
`["BLU", _pos] call fnc_zone_control_set`; that writer moves both side lists and both counters
together and broadcasts them atomically (`server/server_fnc_init.sqf:81-120`), so
`zoneundercontrolblu` and `amount_zones_captured` come out consistent instead of being separately
restored and separately wrong.

**The zone bounty is not derivable.** A zone's *worth* is fixed at generation and comes back with
`zone_meta_array`, but its CP bounty decays on every capture by design
([`info/cp_economy.md`](info/cp_economy.md)). Not storing it refunds the player a full-price zone
for every one they have already farmed.

**The tier ratchet is state, not a threshold test.** Once AP is spendable, deriving the tier from
the live pool re-derives it from a number that has since been spent down, silently un-unlocking an
enemy that had already reached armour — the failure mode
[`ap_economy_plan.md`](ap_economy_plan.md#the-ratchet-is-structural-today-and-only-in-half-the-read-sites)
describes. A ratchet whose only record is a number that goes both ways is not a ratchet.

`civ_town_ap` is stored rather than recomputed, against this plan's usual preference for rebuilding
derived state. It is a rank within the kept set's building counts, so recomputing it needs the
whole set to rank against and produces the right answer only while the ranking function is
unchanged — a tuning edit between the save and the load would silently repay every town
differently. It is one integer per town beside a number array the save already carries.

None of the town rows exists under `CIV_PRESENCE` of `RAVAGE`, `WBK` or `NONE`, where per-town
reputation does not run at all. `CIV_PRESENCE` is in the server-config group, so a restore knows
which shape to expect and reads the group as absent rather than empty.

**Escalation restores the ledger, not the rubble.** Destroyed buildings come back intact on a new
session because terrain objects reset, so the map looks repaired while prices stay raised. That is
the correct half to keep: the census counts the same total on the same world
(`server/misc/fnc_escalation.sqf:55-70`), so one stored integer reproduces the level, the
multiplier and the loss condition together.

### The enemy

| Group | Kind | Contents |
|---|---|---|
| Commander | input | the archetype rolled at WARCOM init |
| Town garrisons | outcome | purchased tier per town |
| Hardpoints | input | `hardpoint_pos_array`, `hardpoint_type_array`, `hardpoint_zone_array`, `hardpoint_state_array`, the `zone_hp_left_<n>` counters |
| Taskings | outcome | one row per standing order: type, target, and budget already spent |

The commander archetype is rolled once per campaign and never re-rolled
([`ap_economy_plan.md`](ap_economy_plan.md#the-commander-has-an-archetype)), so a restore that
re-rolls it changes the war the player has been fighting. One string.

Hardpoints are an input for the same reason zones are:
[`hardpoint_system_plan.md`](hardpoint_system_plan.md) sites them inside `fnc_createZone`, so the
siting pass has to accept a restored registry instead of rolling fresh positions, or a restore
moves every hardpoint and orphans its cleared state. The campaign-start batch of normal hardpoints
is a second siting pass outside `fnc_createZone` and needs the same guard for the same reason.
Cores and garrison groups are objects and stay out — they live in server-local
`hardpoint_core_<i>` keys and are rebuilt from the registry.

**Taskings persist as orders, not as squads.** A tasking is bought for a squad the director was
spawning anyway, so the purchase buys intent; the squad is live state and is regenerated like every
other. Restoring the order lets the director re-issue it to the next squad it spawns, which is what
the player experiences as continuity. Storing anything about the squad itself would be storing a
group handle.

### The players

| Group | Kind | Contents |
|---|---|---|
| Loadouts | — | `getUnitLoadout` per player UID |
| Support unlocks | input | the server-side mirror, per UID |
| Reveal | outcome | positions of revealed zones and revealed towns, indices of revealed normal hardpoints |
| Cooldowns | outcome | remaining seconds per player-scoped cooldown, per UID |

Loadouts are already data; what they lack is a stable key. `client/client_init.sqf:449` stores the
loadout on the player object, which dies with the session, so the mirror keys on UID.

**Reveal is an outcome, not an input.** A hardcore campaign's entire progress is which zones and
towns the player has found, and a replay re-hides both: `fnc_createzone.sqf:16` sets every zone's
visibility from `hardcore_mode_enable`, and `fnc_civ_init_Tomata` hides every town outside the HQ
anchor's opening quota. Store the positions of both, then re-flag the matching `zone_namePOS_pairs`
and `civ_visible` entries and repaint their markers after build-out — the same shape and the same
reason as Ownership.

Storing the state rather than how it was reached is what keeps this to a flat list of positions: a
zone the player walked into, bought from a local, or found on a dead officer all restore
identically, because by then they are one flag. `hardcore_visibleZone_found` is derived from reveal
plus OPFOR ownership and is recomputed rather than stored. Whether a hardpoint has been revealed is
separate state on the same footing, because intel can uncover one without its parent zone. Details
in [`info/intel_system.md`](info/intel_system.md#persistence).

**Reveal is team state today and stays that way.** `zone_namePOS_pairs` and `civ_visible` are
shared arrays and the markers they drive are global, so there is no per-player reveal to persist.
Making reveal personal is a design change to the intel system, not a persistence feature, and it
would mean per-player markers everywhere.

### The arsenal is not stored

Faction init rebuilds the virtual cargo from scratch (`server/misc/fnc_create_ammo_lists.sqf`), so
all a restore loses is gear added during play by
`server/misc/fnc_addNearbyUnitsGearToArsenal.sqf`. Storing those classnames would pin the campaign
to the mod set that produced them, which is exactly what the mission's no-hard-dependency rule
exists to avoid.

## The vehicle persistence zone

Every base anchor keeps the vehicles parked around it. This is the one part of the plan that
persists *objects* rather than campaign bookkeeping, and it is worth the exception because
stockpiling vehicles is a thing players do across sessions and nothing else in the design covers
it.

**Anchors and radius.** `PosOfBLUHQ`, every entry of `Array_of_FOBpos`, and the MHQ's position
when it is deployed. One radius constant, 100 m, in `server/server_var_init.sqf`. Anchors are
restored before vehicles are — the HQ and FOB builders are deterministic, so the composition a
vehicle was parked beside is back in the same place before the vehicle returns to it.

**What is collected.** Alive vehicles inside an anchor radius that are not `Man`, not
`StaticWeapon`, and not tracked in `DUWS_compositions`. The last two exclusions are the ones that
matter: FOB defence turrets are statics the FOB builder puts back itself, and anything composition-
tracked is rebuilt with its composition. Without them a restore doubles every FOB's gun ring.

| Field | Read with | Note |
|---|---|---|
| Type | `typeOf` | |
| Position | `getPosATL` | |
| Orientation | `vectorDir`, `vectorUp` | Two number triples; `getDir` alone loses a vehicle parked on a slope |
| Damage | `damage`, `getAllHitPointsDamage` | Both: hit points restore component damage, the scalar restores the whole |
| Fuel | `fuel` | |
| Ammo | `vehicleAmmo` | One fraction, restored with `setVehicleAmmo` |
| Cargo | `BIS_fnc_saveInventory` | Verify its output is pure data; the fallback is the four explicit cargo getters |
| Textures | `getObjectTextures` | The customisation the repair action already applies |
| Animations | `animationPhase` per source | Same feature, `client/supports/fnc_client_addRepairActions.sqf:77` |
| Pylons | `getPylonMagazines` | Aircraft only; restored with `setPylonLoadout`, already used at `server/server_fnc_init.sqf:1606` |
| Locked | `locked` | |
| MHQ flag | — | Marks which stored vehicle was `MHQ1` |

Per-turret magazine detail is deliberately dropped in favour of a single ammo fraction. It is a
stockpile, not a save state of a firefight, and the alternative is a nested structure that has to
survive a mod set changing under it.

**Crews are never stored.** Vehicles restore empty. An AI crewman is a live unit and lives under
the same rule as every other.

**The count is capped, and what is dropped is logged.** A per-anchor cap — 15 as the opening
number, a constant beside the radius — keeps the snapshot bounded and boot-time spawning finite.
Silently truncating would read to a player as vehicles randomly disappearing, so the cull logs
what it dropped and why, and drops the furthest from the anchor first.

**The MHQ is a stockpiled vehicle plus one flag.** `MHQ1` is whatever vehicle a player designated
through the comm menu (`client/dialog/fnc_MHQ_select.sqf:20-22`), so it needs no separate storage
path: it is a vehicle in the stockpile carrying a marker, plus its deployed state. On restore, the
designation is re-applied and — if it was deployed — `fnc_MHQ_deploy` is replayed, which rebuilds
the tent, the ammo box and the respawn point rather than persisting any of them.

**What is lost.** The restored vehicle is a new object, so anything attached to the old one goes:
R3F-carried cargo, player-placed objects riding on it, and any per-object variable a subsystem set
without a registry behind it. That is the price of not persisting object identity, and it is the
same price zones and FOBs pay.

## Features not built yet

Three planned features are cheap to persist if they are built as registries and expensive if they
are not. The contract is the same for all three: **the builder takes data and the registry holds
that data.** Persistence is then a replay, and there is nothing extra to write.

**Player-built fortifications and BLUFOR hardpoints.** Build them through one function taking
`[type, position, direction]` and keep a parallel registry of exactly those tuples, on the model of
the hardpoint arrays. Built the other way — the player places an object and persistence serialises
the object — restore has to reverse-engineer what was built from what is standing, and every new
buildable is a new special case.

**Virtualised OPFOR units.** Whatever a virtualisation layer holds must be classnames, positions,
sides and group names. A layer that caches group or unit handles is not persistable at all, and
that will not be visible until a restore produces an empty map.

**Anything with a cooldown or a timer.** Store the remaining duration. See the `diag_tickTime`
rule above.

## Restore

The restore path must not rebuild anything itself. It sets state, then lets the normal builders
run. There is exactly one code path that builds a zone, and it stays that way.

**Resume is the default, and the prompt is a confirmation rather than a fork.** A dedicated server
restarting unattended has nobody to ask; a hosted session has the host sitting at the setup screens
and asking them costs nothing. One mechanism covers both, and it branches on whether an answer
arrives rather than on what kind of server this is:

- The early gate loads the snapshot, raises `DUWST_restoring`, and publishes a one-line summary of
  what is in it — day, zones held, CP — so a client can describe the campaign it is about to
  resume rather than offering an unlabelled choice.
- The game master's setup entry (`client/client_init.sqf:95-113`) shows the screen when that flag
  is up, in front of `fnc_startup_faction_flow`. Resume skips the setup flow entirely; New campaign
  clears the key, drops the flag, and calls `fnc_startup_faction_flow` exactly as today.
- Everyone else waits where they already wait. Non-game-master clients block on
  `HQ_pos_found_generated && chosen_settings` (`client/client_init.sqf:139-143`) and need no
  knowledge of the screen at all — a resume satisfies both flags the same way a finished setup
  does.

**The screen is one more dialog in the chain, not a new mechanism.** `shared/includes/` holds one
`.hpp` per screen, each `idd = -1`, each closing through an `onUnload` that spawns the next step —
which is exactly how `fnc_startup_faction_flow` chains HQ placement into the faction prompts into
the environment menu. A load screen is a two-button member of that chain placed one link earlier,
and building it any other way means inventing a second setup idiom for one screen.
- The gate waits for the answer on the same `fnc_waitLogged` pattern as every other setup gate, and
  the timeout resumes. The bound is short while no player is connected and extends to the
  setup-screen bound once one is, so an unattended restart is not delayed by a screen nobody can
  see and a host is not raced past by a timer.

Two properties make the timeout safe rather than merely convenient. Resuming without asking is
recoverable — the player starts a new campaign one screen later — where starting fresh without
asking destroys the save. And nothing is written until `mission_init_complete`, so a resume the
player did not want does not overwrite what it restored from.

**New campaign wipes a save, so it confirms.** It is the only destructive control in the flow, and
it is one click away from the button most players will press every session.

Three hooks, in boot order.

**An early gate in `server_init.sqf`, between `:9` and `:15`.** After `server_var_init` so the
snapshot overwrites the defaults, before the terrain survey so it can be skipped. It decides
whether a valid snapshot exists, publishes the settings and placement inputs, and raises a
`DUWST_restoring` flag the later hooks read. It has to sit this early because the setup gates at
`:46,52` block on globals a *client* publishes. Note that those are now `fnc_waitLogged` loops
rather than bare `waitUntil`s, which makes the restore simpler than it was: setting
`chosen_hq_placement` and `createzone_server` true in the gate satisfies them immediately, so
nothing has to branch around them.

**Zone replay, at `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-16`,** where the guard already is:

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

**Ownership and reveal replay, after the `WARCOM_init_done` wait at
`fnc_init_OPFOR_WARCOM.sqf:97`.** `fnc_WARCOM_init.sqf:38-46` hands every zone back to OPFOR, so
ownership can only be applied after it has run.

Civilians restore inside the same file at `:54`, where `fnc_civ_init_Tomata` is called: the saved
towns replace the `fnc_civ_selectTowns` roll — which is not deterministic — and the rest of that
function runs unchanged.

| Boot step | On restore |
|---|---|
| `server/server_var_init.sqf` (`server_init.sqf:9`) | Runs, then the snapshot overwrites |
| `fnc_moreUrban_locations` (`:15`) | **Skipped** — a terrain scan recorded taking 140 s, and placement is already decided |
| Setup gates, `chosen_hq_placement` / `createzone_server` (`:46,52`) | Pre-satisfied by the gate |
| Faction init (`:65-95`) | Runs — classnames must be re-resolved against whatever mods are loaded now |
| `fnc_bluHQinit` (`:108`) | Runs, from the saved `PosOfBLUHQ`. It rebuilds the whole HQ deterministically, which is why persisting one position is enough |
| `fnc_init_OPFOR_WARCOM` (`:129`) | Runs, with the locator bypassed as above |
| `fnc_escalation` (`fnc_init_OPFOR_WARCOM.sqf:63`) | Runs the census, then the snapshot restores `escalation_destroyed` |
| `fnc_intro_heli` (`:424`) | **Skipped** |

FOBs restore the same way: call `fnc_fob_server` per saved position — silently, and with the saved
name — rather than reimplementing what it builds. Vehicles are spawned last, after every anchor is
standing.

## What is deliberately not saved

Live AI, spawned garrisons, active side missions, in-flight support, and the JIP task queue. Zone
garrisons and composition props both spawn and despawn on player distance
(`server/init_zones/fnc_spawnWait.sqf`), so a restored campaign regenerates them the first time a
player approaches — the same code path a fresh campaign uses.

Session-scoped locks go with them and must come back clear: the per-support fire-mission locks, the
per-FOB rebuild busy flags, `Mission_available`, and the JIP queue entries. A lock restored as held
is a support nobody can ever call again.

Composition streaming adds nothing here. Its stow records are built when a composition leaves the
map and dropped when it returns
([§Map object count](info/performance_hotspots.md#map-object-count-is-bounded-by-proximity-not-campaign-length)),
so they never outlive the session and a restore rebuilds every composition deployed.

This is the decision that keeps the plan finite. The server runs 40 `while {true}` loops across 23
files, each holding script locals; persisting live state would mean relaunching every one with
reconstructed arguments. Regenerating instead means they start the way they always do.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_campaign_save.sqf` | New. Builds the snapshot array and writes the namespace key. |
| `server/misc/fnc_campaign_restore.sqf` | New. Reads it, validates version and world, sets globals, replays builders. |
| `server/misc/fnc_campaign_vehicles.sqf` | New. Collects and respawns the stockpile around each anchor. |
| `server/misc/fnc_autoSave.sqf` | Rewritten to call the new save; drop `saveGame`. Owns the interval loop and the no-overlap guard. |
| `server/supports/fnc_sitrep_support.sqf:13` | Nothing here for persistence — it already asks the server to save. Its price and cooldown are [`ap_economy_plan.md`](ap_economy_plan.md#sitrep-becomes-free)'s business. |
| `server/server_init.sqf` | Early restore gate before `:15`; save triggers and the disconnect/end event handlers. Keep `enableSaving [false,false]` at `:113`; the engine save is no longer the mechanism. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-16,54,97` | Branch to the restore path for zones; feed saved towns to civilian init; replay ownership and reveal after `WARCOM_init_done`. |
| `server/supports/fnc_fob_server.sqf:7,20-24` | Accept a name; the announcement is silenced by the router, not a flag here. |
| `client/misc/fnc_duws_dialogue.sqf` | Suppress mode, so replayed builders announce nothing at boot. |
| `server/misc/fnc_civ_init_Tomata.sqf:170` | Accept a restored town set in place of the `fnc_civ_selectTowns` roll. |
| `client/client_init.sqf:449` | Loadout save keys on player UID, not the player object. |
| `server/server_fnc_init.sqf` | Registry lines; the support-unlock mirror writer; the settings name list. |
| `server/server_var_init.sqf` | Persistence-zone radius and per-anchor cap. |
| `client/client_init.sqf:95-113` | Resume screen ahead of `fnc_startup_faction_flow`, game master only. |
| `shared/includes/params_modern.hpp` | `DUWS_AutosaveInterval`, seconds, `0` for off, default 900. |
| `shared/includes/campaign_load_menu.hpp` | New. The load screen, in the existing setup-dialog idiom; `#include`d from `description.ext`. |
| `client/dialog/` | Its handlers and wipe confirmation; save export and import. |
| `description.ext` | `missionGroup = "DUWS_T";` |
| `info/architecture.md:122` | Replace the "vanilla `saveGame` only" persistence row. |
| `KNOWN_ISSUES.md` | Drop the save/reload row once it passes. |

## Task list

- [ ] Prerequisites 1-3 above, each as its own change. Prerequisite 1 gates the rest.
- [ ] Write `fnc_campaign_save.sqf` and dump a snapshot to the log without restoring. Verify: every value in it is a number, string, boolean or array of those, and `str` then `parseSimpleArray` round-trips it unchanged.
- [ ] Write `fnc_campaign_restore.sqf` covering pools, bounties and ownership only. Verify: restart mid-campaign and confirm CP, AP, reputation and a farmed zone's reduced bounty all return.
- [ ] Add zone replay through `fnc_createZone`, then the ownership and reveal passes after `WARCOM_init_done`. Verify: restored zones sit in the same places with the same radii, a captured zone comes back captured, a hardcore campaign's found zones stay found, and `amount_zones_created` matches the zone count instead of double it.
- [ ] Add HQ, FOB and civilian-town replay. Verify: HQ actions work, FOB triggers fire, FOB names and towns come back where they were, and the restore replays no FOB radio announcements.
- [ ] Add the vehicle persistence zone. Verify: a vehicle parked at a FOB returns with its damage, fuel, cargo and paint; a FOB's turret ring is not duplicated; the cap drops the furthest vehicle and logs it.
- [ ] Add the MHQ. Verify: a deployed MHQ comes back deployed, with a working respawn point and one ammo box.
- [ ] Add loadouts, support unlocks and cooldowns. Verify: a cooldown stamped just before the save has roughly its remaining time left after it, not the whole duration and not a wedged action.
- [ ] Add the autosave loop, its parameter and the other three triggers. Verify: changing `DUWS_AutosaveInterval` in the lobby changes the observed write cadence in the `.rpt`; two triggers firing together produce one write, not two; at `0` the loop never fires but SITREP and a clean exit still write.
- [ ] Add the zero-player gate. Verify: the campaign clocks stop with nobody connected and resume on join; a snapshot is written on the last disconnect; a connected headless client does not count as a player.
- [ ] Add the resume screen and its timeout. Verify: a hosted host is asked and can decline; a dedicated server with nobody connected resumes without waiting on the screen; declining wipes the save only after a confirmation.
- [ ] Version and world guards: refuse a snapshot from a different map or format version and start fresh with a logged warning.
- [ ] Add export and import. Verify: a save exported on one machine restores a campaign on another, and an oversized snapshot either survives the edit control or is chunked.
- [ ] On a dedicated server ([`info/dedicated_server_setup.md`](info/dedicated_server_setup.md)): play, restart, confirm the campaign continues. This cannot be validated by a hosted session — a host is both server and client and will mask locality faults.

## Decided trade-offs

**A restore is a fresh world with an old ledger.** Enemy garrisons, side missions and support in
flight are all lost. A player who restarts mid-firefight reappears with the zone unclaimed and the
garrison regenerated. Persisting the fight itself is a different and much larger project.

**Save on a timer, not on every change.** Writing the snapshot per CP change would put a
serialisation on the hot path of the most frequently written global in the mission. A periodic
write plus the disconnect and end hooks loses at most one interval of progress.

**The snapshot is versioned and map-locked.** Restoring a snapshot into a different world or an
incompatible format silently produces a broken campaign. Refusing it and starting fresh is worse
for the player in that moment and better every other time.

**Faction classnames are re-resolved, not restored.** A player who removes a faction mod between
sessions gets whatever auto-detection now picks, not a campaign full of missing classnames.
Storing resolved classnames would pin the campaign to a mod set, which is exactly what the
mission's no-hard-dependency rule refuses.

**The campaign idles at zero players.** Reasoning above. The cost is that a persistent dedicated
server no longer simulates a living war between sessions, which some hosts will want; it is one
gate to invert if that turns out to be the more popular reading.

**Vehicles persist by data, so they come back as new objects.** Anything attached to the old
object is lost. The alternative is persisting object identity, which vanilla cannot do.

## Open questions

- Whether the edit control survives a full-size snapshot on import, and at what size chunking
  becomes necessary. This is the only part of the transfer story that cannot be settled on paper.
- Whether a per-anchor cap of 15 vehicles is generous or stingy. It wants a play-test, not an
  argument.
- Where a player who wants to save *now* is sent. SITREP is that control today and it is a radio
  support, which is not where anyone looks after pressing Escape. Singleplayer feels this hardest.
- Whether a restored campaign should replay anything at all to the player — a one-line "campaign
  resumed, day N" — or come up silent. Silent is the default here because every builder is being
  suppressed anyway.
- Whether `BIS_fnc_saveInventory` output is pure data on every container type the mission can
  produce, including modded vehicles.
- What happens to a save when the mission's own format changes mid-Workshop-release. Refusing it
  is the decided behaviour; whether a migration path is ever worth writing is not decided.
- Whether the zero-player gate should be a host-facing setting rather than a decision. It is the
  same kind of question as the autosave interval, so it would be the same kind of answer — a
  mission parameter — and the argument against is that a host who turns it off is choosing to lose
  ground while logged out, which is not obviously a choice worth offering.
