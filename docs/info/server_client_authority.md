# Server/client authority

Shared campaign state — the CP, AP and reputation pools, the zone and FOB lists — lives in
networked globals that every machine keeps its own copy of. Correctness depends on exactly one
machine writing each of them. This doc covers the model, how locality is recorded in the
source, and what dedicated-server support additionally demands. The three economies and their
writers are in [`cp_economy.md`](cp_economy.md); for where subsystems live see
[`architecture.md`](architecture.md).

## The invariant

Every shared global has one writer, on the server, taking an *intent* rather than a resulting
value. Callers send the intent via `remoteExec [..., 2]` and never assign the global.
`publicVariable` broadcasts an absolute, so two machines that each read, modify and rebroadcast
a global drop one another's change — the failure mode is the gotchas entry *"A shared global
mutated as `x = x - c; publicVariable` loses concurrent writes"*
([`arma_engine_gotchas.md`](arma_engine_gotchas.md)). A delta cannot carry a stale base, and the
server applies each as one uninterruptible statement.

Five writers implement it, and they are the templates to copy. Three sit in
`server/misc/fnc_economy_init.sqf`: `fnc_cp_adjust` (signed numeric delta), `fnc_ap_adjust`
(delta plus a target-pool selector) and `fnc_town_rep_adjust` (delta plus ownership of
rounding, applied to one town). Two sit in `server/init_zones/fnc_zone_state_init.sqf`:
`fnc_warcom_set_primary_zone` (an operation on a shared list, matched by value so a stale
caller finds nothing rather than corrupting state), and `fnc_zone_control_set` (a whole
transition — a capture moves both side lists and both counters, and applying them together
keeps the four consistent with each other as well as individually atomic).

The two pools the player sees are floored at zero. That is not arithmetic tidiness: the
purchase gates all read *"can I afford this"*, so a negative pool behaves like an empty one
anyway, and the floor keeps the HUD honest.

