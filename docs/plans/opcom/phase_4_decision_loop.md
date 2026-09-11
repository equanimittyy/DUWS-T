# OPCOM Phase 4a — the decision loop: thinking harness and defensive economy

Phase 4 of [`opcom_plan.md`](opcom_plan.md), in that plan's [§Build order](opcom_plan.md#build-order).
Phase 1 shipped perception; Phase 2 made force real (firepower weighting); Phase 3 wired recruitment,
tasking, movement and the ferry under manual control (the debug harness).

Phase 4 puts the first *decisions* on the tick and ships in two cuts; **this doc is Phase 4a — the thinking
harness and the defensive economy.** Each pass, score the actions the commander can afford, commit one, and
spend Army Power — replacing the hand-drive harness
([`fnc_opcom_debug_task.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_debug_task.sqf))
with the appraisal for the non-combat side of the war. The offensive cut (Phase 4b — single-unit Attack,
Intercept, Scout, Arty) and the multi-unit orchestration of those offensives (Phase 5) build on this same
spine.

This is the implementation spec; the design it builds is in `opcom_plan.md` and is referenced, not restated.

## Scope: the harness and the defensive economy

Phase 4a is the appraisal spine (the "thinking" harness) plus the actions that spend Army Power without a
fight — build up, supply, sway. It stands the loop up end-to-end for those actions: enumerate, gate, score,
pick, commit, spend, and (for the supplied actions) deliver on arrival. **No offensive** — nothing draws a
garrison unit out to attack, intercept, scout, or shell. The commander that fields these actions defends and
grows; it does not yet take ground. Making it fight is Phase 4b (single-unit); coordinating those fights is
Phase 5.

| In Phase 4a | Deferred (4b = single-unit offensive, P5 = orchestration) |
|---|---|
| The appraisal spine: enumerate, gate, score, weighted-random pick, commit one, spend ([§Appraisal](opcom_plan.md#appraisal-expected-ap-return)) | **Attack** and **Intercept** *(4b)* — drawing a unit out to fight as an individual order; the multi-unit templates over them are P5 ([§Templates](opcom_plan.md#templates-the-execution-forms)) |
| Bank, Recruit (supply demand only), Build, Reinforce, Fortify, Rapport | **Scout** and **Arty** *(4b)* — the recon draw and the one-gun fire mission; the arty saturation / spotter template is P5 |
| `P(win)` a flat **1** — every action here is uncontested economics, no combat outcome to weigh | Real `P(win)` *(4b)* — the force ratio `r² / (r²+1)` driving the offensive gate ([§The score](opcom_plan.md#the-score)), and `OPCOM_PWIN_FLOOR` |
| Supply-arrival **delivery** — the errand and `fnc_opcom_deliver`, closing the Phase-3 stub | The contested **draw-lock** and single-unit **resolve** *(4b)* — both exist only once a unit is drawn out to fight ([§Unit strength](opcom_plan.md#unit-strength)) |
| Recruit scored on **supply demand** alone — hire a truck when a delivery is gated for want of one | Recruit's **force / recon / transport** demand groups *(4b)* — the offensives in 4b give their units a job ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)) |

`archWeight` stays a **flat stub** (1 for every class) through Phase 4 and Phase 5; the real per-class,
per-archetype table is **Phase 6** ([§Build order](opcom_plan.md#build-order),
[§The commander has an archetype](opcom_plan.md#the-commander-has-an-archetype)). Isolated in one file so
Phase 6 replaces it alone.

## What Phase 3 already ships (build on it, do not rebuild)

The tasking layer is live and hand-driven. Phase 4a adds the economic decision; most primitives exist.

| Already shipped | Where |
|---|---|
| The tasking record (a serialisable hashMap), the recruit menu, the speed / streamK / water tables | [`fnc_opcom_tasking_init.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_tasking_init.sqf) |
| Hire a menu row into a resting `garrison` unit, priced `ceil(force × OPCOM_AP_PER_FORCE)`, paid from the wallet | [`fnc_opcom_recruit.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_recruit.sqf) |
| Issue `move` / `guard` to a resting unit, plan its route, arm the commit hold | [`fnc_opcom_task.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_task.sqf) |
| The per-tick step: movement along the route, streaming in/out, ferry carry, garrison heal, status read | [`fnc_opcom_task_step.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_task_step.sqf) |
| The commit **hold** — `fnc_opcom_task` sets `hold = tick + OPCOM_COMMIT_HOLD` and refuses to re-issue a held or live unit's order | `fnc_opcom_task.sqf:22,45` |
| The tick **fault-wrap** — the loop body is already in a `try`/`catch` naming `_stage` | `fnc_opcom_perception_run.sqf:16-39` |
| Enemy-ground worth `_points` for Value — already stamped into `zone_meta_array` | `fnc_createzone.sqf:30` |

The one Phase-3 gap Phase 4a must close (flagged in the P3 code):

- **Supply-arrival effects are stubbed.** A `move` carrying `supplyDrop` arrives and only *logs* "supply
  delivered" — it does not build, turn a town, or refill a garrison. The record carries a bare boolean, not
  *which* errand. See `fnc_opcom_task_step.sqf:56-60,124-131` ("mission plumbing lands with the actions that
  consume it in Phase 4"). Closed by [§Supply delivery](#supply-delivery-the-errand-and-fnc_opcom_deliver).

The other P3 note — the contested draw-lock (`fnc_opcom_task.sqf:47-48`) — stays open. It gates drawing a
`garrison` unit out for an offensive, and Phase 4a draws no unit out to fight, so it lands with the
offensives in Phase 4b. Phase 4a only ever *recruits* (a fresh supply truck), never draws a garrison.

The order vocabulary is fixed at `move` / `guard` / `garrison` for this cut (`assault` arrives in 4b). Every
Phase-4a action maps onto these: Rapport / Build / town Reinforce / town Fortify → `move` + an errand;
Recruit → a resting `garrison` unit; zone Reinforce / zone Fortify → no tasking at all (a same-tick AP
spend).

## Files

Under `src/duws/server/warcom/opcom/`, one function per file, each registered by a compile-path string in
`server_fnc_init.sqf` beside the Phase 1–3 functions (the misc-loader convention — callers use the variable
name, not `CfgFunctions`). Belief-reading files land in `belief/`, tasking-emitting files in `taskings/`.

New:

| File | Subsystem | Responsibility |
|---|---|---|
| `fnc_opcom_grid_read` | belief | The read API the score is defined on, in the shape Phase 4a needs: point balance (`fri − ene`) and threat (Σ enemy over a 3×3 cell block) over the live `DUWS_opcom_grid_fri` / `_ene` arrays ([§What reads it](opcom_plan.md#what-reads-it)). The force ratio `r` and real `P(win)` land in Phase 4b with the offensives that weigh them; this cut reads `P(win)` as a flat 1 |
| `fnc_opcom_actions` | taskings | The flat action list — each row its own gate, Value, Cost and *execute* closure. The extension point every later cut adds to (Phase 4b appends Attack / Intercept / Scout / Arty) |
| `fnc_opcom_appraise` | taskings | The scoring pass: enumerate `[action, target]` pairs, drop what the gate rejects, score the survivors, weighted-random over the top `OPCOM_PICK_TOP`, hand the one pick back for execution ([§Appraisal](opcom_plan.md#appraisal-expected-ap-return)) |
| `fnc_opcom_deliver` | taskings | Runs one courier's **errand** on arrival — build a hardpoint, step a town's rep, refill or upgrade a town garrison — then the truck is spent. Lives and dies with its truck: a truck killed en route delivers nothing, no AP refund |
| `fnc_opcom_archweight` | taskings | The flat stub — `[archetype, actionClass] → 1`. Isolated so Phase 6 replaces one file |

Extended in place:

| File | Change |
|---|---|
| `fnc_opcom_perception_run` | After the task step, run the scoring pass inside a fresh `isNil { }` block, then execute the one pick outside it (the route plan may yield). Slots between `_stage = "taskstep"` and the debug log |
| `fnc_opcom_task_step` | Replace the supply-arrival log stub with a `fnc_opcom_deliver` call (both the live-arrival and virtual-arrival branches). No resolve check is added — Phase 4a emits no offensive to resolve |

Reused, not rewritten:

| File / function | Use |
|---|---|
| `fnc_ap_adjust` (`["OPF", -_cost, _reason]`) | The only writer of `WARCOM_opfor_ap`. Every spend goes through it; the director is server-side and single, so nothing races it |
| `fnc_hardpoint_seed_radio`, `fnc_hardpoint_lay` (with `fnc_hardpoint_band_cand` / `_band_anchor` / `fnc_hardpoint_zone_cap`) | The Build errand's three per-type builds, drawn from the retired director ([§Build](#build)) |
| `fnc_town_rep_adjust` | The Rapport errand steps a town's `civ_town_rep` by −3 toward the −10 OPFOR turn ([§Rapport](#rapport)) |
| `fnc_zone_tier` / `fnc_zone_tier_roll` and the garrison-strength ledger (`DUWS_fnc_garrisonStrength`, `DUWS_fnc_garrisonUnlose`) | Fortify raises the tier and re-stamps potential; Reinforce restores lost tokens ([§Fortify](#fortify), [§Reinforce](#reinforce)) |

The Phase-3 hand-drive harness `fnc_opcom_debug_task` stays — it is the manual override for play-testing,
not dead once the loop drives itself.

## Constants

In `server_var_init.sqf`, `OPCOM_` prefix, plain globals (out of a preprocessor macro's reach, like the
Phase 1 constants). Reuse the existing prices — `OPCOM_AP_TOWER` 30, `OPCOM_AP_BAND` 12, `OPCOM_AP_TOPUP` 8,
`OPCOM_AP_PER_FORCE` 1, `OPCOM_COMMIT_HOLD` 6 — do not add a second set. New this cut (both tune in play):

- `OPCOM_SCORE_DEADLINE` — wall-clock budget for the `isNil` scoring pass (worked example:
  `server/init_zones/fnc_moreUrban_locations.sqf`). Small; the candidate set is tens–low-hundreds of pairs.
- `OPCOM_PICK_TOP` — how many top-scored candidates the weighted random draws from
  ([§Weighted random](opcom_plan.md#weighted-random-over-the-top-few-not-the-best)).

`OPCOM_PWIN_FLOOR` and `OPCOM_ARTY_*` are Phase 4b — they gate offensives and the fire mission, neither in
this cut.

## The scoring pass on the tick

Slots into the loop after the task step, before the debug log. The score/pick runs inside `isNil { }`
(unscheduled, uninterruptible, **no `sleep`**); the *execute* runs after it, in scheduled space, because a
tasking action plans a route (A\*, may yield) — the same split the plan draws
([§The loop](opcom_plan.md#the-loop-against-the-engine)).

```
_stage = "appraise";
private _pick = isNil { call fnc_opcom_appraise };   // [actionId, target] or []
_stage = "commit";
if (!(_pick isEqualTo [])) then { _pick call (<the action's execute closure>) };
```

One pass:

1. **Enumerate** every action against its valid targets ([§Candidate enumeration](opcom_plan.md#candidate-enumeration-gate-then-score)) — the sweep table there.
2. **Gate** — spend actions drop when `Cost > WARCOM_opfor_ap`; a supply-gated action (Build, town Reinforce,
   town Fortify, Rapport) also drops when no `supply` truck is on hand to carry it. Bank never drops.
3. **Score** each survivor `archWeight × P(win) × Value / Cost` — with `archWeight = 1` and `P(win) = 1` this
   cut, the score is `Value / Cost`.
4. **Pick** by weighted random over the top `OPCOM_PICK_TOP`; hand back the one pick.
5. **Execute** the pick — at most one commit per tick.

`Value` and `Cost` are the plan's ([§The score](opcom_plan.md#the-score) onward), read through
`fnc_opcom_grid_read`. **Cost** for every Phase-4a action is a plain AP price — the hire cost for Recruit, the
build / tier / refill price for the spends. The `defenseAbandoned` term the plan adds to a commit's cost is
offensive-only (it prices the hole a drawn-out garrison leaves), so it lands in Phase 4b with the draws.

## The actions

Each is a row in `fnc_opcom_actions`. Design (Value / Cost formulas, target semantics) is `opcom_plan.md`;
here is only how each *executes* and *resolves*.

### Bank
The null action — no target, no Cost, a low flat score. Wins when nothing else clears the gate or scores
above it; the surplus stays in `WARCOM_opfor_ap`. Execute: nothing.

### Recruit
Fill the roster. Phase 4a scores **one demand group — supply** ([§Recruit fills the roster](opcom_plan.md#actions-sinks-and-taskings)):
a delivery worth doing (a Rapport, or a Build / town Fortify / town Reinforce) is gated for want of a truck,
so Recruit hires one. Value is the best such gated delivery's Value; the loop is self-terminating — once a
truck exists the delivery itself becomes the live commit and the supply demand falls back to the next gated
errand. The force / recon / transport demand groups wait for Phase 4b, which gives their units something to
do (there is no offensive to feed a fresh rifle squad in 4a).

Execute: `fnc_opcom_recruit` the `supply` menu row into the OPFOR-held zone nearest that demand; the truck
rests in `garrison` with no order. Resolves the same tick (a hire, not a march).

### Build
Raise a hardpoint on threatened / thin-line own ground. Always supply-gated: pay AP at commit, bind a
`supply` truck with a `["build", cell, type]` errand where `type ∈ {tower, band, topup}` picked by the
earned-AP ladder (and `archWeight`, flat here) at prices `OPCOM_AP_TOWER` / `OPCOM_AP_BAND` /
`OPCOM_AP_TOPUP`. On arrival `fnc_opcom_deliver` re-drives the retired director's build for that type —
`fnc_hardpoint_seed_radio` for a tower, `fnc_hardpoint_lay` (with the band or zone-topup candidate
functions) otherwise. The standalone director stays disabled; its per-type builds now run through the
appraisal, not its own clock.

### Reinforce
Refill a depleted garrison toward its current tier. **Zone**: pure AP spend, resolves the same tick —
restore lost tokens through the garrison-strength ledger (`DUWS_fnc_garrisonUnlose`), no courier. **Town**:
pay AP at commit, then bind a `supply` truck with a `["reinforce", townKey]` errand; the refill fires on
arrival ([§Supply delivery](#supply-delivery-the-errand-and-fnc_opcom_deliver)). Value scores the strength
deficit `1 − strength`, so a full garrison scores 0 and is never topped up.

### Fortify
Raise a garrison's tier ceiling. **Zone**: pure AP spend, resolves the same tick — raise the zone's tier var
(`fnc_zone_tier` store) and re-stamp its potential. **Town**: pay AP at commit, bind a `supply` truck with a
`["fortify", townKey]` errand; the tier raise fires on arrival. Value scores the force the next tier adds,
diminishing as tiers climb.

### Rapport
Step a town toward the −10 OPFOR turn. Recruit (or use a resting) `supply` unit, issue `move` to the town
with a `["rapport", townKey]` errand. On arrival `fnc_opcom_deliver` calls `fnc_town_rep_adjust` for −3 and
the courier is spent. Resolve: the delivery, or the courier's death en route. The town *turning* is the
town-band system's, not the template's ([§Random events](opcom_plan.md#random-events-what-a-turned-town-does)).

## Supply delivery: the errand and `fnc_opcom_deliver`

The concrete close of the Phase-3 stub, and the heart of this cut. Four actions cannot resolve at commit —
they need a `supply` truck to drive to a cell and be spent there: Build, Rapport, town Reinforce, town
Fortify.

- **The errand.** At commit the action stores an errand descriptor on the truck's tasking record —
  `["build", cell, type]`, `["rapport", townKey]`, `["reinforce", townKey]`, `["fortify", townKey]` — and
  issues the `move`. The errand replaces the bare `supplyDrop` boolean as the carrier of *what* to do on
  arrival (keep `supplyDrop` as the "self-delete on arrival" marker, or fold it into "errand is set").
- **Lives and dies with the truck.** The order binds to *that* truck, sent to that cell. On arrival
  `fnc_opcom_task_step` calls `fnc_opcom_deliver`, which switches on the errand kind and calls the reused
  writer, then the truck is deleted. Kill the truck en route and the order fails outright — no build, and the
  AP paid at commit is **not** refunded. This is the interdiction counterplay
  ([§Supply gates the town-side builds](opcom_plan.md#supply-gates-the-town-side-builds)).
- **AP is paid at commit, effect lands on arrival.** A spend action still debits its price when the appraisal
  commits it; only the *result* waits on the truck.
- **`fnc_opcom_deliver` is the one dispatch site.** Both the live-arrival branch (`task_step:56`) and the
  virtual-arrival branch (`task_step:127`) call it, replacing the two log stubs — one place to test each
  errand's effect in isolation.

## Commitment

Phase 4a needs **no separate intent store**: the Phase-3 tasking record *is* the intent for a supplied
action, and an economic action (Bank, zone Reinforce / Fortify) resolves the same tick it commits and needs
no record at all ([§Commitment](opcom_plan.md#commitment-intents-are-sticky)). The commit **hold** is already
enforced in `fnc_opcom_task` — the appraisal simply never re-commits a held or live unit, because
`fnc_opcom_task` refuses it.

The contested **draw-lock** and the offensive **P(win) gate** are Phase 4b. Phase 4a never draws a garrison
unit out (its only unit-producing action is Recruit, a fresh hire) and fights nothing, so neither guard is
reachable yet.

## Resolve

Phase 4a emits no offensive, so there is no combat resolve. The only thing to resolve is a **courier reaching
its cell**, which is already the shape `fnc_opcom_task_step` handles for a `move`; the errand adds the effect
(`fnc_opcom_deliver`), not a new resolve path. A truck killed en route is retired as a dead group by the same
sweep that clears any lost tasking (`task_step:39-41`), leaving the errand undone and the AP unrefunded.

The single-unit Attack / Intercept resolve — the group fighting its target to a decision, then releasing to
`garrison` on the ground — lands in Phase 4b with the offensives that need it.

## Verification

No engine-behaviour gates this cut — both of the earlier unknowns (AI-only zone capture firing the
`EAST SEIZED` retake trigger, and an AI gunner executing `doArtilleryFire`) belong to the offensives held for
Phase 4b. Phase 4a is checkable entirely against a live player with the Phase-1 grid overlay and the AP debug
readout:

- A believed BLUFOR build-up near own ground raises `_gridEne`, and OPCOM answers — **Fortify** or **Build**
  the pressured holding, resolving the zone spends the same tick and the supplied builds on truck arrival.
- With a town-supply / Rapport / Build worth doing but no truck on hand, OPCOM commits **Recruit(supply)**,
  then next tick commits the delivery and the truck drives out; a **truck killed en route** delivers nothing
  and refunds no AP.
- With no pressure and a full line it **Banks**, and `WARCOM_opfor_ap` climbs.

Each commit is one `fnc_ap_adjust` `"OPF"` debit, at most one per tick, logged with its reason.
