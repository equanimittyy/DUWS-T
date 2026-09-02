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
fortifications will only if they are designed that way from the start
([§Features not built yet](#features-not-built-yet)), and the enemy commander's state carries the
same contract into [`opcom_plan.md`](opcom_plan.md#persistence).

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

**It is the default rather than the only option, because it is reported broken on Linux servers.**
Antistasi ships the choice between it and `profileNamespace` as a control on its own load screen,
defaulted off on Linux with the reason printed on the control. So the namespace and its flush are
each reached through one function and named nowhere else; the fallback is then a one-line change.
That indirection, and the rest of the container the snapshot travels in, are
[`campaign_save_format.md`](../info/architecture/campaign_save_format.md). `profileNamespace` stays the fallback rather
than the default because it is shared by every mission on the box, so a player clearing one
mission's state risks another's.

`saveGame` is not a candidate at all. It saves a whole session rather than a data snapshot, so it
cannot be replayed through the builders, which is what the restore below depends on. That holds
whether or not it works in multiplayer, which is
[still unestablished](../../KNOWN_ISSUES.md#does-a-multiplayer-save-happen-at-all).

### Transferring a save between machines

Three routes. Two of them are what a player uses; the clipboard is the escape hatch, not the
mechanism.

| Route | Mechanism | Limits |
|---|---|---|
| Copy the file | `DUWS_T.vars.Arma3Profile` out of the profile directory | Different directory on a client and a dedicated server; the player has to find it |
| Client profile carry | The server hands the snapshot to a connected client, which keeps it in its own `profileNamespace` and offers it back on the load screen | Needs that client connected when the save is taken; validated coming back in, not trusted |
| Clipboard string | `copyToClipboard` out, paste into an edit control in | One deliberate player action per direction; edit-control length under a full snapshot is untested |

All three move the same value, and they cost almost nothing because the snapshot is already a
single JSON string in the store — `toJSON` on the way out and `fromJSON` on the way back, with no
serialiser to write or keep in step. Antistasi's export is nine lines and its import twenty-one
for that reason.

**The clipboard cannot be the store, because SQF can write it and not read it.** `copyToClipboard`
has no counterpart, so every import ends at a human pasting into an edit control — which is a thing
no unattended restart can do. That settles the store question rather than weighing it: the namespace
is not preferred over the clipboard, the clipboard is not a candidate. `copyToClipboard` also writes
the clipboard of the machine it runs on, so on a dedicated server an export has to be `remoteExec`'d
back to the requesting client or it lands on the server box where nobody can reach it. The control
the paste lands in already exists in the mission — `RscEditMulti` idc 2100
(`shared/includes/custom_faction.hpp:59`), read with `ctrlText`, carries custom-faction definitions
today.

**The carry route is the store's own mechanism pointed at a client.** A client's `profileNamespace`
is durable in the same way the server's `missionProfileNamespace` is, so an export is a `remoteExec`
plus `saveProfileNamespace` on the receiving end and an import is a `getVariable`, with nothing for
the player to find, copy or paste. That is why it is the primary route and the clipboard is the
fallback. Two consequences, both handled rather than avoided: a profile the player can hand-edit is
an input, so a carried snapshot is validated exactly as the server's own is (version, world, types)
instead of trusted — cover against a stale or corrupted payload in a co-op mission, not anti-cheat;
and two clients can offer divergent copies of one campaign, which the write stamp in
[§Identity and settings](#identity-and-settings) decides — newest wins, and the screen names what it
is about to load.

**Extension-based stores are refused as the mechanism, and shipping one inside the PBO is not
available as a compromise.** FileXT, extDB and iniDBI can write real files and are what large
persistent missions usually end up on. Every one of them is a binary, because SQF has no
file-writing command at all — that is the reason they exist, not an implementation choice. And the
engine resolves an extension only from the root of a loaded mod folder or the game install
directory; a mission PBO is never searched and is never unpacked to disk. So there is no version of
"vendor the dependency" that reaches a file. The mission already vendors third-party *script*
modules (`src/modules/`), and that is the ceiling: anything shipped inside the PBO ends at the
profile namespace, which is where this plan already is.

**The one route that costs a player nothing is a dedicated server's `-serverMod`.** Server mods are
not announced to clients, so nothing is downloaded, enabled or signature-checked on the joining
player's side — an admin who installs iniDBI2 gets real files for free, and the campaign's players
never learn it is there. That is worth building toward because the snapshot is a value rather than a
format, so an extension writer is one alternative `setVariable` site. Three limits keep it optional
rather than primary: it does nothing for singleplayer or a hosted session, where the host *is* the
server and would have to install the binary themselves; iniDBI2's is a Windows C# DLL, so a Linux
dedicated box needs the community port; and a mission that only saves when an extension is present
fails exactly the no-hard-dependency rule. The vanilla path has to be complete on its own first, and
this plan is that path.

The Workshop's "required items" does not soften any of this: it subscribes the dependency, and the
player still has to tick it in the launcher before the scenario will run with it.

## When the save is written, and what happens with nobody on

The writer is the server and there is only one. Four triggers:

| Trigger | Why |
|---|---|
| Periodic timer | The only protection against a crash or an ALT-F4, neither of which fires any hook |
| SITREP action | The existing manual save, kept |
| Last player disconnecting | On a default dedicated server this is the last moment the mission exists. Under `persistent = 1` the loop's first empty pass would cover it; on the default that pass never comes |
| `Ended` / `MPEnded` mission event handlers | Covers a clean mission end or admin `#missions` |

Every write is gated on `mission_init_complete` (`server/server_var_init.sqf`). A snapshot taken
during zone build-out describes half a campaign, and restoring it would produce a map with some
zones and no others.

**The last-disconnect write cannot be scheduled.** Under `persistent = 0` the mission ends in the
frame the last player leaves, so a `spawn`ed save is a thread the mission may never get to run —
the trigger that exists *because* it is the last moment the mission exists is also the one with no
time to spare. The snapshot and the flush both `call`, inside the disconnect handler
(`server/server_init.sqf:221`). That handler also has to identify the last player rather than count
them: the leaver can still be in `allPlayers` when it fires, so the test excludes the UID the
handler was handed.

**A campaign that has ended is written, and must then never be auto-loaded.**
`server/misc/fnc_capture_zones_task.sqf:87` ends the mission on total victory, which fires the
`Ended` trigger above; the load screen's timeout reloads the newest snapshot on the next unattended
start, and that campaign's win condition is true on its first evaluation — so the server ends and
restarts into it again, indefinitely, with nobody able to play. Both endings go in the snapshot
header: the win, and the `campaign_lost` that is otherwise stored nowhere and would restore a lost
campaign as a live one on a flattened map. The index labels a terminal campaign and the timeout
passes over it; a player can still pick it deliberately.

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
([`economy_second_pass.md`](economy_second_pass.md#sitrep-becomes-free)). Off is a second reason for that
change to land rather than a reason to withhold the option, because it promotes the manual save
from a convenience to the only in-session one. The grant itself follows the `game_master` slot
rather than the person (`server/server_var_init.sqf`), so a co-op team whose game master leaves
recovers it by someone taking that slot.

- **The deadline is a variable the loop polls, not a `sleep`.** Every write sets the next deadline,
  so a manual save pushes the timer out instead of being followed seconds later by an automatic
  one. That needs a short poll against a stamp rather than sleeping the interval.
- **It always writes, as long as somebody has been on since the last pass.** Tracking whether
  campaign state changed would mean a dirty flag on every writer in the mission; tracking whether
  anyone was connected is one count. Antistasi's condition is the one to copy — players now *or*
  players at the previous pass — because the first empty tick still writes, which is what banks the
  session on a server that has just emptied.
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
[OPCOM](opcom_plan.md#what-the-commander-spends-on) lands — the enemy keeps
buying garrisons and hardpoints against a player who is asleep.

**Decided: the campaign idles at zero players.** A player who logs off overnight and returns to a
poorer wallet and a fully upgraded enemy has lost ground by not playing, which is not a mechanic
anyone chose — OPCOM spending an unattended night buying garrisons is the sharp
edge of it. The server also burns CPU simulating a war nobody is watching. The gate goes on the
campaign clocks — the economy tick, the WARCOM wave threads, the side-mission generator, the
hardpoint and director build ticks — not on everything. The zone spawn/despawn checker and the JIP
machinery keep running; with no players they are already no-ops, and gating them would only add a
branch.

Antistasi does not do this — its war runs regardless and only the save loop stops writing — so
this is a divergence from the prior art rather than an uncontested default.

**A "the war moved on" mechanic is the eventual answer and is not this plan's.** Idling is the
correct floor because it can only ever cost the player nothing; a system that advances the
campaign across an absence has to decide what it advances, by how much, and how the player is told
— a design question, not a persistence one. The elapsed real time is derivable whenever it is
wanted, because the write stamp is already in the snapshot.

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
| `civ_locations` stores Location objects in the mission namespace, which the mission's own rule forbids because the namespace is what a save serialises | `server/civilian/fnc_civ_init_Tomata.sqf:170`, rule in [`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) |
| Consumable support unlocks stay client-local by design, and what each one charged is recorded only on the buyer's machine | `client/supports/fnc_supports_init.sqf` |
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
| `fnc_createZone` appends to `zone_namePOS_pairs` and `Array_of_OPFOR_zones`, registers the site, and increments `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-34` | Restoring those globals *and* replaying the builder counts every zone twice |
| `fnc_WARCOM_init` clears the BLUFOR zone list and hands every zone back to OPFOR | `server/warcom/fnc_WARCOM_init.sqf:38-46` | Ownership applied before it runs is wiped; every capture is lost |
| The setup-screen gates block on globals a *client* publishes | `server/server_init.sqf:46,52` | A restore has no player at those screens, so boot never gets past them |
| The locator `spawn`s `fnc_createZone` per zone, so builds finish out of order | `server/init_zones/fnc_locatorzones_random.sqf:181` | Registration order is not zone order, so anything keyed by array position is keyed to the wrong zone. `zone_meta_array` carries `_zone_num` for this reason |
| `fnc_fob_server` rolls a fresh name and announces the FOB over radio behind a 5 s sleep | `server/supports/fnc_fob_server.sqf:7,20-24` | Replaying it renames every FOB and queues one callout per FOB at boot |
| Zone names are drawn at random from a pool that records what it has spent | `server/init_zones/fnc_zone_state_init.sqf`, `fnc_createzone.sqf` | Replaying the builder renames every zone on the map. The names *and* the used list have to be restored, and the builder must not re-draw |
| Campaign settings are set *and* broadcast by a client | `client/dialog/fnc_process_campaign_menu.sqf:480-515`, `fnc_process_enviro_menu.sqf:88-194` | A restore that only assigns them server-side leaves every client on defaults |
| Arsenal contents are resolved at boot from whatever mods are loaded | `server/misc/fnc_create_ammo_lists.sqf` | Storing the resolved classnames pins the campaign to that mod set |
| Hardpoints are sited in a generation phase after zone build-out and stored in `DUWS_hardpoints` ([`info/hardpoints.md`](../info/gameplay/hardpoints.md#siting)) | `server/warcom/fnc_init_OPFOR_WARCOM.sqf:52-96` | Replaying generation re-rolls every hardpoint position and orphans its cleared state |

One thing that looks like a blocker and is not: `fnc_fob_server` takes a `_fob_owner` object
(`:5`) and hands it to `fnc_FOBactions.sqf:3`, which reads it and never uses it. Restore needs no
substitute for it. That dead parameter pre-dates this plan and is left alone here.

## Prerequisites

None of these is persistence work, and all of them must land first. Each is independently worth
doing.

1. **Confirm the store reads back on our dedicated server.** Dedicated servers historically wrote
   profile-namespace variables to disk correctly and failed to read them back on the next start.
   What de-risks that is not that it is reported fixed but that the store is Antistasi's
   `missionProfileNamespace`, which Antistasi runs in production on dedicated servers today
   ([`campaign_save_format.md`](../info/architecture/campaign_save_format.md)) — a mechanism with that much live mileage
   is not the open unknown the plan rests on. The remaining failure mode is ours, not the engine's:
   the namespace is read back for the profile that wrote it, so **run the check with a fixed
   `-profiles` and `-name`.** A server whose profile identity moves between starts saves each session
   under a different one and presents as the engine bug rather than as a launch-parameter mistake,
   and a probe that does not control for it cannot tell the two apart. Write one key, restart, read
   it — a ten-minute confirmation, not a gate the design hangs on.
2. **Make `fnc_fob_server` replayable.** It needs an optional name, for the naming reason in the
   table above. Silencing its announcement belongs on `fnc_duws_dialogue`, not here: a restore
   replays several builders, and a per-function flag has to be re-invented at every one of them.
   The position registry it needs is already in place: `Array_of_FOBpos`
   (`server/supports/fnc_fob_server.sqf:84`).
3. **Read the support mirror back on restore.** The write half exists:
   `DUWS_support_permanent` holds the team's permanent unlocks in purchase order, and each client
   keeps the individual flags as its fast path
   ([`info/economy.md`](../info/gameplay/economy.md#supports-permanent-and-consumable)). What is missing is the
   read — a restore has to replay the array into the flags, and a joining client should be told the
   set rather than inferring it from six broadcast booleans. Consumable unlocks are deliberately out
   of scope: they are per-player and are lost on death already, so a restart costs no more than a
   firefight does.

**Taking Locations out of `civ_locations` is not one of them.** The civilian rewrite deliberately
kept them: the entries are the map's own Locations, never deleted so that the `nearestLocations`
consumers keep seeing them (`server/civilian/fnc_civ_init_Tomata.sqf:145-170`). That still breaks the
mission-namespace rule and is still worth fixing, but it does not block this plan. The snapshot
stores town positions, and restore re-resolves each one to a Location through the same
`nearestLocations` filter the selector uses (`server/civilian/fnc_civ_selectTowns.sqf:42`); the world
guard pins the map, so the lookup returns what it stored.

## The snapshot

One hashmap, keyed by name, serialised as a single JSON string; the container and its type rules
are [`campaign_save_format.md`](../info/architecture/campaign_save_format.md). Named keys rather than array positions
so that adding a field to a later version does not shift what an older save's readers see. Only
serialisable types go in: numbers, strings, booleans, arrays and hashmaps of those. No objects, no
groups, no triggers, no Locations, no netIds — netIds are strings but resolve to nothing after a
restart, which is worse than a type error because it fails silently.

Every group below is one key. The tables name what each holds, not the order it holds it in.

Entries split into **inputs**, fed to the builders before they run, and **outcomes**, applied
after the builders have run and reset what they own. The split answers the first two rows of the
table above: anything the replay rebuilds must not also be restored, or it is double-counted.

### Identity and settings

| Group | Kind | Contents |
|---|---|---|
| Identity | — | format version, `worldName`, campaign start time, UTC write stamp |
| Server config | input | every global the setup screens broadcast |
| Callsign | input | `duws_callsign` |

**The write stamp is `systemTimeUTC`, and it is a label and a tiebreak, nothing else.** The load
screen has to say how old a save is, and two carried copies of one campaign need an ordering; UTC
rather than `systemTime` so a save that crosses a time zone still compares correctly. Nothing gates
on it — the rule against absolute stamps above exists because `diag_tickTime` restarts with the
process, and a wall clock does not.

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
| Clock | outcome | `date` |

**The campaign clock is stored because boot sets it unconditionally.**
`server/server_init.sqf:154` calls `setDate [2035, 8, 3, time_of_day, 0]`, so without this every
restore snaps back to the third day at the hour the campaign was configured with, and a night
operation resumes at noon. It is gameplay state rather than presentation:
`server/events/fnc_night_horde_event.sqf:33` counts days off `date`, and the load screen labels each
row with one. It is an outcome because it has to be re-applied after `setTimeMultiplier` (`:159`)
rather than before the builders — the boot line would overwrite it.

**Zone names have to be stored.** They are drawn, not derived: `fnc_zone_name` hands out a
phonetic-alphabet word at random and records which are spent, so nothing about a zone's index or
position reproduces the name it was given. A restore that re-ran the allocator would rename every
zone on the map, and the player's own notes and any dialogue they remember would stop matching the
ground. Storing the string costs nothing in translation, which was the old objection: these words
carry no stringtable key and are the same in every language. The used-name list is restored with
them, or the allocator would hand a second zone a name already on the map.

Towns go in by position even though the runtime keys them by index into `civ_locations`, because
that index is not stable across a restore: selection's top-up wave shuffles before it draws
(`server/civilian/fnc_civ_selectTowns.sqf:125`) and the registration cull drops towns depending on
which radii survive. A Location's position comes out of the map's config and does not move.

### Territory, economy and escalation

| Group | Kind | Contents |
|---|---|---|
| Pools | outcome | `commandpointsblu1`, `WARCOM_blufor_ap`, `WARCOM_opfor_ap` |
| Ownership | outcome | the positions of BLUFOR-held zones, and nothing else |
| First capture | outcome | `DUWS_zone_first_captured`, the per-zone flags that gate the one-time liberation bonus |
| Town reputation | outcome | `civ_town_rep` and `civ_town_ap` |
| Escalation | outcome | `escalation_destroyed`. One integer; the census re-runs on the restored world |
| Tier ratchet | outcome | per-side earned counters `WARCOM_blufor_ap_earned` / `WARCOM_opfor_ap_earned`, and the tiers derived from them (`WARCOM_blufor_tier`, `WARCOM_opfor_tier`) |
| Kill income | outcome | the per-player kill tally awaiting conversion, keyed by UID, and the CP already banked for players who have left |

**Ownership is stored as held positions and nothing derived from them.** Restore applies each as
`["BLU", _pos] call fnc_zone_control_set`; that writer moves both side lists and both counters
together and broadcasts them atomically (`server/init_zones/fnc_zone_state_init.sqf:31-70`), so
`zoneundercontrolblu` and `amount_zones_captured` come out consistent instead of being separately
restored and separately wrong.

**The first-capture flags are not derivable.** `DUWS_zone_first_captured`
(`server/init_zones/fnc_captured.sqf`) records which zones have ever paid their one-time CP+AP
liberation bonus. Without it a restore re-pays the bonus for every zone already taken — and because
that bonus also credits the AP tier counter, it silently re-ratchets the ladder on top. (The CP
capture bounty this row used to carry is retired with the town→CP reroute.)

**The tier ratchet is state, not a threshold test.** The tier derives from a per-side *earned*
counter that only ever rises (`WARCOM_*_ap_earned`), never from the spendable wallet, so the earned
counter is the source of truth the save must carry — the tier is re-derivable from it on load
(`DUWS_fnc_ap_tier`). Deriving the tier from the live wallet instead reads a number since spent down,
silently un-unlocking an enemy that had already reached armour — the failure mode
[`economy_second_pass.md`](economy_second_pass.md#the-ratchet-is-otherwise-structural-and-only-in-half-the-read-sites)
describes. Floor shipped these globals broadcast but unsaved; this snapshot is what closes that.

**Kill income needs one existing handler changed to survive a restore.**
`server/server_init.sqf:214` zeroes a UID's tally on `PlayerConnected` so that a rejoining player
does not resume a count from earlier in the session; against a restored tally it deletes exactly
the entries the snapshot was written for. The handler has to skip UIDs the restore has just
written. The banked total goes in beside the tally because it holds a leaver's unpaid kills
(`:224`), which makes it the balance most likely to be non-zero at the moment a persistent server
saves on the last disconnect.

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
| Town garrisons | outcome | purchased tier per town (`DUWS_townGarrisonTier`) |
| Hardpoints | input | `hardpoint_pos_array`, `hardpoint_type_array`, `hardpoint_zone_array`, `hardpoint_state_array`, the `zone_hp_left_<n>` counters |

Hardpoints are an input for the same reason zones are:
[`info/hardpoints.md`](../info/gameplay/hardpoints.md#siting) sites them in a generation phase after zone
build-out, so the siting pass has to accept a restored `DUWS_hardpoints` registry instead of rolling
fresh positions, or a restore moves every hardpoint and orphans its cleared state. Zone-ring and
standalone hardpoints run in that one phase and share the one registry, so a single guard covers
both. Cores and garrison groups are live objects rebuilt on approach from the stored composition,
so they stay out of the save.

Town garrison tier is stored because the store already exists: `DUWS_townGarrisonTier` is written the
moment a town crosses `-10` into the OPFOR band, independently of the commander
([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv)), so a restore
that dropped it would repair every turned town back to ungarrisoned.

**The commander's own state is deferred with the commander.** The archetype, its standing orders
(taskings) and — if it is ever wanted — its belief store are snapshot content only once OPCOM exists,
and their persistable shape and serialisation contract are
[`opcom_plan.md`](opcom_plan.md#persistence)'s to define, not this plan's. The
snapshot is a name-keyed hashmap ([§The snapshot](#the-snapshot)), so it gains those keys when the
commander lands and omitting them until then costs a restore nothing.

### The players

| Group | Kind | Contents |
|---|---|---|
| Loadouts | — | `getUnitLoadout` per player UID |
| Support unlocks | input | the server-side mirror, per UID |
| Reveal | outcome | positions of revealed zones and revealed towns, indices of revealed normal hardpoints |
| Cooldowns | outcome | remaining seconds per player-scoped cooldown, per UID |

Loadouts are already data; what they lack is a stable key. `client/client_init.sqf:449` stores the
loadout on the player object, which dies with the session, so the mirror keys on UID. One hashmap
of per-player hashmaps, and the three guards a UID-keyed player save needs — a per-player
"restored yet" flag, stripping a loadout saved while dead, and deleting the unit whose gear has
just been banked — are in
[`campaign_save_format.md`](../info/architecture/campaign_save_format.md#per-player-data).

**Reveal is an outcome, not an input.** A hardcore campaign's entire progress is which zones and
towns the player has found, and a replay re-hides both: `fnc_createzone.sqf:16` sets every zone's
visibility from `hardcore_mode_enable`, and `fnc_civ_init_Tomata` hides every town outside the HQ
anchor's opening quota. Store the positions of both, then re-flag the matching `zone_namePOS_pairs`
and `civ_visible` entries and repaint their markers after build-out — the same shape and the same
reason as Ownership.

Storing the state rather than how it was reached is what keeps this to a flat list of positions: a
zone the player walked into, bought from a local, or found on a dead officer all restore
identically, because by then they are one flag. Whether a hardpoint has been revealed is
separate state on the same footing, because intel can uncover one without its parent zone. Details
in [`info/intel_system.md`](../info/gameplay/intel_system.md#persistence).

**Reveal is team state today and stays that way.** `zone_namePOS_pairs` and `civ_visible` are
shared arrays and the markers they drive are global, so there is no per-player reveal to persist.
Making reveal personal is a design change to the intel system, not a persistence feature, and it
would mean per-player markers everywhere.

### The friendly arsenal is not stored; the captured pool will be

Faction init rebuilds the friendly virtual cargo from scratch
(`server/misc/fnc_create_ammo_lists.sqf`), so a restore re-resolves it against whatever mods are
loaded now. Storing those classnames would pin the campaign to the mod set that produced them, which
is exactly what the no-hard-dependency rule exists to avoid. The friendly shelf therefore stays out
of the snapshot.

The **captured-materiel pool** (`DUWS_capturedPool`, written by the `fnc_captured_pool_*` functions in
`server/misc/fnc_economy_init.sqf`) is the opposite case, and is
the one arsenal state that will be persisted. It is player-earned and scarce — the enemy gear brought
back and banked — so losing it on reload loses progress, the same argument that puts the vehicle
stockpile in the snapshot rather than the friendly cargo. Like the stockpile it is data, one
`class -> count` map, and like it, it pins to the mod that produced the classnames: a removed enemy
mod drops those entries, so restore validates each class and discards the unknown rather than
restoring a name that resolves to nothing. It joins the snapshot as one key, deferred with the pool
itself — the group lands when the arsenal work does.

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
| Pylons | `getPylonMagazines` | Aircraft only; restored with `setPylonLoadout`, already used at `server/supports/fnc_pylon_init.sqf:33` |
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

### The load screen

**The first setup screen is a fork: New Game or Load Game.** It is shown to the game master —
`game_master = ["player1"]` (`server/server_var_init.sqf:331`), so the singleplayer player is one —
one link ahead of `fnc_startup_faction_flow`, and it is shown every campaign rather than only when a
save exists. A screen that appears only sometimes is one players do not know they have, and it is
also the only place an import can live: a machine with no save of its own is exactly the machine that
needs to bring one in.

- **New Game** runs the existing setup flow — faction, HQ placement, environment, callsign —
  unchanged.
- **Load Game** lists the campaigns in the save index, newest first, each labelled from its stored
  header: world, day, zones held, CP, and how long ago it was written. It is disabled, with the
  reason on the control, when none of them is loadable here. An unlabelled choice is not a choice.
- **Import** takes a snapshot from this client's own profile or from a pasted string, validates it,
  and adds it to the list. Export is not here: a player exporting has a campaign running, so it
  belongs with the in-session save controls.

**New Game destroys nothing, because it writes under a new campaign ID.** That falls out of the
index shape rather than being designed for: an existing campaign is only ever overwritten by its
own saves. What the screen needs instead is a delete, so the list cannot grow without bound — one
deliberate action, on a named row, with a confirmation.

**A save that fails validation is named and disabled, not hidden.** A row the player can see and
cannot pick, carrying why, beats a list that silently omits the campaign they are looking for.
`_prev` is offered the same way when a payload fails to parse.

**The screen is one more dialog in the chain, not a new mechanism.** `shared/includes/` holds one
`.hpp` per screen, each `idd = -1`, each disabling ESC through an `onLoad` `KeyDown` handler, each
closing through a handler that spawns the next step — which is exactly how
`fnc_startup_faction_flow` chains HQ placement into the faction prompts into the environment menu.
The load screen is one more member of that chain, placed one link earlier, and building it any other
way means inventing a second setup idiom for one screen. Eating ESC matters more here than on
the others: escaping this one leaves boot blocked on a question with no answer.

### Nobody at the screen

A dedicated server restarting unattended has no game master connected, and coming back up on its own
campaign is the checkpoint the whole dedicated story rests on. So the screen has a timeout, on the
same `fnc_waitLogged` pattern as every other setup gate, and **the timeout loads the newest valid
snapshot when one exists and starts a new campaign when none does.** The bound is short while no
player is connected and extends to the setup-screen bound once one is, so an unattended restart is
not delayed by a screen nobody can see and a host is not raced past by a timer.

Antistasi makes the same timeout a mission parameter defaulting to off (`autoLoadLastGame`,
`-1` through 600 seconds). Here it defaults to on, because a server that will not restart into its
own campaign without an admin present is the failure this whole plan exists to fix, and the two
properties below make defaulting to Load recoverable rather than merely convenient.

Loading without asking is recoverable — the player picks New Game at the next restart — where
starting fresh without asking would strand the campaign behind a screen nobody attended. And a
load that was not wanted cannot damage what it read: nothing is written until
`mission_init_complete`, and a New Game started afterwards writes under its own campaign ID.

**Everyone else waits where they already wait.** Non-game-master clients block on
`HQ_pos_found_generated && chosen_settings` (`client/client_init.sqf:139-143`) and need no knowledge
of the screen at all — a load satisfies both flags the same way a finished setup does.

### Hooks, in boot order

**An early gate in `server_init.sqf`, between `:9` and `:15`.** After `server_var_init` so a snapshot
overwrites the defaults, before the terrain survey so the survey can be skipped. It has to sit this
early because the setup gates at `:46,52` block on globals a *client* publishes. Because the answer
now comes from a player, the gate is three steps rather than one:

1. **Scan.** Read the key, validate version and world, publish the summary the load screen labels
   its Load control with. An absent or invalid snapshot publishes an *empty* summary rather than
   nothing at all: the client waits on this variable, and a variable that is never set is
   indistinguishable from a server still working.
2. **Wait — but only when there is something to load.** On an empty summary the gate returns
   immediately and boot proceeds exactly as today. That is not a micro-optimisation:
   `fnc_moreUrban_locations` is `spawn`ed at `:15` and has been recorded taking 140 s, and today it
   runs *while* the player is in the setup screens. Blocking ahead of it on every campaign would move
   that 140 s out from behind the screens and into the player's wait.
3. **Apply, on Load only.** Publish the settings and placement inputs, raise `DUWST_restoring` for
   the later hooks, and set `chosen_hq_placement` and `createzone_server` true — those gates are now
   `fnc_waitLogged` loops, so satisfying them clears them immediately and nothing has to branch
   around them. Skip the terrain survey. On New Game none of this happens and the gate is a no-op.

The client must **wait** for the summary rather than sample it. A joining client is sent every
`publicVariable`'d global and then runs its own init over the top
([`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#a-joining-client-is-sent-every-publicvariabled-global-then-its-own-init-overwrites-them)),
so a screen that reads the variable once at boot can read back the default it just wrote itself.

**The fork lives inside the existing game-master block** (`client/client_init.sqf:95-113`), with that
block's current contents — `fnc_startup_faction_flow` and its `chosen_settings` wait — moving into
the New Game branch. Load needs no client-side flag of its own: the branch it is not in is the one
that opens the setup screens.

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
(`server/misc/fnc_site_stream_init.sqf`), so a restored campaign regenerates them the first time a
player approaches — the same code path a fresh campaign uses.

Session-scoped locks go with them and must come back clear: the per-support fire-mission locks, the
per-FOB rebuild busy flags, `Mission_available`, and the JIP queue entries. A lock restored as held
is a support nobody can ever call again.

Composition streaming adds nothing here. Its stow records are built when a composition leaves the
map and dropped when it returns
([§Map object count](../info/architecture/performance.md#map-object-count-is-bounded-by-proximity-not-campaign-length)),
so they never outlive the session and a restore rebuilds every composition deployed.

This is the decision that keeps the plan finite. The server runs 25 `while {true}` loops across 19
files, each holding script locals; persisting live state would mean relaunching every one with
reconstructed arguments. Regenerating instead means they start the way they always do.

### What live state costs, and who pays it back

Discarding live units discards what was *spent* on them. A save taken while a WARCOM wave is in
the air deletes the wave and the AP that bought it; a support in flight takes its CP with it. Over
a campaign of restarts that is a slow leak out of both economies, and it gets worse once the
[OPCOM](opcom_plan.md#what-the-commander-spends-on) is buying continuously.

Antistasi reconciles this at save time rather than living with it: before writing, it walks live
vehicles and units and folds their value back into the pools it is about to save — a full refund
for anything not crippled, explicitly *"to reduce exploiting save-on-attack"*, and the same pass on
the player side for a player's live AI squad and their vehicle.

**Decided: a reconciliation pass runs before every write, on both sides.** The alternative is that
the correct play becomes to save immediately after committing a wave, which is a mechanic nobody
chose. Scaling by remaining health is the shape to copy — a refund proportional to what survives
means saving mid-firefight is neither punished nor exploitable. What each unit and vehicle is worth
is already the price tables the economies buy from, so this is a walk and a sum, not new pricing.

**The refund lands in the snapshot's pools, never in the live ones.** The pass runs on a repeating
timer for the life of the campaign, so a refund applied through `fnc_ap_adjust` pays for the same
live wave again at every interval, and on a server that stays up for days the enemy's pool grows
with uptime rather than with play. Reconciling into the copy about to be serialised keeps each
refund attached to the one restore that consumes it.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_campaign_store.sqf` | New. The container: namespace resolution and flush, the accessor pair, the index, commit and scan. Shape and responsibilities in [`campaign_save_format.md`](../info/architecture/campaign_save_format.md). |
| `server/misc/fnc_campaign_save.sqf` | New. Fills the snapshot hashmap from mission state and commits it. |
| `server/misc/fnc_campaign_restore.sqf` | New. Validates a payload, sets globals, replays builders. The same validation is what an imported snapshot goes through. |
| `server/misc/fnc_campaign_reconcile.sqf` | New. Folds the value of live units and vehicles back into the pools, before every write. |
| `server/misc/fnc_campaign_vehicles.sqf` | New. Collects and respawns the stockpile around each anchor. |
| `server/misc/fnc_autoSave.sqf` | Rewritten to call the new save; drop `saveGame`. Owns the interval loop and the no-overlap guard. |
| `server/supports/fnc_sitrep_support.sqf:13` | Nothing here for persistence — it already asks the server to save. Its price and cooldown are [`economy_second_pass.md`](economy_second_pass.md#sitrep-becomes-free)'s business. |
| `server/server_init.sqf` | Early gate before `:15` — scan, wait for the fork, apply; save triggers and the disconnect/end event handlers. Re-apply the saved date after `:159`, and stop the connect handler at `:214` zeroing a restored kill tally. Keep `enableSaving [false,false]` at `:113`; the engine save is no longer the mechanism. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-16,54,97` | Branch to the restore path for zones; feed saved towns to civilian init; replay ownership and reveal after `WARCOM_init_done`. |
| `server/supports/fnc_fob_server.sqf:7,20-24` | Accept a name; the announcement is silenced by the router, not a flag here. |
| `client/misc/fnc_duws_dialogue.sqf` | Suppress mode, so replayed builders announce nothing at boot. |
| `server/civilian/fnc_civ_init_Tomata.sqf:170` | Accept a restored town set in place of the `fnc_civ_selectTowns` roll. |
| `client/client_init.sqf:449` | Loadout save keys on player UID, not the player object. |
| `server/server_fnc_init.sqf` | Registry lines only. The manifest holds no bodies, so the support-unlock mirror writer and the settings name list land in a module beside their subsystem. |
| `server/server_var_init.sqf` | Persistence-zone radius and per-anchor cap. |
| `client/client_init.sqf:95-113` | The New Game / Load Game fork at the top of the block, game master only; the existing faction flow moves into the New Game branch. |
| `shared/includes/params_modern.hpp` | `DUWS_AutosaveInterval`, seconds, `0` for off, default 900. |
| `shared/includes/campaign_load_menu.hpp` | New. The fork screen — New Game, Load Game with the campaign list, Import, Delete — in the existing setup-dialog idiom; `#include`d from `description.ext`. |
| `client/dialog/` | Its handlers, the delete confirmation, and import from a carried profile or a pasted string. |
| `description.ext` | `missionGroup = "DUWS_T";` |
| `info/architecture.md:132` | Replace the "vanilla `saveGame` only" persistence row. |
| `KNOWN_ISSUES.md` | Drop the save/reload row once it passes. |

## Task list

- [ ] Prerequisites 1-3 above, each as its own change; land Prerequisite 1's confirmation first.
- [ ] Write `fnc_campaign_store.sqf`: namespace resolution, accessors, index, commit, scan. Verify: two campaigns written under separate IDs both appear in the index with correct headers; a commit replaces its own row rather than appending; `_prev` holds the previous payload.
- [ ] Write `fnc_campaign_save.sqf` and dump a snapshot to the log without restoring. Verify: `toJSON` then `fromJSON` round-trips it unchanged, and nothing in it is an object, group, side or `netId`.
- [ ] Write `fnc_campaign_restore.sqf` covering pools, the first-capture flags, the AP tier and ownership only. Verify: restart mid-campaign and confirm CP, AP, reputation, each side's AP tier and a re-taken zone paying no fresh liberation bonus all return, and that the campaign resumes on the date and hour it was saved at rather than on day three.
- [ ] Add zone replay through `fnc_createZone`, then the ownership and reveal passes after `WARCOM_init_done`. Verify: restored zones sit in the same places with the same radii, a captured zone comes back captured, a hardcore campaign's found zones stay found, and `amount_zones_created` matches the zone count instead of double it.
- [ ] Add HQ, FOB and civilian-town replay. Verify: HQ actions work, FOB triggers fire, FOB names and towns come back where they were, and the restore replays no FOB radio announcements.
- [ ] Add the vehicle persistence zone. Verify: a vehicle parked at a FOB returns with its damage, fuel, cargo and paint; a FOB's turret ring is not duplicated; the cap drops the furthest vehicle and logs it.
- [ ] Add the MHQ. Verify: a deployed MHQ comes back deployed, with a working respawn point and one ammo box.
- [ ] Add loadouts, support unlocks and cooldowns. Verify: a cooldown stamped just before the save has roughly its remaining time left after it, not the whole duration and not a wedged action; a rejoining player's restored kill tally survives their reconnect instead of being zeroed by the connect handler.
- [ ] Add the autosave loop, its parameter and the other three triggers. Verify: changing `DUWS_AutosaveInterval` in the lobby changes the observed write cadence in the `.rpt`; two triggers firing together produce one write, not two; at `0` the loop never fires but SITREP and a clean exit still write.
- [ ] Add the zero-player gate. Verify: the campaign clocks stop with nobody connected and resume on join; a snapshot is written on the last disconnect, on a `persistent = 0` server as well as a `persistent = 1` one; a connected headless client does not count as a player.
- [ ] Add the reconciliation pass. Verify: saving with a WARCOM wave live and reloading returns roughly the AP that wave cost, and saving twice in a row without playing does not inflate either pool.
- [ ] Add the fork screen and its timeout. Verify: the screen is the first thing a game master sees on every campaign, singleplayer included; Load Game lists every saved campaign newest first, labelled with world, day, zones and CP; an unloadable save is listed disabled with its reason rather than hidden; New Game runs the old setup flow untouched and leaves existing campaigns intact; delete removes exactly one campaign; a dedicated server with nobody connected loads without waiting out the full bound; a fresh campaign is not made to wait on the screen before the terrain survey starts; a campaign that was won or lost is listed as ended and is not what the timeout picks up.
- [ ] Version, world and faction guards: refuse a snapshot from a different map or format version, or one naming a faction this session cannot detect, and say which on the control.
- [ ] Add export and import. Verify: a campaign carried in a client's own profile restores on a different server with nothing pasted; a hand-edited carried snapshot is refused rather than loaded; the clipboard fallback round-trips, and an oversized snapshot either survives the edit control or is chunked.
- [ ] On a dedicated server ([`info/testing.md`](../info/architecture/testing.md#running-a-dedicated-server)): play, restart, confirm the campaign continues. This cannot be validated by a hosted session — a host is both server and client and will mask locality faults.

## Decided trade-offs

**A restore is a fresh world with an old ledger.** Enemy garrisons, side missions and support in
flight are all lost. A player who restarts mid-firefight reappears with the zone unclaimed and the
garrison regenerated. Persisting the fight itself is a different and much larger project.

**The fork screen shows even when there is nothing to load.** It costs a click on every fresh
campaign. It buys a control players know exists, the only sensible home for import, and one code
path instead of a screen that appears conditionally — and the alternative, loading by default and
asking only for confirmation, hides the decision behind a button whose meaning changes between
sessions.

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
server no longer simulates a living war between sessions, which some hosts will want; the answer
to them is an offline-progression mechanic built deliberately, not this gate left open.

**The save container is Antistasi's, not a new design.** Its shape has been through several format
migrations in production on dedicated servers, and the parts of it this plan declines — the dual
namespace keying, the per-variable namespace writes, the legacy name fallbacks — are back-compat
for saves already in the wild rather than design. What is adopted and what is dropped:
[`campaign_save_format.md`](../info/architecture/campaign_save_format.md).

**Vehicles persist by data, so they come back as new objects.** Anything attached to the old
object is lost. The alternative is persisting object identity, which vanilla cannot do.

## Open questions

- Whether the edit control survives a full-size snapshot on import, and at what size chunking
  becomes necessary. It bounds the clipboard fallback only — the carry route never builds the string
  — and it cannot be settled on paper.
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
  is the decided behaviour; whether a migration path is ever worth writing is not decided. The
  datapoint against refusing is that a quarter of Antistasi's save subsystem is converters, carried
  because refusing means every player loses their campaign on update day.
- What an offline-progression mechanic would actually advance, and how the returning player is
  told. Idling is the floor; the elapsed time is derivable from the write stamp whenever this is
  taken up.
- What the reconciliation pass is worth per unit type. A flat per-unit figure scaled by health is
  the opening shape, and whether infantry and armour want different treatment is a tuning question
  a play-test answers.
