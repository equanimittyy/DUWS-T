# Transport and ferry

A `transport`-flagged tasking unit carries one other tasking unit — the *rider* — to speed its march or to
cross terrain the rider cannot (water for a foot squad, distance for anything). This document is the
authoritative design for that mechanic; it supersedes the detail in
[`opcom_plan.md` §Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight), which is to become a
summary pointing here (see [Migration](#migration)).

The shipped Phase 3 ferry got two things wrong. It dropped the rider at the rider's own final target, which
forfeits *where to dismount* — a real tactical lever: a ground assault ferried across a strait should
dismount at a low-threat cell short of the objective and take the last leg on foot, exactly the **safe rally**
the muster template already uses ([`opcom_plan.md` §Commitment](opcom_plan.md#commitment-intents-are-sticky)).
And it marked the transport `done` after one drop, discarding a reusable relocation asset. This rework makes
the **drop cell a deliberate choice** and the **transport re-taskable** after it unloads.

## What the commander decides

The mechanic separates the commander's decisions from the sim's mechanical execution. Only the first column
is a choice; the pickup and the dismount are automatic once the choice is made.

| Decision | Deliberate? | Picked by |
| --- | --- | --- |
| Ferry this rider, or let it march alone | yes — this *is* the load decision (load is implicit) | P4 Transport valuation; P3 by hand |
| Drop cell — where the rider dismounts | yes — new | P4 (the safe rally, or the target); P3 by hand (map-pick) |
| The transport's next job after it drops | yes — new (re-taskable) | P4; P3 by hand |

Mechanical, never a decision: rendezvous with the rider, embark on contact, carry, and dismount at the drop
cell. **Load stays implicit** because in a continuous virtual model — unlike a turn-based grid where a unit's
per-turn position is itself the play — once ferrying is chosen, driving the transport to the pickup is not a
second tactical lever. The deliberate acts are *whether to ferry* and *where to drop*.

## The boarding binding

OPCOM issues one order, `board(transport, rider, dropCell)`, which binds the pair — never an automatic embark
of two units that happen to share a cell. It stores, on the **transport** tasking record: `carrying` (the
rider's id), `embarked` (false until pickup), and the new `dropCell` (a world point, defaulting to the
rider's target). On the **rider**: `ridingOn` (the transport's id). While `ridingOn` is set the rider takes
no turn of its own — the transport drives it.

Capacity is **one rider of any headcount** — seats are not checked in the virtual layer, so the mechanic never
depends on a mod fielding a roomy carrier. Seats bind only when the pair goes live.

## State machine

Reworked `DUWS_fnc_opcom_ferryStep` (server, [`fnc_opcom_ferry.sqf`](../../../src/duws/server/opcom/fnc_opcom_ferry.sqf)),
run each tick on the transport:

1. **Rendezvous** — not yet embarked: the transport targets the rider's current position and marches to it on
   its own move type. Within one cell (`OPCOM_GRID_CELL`) it embarks: sets `embarked`, and retargets to the
   **`dropCell`** — not the rider's final target, which is the shipped bug.
2. **Carry** — embarked: the transport marches to the `dropCell`, the rider's position copied onto it each
   tick so it rides along, ignoring its own terrain rule.
3. **Dismount at the drop cell** — on arrival the rider is released (`ridingOn = -1`, route cleared) and, from
   the drop cell, replans a route to **its own target** and resumes its own order — so it foots the last leg.
   When the drop cell equals the target (the default), this is a drop straight on the objective, as before.
4. **Transport freed** — the transport clears `carrying`/`embarked` and, rather than going `done`, reverts to
   a **free transport unit holding at the drop cell** (a `guard` order there). It is now available to be
   re-tasked or issued another `board` — the re-taskable shuttle.

## Drop cell

- **Default** is the rider's target, so an unspecified drop reproduces today's on-objective behaviour —
  backward-compatible.
- **Validity.** The transport must have a route to the drop cell on its move type, or the ferry is pointless;
  `board` refuses the binding when it does not (a deliberate cell can be mis-specified, so the mechanism fails
  loud here rather than stalling silently). The rider *should* have a route from the drop cell to its target;
  when it does not the binding is accepted but warns — the rider will hold straight after dismount. P4 is
  expected to pick a drop cell that satisfies both; a hand P3 pick is trusted with a warning.
- **Safe-rally tie-in.** For a ground assault ferried into range, the natural drop cell is the **safe rally** —
  a low-threat cell short of the target
  ([`opcom_plan.md` §Commitment](opcom_plan.md#commitment-intents-are-sticky)) — reusing the same primitive
  the multi-unit muster uses. The rider dismounts there and advances on foot into contact.

## Lifecycle: the transport is re-taskable

After a drop the transport is a free `transport` tasking holding at the drop cell, not a consumed one. P4 (or
the operator) decides its next job — another `board`, a `move`, or holding — so one transport can shuttle
several riders across a strait rather than being spent per crossing. There is **no** hardcoded return-to-base:
the idle transport is a candidate the decision loop re-tasks like any other, or leaves holding.

## De-virtualisation

Unchanged in spirit ([`opcom_plan.md` §The virtualisation boundary](opcom_plan.md#the-virtualisation-boundary)):
when a carrying pair streams in near a player, both spawn and the rider is `moveInCargo`'d into the hull if it
fits, else dropped beside it (the current simplification, not a tied abort). The drop-cell intent is lost once
the pair is live — they go independent. Because the transport is now re-taskable, a transport that survives
its live spell re-virtualises as a free transport, consistent with the lifecycle above.

## Migration

From the shipped Phase 3 ferry. Code:

- [`fnc_opcom_ferry.sqf`](../../../src/duws/server/opcom/fnc_opcom_ferry.sqf): `ferryStep` carry phase targets
  `dropCell` (not the rider's target); on arrival the transport reverts to a free `guard` transport instead of
  `done`; the rider replans drop-cell → target.
- The tasking record ([`fnc_opcom_recruit.sqf`](../../../src/duws/server/opcom/fnc_opcom_recruit.sqf)) gains a
  `dropCell` field (default `[]` → resolves to the rider's target at bind time).
- The `board` verb ([`fnc_opcom_debug_task.sqf`](../../../src/duws/server/opcom/fnc_opcom_debug_task.sqf)) and
  the in-game menu's Ferry flow ([`fnc_debug_opcom.sqf`](../../../src/duws/server/debug/fnc_debug_opcom.sqf),
  [`fnc_debug_opcom_pick.sqf`](../../../src/duws/client/debug/fnc_debug_opcom_pick.sqf)) gain a drop-cell
  map-pick after the rider pick, defaulting to the rider's target if cancelled.

Docs, same change (per the plan-consistency rule): rewrite
[`opcom_plan.md` §Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight) to a summary that points
here; fix its "unload at the destination" line to name the drop cell as a deliberate choice; add to the
Transport valuation ([`opcom_plan.md` §Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)) that it
also picks the drop cell and the transport's post-drop job; note in §Commitment that a ferry dismount reuses
the safe rally.

## Out of scope

- **Explicit load** — rejected; load is the implicit consequence of issuing the ferry.
- **Multi-rider transports** — capacity stays one virtual rider of any size.
- **Mid-transit re-route of the drop cell** — a new `board` re-issues instead; no in-flight edit.
- **Auto return-to-base pathing** — the freed transport is a re-task candidate, not a unit with a homing
  behaviour of its own.

## Phase 4 hooks

The Transport action's appraisal must now also (a) choose the drop cell — the safe rally for a ground assault,
or the target where a drop-on-objective is wanted — and (b) decide the freed transport's next job. Both are
decision-loop work; Phase 3 exposes the drop cell and the re-taskable lifecycle for the hand harness to drive.
