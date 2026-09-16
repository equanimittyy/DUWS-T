# Audit: opcom_plan.md

A full-document review of [`opcom_plan.md`](opcom_plan.md) and its Phase 4a spec
[`phase_4_decision_loop.md`](phase_4_decision_loop.md), cross-checked against the shipped code under
`src/duws/server/warcom/opcom/`. It tracks what the plan still has to settle; each item folds into the plan
once it is decided.

## Verdict

**The mechanism is sound; the Phase 4a scoring is not ready to build.** Perception is strictly separated from
truth, state is serialisable by construction, locality and no-retreat follow documented engine gotchas, and the
phase order is forced by read dependencies. Phases 1–3 (perception, force weighting, tasking / movement / ferry)
ship and match the plan's Shipped table, except the contested draw-lock
([below](#plan-out-of-step-with-code)); the Phase 3 live playtest is pending.

The score's shape (`archWeight × P(win) × Value / Cost`, Value and Cost both in AP) holds, but several Value and
Cost definitions break it, and the Phase 4a spec leans on prices, wrappers and a candidate table that do not
exist. Those gaps block the decision loop and are listed first.

## Blocking — Phase 4a

- **Defensive Value is not in AP and reads the wrong signal.** Build, Reinforce and Fortify multiply worth by
  threat (`opcom_plan.md:134-137`). Threat is `_ene`, a force magnitude, so Value comes out in AP × force (AP ×
  force² for Fortify); and threat shifts tick to tick, while the truck runs and tier buys it would drive take
  minutes and stand for the campaign. Decided:
  - Threat drives only the fast actions: Intercept (QRF) and attack staging. Build, Reinforce and Fortify never
    read it.
  - Defensive Value = **worth × exposure × gain**, all read from slow state:
    - **worth** is the holding's fixed AP worth. A zone's is `_points`, its radius ÷ 10 (35–50 at the default
      radii). A town's is its level `civ_town_ap` (1–5, a rank by building count within the campaign's towns,
      `fnc_civ_init_Tomata.sqf:199`, the same figure its income pays) × a tunable 5, so 5–25: always below a zone.
    - **exposure** (0–1) is how close the holding sits to BLUFOR-held ground. OPCOM knows the owner of every zone
      and town for free, a territorial fact like the grid's nominal BLU-zone deposit, so exposure moves only when
      ground changes hands. Exposure is 1 within 5 km of BLUFOR-held ground and falls in a straight line to a
      floor of 0.2 at 10 km (tuning values).
    - OPCOM holds the player HQ's position from the start behind a hidden flag, and a hidden HQ counts toward
      nothing. The first sighting of a BLUFOR group within K = 2 cells of the HQ flips the flag for good, and the HQ
      counts as BLUFOR ground from then on. Every sensor writes through `fnc_opcom_belief_upsert`, so the flip
      check sits there once. BLUFOR holds no zone or town at campaign start, so exposure sits at its floor
      everywhere until the first capture or the HQ's reveal, and OPCOM defends evenly until then.
    - **gain** (0–1) is the force the purchase adds ÷ the force the holding fields at full strength and top tier.
  - Build splits by where the hardpoint stands:
    - A **zone hardpoint** is scored as above, with gain the emplacement's force share, gated by the zone's
      hardpoint cap (`fnc_hardpoint_zone_cap`), and placed by the existing in-zone draw. Nothing else constrains
      it.
    - A **standalone hardpoint** takes its own Value from coverage of the whole map, not of any one zone: weighted
      toward OPFOR's holdings, and rewarding cover over sparse sectors between zones. A zone's ring already
      defends the zone. Per band grid cell:
      - **need** (AP) is each OPFOR holding's worth spread over nearby cells, fading with distance, plus a flat
        base on every band cell for the sparse sectors, all scaled by the cell's exposure. A holding pulls harder
        than an open gap, but not so hard that hardpoints cluster around zones: the ratio is a tunable constant,
        starting at 2–3×.
      - **Asset hardpoints emit need.** A standing radio tower, artillery battery, mortar pit or OP spreads need
        around itself like a small holding worth its build price (tuned later), so it becomes an asset worth
        protecting. Radios and OPs site out in the wilderness by their own placement logic, and the network of
        other hardpoints builds up around them; they are what drives cover into the gaps between zones. An asset
        never stands in a zone's ring, which fields only the offensive types it already rolls
        (`DUWS_hardpointWeightZone`: MG, AT, GMG, ROADBLOCK).
      - **cover** (0–1) is how well standing OPFOR hardpoints protect the cell, zone rings included. Each
        hardpoint within K = 2 cells (Chebyshev, a 5 × 5 block) covers half of what is left: 0, 0.5, 0.75, 0.875.
        Every hardpoint type shares that one reach.
      - A candidate cell's Value is the sum over its 5 × 5 block of need × the rise in cover the new hardpoint
        makes, so a hardpoint beside others earns little. `fnc_hardpoint_spawn_sited` then sites it within that
        cell. Both layers change only when a hardpoint is built or cleared, or ground changes hands.
  - When this folds into the plan, also fix `opcom_plan.md:231` and `:263-264` (Build targets and sites off
    threat), `phase_4_decision_loop.md:79` (`fnc_opcom_grid_read`; 4a no longer reads the grid) and `:246-247`
    (the verification expects a Fortify or Build answer to a believed BLUFOR build-up), and add the HQ flag to
    the [§Persistence](opcom_plan.md#persistence) contract.
- **The two docs disagree on the truck flow.** The plan counts a truck as on hand when one is idle *or affordable
  this tick* (`opcom_plan.md:252`), which makes hire and dispatch one commit. Phase 4a gates on a truck that
  exists, hires through a separate Recruit(supply) commit and dispatches on a later tick
  (`phase_4_decision_loop.md:156-165`), and its Rapport section hires inline as well
  (`phase_4_decision_loop.md:190`). Recruit(supply) is valued by the best delivery the gate dropped, so a gated
  delivery still needs its Value computed before the gate removes it.
- **The zone-side garrison wrappers are missing from Phase 4a.** The plan lists them as not built
  (`opcom_plan.md:341-345`), but the Phase 4a file list omits them. Whether the generation roll caps a zone's tier
  must close before zone Fortify can score: zones roll tier 1–4 weighted toward IV (`fnc_zone_tier_roll`), so most
  have one step of headroom or none.
- **A standalone Build cannot site at chosen ground with the helpers Phase 4a names.** `fnc_hardpoint_seed_radio`,
  and `fnc_hardpoint_lay` with `fnc_hardpoint_band_anchor` / `_band_cand`, sample random band ground and take no
  target. The directed builder is `fnc_hardpoint_spawn_sited` (type and anchor, `fnc_hardpoint_place.sqf:184`); a
  zone Build keeps the existing in-zone draw.
  Every builder must run spawned — an emplacement registered near a player crews inline and sleeps
  (`fnc_hardpoint_place.sqf:212`) — so a `fnc_opcom_deliver` called straight from `fnc_opcom_task_step` stalls
  the OPCOM tick.
- **Build's type choice reads the wrong ladder.** Phase 4a picks the errand type `tower` / `band` / `topup` "by
  the earned-AP ladder" (`phase_4_decision_loop.md:169`), but those are siting modes; the plan's ladder unlocks
  weapon types (OP, MG, AT, AA, mortar, artillery).
- **The candidate enumeration table is gone.** The trim of the plan to the forward spec deleted the per-action
  "targets swept" table, but `phase_4_decision_loop.md:134` still sends the reader to it, and `:123` cites a loop
  description (score inside `isNil`, execute outside) that the plan no longer holds. Rapport's target is left as
  "a town in reach", with no reach defined.

## Deferred — the OPCOM cost sweep

One pass prices everything OPCOM buys, unit hires and builds included. It still gates Phase 4a, which cannot
score an action without its Cost.

- **Rapport is nearly free.** It spends no AP of its own, and its only Cost is the courier truck at
  `ceil(2 × OPCOM_AP_PER_FORCE)` = 2 AP (`truck` prices as `car_unarmed`, `fnc_opcom_force.sqf`). A level-5 town's
  −3 step from neutral is worth 7.5 AP, a score of 3.75 against the 0.2–1 of a defensive buy, so OPCOM turns towns
  for almost nothing.
- **Unit hires** cost `ceil(force × OPCOM_AP_PER_FORCE)` (`fnc_opcom_recruit.sqf:14`), the rate that also prices
  the courier truck.
- **Reinforce and Fortify have no price.** Phase 4a reuses only the hardpoint build prices
  (`phase_4_decision_loop.md:107`), and the town hooks `fnc_town_garrison_reinforce` and
  `fnc_town_garrison_setTier` charge nothing. What a zone costs against a town is open too.
- **Asset hardpoint prices:** an asset hardpoint emits need worth its build price, but only the radio tower has
  one (`OPCOM_AP_TOWER`); the OP, mortar pit and artillery battery have none yet.

## Plan out of step with code

- **The build ladder predates the five-tier economy.** The garrison / unlock table and the indirect-fire unlocks
  key off 40 / 100 / 136 AP (`opcom_plan.md:271-276`, `:299`); the economy gates on
  `DUWS_ap_tier_rungs = 60, 150, 350, 600` (`fnc_economy_init.sqf:39`) through `WARCOM_opfor_tier`. Both tables
  need re-keying on the tiers. Hardpoint garrisons are fixed per type today (`DUWS_hardpointGarrison`), so the
  ladder's garrison column is unbuilt.
- **The contested draw-lock is listed as shipped.** The Shipped table says a contested zone locks its garrison
  units off any offensive draw (`opcom_plan.md:47`). No code does: `DUWS_fnc_opcom_zoneContested` gates only the
  ferry pool, the freed hull's home pick and the garrison settle, and Phase 4a defers the lock to 4b.
- **Phase 4a cites stale line numbers:**

| Cited | Now |
|---|---|
| `fnc_opcom_task_step.sqf:56-60,124-131` (supply stub) | `:79-85`, `:174-179` |
| `task_step:56` / `task_step:127` (delivery sites) | `:80` / `:175` |
| `task_step:39-41` (dead sweep) | `:58-60` |
| `fnc_opcom_task.sqf:52-58` (draw-lock) | no draw-lock; the lines strip a drawn garrison's reserve defender |
| `fnc_opcom_perception_run.sqf:16-39` (fault wrap) | `:17-67` |
| `fnc_createzone.sqf:129` (`selectRandomWeighted`), also cited at `opcom_plan.md:117` | `:117` |

## Resolved — Phase 3 (shipped)

The tasking-wiring phase is built and its plan-doc items are closed:

- **Router** shipped as **A\*** (octile heuristic, early exit on target, one search per tick); the plan says A\*.
- **Fast-airborne streaming gap** closed by a de-virt entry buffer
  ([§Shipped](opcom_plan.md#shipped-the-substrate-the-loop-drives)): a player must be within K on two
  consecutive ticks before a unit spawns live, so a jet crossing a ring never streams, whether or not a tick
  sample lands inside it. Recon detection keeps its single per-tick sample and the accepted blind spot
  ([§Open questions](opcom_plan.md#open-questions)).

## Remaining — deferred to a later phase

- **`defenseAbandoned` threat term (Phase 4b):** reads as a counterfactual grid rebuild, unaffordable per
  candidate. State the approximation — read `_gridEne` around the unit's own cell as the threat term — so the
  decision loop does not implement the literal counterfactual.
- **Orchestration:** the resolve predicate and capture handoff are specified
  ([§Templates](opcom_plan.md#templates-phase-5)); the open task is the verification the section calls out —
  confirm the zone-capture trigger fires for an AI-only fight with no player near, else have OPCOM's resolve call
  the capture functions itself.
- **Muster livelock (Phase 5):** a player who keeps reinforcing keeps raising the muster bar
  (`opcom_plan.md:172-176`), and nothing ends the muster — the plan has no abandon rule. Mustering needs an
  abandon condition before Phase 5 builds it.
- **Belief persistence (open question):** belief is keyed by group `netId` (`fnc_opcom_sense.sqf`), which is not
  stable across a save/load — a persisted store would restore rows whose keys never match again. The grid and its
  coverage layer already rebuild from cold (`fnc_opcom_grid_init.sqf`). Cheapest resolution: decide *not* to
  persist belief and close the open question ([§Open questions](opcom_plan.md#open-questions)).
- **Minor underspecifications** (fine to leave for tuning, worth a word each when their phase lands): Intercept's
  "near own ground" radius, and the zero-balance edge in the front-line definition (sign-0 cells).

## Watch items — not defects

- **Grid rebuild cost.** Zeroing both layers over the play box plus depositing every source each 5 s tick runs in
  scheduled space and should be fine, but the plan budgets wall-clock only to the scoring pass. Measure the
  rebuild once under a full map before the decision loop stacks scoring on the same tick.
- **Nominal enemy deposit on empty BLU zones** (`OPCOM_GRID_ZONE_ENEMY_FORCE`, 8) means OPCOM never sees an
  undefended zone as empty. Belief-consistent (territorial facts are free, strength is not); the constant is the
  knob that sets baseline OPCOM caution.

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
