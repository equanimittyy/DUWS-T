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
— is specified below. Everything from Phase 4 on is preliminary: it changes as each chunk is built and played.

## Status

| Phase | State |
|---|---|
| 1 — Perception, 2 — Force weighting, 3 — Recruitment & tasking wiring (+ transport ferry) | **shipped** (live-playtest verification of P3 pending) |
| 4, Stage A — Orders, driven by hand: 4.1 supply errands, 4.2 live engagement + the Attack order, 4.3 the Intercept order | [§Orders](#orders-phase-4-stage-a) |
| 4, Stage B — The decision loop: 4.4 spine + zone economy, 4.5 trucks + towns + Rapport, 4.6 need and cover fields + standalone hardpoints, 4.7 QRF + Attack decisions, 4.8 Scout, then one-gun Arty | [§Appraisal](#appraisal-phase-4) |
| 5 — Orchestration: multi-unit templates + mustering | [§Templates](#templates-phase-5) |
| 6 — Archetype: per-class weight sets | [§Archetype](#archetype-phase-6) |

Each phase ships runnable and verifiable before the next; the ordering is forced by what the next reads. Do not
pre-build later phases — the tuning constants and engine-contact behaviours (streaming, `doArtilleryFire`, AI-only
live fights) only settle by running the core. Stage A builds each order and its outcome under the debug harness
before Stage B scores them, so a wrong decision is never debugged together with a broken order.

## Shipped: the substrate the loop drives

The mechanism P4 scores against. Each row's code file is the SSOT for its behaviour; the notes are the
cross-cutting invariants a P4/P5 author must respect and that no single file states. Two terms carry one meaning
each throughout:

| Term | Applies to | Meaning |
|---|---|---|
| **Contested** | a zone or a town | BLUFOR are assaulting the site: OPFOR belief holds a BLUFOR sighting within one grid cell of its edge, rebuilt once per tick (`fnc_opcom_contested.sqf`). Built for zones only: the rebuild skips the `town_` sites |
| **Engaged** | a unit | The unit is live and fighting BLUFOR: its leader is in `COMBAT`, or knows the nearest player above 1.5 (`fnc_opcom_task_step.sqf:69-77`). A virtual unit, a zone and a town are never engaged |

| Subsystem | Code | Invariant that still binds new work |
|---|---|---|
| **Belief store** | `belief/fnc_opcom_belief_init.sqf`, `fnc_opcom_force.sqf`, `fnc_opcom_contested.sqf`, sensors in `fnc_opcom_perception_run.sqf` | The commander plans against belief, never truth: only the sensors read live player state (`allPlayers`/`getPos`/`knowsAbout`). Belief tracks groups, not players; a human weighs `OPCOM_PLAYER_WORTH`. Store a position, never a handle |
| **Influence grid** | `belief/fnc_opcom_grid_init.sqf`, `fnc_opcom_grid_rebuild.sqf`, `fnc_opcom_grid_coords.sqf` | Two force layers (`_fri` known OPFOR, `_ene` believed BLUFOR), firepower-weighted and condition-scaled, rebuilt each tick. Exposes what scoring reads: **`r`** = Σ`_fri`/(Σ`_ene`+1) over a 3×3 block, **threat** = `_ene` on own ground, the **front line** (sign-change band), and **route-around** (lowest-`_ene` neighbour). Static per-cell masks classify land / navigable-water / air domains for routing and the ferry |
| **Movement & streaming** | `taskings/fnc_opcom_move.sqf`, `fnc_opcom_route.sqf`, `fnc_opcom_stream.sqf`, `fnc_opcom_task_step.sqf` | A tasking is a virtual world-point stepping a route (A\* cost field foot/air/boat, `fnc_convoy_path` road for wheeled/tracked) until a player closes within **K cells** (per move type), then it spawns live. Stow is temporal hysteresis (`OPCOM_REVIRT_GRACE` clear ticks). Not built (4.2): a unit renders only when it has something to engage — a live BLUFOR group within K spawns it as a player does, spawn takes a one-tick entry buffer (within K on two consecutive ticks, so a fast flyover never streams), and stow waits until neither is within K — so every engagement, AI-only included, runs live. Streaming is side-symmetric and the **engine resolves combat** — `P(win)` never dices one. Spawn posture is the closest A3 order to the tasking, re-issuable live |
| **Tasking, status & strength** | `taskings/fnc_opcom_tasking_init.sqf`, `fnc_opcom_strength.sqf`, `fnc_opcom_task_step.sqf` | Each unit has a standing **tasking** (`garrison`/`guard` rest; the rest active) and a **status** (`virtual`/`moving`/`engaged`/`dead`). `effForce` (power × condition) is what the grid deposits, so a shot-up group weighs less automatically; `strength` (0..1) is persisted and heal-targeted; `garrison` heals at `OPCOM_GARRISON_HEAL_RATE`, `guard` does not. A `garrison` never streams live: a live unit reaching its return zone despawns into it, settling only once it is not engaged and the zone is not contested. A recruited combatant feeds its zone's reserve wave. A unit garrisoned in a contested zone is off every draw — built inline in the ferry pool only; the shared filter lands with the truck-source pick (4.5) |
| **Transport ferry** | `taskings/fnc_opcom_ferry.sqf` (+ `_virt` / `_devirt`), [§Transport](#transport-shipped) | A land unit stopped at a water leg borrows the nearest idle water-compatible hull, which carries it across and then garrisons the nearest held zone. The ferry is a *consequence of the rider's route*, never an order. Combat gates the borrow, never a bound crossing |

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
  different shapes: a **rotary** takes the rescue-squad pickup (`fnc_rescue_squad_success.sqf`) — a helipad marks
  its LZ so `land` settles on the spot, its pilot is pinned (no fleeing, no targeting) and its crew CARELESS/BLUE;
  within `OPCOM_FERRY_LAND_K` grid cells of the LZ — a gate one cell wide that reads no altitude — it assigns the
  squad their seats, walks them to the nearest point `OPCOM_FERRY_STAGE` off the LZ so it does not set down on its
  own riders, and lands with `land "GET IN"`, which keeps the engine turning where `"LAND"` shuts it down. That
  hold waits on the assignment, not on the walk, so the `orderGetIn` goes out only from pickup-board with the skids
  down, each man despawning as he enters. Assigned to nobody, `"GET IN"` completes at once and lifts the hull
  straight off again. The board order is re-issued each tick to whoever is still outside, and at half the cap the
  hold-outs are teleported into the cabin — a man left holding a seat assignment from when the cabin was full never
  re-paths himself. Descent and board hold a cap each, so a slow approach cannot eat the walk-aboard; a board
  unfinished at its cap despawns the men still ashore. At the drop it sets down on a second helipad with
  `land "GET OUT"`, which keeps the engine turning where `"LAND"` shuts it down. No landing hold lasts a whole
  dismount, so the squad is seated before the descent and rides it down, and the grounded hull is pinned with
  `flyInHeight 0` — its waypoint reached and its hold spent, a pilot otherwise climbs back to cruise and hovers
  over the pad. Whoever the cabin cannot take waits 10 km above the LZ (hiding lands a frame late, so a group
  raised on the pad flashes there) and rides in as seats free. On the ground it turns one man out every two
  seconds, leader first, refilling the cabin before each, and lifts off once the queue and the seats are empty,
  the pin undone at release. Every exit is gated on the hull still being grounded, because the pin is all that
  holds it: a hull that lifts with men still to come out, one that never settles, or a dismount out of time sets
  them down at the LZ rather than turning them out at height. The pilot itself is never pinned —
  `disableAI "MOVE"` takes away the control that keeps a hull on the ground and crashed one with its riders
  aboard. Men still aboard when the hull goes down are lost with it. A **boat** never boards or dismounts
  men: it parks `OPCOM_FERRY_BOAT_PARK` out from the shoreline nearest the riders (a water-cell centre can sit
  ~350 m out) while they walk to that shore, and the whole group vanishes into it once its leader is within
  `OPCOM_FERRY_BOARD_BOAT` of the shore, then
  spawns ashore at once — boats are finnicky, so this mass swap is deliberate, do not unify the two shapes.
  Each live leg's move order goes out once, as the leg starts.
- **Strength freezes on pickup, thaws on drop.** From the board commit (a rotor's landing order, a boat's vanish)
  the rider's `effForce` is snapshotted and belief stops reading its live count (board-despawn is not a casualty).
  The freeze thaws, the rider detaches (`ridingOn = -1`) and it takes up its own route the instant it is back on
  the ground — a boat's group as it spawns ashore, a rotor's as its first man gets out — so egress losses count.
- **A freed hull goes home.** When the carry ends (the crossing is done, or the rider is lost), the hull takes a
  `move` to garrison the nearest OPFOR-held, uncontested zone — a boat goes to the nearest such zone's port. It is
  off the pool until it settles there. With no such zone, it holds `guard` where it stands.
- **A boat** is its own move type (water-passable, land-impassable), armed by default, spawning and garrisoning
  on its zone's **port** (`taskings/fnc_opcom_ports.sqf`) — the one navigable-water cell within 3 grid steps
  that zone owns (a cell two zones claim goes to the nearer; the loser takes its nearest unclaimed land-adjacent
  cell). A portless zone refuses boats outright, as a hire target and as a return-to-garrison pick. The borrow
  has no lift-type preference — the closest free hull wins, boat or rotary alike. A port draws on every player's
  map as a `loc_Quay` marker at its cell centre, hidden under hardcore fog until `fnc_zone_reveal` finds its zone
  and carrying its zone's own colour, so it turns with each capture.

Not built (Phase 4 valuations on the shipped mechanic): whether an idle hull leaves its post to ferry; whether a
rider waits for lift or walks a longer route (real only once P4 lowers `OPCOM_ROUTE_LIFT_PENALTY` so water is a
genuine shortcut); and **land-taxi** — lifting a foot unit over dry ground to save time, reusing the whole carry
engine with a distance trigger and a land-transport pool.

## Orders (Phase 4, Stage A)

Stage A finishes the orders the decision loop will issue, so each one runs to its outcome when driven by hand
through the debug harness (`taskings/fnc_opcom_debug_task.sqf`). Nothing scores or picks yet, and a harness order
spends no AP. Stage B owns everything that decides or pays: scoring, prices, the truck-source pick and the shared
contested draw-lock filter it brings, Recruit, and the need and cover fields.

### 4.1 Supply errands

Today a `move` with `supplyDrop` set deletes its truck on arrival and only logs "supply delivered"
(`fnc_opcom_task_step.sqf:80` live, `:175` virtual).

- **The errand.** The tasking record takes an `errand` field, set with the order, in place of the `supplyDrop`
  flag: a set errand is what marks a supply run. Each kind maps to one writer:

  | Errand | Effect | Writer |
  |---|---|---|
  | `["reinforce", townIndex]` | +0.3 strength | `fnc_town_garrison_reinforce` (`fnc_civ_state_init.sqf:146`) |
  | `["fortify", townIndex]` | tier +1, clamped at IV | `fnc_town_garrison_setTier` (`fnc_civ_state_init.sqf:176`) |
  | `["rapport", townIndex]` | reputation −3 | `fnc_town_rep_adjust` (`fnc_economy_init.sqf:165`) |
  | `["build", pos, type]` | a standalone hardpoint of that type near `pos` | `fnc_hardpoint_spawn_sited` (`fnc_hardpoint_place.sqf:184`), drawing with `fnc_hardpoint_band_cand` around `pos` |

- **`fnc_opcom_deliver`** (new, `taskings/`) replaces the log in both arrival branches: it reads the errand kind
  and calls the writer. A build runs with `spawn`, because the builder sleeps in its crew drop
  (`fnc_hardpoint_place.sqf:182-183`) and the tick must never sleep.
- **The truck is spent** — it despawns once its errand lands. A killed truck delivers nothing: the dead-unit sweep
  removes it (`fnc_opcom_task_step.sqf:59`, `:194`) and its errand goes with it.
- **A refused errand is lost.** Both town garrison writers refuse a raise while the town is `REGROUPING`; the truck
  is still spent. Stage B's candidate sweep skips a regrouping town, so only a town that starts regrouping while
  the truck is on the road loses the delivery.
- **The zone writers** ([§Town & zone garrisons](#town--zone-garrisons)). A zone buy needs no truck and resolves
  the tick it is ordered, so these are called directly, not through an errand. *Zone reinforce* applies the town
  step to a zone's garrison key through `DUWS_fnc_garrisonUnlose`, re-deriving the reserve pool when the garrison
  stands. *Zone tier* raises `DUWS_zoneTier_<key>` (read by `fnc_zone_tier`) by one, clamped at IV whatever tier
  the zone rolled, and re-stamps the new tier's full potential with `DUWS_fnc_garrisonSetFull` so the new men count
  as owed; the tier also raises the zone's hardpoint cap (`fnc_hardpoint_zone_cap`). *Zone build* calls
  `fnc_hardpoint_spawn_sited` with the zone key and the in-zone draw `fnc_hardpoint_site_zone` uses, the type given,
  under a fresh hardpoint key, with `spawn`.
- **Harness.** The `supply` verb takes the errand as a fourth argument; a new
  `["zone", "reinforce" | "fortify" | "build", zoneKey, type]` verb calls the zone writers.

Done when a truck sent by hand to a town raises its strength or tier, or steps its reputation, and despawns; a
truck sent to a band position builds the type it carries; a killed truck changes nothing; and each zone verb
changes its zone the same tick.

### 4.2 Live engagement and the Attack order

Today a virtual tasking spawns only when a player is within K (`fnc_opcom_task_step.sqf:141`, `:152`, `:184`) and
stows after `OPCOM_REVIRT_GRACE` ticks with no player near (`:120-127`). An OPFOR retake runs through an
`EAST SEIZED` trigger (`fnc_captured.sqf:72`, `fnc_blufor_cap.sqf:56`) that sees live units only, so a virtual
attacker with no player near never takes the zone. The rule 4.2 builds: **a unit renders only when it has
something to engage, and every engagement runs live.**

- **Entry buffer.** A `nearTicks` counter, the mirror of `farTicks`, gates every de-virt site: a unit spawns only
  after two consecutive ticks with a player or a live BLUFOR group within its K, so a jet crossing the ring on one
  tick spawns nothing.
- **Render on live BLUFOR.** Every de-virt site counts a live BLUFOR group within K as it counts a player, so a
  player's AI squad or a headless client's group draws a real fight. It is a streaming read of true positions,
  like the existing `allPlayers` read, and never reaches belief or scoring. A unit with nothing within K stays
  virtual, even at its target.
- **Stow rule.** A live unit counts far ticks only while no player and no live BLUFOR group is within K, so it
  cannot flap between live and virtual beside an AI squad.
- **Assault resolve.** `assault` already exists as an order (`fnc_opcom_task.sqf:4`); its target is a BLUFOR-held
  zone. The order ends when the zone flips to OPFOR, or when the attacker dies. A live attacker then drops to
  `guard` in the zone and settles into its garrison only once it stows back to virtual, so it never vanishes in
  front of a player; a virtual attacker settles at once. Either way it joins the zone's reserve wave, since a
  retaken zone restarts on a thin 0.3 garrison (`fnc_opfor_cap.sqf`).
- **Capture mirror.** A new `fnc_zone_retake_ready` mirrors `fnc_zone_capture_ready`: the zone's BLUFOR garrison
  is beaten (none exists yet, and a zone with none bought always counts as beaten), and OPFOR in the trigger area
  outnumber BLUFOR. It replaces `EAST SEIZED` at the two re-arm sites with an `EAST PRESENT` trigger gated on the
  check. A zone can now flip with players still inside it, and the retake takes no hold: ground changes hands back
  and forth under a live fight.
- **Virtual capture.** An empty BLUFOR zone renders nothing, so a virtual attacker there trips neither the trigger
  nor the contact report. Each tick, for a virtual `assault` tasking inside its target zone's radius, OPCOM runs
  the same check on stored state — the attacker's stored force is the OPFOR present, and BLUFOR present is nil,
  since any BLUFOR within K would have rendered the attacker — and calls `fnc_opfor_cap` when it holds.
- **Contact report.** A live attacker inside the radius trips the zone's existing `EAST PRESENT` trigger
  (`fnc_createzone.sqf:153-167`) and `fnc_enemy_contact`. A virtual attacker has no units to trip it, so OPCOM
  calls `fnc_enemy_contact` itself when the attacker enters the radius, with no map marks, since there is no live
  leader to mark.
- **Docs that change with the code.** `zones_and_civilians.md:297-299`, the header of `fnc_zone_capture_ready.sqf`
  and the comment at `fnc_opfor_cap.sqf:27-29` all describe the `EAST SEIZED` retake, and the last claims a retake
  cannot happen under a player's feet.
- **Harness.** The existing `task` verb issues `assault`.

Done when a player flying through a virtual unit's K on a single tick spawns nothing; an assault on an empty
BLUFOR zone with every player far away takes it the tick the virtual attacker enters the radius, posts the contact
notification and garrisons the attacker there; and, with a player's AI squad in that zone, the attacker renders
once the squad is within K and the zone flips only if OPFOR win and outnumber BLUFOR.

### 4.3 The Intercept order

- **The order.** `fnc_opcom_task` takes a new order, `intercept`, whose target is a belief row key (a BLUFOR
  group's `netId`), not a position.
- **Following.** Each tick the destination is the row's latest believed position. The route is re-planned only
  when that position moves more than one cell, because the router runs one A\* search per tick. If the row decays
  on the way, the unit keeps the last position it read.
- **Truth read.** Within its own K (`DUWS_opcom_streamK` for its move type), an intercepting unit reads true
  BLUFOR positions, whatever the unit is. The read is a sensor: BLUFOR found refresh their rows through
  `fnc_opcom_belief_upsert`, and an empty block clears the rows in it through `fnc_opcom_cover_clear`.
- **Resolve.** At the last known position with no BLUFOR within K, the order drops to `guard` in place, where the
  unit waits for its next order. BLUFOR within K have already rendered the unit (4.2); it fights them live and
  drops to `guard` once none remain within K. An interceptor never returns to garrison.
- **Harness.** A new `["intercept", id, rowKey]` verb.

Done when a unit sent at a sighting whose squad has left arrives, clears the row and guards; one sent at a squad
still there renders, fights and guards after; and one sent at a moving squad re-routes as the sighting updates.

## Appraisal (Phase 4)

Each tick, enumerate candidate `[action, target]` pairs, gate cheaply, score the survivors, pick by weighted
random over the top few (`selectRandomWeighted` over the top three, the `fnc_createzone.sqf:129` idiom). No search
or lookahead. Scoring is Phase 4 Stage B, built on the orders Stage A ships ([§Status](#status)); what follows is
the model it builds.

The score is one number — expected AP returned per AP spent:

```
score = archWeight[archetype][actionClass] × P(win) × Value / Cost
```

`Value` and `Cost` are both Army Power, so the units already agree; `archWeight` tilts by action class
([§Archetype](#archetype-phase-6)); `P(win)` scales to the expected return.

- **`P(win)` — Lanchester-square.** `P(win) = r² / (r² + 1)` over the target's 3×3 `r`. Parity is a coin-flip, a
  2:1 edge ≈ 0.8, a hopeless ratio floors near 0. The economy chunks stub it at 1; the real formula lands with the
  QRF and Attack decisions (4.7).
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
- **`resolve`** is the transition that frees the units and writes the outcome, one predicate per action
  ([§Orders](#orders-phase-4-stage-a)): **Attack** — OPFOR take the zone by the mirror of
  BLUFOR's capture rule (`fnc_zone_capture_ready`): the zone's BLUFOR garrison beaten, none bought counting as
  beaten, and OPFOR outnumbering BLUFOR in the radius. A live fight flips through the retake trigger; a virtual
  attacker at an empty zone flips it on the OPCOM tick against stored state, and OPCOM sends that attack's contact
  report itself. The attacker garrisons the zone once it is virtual. **Intercept** — at the sighting's last known position the
  unit reads truth within its own K: nothing there, it drops to `guard` in place; BLUFOR there, it fights them live
  and guards once none remain. It never returns to garrison. **Rapport** — courier delivers or dies.

## What AP buys

Three levels: **Action** (what AP commits to, scored and held), **Sink** (how it's paid — tier / strength / build /
tasking-spawn / bought fire mission), **Tasking** (orders emitted: 0 economic, 1 simple, N template). One actor
shares `WARCOM_opfor_ap`; every sink competes in the one appraisal — none runs on its own clock. Spends call
`["OPF", -_cost, _reason] call fnc_ap_adjust` (server-side, single writer, no race).

| Action | Class | Target | Sink | Taskings |
|---|---|---|---|---|
| Attack | offensive | a BLU-held zone | tasking-spawn | 1–N (band → template) |
| Intercept (QRF) | defensive | a BLUFOR sighting inside OPFOR's area of influence | tasking-spawn | 1–N |
| Rapport | offensive | a town in reach (needs `supply`) | tasking-spawn | 1 courier |
| Recruit | buildup | the highest-value unmet unit need | tasking-spawn | 1 (`garrison`, resting) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 zone / 1 truck town |
| Scout | recon | a `recon` unit's route over stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed belief point in gun range | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 zone / 1 truck town |
| Build | defensive | an own zone ring or band cell | hardpoint build | 0 zone / 1 truck standalone |
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
arrival, behind four actions: Rapport, standalone Build, and *town* Reinforce / Fortify. The AP is paid at commit but the
result lands only when the *specific* bound truck arrives — **kill it en route and the order fails, no refund**
(interdiction is the counterplay). No truck on hand (idle or affordable this tick) → the action drops from scoring.
**Zones need no supply** — zone Reinforce, Fortify and hardpoint Build resolve on AP alone, reading as OPFOR
trucking matériel outward from its zones to the towns.

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
- **Capped campaign-wide** — one battery and two mortar pits alive at once across the map. These are the only
  permanent-crew hardpoints (~6 units that never despawn); making AA resident would add a fourth and needs its own
  cap.

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

- **Zone-side spend wiring (4.1).** Both sinks should reach zones as they reach towns, but a zone strength setter
  is missing — a pair of wrappers, one applying the reinforcement step to a zone key, one raising a zone's tier
  clamped at IV whatever tier it rolled at generation and re-stamping its full potential (zone read is
  `fnc_zone_strength` → `DUWS_fnc_garrisonStrength`; town write is `fnc_town_garrison_reinforce` →
  `DUWS_fnc_garrisonUnlose`). Open: whether a zone costs a town's price or more.
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
- **Accepted limitation — recon detection samples once per tick**, so a fast airborne player can cross a recon's
  K reach between ticks unsensed. The fix, if it bites, is a larger K against airborne players, tuned then.
