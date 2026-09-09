# Transport and ferry

A tasking unit owns its whole journey. When its route crosses water it cannot walk, the unit borrows a
transport to lift it over that leg, then dismounts on the far shore and foots on. The commander never binds a
carrier to a rider by hand — ferrying is a consequence of the route, not a separate order. This document is the
authoritative design for that mechanic; it supersedes the detail in
[`opcom_plan.md` §Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight), which is a summary
pointing here.

## What the commander decides

The commander decides only how much lift exists; the crossing itself is mechanical.

| Decision | Deliberate? | Picked by |
| --- | --- | --- |
| Recruit transports (boats, helis) — how much lift exists at all | yes | P4 valuation; P3 by hand |
| Where a transport waits — staged on ferry duty (`move`/`guard`) or resting in a zone garrison | yes | P4; P3 by hand |
| Which transport lifts which rider, where they meet, where the rider dismounts | **no** — all mechanical | the sim |

There is no boarding order and no drop-cell choice. Once a rider's route crosses water, the nearest compatible
transport is found, bound, carried and dismounted without a command. Any recruited transport is borrowable,
whether staged on ferry duty or resting in a zone garrison — staging decides where a hull waits, not whether it
can be borrowed. The one exclusion is a **contested (locked) garrison**: while a zone is under assault its
garrison is locked and nothing is drawn from it (the contested state the reserve wave already keys on,
[`fnc_garrison_reserve.sqf`](../../../src/duws/server/init_zones/fnc_garrison_reserve.sqf)).

Borrowing a garrisoned hull costs the zone no defender. A ferry-capable transport — a boat or transport heli — is a **non-combatant** (the combatant
garrison model, `opcom_plan.md`) — never enrolled in the zone's reserve wave — so the borrow needs no
garrison-reserve draw-out: there is no reserve-spawned defender to delete, and no reserve pool or ceiling entry
to decrement. It is a plain re-task.

## The route crosses water

The mechanic starts in the router ([`fnc_opcom_route.sqf`](../../../src/duws/server/opcom/fnc_opcom_route.sqf)).
Today a land move type treats navigable water as impassable, so a target across a strait returns the
hold-straight fallback and the rider never moves. The rework lets a land type **cross navigable water at a lift
penalty**: water cells become passable in the A\* search at a high added cost, so the planner still prefers a
land path where one exists and only routes over water when it must. A contiguous run of water cells in the
returned chain is one **ferry leg**.

Two consequences the implementation must handle, called out because they are the load-bearing change and the
main risk of this rework:

- The land-component reachability pre-check (`fnc_opcom_route.sqf` line 59) rejects a route whose ends sit in
  different land masses. With water now crossable that rejection is wrong for land types — a route may
  legitimately cross a navigable body — so the pre-check must be relaxed for the lift case.
- The emitted route must carry which of its points are water, so the executor knows where a leg needs a lift.
  The A\* already tests each cell's water status, so tagging the chain is cheap; the exact representation (a
  parallel flag array, or a per-point tag) is an implementation choice.

The router change is the cost of this rework: the commander-facing model gets simpler, but the pathfinder
takes on the water-crossing logic the hand `board` order used to stand in for.

## The borrow

The **pool** of borrowable lift is every tasking that is virtual, `transport`-flagged, not already carrying,
of a move type that can cross the leg's water (a boat, or — where no boat is available — a rotary transport; a
wheeled or tracked transport is never compatible with a water leg), and **not garrisoned in a contested zone**.
Order does not otherwise gate the pool: an idle garrisoned transport is as borrowable as a staged one. When the
pick is a garrisoned hull the executor flips its order off `garrison` — the step loop's `garrison` case only
heals and never runs a ferry turn, so an un-flipped hull would mend in place instead of lifting. No reserve
draw-out is ever needed: a ferry-capable hull (boat or transport heli) is a non-combatant, so it never sits
in the reserve wave.

The **trigger** is execution, not planning: a rider advances along its route on foot until the next waypoint
is a water cell. There it stops at the near shore and requests lift. Deferring to execution means contention
is resolved when it actually matters, not guessed at plan time.

