# Audit: opcom_plan.md

Verdict of a full-document review of [`opcom_plan.md`](opcom_plan.md) and
[`phase_1_belief_and_grid.md`](phase_1_belief_and_grid.md), cross-checked against the shipped Phase 1
code under `src/duws/server/opcom/`. Written for the agent that acts on it: each finding names the
location and the fix.

## Verdict

**The plan is sound.** The architecture is coherent and engine-aware: perception is strictly separated
from truth, the score is dimensionally consistent (AP-return ROI, no ad-hoc normalisation), state is
serialisable by construction, locality and no-retreat rules follow documented engine gotchas, and the
phase order is forced by read dependencies. Phase 1 as built matches its spec. Before Phase 2+ proceeds,
fix two internal contradictions (§A), close one specification gap (§B1), and sweep the statements that
Phase 1 landing has made stale (§C).

## A. Internal contradictions — fix in the plan before Phase 3

1. **Intent expiry clock is specified twice, differently.** The intent record table says
   `expiry — time plus the intent's own lifetime` (opcom_plan.md:431), and §Unit tasking reinforces
   "`time`, not `diag_tickTime`" (:478-479). But §The loop says "intent expiries and belief age count
   in **ticks**" (:671), and §Persistence says time-based fields store on `time` as remaining durations
   (:1098-1100). Pick one clock for intents and state it in all three places. Ticks is the safer pick:
   belief already ages in ticks, the counter persists with the mission namespace, and one clock avoids
   a mixed-unit comparison bug in the commitment code.

2. **Recruit's candidate count.** The enumeration table says Recruit sweeps "one — the locked prize"
   (opcom_plan.md:267), but §Value and §What the commander spends on define Recruit as one candidate
   **per hireable type** (combat/armor/recon/supply), each valued by the best action that type unlocks
   (:344-352, :744-748). Fix the enumeration row to "one per hireable type".

## B. Gaps and optimistic spots — resolve before the phase that depends on them

1. **Attack's endgame is unspecified** (blocks Templates phase). The plan says an Attack targets a
   BLU-held zone, the engine fights it out, and the template ends in a "resolve" phase — but never
   defines the resolve predicate or the ownership handoff: what detects that the defenders are gone,
   and what writes the zone flip (`WARCOM_zones_controled_by_*`, markers, the capture trigger in
   `fnc_createzone.sqf`). Zone capture triggers exist (`fnc_captured.sqf`, `fnc_blufor_cap.sqf`);
   verify they fire for an AI-only fight with no player near, and add a short section naming the
   handoff. The same applies to Intercept's and Rapport's resolve predicates.

2. **"Dijkstra … at 3844 nodes it is cheap" (opcom_plan.md:222) is optimistic for SQF.** With no
   priority queue, naive Dijkstra is O(n²) — ~15M operations worst case, seconds of scheduled time.
   The plan already keeps it out of the unscheduled block and recomputes rarely, which contains the
   damage; still, specify A* with a distance heuristic and early exit on reaching the target, plus a
   budget of at most one route search per tick.

