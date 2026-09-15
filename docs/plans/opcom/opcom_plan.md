# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns, tasks
squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and faucets are the economy's
([`economy_second_pass.md`](../economy_second_pass.md#army-power)); the hardpoint mechanics it draws from are
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md); the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting).

Three layers, one thread, one `OPCOM_TICK_PERIOD` (5 s) tick:

| Layer | Does |
|---|---|
| **Perception** | Maintains the enemy's *belief* about BLUFOR. Never reads live player state except through its sensors |
| **Appraisal** | Scores each candidate `[action, target]` as an expected AP return; picks by weighted random over the top few |
| **Commitment** | Turns a choice into a sticky intent with an owner and a minimum lifetime |

This doc is the forward design spec. **Perception (P1), force weighting (P2), and the tasking / movement / ferry
mechanism (P3) are shipped** — the code under `src/duws/server/warcom/opcom/` (`belief/` and `taskings/`) is the
source of truth for how they work; [§Shipped](#shipped-the-substrate-the-loop-drives) maps them and records only
the invariants new work must respect. What remains — the decision loop, its orchestration, and the assets it buys
— is specified below.

## Status

| Phase | State |
|---|---|
| 1 — Perception, 2 — Force weighting, 3 — Recruitment & tasking wiring (+ transport ferry) | **shipped** (live-playtest verification of P3 pending) |
| 4a — Decision loop: thinking harness + defensive economy | specified in [`phase_4_decision_loop.md`](phase_4_decision_loop.md) |
| 4b — Single-unit offensives (Attack, Intercept, Scout, one-gun Arty; real `P(win)`; draw-lock) | [§Appraisal](#appraisal-phase-4) — own spec when picked up |
| 5 — Orchestration: multi-unit templates + mustering | [§Templates](#templates-phase-5) |
| 6 — Archetype: per-class weight sets | [§Archetype](#archetype-phase-6) |

Each phase ships runnable and verifiable before the next; the ordering is forced by what the next reads. Do not
pre-build later phases — the tuning constants and engine-contact behaviours (streaming, `doArtilleryFire`, virtual
combat) only settle by running the core.

## Shipped: the substrate the loop drives

The mechanism P4 scores against. Each row's code file is the SSOT for its behaviour; the notes are the
cross-cutting invariants a P4/P5 author must respect and that no single file states.

| Subsystem | Code | Invariant that still binds new work |
|---|---|---|
| **Belief store** | `belief/fnc_opcom_belief_init.sqf`, `fnc_opcom_force.sqf`, sensors in `fnc_opcom_perception_run.sqf` | The commander plans against belief, never truth: only the sensors read live player state (`allPlayers`/`getPos`/`knowsAbout`). Belief tracks groups, not players; a human weighs `OPCOM_PLAYER_WORTH`. Store a position, never a handle |
| **Influence grid** | `belief/fnc_opcom_grid_init.sqf`, `fnc_opcom_grid_rebuild.sqf`, `fnc_opcom_grid_coords.sqf` | Two force layers (`_fri` known OPFOR, `_ene` believed BLUFOR), firepower-weighted and condition-scaled, rebuilt each tick. Exposes what scoring reads: **`r`** = Σ`_fri`/(Σ`_ene`+1) over a 3×3 block, **threat** = `_ene` on own ground, the **front line** (sign-change band), and **route-around** (lowest-`_ene` neighbour). Static per-cell masks classify land / navigable-water / air domains for routing and the ferry |
| **Movement & streaming** | `taskings/fnc_opcom_move.sqf`, `fnc_opcom_route.sqf`, `fnc_opcom_stream.sqf`, `fnc_opcom_task_step.sqf` | A tasking is a virtual world-point stepping a route (A\* cost field foot/air/boat, `fnc_convoy_path` road for wheeled/tracked) until a player closes within **K cells** (per move type) or it reaches contact, then it spawns live. Stow is temporal hysteresis (`OPCOM_REVIRT_GRACE` clear ticks). Streaming is side-symmetric and the **engine resolves combat** — `P(win)` never dices one. Spawn posture is the closest A3 order to the tasking, re-issuable live |
| **Tasking, status & strength** | `taskings/fnc_opcom_tasking_init.sqf`, `fnc_opcom_strength.sqf`, `fnc_opcom_task_step.sqf` | Each unit has a standing **tasking** (`garrison`/`guard` rest; the rest active) and a **status** (`virtual`/`moving`/`engaged`/`dead`). `effForce` (power × condition) is what the grid deposits, so a shot-up group weighs less automatically; `strength` (0..1) is persisted and heal-targeted; `garrison` heals at `OPCOM_GARRISON_HEAL_RATE`, `guard` does not. A recruited combatant feeds its zone's reserve wave; a contested zone locks its garrison units off any offensive draw |
| **Transport ferry** | `taskings/fnc_opcom_ferry.sqf` (+ `_virt` / `_devirt`), [§Transport](#transport-shipped) | A land unit stopped at a water leg borrows the nearest idle water-compatible hull, which carries it across and reverts to `guard` in the pool. The ferry is a *consequence of the rider's route*, never an order. Combat gates the borrow, never a bound crossing |

State is numbers / strings / arrays only — no handles near the mission namespace (a live group is held by netId).
Every time field counts in ticks off `DUWS_opcom_tick`, the one clock belief ages on, which persists where `time`
/ `diag_tickTime` do not.

### Transport (shipped)

The design rules the code encodes, kept because P4 layers valuations on them:

- **Dual-purpose, never both at once.** A `transport` hull is a role unit (on a directed order) *or* an idle lift
  the pool may draw — a hull on a job is off the pool. Protected: `carrying`, or garrisoned in a contested zone.
- **Borrow gates.** A fighting hull is not lendable, and a *live* rider will not start a borrow while engaged. But
  once bound the sequence is **unescapable** — board, carry, unload run regardless of contact; the rider, held by
  `ridingOn`, takes no turn of its own. A ferry never draws a hull off a standing order.
- **The carry** drops at the far shore (first land past the water span). Virtual = store math; **watched = a timed
  six-phase machine** (`to-pickup → pickup-land → pickup-board → carry → drop-land → drop-unload`), the two transit
  legs untimed, each land/board/unload phase capped at `OPCOM_FERRY_WAIT_MAX` ticks so a hull stuck short of shore
  forces the group to its destination at expiry rather than hanging. The two lifts board and dismount on purpose
  different shapes: a **rotary** lands and the squad walks aboard man by man — the riders are assigned and
  `orderGetIn`'d onto the parked hull (with nothing assigned the landing hold is vacuous and the hull lifts at
  once), despawning as each enters, the current leader forced aboard per tick so an engaged board still drains.
  A **boat** never boards or dismounts men: it parks at `OPCOM_FERRY_BOARD_BOAT` off the shore and the whole
  group vanishes into it, then spawns ashore at once — boats are finnicky, so this mass swap is deliberate, do
  not unify the two shapes.
- **Strength freezes on pickup, thaws on drop.** From the board commit the rider's `effForce` is snapshotted and
  belief stops reading its live count (board-despawn is not a casualty); the freeze thaws the instant the riders
  spawn at the destination, so egress losses count. The rider detaches (`ridingOn = -1`) the moment its leader
  spawns.
- **A boat** is its own move type (water-passable, land-impassable), armed by default, spawning and garrisoning
  on its zone's **port** — the one navigable-water cell within 3 grid steps that zone owns (a cell two zones
  claim goes to the nearer; the loser takes its nearest unclaimed land-adjacent cell). A portless zone refuses
  boats outright, as a hire target and as a return-to-garrison pick. The borrow has no lift-type preference —
  the closest free hull wins, boat or rotary alike.

Not built (Phase 4 valuations on the shipped mechanic): whether an idle hull leaves its post to ferry; whether a
rider waits for lift or walks a longer route (real only once P4 lowers `OPCOM_ROUTE_LIFT_PENALTY` so water is a
genuine shortcut); and **land-taxi** — lifting a foot unit over dry ground to save time, reusing the whole carry
engine with a distance trigger and a land-transport pool.

## Appraisal (Phase 4)

Each tick, enumerate candidate `[action, target]` pairs, gate cheaply, score the survivors, pick by weighted
random over the top few (`selectRandomWeighted` over the top three, the `fnc_createzone.sqf:129` idiom). No search
or lookahead. **Phase 4a — the thinking spine plus the defensive economy — is specified in
[`phase_4_decision_loop.md`](phase_4_decision_loop.md)** (Bank, Recruit on demand, Build, Reinforce, Fortify,
Rapport, supply delivery; `P(win)` a flat 1). What follows is the enduring model both cuts share; 4b (offensive
single-unit orders) gets its own spec.

The score is one number — expected AP returned per AP spent:

```
score = archWeight[archetype][actionClass] × P(win) × Value / Cost
```

`Value` and `Cost` are both Army Power, so the units already agree; `archWeight` tilts by action class
([§Archetype](#archetype-phase-6)); `P(win)` scales to the expected return.

- **`P(win)` — Lanchester-square.** `P(win) = r² / (r² + 1)` over the target's 3×3 `r`. Parity is a coin-flip, a
  2:1 edge ≈ 0.8, a hopeless ratio floors near 0. 4a stubs it at 1; 4b uses the real formula.
- **`Value` — the worth of ground in play.** A player has no worth of its own; it earns Value only through the
  ground it threatens. Attack = enemy zone `_points`; Intercept/Build = own worth × threat; Reinforce = own worth
  × threat × deficit `1−strength`; Fortify = own worth × threat × force the next tier adds; Rapport = town worth ×
  progress the −3 step makes toward the −10 turn; Recruit = per demand group, the best action that group unlocks;
  Scout = Σ over its recon footprint of `cell worth × staleness`; Arty = `effForce killed × AP-per-force`.
- **`Cost` — what an action stakes.** *Spend* actions (Recruit, Reinforce, Fortify, Build, Arty) pay fresh AP.
  *Commit* actions (Attack, Intercept, Rapport, Scout) stake roster units: `Cost` = AP to reacquire the committed
  force (`Σ effForce × AP-per-force`) **plus abandoned defense** — a unit pulled off threatened own ground forfeits
  the Value it was covering, so a hot-backline unit costs far more and stays put unless the prize outweighs it.
  Force size is ROI-optimal (add units while each ΔP(win) pays its commit cost) — lands near "enough to win plus a
  margin".
- **The band** reads the same `r` to pick *how* an offensive runs (`≥2` assault, `1–2` flank/encircle, `0.5–1`
  probe or muster, `<0.5` hold). `P(win)` (whether) and the band (how) are two jobs off one `r`.

**Gate before scoring.** Spend actions drop when `Cost > wallet` (a supply-gated build also drops with no truck on
hand). Commit actions drop when the roster holds no eligible unit, and an offensive drops when `P(win)` is below
the floor. Bank is a candidate, not a policy — a low flat score that wins only when everything else has saturated.

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
- **A multi-unit assault musters, then launches as one wave** (Phase 5). In `mustering` it binds force across ticks
  at a safe rally short of the target until the ROI-optimal force has converged, then advances all together — it
  never dribbles units into contact, which no-retreat would turn into defeat in detail. The bar is sized to exceed
  believed player force over the 3×3 on arrival, and rises if the player reinforces mid-muster. Mustering is also
  how a force-short action waits for units — from the roster or from Recruit.

## Templates (Phase 5)

A template is a unit-dispatching action's execution form — named roles and a phase sequence a single generic
**runner** steps off unit status. It is not separately scored (the action is; the template is *how* it runs), and a
simple tasking is the one-role, one-phase case, so adding a coordinated behaviour is a bigger template, not a new
subsystem. There is no planner.

**The runner**, each tick over every live intent with roles: refresh each bound unit's status; a required role
`dead`/lost → **abort** (release survivors, no AP refund); else advance `phase` when its transition predicate holds
(predicates read child status and geometry only); last phase complete → done, release. The runner sequences phases;
the route/streaming machinery moves the units.

**The roster** is the free-unit pool — every uncommitted `garrison`ed or `guard` unit. Binding pulls a unit (a
`garrison`ed draw strips that zone's reinforcement); release returns it. One unit, one owner. A template applies
only when its band fits, enough roles fill, and the geometry holds; short a role, it commits in `mustering`.

| Template | Picked when | Roles | Phases (→ on transition) |
|---|---|---|---|
| `assault` | band ≥ 2 | `attacker` ×1 | approach (direct) → S&D → resolve |
| `flank` | band 1–2, ≥2 mobile, a reachable flank cell | `fix` ×1, `maneuver` ×1+ | form (fix frontal; maneuver → flank cell, λ route) → *(fix engaged)* assault → resolve |
| `encircle` | band 1–2, target pocketed, ≥3 mobile | `blockers` ×N (per escape corridor), `crushers` ×1–2 | deploy (blockers → corridors) → *(in position)* seal → crush (inward) → resolve |
| `probe` | band 0.5–1 | `prober` ×1 (cheapest expendable; never armour/air/recon) | approach → make contact → resolve (survives ⇒ soft, escalate; dies ⇒ confirmed, mass/re-target) |
| `rapport` | a `supply` unit, a town in reach | `courier` ×1 | move → deliver (step rep 3 toward −10) → resolve |
| `scout` | a `recon` unit, a stale valuable area | `recon` ×1 | move (plain `move`; standing recon detection stamps belief as it goes) → resolve |
| `arty` | an observed belief point in range of an owned gun off cooldown | owned `guns` ×1–3 (hardpoints, 0 roster), `spotter` ×0–1 | mark → salvo (rounds × saturation) → assess (force dropped? re-fire : done) |

- **`probe` is disposable recon-by-fire** — no-retreat forbids poke-and-withdraw, so it converts uncertain belief
  into observed defender strength by drawing fire, reaching what recon cannot (a dug-in town garrison). It minimises
  stake, the inverse of every other commit's ROI sizing.
- **Escape corridors** (`encircle`): the target cell's neighbours whose enemy-influence gradient points outward.
- **`resolve`** is the transition that frees the units and writes the outcome, one predicate per action: **Attack** —
  no live BLUFOR in the zone radius (direct count, not belief), then **reuse the capture path**
  (`fnc_createzone.sqf` trigger → `fnc_captured.sqf`/`fnc_blufor_cap.sqf`); **verify that trigger fires for an
  AI-only fight with no player near** before this ships, else call the capture functions directly. **Intercept** —
  threatened ground clear, units release to `garrison` there. **Rapport** — courier delivers or dies.

## What AP buys

Three levels: **Action** (what AP commits to, scored and held), **Sink** (how it's paid — tier / strength / build /
tasking-spawn / bought fire mission), **Tasking** (orders emitted: 0 economic, 1 simple, N template). One actor
shares `WARCOM_opfor_ap`; every sink competes in the one appraisal — none runs on its own clock. Spends call
`["OPF", -_cost, _reason] call fnc_ap_adjust` (server-side, single writer, no race).

| Action | Class | Target | Sink | Taskings |
|---|---|---|---|---|
| Attack | offensive | a BLU-held zone | tasking-spawn | 1–N (band → template) |
| Intercept (QRF) | defensive | a sighted player near own ground | tasking-spawn | 1–N |
| Rapport | offensive | a town in reach (needs `supply`) | tasking-spawn | 1 courier |
| Recruit | buildup | the highest-value unmet unit need | tasking-spawn | 1 (`garrison`, resting) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 zone / 1 truck town |
| Scout | recon | a `recon` unit's route over stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed belief point in gun range | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 zone / 1 truck town |
| Build | defensive | an own threatened cell | hardpoint build | 1 truck |
| Bank | — | — | none | 0 |

- **Recruit fills the roster; every other unit-dispatching action drains it** — so OPCOM must build up before it
  strikes, and a lost unit is lost standing strength. It scores **once per demand group** (generic force, `recon`,
  `supply`, `transport`), each valued by the best action that group unlocks, so it hires exactly what it is short of.
  Units spawn only from OPFOR-held ground; taking the zone cuts what it can raise.
- **A unit's force is a token composition** — a row in `DUWS_opcom_recruitMenu` (`fnc_opcom_tasking_init.sqf`): an
  id, a **bare**-token composition (`none` posture, so OPCOM commands it), and capability flags. Priced from
  composition firepower × `OPCOM_AP_PER_FORCE` (`fnc_opcom_recruit.sqf`) — the single force↔AP knob, which also
  prices commit `Cost` and Arty kill Value, so the menu carries no price column.
- **Capability flags decide what a unit unlocks; there is no unit "type".** `recon` → Scout (range by platform,
  `OPCOM_RECON_K` cells), `supply` → a delivery run, `transport` → carry another unit; `noncombat` keeps a row out
  of a zone's reserve wave (regardless of armament — the boat is armed). A row may carry several.
- **The live-group cap is per active locality, not global.** Virtual taskings are cheap and uncapped;
  `OPCOM_MAX_TASKINGS` (start 10) budgets spawned AI per player-bubble / contact point, so one flank cannot starve a
  defender's spawn elsewhere, and co-op localities each keep their own budget.

**Supply gates the town-side builds.** A `supply` truck drives from OPFOR ground to a target cell and is spent on
arrival, behind four actions: Rapport, Build, and *town* Reinforce / Fortify. The AP is paid at commit but the
result lands only when the *specific* bound truck arrives — **kill it en route and the order fails, no refund**
(interdiction is the counterplay). No truck on hand (idle or affordable this tick) → the action drops from scoring.
**Zones need no supply** — reinforcing/fortifying a zone resolves on AP alone, reading as OPFOR trucking matériel
outward from its zones to the contested towns.

## What the commander builds

The escalation ladder and indirect-fire assets, once the commander spends on them. **Built but disabled:** a
standalone fortification director (`fnc_WARCOM_opf_hardpoints`) spent AP on flat-priced builds on its own clock
with no appraisal; its spawn is cut (file/compile stay), to be re-driven through the appraisal so build competes
for the wallet. Hardpoints otherwise generate at scenario init only.

**Build is scored like any other action** — target the threatened cell (read off the grid: a climbing `_ene`
magnitude, or a thin friendly front-contour), Value = own worth × threat. Given the site, the type is tier-gated by
the earned-AP ladder and archetype-weighted (`archWeight`), though it cannot be a *typed* counter (AT under armour)
until belief carries threat category ([§Open questions](#open-questions)).

Construction is an AP sink; no build refund (clearing pays the player CP only). Both columns key off
`WARCOM_opfor_ap_earned`, the high-water counter, never the spendable wallet:

| Highest AP reached | Garrison (any hardpoint) | Types the *director* may build |
|---|---|---|
| < 40 | 2–3 infantry | OP, MG |
| 40–99 | 3–4 infantry, one armed car | + AT |
| 100–135 | 4–5 infantry, an APC on the position | + AA, mortar pit (max 2 alive) |
| 136+ | 4–5 infantry, MBT if `HeavyArmor==1` else APC | + artillery battery (max 1 alive) |

The unlock column binds the *director* only — generation rolls from the full type list at any AP. The garrison
column applies to all (composition read at spawn), so an hour-one AA position revisited late has armour beside it.
The ladder is a composition table on the zone pattern (`DUWS_zoneSpawnTiers` / `DUWS_fnc_tokenClass`,
`fnc_zone_spawn_sizes.sqf`) — put the hardpoint tier in that file as its own small table. Knobs (all tune): seed
subset 2–3 at init; build tick every 20–30 min; gate AP > 10; costs 8–25 by type; no live cap (bounded by player
proximity).

### Indirect-fire hardpoints

Persistent enemy assets, two tiers sharing one fire-mission implementation. **None of the fire missions ships** —
the mortar and artillery cores exist as clearable emplacements but run no missions. A zone's own mortar is separate
and stays autonomous (`fnc_static_resolve`), uncapped here.

`doArtilleryFire` must issue from the machine where the gun is local; both are server-spawned, so the server issues
it (the locality rule that broke `fnc_helolift`). **Verify first** that an AI gunner reliably executes
`doArtilleryFire` — nothing in the mission has ever issued it; if not, the fallback is spawning shells directly as
the player's own arty support does (`client/supports/fnc_arty.sqf`), the gun becoming scenery.

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static `opfor_TURRET_MORTAR` | self-propelled `opfor_ARTY_X` |
| Unlocks at | 100 AP | 136 AP |
| Cooldown | 4–8 rounds, then 25–40 min | 6–10 rounds, then 40–60 min |
| Scatter | tighter (base 50 m) | wider (base 100 m) |

- **A fire mission is the Arty action** — scored and committed like any other, `Cost` scaling with rounds ×
  saturation; it fires only when that action wins its phase, never on a schedule. The owned gun off cooldown and in
  range is the availability gate, nothing more. **AP is the ammunition** — no finite store, the wallet limits.
- **Observation is the trigger** — nothing is shelled the enemy has not seen. A player above `east knowsAbout ~1.5`
  (shared with the sighting sweep); a BLU zone/FOB an OP covers or an OPFOR element was within ~500 m of in 15 min.
  OPs are the artillery's eyes; killing them blinds guns.
- **HQ exclusion** — no mission *aimed* inside 100 m of `PosOfBLUHQ` (rounds may still stray there from a barrage
  aimed elsewhere). The target grid is latched `[x,y,0]` at order time (never an object ref that would follow a
  respawn into the circle), and re-checked against the circle immediately before firing.
- **Scatter** is deliberate (`doArtilleryFire` converges): base by type, +25 m per km range, −30 m with direct OP
  observation. Telegraph: Allseer line + a temporary marker ~20 s before impact.
- **Capped campaign-wide** — one battery and two mortar pits alive at once across the map, spanning both flavours (a
  zone that rolls a mortar consumes one). These are the only permanent-crew hardpoints (~6 units that never
  despawn); making AA resident would add a fourth and needs its own cap.

## Archetype (Phase 6)

One archetype rolled per campaign (in the persistence snapshot, never re-rolled) sets the
`archWeight[archetype][actionClass]` factor — it *multiplies* an action class's score, never removes an action, and
cannot override the ladder (an Aggressive commander with no armour tier fields none). It is not difficulty
(`opfor_ai_skill` sets aim). A single authored per-class table; further leans (indirect fire, armour) become rows.

| Archetype | Weights toward |
|---|---|
| Defensive | Fortify, Reinforce, Build, Recruit, Intercept |
| Balanced | no strong lean — the baseline |
| Aggressive | Attack, Rapport; leaves ground thin |

## Town & zone garrisons

The OPFOR town ladder (tiers 0–IV in `DUWS_townSpawnTiers`, per-town `DUWS_townGarrisonTier` via
`fnc_town_garrison_setTier`) and the zone tiers are shipped and documented in
[`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv). Reputation
decides *whether* a town garrisons (crossing −10 writes tier I); AP decides *how hard*. Clearing a town drops it to
tier I (no refund, three-hour regroup lock) and pins it to the `0.3` strength floor for the campaign.

Not built:

- **Zone-side spend wiring.** Both sinks should reach zones as they reach towns, but a zone strength setter is
  missing — a pair of wrappers, one applying the reinforcement step to a zone key, one writing a zone tier with a
  clamp (zone read is `fnc_zone_strength` → `DUWS_fnc_garrisonStrength`; town write is
  `fnc_town_garrison_reinforce` → `DUWS_fnc_garrisonUnlose`). Open: whether a zone costs a town's price or more,
  and whether zone tiers are capped by the generation roll.
- **BLUFOR garrisons.** The BLUFOR band (`>= 10`) has no garrison; buying tier I at a held town *creates* one at
  zero strength (each reinforcement +30 %), never inherits OPFOR's — captured ground carries no tier or strength.
  The presence latch is still wanted (a BLUFOR town garrison streams), but the `Mobilising`/`Regrouping` holds are
  not (a BLUFOR garrison never arrives on ground it owns).

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

Planned, not shipped ([`campaign_persistence_plan.md`](../campaign_persistence_plan.md)); today persistence is the
engine's `saveGame`. OPCOM's store is shaped to serialise but implements no save/load — persisting its state is the
snapshot's responsibility. Contract: **Archetype** (input — fed back before the loop, never re-rolled); **standing
units & orders** (outcome — one row per unit: tasking, target, world position, `strength`, route mode; restored as
data, streaming to a live group on approach at saved strength); **tiers** (`WARCOM_opfor_tier` + earned counter,
owned by the economy). Every field a number/string/array; time in ticks off `DUWS_opcom_tick`. Whether the belief
store persists is [open](#open-questions) — it is shaped to serialise, and a restore that omits it rebuilds belief
from the first sensor pass; if kept, `fnc_opcom_belief_init` must initialise **init-if-nil** so a fed-back store
survives.

## Naming: OPCOM sits inside WARCOM

OPCOM is a component of WARCOM, not a replacement; prefixes split by ownership, nothing mass-renamed. Shared
war-economy state stays `WARCOM_` (`WARCOM_opfor_ap`/`_tier`); OPCOM's own state takes `OPCOM_`; the belief store
keeps `DUWS_` with an `opcom_` owner tag.

## Open questions

- **Typed belief for counter-building.** The grid is force magnitude only, so Build cannot site a typed counter (AT
  under armour, AA under air) until belief carries a threat category.
- **Whether the belief store should persist** ([§Persistence](#persistence)).
- **Whether the player can perceive the enemy is acting on stale information**, and whether it is worth surfacing
  (the intel system is the route). Same for **learning the commander's archetype**.
- **Whether an AI gunner reliably executes `doArtilleryFire`** — verify with a throwaway console test before writing
  the fire missions; if no, the shell-spawn fallback becomes the implementation.
- **What the commander does with a surplus**, and **whether it should be required to spend** rather than merely able
  to. Absorbers: Recruit (only while a locked prize exists), reinforcing over upgrading, mustering.
- **Tuning knobs** (mechanism ships, value tunes): `OPCOM_GARRISON_HEAL_RATE`; `OPCOM_AP_PER_FORCE` (the force↔AP
  rate); `OPCOM_MAX_TASKINGS` per locality and how a bubble is delimited; `OPCOM_COMMIT_HOLD`; the P(win) / band
  thresholds; the route λ weights and recompute cadence.
- **Accepted limitation — a fast airborne player** overflies a K=1 ring between ticks, unstreamed (same blind spot
  for recon detection). The fix, if it bites, is a larger K against airborne players, tuned then.
