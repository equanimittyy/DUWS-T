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

## Purchases create entities on the buyer's machine

The reinforcement and vehicle menus run as dialog button actions
(`includes/request_menu.hpp:74,85,97`), so their spawn calls execute on the requesting
player's machine:

| Site | Creates |
|---|---|
| `dialog/fnc_request_unit.sqf:30`, `dialog/fnc_request_unit_fob.sqf:29` | `createUnit` |
| `dialog/fnc_request_squad.sqf:102`, `dialog/fnc_request_squad_fob.sqf:85` | `BIS_fnc_spawnGroup` |
| `dialog/fnc_request_vehicle.sqf:28`, `dialog/fnc_request_vehicle_fob.sqf:28` | `createVehicle` |
| `dialog/fnc_MHQ_deploy.sqf:12,36,52` | group plus two vehicles |
| `operative/modern/fnc_operator_recruit.sqf:34` | `BIS_fnc_spawnGroup` |

An entity created on a client is local to it: that machine simulates the AI, and the group is
orphaned if the player disconnects. Moving creation to the server also closes the
client-side-permission-check problem below for free, because the server then owns both the
charge and the effect — which is why this is the higher-value change of the two even though
the authority violation is less direct.

## Client-side permission checks

Roughly 45 affordability comparisons across 22 files read the pool from the buying client's
copy and apply the effect unconditionally, so the server cannot refuse. The consequences and
the reasoning for leaving it are recorded under *Client-side affordability checks allow a
co-op overdraft* in [`cp_economy.md`](cp_economy.md#balance-concerns); this is not scheduled
work on its own, and the entity-creation change above dissolves most of it as a side effect.
`init/server_fnc_init.sqf:801-803` (`fnc_pylon_set_with_cost`) is the one purchase that
already checks server-side, and is the pattern for the rest.

## Dead shared state

`missions/mission_threads/protect_civ/fnc_protect_civ.sqf:251-254` mutates and broadcasts
`CommandPoints` and `ActionPoints`. Neither global exists anywhere else in the mission and
neither is ever initialised, so the branch would error on the nil read if it ever ran. It is
the `else` arm of a check on whether `fnc_mission_reward` is defined, and that function is
compiled unconditionally in `init/server_fnc_init.sqf`, so the arm is unreachable. Delete it
rather than repair it.

## Sequence

Reputation first: it is the same shape as the finished CP and AP work, it has a live
client-side writer, and it feeds AI spawning. Entity creation second, as it is the larger
structural change and subsumes the permission-check problem. The dead branch is independent
and can ride with either.

## Verification

The invariant is greppable, and that is the point of stating it as "nothing else assigns the
global": a search for direct assignments to a pool should return only its writer function and
the pre-play absolutes. Nothing else here is machine-checkable — the lint layer parses
syntax and resolves paths, and the unit layer runs only pure functions, so no test can reach
a `remoteExec` or a `publicVariable` (see [`testing.md`](testing.md)). Every change in this
plan needs a co-op session with at least two players to confirm, single player cannot
reproduce any of these failures by construction.