A delta writer settles *who computes the new value*; it does not settle *who may spend*. Those
are separate problems and the second needs its own mechanism, because a client's affordability
test reads a snapshot the server has already moved past. `fnc_pool_spend` /
`fnc_pool_try_spend` are that mechanism — the buyer asks and blocks, the server tests and
debits in one breath and replies. The contract, the surviving advisory pre-filters and the
scheduled-caller requirement are in
[`cp_economy.md`](cp_economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

Where a function is *intended* to be server-only and its locality is not provable from the
code, assert it: `server/init_zones/fnc_captured.sqf` and its two peers open with
`if (!isServer) exitWith {}` because they are driven by a `createTrigger` whose evaluation
locality is not proven.

One hazard the invariant does **not** address: a direct `setVariable`-form write existed for
years without matching the `x = x + n` shape any grep for it would find. Auditing this by
pattern misses that idiom entirely.

## Locality is decided by the caller, so line 1 states it

**A function's execution locality is invisible from its name, its folder, and its body.** The
same `remoteExec` that sends work to the server (`target 2`) sends it to every client
(`target 0`); a dialog button action runs purely local; and an `addAction` body runs on whoever
activates it regardless of where the surrounding file ran. Locality is a property of the call
site, which a reader holding the function open cannot see.

Three files in the tree make the point:

| File | Reads as | Actually |
|---|---|---|
| `server/dialog/fnc_MHQ_deploy.sqf` | client, from its folder | server — the action at `shared/functions/fnc_MHQ_addActions.sqf:21` sends it to target 2 |
| `client/supports/fnc_helolift.sqf` | server, from an early `isServer` guard | client throughout; that guard is *indented*, governing an inner block only |
| `server/misc/fnc_createKillhouse.sqf` | server, and it is | but its `addAction` body runs on the activating client, so `player` resolves there |

So each load-bearing function states its locality on line one:

```sqf
// Locality: server -- callers remoteExec to target 2.
// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
```

The header names the evidence — a `remoteExec` target, a dialog action, or the caller it
inherits from — so a reader can re-check it rather than trust it. Of 211 load-bearing files
(those that write a networked global or are a `remoteExec` target):

| Count | Treatment |
|---|---|
| 137 | header states the locality, which nothing in the code otherwise reveals |
| 74 | no header — a top-level `isServer`/`hasInterface` guard already says it, and a comment would restate code |

Of the 137, **49 record a split** rather than one answer: the file runs on one machine and its
`addAction`, trigger, button or map-click bodies run on whichever machine triggers them. Those
are the highest-value headers, because a guard tells you where the file runs and is then
actively misleading about the callbacks inside it. Three more record that the function is
called from both sides and is safe either way, because it touches no shared state.

Nothing load-bearing is left undocumented. Getting there needed hand-tracing for 28 files that
automated resolution could not reach, and the reasons are worth knowing:

- **Function names are referenced in mixed case.** `server/server_init.sqf:108` spawns
  `fnc_bluHQinit` while the registry defines `fnc_BluHQinit`; `shared/includes/operative_menu.hpp:70`
  calls `fnc_LBselected` against a registered `fnc_lbselected`. SQF does not care, but any
  exact-match search over the source does, so a grep for callers silently comes back empty.
- **A function passed as a value has no call site to find.** `addAction`, `onLBSelChanged` and
  the dyna-mission table all take a bare function reference, so the invocation never appears as
  `spawn`/`call`/`remoteExec` next to the name.

## Dedicated-server compatibility

**`player` is `objNull` on a dedicated server.** Anything inherently about one player's view —
High Command assignment, comm-menu entries, teleports, addActions — must execute on that
player's machine even when the server decides it should happen. The pattern is to hand a code
block back to the requesting client; `server/misc/fnc_hirePartisans_spawnDeployed.sqf:113-118` and
`server/misc/fnc_HCsquad_spawn.sqf` both do it:

```sqf
[[_group], {
    params ["_group"];
    if (isNull _group) exitWith {};
    player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];
```

**The mirror-image bug is a server thread calling a function that opens `if (!hasInterface)
exitWith {}`.** The guard is correct for the function — it draws markers and hints — but on a
dedicated server it makes the call a no-op, and on a hosted one it works for exactly the host,
which is why a listen-server test proves nothing. The old `fnc_found_intel` was reached both
ways: most callers attached it as an `addAction`, so it ran on the player who used it, but two
side missions `spawn`ed it straight from a server thread and their reward silently evaporated.
The fix is not to weaken the guard but to split the function — the decision server-side, the
presentation `remoteExec`'d at whoever should see it. See
[`intel_system.md`](intel_system.md#one-writer-per-reveal-flag-one-function-for-payout).

The corollary is that a bare `player` read in server-side code is a latent dedicated-server
bug, and a silent one — `objNull` yields no error, just wrong behaviour.
`server/warcom/fnc_WARCOM_blu_patrol.sqf` measured `_randomZone distance player` to keep patrol waves
away from players; that returned a huge value against `objNull` so the keep-out always passed,
and on a hosted server it only ever measured the host. It now tests `allPlayers`.

Counters that name things must live server-side for the same reason. `DUWS_number_*` were
initialised only in `client/includes/squad_number_init.hpp` via `client/client_init.sqf:53`, so each
client kept its own and two players both minted "Inf 1". The High Command counters now live in
`server/misc/fnc_HCsquad_spawn.sqf`, read as `missionNamespace getVariable [key, 0]` so they
self-initialise wherever the server first needs them; the remaining entries in that include are
still client-local.

**One deliberate exception.** Pre-play configuration is authored on a *client*: the game master
runs the campaign menu and broadcasts the result, and everyone else waits on
`HQ_pos_found_generated && chosen_settings` (`client/client_init.sqf:124-138`). That survives a
dedicated server because game master is a client role rather than the host, but roughly 18
globals in `client/dialog/fnc_process_campaign_menu.sqf` are set from a client and broadcast. It is
safe only because it happens once, before any other writer exists. Do not let it become the
precedent for anything mid-mission.

## Entity creation

Purchase menus spawn units and vehicles, and it is tempting to read all of that as a
client-authority problem. It mostly is not — locality has to be judged per site:

| Site | Runs on | Assessment |
|---|---|---|
| `server/dialog/fnc_MHQ_deploy.sqf` | server, via target 2 | correct |
| `client/dialog/fnc_request_squad.sqf` task-force path | server, `server/misc/fnc_playerTF_spawn.sqf` | correct |
| `client/dialog/fnc_request_squad.sqf` High Command path | server, `server/misc/fnc_HCsquad_spawn.sqf` | correct; campaign assets must outlive one player's session |
| `client/dialog/fnc_request_unit.sqf`, `fnc_request_unit_fob.sqf` | client, `createUnit` into `group player` | correct by design — a player's AI subordinates belong on the commanding machine |
| `client/operative/fnc_operator_recruit.sqf` | client, then `joinSilent (group player)` | same |
| `client/dialog/fnc_request_vehicle.sqf`, `fnc_request_vehicle_fob.sqf` | client, `createVehicle` | low risk — locality transfers when a player enters |
| `server/init_hq/fnc_fortifyFOB.sqf`, `fnc_guardsFOB.sqf` | server, on build and on rebuild alike | correct |

The distinction that matters: a group the player *commands* belongs on the commanding machine,
because that is where orders originate. A group the campaign *owns* belongs on the server,
because it must survive that player disconnecting.

FOB defences are campaign property by that test, so both spawn functions are server-only. The one
redeploy scroll action still runs on the acting player, but it keeps only the sound and an advisory
affordability hint: `server/misc/fnc_redeployFOBUnits.sqf` does the checking, the charging and the
rebuild, exactly as the HQ's redeploy does. The charge moved off the client so that a caller who
loses a race against another rebuild is turned away before paying, rather than charged and refunded.

Getting there needed three linked changes, and the reasoning generalises to any per-object
scroll action in a co-op mission:

- **The action is added to every machine, not the builder's.** It used to target the
  `clientOwner` captured when the FOB was built, so only that player ever saw the option. It now
  targets `[0,-2] select isDedicated` with JIP, matching `shared/functions/fnc_FOBactions.sqf`.
- **It carries no arguments.** Baking the current turrets into the action was only safe while one
  machine held it; broadcast, every other player's copy would still reference the ring a rebuild
  had already deleted. The server reads the live set off the FOB object instead, so the action
  never goes stale and never needs removing and re-adding.
- **A per-FOB busy flag serialises rebuilds.** Two players can now fire the same action at once,
  which would have spawned a duplicate ring over the first. The loser is refunded: the charge
  is settled before the rebuild request arrives, so the busy check cannot decline it in time.

That last point is the one worth generalising: opening an action to every player converts a
"only one machine can do this" assumption into a race, and the object the action hangs on is
the natural place to hold the lock.

## Adding a function

State the locality on line one, and name the evidence rather than the conclusion — "callers
remoteExec to target 2" can be re-checked, "server only" cannot. If a top-level
`isServer`/`hasInterface` guard already says it and the file creates no callbacks, that guard
is the statement and a header would restate code.

Then check the failure modes that produced every wrong answer here: an indented guard governs
its block, not the file; an `addAction` or `onLBSelChanged` body runs on whoever triggers it
regardless of where the surrounding file ran; and `player` is `objNull` wherever the server is
the one executing.
