# OPCOM Phase 4 — the decision loop (draft: the economic slice)

**Early draft.** Written ahead of its phase and covering only the *economic* half of the decision loop
(Fortify, Build, Bank); the tasking-automation half — auto-Recruit and auto-issued orders over the P3
mechanism — is added when Phase 4 begins. Kept as a working draft, not a finished spec.

The decision loop is Phase 4 of [`opcom_plan.md`](opcom_plan.md), in that plan's
[§Build order](opcom_plan.md#build-order). Phase 1 shipped perception; Phase 2 makes force real
(firepower weighting); Phase 3 wires up recruitment, tasking and movement under manual control. Phase 4
puts a *decision* on the tick: score the actions the commander can afford, commit one, and spend Army
Power. This draft stops at the economic actions — the ones that emit no unit
([§Actions, sinks and taskings](opcom_plan.md#actions-sinks-and-taskings)): **Fortify, Build, Bank**. The
unit-dispatching actions (Attack, Intercept, Rapport, Recruit, Scout, Reinforce, Arty) drive the P3
mechanism and are the other half of this phase, not yet drafted here.

## Scope

The economic subset is deliberate: it exercises the whole appraisal spine — enumerate, gate, score,
weighted-random pick, commit one, spend — against actions that resolve the same tick they commit, so no
intent record, no unit, and no movement is needed to see the commander behave. The score
([§The score](opcom_plan.md#the-score)) runs in full with two draft simplifications, each a documented
swap point a later step replaces:

- **`P(win)` is 1 for an economic action** — a purchase has no combat outcome. The force-ratio `r`
  ([§P(win)](opcom_plan.md#pwin-the-force-ratio-lanchester-square)) is still built as a grid read (below),
  because Value reads the grid too, but it has no offensive consumer yet. The **band → template**
  selection ([§Action follows the force ratio](opcom_plan.md#action-follows-the-force-ratio)) is *not*
  built here — it selects an offensive form, and there is no offensive action to run it, so it lands with
  the Templates phase per the plan's do-not-pre-build rule ([§Implementation](opcom_plan.md#implementation)).
- **`archWeight` is flat** — a stub table returning 1 for every action class. The real per-class,
  per-archetype weights are Phase 5 ([§The commander has an archetype](opcom_plan.md#the-commander-has-an-archetype)).

## Files

Under `src/duws/server/warcom/opcom/`, split into `belief/` and `taskings/` by subsystem, one function per
file, each registered by a compile-path string in `server_fnc_init.sqf` beside the Phase 1–3 functions (the
misc-loader convention — callers use the variable name, not `CfgFunctions`). A new Phase 4 file lands in
whichever subsystem folder it reads.

| File | Responsibility |
|---|---|
| `fnc_opcom_grid_read` | The grid read API the score is defined on: point balance (`fri − ene`), threat (Σ enemy over a cell block), and the force ratio `r = Σfri / (Σene + 1)` over a 3×3 block ([§What reads it](opcom_plan.md#what-reads-it)). Pure reads over the live arrays |
| `fnc_opcom_actions` | The flat action list for this phase — Fortify, Build, Bank — each carrying its own gate, Value, Cost and execute step. The extension point every later phase adds its actions to |
| `fnc_opcom_appraise` | The scoring pass: enumerate `[action, target]` pairs, drop what the gate rejects, score the survivors, weighted-random over the top few, execute the one pick ([§Appraisal](opcom_plan.md#appraisal-expected-ap-return)) |
| `fnc_opcom_archweight` | The flat stub — `[archetype, actionClass] → 1`. Isolated so Phase 5 replaces one file |

Extended in place:

| File | Change |
|---|---|
| `fnc_opcom_perception_run` | After the grid rebuild, run `fnc_opcom_appraise` inside the tick's `isNil { }` block ([§The loop](opcom_plan.md#the-loop-against-the-engine)). Wrap the tick body so a throw is caught and logged, never killing the thread |

Reused, not rewritten:

| File | Use |
|---|---|
| `fnc_WARCOM_opf_hardpoints` | The build director shipped and disabled ([§What the commander builds](opcom_plan.md#what-the-commander-builds)); its spawn stays cut. The Build action re-drives its per-type build (`OPCOM_AP_TOWER`/`BAND`/`TOPUP`) through the appraisal instead of its own clock |
| `fnc_ap_adjust` | The only writer of `WARCOM_opfor_ap`. Every spend is `["OPF", -_cost, _reason] call fnc_ap_adjust`; the director is server-side and single, so nothing races it |

## Constants

In `server_var_init.sqf`, `OPCOM_` prefix, plain globals (out of a preprocessor macro's reach, like the
Phase 1 constants). The build prices already exist: `OPCOM_AP_TOWER` 30, `OPCOM_AP_BAND` 12,
`OPCOM_AP_TOPUP` 8 — reuse them, do not add a second set. New this phase:

- `OPCOM_SCORE_DEADLINE` — the wall-clock budget for the `isNil` scoring pass, the bound the worked
  example uses (`server/init_zones/fnc_moreUrban_locations.sqf`). Small; the candidate set is tens of pairs.
- `OPCOM_PICK_TOP` — how many top-scored candidates the weighted-random draws from
  ([§Weighted random](opcom_plan.md#weighted-random-over-the-top-few-not-the-best)).

## The scoring pass

Runs each tick after the rebuild, in the `isNil { }` unscheduled block so it cannot be interrupted
mid-pass — no `sleep` inside it, the route search (Phase 4) is the only thing kept outside. One pass:

1. **Enumerate** the three actions against their targets ([§Candidate enumeration](opcom_plan.md#candidate-enumeration-gate-then-score)):
   Fortify each own holding below its tier ceiling, Build each own threatened / thin-line cell, Bank the
   one null.
2. **Gate** — all three are spend actions, so drop any whose `Cost > WARCOM_opfor_ap`. Bank never drops.
3. **Score** each survivor `archWeight × P(win) × Value / Cost`, with `archWeight = 1` and `P(win) = 1`.
4. **Pick** by weighted random over the top `OPCOM_PICK_TOP`, and **execute** that one. At most one
   commit per tick.

## The actions

Value and Cost are the plan's ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play),
[§Cost](opcom_plan.md#cost-what-an-action-stakes)); this phase reads them through `fnc_opcom_grid_read`.

- **Fortify** — target an own town / zone below its tier ceiling. **Cost** the tier purchase price.
  **Value** `own worth × threat × force the next tier adds` (threat = enemy influence on the holding's
  cell; the tier increment from the composition table, diminishing as tiers climb). **Execute** raise the
  garrison tier — the town-band ladder ([§Town garrisons](opcom_plan.md#town-garrisons-i-through-iv)) or
  the zone tier.
- **Build** — target an own threatened or thin-line cell. **Cost** `OPCOM_AP_TOWER`/`BAND`/`TOPUP` by the
  type the earned-AP ladder allows ([§The director and the escalation ladder](opcom_plan.md#the-director-and-the-escalation-ladder)),
  picked by `archWeight` (flat here). **Value** `own worth × threat` at the cell. **Execute** the reused
  `fnc_WARCOM_opf_hardpoints` build.
- **Bank** — the null action. No Cost, no Value beyond a floor; it wins when nothing else clears the gate
  or scores above it, and the surplus simply stays in `WARCOM_opfor_ap` ([§What the commander spends on](opcom_plan.md#what-the-commander-spends-on)).

## Verification

With the OPCOM grid overlay up (Phase 1) and the AP debug readout: a believed BLUFOR build-up near own
ground raises `_gridEne` on those cells, and OPCOM answers by Fortifying the pressured holding or Building
toward the threatened cell — an `fnc_ap_adjust` `"OPF"` debit per commit, one per tick at most, logged
with its reason. With no threat and a full line it Banks, and `WARCOM_opfor_ap` climbs. All checkable
against a live player from the debug console with no unit code in play — the point of stopping the phase
at the economic actions.
