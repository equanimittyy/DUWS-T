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

Four writers implement it, all in `init/server_fnc_init.sqf`, and they are the templates to
copy: `fnc_cp_adjust` (signed numeric delta), `fnc_ap_adjust` (delta plus a target-pool
selector), `fnc_rep_adjust` (delta plus ownership of rounding), and
`fnc_warcom_set_primary_zone` (an operation on a shared list, matched by value so a stale
caller finds nothing rather than corrupting state).

Where a function is *intended* to be server-only and its locality is not provable from the
code, assert it: `init_zones/fnc_captured.sqf` and its two peers open with
`if (!isServer) exitWith {}` because they are driven by a `createTrigger` whose evaluation
locality is not proven.

Two hazards the invariant does **not** address, both recorded under *Balance concerns* in
[`cp_economy.md`](cp_economy.md#balance-concerns): affordability checks read the pool on the
buying client, so the server cannot refuse a purchase; and one direct `setVariable`-form write
existed for years without matching the `x = x + n` shape any grep for it would find.

## Locality is decided by the caller, so line 1 states it

**A function's execution locality is invisible from its name, its folder, and its body.** The
same `remoteExec` that sends work to the server (`target 2`) sends it to every client
(`target 0`); a dialog button action runs purely local; and an `addAction` body runs on whoever
activates it regardless of where the surrounding file ran. Locality is a property of the call
site, which a reader holding the function open cannot see.

Three files in the tree make the point:

| File | Reads as | Actually |
|---|---|---|
| `dialog/fnc_MHQ_deploy.sqf` | client, from its folder | server — the action at `dialog/fnc_MHQ_addActions.sqf:21` sends it to target 2 |
| `supports/fnc_helolift.sqf` | server, from an early `isServer` guard | client throughout; that guard is *indented*, governing an inner block only |
| `misc/fnc_createKillhouse.sqf` | server, and it is | but its `addAction` body runs on the activating client, so `player` resolves there |

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
| 95 | header states the locality, which nothing in the code otherwise reveals |
| 18 | header states a **split**: the file runs on one machine, its callback bodies on another |
| 75 | no header — a top-level `isServer`/`hasInterface` guard already says it, and a comment would restate code |
| 23 | no header — locality did not resolve; see below |

The 18 split entries are the highest-value ones. A guard tells you where the file runs and is
then actively misleading about the `addAction`, trigger and map-click bodies inside it, which
run elsewhere.

## Dedicated-server compatibility

**`player` is `objNull` on a dedicated server.** Anything inherently about one player's view —
High Command assignment, comm-menu entries, teleports, addActions — must execute on that
player's machine even when the server decides it should happen. The pattern is to hand a code
block back to the requesting client; `misc/fnc_hirePartisans_spawnDeployed.sqf:113-118` and
`misc/fnc_HCsquad_spawn.sqf` both do it:

```sqf
[[_group], {
    params ["_group"];
    if (isNull _group) exitWith {};
    player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];
```

The corollary is that a bare `player` read in server-side code is a latent dedicated-server
bug, and a silent one — `objNull` yields no error, just wrong behaviour.
`warcom/fnc_WARCOM_blu_patrol.sqf` measured `_randomZone distance player` to keep patrol waves
away from players; that returned a huge value against `objNull` so the keep-out always passed,
and on a hosted server it only ever measured the host. It now tests `allPlayers`.

Counters that name things must live server-side for the same reason. `DUWS_number_*` were
initialised only in `includes/squad_number_init.hpp` via `init/client_init.sqf:53`, so each
client kept its own and two players both minted "Inf 1". The High Command counters now live in
`misc/fnc_HCsquad_spawn.sqf`, read as `missionNamespace getVariable [key, 0]` so they
self-initialise wherever the server first needs them; the remaining entries in that include are
still client-local.

**One deliberate exception.** Pre-play configuration is authored on a *client*: the game master
runs the campaign menu and broadcasts the result, and everyone else waits on
`HQ_pos_found_generated && chosen_settings` (`init/client_init.sqf:124-138`). That survives a
dedicated server because game master is a client role rather than the host, but roughly 18
globals in `dialog/fnc_process_campaign_menu.sqf` are set from a client and broadcast. It is
safe only because it happens once, before any other writer exists. Do not let it become the
precedent for anything mid-mission.

## Entity creation

Purchase menus spawn units and vehicles, and it is tempting to read all of that as a
client-authority problem. It mostly is not — locality has to be judged per site:

| Site | Runs on | Assessment |
|---|---|---|
| `dialog/fnc_MHQ_deploy.sqf` | server, via target 2 | correct |
| `dialog/fnc_request_squad.sqf` task-force path | server, `misc/fnc_playerTF_spawn.sqf` | correct |
| `dialog/fnc_request_squad.sqf` High Command path | server, `misc/fnc_HCsquad_spawn.sqf` | correct; campaign assets must outlive one player's session |
| `dialog/fnc_request_unit.sqf`, `fnc_request_unit_fob.sqf` | client, `createUnit` into `group player` | correct by design — a player's AI subordinates belong on the commanding machine |
| `operative/modern/fnc_operator_recruit.sqf` | client, then `joinSilent (group player)` | same |
| `dialog/fnc_request_vehicle.sqf`, `fnc_request_vehicle_fob.sqf` | client, `createVehicle` | low risk — locality transfers when a player enters |

The distinction that matters: a group the player *commands* belongs on the commanding machine,
because that is where orders originate. A group the campaign *owns* belongs on the server,
because it must survive that player disconnecting.

## Where locality is still unknown

Twenty-three load-bearing files carry no header because locality could not be established,
and they are the ones to treat with suspicion:

- **Reached from both server and client paths** — `missions/fnc_mission_reward.sqf`,
  `misc/fnc_random_name.sqf`, `misc/fnc_sideChat_filter.sqf`, `init_hq/fnc_fortifyFOB.sqf`,
  `operative/modern/fnc_operative_mission_complete.sqf` and eight more. These genuinely have
  two localities; resolving them means deciding which is intended, not just observing.
- **No discoverable caller** — the faction autodetect set (`factions/MODERN/AUTODETECT_*.sqf`,
  `fn_factionAutoDetect.sqf`, `CIV_FACTIONS.sqf`), which is reached by `execVM`/`#include`
  rather than the function registry, plus `init_hq/fnc_BluHQinit.sqf`,
  `misc/fnc_ghst_halo.sqf` and `warcom/fnc_WARCOM_wp_opf_qrf.sqf`.

A header on any of these would be a guess. Leaving them bare is the honest signal, and it
narrows what a future reader has to work out from scratch.
