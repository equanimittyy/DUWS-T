# Server/client authority

Shared campaign state — the CP and AP pools, reputation, zone lists, FOB lists — lives in
networked globals that every machine keeps a copy of. Correctness depends on exactly one
machine writing each of them. Command Points and Army Power now work that way; the rest of
the mission does not yet, and this doc is the plan to finish the job. For where the
subsystems live see [`architecture.md`](architecture.md); for the CP and AP contracts
already in place see [`cp_economy.md`](cp_economy.md).

## Why this keeps recurring

**A function's execution locality is invisible from its name, its folder, and its body. Only
the caller decides it.** The same `remoteExec` that sends work to the server (`target 2`)
sends it to every client (`target 0`), and a dialog button action runs purely local. So
locality is a property of the call site, and a reader holding the function open cannot see
it.

Two files in the tree prove the point in opposite directions:

| File | Where it looks like it runs | Where it actually runs |
|---|---|---|
| `dialog/fnc_FOB_cleanup.sqf` | client, from its folder | server only — `dialog/fnc_FOB_remove.sqf:33` sends it to target 2 |
| `misc/fnc_civ_healAction.sqf` | a shared helper | every client — `misc/fnc_civ_handler.sqf:439,506` send it to target 0 with JIP |

That is the root cause. Every new feature has to re-derive the answer, and one wrong guess
reintroduces a lost-update bug. Naming or a header comment stating the intended locality is
worth more here than any individual fix below.

## The invariant

Every shared global has one writer, on the server, taking an *intent* rather than a
resulting value. Callers send the intent via `remoteExec [..., 2]` and never assign the
global. The engine applies each intent as one uninterruptible statement against the single
server copy, so concurrent changes serialise instead of overwriting one another with stale
absolutes — the failure mode is in the gotchas entry *"A shared global mutated as
`x = x - c; publicVariable` loses concurrent writes"*
([`arma_engine_gotchas.md`](arma_engine_gotchas.md)).

Three writers already follow it and are the templates to copy: `fnc_cp_adjust` (signed
numeric delta), `fnc_ap_adjust` (delta plus a target-pool selector), and
`fnc_warcom_set_primary_zone` (an operation on a shared list, matched by value so a stale
caller finds nothing rather than corrupting state). All three live in
`init/server_fnc_init.sqf`.

A guard is not a substitute for a single writer, but it is worth adding where a function is
*intended* to be server-only and its locality is not provable: `init_zones/fnc_captured.sqf`
and its two peers open with `if (!isServer) exitWith {}` for that reason.

## Reputation is the next pool to consolidate

`Player_Reputation` is written at 12 sites across 8 files with no single writer at all. One
of those sites is live client-side mutation — `misc/fnc_civ_healAction.sqf:68` does
`Player_Reputation = Player_Reputation + 0.5; publicVariable` on the machine of whoever
healed a civilian.

This matters more than a skewed counter. The server reads reputation to decide whether to
spawn hostile civilians and how many (`misc/fnc_civ_handler.sqf:382,533-535,566`), so a
dropped update changes enemy behaviour rather than just a number on a screen. Reputation also
carries fractional deltas (`+0.5`, `-0.3`) and a rounding normalisation at
`misc/fnc_warcrimes_script.sqf:48-49`, so the writer has to own that rounding or two callers
will round differently.

The remaining 11 sites are already server-side; routing them too is what makes the
"no direct assignment" rule greppable, which is the property that keeps it true.

The writer has to own the rounding, because reputation is the only pool with fractional
deltas and `misc/fnc_warcrimes_script.sqf:48-49` currently normalises after its own
subtraction. Left at the call sites, two callers would round differently:

```sqf
fnc_rep_adjust = {
    if (!isServer) exitWith {};
    params [["_delta", 0]];
    Player_Reputation = Player_Reputation + _delta;
    // Snap to 2dp and clear float dust: deltas are fractional (+0.5, -0.3) and
    // abs(rep) is multiplied into a spawn count, so drift would compound there.
    Player_Reputation = (round (Player_Reputation * 100)) / 100;
    if (abs Player_Reputation < 0.01) then { Player_Reputation = 0 };
    publicVariable "Player_Reputation";
};
```

No display refresh: reputation has no HUD control, so the writer stays simpler than
`fnc_cp_adjust`. Notifications already fan out via `remoteExec` at each call site and can
stay there, but they read `Player_Reputation` for the message text, so on a client they will
show the pre-change value — the same staleness `dialog/fnc_convertAPtoCP.sqf` solved by
printing the expected total.

Two traps when converting. At `misc/fnc_warcrimes_script.sqf:45-50` the normalisation and
broadcast sit at column zero but are syntactically inside `if (_repLoss > 0) then {`;
indentation there does not reflect scope. And `misc/fnc_civ_init_Tomata.sqf:199-207` samples
`Player_Reputation` into `_rep` and later compares the two to detect whether it changed
during a wait, so that read must not be folded into the writer.

`CIV_deaths` is a smaller instance of the same inconsistency: broadcast once at
`init/server_var_init.sqf:69`, then incremented at `misc/fnc_civ_rep_Tomata.sqf:34` with no
broadcast. Both writer and reader are server-side today, so nothing is broken — either
broadcast it on change or stop broadcasting it at init, rather than leaving a networked
global that silently is not.

## Entity creation is mostly already correct

Purchase menus spawn units and vehicles, and it is tempting to read all of that as a
client-authority problem. It mostly is not. Locality has to be judged per site, and the
answer differs:

| Site | Runs on | Assessment |
|---|---|---|
| `dialog/fnc_MHQ_deploy.sqf:12,36,52` | server — the action at `dialog/fnc_MHQ_addActions.sqf:20` sends it to target 2 | already correct |
| `dialog/fnc_request_squad.sqf:100`, `dialog/fnc_request_squad_fob.sqf:83` task-force path | server — `misc/fnc_playerTF_spawn.sqf` | already correct, and the template for server-side spawning |
| `dialog/fnc_request_unit.sqf:30`, `dialog/fnc_request_unit_fob.sqf:29` | client, `createUnit` into `group player` | correct by design — a player's AI subordinates belong on the commanding machine |
| `operative/modern/fnc_operator_recruit.sqf:34,59` | client, then `joinSilent (group player)` | same, ends up in the player's group |
| `dialog/fnc_request_vehicle.sqf:28`, `dialog/fnc_request_vehicle_fob.sqf:28` | client, `createVehicle` | low risk — locality transfers when a player enters |
| `dialog/fnc_request_squad.sqf:102`, `dialog/fnc_request_squad_fob.sqf:85` non-task-force path | client, independent High Command group | move to the server |

High Command squads move to the server. They are campaign assets meant to outlive any one
player's session, and a group created on a client is simulated there and orphaned when that
player disconnects — which a dedicated server turns from an edge case into the normal way the
mission runs. `misc/fnc_playerTF_spawn.sqf` is the spawn half of the pattern; the assignment
half has to stay on the client, for the reason below.

## Dedicated-server compatibility

**`player` is `objNull` on a dedicated server.** Nothing that touches it can run server-side,
so any operation that is inherently about *one player's* view — High Command assignment,
comm-menu entries, teleports, addActions — has to execute on that player's machine even when
the server decides it should happen. The pattern is to hand a code block back to the
requesting client, and `misc/fnc_hirePartisans_spawnDeployed.sqf:113-118` already does it:

```sqf
[[_group], {
    params ["_group"];
    if (isNull _group) exitWith {};
    player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];
```

The server spawns, names, and registers the group; the client performs the one step that
needs its own `player`. Copy this for the HC squad move rather than inventing a second shape.

Two places still get this wrong, and both are silent rather than loud:

| Site | On a dedicated server |
|---|---|
| `misc/fnc_createKillhouse.sqf:1086` | `player setPos _respawnPos` targets `objNull`, so the respawn move never happens |
| `warcom/fnc_WARCOM_blu_patrol.sqf:69` | `_randomZone distance player` measures against `objNull`, which returns a huge value, so `> 500` is always true and patrol placement silently loses its keep-out |

**The squad-name counters exist only on clients.** `init/client_init.sqf:52` includes
`includes/squad_number_init.hpp`, which is never broadcast, so every client keeps its own
`DUWS_number_*` set and two players buying infantry both mint "Inf 1" today. The server has no
copy at all, so moving spawn and naming there without moving the counters would read nil.
They have to move to server-side init as part of the same change, which also collapses the
duplicate-name problem — one counter, one namer.

**Pre-play configuration is authored on a client, deliberately.** The game master runs the
campaign menu and broadcasts the result; everyone else waits on `HQ_pos_found_generated &&
chosen_settings` (`init/client_init.sqf:123-137`). That survives a dedicated server because
game master is a *client* role rather than the host, but it is a genuine exception to the
one-writer rule: roughly 18 globals in `dialog/fnc_process_campaign_menu.sqf` are set from a
client and broadcast. It is safe only because it happens once, before any other writer exists.
Keep it as a stated exception; do not let it become the precedent for anything mid-mission.

## Client-side permission checks

Roughly 45 affordability comparisons across 22 files read the pool from the buying client's
copy and apply the effect unconditionally, so the server cannot refuse. The consequences and
the reasoning for leaving it are recorded under *Client-side affordability checks allow a
co-op overdraft* in [`cp_economy.md`](cp_economy.md#balance-concerns).
`init/server_fnc_init.sqf:801-803` (`fnc_pylon_set_with_cost`) is the one purchase that
already checks server-side, and is the pattern if this is ever scheduled. Note that it does
not dissolve as a side effect of moving spawns: the sites that spawn on a client are the ones
that are correct to, so the charge and the effect stay split regardless.

## Dead shared state

`missions/mission_threads/protect_civ/fnc_protect_civ.sqf:251-254` mutates and broadcasts
`CommandPoints` and `ActionPoints`. Neither global exists anywhere else in the mission and
neither is ever initialised, so the branch would error on the nil read if it ever ran. It is
the `else` arm of a check on whether `fnc_mission_reward` is defined, and that function is
compiled unconditionally in `init/server_fnc_init.sqf`, so the arm is unreachable. Delete it
rather than repair it.

## Sequence

Reputation first: it is the only phase with a live defect and a settled shape, and it carries
the `CIV_deaths` decision with it. The dead `protect_civ` branch is a deletion and can ride
along.

High Command squads second, together with moving the `DUWS_number_*` counters, since the two
cannot be separated. The two bare-`player` bugs above belong here too — they are the same
mistake in a different place, and fixing them alongside means the dedicated-server rule gets
applied once rather than rediscovered.

The locality convention is last and is the cheapest thing in this doc: a one-line header on
each function stating where it is meant to run. Every wrong assessment made while writing this
plan came from trusting a file's folder over its call sites — `fnc_MHQ_deploy` lives under
`dialog/` and runs on the server; `fnc_helolift` carries an inner `isServer` guard while being
a client function throughout. Dedicated-server support raises the cost of each such mistake,
because the host stops being a machine that happens to satisfy both roles.

## Verification

The invariant is greppable, and that is the point of stating it as "nothing else assigns the
global": a search for direct assignments to a pool should return only its writer function and
the pre-play absolutes. Nothing else here is machine-checkable — the lint layer parses
syntax and resolves paths, and the unit layer runs only pure functions, so no test can reach
a `remoteExec` or a `publicVariable` (see [`testing.md`](testing.md)). Every change in this
plan needs a co-op session with at least two players to confirm, single player cannot
reproduce any of these failures by construction.
