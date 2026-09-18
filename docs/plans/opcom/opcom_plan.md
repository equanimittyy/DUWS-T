# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns, tasks
squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and faucets are the economy's
([`economy_second_pass.md`](../economy_second_pass.md#army-power)); the hardpoint mechanics it draws from are
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md); the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting).

One thread runs on a 5 s tick (`OPCOM_TICK_PERIOD`): **perception** keeps the enemy's belief about BLUFOR,
**appraisal** scores candidate actions and picks one, and **commitment** turns the pick into a sticky intent.

Phases 1–3 and Phase 4 Stage A are shipped, and the code under `src/duws/server/warcom/opcom/` is the source of truth
for them. This doc specifies what remains. The sections marked **WIP** (Stage B onward) are first-pass decisions: they
change as each chunk is built and played.

## Status

| Phase | State |
|---|---|
| 1 — Perception, 2 — Force weighting, 3 — Recruitment & tasking wiring (+ transport ferry) | **shipped** |
| 4, Stage A — Orders, driven by hand: 4.1 supply errands, 4.2 live engagement + the Attack order, 4.3 the Intercept order, 4.4 fire missions | **shipped** |
| 4, Stage B — The decision loop: 4.5 spine + zone economy, 4.6 trucks + towns + Rapport, 4.7 need and cover fields + standalone hardpoints, 4.8 QRF + Attack decisions, 4.9 Scout, then one-gun Arty | [§Appraisal](#appraisal-phase-4) — WIP |
| 5 — Orchestration: multi-unit templates + mustering | [§Templates](#templates-phase-5) — WIP |
| 6 — Archetype: per-class weight sets and the commander's patience | [§Archetype](#archetype-phase-6) — WIP |

The ordering is forced by what the next phase reads. Do not pre-build later phases: the tuning constants and
engine-contact behaviours only settle by running the core.

## Shipped: the substrate the loop drives

The code is the source of truth. What new work must hold to:

- **Belief, never truth.** The commander plans against belief; only the sensors read live player state. Belief
  tracks groups, not players, and stores positions, never handles.
- **The grid** rebuilds `_fri` (known OPFOR) and `_ene` (believed BLUFOR) each tick. Scoring reads the force ratio
  `r` = Σ`_fri` ÷ (Σ`_ene` + 1) over a 3×3 block, and threat as `_ene`.
- **Streaming.** A tasking is a virtual point on a route until a player or a live BLUFOR group stays within K cells
  for `OPCOM_DEVIRT_BUFFER` ticks, then it spawns live; it stows after `OPCOM_REVIRT_GRACE` ticks with neither
  within K. The BLUFOR read is of true positions and never reaches belief or scoring. The engine resolves every
  fight, and `P(win)` never dices one. A `garrison` never streams live, and a recruited combatant feeds the reserve
  wave of the zone or town it is homed at. One spawn check and one stow check in `fnc_opcom_task_step.sqf` stream every tasking, a ferry carry
  included; the ferry scripts a live carry but never decides when a unit streams.
- **The ferry** is a consequence of a unit's route, never an order. A freed hull garrisons the nearest held,
  uncontested zone. Not built: whether an idle hull leaves its post to ferry, whether a rider waits for lift or
  walks, and land-taxi — lifting a foot unit over dry ground with the same carry.
- **Capture.** A `capture` takes the BLUFOR-held zone at its target and aims at the zone's centre
  (`fnc_opcom_task`). A retake is an `EAST PRESENT` trigger gated on `fnc_zone_retake_ready` — OPFOR outnumber
  BLUFOR, a BLUFOR garrison counting as beaten until one is built — so a zone flips with players inside and takes no
  hold. A virtual attacker inside the radius posts the contact report as it enters and runs the zone's retake
  statement itself. The order ends when the zone is OPFOR's: an attacker inside the radius garrisons there, a live one
  holding `guard` until it stows, and one still on the road re-garrisons there.
- **Intercept.** An `intercept` targets a belief row key, a BLUFOR group's `netId` (`fnc_opcom_task`). It follows
  the row's believed position, re-planning only once that moves past one cell, and keeps the last position read if
  the row decays. Standing in the cell it was sent to, it takes one guaranteed look `OPCOM_INTERCEPT_K` cells wide:
  every BLUFOR group inside is stamped for certain, rows the look disproves clear, and it hunts the closest group
  found. Nothing inside drops it to `guard` there; an interceptor never returns to garrison.
- **Fire missions.** `DUWS_fnc_opcom_fireMission` (`fnc_opcom_fires.sqf`) puts rounds on a point from one mortar pit
  or battery: every crewed piece of it that bears on the target fires. Those two types never stream, so their guns
  and crews always stand. A standing battery holds **no ammunition** — its guns are emptied at register, loaded for
  the mission they are given, topped up as they fire and emptied again once the rounds are away or
  `OPCOM_ARTY_ROUND_SECS` per round has passed, so a crew never shells anything on its own. It fires what it is
  handed — what is worth shelling, the cooldown, the scatter and the HQ exclusion are the scored Arty action's.
- **A flipped site frees its orders.** When a zone is captured, or a town's garrison is cleared or works its way out
  of the band, every tasking tied to that site drops to `guard` where it stands (`DUWS_fnc_opcom_siteLost`): the
  garrison homed there, the unit still walking in to settle, the errand carrying goods to it. Its resting
  non-combatants are deleted with the garrison they were attached to; combatants are left to the fight that beat them.
- **Supply errands.** A `move` given an `errand` is a supply run (`fnc_opcom_task`). On arrival, live or virtual,
  `DUWS_fnc_opcom_deliver` lands the errand through its writer and the truck despawns; a killed truck delivers
  nothing, and a refused errand is lost. `reinforce`, `fortify` and `rapport` take a town index
  (`fnc_town_garrison_reinforce`; `fnc_town_garrison_setTier` one tier up, never from tier 0; `fnc_town_rep_adjust`
  −3). `["build", pos, type]` sites a standalone hardpoint in the band near `pos` (`DUWS_fnc_opcom_build`). A zone
  buy needs no truck and lands the call it is made: `fnc_zone_garrison_reinforce`, `fnc_zone_garrison_fortify`
  (clamped at IV, full potential re-stamped) and a zone-keyed `DUWS_fnc_opcom_build`, each refused on BLUFOR ground.
  The harness drives both (`supply` with an errand, `zone`).
- **Orders run by hand** through the debug harness (`fnc_opcom_debug_task.sqf`, and the OPCOM debug menu over it)
  and spend no AP. Stage B owns everything that decides or pays: scoring, prices, the truck-source pick and the
  shared contested draw-lock filter it brings, Recruit, and the need and cover fields.
- **State** is numbers, strings and arrays only, and every time counts in ticks off `DUWS_opcom_tick`.

Two terms carry one meaning each throughout:

| Term | Applies to | Meaning |
|---|---|---|
| **Contested** | a zone or a town | BLUFOR are assaulting the site: OPFOR belief holds a BLUFOR sighting within one grid cell of its edge (`fnc_opcom_contested.sqf`). Built for zones only |
| **Engaged** | a unit | The unit is live and fighting BLUFOR. A virtual unit, a zone and a town are never engaged |

## Appraisal (Phase 4)

**WIP.** Stage B is decided as a first pass: its Values, prices and constants will change as each chunk is built and
played.

Each tick, enumerate candidate `[action, target]` pairs, gate them cheaply, score the survivors, and pick one by
weighted random over the top `OPCOM_PICK_TOP` (`selectRandomWeighted`, the `fnc_createzone.sqf:117` idiom). No
search or lookahead. The scoring pass runs inside `isNil { }` (unscheduled, no `sleep`) under a wall-clock budget,
`OPCOM_SCORE_DEADLINE`; the pick executes after it in scheduled space, because an order plans a route and the router
may yield. One commit per tick. The action list (`fnc_opcom_actions`) holds each action's gate, Value, Cost and
execute. `archWeight` stays a flat 1 until Phase 6, isolated in one file so Phase 6 replaces it alone. Measure the
grid rebuild once under a full map before 4.5 stacks scoring on the same tick.

| Chunk | Builds | Settles in play |
|---|---|---|
| **4.5** Spine + zone economy | The action list and scoring pass, Bank, exposure and the hidden HQ flag, zone Reinforce / Fortify / hardpoint Build, force pricing, the savings goal | `OPCOM_AP_PER_FORCE`; the zone prices; the exposure distances (5 / 10 km, 0.2 floor); `OPCOM_SAVE_HORIZON` |
| **4.6** Trucks + towns + Rapport | The truck-source pick and the shared contested draw-lock filter, Recruit for supply, town Reinforce / Fortify, Rapport, the delay discount | The town worth factor (5); `OPCOM_AP_PER_KM` and `OPCOM_AP_RAPPORT`; `OPCOM_VALUE_HALFLIFE` |
| **4.7** Need and cover fields + standalone hardpoints | The two fields, shown on a debug overlay before anything reads them, then the standalone Build and the asset types | The need field's base ratio (2–3); the asset prices; what a radio's reach and an OP's eyes are worth, in place of the build-price stand-in; where a mortar pit or artillery battery sites; whether belief carries a threat category, so a build sites a typed counter (AT under armour, AA under air) |
| **4.8** QRF + Attack decisions | Real `P(win)`, combatant Recruit, the QRF and Attack scores, the commit Cost | `OPCOM_PWIN_FLOOR`; `OPCOM_COMMIT_HOLD`; `OPCOM_GARRISON_HEAL_RATE`; `OPCOM_GRID_ZONE_ENEMY_FORCE` (8), the force OPCOM believes every BLUFOR zone holds, which sets its baseline caution; `OPCOM_MAX_TASKINGS` per locality and how a bubble is delimited; whether the player can see the commander act on stale belief, and whether the intel system surfaces it; what the commander does with a surplus, and whether it must spend rather than only can (absorbers: combatant Recruit, reinforcing over upgrading, mustering) |
| **4.9** Scout, then one-gun Arty | The staleness Value and recon Recruit; the Arty action over the shipped fire mission — what is worth shelling, the cooldown, the scatter and the HQ exclusion ([§Indirect-fire hardpoints](#indirect-fire-hardpoints)) | `OPCOM_SCOUT_SHARE`; what a gun's fire missions are worth; whether a fast airborne player crosses a recon's K between its once-per-tick samples unsensed, fixed by a larger K against airborne players if it does |

The score is one number — expected AP returned per AP spent:

```
score = archWeight[archetype][actionClass] × P(win) × Value / Cost
```

`Value` and `Cost` are both Army Power, so the units agree; `archWeight` tilts by action class
([§Archetype](#archetype-phase-6)); `P(win)` scales to the expected return.

- **`P(win)` — Lanchester-square.** `P(win) = r² / (r² + 1)` over the target's 3×3 `r`. Parity is a coin-flip, a
  2:1 edge ≈ 0.8, a hopeless ratio floors near 0. It is a flat 1 until 4.8.
- **The band** reads the same `r` to pick *how* an offensive runs (`≥2` assault, `1–2` flank/encircle, `0.5–1`
  probe or muster, `<0.5` hold). `P(win)` (whether) and the band (how) are two jobs off one `r`. The band picks
  once, at commit ([§Templates](#templates-phase-5)).

### Candidates

| Action | Targets swept | Chunk |
|---|---|---|
| Bank | one null | 4.5 |
| Zone Reinforce | each uncontested OPFOR zone below full strength | 4.5 |
| Zone Fortify | each uncontested OPFOR zone below tier IV | 4.5 |
| Zone hardpoint Build | each uncontested OPFOR zone with a free hardpoint slot (`fnc_hardpoint_zone_cap`) | 4.5 |
| Town Reinforce | each OPFOR-band town below full strength and not regrouping | 4.6 |
| Town Fortify | each OPFOR-band town below tier IV and not regrouping | 4.6 |
| Rapport | each town above −15 and below +10 that OPFOR's area of influence covers (`fnc_aoi_opfor_covers`) | 4.6 |
| Recruit | once per demand group | 4.6 supply, 4.8 combatant, 4.9 recon |
| Standalone hardpoint Build | the band cells with the highest coverage Value; each asset type unlocked | 4.7 |
| Intercept (QRF) | each BLUFOR sighting inside OPFOR's area of influence | 4.8 |
| Attack | each BLUFOR-held zone | 4.8 |
| Scout | each `recon` unit's route over stale, valuable cells | 4.9 |
| Arty | each observed belief point in range of an owned gun off cooldown | 4.9 |

### Value

Value is the AP worth of what an action delivers. Every build, refill and tier reads slow state only: threat
(`_ene`) shifts tick to tick, while the trucks and buys it would drive take minutes and stand for the campaign, so
threat drives only the fast actions — the QRF and attack staging.

- **Worth** is a holding's fixed AP figure. A zone's is `_points`, its radius ÷ 10 (35–50 at the default radii). A
  town's is its level `civ_town_ap` (1–5, the figure its income pays) × a tunable 5, so 5–25 and always below a
  zone.
- **Exposure** (0–1) is how close the holding sits to BLUFOR-held ground: 1 within 5 km, falling in a straight line
  to 0.2 at 10 km. OPCOM knows every zone and town owner for free, so exposure moves only when ground changes hands.
  OPCOM holds the player HQ's position from the start behind a hidden flag, and a hidden HQ counts toward nothing;
  the first BLUFOR sighting within 2 cells of it flips the flag for good, checked once in
  `fnc_opcom_belief_upsert`. Until the first capture or that reveal, exposure sits at its floor everywhere and
  OPCOM defends evenly.
- **Gain** (0–1) is the share of the full result a partial action delivers: the force a purchase adds ÷ the force
  the holding fields at full strength and top tier, or 3/10 for Rapport, whose −3 step is three tenths of a flip.

| Action | Value |
|---|---|
| Zone or town Reinforce / Fortify, zone hardpoint | worth × exposure × gain |
| Standalone hardpoint | Σ over its 5×5 block of need × the cover it adds ([§Need and cover fields](#need-and-cover-fields)) |
| Asset hardpoint (radio tower, OP, mortar pit, artillery battery) | build price × exposure |
| Rapport | town worth × skew × 3/10, with skew = max(0.1, 1 − \|rep\| ÷ 10) |
| Recruit, specialist (`supply`, `transport`, `recon`) | the Value of the best action blocked for want of it |
| Recruit, combatant | the larger of that demand and home-zone worth × exposure × unitForce ÷ (the zone's current force + unitForce) |
| Intercept (QRF) | Σ need over the sighting's 5×5 block × min(1, sighting force ÷ (Σ `_fri` over its 3×3 + 1)) |
| Attack | the zone's `_points` |
| Scout | Σ need × staleness × `OPCOM_SCOUT_SHARE` (0.2) over the unique cells within its K of its route |
| Arty | `effForce` killed × `OPCOM_AP_PER_FORCE` |

- **Rapport favours a neutral town.** A town near −10 turns anyway on the free area-of-influence drift, and a −3
  step barely moves one near +10. The skew is 1 at 0, 0.5 at ±5 and 0.1 from ±9 out, so a town between −15 and −10
  scores at the floor; a town at +10 or more is BLUFOR-held and no target.
- **A combatant counts once.** It joins its zone's reserve wave on hire, so it defends at once; its Value is the
  larger of demand and defense, not the sum, because one unit serves one role at a time. Its gain shrinks as the
  zone stacks up, so combatants gather where exposure is high and a QRF pool forms there with no roster table. A
  truck is also cheap infantry transport; its transport demand lands with land-taxi ([§Shipped](#shipped-the-substrate-the-loop-drives)).
- **The QRF share** is how much of the local defense the sighted group can overwhelm. `P(win)` says whether the QRF
  can win, so a platoon is worth stopping but a small QRF is not thrown at it.
- **Scout staleness** is min(1, ticks since the cell's last sweep in `DUWS_opcom_grid_seen` ÷
  `OPCOM_BELIEF_EXPIRE`). The share holds Scout below the ground it reveals, since scouting takes and protects
  nothing itself.
- **An asset's Value is a stand-in** that favours frontline assets until 4.7 settles what a radio's reach and an
  OP's eyes are worth, and 4.9 what a gun's fire missions are worth ([§Appraisal](#appraisal-phase-4)).
- **Delay.** Value that lands later counts for less: Value × 0.5 ^ (ETA ÷ `OPCOM_VALUE_HALFLIFE`), with ETA in
  ticks from the route length and the unit's per-cell speed (`DUWS_opcom_speed`). A zone action's ETA is 0.
- **No route-risk discount, no emergency reserve.** A truck's odds en route would read threat, so the risk stays
  with the player as counterplay. A QRF stakes roster units, not AP, and combatant Recruit keeps a pool at the
  exposed zones.

### Need and cover fields

A standalone hardpoint's Value comes from cover over the whole map, not over one zone, because a zone's ring already
defends its zone: weighted toward OPFOR's holdings, and rewarding cover over the sparse sectors between them. Two
layers span every land cell; standalone candidates are band cells only. Both change only when a hardpoint is built
or cleared or ground changes hands.

- **Need** (AP). Each OPFOR holding spreads worth × exposure over the 5×5 block around its cell, with weights that
  fall with distance and sum to exactly that figure. Every band cell also carries a flat base for the sparse
  sectors: a zone's average pull per cell (worth ÷ 25) ÷ a tunable ratio starting at 2–3, × the cell's exposure, so
  a holding pulls harder than a gap but not so hard that hardpoints cluster around zones. Each standing asset
  hardpoint spreads its build price the same way and becomes an asset worth protecting; radios and OPs site out in
  the wilderness by their own logic, so the cover network builds up around them into the gaps.
- **Cover** (0–1). Each standing OPFOR hardpoint within 2 cells, zone rings included, covers half of what is left:
  0, 0.5, 0.75, 0.875. Every type shares that reach.
- A first hardpoint at a frontline zone worth 40 earns about 10, beside that zone's Reinforce at 15; one beside
  other hardpoints earns little.

### Cost

- **Spend** actions (Recruit, Reinforce, Fortify, Build, Rapport, Arty) pay fresh AP at the prices in
  [§What AP buys](#what-ap-buys); a supply-gated one adds its truck's source cost.
- **Commit** actions (Attack, Intercept, Scout) stake roster units: `Cost` = the AP to rebuy the force
  (`Σ effForce × OPCOM_AP_PER_FORCE`) plus the defense the unit abandons, read off the grid at its home cell with no
  counterfactual rebuild:

  ```
  defenseAbandoned = homeWorth × min(1, 1 / r_home) × min(1, unitForce / Σ_fri_home)
  ```

  `homeWorth` is the home zone's `_points` (0 for a unit that holds no zone). `r_home` is the 3×3 ratio there, so a
  safe backline costs almost nothing to draw from and a threatened one its full worth. The last term is the share of
  the local OPFOR force that leaves, capped for a deposit that spreads past the block. A draw takes only
  OPCOM-recruited units, never a zone's base garrison, so the term prices a thinned zone, never an empty one; a
  `noncombat` unit covers nothing and abandons 0.

### Gate and the savings goal

- **Gate.** A zone action drops while its zone is contested. A supply-gated action drops only when no truck idles
  and the wallet cannot cover the action plus a hire. A commit action drops when no eligible unit is free, and no
  pool draws a unit garrisoned in a contested zone. An offensive that does not muster drops below
  `OPCOM_PWIN_FLOOR` at commit; a mustering one checks the floor at launch
  ([§Commitment](#commitment-intents-are-sticky)).
- **An unaffordable action is still scored.** When the top scorer is unaffordable and its ETA,
  `(price − wallet) ÷ income rate`, is inside `OPCOM_SAVE_HORIZON`, it is the savings goal and OPCOM banks that
  tick; an action that outscores it later, such as a QRF, still commits. Past the horizon it drops, and the pick
  runs over the affordable top few. Without the goal, cheap actions spend every refill and a better, dearer one
  never becomes affordable.
- **Bank** is a candidate, not a policy — a low flat score that wins when nothing else scores, or when a savings
  goal stands.

## Commitment: intents are sticky

A chosen action becomes an intent record — same shape at every granularity, `roles` empty (economic), one entry
(simple tasking) or several (a template):

| Field | Holds |
|---|---|
| type / target | the action id; the objective (registry index or cell) |
| roles | `[role, unitRef, status]` bindings drawn from the roster |
| phase | index into the template's phase list |
| hold | `DUWS_opcom_tick` at commit + `OPCOM_COMMIT_HOLD` — earliest tick OPCOM may re-issue this unit's order |
| state | mustering / ordered / in progress / done |

- **The hold is an absolute anti-flap lock** (KISS), not a success deadline: a committed unit is held the full span
  no matter what; a target that dies mid-hold is re-evaluated once it expires. Resting `garrison`/`guard` are
  unheld. Re-scoring fills free capacity and may re-task a unit only past its hold — a de-virtualised unit included
  (a new order pushes onto the live group), a live water crossing included; only a *bound* ferry carry is off-limits.
- **There is no retreat.** The engine owns a group in `COMBAT` and ignores a commanded withdrawal
  ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)).
  A group that wins drops to `moving` and re-virtualises on clearing; one that loses dies. Recovery is winning.
- **A multi-unit assault musters, then launches as one wave** (Phase 5, WIP). In `mustering` it binds force across
  ticks at a safe rally short of the target, then advances all together — it never dribbles units into contact,
  which no-retreat would turn into defeat in detail. It launches the tick its bound force reaches the archetype's
  **ideal** ratio over believed BLUFOR force at the target (3:1 baseline). At `OPCOM_MUSTER_EXPIRY` it launches if
  it holds at least the archetype's **minimum** (1:1 baseline), and is otherwise abandoned, its units returning to
  rest, so a player who keeps reinforcing cannot hold it forever. Both bars read believed force, so a mid-muster
  reinforcement raises them. A mustering action checks `OPCOM_PWIN_FLOOR` at launch, against its archetype's
  minimum, because it commits below the odds it launches at. Mustering is also how a force-short action waits for
  units — from the roster or from Recruit.

## Templates (Phase 5)

**WIP.**

A template is a unit-dispatching action's execution form — named roles and a phase sequence a single generic
**runner** steps off unit status. It is not separately scored (the action is; the template is *how* it runs), and a
simple tasking is the one-role, one-phase case, so adding a coordinated behaviour is a bigger template, not a new
subsystem. There is no planner.

**The runner**, each tick over every live intent with roles: refresh each bound unit's status; a required role
`dead`/lost → **abort** (release survivors, no AP refund); else advance `phase` when its transition predicate holds
(predicates read child status and geometry only); last phase complete → done, release. The runner sequences phases;
the route/streaming machinery moves the units.

**The roster** is the free-unit pool — every uncommitted `garrison`ed or `guard` unit, except one garrisoned in a
contested zone. Binding pulls a unit (a `garrison`ed draw strips that zone's reinforcement); release returns it.
One unit, one owner. A template applies only when its band fits, enough roles fill, and the geometry holds; short a
role, it commits in `mustering`. The band picks the template once, at commit, and a muster launches that template
whatever `r` it reaches, so a plan never flips mid-muster: a `flank` committed at 1.5 that musters to 3:1 still
launches as a flank.

| Template | Picked when | Roles | Phases (→ on transition) |
|---|---|---|---|
| `assault` | band ≥ 2 | `attacker` ×1 | approach (direct) → S&D → resolve |
| `flank` | band 1–2, ≥2 mobile, a reachable flank cell | `fix` ×1, `maneuver` ×1+ | form (fix frontal; maneuver → flank cell, λ route) → *(fix engaged)* assault → resolve |
| `encircle` | band 1–2, target pocketed, ≥3 mobile | `blockers` ×N (per escape corridor), `crushers` ×1–2 | deploy (blockers → corridors) → *(in position)* seal → crush (inward) → resolve |
| `probe` | band 0.5–1 | `prober` ×1 (cheapest expendable; never armour/air/recon) | approach → make contact → resolve (survives ⇒ soft, escalate; dies ⇒ confirmed, mass/re-target) |
| `rapport` | a `supply` truck, a Rapport candidate town ([§Candidates](#candidates)) | `courier` ×1 | move → deliver (rep −3) → resolve |
| `scout` | a `recon` unit, a stale valuable area | `recon` ×1 | move (plain `move`; standing recon detection stamps belief as it goes) → resolve |
| `arty` | an observed belief point in range of an owned gun off cooldown | owned `guns` ×1–3 (hardpoints, 0 roster), `spotter` ×0–1 | mark → salvo (rounds × saturation) → assess (force dropped? re-fire : done) |

- **`probe` is disposable recon-by-fire** — no-retreat forbids poke-and-withdraw, so it converts uncertain belief
  into observed defender strength by drawing fire, reaching what recon cannot (a dug-in town garrison). It minimises
  stake, the inverse of every other commit, which gathers force toward the odds it launches at.
- **Escape corridors** (`encircle`): the target cell's neighbours whose enemy-influence gradient points outward.
- **`resolve`** is the transition that frees the units and writes the outcome, one predicate per action
  ([§Shipped](#shipped-the-substrate-the-loop-drives)): **Attack** — OPFOR take the zone by the mirror of BLUFOR's capture rule
  (`fnc_zone_retake_ready`): the zone's BLUFOR garrison beaten, none bought counting as beaten, and OPFOR
  outnumbering BLUFOR in the radius. A live fight flips through the retake trigger; a virtual attacker at an empty
  zone flips it on the OPCOM tick against stored state, and OPCOM sends that attack's contact report itself. The
  attacker garrisons the zone once it is virtual. **Intercept** — at the sighting's last known position the unit
  reads truth within its own K: nothing there, it drops to `guard` in place; BLUFOR there, it fights them live and
  guards once none remain. It never returns to garrison. **Rapport** — courier delivers or dies.

Phase 5 settles in play the band thresholds, the route λ weights and their recompute cadence, and
`OPCOM_MUSTER_EXPIRY`.

## What AP buys

**WIP.**

Three levels: **Action** (what AP commits to, scored and held), **Sink** (how it's paid — tier / strength / build /
tasking-spawn / bought fire mission), **Tasking** (orders emitted: 0 economic, 1 simple, N template). One actor
shares `WARCOM_opfor_ap`; every sink competes in the one appraisal — none runs on its own clock. Spends call
`["OPF", -_cost, _reason] call fnc_ap_adjust` (server-side, single writer, no race).

| Action | Class | Target | Sink | Taskings |
|---|---|---|---|---|
| Attack | offensive | a BLU-held zone | tasking-spawn | 1–N (band → template) |
| Intercept (QRF) | defensive | a BLUFOR sighting inside OPFOR's area of influence | tasking-spawn | 1–N |
| Rapport | offensive | a town above −15 and below +10 inside OPFOR's area of influence (needs `supply`) | tasking-spawn | 1 courier |
| Recruit | buildup | the highest-value demand group | tasking-spawn | 1 (`garrison`, resting) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 zone / 1 truck town |
| Scout | recon | a `recon` unit's route over stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed belief point in gun range | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 zone / 1 truck town |
| Build | defensive | an own zone ring or band cell | hardpoint build | 0 zone / 1 truck standalone |
| Bank | — | — | none | 0 |

- **Recruit fills the roster; every other unit-dispatching action drains it** — so OPCOM must build up before it
  strikes, and a lost unit is lost standing strength. It scores **once per demand group** (combatant, `recon`,
  `supply`, `transport`), each valued as [§Value](#value) sets out, so it hires what it is short of.
  Units spawn only from OPFOR-held ground; taking the zone cuts what it can raise.
- **A unit's force is a token composition** — a row in `DUWS_opcom_recruitMenu` (`fnc_opcom_tasking_init.sqf`): an
  id, a **bare**-token composition (`none` posture, so OPCOM commands it), and capability flags. Priced from
  composition firepower × `OPCOM_AP_PER_FORCE` (`fnc_opcom_recruit.sqf`), decided at 2 where the code holds 1 — the
  single force↔AP knob, which also prices garrison buys, commit `Cost` and Arty kill Value, so the menu carries no
  price column.
- **Capability flags decide what a unit unlocks; there is no unit "type".** `recon` → Scout (range by platform,
  `OPCOM_RECON_K` cells), `supply` → a delivery run, `transport` → carry another unit; `noncombat` keeps a row out
  of a zone's reserve wave (regardless of armament — the boat is armed). A row may carry several.
- **The live-group cap is per active locality, not global.** Virtual taskings are cheap and uncapped;
  `OPCOM_MAX_TASKINGS` (start 10) budgets spawned AI per player-bubble / contact point, so one flank cannot starve a
  defender's spawn elsewhere, and co-op localities each keep their own budget.

Prices, first-pass defaults set against OPFOR's income of roughly 40–80 AP per 30 min (`fnc_zonesundercontrol.sqf`):

| Purchase | Price |
|---|---|
| Unit hire | force × `OPCOM_AP_PER_FORCE`: truck 4, APC 8, IFV 18, tank 24, helicopter 30 |
| Zone Reinforce / Fortify | the force the 0.3 step or the next tier adds × `OPCOM_AP_PER_FORCE` |
| Town Reinforce / Fortify | as a zone, plus the truck's source cost |
| Zone hardpoint (MG, AT, GMG, roadblock) | the hardpoint's force, emplacement and fixed garrison, × `OPCOM_AP_PER_FORCE` |
| Standalone hardpoint | as a zone hardpoint, plus the truck's source cost |
| Radio tower / OP / mortar pit / artillery battery | `OPCOM_AP_TOWER` 30 / `OPCOM_AP_OP` 15 / `OPCOM_AP_MORTAR` 25 / `OPCOM_AP_ARTY` 50, plus the truck's source cost |
| Rapport | `OPCOM_AP_RAPPORT` 10, the goods the courier carries, plus the truck's source cost |
| Truck source | the hire price (4), or 0 for an idle truck on hand, plus `OPCOM_AP_PER_KM` 0.5 × distance; the lowest wins |

- **Force pricing sets the defensive scores.** Pricing garrison force at the hire rate makes a zone or town buy
  score worth × exposure ÷ (full force × rate) whatever the step's size — about 0.5 at a frontline zone worth 40
  with a full force of 40 — and a town, fielding less force, costs less than a zone with no separate price. A
  neutral level-5 town's Rapport scores 7.5 ÷ 14 ≈ 0.5, inside the defensive range.
- `OPCOM_AP_BAND` and `OPCOM_AP_TOPUP`, the disabled director's flat errand prices, retire.

**Supply gates the town-side builds.** A `supply` truck drives from OPFOR ground to its target and is spent on
arrival, behind four actions: Rapport, standalone Build, and *town* Reinforce / Fortify
([§Shipped](#shipped-the-substrate-the-loop-drives)). The action takes an idle truck on hand, or hires one and tasks it in the same commit,
whichever source costs less. The AP is paid at commit but the result lands only when the *specific* bound truck
arrives — **kill it en route and the order fails, no refund** (interdiction is the counterplay). A town buy whose
truck arrives while the town is contested still lands through the garrison's existing hold — owed at once, the men
arriving once BLUFOR leave — and a town that falls first loses it. **Zones need no supply** — zone Reinforce,
Fortify and hardpoint Build resolve on AP alone the tick they commit, reading as OPFOR trucking matériel outward
from its zones to the towns.

## What the commander builds

**WIP.**

The escalation ladder and indirect-fire assets, once the commander spends on them. **Built but disabled:** a
standalone fortification director (`fnc_WARCOM_opf_hardpoints`) spent AP on flat-priced builds on its own clock
with no appraisal; its spawn is cut (file/compile stay), to be re-driven through the appraisal so build competes
for the wallet. Hardpoints otherwise generate at scenario init only.

**Build is scored like any other action** ([§Value](#value)). A zone hardpoint builds in the zone's ring through the
existing in-zone draw; a standalone one sites at its chosen band cell through `fnc_hardpoint_spawn_sited`. Given the
site, the type is rolled from the existing weight table — `DUWS_hardpointWeightZone` (MG, AT, GMG, roadblock) for a
ring, `DUWS_hardpointWeightSolo` standalone — limited to the types OPFOR's tier has unlocked; campaign generation
still rolls the full list. An asset hardpoint is its own candidate and never stands in a zone's ring: radios and OPs
site by their own logic. A build cannot be a *typed* counter (AT under armour) until belief carries threat
category, which 4.7 settles ([§Appraisal](#appraisal-phase-4)).

Construction is an AP sink; no build refund (clearing pays the player CP only). Unlocks key off
`WARCOM_opfor_tier`, which climbs the earned-AP rungs (`DUWS_ap_tier_rungs`), never the spendable wallet:

| Tier (earned AP) | Types a build may place |
|---|---|
| 1 Infantry (0) | OP, MG, roadblock |
| 2 Motorised (60) | + AT |
| 3 Mechanised (150) | + GMG, AA, mortar pit (max 2 alive) |
| 4 Armour (350) | + artillery battery (max 1 alive) |
| 5 Jets (600) | nothing new |

Hardpoint garrisons stay fixed per type (`DUWS_hardpointGarrison`). Knobs (all tune): seed subset 2–3 at init; no
live cap (bounded by player proximity).

### Indirect-fire hardpoints

Persistent enemy assets, two tiers sharing one fire-mission implementation. The order ships
([§Shipped](#shipped-the-substrate-the-loop-drives)); **nothing decides to use it** — no cooldown, scatter,
observation gate or HQ exclusion. A zone's own mortar is separate and stays autonomous (`fnc_static_resolve`),
uncapped here.

Whether an AI gunner reliably executes `doArtilleryFire` settles in play, nothing in the mission having issued it
before; if it does not, the fallback is spawning shells directly as the player's own arty support does
(`client/supports/fnc_arty.sqf`), the gun becoming scenery.

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static `opfor_TURRET_MORTAR` | self-propelled `opfor_ARTY_X` |
| Unlocks at | tier 3 (150 earned AP) | tier 4 (350 earned AP) |
| Cooldown | 4–8 rounds, then 25–40 min | 6–10 rounds, then 40–60 min |
| Scatter | tighter (base 50 m) | wider (base 100 m) |

- **A fire mission is the Arty action** — scored and committed like any other, `Cost` scaling with rounds ×
  saturation; it fires only when that action wins its phase, never on a schedule. The owned gun off cooldown and in
  range is the availability gate, nothing more. **AP is the ammunition** — the guns rest empty and are loaded per
  mission, so there is no finite store and the wallet is the only limit.
- **Observation is the trigger** — nothing is shelled the enemy has not seen. A player above `east knowsAbout ~1.5`
  (shared with the sighting sweep); a BLU zone/FOB an OP covers or an OPFOR element was within ~500 m of in 15 min.
  OPs are the artillery's eyes; killing them blinds guns.
- **HQ exclusion** — no mission *aimed* inside 100 m of `PosOfBLUHQ` (rounds may still stray there from a barrage
  aimed elsewhere). The target grid is latched `[x,y,0]` at order time (never an object ref that would follow a
  respawn into the circle), and re-checked against the circle immediately before firing.
- **Scatter** is deliberate (`doArtilleryFire` converges): base by type, +25 m per km range, −30 m with direct OP
  observation. Telegraph: Allseer line + a temporary marker ~20 s before impact.
- **Capped campaign-wide** — one battery and two mortar pits alive at once across the map. These are the only
  permanent-crew hardpoints (~6 units that never despawn); making AA resident would add a fourth and needs its own
  cap.

## Archetype (Phase 6)

**WIP.**

One archetype rolled per campaign (in the persistence snapshot, never re-rolled) sets the
`archWeight[archetype][actionClass]` factor — it *multiplies* an action class's score, never removes an action, and
cannot override the ladder (an Aggressive commander with no armour tier fields none). It is not difficulty
(`opfor_ai_skill` sets aim). A single authored per-class table; further leans (indirect fire, armour) become rows.

| Archetype | Weights toward |
|---|---|
| Defensive | Fortify, Reinforce, Build, Recruit, Intercept |
| Balanced | no strong lean — the baseline |
| Aggressive | Attack, Rapport; leaves ground thin |

Beyond `archWeight`, an archetype sets the commander's patience: the muster ideal, minimum and expiry,
`OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE`. A patient, strategic commander musters and saves longer for a
properly executed manoeuvre; a flexible, aggressive one launches sooner at lesser odds. The Balanced baseline (a 3:1
muster ideal, a 1:1 minimum) applies until Phase 6. Phase 6 settles the set of archetypes, which is not final, and
whether the player can learn the commander's archetype through the intel system.

## Town & zone garrisons

The OPFOR town ladder (tiers 0–IV in `DUWS_townSpawnTiers`, per-town `DUWS_townGarrisonTier` via
`fnc_town_garrison_setTier`) and the zone tiers are shipped and documented in
[`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv). Reputation
decides *whether* a town garrisons (crossing −10 writes tier I); AP decides *how hard*. Clearing a town drops it to
tier I (no refund, three-hour regroup lock) and pins it to the `0.3` strength floor for the campaign.

Not built:

- **BLUFOR garrisons.** BLUFOR buy garrisons for zones and towns as OPFOR do. The BLUFOR band (`>= 10`) has no
  garrison; buying tier I at a held town *creates* one at zero strength (each reinforcement +30 %), never inherits
  OPFOR's — captured ground carries no tier or strength. The presence latch is still wanted (a BLUFOR garrison
  streams), but the `Mobilising`/`Regrouping` holds are not (a BLUFOR garrison never arrives on ground it owns). A
  BLUFOR-held site also wakes when an OPCOM attacker, live or virtual, closes within K, so its garrison renders and
  renders the attacker in turn.

## Random events: what a turned town does

Shipped separately, not an OPCOM build phase. A turned town — reputation `<= -10`, inside the OPFOR band — acts on
its own, free and rolled off reputation: IEDs on approach roads, ambushes on passing patrols, sabotage against
nearby FOBs, planned outside the town's presence trigger so it can mine a road ahead of the player.

## Rejected: the OPFOR spawners this replaces

WARCOM's three OPFOR threads (roaming patrols, attack waves, random air) are deleted. The director **must not
reproduce their shape**: routes closed with a `CYCLE` and never despawned, cadence was unconditional, AP was read
but never spent (a one-way ratchet), and spawns sited >1500 m from every player so contact only happened when the
player drove into them. Three behaviours are worth rebuilding as commander decisions: **target selection** (old
distance-sort of BLU zones; a rebuild reaches HQ only through belief); **dismounts** (a second infantry team
`joinSilent`ed into a vehicle group above AP 100 — keep as a composition Recruit buys); the **ammo truck** is not
carried (garrison restoration is now Reinforce).

## Persistence

**WIP.** Planned, not shipped ([`campaign_persistence_plan.md`](../campaign_persistence_plan.md)); today
persistence is the engine's `saveGame`. OPCOM's store is shaped to serialise but implements no save/load —
persisting its state is the snapshot's responsibility. Every field is a number, string or array.

| Saved | Holds |
|---|---|
| **Archetype** (input) | Fed back before the loop, never re-rolled |
| **Standing units & orders** (outcome) | One row per unit: world position; order, target, home and return zone, route mode; `strength`; class — the composition tokens and `spawnClass`, the hull drawn once at hire, so a restored vehicle keeps its hull. Restored as data, streaming to a live group on approach at saved strength |
| **Clock and flags** | `DUWS_opcom_tick`, the count of ticks since the campaign began, which every stored time counts against — a commit `hold` restored against a counter reset to 0 would hold its unit for hours — and the HQ reveal flag |
| **Inputs owned elsewhere** | Tiers (`WARCOM_opfor_tier` and the earned counter, the economy's); zone and town owners, which exposure and the candidate sweep read (the campaign snapshot's BLUFOR-held zone positions and town reputation) |

- **Belief sightings are not saved.** Belief is keyed by group `netId`, which resolves to nothing after a restart,
  and a restart also loses the headless clients and returns players to HQ, so the sightings would describe a
  battlefield that no longer exists. The grid, its coverage layer and the contested set rebuild from the first
  sensor pass.
- `fnc_opcom_belief_init` sets the tick to 0 today; it must initialise the tick and the HQ flag only when they are
  nil, or a restore resets them.
- A saved `spawnClass` the loaded mods no longer define is rerolled from its token against the current faction
  settings (`DUWS_fnc_tokenClass`), with a WARN. A token the current faction cannot field at all drops the unit,
  with a WARN.

## Naming: OPCOM sits inside WARCOM

OPCOM is a component of WARCOM, not a replacement; prefixes split by ownership, nothing mass-renamed. Shared
war-economy state stays `WARCOM_` (`WARCOM_opfor_ap`/`_tier`); OPCOM's own state takes `OPCOM_`; the belief store
keeps `DUWS_` with an `opcom_` owner tag.