**Selection** is the nearest free compatible transport in the pool. On a match the pair is bound — the same
internal binding the shipped ferry used, now set by the executor rather than a verb: `carrying` (the rider's
id) on the transport, `ridingOn` (the transport's id) on the rider. While `ridingOn` is set the rider takes no
turn of its own; the transport drives it.

**Contention** — no free compatible transport — is not an error: the rider holds at the near shore and retries
each tick until one frees up. Capacity is **one rider of any headcount**; seats are not checked in the virtual
layer, so the mechanic never depends on a mod fielding a roomy carrier. Seats bind only when the pair goes
live.

## State machine

The carry reuses `DUWS_fnc_opcom_ferryStep` (server,
[`fnc_opcom_ferry.sqf`](../../../src/duws/server/opcom/fnc_opcom_ferry.sqf)), run each tick on the transport,
with the drop point now the **far shore of the water leg** rather than a commanded cell:

1. **Rendezvous** — not yet embarked: the transport marches to the waiting rider's near-shore position on its
   own move type. Within one cell (`OPCOM_GRID_CELL`) it embarks and retargets to the far shore.
2. **Carry** — embarked: the transport marches to the far shore, the rider's position copied onto it each tick
   so it rides along, ignoring its own water rule.
3. **Dismount on the far shore** — on arrival the rider is released (`ridingOn = -1`, route cleared) and
   replans from the far shore to **its own target**. Because the far shore is the first land cell past the
   water span, that replanned route is land the rider can walk — it foots the rest of the way. A target across
   a further body simply triggers another borrow at the next water leg.
4. **Transport freed** — the transport clears `carrying`/`embarked` and reverts to a **free staged transport
   holding at the far shore** (a `guard` there), back in the pool. It is not consumed: one hull shuttles rider
   after rider across a strait, and there is no hardcoded return-to-base. A hull borrowed from a garrison does
   not return to it — it stays a staged ferry asset near the front.

The **far shore** is the first land cell after the water span in the rider's route chain, so the drop always
lands the rider on the target side and its replan stays on land.

## De-virtualisation

Unchanged in spirit ([`opcom_plan.md` §The virtualisation boundary](opcom_plan.md#the-virtualisation-boundary)):
when a carrying pair streams in near a player, both spawn and the rider is `moveInCargo`'d into the hull if it
fits, else dropped beside it (the current simplification, not a tied abort). The water-leg intent is lost once
the pair is live — they go independent. Because the transport is re-borrowable, a transport that survives its
live spell re-virtualises as a free staged transport, back in the pool.

## Lifecycle

A staged transport is a durable lift asset: it ferries a rider, returns to the pool at the far shore, and
waits for the next. P4 (or the P3 operator) decides when to recruit more lift and where to stage it; nothing
auto-returns a hull to base or auto-recruits one under demand. A transport is only ever removed from play by
loss, or by being re-tasked back into a zone garrison (un-staging it).

## Out of scope

- **Air-lift to speed a land leg** — deferred. Ferrying is triggered only by a water leg a land type cannot
  walk. Lifting a walkable leg just to go faster is a cost-versus-time judgment, which is P4 valuation, not a
  routing necessity — the P3 mechanic does not attempt it.
- **A manual board verb or a deliberate drop cell** — not part of the mechanic; the route fetches the lift and the drop is computed (the far shore).
- **Multi-rider transports** — capacity stays one virtual rider of any size.
- **Auto return-to-base or auto-recruit of lift** — the pool is what the commander has recruited, staged or
  garrisoned, nothing more.

## Phase 4 hooks

The decision loop's only ferry-related work is upstream of the mechanic: value **how much lift to recruit** and
**where to stage it**, given the water the front sits across. Everything below that — which hull lifts which
rider, the rendezvous, the crossing, the dismount — is mechanical and needs no appraisal. Phase 3 exposes the
pool borrow and the far-shore dismount for the hand harness to exercise.
