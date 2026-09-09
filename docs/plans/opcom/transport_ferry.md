# Transport and ferry

A tasking unit owns its whole journey. When its route crosses water it cannot walk, it requests a lift across
that leg, rides to the far shore, and foots on. The commander never binds a carrier to a rider by hand — a
ferry is a consequence of a rider's route, not an order. This document is the authoritative design for the
mechanic; it supersedes the summary in
[`opcom_plan.md` §Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight), which points here.

A transport is a **dual-purpose unit**, and reconciling that is what this design turns on. The same boat or
transport helicopter can be a *role unit* — given a directed order, it executes like any other tasking — or an
*idle lift asset* the ferry pool may draw on. It is never both at once: a hull on a job is off the pool, and
only an idle hull is lendable, so a standing order is never silently broken to serve another unit's crossing.

## What the commander decides

| Decision | Deliberate? | Owned by |
| --- | --- | --- |
| Recruit transports — how much lift exists at all | yes | P4 valuation; P3 by hand |
| Give a transport a directed order, or leave it idle (a lendable lift) | yes | P4; P3 by hand |
| Whether an idle hull actually leaves its post to ferry | yes | **P4** valuation; P3 auto-takes the nearest |
| Which idle hull lifts which rider, where they meet, where the rider dismounts | no — mechanical | the sim |

An idle transport — one sitting on `guard`, or resting in an uncontested `garrison` — is **available** to be
called for a ferry. Available is not the same as *will*: whether spending that hull on a crossing is worth
vacating its post is a valuation, and valuation is the Phase 4 decision loop's job. In Phase 3 the mechanic only
marks idle hulls available and the hand-harness (via the mechanical auto-borrow) takes the nearest; Phase 4
later decides whether the call is worth making.

A transport executing a **directed order** — a `move`, a supply lift, any order aimed at a target — is a role
unit and is **not** in the pool. Its order is preserved and no rider preempts it. The two further protected
states a hull can sit in — already `carrying`, or garrisoned in a **contested** (locked) zone — stay protected
as before.

Borrowing an idle hull costs a zone no defender: a ferry-capable transport (a boat or transport heli) is a
non-combatant in the combatant garrison model (`opcom_plan.md`), never enrolled in a zone's reserve wave, so the
borrow needs no garrison-reserve draw-out — there is no reserve-spawned defender to delete and no pool or
ceiling entry to decrement. It is a plain re-task.

## The route crosses water

The mechanic starts in the router ([`fnc_opcom_route.sqf`](../../../src/duws/server/opcom/fnc_opcom_route.sqf)).
A land move type may **cross navigable water at a lift penalty**: water cells are passable in the A\* search at a
high added cost (`OPCOM_ROUTE_LIFT_PENALTY`), so the planner still prefers a land path wherever one exists and
routes over water only when it must. A contiguous run of water cells in the returned chain is one **ferry leg**.

Two points carry the design:

- There is no land-mass reachability pre-check for a land type. Because water is crossable, a route whose ends
  sit on different land masses may legitimately join over a navigable body; only a target reachable by neither
  land nor a navigable crossing falls through to the no-route fallback (hold straight).
- The route is not tagged with which points are water. The executor re-tests each waypoint's water status at
  step time (`DUWS_fnc_opcom_isWaterPt`), so a leg's need for a lift is decided from the live grid, not a stored
  flag that could drift.

The router carries the water-crossing logic the removed hand `board` order used to stand in for; the
commander-facing model is simpler for it.

## The borrow

The **pool** of borrowable lift is every tasking that is:

- virtual (not currently live),
- `transport`-flagged and of a move type that can cross the leg's water — a boat, or, where no boat is free, a
  rotary transport (a wheeled or tracked transport is never compatible with a water leg),
- not already `carrying`, and
- **idle**: its order is `guard`, or `garrison` in an uncontested zone.

The idle gate is the model this design commits to: a hull on a directed order is a role unit and stays off the
pool, so a ferry never breaks a standing order. A hull that finishes a ferry reverts to `guard` at the far shore
(below), which returns it to the idle pool — so one hull still shuttles rider after rider without a fresh order.

**Trigger** — execution, not planning: a rider advances on foot until its next waypoint is a water cell. There
it stops at the near shore and **requests** a lift. Deferring to execution resolves contention when it actually
matters, not at plan time.

