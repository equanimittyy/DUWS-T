# Live ferry rendering — load, carry, unload across the stream boundary

How a land tasking's water crossing is shown when a player watches it, while staying a cheap virtual
transfer when nobody does. Extends the virtual ferry in
[`opcom_plan.md` §Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight).

## Why

The virtual ferry (`borrowFerry` → `ferryStep`) carries a land unit over water off-screen: it stops at the
near shore, borrows a hull, and is teleported across in cell steps. Correct, and invisible, which is fine
until a player is at the shore. Today a live land unit reaching a crossing walks to the near shore and idles
there until it re-virtualises — which needs the player to leave — so under a watching player the squad just
stands at the beach, and a carrying pair that streams in unbinds and goes independent, its crossing abandoned.
This plan renders the whole crossing live when observed: a real pickup, carry, and drop, with no seam against
the virtual path.

## Model — the ferry streams like every other tasking

The rider and the transport are two separate tasking records. Each de-virtualises and re-virtualises on
**its own** cell against player cells — the standard K-cell streaming boundary
([`opcom_plan.md` §The virtualisation boundary](opcom_plan.md#the-virtualisation-boundary)). Neither forces
the other live: a player standing over a rider that waits for a lift does not pull a transport that is still
kilometres away — the transport keeps closing virtually until it enters a player ring of its own.

The ferry **binding** survives every transition. `carrying` (the rider's id) on the transport and `ridingOn`
(the transport's id) on the rider persist whether either end is live or virtual, so the crossing is one intent
from pickup to drop, never abandoned by a stream cycle.

Orders are **seamless** across a transition. The stored order drives the live `DUWS_fnc_opcom_applyOrder` and
the virtual `DUWS_fnc_opcom_advance` identically; nothing resets when a unit streams in or out. A transport
de-virtualising *on a ferry order* is exactly what tells de-virt to hand it the move or land order for its
current phase.

The rider is **board-despawned**: once loaded it owns no live units. It is virtual and bound, and its position
copies the transport's each tick (whether the transport is live or virtual). The rider re-spawns only at
unload. The despawn is also why seat capacity never binds — there is no passenger object to fit.

## Phases

| Phase | Live — by the unit's **own** streaming radius | Virtual — far |
|---|---|---|
| **Load** | transport, on entering a ring, takes the move/land order and closes on the rider; on arrival the rider **board-despawns** → virtual + bound; fallback group-delete at the hull | `borrowFerry` binds a free compatible lift; transport closes on the rider in cell steps |
| **Carry** | transport drives/flies the water leg live **only while in its own ring** — leaves it → re-virts; rider stays **virtual + bound**, pos copies the transport each tick | `ferryStep` steps the carry across |
| **Unload** | transport lands/drives to the drop waypoint; if still de-virt, the rider **re-spawns** disembarking → live + independent | rider dropped at the far shore, replans to its target |

## Load

Virtual: `borrowFerry` binds the nearest free compatible idle hull (boats preferred, rotary the fallback lift)
and the transport closes on the rider's near-shore point in cell steps, unchanged from the current path.

Live (the transport enters its own player ring): de-virt hands it the pickup order and it closes on the rider
by type.

| Type | Approach | Board |
|---|---|---|
| Helicopter | LZ found by the rider (`BIS_fnc_findSafePos`), fly in, `land "GET IN"`, poll grounded (`getPosATL` z under a low threshold, near the LZ) | rider units deleted **one by one** as they board — a seat is always free |
| Land vehicle | drive to within a short distance of the rider | rider units deleted **one by one** as they board |
| Boat | close to within **100 m** of the rider | **whole rider group** deleted at once — boarding a boat is finnicky, so it is skipped |

Fallback for the per-unit path: once the group is at the hull, delete the group outright rather than wait on
stragglers. On the last unit's despawn the rider record goes virtual, `ridingOn` set, `embarked` true.

## Carry

The transport drives or flies the water leg. It is live only while inside its own player ring; the moment it
leaves the ring it re-virtualises and `ferryStep` continues the carry from where it was. The rider stays
virtual and bound the whole time — no rider objects exist — and its position is copied from the transport each
tick, live or virtual, so belief and the grid read it riding along.

## Unload

The transport lands or drives to the drop waypoint (the far shore — the first land cell past the water span in
the rider's chain). If it is still de-virt on arrival, the rider disembarks live, mirroring how it boarded:

| Type | Disembark |
|---|---|
| Boat | snap the rider group to the shore and spawn the **whole group** at once (mirror of the whole-group board) |
| Helicopter | land, then spawn rider units in cargo **one by one** and turn each out (`getOut`) |
| Land vehicle | spawn rider units in cargo **one by one** and turn each out — same as the helo, no landing |

The rider becomes live and independent and replans from the far shore to its own target; since the drop is the
first land past the span, that replan stays on land (a target across a further body simply triggers another
lift request at the next water leg). The transport clears `carrying`/`embarked` and reverts to a free `guard`
in place (a boat backs off to navigable water), back in the idle pool — not consumed, so one hull shuttles
rider after rider.

## Implementation

**Tick-driven, no async.** The sequence advances as sub-states on the record, polled once per tick by the
tasking step — never a spawned `waitUntil`. OPCOM is a single tick loop that must stay savegame-safe and inside
its `try`/`catch` fault boundary, which a blocking spawn would break.

**The helo land pattern is borrowed, not the function.** `fnc_helotaxi.sqf`
([`src/duws/client/supports/taxi/fnc_helotaxi.sqf`](../../../src/duws/client/supports/taxi/fnc_helotaxi.sqf))
is client, player-facing — markers, dialogue, music, `addAction`, spawns. Only the pattern transfers:
`land "GET IN"` / `land "GET OUT"`, poll for grounded, animate doors.

**This replaces `deVirtFerry`'s unbind.** Today a mid-carry pair that streams in near a player unbinds —
`carrying`/`ridingOn` cleared, the two go independent, the water-leg intent lost. Under this model the binding
survives de-virt and the phase renders live instead.

**Re-spawn matches stored strength.** Disembarking rebuilds the rider through `DUWS_fnc_opcom_matchStrength`,
as a normal de-virt does, so attrition banked before the crossing is preserved.

Touch points:
[`fnc_opcom_ferry.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_ferry.sqf) (`borrowFerry`,
`ferryStep`, `advance`),
[`fnc_opcom_stream.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_stream.sqf) (`deVirt`,
`reVirt`, `reOrderLive`, `spawnComp`),
[`fnc_opcom_task_step.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_task_step.sqf) (the
per-tick phase driver).

## Build order

Three reviewable stages, each tested before the next: **Load** (live pickup + board-despawn + bind),
**Carry** (live drive with re-virt on leaving the ring), **Unload** (live disembark + re-spawn). The virtual
path stays intact throughout, so a half-built feature still ferries correctly off-screen.
