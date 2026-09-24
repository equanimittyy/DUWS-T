# Campaign persistence: implementation plan

Make a campaign survive the session it was played in. The mission writes a data-only snapshot to
an external store and, on the next start, rebuilds the world by feeding that snapshot back through
the **existing** builders rather than through a second construction path.

Live units are not persisted. Zones, the HQ and FOBs are rebuilt and re-garrisoned from scratch;
what carries over is campaign state — pools, zone ownership, placement, reputation, unlocks, and the
vehicles the team put in the garage.

Two rules govern everything below, the features that are not built yet included.

**A thing is persistable when a single function can build it from numbers and strings.** Zones
already satisfy it (`zone_meta_array` is exactly the argument list of `fnc_createZone`); FOBs nearly
do; player fortifications will only if they are designed that way from the start
([§Features not built yet](#features-not-built-yet)), and the enemy commander's state carries the
same contract into [`opcom_plan.md`](opcom/opcom_plan.md#persistence-phase-6).

**Only what outlives a session is stored.** Long-term campaign progress earns a key; a session's own
bookkeeping does not, however easy it would be to serialise. That is why the snapshot holds the
reveal state and the team's permanent unlocks and holds nothing keyed to a player — no loadouts, no
cooldowns, no unconverted kill tally. A player rejoins a restored campaign the way they join a fresh
one.

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
(`server/server_init.sqf:322`). That handler also has to identify the last player rather than count
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
than an unlock, and `client/client_init.sqf:383` grants it to the singleplayer player as well as
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
`enableSaving [false, false]` (`server/server_init.sqf:196`) removes the engine autosave *and* the
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
spawning waves, the side-mission generator keeps rolling and expiring missions, and the
[OPCOM](opcom/opcom_plan.md#what-ap-buys) keeps buying garrisons and hardpoints against a player who is
asleep.

**Decided: the campaign idles at zero players.** A player who logs off overnight and returns to a
poorer wallet and a fully upgraded enemy has lost ground by not playing, which is not a mechanic
anyone chose — OPCOM spending an unattended night buying garrisons is the sharp
edge of it. The server also burns CPU simulating a war nobody is watching. The gate goes on the
campaign clocks — the economy tick, the WARCOM wave threads, the side-mission generator, the
OPCOM tick — not on everything. The zone spawn/despawn checker and the JIP
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
carries a monitor that clears future stamps off player objects (`server/server_init.sqf:441-468`);
that stays as the backstop, and nothing new should need it.

## What the current save does not cover

| Problem | Where |
|---|---|
| The only save is vanilla `saveGame`, reached from one place: the SITREP support | `server/persistence/fnc_autoSave.sqf:11`, sole caller `server/supports/fnc_sitrep_support.sqf` |
| Engine autosave and the save menu are switched off at boot | `server/server_init.sqf:196` |
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
| The setup-screen gates block on globals a *client* publishes | `server/server_init.sqf:161,166` | A restore has no player at those screens, so boot never gets past them |
| The locator `spawn`s `fnc_createZone` per zone, so builds finish out of order | `server/init_zones/fnc_locatorzones_random.sqf:181` | Registration order is not zone order, so anything keyed by array position is keyed to the wrong zone. `zone_meta_array` carries `_zone_num` for this reason |
| `fnc_fob_server` rolls a fresh name and announces the FOB over radio behind a 5 s sleep | `server/supports/fnc_fob_server.sqf:7,20-24` | Replaying it renames every FOB and queues one callout per FOB at boot |
| Zone names are drawn at random from a pool that records what it has spent | `server/init_zones/fnc_zone_state_init.sqf`, `fnc_createzone.sqf` | Replaying the builder renames every zone on the map. The names *and* the used list have to be restored, and the builder must not re-draw |
| Campaign settings are set *and* broadcast by a client | `client/dialog/fnc_process_campaign_menu.sqf:480-515`, `fnc_process_enviro_menu.sqf:88-194` | A restore that only assigns them server-side leaves every client on defaults |
| Arsenal contents are resolved at boot from whatever mods are loaded | `server/arsenal/fnc_create_ammo_lists.sqf` | Storing the resolved classnames pins the campaign to that mod set |
| Hardpoints are sited in a generation phase after zone build-out and stored in `DUWS_hardpoints` ([`info/hardpoints.md`](../info/gameplay/hardpoints.md#siting)) | `server/warcom/fnc_init_OPFOR_WARCOM.sqf:52-96` | Replaying generation re-rolls every hardpoint position and orphans its cleared state |
| `fnc_opcom_belief_init` assigns `DUWS_opcom_tick` 0 and `DUWS_opcom_hqKnown` false at boot | `server/warcom/opcom/belief/fnc_opcom_belief_init.sqf:12,14` | Every commit hold, staleness stamp and gun cooldown is a count against that tick, so a restored clock reset to 0 holds units for hours and hides an HQ the commander had found |
| A tasking's `grp` is a live group's netId, and the ferry binds a carry by tasking id | `server/warcom/opcom/taskings/fnc_opcom_tasking_init.sqf` | Restoring a record unchanged points it at a group that no longer exists, and a carry bound at the write holds a rider that was never spawned |

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
| Mission params | input | the gameplay lobby params of `params_modern.hpp`, applied over the lobby's own picks |
| Callsign | input | `duws_callsign` |
| Faction list edits | input | `DUWS_factionListEdits`: the player's main, added and dropped classes per edited vehicle role ([`faction_system.md`](../info/gameplay/faction_system.md#the-confirmation-screen)) |

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
`simple_zones_enable`, `enable_fast_travel`, `ZeusStatus`. A single array of
those names, held in one place, is what both the save and the re-broadcast iterate. Listing them
individually in two functions guarantees that the next setting added is saved in one and not the
other.

**The settings group has to be re-broadcast, not just assigned.** Those globals are normally set
*and* `publicVariable`'d by a client, and restore skips those screens entirely.

**The mission params are campaign rules, so the snapshot outranks the lobby.** `Params`
(`shared/includes/params_modern.hpp`) is picked per session, so the same campaign reloaded on another
server, or in a lobby somebody re-configured, changes the rules a player has been playing under for
hours. The arsenal is the sharpest case: a campaign saved with every class count-tracked comes back
unlimited, and the pool it was spending against stops meaning anything
([§The arsenal](#the-arsenal-the-shelf-is-rebuilt-the-pool-is-stored)). The saved value therefore wins
for the arsenal mode and ammo tracking, revive, fatigue, the first-person restriction, rest weather,
the lose conditions and bandits.

**Five params stay the host's.** `DUWS_Debug`, `DUWS_LogLevel`, `DUWS_GroupIcons`,
`DUWS_CleanupLifetime` and `DUWS_AutosaveInterval` say how a server is being run, not what the
campaign is, and a carried snapshot must not put an admin's old logging level or write cadence back.

**A param is overridable only where it is read once.** `BIS_fnc_getParamValue` always answers from the
lobby, so a call site that asks it directly cannot be overridden at all: the arsenal shelf re-reads its
mode on every open (`client/arsenal/fnc_duws_Arsenal.sqf:8`,
`client/arsenal/fnc_quick_kits_menu.sqf:32`). Each saved param resolves once into one global, the way
`DUWS_arsenalLimited` and `DUWS_trackAmmo` already do (`server/server_var_init.sqf:65-66`); every call
site reads that global, and restore assigns and re-broadcasts them with the settings group.

`game_master` and `Squad_Leaders` are deliberately **not** in the group. They are a server's
permission policy (`server/server_var_init.sqf`), and an admin who trims them between sessions
must not have a snapshot put the old list back.

### World and placement

| Group | Kind | Contents |
|---|---|---|
| Placement | input | `PosOfBLUHQ`, `AO_direction`, `serv_zones_array`, `zone_meta_array` |
| Player build | input | `Array_of_FOBpos`, `Array_of_FOBname` |
| Commanding officer | outcome | whether `hq_blu1` is alive |
| Civilians | input | town positions, names, radii and populations |
| Vendors | input | `DUWS_vendors`: per town slot, the shop's type, position, facing and remaining respawn seconds |
| Clock | outcome | `date`, `DUWS_timeSkew` |

**The campaign clock is stored because boot sets it unconditionally.**
`server/server_init.sqf:268` calls `setDate [2035, 8, 3, time_of_day, 0]`, so without this every
restore snaps back to the third day at the hour the campaign was configured with, and a night
operation resumes at noon. It is gameplay state rather than presentation:
`server/events/fnc_night_horde_event.sqf:33` counts days off `date`, and the load screen labels each
row with one. It is an outcome because it has to be re-applied after the boot `setDate` (`:268`)
rather than before the builders — the boot line would overwrite it. `DUWS_timeSkew` (seconds a rest
has skipped, the campaign clock's offset over engine `time` — see `fnc_campaign_now`) rides in the
same group: a plain serializable scalar, stored and re-applied beside `date`, exempt from the
remaining-duration rule because it is not derived from `time`/`diag_tickTime`.

**A dead officer has to stay dead, and only one lose condition makes that interesting.** Under Full
or Officer-only, the officer's death ends the campaign and the snapshot header carries that ending
([§A campaign that has ended](#when-the-save-is-written-and-what-happens-with-nobody-on)). Under
Escalation-only or Off the campaign continues and the loss is permanent: the request menu refuses to
open while `hq_blu1` is dead (`client/dialog/fnc_request_menu.sqf:19-20`), so the players spend the
rest of the campaign unable to buy anything. `fnc_bluHQinit` rebuilds the HQ deterministically and
spawns the officer alive, which is why one position persists the whole base — and why the flag is an
outcome applied after it. Without it a reload hands the players their request menu back and erases
the worst thing that can happen to them short of losing.

**A destroyed FOB does not come back, and the registries already know it.** Both removal paths, the
player's dialog and the destruction watcher, funnel through `fnc_fob_deregister`
(`server/init_hq/fnc_fob_deregister.sqf`), which drops the position and the name in lockstep with
`Array_of_FOBS`. What is saved is therefore the FOBs standing at the write, and replay calls
`fnc_fob_server` per entry rather than rebuilding what it places. Nothing player-scoped rides along:
the owner passed at build time is never read (`shared/functions/fnc_FOBactions.sqf:8`), and a FOB's
garrison and its defences are live state the site streamer regenerates.

**Zone names have to be stored.** They are drawn, not derived: `fnc_zone_name` hands out a
phonetic-alphabet word at random and records which are spent, so nothing about a zone's index or
position reproduces the name it was given. A restore that re-ran the allocator would rename every
zone on the map, and the player's own notes and any dialogue they remember would stop matching the
ground. Storing the string costs nothing in translation, which was the old objection: these words
carry no stringtable key and are the same in every language. The used-name list is restored with
them, or the allocator would hand a second zone a name already on the map.

**The vendor draft is drawn, not derived, so it is stored like the zone names.**
`fnc_vendor_init` picks each town's shop types by weighted roll, each shop's spot from that
building's positions and each facing from the town centre, and it already treats the result as the
campaign's fixed answer: its own header says a town's shops have to stand in the same place after a
save and restore, and a killed shop's countdown is held as remaining seconds for that reason
(`server/vendors/fnc_vendor_init.sqf:170-173`). Re-running the draft would move every shop in every
town. The registry is keyed by town index, so it restores beside the town list and in the same order
the towns do; that order is the snapshot's, which is what makes the index stable across a restore
when `civ_locations` is not.

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
(`server/warcom/fnc_escalation.sqf:55-70`), so one stored integer reproduces the level, the
multiplier and the loss condition together.

### The enemy

| Group | Kind | Contents |
|---|---|---|
| Town garrisons | outcome | purchased tier per town (`DUWS_townGarrisonTier`) and whose it is (`DUWS_townGarrisonOwner`) |
| Zone garrisons | outcome | purchased tier per zone (`DUWS_zoneTier_<key>`) |
| Garrison strength | outcome | per site, `DUWS_garrisonFull_<key>` and `DUWS_garrisonLost_<key>` — the full token multiset and the lost ledger against it |
| Hardpoints | input | `DUWS_hardpoints`, one row per standing emplacement: `[key, pos, type, side, zoneKey, shown, dir]` |

Hardpoints are an input for the same reason zones are:
[`info/hardpoints.md`](../info/gameplay/hardpoints.md#siting) sites them in a generation phase after zone
build-out, so the siting pass has to accept a restored `DUWS_hardpoints` registry instead of rolling
fresh positions, or a restore moves every hardpoint and orphans its cleared state. Zone-ring and
standalone hardpoints run in that one phase and share the one registry, so a single guard covers
both. Cores and garrison groups are live objects rebuilt on approach from the stored composition,
so they stay out of the save.

**The registry is the whole hardpoint state, because presence is liveness.** A cleared hardpoint is
deleted from `DUWS_hardpoints` rather than flagged
(`server/init_zones/fnc_hardpoint_stream.sqf:185-189`), so what was cleared needs no key of its own —
it is what the saved array does not hold. Reveal rides the row's `shown` field, whose sole writer is
`fnc_hardpoint_reveal`, keyed by the row's own key, which is why the hardpoint half of reveal is not
in [§The team](#the-team): restoring the rows restores it, provided the siting pass takes them
whole rather than rebuilding rows around the saved positions. Facing rides the row too, so a restored
emplacement points where it pointed.

The per-key variables beside the registry are session state and stay out. `DUWS_hpPeak_<key>` is
re-anchored every time a hardpoint raises and cleared when it stows, and `DUWS_hpMines_<key>`,
`DUWS_hpMineSquares_<key>` and `DUWS_hpMineLaid_<key>` are made and unmade with the mines a streamed
belt lays. A restored minefield lays its belt again on the next raise, which is the same path a fresh
campaign takes. What the snapshot does carry for them is the variant, because the registry row does
not name it ([§The commander](#the-commander)).

Town garrison tier is stored because the store already exists: `DUWS_townGarrisonTier` is written the
moment a town crosses `-10` into the OPFOR band, independently of the commander
([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv)), so a restore
that dropped it would repair every turned town back to ungarrisoned. Its owner rides with it for the
same reason: a tier and the side it belongs to are one fact, and a restored tier read as the wrong
side's would hand one army the other's men.

**A tier is not only the enemy's any more.** Both sides garrison ground they hold, so a zone's tier is
outcome the same way a town's is — it is bought, and a restore that dropped it would take back every
garrison the player paid for.

**Strength is stored beside the tier, because the two answer different questions.** A tier is what a
site fields at full; strength is how much of that is still standing. Attrition is a ledger of lost
whole tokens rather than a thinned scalar — destroy one tank and the site comes back missing one tank
(`server/garrison/fnc_garrison_strength_init.sqf`,
[`garrison_and_reserves.md`](../info/gameplay/garrison_and_reserves.md)) — so a restore that dropped it
either repairs every mauled garrison for free, wiping the attrition the players fought for, or zeroes
one, handing them ground nobody took. Reinforce buys strength back on both sides, which makes it paid
progress on the same footing as the tier.

Both are flat token lists keyed `zone_<x>_<y>` or `town_<n>`, and a token is a composition name rather
than a classname, so the group serialises as strings and pins to no mod set. Everything else derives
from the pair on read: which side holds the site, which tokens sit behind an unearned Army Power rung,
and what is surviving (full less lost). They are outcomes and go in after the builders, because a raise
stamps `full` and a seed clears `lost`, and both are keyed by a site key that has to exist first.

### The commander

OPCOM is shipped, so its store is snapshot content now rather than deferred. These are the keys the
snapshot carries for it, and the contract they answer to is this section's; the phase that lands them is
[`opcom_plan.md` §Persistence](opcom/opcom_plan.md#persistence-phase-6).

| Group | Kind | Contents |
|---|---|---|
| Archetype | input | `DUWS_opcom_archetype`, fed back before the loop and never re-rolled |
| Taskings | outcome | `DUWS_opcom_taskings`, one hashmap per unit, with `DUWS_opcom_taskSeq` beside it |
| Clock and flags | outcome | `DUWS_opcom_tick` and `DUWS_opcom_hqKnown` |
| Mine variants | outcome | `DUWS_opcom_mineVariants`, with `DUWS_hpOpcomSeq` beside it |
| Intents | outcome | the commander's live intent records and the `boundTo` key on the taskings they own, once orchestration lands |

**A tasking is already serialisable, and that is deliberate.** A record holds numbers, strings and arrays
only, and `grp` is a live group's netId rather than a handle
(`server/warcom/opcom/taskings/fnc_opcom_tasking_init.sqf`). What a restore has to clear is the live half:
`grp` back to `""`, `status` to `virtual`, and `carrying`, `ridingOn` and `embarked` reset. The groups those
bound are gone, and a half-bound carry would hold its rider for the rest of the campaign, since a bound
record refuses every new order.

**Intents land with orchestration, and they change nothing here.** An intent is the record that binds
several units to one action, and its roles name their units by tasking id rather than by handle
([`opcom_plan.md` §Commitment](opcom/opcom_plan.md#commitment-intents-are-sticky)). It therefore
serialises on the taskings' own terms and restores with them, which is why that phase is built before
this one rather than after: a contract written first would be reopened the moment intents existed.

**`DUWS_opcom_taskSeq` rides with the taskings.** The id is what every binding uses — a ferry pairs a
transport to its rider by id, not by handle — so a counter restored to 0 hands the next hire an id a
standing unit already holds.

**The tick is the clock every stored time counts against.** A commit `hold`, the staleness layer and a gun's
cooldown are all tick counts, so `fnc_opcom_belief_init` must initialise `DUWS_opcom_tick` and
`DUWS_opcom_hqKnown` only when they are nil. It assigns both unconditionally today, which resets a restored
campaign's clock and re-hides an HQ the commander had already found.

**A minefield's variant lives outside the hardpoint registry.** `DUWS_opcom_mineVariants` maps a build key to
`AT` or `AP` because the registry row carries no variant, and the build mix weighs the two apart, so a restore
without it lays the wrong mix for the rest of the campaign. `DUWS_hpOpcomSeq` is the key counter behind those
keys and collides the same way `taskSeq` does.

**A saved `spawnClass` is a hull, not a contract.** It is stored because `DUWS_fnc_tokenClass` redraws a
random model per spawn, so a restored vehicle would otherwise swap hulls. A class the loaded mods no longer
define is rerolled from its token with a WARN, and a token the current faction cannot field at all drops the
unit — the faction rule of [§Decided trade-offs](#decided-trade-offs) applied one unit at a time.

**Belief is not saved, and neither is the influence grid.** Belief is keyed by group netId, which resolves to
nothing after a restart, and a restart also loses the headless clients and returns players to HQ, so the
sightings would describe a battlefield that no longer exists. The grid layers, the coverage layer and the
contested set rebuild on the first sensor pass, and the traffic layer refills as sightings land.

**The commander's mode and pick rate are not its state.** `DUWS_opcom_aiMode` and `DUWS_opcom_picksPerTick`
belong to the debug page today and come back at their defaults. Once the difficulty setting drives them they
restore with the settings group, not here.

### The team

| Group | Kind | Contents |
|---|---|---|
| Support unlocks | input | `DUWS_support_permanent`, the team's permanent unlocks in purchase order |
| Reveal | outcome | positions of revealed zones and revealed towns |

**Nothing per-player is saved.** No loadouts, no per-player cooldowns, and no per-player record of
what a player bought. Consumable unlocks were already out for exactly this reason — they are
per-player and are lost on death, so a restart costs no more than a firefight does — and the rest
follows the same rule: a player rejoins a restored campaign and kits out from the arsenal, which the
restore rebuilds anyway. It also keeps the whole UID-keyed player-save machinery out of the design:
the per-player "restored yet" flag, stripping a loadout saved while dead, and the bank-then-delete
order in
[`campaign_save_format.md`](../info/architecture/campaign_save_format.md#per-player-data) are all
unbuilt here.

**Permanent unlocks are team state, so one array carries them.** `DUWS_support_permanent` holds them
in purchase order and each client keeps the individual flags as its fast path, so restore replays the
array into the flags (Prerequisite 3). The garage's capacity ladder reads those same flags, so its
pools come back the size the team paid for.

**Replaying the flags is not enough on its own.** `DUWS_bluforRadioLevel` is counted off the unlock
array when a support is granted (`server/supports/fnc_support_perm_grant.sqf:19`), and nothing
recounts it afterwards, so a restore that only sets the flags leaves a team holding its radio unlocks
with no radio reach. Restore recounts it from the restored array. The OPFOR twin needs no rule:
`fnc_hardpoint_stream.sqf:21` recounts it from `DUWS_hardpoints`, which the snapshot restores.

**Reveal is an outcome, not an input.** A hardcore campaign's entire progress is which zones and
towns the player has found, and a replay re-hides both: `fnc_createzone.sqf:16` sets every zone's
visibility from `hardcore_mode_enable`, and `fnc_civ_init_Tomata` hides every town outside the HQ
anchor's opening quota. Store the positions of both, then re-flag the matching `zone_namePOS_pairs`
and `civ_visible` entries and repaint their markers after build-out — the same shape and the same
reason as Ownership.

Storing the state rather than how it was reached is what keeps this to a flat list of positions: a
zone the player walked into, bought from a local, or found on a dead officer all restore
identically, because by then they are one flag. A hardpoint's reveal is the same kind of state —
intel can uncover one without its parent zone — but it is not stored here: it is a field on the
hardpoint's own registry row and comes back with it ([§The enemy](#the-enemy)). Details in
[`info/intel_system.md`](../info/gameplay/intel_system.md#persistence).

**Reveal is team state today and stays that way.** `zone_namePOS_pairs` and `civ_visible` are
shared arrays and the markers they drive are global, so there is no per-player reveal to persist.
Making reveal personal is a design change to the intel system, not a persistence feature, and it
would mean per-player markers everywhere.

### The arsenal: the shelf is rebuilt, the pool is stored

Faction init rebuilds the friendly class list from scratch
(`server/arsenal/fnc_create_ammo_lists.sqf`), so a restore re-resolves it against whatever mods are
loaded now. Storing those classnames would pin the campaign to the mod set that produced them, which
is exactly what the no-hard-dependency rule exists to avoid. The list therefore stays out of the
snapshot in every arsenal mode.

The **captured-materiel pool** (`DUWS_capturedPool`, written by the `fnc_captured_pool_*` functions in
`server/warcom/fnc_economy_init.sqf`) is the opposite case, and is the one arsenal state that is
persisted. It is player-earned and scarce, so losing it on reload loses progress, the same argument
that puts the garage in the snapshot rather than the friendly cargo. Like the garage it is data, one
`class -> count` map, and like it, it pins to the mod that produced the classnames: a removed enemy
mod drops those entries, so restore validates each class and discards the unknown rather than
restoring a name that resolves to nothing. It joins the snapshot as one key.

**What the pool means depends on the arsenal mode,** which is why that param is in the settings group
([§Identity and settings](#identity-and-settings)) rather than left to the lobby.

| `DUWS_ArsenalMode` | The shelf | The pool holds |
|---|---|---|
| Hybrid (default) | the player's own faction unlimited, foreign gear count-tracked | the enemy gear the player banked |
| Full | everything unlimited | nothing reads it, so it restores inert |
| Limited | every class count-tracked, no unlimited floor | the whole arsenal, friendly classes included |

**In Limited the friendly counts are campaign progress, not a starting stock.** Boot seeds every class
of `DUWS_friendlyArsenal` into the pool at `DUWS_limitedSeed` (`fnc_create_ammo_lists.sqf:59-61`), and
`fnc_captured_pool_setCount` overwrites a class outright rather than filling a gap
(`fnc_economy_init.sqf:437-447`), so a seed that runs over a restored pool resets a whole campaign's
spend-down to full stock. The seed therefore covers only the classes the pool does not already name.
That rule needs no restore branch — on a fresh campaign the pool is empty and every class is seeded —
and it is also what a mod added between sessions needs, since its classes have no saved count to come
back to. `fnc_buildQuickKits.sqf:123` and `fnc_scanCivilianGear.sqf:94` already seed newly discovered
classes alone.

**Ammo tracking rides with the mode.** `DUWS_TrackAmmo` decides whether magazines are pooled at all,
so a campaign reloaded with it flipped either finds its magazine counts meaningless or starts counting
rounds it never counted. It is in the settings group for the reason the mode is.

## Vehicles: the garage

Vehicles persist because the garage already turns them into data. `DUWS_garage_stored` is an array of
specs written by `fnc_garage_store` and read back by the depot's retrieve path
(`server/supports/fnc_garage_init.sqf`, `shared/functions/fnc_garage_spec.sqf`), and a spec is exactly
what this plan asks of everything else: one class string plus numbers and arrays, captured by
`DUWS_fnc_vehSpecCapture` and re-applied by `DUWS_fnc_vehSpecApply`. It joins the snapshot as one key
that restore assigns and broadcasts. There is nothing to collect and nothing to respawn, because a
stored vehicle is not an object until a player retrieves it.

| Group | Kind | Contents |
|---|---|---|
| Garage | outcome | `DUWS_garage_stored`: per vehicle its class, textures, pylon loadout, per-hitpoint and overall damage, fuel, the four cargo lists and one ammo fraction |
| MHQ | outcome | the designated vehicle's spec, whether it was deployed, and where |

**A vehicle parked in the world is not saved; a garaged one is.** That is the trade, and it is the
right one. The capture and apply pair is already written and is exercised every time a player uses the
depot, and the garage's own capacity ladder bounds it, so persistence needs no radius constant, no
per-anchor cap, no cull, and no filter to keep a FOB's turret ring out of a collection sweep. What it
costs is a habit: a player who wants a vehicle to survive a restart garages it first.

**The garage's capacity is a permanent support, so the caps restore with the unlocks.**
`DUWS_fnc_garageCaps` reads the highest owned level's row off `DUWS_garage_tiers`, and ownership is a
support flag ([§The team](#the-team)). A snapshot holding more vehicles than the restored caps allow is
over capacity rather than invalid: restore keeps them all and the depot refuses the next store until
the team is back under.

**The MHQ needs its own record.** `MHQ1` is whatever vehicle a player designated through the comm menu
(`client/dialog/fnc_MHQ_select.sqf:20-22`), and it stands in the world rather than in the garage, so
nothing else carries it. Store its spec beside its deployed state and position. Restore spawns it,
re-applies the designation and — if it was deployed — replays `fnc_MHQ_deploy`, which rebuilds the
tent, the ammo box and the respawn point rather than persisting any of them.

**Crews are never stored, and a retrieved vehicle is a new object.** Anything attached to the old one
goes: R3F-carried cargo, player-placed objects riding on it, and any per-object variable a subsystem
set without a registry behind it. Zones and FOBs pay the same price.

## Features not built yet


Three planned features are cheap to persist if they are built as registries and expensive if they
are not. The contract is the same for all three: **the builder takes data and the registry holds
that data.** Persistence is then a replay, and there is nothing extra to write.

**Player-built fortifications and BLUFOR hardpoints.** Build them through one function taking
`[type, position, direction]` and keep a parallel registry of exactly those tuples, on the model of
the hardpoint arrays. Built the other way — the player places an object and persistence serialises
the object — restore has to reverse-engineer what was built from what is standing, and every new
buildable is a new special case.

**Civilian vendors.** The vendor registry
([`civilian_shops.md`](../info/gameplay/civilian_shops.md#vendor-registry)) holds, per town, each
vendor's type, building, facing and respawn cooldown. It is an input: restore replays it in place of
the init-time roll, so every town keeps the same vendors in the same buildings. The building goes in
by position on the same footing as towns: a terrain building does not move, so the nearest building
to the stored position is the same one. Shop money has no entry and is lost: it is the carried
`Money_roll` item, and no player gear is saved ([§The team](#the-team)). Whether a player's cash wants a
team-level or per-player key of its own is the vendor work's question, not this plan's.

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

**The fork goes at the head of the existing chain, not inside it.** Setup runs as one chain on the
game master's machine today (`client/client_init.sqf:84-98`):

1. `fnc_startup_faction_flow` — faction pick, the custom-faction paste, the confirmation, then HQ
   placement
2. the environment menu
3. the campaign menu
4. the callsign screen, which sets `chosen_settings` and releases the server

The fork becomes step 0. New Game runs 1 to 4 exactly as they run now. Load runs none of them: the
early server gate has already published the placement and settings inputs and pre-satisfied the flags
those screens would have set, so there is nothing left for them to ask. Siting it ahead of the chain
rather than inside it is what keeps New Game untouched — a fork at step 2 or 3 would have to unwind
choices the player had already made.

**Back from the first setup screen returns to the fork.** The chain already treats Back as re-entry:
the paste window and the confirmation both restart `fnc_startup_faction_flow`
(`client/dialog/fnc_startup_faction_flow.sqf`), and the environment screen routes back into it. The
fork is one more link at the head, so the first screen's Back opens it instead of dead-ending, and a
player who picked New Game by accident is one keypress from the list of their campaigns. The faction
screen's dev-only quickstart button is unaffected: it sits inside the New Game branch, so it is
reached only once the fork has been answered, and it skips the rest of the chain as it does today.

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

### Telling the player what did not load

Three failures reach the player, at three different moments, because that is when each one is
discovered.

**The store not reading back is not an empty list.** The scan publishes a status beside the summary —
saves found, none found, or the store unreadable — because the screen renders the last two
identically otherwise, and a player told "no saves" starts a new campaign over the one they have.
Unreadable is also the one case that has to warn on the New Game path: the namespace that will not
read back is the namespace this session's saves are written to, so the fork says so before the player
spends an evening on a campaign nothing will keep. That is the dedicated-server failure
[Prerequisite 1](#prerequisites) exists to rule out, and it needs a name in the interface rather than
in the log alone.

**A snapshot missing keys loads only when the missing keys are outcomes.** An absent input group is
fatal: placement, zones and hardpoints are what the builders replay, and a builder handed nothing
rolls fresh ground, which is a different campaign wearing the same name. That row is disabled with
the missing group named, like any other validation failure. An absent outcome group is a degraded
load rather than a refusal — the campaign returns with those pools, flags or ledgers at their boot
values — so the row stays selectable and the screen names the gap before the player commits to it.

**What only the restore can discover is reported once it has run.** A classname a removed mod
defined, a token the current faction cannot field, a town position that no longer resolves to a
Location: each is handled per case already — reroll, drop the unit, discard the entry — and each
writes a WARN. What is missing is the player's half. Restore counts what it dropped and reports those
counts once, so a campaign that came back three vehicles and a squad short says so rather than
leaving the player to find out at the motor pool. The surface is a `hint`, not a notification card:
the card clips at about 60 characters and a line of counts does not fit, and the style guide takes
one surface per message rather than both
([`player_text_style_guide.md`](../info/gameplay/player_text_style_guide.md#notification-card-dialogue-and-the-hint-box)).
The log keeps the detail; the hint keeps the number.

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
`HQ_pos_found_generated && chosen_settings` (`client/client_init.sqf:114-123`) and need no knowledge
of the screen at all — a load satisfies both flags the same way a finished setup does.

### Hooks, in boot order

**An early gate in `server_init.sqf`, between `:8` and `:13`.** After `server_var_init` so a snapshot
overwrites the defaults, before the terrain survey so the survey can be skipped. It has to sit this
early because the setup gates at `:161,166` block on globals a *client* publishes. Because the answer
now comes from a player, the gate is three steps rather than one:

1. **Scan.** Read the key, validate version and world, publish the summary the load screen labels
   its Load control with, and a status beside it — saves found, none found, or the store unreadable
   ([§Telling the player](#telling-the-player-what-did-not-load)). An absent or invalid snapshot
   publishes an *empty* summary rather than nothing at all: the client waits on this variable, and a
   variable that is never set is indistinguishable from a server still working.
2. **Wait — but only when there is something to load.** On an empty summary the gate returns
   immediately and boot proceeds exactly as today. That is not a micro-optimisation:
   `fnc_moreUrban_locations` is `spawn`ed at `:13` and has been recorded taking 140 s, and today it
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

**The fork lives inside the existing game-master block** (`client/client_init.sqf:84-98`), with that
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
| `server/server_var_init.sqf` (`server_init.sqf:8`) | Runs, then the snapshot overwrites |
| `fnc_moreUrban_locations` (`:13`) | **Skipped** — a terrain scan recorded taking 140 s, and placement is already decided |
| Setup gates, `chosen_hq_placement` / `createzone_server` (`:161,166`) | Pre-satisfied by the gate |
| Faction init (`:60-156`) | Runs — classnames must be re-resolved against whatever mods are loaded now. Then `fnc_faction_edits_apply` applies the saved faction list edits over the new pools. The restore has to publish the result itself: the loop that broadcasts every schema key and the request-menu catalogue is the setup loop this gate skips, and no faction file runs on a client to fill the gap |
| `fnc_create_ammo_lists` (`:189`) | Runs — the friendly class list re-resolves against the loaded mods. In Limited its pool seed covers only the classes the restored pool does not name ([§The arsenal](#the-arsenal-the-shelf-is-rebuilt-the-pool-is-stored)) |
| `fnc_bluHQinit` (`:192`) | Runs, from the saved `PosOfBLUHQ`. It rebuilds the whole HQ deterministically, which is why persisting one position is enough. The officer spawns alive, so a saved officer death applies after this step |
| `fnc_init_OPFOR_WARCOM` (`:205`) | Runs, with the locator bypassed as above |
| `fnc_escalation` (`fnc_init_OPFOR_WARCOM.sqf:63`) | Runs the census, then the snapshot restores `escalation_destroyed` |
| `fnc_intro_heli` (`:433`) | **Skipped** |

FOBs restore the same way: call `fnc_fob_server` per saved position — silently, and with the saved
name — rather than reimplementing what it builds. Vehicles are spawned last, after every anchor is
standing.

## What is deliberately not saved

Live AI, spawned garrisons, active side missions, in-flight support, and the JIP task queue. Zone
garrisons and composition props both spawn and despawn on player distance
(`server/misc/fnc_site_stream_init.sqf`), so a restored campaign regenerates them the first time a
player approaches — the same code path a fresh campaign uses.

Player-scoped state goes with them: loadouts, per-player cooldowns, any per-player record of what a
player bought, and an unconverted kill tally. So does a vehicle left parked in the world rather than
garaged ([§Vehicles](#vehicles-the-garage)). The snapshot is keyed to no player at all.

Session-scoped locks go with them and must come back clear: the per-support fire-mission locks, the
per-FOB rebuild busy flags, `Mission_available`, and the JIP queue entries. A lock restored as held
is a support nobody can ever call again.

OPCOM's own units are the same shape: a tasking restores as data and streams to a live group on
approach, so the groups it had rendered at the write are not saved. A hardpoint still siting on a
delivered truck (`DUWS_opcom_buildsPending`) dies with its spawned builder, and the AP that bought it
is the reconciliation pass's to fold back ([§What live state costs](#what-live-state-costs-and-who-pays-it-back)).

Three counters reset with them and are meant to. `econ_tick` numbers the 30-minute payout and only
the server's payout caps read it. `WARCOM_opfor_lastIncome` holds OPFOR's last payout, which OPCOM
divides by the period to read an income rate, so a restored campaign sets no savings goal until its
first payout lands — what the commander does at the start of every campaign anyway
([`opcom_plan.md`](opcom/opcom_plan.md#gate-and-the-savings-goal)). `DUWS_lastMissionStartDate`
stamps the last side mission and gates the next one for three hours
(`shared/functions/fnc_mission_gate_left.sqf:15`), and it resets with the mission it was stamped for:
a restore drops live missions, so the wait goes with them rather than being served for a mission the
player no longer has.

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
a campaign of restarts that is a slow leak out of both economies, and the
[OPCOM](opcom/opcom_plan.md#what-ap-buys) buying continuously is what makes it a leak worth plugging.

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
| `server/persistence/fnc_autoSave.sqf` | Rewritten to call the new save; drop `saveGame`. Owns the interval loop and the no-overlap guard. |
| `server/supports/fnc_sitrep_support.sqf:13` | Nothing here for persistence — it already asks the server to save. Its price and cooldown are [`economy_second_pass.md`](economy_second_pass.md#sitrep-becomes-free)'s business. |
| `server/server_init.sqf` | Early gate before `:13` — scan, wait for the fork, apply; save triggers and the disconnect/end event handlers. Re-apply the saved date after `:268`. Keep `enableSaving [false,false]` at `:196`; the engine save is no longer the mechanism. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:8-16,54,97` | Branch to the restore path for zones; feed saved towns to civilian init; replay ownership and reveal after `WARCOM_init_done`. |
| `server/supports/fnc_fob_server.sqf:7,20-24` | Accept a name; the announcement is silenced by the router, not a flag here. |
| `client/chatter/fnc_duws_dialogue.sqf` | Suppress mode, so replayed builders announce nothing at boot. |
| `server/civilian/fnc_civ_init_Tomata.sqf:170` | Accept a restored town set in place of the `fnc_civ_selectTowns` roll. |
| `server/warcom/opcom/belief/fnc_opcom_belief_init.sqf:12,14` | Initialise `DUWS_opcom_tick` and `DUWS_opcom_hqKnown` only when they are nil, so a restored clock and a found HQ survive boot. |
| `server/warcom/opcom/appraisal/fnc_opcom_archetypes.sqf` | `DUWS_opcom_archetype` set from the restored snapshot on a load, in place of the campaign setting's roll. |
| `server/server_fnc_init.sqf` | Registry lines only. The manifest holds no bodies, so the support-unlock mirror writer and the settings name list land in a module beside their subsystem. |
| `client/client_init.sqf:84-98` | The New Game / Load Game fork at the top of the block, game master only; the existing faction flow moves into the New Game branch. |
| `shared/includes/params_modern.hpp` | `DUWS_AutosaveInterval`, seconds, `0` for off, default 900. |
| `server/server_var_init.sqf:65-66` | Every saved param resolved once into a global beside `DUWS_arsenalLimited` and `DUWS_trackAmmo`, and the name list restore iterates. |
| `client/arsenal/fnc_duws_Arsenal.sqf:8`, `client/arsenal/fnc_quick_kits_menu.sqf:32` | Read the resolved global instead of `BIS_fnc_getParamValue`, or the restored arsenal mode cannot reach the shelf. |
| `server/arsenal/fnc_create_ammo_lists.sqf:59-61` | Seed a friendly class only when the pool does not already name it, so a restored Limited campaign keeps its spend-down. |
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
- [ ] Add the garrison ledger: the purchased tier per zone and town, and the full and lost token multisets behind it. It follows zone and town replay, because every key is a site key. Verify: an OPFOR zone the players mauled but did not take comes back missing exactly what it lost rather than repaired to full; a cleared town comes back at tier I with nothing standing; a zone the players garrisoned comes back theirs at the tier they paid for; and a token behind an unearned rung stays unfielded rather than lost.
- [ ] Add HQ, FOB, vendor and civilian-town replay. Verify: HQ actions work, FOB triggers fire, FOB names and towns come back where they were, every town's shops come back the same types in the same doorways facing the same way and a shop killed before the save is still on its countdown, a FOB destroyed before the save stays gone, an officer killed under a non-terminal lose condition comes back dead with the request menu still refusing to open, and the restore replays no FOB radio announcements.
- [ ] Add OPCOM's state: the archetype, the taskings with `DUWS_opcom_taskSeq`, the tick and the HQ flag, and the mine variants with `DUWS_hpOpcomSeq`. It follows zone and ownership replay, because `homeZone` and `returnZone` are site keys and a restored garrison re-syncs into its zone's reserve pool. Verify: a restored garrison still fields its reserve token at its own zone; a unit saved mid-march comes back virtual at its saved point with its order and route, and streams to a live group at its saved strength on approach; a commit hold stamped just before the save has roughly its remaining ticks left rather than thousands; a minefield comes back as the variant it was laid as; and nothing in the restored store resolves a netId.
- [ ] Add the garage. Verify: `DUWS_garage_stored` round-trips; a retrieved vehicle comes back with its damage, fuel, cargo, paint, pylons and ammo fraction; a snapshot holding more than the restored caps allow keeps every vehicle and blocks the next store instead of dropping one.
- [ ] Add the mission params and the captured pool. The params land with the settings group, and the pool follows faction init because the Limited seed reads it. Verify: a Limited campaign reloaded in a lobby set to Hybrid comes back Limited; a friendly class the player spent down to 3 comes back at 3 rather than reseeded to `DUWS_limitedSeed`; a class added by a mod since the save is seeded rather than missing; a Hybrid campaign's banked foreign gear comes back at its counts; and the host's log level, debug flag, cleanup lifetime, group icons and autosave interval are the lobby's, not the snapshot's.
- [ ] Add the MHQ, which carries its own spec now that the garage does not hold it. Verify: a deployed MHQ comes back deployed where it stood, with a working respawn point and one ammo box.
- [ ] Add the reveal state and the permanent support unlocks. Verify: a hardcore campaign's revealed zones, towns and hardpoints come back revealed with their markers repainted; the unlock array replays into every client's flags and `DUWS_bluforRadioLevel` comes back counted rather than zero, a client that joins after the restore included; and the garage's capacity pools come back the size they were bought to.
- [ ] Add the autosave loop, its parameter and the other three triggers. Verify: changing `DUWS_AutosaveInterval` in the lobby changes the observed write cadence in the `.rpt`; two triggers firing together produce one write, not two; at `0` the loop never fires but SITREP and a clean exit still write.
- [ ] Add the zero-player gate. Verify: the campaign clocks stop with nobody connected and resume on join; a snapshot is written on the last disconnect, on a `persistent = 0` server as well as a `persistent = 1` one; a connected headless client does not count as a player.
- [ ] Add the reconciliation pass. Verify: saving with a WARCOM wave live and reloading returns roughly the AP that wave cost, and saving twice in a row without playing does not inflate either pool.
- [ ] Add the fork screen and its timeout. Verify: the screen is the first thing a game master sees on every campaign, singleplayer included; Load Game lists every saved campaign newest first, labelled with world, day, zones and CP; an unloadable save is listed disabled with its reason rather than hidden; New Game runs the old setup flow untouched and leaves existing campaigns intact; delete removes exactly one campaign; a dedicated server with nobody connected loads without waiting out the full bound; a fresh campaign is not made to wait on the screen before the terrain survey starts; a campaign that was won or lost is listed as ended and is not what the timeout picks up; a store that cannot be read back is reported as unreadable rather than as an empty list, and New Game warns before it starts; a snapshot missing an outcome group loads with that group named on the screen, and one missing an input group is disabled; and a restore that dropped classes or units says how many.
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
mission's no-hard-dependency rule refuses. The player's vehicle-list edits are the one exception: they
are stored as intent (main, added, dropped) and applied over the new detection, and a class the session
lacks is skipped, so the campaign never depends on the mod that supplied it
([`faction_system.md`](../info/gameplay/faction_system.md#the-confirmation-screen)).

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
- Where a player who wants to save *now* is sent. SITREP is that control today and it is a radio
  support, which is not where anyone looks after pressing Escape. Singleplayer feels this hardest.
- Whether a restored campaign should replay anything at all to the player — a one-line "campaign
  resumed, day N" — or come up silent. Silent is the default here because every builder is being
  suppressed anyway.
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
