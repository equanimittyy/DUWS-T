# Audit: opcom_plan.md

A full-document review of [`opcom_plan.md`](opcom_plan.md), cross-checked against the shipped Phase 1
code under `src/duws/server/opcom/`. The plan-doc gates it raised — which block the decision-loop and
orchestration phases, not the force-weighting phase next in line — are now closed in the plan; this doc is
kept as the tracker for the items deferred to the phase or code change that owns them.

## Verdict

**The plan is sound.** Perception is strictly separated from truth, the score is dimensionally consistent
(AP-return ROI, no ad-hoc normalisation), state is serialisable by construction, locality and no-retreat
follow documented engine gotchas, and the phase order is forced by read dependencies. Phase 1 as built
matches its spec.

The gates that blocked the decision-loop and template work are resolved in `opcom_plan.md`: the
intent-clock contradiction (now ticks everywhere), Recruit's candidate count (one per hireable type), the
Attack/Intercept/Rapport resolve predicate and ownership handoff, and the stale-statement sweep from
Phase 1 landing. What remains is later-phase design and code housekeeping, tracked below against the
change that owns each.

## Remaining — code housekeeping (any time; no design decision)

Not plan defects; correct when next touching these files.

- **Stale doc path** `docs/plans/opcom_plan.md` in `fnc_WARCOM_opf_hardpoints.sqf:8` and
  `fnc_createzone.sqf:160` — the plan now lives at `docs/plans/opcom/opcom_plan.md`.
- **Naming drift**: `fnc_init_OPFOR_WARCOM.sqf:149-151` still calls the launch "the OPCOM director"
  though it starts perception only.
- **Dead `_key`** on the BLU branch of `fnc_opcom_grid_rebuild.sqf` — computed every zone, used only in
  the else branch. Hoist into the else.
- **Comment drift**: `fnc_opcom_belief_init.sqf` and `fnc_opcom_grid_rebuild.sqf` describe zone / FOB / HQ
  belief subjects that nothing writes yet — only direct sighting is live. Trim to what ships, or add the
  writer when its sensor lands.

## Remaining — deferred to a later phase

- **Movement (Phase 3 — the tasking-wiring phase):**
  - The router is specified as Dijkstra; use A* with a distance heuristic, early exit on the target, and
    a budget of one route search per tick. The connectivity mask already prunes most of the 3844 cells, so
    the cost is contained — but say A* in the plan before the phase builds it.
  - The streaming margin is argued against a 200 km/h player; a jet at 700+ km/h overflies an infantry
    ring (K=1) unstreamed, invisible to CAS. Either raise K against airborne players (precedent: the AA
    hardpoint's 5000 m air ring) or note the exploit as accepted.
  - `defenseAbandoned` reads as a counterfactual grid rebuild, which is unaffordable per candidate. State
    the approximation — read `_gridEne` around the unit's own cell as the threat term — so the decision
    loop does not implement the literal counterfactual.
- **Orchestration:** the resolve predicate and capture handoff are now specified
  ([§The resolve phase](opcom_plan.md#the-resolve-phase-what-ends-a-template)); the open task is the
  verification the section calls out — confirm the zone-capture trigger fires for an AI-only fight with no
  player near, else have OPCOM's resolve call the capture functions itself.
- **Belief persistence (open question):** belief is keyed by group `netId` (`fnc_opcom_sense.sqf`), which
  is not stable across a save/load — a persisted store would restore rows whose keys never match again.
  Cheapest resolution: decide *not* to persist belief and close the open question
  ([§Open questions](opcom_plan.md#open-questions)).
- **Minor underspecifications** (fine to leave for tuning, worth a word each when their phase lands): the
  AOI sensor's delayed-entry delay, Intercept's "near own ground" radius, and the zero-balance edge in the
  front-line definition (sign-0 cells).

## Watch items — not defects

- **Grid rebuild cost.** Zeroing 2×3844 cells plus depositing every source each 5 s tick runs in
  scheduled space and should be fine, but the plan budgets wall-clock only to the scoring pass. Measure the
  rebuild once under a full map before the decision loop stacks scoring on the same tick.
- **Nominal enemy deposit on empty BLU zones** (`OPCOM_GRID_ZONE_ENEMY_MEN`) means OPCOM never sees an
  undefended zone as empty. Belief-consistent (territorial facts are free, strength is not) and arguably
  good design; the constant is the knob that sets baseline OPCOM caution.
- **Land mask and connectivity are built with no consumer yet** — deliberate; the router lands in Movement.
- **Muster livelock** (player keeps reinforcing, muster keeps buying) is bounded only by the hysteresis
  abandon; the open question on `OPCOM_COMMIT_HYSTERESIS` covers it.

## What is right and should not be reopened

- The belief/truth firewall, with sensors as the only truth readers.
- One dimensionless score (`archWeight × P(win) × Value / Cost`) with Value and Cost both in AP.
- Serialisation discipline: positions not handles, numbers-only grid, `DUWS_`/`OPCOM_` prefix split,
  plain-global constants out of preprocessor reach.
- No-retreat derived from the engine's COMBAT-behaviour limitation, and the muster rule that keeps it from
  causing defeat in detail.
- Templates as the single execution form — a simple tasking is the degenerate template; no planner.
- One arbitrated wallet: every sink competes in the appraisal, nothing spends on its own clock.
- The build order, which tracks read dependencies exactly.