**When lift is available**, the nearest free compatible idle hull is bound — `carrying` (the rider's id) on the
transport, `ridingOn` (the transport's id) on the rider. While `ridingOn` is set the rider takes no turn of its
own; the transport drives it. In Phase 3 this pick is mechanical (nearest); in Phase 4 it is the point at which
the decision loop may decline to spend the hull at all.

**When no lift is available** the rider does not stall forever. It either **waits** at the near shore and retries
each tick, or **proceeds on foot** where a land route is the better answer. Under the current router this
resolves itself: the lift penalty makes a land path win wherever one exists, so a rider only ever holds a water
leg when land is effectively impossible (a true island gap), where waiting for lift is the only option. The
explicit *wait-versus-walk-a-longer-way* trade becomes real only if Phase 4 lowers the penalty to treat water as
a genuine shortcut; that comparison is then a Phase 4 valuation, not a Phase 3 rule. A rider that keeps
requesting with no lift free is logged as **stranded** (a WARN every `OPCOM_FERRY_STRAND_TICKS` ticks), so a
real deadlock shows in the RPT instead of hanging silently.

Capacity is one rider of any headcount; seats are not checked in the virtual layer, so the mechanic never
depends on a mod fielding a roomy carrier. Seats bind only when the pair goes live.

## State machine

The carry reuses `DUWS_fnc_opcom_ferryStep` (server,
[`fnc_opcom_ferry.sqf`](../../../src/duws/server/opcom/fnc_opcom_ferry.sqf)), run each tick on the transport,
with the drop point the **far shore of the water leg**:

1. **Rendezvous** — not yet embarked: the transport marches to the waiting rider's near-shore position on its
   own move type. Within one cell (`OPCOM_GRID_CELL`) it embarks and retargets to the far shore.
2. **Carry** — embarked: the transport marches to the far shore, the rider's position copied onto it each tick
   so it rides along, ignoring its own water rule.
3. **Dismount on the far shore** — on arrival the rider is released (`ridingOn = -1`, route cleared) and replans
   from the far shore to **its own target**. Because the far shore is the first land cell past the water span,
   that replanned route is land the rider can walk. A target across a further body simply triggers another
   request at the next water leg.
4. **Transport freed** — the transport clears `carrying`/`embarked` and reverts to a **free `guard` in place**
   (where the crossing ended; a boat backs off to navigable water since it cannot rest on land), back in the idle
   pool and ready for its next tasking. It is not consumed: one hull shuttles rider after rider, and nothing
   auto-returns it to base. A hull borrowed from a garrison does not return to it — it stays a staged ferry asset
   near the front.

The **far shore** is the first land cell after the water span in the rider's route chain, so the drop always
lands the rider on the target side and its replan stays on land.

## De-virtualisation

Unchanged in spirit ([`opcom_plan.md` §The virtualisation boundary](opcom_plan.md#the-virtualisation-boundary)):
when a carrying pair streams in near a player, both spawn and the rider is `moveInCargo`'d into the hull if it
fits, else dropped beside it (the current simplification, not a tied abort). The water-leg intent is lost once
the pair is live — they go independent. Because the transport is re-borrowable, one that survives its live spell
re-virtualises as a free `guard`, back in the idle pool.

## Lifecycle

An idle transport is a durable lift asset: it ferries a rider, reverts to `guard` in place, and waits for the
next. Phase 4 (or the Phase 3 operator) decides when to recruit more lift and where to stage it; nothing
auto-returns a hull to base or auto-recruits one under demand. A transport leaves play only by loss, by being
given a directed order (which takes it off the pool), or by being re-tasked into a zone garrison.

## Out of scope

- **Air-lift to speed a land leg** — deferred. Ferrying is triggered only by a water leg a land type cannot
  walk. Lifting a walkable leg just to go faster is a cost-versus-time judgment, which is Phase 4 valuation, not
  a routing necessity.
- **A manual board verb or a deliberate drop cell** — not part of the mechanic; the route fetches the lift and
  the drop is computed (the far shore).
- **Multi-rider transports** — capacity stays one virtual rider of any size.
- **Auto return-to-base or auto-recruit of lift** — the pool is what the commander has recruited and left idle,
  nothing more.

## Phase 4 hooks

Two valuations sit on top of the Phase 3 mechanic, both deliberately deferred to the decision loop:

- **Whether an idle hull leaves its post to ferry.** Phase 3 marks a guard/garrison hull available and
  auto-takes the nearest; Phase 4 weighs the crossing's worth against vacating that post, and may decline.
- **Whether a rider waits for lift or walks a longer land route.** This bites only once Phase 4 tunes the lift
  penalty so water is a real shortcut; then wait-versus-walk is a time/cost weigh.

Everything below those — which idle hull lifts which rider, the rendezvous, the crossing, the dismount — is
mechanical and needs no appraisal. Phase 3 exposes the idle-pool borrow and the far-shore dismount for the hand
harness to exercise.
