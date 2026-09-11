# OPCOM Phase 4 — the decision loop

Phase 4 of [`opcom_plan.md`](opcom_plan.md), in that plan's [§Build order](opcom_plan.md#build-order).
Phase 1 shipped perception; Phase 2 made force real (firepower weighting); Phase 3 wired recruitment,
tasking, movement and the ferry under manual control (the debug harness). Phase 4 puts a *decision* on the
tick: each pass, score the actions the commander can afford, commit one, and spend Army Power — replacing
the hand-drive harness ([`fnc_opcom_debug_task.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_debug_task.sqf))
with the appraisal.

This is the implementation spec; the design it builds is in `opcom_plan.md` and is referenced, not restated.

## Scope: the whole loop, single-unit

Phase 4 is end-to-end — every action the appraisal can score, committed and resolved automatically — with
one boundary: an offensive action commits **one unit**, never a coordinated wave. The multi-unit forms are
Phase 5.

| In Phase 4 | Deferred to Phase 5 (Orchestration) |
|---|---|
| The appraisal spine: enumerate, gate, score, weighted-random pick, commit one, spend ([§Appraisal](opcom_plan.md#appraisal-expected-ap-return)) | Multi-unit **templates** — flank, encircle, probe ([§Templates](opcom_plan.md#templates-the-execution-forms)) |
| Real `P(win)` — the force ratio drives the offensive gate now that Attack/Intercept exist to consume it | **Mustering** and ROI-optimal force sizing ([§Cost](opcom_plan.md#cost-what-an-action-stakes)) — every P4 offensive is one unit |
| Every action: Bank, Reinforce, Fortify, Build, Recruit, Attack, Intercept, Rapport, Scout, Arty | The **band → template** pick ([§Action follows the force ratio](opcom_plan.md#action-follows-the-force-ratio)) — a P4 Attack is always the degenerate one-unit assault |
| Single-unit resolve per action | The generic template **runner** ([§The runner](opcom_plan.md#the-runner)) and its `resolve` phases |
| Full demand-driven Recruit ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)) | Arty **saturation / spotter** template and belief-staleness widening — P4 arty is one gun, one salvo |

`archWeight` stays a **flat stub** (1 for every class) through Phase 4 *and* Phase 5; the real per-class,
per-archetype table is **Phase 6** ([§Build order](opcom_plan.md#build-order),
[§The commander has an archetype](opcom_plan.md#the-commander-has-an-archetype)). Isolated in one file so
Phase 6 replaces it alone.

## What Phase 3 already ships (build on it, do not rebuild)

The tasking layer is live and hand-driven. Phase 4 adds the decision; most primitives exist.

| Already shipped | Where |
|---|---|
| The tasking record (a serialisable hashMap), the recruit menu, the speed / streamK / water tables | [`fnc_opcom_tasking_init.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_tasking_init.sqf) |
| Hire a menu row into a resting `garrison` unit, priced `ceil(force × OPCOM_AP_PER_FORCE)`, paid from the wallet | [`fnc_opcom_recruit.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_recruit.sqf) |
| Issue `assault` / `move` / `guard` to a resting unit, plan its route, arm the commit hold, draw a unit out of its garrison reserve | [`fnc_opcom_task.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_task.sqf) |
| The per-tick step: movement along the route, streaming in/out, ferry carry, garrison heal, status read | [`fnc_opcom_task_step.sqf`](../../../src/duws/server/warcom/opcom/taskings/fnc_opcom_task_step.sqf) |
| The commit **hold** — `fnc_opcom_task` sets `hold = tick + OPCOM_COMMIT_HOLD` and refuses to re-issue a held or live unit's order | `fnc_opcom_task.sqf:22,45` |
| The tick **fault-wrap** — the loop body is already in a `try`/`catch` naming `_stage` | `fnc_opcom_perception_run.sqf:16-39` |
| Enemy-ground worth `_points` for Value — already stamped into `zone_meta_array` | `fnc_createzone.sqf:30` |

Two Phase-3 gaps Phase 4 must close, both flagged in the P3 code:

- **Supply-arrival effects are stubbed.** A `move` carrying `supplyDrop` arrives and only *logs* "supply
  delivered" — it does not build, turn a town, or refill a garrison. The record carries a bare boolean, not
  *which* errand. See `fnc_opcom_task_step.sqf:56-60,124-131` ("mission plumbing lands with the actions that
  consume it in Phase 4"). Closed by [§Supply delivery](#supply-delivery-the-errand-and-fnc_opcom_deliver).
- **No contested draw-lock.** Drawing a `garrison` unit out for an offensive is unconditional; the code notes
  "A P4 draw-lock will refuse this while the zone is contested" (`fnc_opcom_task.sqf:47-48`). Closed by
  [§Commitment and the draw-lock](#commitment-and-the-draw-lock).

The order vocabulary is fixed at `assault` / `move` / `guard` / `garrison`. Every Phase-4 action maps onto
these: Attack → `assault`; Intercept → `move` then settle `guard`; Rapport / Build / town Reinforce / town
Fortify → `move` + an errand; Scout → `move`; Recruit → a resting `garrison` unit.

## Files

Under `src/duws/server/warcom/opcom/`, one function per file, each registered by a compile-path string in
`server_fnc_init.sqf` beside the Phase 1–3 functions (the misc-loader convention — callers use the variable
name, not `CfgFunctions`). Belief-reading files land in `belief/`, tasking-emitting files in `taskings/`.

New:

| File | Subsystem | Responsibility |
|---|---|---|
| `fnc_opcom_grid_read` | belief | The read API the score is defined on: point balance (`fri − ene`), threat (Σ enemy over a 3×3 cell block), and the force ratio `r = Σfri / (Σene + 1)` over that block ([§What reads it](opcom_plan.md#what-reads-it)). Pure reads over the live `DUWS_opcom_grid_fri` / `_ene` arrays |
| `fnc_opcom_actions` | taskings | The flat action list — each row its own gate, Value, Cost and *execute* closure. The extension point every later phase adds to |
| `fnc_opcom_appraise` | taskings | The scoring pass: enumerate `[action, target]` pairs, drop what the gate rejects, score the survivors, weighted-random over the top `OPCOM_PICK_TOP`, hand the one pick back for execution ([§Appraisal](opcom_plan.md#appraisal-expected-ap-return)) |
| `fnc_opcom_deliver` | taskings | Runs one courier's **errand** on arrival — build a hardpoint, step a town's rep, refill or upgrade a town garrison — then the truck is spent. Lives and dies with its truck: a truck killed en route delivers nothing, no AP refund |
| `fnc_opcom_archweight` | taskings | The flat stub — `[archetype, actionClass] → 1`. Isolated so Phase 6 replaces one file |

Extended in place:

| File | Change |
|---|---|
| `fnc_opcom_perception_run` | After the task step, run the scoring pass inside a fresh `isNil { }` block, then execute the one pick outside it (the route plan may yield). Slots between `_stage = "taskstep"` and the debug log |
| `fnc_opcom_task` | Add the contested-zone **draw-lock**: refuse to draw a `garrison` unit whose home zone holds live BLUFOR contact ([§Unit strength](opcom_plan.md#unit-strength)) |
| `fnc_opcom_task_step` | Replace the supply-arrival log stub with a `fnc_opcom_deliver` call (both the live-arrival and virtual-arrival branches); add the single-unit **resolve** check for an `assault` whose target zone is clear |

Reused, not rewritten:

| File / function | Use |
|---|---|
| `fnc_ap_adjust` (`["OPF", -_cost, _reason]`) | The only writer of `WARCOM_opfor_ap`. Every spend goes through it; the director is server-side and single, so nothing races it |
| `fnc_hardpoint_seed_radio`, `fnc_hardpoint_lay` (with `fnc_hardpoint_band_cand` / `_band_anchor` / `fnc_hardpoint_zone_cap`) | The Build errand's three per-type builds, drawn from the retired director ([§Build](#build)) |
| `fnc_town_rep_adjust` | The Rapport errand steps a town's `civ_town_rep` by −3 toward the −10 OPFOR turn ([§Rapport](#rapport)) |
| `fnc_zone_tier` / `fnc_zone_tier_roll` and the garrison-strength ledger (`DUWS_fnc_garrisonStrength`, `DUWS_fnc_garrisonUnlose`) | Fortify raises the tier and re-stamps potential; Reinforce restores lost tokens ([§Fortify](#fortify), [§Reinforce](#reinforce)) |
| The zone-capture path — the `EAST SEIZED` retake trigger in `fnc_createzone.sqf` and `fnc_zone_capture_ready` / `fnc_captured` | An Attack's resolve leaves the flip to this, never re-implementing ownership ([§Resolve](#resolve-single-unit)) |

The Phase-3 hand-drive harness `fnc_opcom_debug_task` stays — it is the manual override for play-testing,
not dead once the loop drives itself.

## Constants

In `server_var_init.sqf`, `OPCOM_` prefix, plain globals (out of a preprocessor macro's reach, like the
Phase 1 constants). Reuse the existing prices — `OPCOM_AP_TOWER` 30, `OPCOM_AP_BAND` 12, `OPCOM_AP_TOPUP` 8,
`OPCOM_AP_PER_FORCE` 1, `OPCOM_COMMIT_HOLD` 6 — do not add a second set. New this phase (all tune in play):

- `OPCOM_SCORE_DEADLINE` — wall-clock budget for the `isNil` scoring pass (worked example:
  `server/init_zones/fnc_moreUrban_locations.sqf`). Small; the candidate set is tens–low-hundreds of pairs.
- `OPCOM_PICK_TOP` — how many top-scored candidates the weighted random draws from
  ([§Weighted random](opcom_plan.md#weighted-random-over-the-top-few-not-the-best)).
- `OPCOM_PWIN_FLOOR` — the win-probability below which an offensive candidate is dropped unscored (a doomed
  assault never commits, [§Candidate enumeration](opcom_plan.md#candidate-enumeration-gate-then-score)).
- `OPCOM_ARTY_*` — one salvo's rounds and blast radius for the minimal fire mission ([§Arty](#arty)).

## The scoring pass on the tick

Slots into the loop after the task step, before the debug log. The score/pick runs inside `isNil { }`
(unscheduled, uninterruptible, **no `sleep`**); the *execute* runs after it, in scheduled space, because a
tasking action plans a route (A\*, may yield) — the same split the plan draws
([§The loop](opcom_plan.md#the-loop-against-the-engine)).

```
_stage = "appraise";
private _pick = isNil { call fnc_opcom_appraise };   // [actionId, target, roleUnit] or []
_stage = "commit";
if (!(_pick isEqualTo [])) then { _pick call (<the action's execute closure>) };
```

One pass:

1. **Enumerate** every action against its valid targets ([§Candidate enumeration](opcom_plan.md#candidate-enumeration-gate-then-score)) — the sweep table there.
2. **Gate** — spend actions drop when `Cost > WARCOM_opfor_ap` (a supply-gated build also drops with no truck
   on hand); commit actions drop when the roster holds no eligible unit, and an offensive drops below
   `OPCOM_PWIN_FLOOR`. Bank never drops.
3. **Score** each survivor `archWeight × P(win) × Value / Cost` (`archWeight = 1`).
4. **Pick** by weighted random over the top `OPCOM_PICK_TOP`; hand back the one pick.
5. **Execute** the pick — at most one commit per tick.

`P(win)`, `Value` and `Cost` are the plan's ([§The score](opcom_plan.md#the-score) onward), read through
`fnc_opcom_grid_read`. `P(win) = r² / (r² + 1)` is now live: economic actions read it as 1 (no combat
outcome), offensives read the real ratio.

## The actions

Each is a row in `fnc_opcom_actions`. Design (Value / Cost formulas, target semantics) is `opcom_plan.md`;
here is only how each *executes* and *resolves*. **Cost** for a commit action is
`Σ effForce × OPCOM_AP_PER_FORCE + defenseAbandoned`, where `defenseAbandoned` is approximated as `_gridEne`
around the drawn unit's own cell rather than a counterfactual grid rebuild
([audit](opcom_plan_audit.md)).

### Bank
The null action — no target, no Cost, a low flat score. Wins when nothing else clears the gate or scores
above it; the surplus stays in `WARCOM_opfor_ap`. Execute: nothing.

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

### Build
Raise a hardpoint on threatened / thin-line own ground. Always supply-gated: pay AP at commit, bind a
`supply` truck with a `["build", cell, type]` errand where `type ∈ {tower, band, topup}` picked by the
earned-AP ladder (and `archWeight`, flat here) at prices `OPCOM_AP_TOWER` / `OPCOM_AP_BAND` /
`OPCOM_AP_TOPUP`. On arrival `fnc_opcom_deliver` re-drives the retired director's build for that type —
`fnc_hardpoint_seed_radio` for a tower, `fnc_hardpoint_lay` (with the band or zone-topup candidate
functions) otherwise. The standalone director stays disabled; its per-type builds now run through the
appraisal, not its own clock.

### Recruit
Fill the roster ([§Recruit fills the roster](opcom_plan.md#actions-sinks-and-taskings)). Scored **once per
demand group** — generic force, `recon`, `supply`, `transport` — each valued by the best action that group
unlocks, so OPCOM hires exactly what it is short of (the full demand model,
[§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)):

- **Force** — scan the Attack candidates that fail the `OPCOM_PWIN_FLOOR` gate, take the richest prize, and
  value one hire at `prize × ΔP(win)`, the win-probability a single added unit buys against that target;
  choose the unflagged menu row whose `ΔP(win) / hire cost` is best. Self-terminating: once accumulated force
  clears the floor the prize becomes a live Attack and the demand drops to the next locked target. `ΔP(win)`
  is computed by adding the row's `fnc_opcom_force` value to `Σfri` over the target block and re-reading
  `P(win)`.
- **Recon** — the best Scout Value it would enable.
- **Supply** — the best delivery it would enable (a Rapport, or a Build / town Fortify / town Reinforce
  otherwise gated for want of a truck).
- **Transport** — the best Attack or Intercept it unlocks by making an out-of-reach objective reachable
  (across water, or nearer in transit than a foot unit) ([§Transport](opcom_plan.md#transport-carrying-a-unit-to-the-fight)).

Execute: `fnc_opcom_recruit` the winning row into the OPFOR-held zone nearest that demand; the unit rests in
`garrison` with no order. Resolves the same tick (a hire, not a march).

### Attack
Take a BLU-held zone. Draw the eligible roster unit with least transit to the target (subject to the
draw-lock), issue `assault` to the zone position via `fnc_opcom_task`. One unit only in Phase 4 — no band,
no muster. Resolve: [below](#resolve-single-unit).

### Intercept
Dispatch a mobile reserve to threatened own ground (a sighted player near a holding with no adequate local
garrison). Draw the least-transit eligible unit, issue `move` to the threatened cell; on arrival it settles
`guard` and holds. It goes live and fights through the streaming machinery when the player closes — no
`assault` order, because Intercept repositions a reserve, it does not charge. Resolve: [below](#resolve-single-unit).

### Rapport
Step a town toward the −10 OPFOR turn. Draw or Recruit a `supply` unit, issue `move` to the town with a
`["rapport", townKey]` errand. On arrival `fnc_opcom_deliver` calls `fnc_town_rep_adjust` for −3 and the
courier is spent. Resolve: the delivery, or the courier's death en route. The town *turning* is the
town-band system's, not the template's ([§Random events](opcom_plan.md#random-events-what-a-turned-town-does)).

### Scout
Route a `recon`-flagged unit's standing detection bubble through stale valuable ground. Draw the least-transit
recon unit, issue a plain `move` along the route; the reveal is the recon flag's standing sensor
([§Sensors](opcom_plan.md#sensors)) firing as it travels — no scout order phase. Resolve: arrival.

### Arty
One gun, one salvo — the minimal fire mission ahead of the Phase-5 saturation template. Target an observed
belief point in range of an owned indirect-fire hardpoint (`DUWS_hardpointComp_MORTAR` /
`DUWS_hardpointComp_ARTY`, classed `static_arty`), off cooldown, not inside the HQ circle. Emits **no**
tasking (0 roster units) — the gun is a resident hardpoint. Execute: `doArtilleryFire` on the sited gun's AI
gunner at the belief point, `OPCOM_ARTY_*` rounds. This depends on an unverified engine behaviour — see
[§Verification](#verification). If an AI gunner will not fire, fall back to a server-side shell-spawn reusing
the `client/supports/fnc_arty.sqf` mechanic. Value is the AP-worth of force expected killed.

## Supply delivery: the errand and `fnc_opcom_deliver`

The concrete close of the Phase-3 stub. Four actions cannot resolve at commit — they need a `supply` truck
to drive to a cell and be spent there: Build, Rapport, town Reinforce, town Fortify.

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

## Commitment and the draw-lock

Phase 4 needs **no separate intent store**: the Phase-3 tasking record *is* the intent for a tasking action,
and an economic action (Bank, zone Reinforce / Fortify) resolves the same tick it commits and needs no record
at all ([§Commitment](opcom_plan.md#commitment-intents-are-sticky)). The commit **hold** is already enforced
in `fnc_opcom_task` — the appraisal simply never re-commits a held or live unit, because `fnc_opcom_task`
refuses it.

Two adds:

- **The contested draw-lock.** A `garrison` unit whose home zone holds live BLUFOR contact is not drawable —
  a pressed zone's reserve feeds only its own defence ([§Unit strength](opcom_plan.md#unit-strength)). Add the
  test in `fnc_opcom_task`'s draw-out branch (`fnc_opcom_task.sqf:49`), so every caller — appraisal or harness
  — is bound by it. The lock lifts when contact clears.
- **The offensive gate.** An offensive candidate below `OPCOM_PWIN_FLOOR` is dropped in enumeration, so a
  doomed single-unit Attack never commits — it surfaces instead as Recruit demand (force) until the ratio
  clears.

## Resolve (single-unit)

The Phase-3 step reads a live group's status but never *resolves* an offensive. Phase 4 adds a minimal
per-order resolve in `fnc_opcom_task_step`; the richer template `resolve` phases are Phase 5.

- **Attack** (`assault`) — resolves when the target zone holds no live BLUFOR (a direct count within the zone
  radius, the group being live and in contact by now). The flip is **not** re-implemented: it reuses the
  `EAST SEIZED` retake trigger and `fnc_captured`, so ownership stays single-sourced. OPCOM owns only the
  precondition. **Pending verification** ([below](#verification)) that the retake trigger fires for an
  AI-only fight with no player near; if it does not, the resolve calls the capture functions itself.
  On resolve the surviving unit releases to `garrison` on the taken ground.
- **Intercept** (`move` → `guard`) — resolves when the threatened block is clear (the belief entries that
  scored it decayed or dropped, no live BLUFOR in the block). Nothing changes hands; the unit releases to
  `garrison` on the ground it was sent to hold.
- **Rapport / Scout / supply couriers** — resolve on arrival (delivery / reveal), already the shape
  `task_step` handles; the errand adds the effect, not a new resolve.

An engaged unit at resolve time fights its contact to a decision first (no-retreat,
[§Commitment](opcom_plan.md#commitment-intents-are-sticky)); a clear one releases immediately.

## Verification

Two engine behaviours gate Phase 4 and must be confirmed from the console before the code that depends on
them is trusted (nothing in the tree exercises either today):

1. **AI-only zone capture.** Stage an OPFOR assault group onto a BLUFOR-held zone with **no player near** and
   confirm the `EAST SEIZED` retake trigger fires and flips ownership. If it is gated on player proximity,
   the Attack resolve must call `fnc_captured` itself.
2. **AI-gunner `doArtilleryFire`.** In a sited mortar / SPG hardpoint with no player near, confirm the AI
   gunner executes `doArtilleryFire` and rounds land. If not, Arty uses the `fnc_arty` shell-spawn fallback.

Otherwise, with the Phase-1 grid overlay and the AP debug readout: a believed BLUFOR build-up near own ground
raises `_gridEne`, and OPCOM answers — Fortify or Build the pressured holding, Recruit force against an
out-of-reach prize, dispatch an Attack once `P(win)` clears the floor, Intercept a QRF onto threatened ground
— one `fnc_ap_adjust` `"OPF"` debit per commit, at most one commit per tick, each logged with its reason.
With no threat and a full line it Banks and `WARCOM_opfor_ap` climbs. All checkable against a live player.