3. **The streaming margin is argued against a 200 km/h player** (opcom_plan.md:581-583). A jet at
   700+ km/h crosses ~1 km (2 cells) per 5 s tick and can overfly an infantry ring (K=1) unstreamed —
   a virtual unit is invisible and unhittable to CAS. Either raise K against airborne players
   (precedent: the AA hardpoint's 5000 m air ring) or note the exploit as accepted.

4. **Belief keyed by group `netId` does not survive a save/load** — netIds are not stable across
   sessions. This weighs on the open question of belief persistence (opcom_plan.md:1154): a persisted
   store would restore rows whose keys never match again (they would decay out harmlessly, but
   keep-strongest dedup is lost). Cheapest resolution: decide *not* to persist belief and close the
   open question.

5. **`defenseAbandoned` implies a counterfactual grid** ("drop it from `_gridFri`, net threat …
   climbs", opcom_plan.md:381-384). A per-candidate grid rebuild is unaffordable; state the intended
   approximation — read `_gridEne` around the unit's own cell as the threat term — so Phase 2 doesn't
   implement the literal counterfactual.

6. **Minor underspecifications**, fine to leave for tuning but worth a word each: the AOI sensor's
   "delayed entry" delay (opcom_plan.md:59); Intercept's "near own ground" radius (:265); the
   zero-balance edge in the front-line definition (sign 0 cells, :206).

## C. Plan vs shipped code — statements Phase 1 landing made stale

Phase 1 (belief arrays, sense sweep, decay, grid init/rebuild, perception loop, overlay) is built and
matches the phase doc, including the documented men-count-not-firepower interim. Drift to sweep:

1. **"the dev overlay `fnc_debug_opcom_view` … today draws only AoI coverage circles"**
   (opcom_plan.md:246) and the Build-order row's "(AoI circles only today)" (:1127) are now false —
   the grid and belief render shipped (`fnc_debug_opcom_grid.sqf` / `fnc_debug_opcom_grid_draw.sqf`).

2. **The zone-flip sensor is claimed for Phase 1 but not implemented.**
   `phase_1_belief_and_grid.md:66-67` lists it in-phase; no writer of `DUWS_opcom_belief_*` exists
   outside `server/opcom/` — direct sighting is the sole sensor. Either implement the hook or move it
   to a later phase in both docs. Related comment drift: `fnc_opcom_belief_init.sqf` and
   `fnc_opcom_grid_rebuild.sqf` describe zone/FOB/HQ belief subjects that nothing writes yet.

3. **Loop restart wipes belief.** `fnc_opcom_perception_run.sqf:8` unconditionally calls
   `fnc_opcom_belief_init`, which reassigns all four arrays and zeroes `DUWS_opcom_tick`. §Persistence
   requires restore to feed state back "before the loop runs" (opcom_plan.md:1094) — that contract
   breaks if the loop ever restarts. State an init-if-nil contract for `belief_init` in the plan.

4. **No failure containment in the loop.** A throw in sense/rebuild kills the perception thread
   silently for the rest of the mission; the disabled `fnc_WARCOM_opf_hardpoints.sqf:71-72` wrapped
   its tick and logged. Worth one line in §The loop.

5. **Housekeeping** (code, not plan): stale doc path `docs/plans/opcom_plan.md` in
   `fnc_WARCOM_opf_hardpoints.sqf:8` and `fnc_createzone.sqf:160`; `fnc_init_OPFOR_WARCOM.sqf:149-151`
   still calls the launch "the OPCOM director" though it now starts perception only; dead `_key`
   assignment on the BLU branch of `fnc_opcom_grid_rebuild.sqf:38`.

## D. Watch items — not defects

- **Grid rebuild cost.** Zeroing 2×3844 cells plus depositing every source each 5 s tick runs in
  scheduled space and should be fine, but the plan gives a wall-clock budget only to the scoring pass.
  Measure the rebuild once under a full map before Phase 2 stacks scoring on the same tick.
- **Nominal enemy deposit on empty BLU zones** (`OPCOM_GRID_ZONE_ENEMY_MEN`) means OPCOM never sees an
  undefended zone as empty. This is belief-consistent (territorial facts are free, strength is not)
  and arguably good design; just note the constant is the knob that sets baseline OPCOM caution.
- **Land mask and connectivity are built with no consumer yet** — deliberate per the phase doc; the
  router lands in the Movement phase.
- **Muster livelock** (player keeps reinforcing, muster keeps buying) is bounded only by the
  hysteresis abandon; the open question on `OPCOM_COMMIT_HYSTERESIS` covers it.

## What is right and should not be reopened

- The belief/truth firewall, with sensors as the only truth readers.
- One dimensionless score (`archWeight × P(win) × Value / Cost`) with Value and Cost both in AP — no
  weight soup to tune.
- Serialisation discipline: positions not handles, numbers-only grid, `DUWS_`/`OPCOM_` prefix split,
  plain-global constants out of preprocessor reach.
- No-retreat derived from the engine's COMBAT-behaviour limitation rather than fought against, and the
  muster rule that keeps it from causing defeat in detail.
- Templates as the single execution form — a simple tasking is the degenerate template; no planner.
- One arbitrated wallet: every sink competes in the appraisal, nothing spends on its own clock.
- The build order, which tracks read dependencies exactly.
