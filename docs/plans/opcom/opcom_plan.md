# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns,
tasks squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and the faucets
that fill it are the economy's ([`economy_second_pass.md`](../economy_second_pass.md#army-power)); the
shipped hardpoint mechanics it draws from are [`info/hardpoints.md`](../../info/gameplay/hardpoints.md);
the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting).

## The three layers

Three layers, one thread.

| Layer | Does | Runs |
|---|---|---|
| **Perception** | Maintains the enemy's *belief* about BLUFOR. Never reads live player state | Every tick, one engine call per BLUFOR group |
| **Appraisal** | Scores each candidate `[action, target]` pair as an expected AP return, picks by weighted random over the top few | Every tick, one unscheduled batch |
| **Commitment** | Turns a choice into an intent with a minimum lifetime and an owner. Re-scoring fills free capacity and may abandon a still-virtual intent whose ROI has collapsed, but never one whose units are in contact | Between ticks |

## Perception: the commander plans against belief, never against truth

The commander reads a belief store. Only the sensors below read truth (`allPlayers`, `getPos`,
`knowsAbout`). Nothing else in OPCOM may read live player position or strength.

### Shape

Parallel arrays, server-local, indexed together, every entry a number or an array of numbers.
Serialisable — the mission namespace is the save file, so state that might outlive a session holds no
handles ([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#why-hardpoints-are-not-zones),
[`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).
Model on `DUWS_sites` (server-local, handle-free), not `DUWS_hardpoints` (a single mixed-type,
`publicVariable`d row array). Not broadcast — no client reads belief.

| Array | Holds |
|---|---|
| `DUWS_opcom_belief_key` | what is believed about: a BLUFOR group's `netId`, a zone index, a FOB index, the player HQ |
| `DUWS_opcom_belief_pos` | `[x,y,0]` as last observed, never a live lookup |
| `DUWS_opcom_belief_time` | the tick counter at the observation |
| `DUWS_opcom_belief_str` | believed BLUFOR force there ([§The quantity](#the-quantity-force-not-coverage)) — each AI counts one, each human `OPCOM_PLAYER_WORTH`, so a group carrying players weighs heavier |

One entry per subject, keyed by `DUWS_opcom_belief_key`; a repeat observation overwrites that entry
rather than appending, and only on a fresh acquisition — `knowsAbout` past the gate and not falling
([§Sensors](#sensors)), the reading superseding the stored one outright. Belief tracks groups, not
individual players, so a squad is one row whether or not it carries a player, and players sharing a group
are not double-counted.

New state takes the `DUWS_` prefix with an `opcom_` tag naming its owner
([`info/architecture.md`](../../info/architecture.md#globals-have-no-namespace)).

Store a position, never an object handle — an object reference re-resolves every tick and follows a
player through respawn, taxi and fast travel. Same latching rule as the artillery target grid
([§Observation is the trigger](#observation-is-the-trigger)).

### Sensors

| Sensor | Writes | Cost |
|---|---|---|
| Direct sighting | for each BLUFOR group, an *acquisition* — `east knowsAbout (leader _grp) > 1.5` and not falling since last tick — stamps the leader's position, the group's threat (each AI one, each human `OPCOM_PLAYER_WORTH`), and the tick; a falling scalar (contact fading) does not write, so the stamp freezes at last-seen and decays | one engine call per BLUFOR group per tick |
| Absence | a group whose belief row resolves (`groupFromNetId`) to a dead, drained or deleted group is dropped, so a confirmed-gone force stops depositing; server-polled, never a `Killed` handler | one resolve per group-keyed row per tick |
| Observation post | an OP hardpoint covering ground stamps what it sees | [§Observation is the trigger](#observation-is-the-trigger) |
| Area of influence | a BLUFOR group inside OPFOR area of influence (`fnc_aoi_opfor_covers`) stamps a low-strength, delayed entry | one coverage read per group per tick |
| Zone flip | stamps exactly and free | event-driven |
| Intel patrol tasking | a purchased sensor ([§What the commander spends on](#what-the-commander-spends-on)) | the tasking's own cost |

`east knowsAbout` is a side-wide query — the sighting sweep is one call per BLUFOR group (on its leader),
no `nearEntities`, no scan over `allUnits`
([`info/performance.md`](../../info/architecture/performance.md#the-pattern-that-costs-the-most-timed-scans-anchored-on-allunits)).
Threshold `1.5` is shared with the artillery observation gate — one constant, do not add a second.

### Decay

Decay models *lost track* only — a group that is alive but unseen, its stamp aging as confidence in it
falls. A group *confirmed gone* (destroyed, drained by a merge, or deleted) is not left to decay: the
absence sensor ([§Sensors](#sensors)) drops its row the same tick, so a stamp aging to expiry now means
strictly "not seen since", never "may already be dead".

Confidence falls with the age of the stamp, counted in **ticks**, not seconds: a stamp holds the tick
counter at observation, and `_age` is the current counter minus it. Two thresholds, in ticks, derived from
real-time horizons over `OPCOM_TICK_PERIOD` — `OPCOM_BELIEF_FRESH` (240 s, 4 min) and `OPCOM_BELIEF_EXPIRE`
(960 s, 16 min) — so retuning the tick holds the memory horizon.

| Age of stamp | Treated as |
|---|---|
| under `OPCOM_BELIEF_FRESH` ticks | current — full weight in scoring |
| `OPCOM_BELIEF_FRESH` to `OPCOM_BELIEF_EXPIRE` ticks | stale — weight falls off linearly to 0, still worth acting on |
| over `OPCOM_BELIEF_EXPIRE` ticks | expired — dropped from the array |

The decay factor the influence grid scales a belief entry by is
`((OPCOM_BELIEF_EXPIRE - _age) / (OPCOM_BELIEF_EXPIRE - OPCOM_BELIEF_FRESH)) max 0 min 1`
([§Rebuild](#rebuild-deposit-each-source-with-a-linear-falloff)).

### What the enemy knows for free

- **What it owns**: its towns, garrison tiers, hardpoints, its own wallet and tier.
- **Which zones the player holds** — territorial facts.

Everything about the player's *current position and strength* goes through belief.

## The influence grid: one spatial substrate

A structure Perception stamps and Appraisal reads. Answers *how contested is this ground* — front
line and route-around — which the point-sampled terms cannot.

### The quantity: force, not coverage

Every cell holds a **force** figure in **firepower-weighted** units, not a body count: each unit
contributes a combat-power value set by its engine type category (`isKindOf`), so a tank outweighs a
rifleman. One table serves both sides — OPFOR (ours, known) and believed BLUFOR (read off a sighting) —
and a modded faction's units classify the same way, so the metric carries no mod dependency.

| Category (`isKindOf`) | Power (starter, tune) |
|---|---|
| Man | 1 |
| Car — armed | 3 |
| Car — unarmed / logistics | 0–1 |
| Armored (APC / IFV) | 6 |
| Tank (MBT) | 12 |
| Helicopter | 15 |
| Plane | 15 |

A unit contributes its power **scaled by its current condition** ([§Unit strength](#unit-strength)), so a
depleted group weighs less with no extra logic — the grid deposits `effForce` (power × condition), never
full strength. Two layers carry it: `friendly` is OPFOR force, `enemy` is believed BLUFOR force. This is
the unit the muster check and the force ratio need; the AOI field's binary coverage cannot supply it
([§It is not the AOI field](#it-is-not-the-area-of-influence-field)).

### Geometry

Two flat numeric arrays, `DUWS_opcom_grid_fri` and `DUWS_opcom_grid_ene`, server-local, numbers only,
no handles, length `_w * _w`. Never persisted; rebuilt from holdings and belief each tick, so a
restored campaign fills them on its first tick.

| Quantity | Definition |
|---|---|
| Cell edge | `OPCOM_GRID_CELL`, 500 m |
| Width `_w` | `ceil(worldSize / OPCOM_GRID_CELL)` — 62 against Altis (`worldSize` 30720, 3844 cells) |
| Cell index | `_cell = _cy * _w + _cx` |
| World to cell | `_cx = (floor (_x / OPCOM_GRID_CELL)) min (_w - 1) max 0`, same for `_cy` |
| Cell to world centre | `[(_cx + 0.5) * OPCOM_GRID_CELL, (_cy + 0.5) * OPCOM_GRID_CELL, 0]` |

Two static per-cell arrays alongside, built once at init and never rebuilt:

- **Land mask** `DUWS_opcom_grid_land` — one `surfaceIsWater` at each cell centre (3844 calls, one-time). A
  cell is passable to ground movement only where the mask reads land.
- **Connectivity** `DUWS_opcom_grid_comp` — a flood-fill of the land mask labelling connected land
  components. A ground tasking is ordered only where source cell and target cell share a component, so
  the director never sends a ground squad at an island it cannot reach ([§Routing](#routing-a-cost-field-over-the-grid)).

### Rebuild: deposit each source with a linear falloff

Zero both arrays, then deposit each force source once. A source is `[_pos, _weight, _reach]`; it adds
to every cell whose centre lies within `_reach`:

```
_k = ceil (_reach / OPCOM_GRID_CELL);
// scan only the (2_k+1) box around the source cell, clamped to the grid — never the whole array,
// never a pass over allUnits
for "_cy" from (_scy - _k) max 0 to (_scy + _k) min (_w - 1) do {
    for "_cx" from (_scx - _k) max 0 to (_scx + _k) min (_w - 1) do {
        _d = _pos distance2D <cell centre>;
        if (_d <= _reach) then {
            _cell = _cy * _w + _cx;
            _layer set [_cell, (_layer select _cell) + _weight * (1 - _d / _reach)];
        };
    };
};
```

Falloff is linear and floors at 0 on the reach edge. Footprints are small — this is a force field, not
the AOI coverage projection, so a source spreads ~1 km (`OPCOM_GRID_SPREAD`, 2 cells), never the 2–5 km
AOI reaches. That spread bleeds force across cell boundaries, so a unit just outside a read footprint
still counts, fading with distance — the read box does not need a hard edge.

**Friendly layer** (`DUWS_opcom_grid_fri`) — OPFOR force, known exactly, no belief scaling. Weight is
category-power ([§The quantity](#the-quantity-force-not-coverage)) summed over the source, condition-scaled
where the source is a unit:

| Source | Position | Weight | Reach |
|---|---|---|---|
| OPFOR-held zone, base garrison | `zone_meta_array` pos (`select 1`) | base-tier composition force (Fortify raises this; recruits do not) | zone size (`select 2`) + `OPCOM_GRID_SPREAD` |
| Banded town garrison | `civ_locations` | `DUWS_townGarrisonTier` composition force | `civ_radii` + `OPCOM_GRID_SPREAD` |
| OPFOR hardpoint | `DUWS_hardpoints` pos (`select 1`) | its crew / weapon power | `OPCOM_GRID_SPREAD` |
| OPFOR unit (`garrison` / `guard` / tasking) | its cell — stored (virtual) or live | its `effForce` ([§Unit strength](#unit-strength)) | `OPCOM_GRID_SPREAD` |

**Enemy layer** (`DUWS_opcom_grid_ene`) — believed BLUFOR force:

| Source | Position | Weight | Reach |
|---|---|---|---|
| BLU-held zone | zone pos | its known garrison force, nominal where none exists | zone size + `OPCOM_GRID_SPREAD` |
| Belief entry | `DUWS_opcom_belief_pos` | `DUWS_opcom_belief_str` × decay factor | `OPCOM_GRID_SPREAD` |

A belief entry covers a sighted player, a discovered HQ and a discovered FOB alike. The decay factor
is `((OPCOM_BELIEF_EXPIRE - _age) / (OPCOM_BELIEF_EXPIRE - OPCOM_BELIEF_FRESH)) max 0 min 1` with `_age`
in ticks — 1 under `OPCOM_BELIEF_FRESH`, falling to 0 at `OPCOM_BELIEF_EXPIRE` ([§Decay](#decay)); an
expired entry is already dropped from the arrays, so it never deposits.

| Constant | Value |
|---|---|
| `OPCOM_GRID_CELL` | 500 m |
| `OPCOM_GRID_SPREAD` | 1 km (2 cells) — force-projection footprint, added to a zone/town radius |

### What reads it

`_gridFri`/`_gridEne` below are `DUWS_opcom_grid_fri`/`DUWS_opcom_grid_ene`. A point read is
`(_gridFri select _cell) - (_gridEne select _cell)` — the signed force balance.

| Read | How |
|---|---|
| **Force ratio `r`** ([§Appraisal](#appraisal-expected-ap-return)) | `Σ(_gridFri) / (Σ(_gridEne) + 1)` over the target's 3×3 block — feeds `P(win)` and the action band |
| **Threat** (defensive Value, [§Appraisal](#appraisal-expected-ap-return)) | `_gridEne` on and around own ground — how threatened it is, scaling a Fortify / Reinforce / Build / Recruit / Intercept Value |
| **Force at a place** (clustering) | `_gridEne select _cell` — the deposit already summed every belief entry in the cell, so a four-to-eight-player co-op stack is one read, no separate clusterer ([§Open questions](#open-questions)) |
| **Muster** ([§Commitment](#commitment-intents-are-sticky)) | sizes the gather: the rally force is built until it would exceed enemy over the target's 3×3 on arrival; the bar rises if the player reinforces the target mid-muster |
| **Front line** | the cells whose signed balance differs in sign from an orthogonal neighbour's — the zero-crossing band, read by the overlay |
| **Route-around** (live group) | among the target cell's 8 neighbours, the one with the lowest `_gridEne`; its centre is a staging waypoint handed to a spawned group's engine pathing. The full route for a *virtualised* squad is [§Routing](#routing-a-cost-field-over-the-grid) |
### Routing: a cost field over the grid

A virtualised tasking follows a **cell chain** produced by a shortest-path search over the grid, cost
per step:

```
cost(step into _cell) = stepLen + OPCOM_ROUTE_LAMBDA * _lambda * (_gridEne select _cell)
```

- `stepLen` is `OPCOM_GRID_CELL` orthogonally, `OPCOM_GRID_CELL * sqrt 2` on a diagonal — 8-neighbour
  steps. Water cells (land mask false) are impassable to ground; air and boat treat every cell passable.
- `_lambda` is **0 for a direct route** (rapport, scout, the Assault template — distance only,
  ignores the enemy) and **1 for a flank** (the Flank / Encircle templates — the path bends around
  believed enemy force). The search is Dijkstra; at 3844 nodes it is cheap, but **not inside the `isNil`
  scoring block** — run it scheduled or on its own bounded pass.
- **When λ=1 is used**: the band picked the Flank or Encircle template
  ([§Templates](#templates-the-execution-forms)), and a lower-cost detour around believed enemy force
  exists — otherwise the maneuver goes direct. Tuning, not fixed here.

**Recompute cadence.** A direct route is recomputed when its target cell changes; a flank route every
`OPCOM_ROUTE_RECOMPUTE_TICKS` ticks (belief drifts under it, so a stale corridor is no longer safe), or
immediately if the chain is exhausted before then. Belief updates each tick, but the route search runs
outside the scoring block and only when a route is actually due, not every tick
([§The loop](#the-loop-against-the-engine)). The chain is
not persisted — it recomputes from the current cell to the target on load.

| Constant | Value |
|---|---|
| `OPCOM_ROUTE_LAMBDA` | flank threat-avoidance weight (tune) |
| `OPCOM_ROUTE_RECOMPUTE_TICKS` | ticks between flank re-routes (start 12–24, ~1–2 min; tune) |

### It is not the area-of-influence field

`fnc_aoi_field_at` is a pointwise, binary read — `+1/-1/0` coverage, no magnitude, no player
knowledge — and it drives town drift and hardpoint siting
([`opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md)). The grid is the
two-sided force magnitude that adds the belief store and only OPCOM's scoring consumes; it touches
neither drift nor siting, and its footprints are small where the AOI reaches are kilometres. Its render
is new work on the dev overlay `fnc_debug_opcom_view`, which today draws only AoI coverage circles.

## Appraisal: expected AP return

Enumerate candidate `[action, target]` pairs, score each as an **expected Army Power return**, pick by
weighted random over the top few. No search, no lookahead — the score is a flat number, and a committed
action's phases are authored, not searched ([§Templates](#templates-the-execution-forms)). The candidate
set is small — the flat action list ([§What the commander spends on](#what-the-commander-spends-on))
against its valid targets — tens of pairs, a full pass every tick.

### Candidate enumeration: gate, then score

Each tick, sweep every action against its valid targets, drop what a cheap test rejects, then
score only the survivors. Tens–low-hundreds of pairs before the gate, fewer after.

| Action | Targets swept |
|---|---|
| Attack | each BLU-held zone |
| Intercept | each belief entry near own ground |
| Rapport | each town not yet turned |
| Recruit | one — the locked prize ([§Value](#value-the-worth-of-the-ground-in-play)) |
| Reinforce | each own holding below its strength cap |
| Scout | drop positions for an available recon unit's footprint |
| Arty | each observed belief point in range of an owned gun |
| Fortify | each own holding below its tier ceiling |
| Build | each own threatened / thin-line cell |
| Bank | one null |

The gate splits by how the action pays ([§Cost](#cost-what-an-action-stakes)):

- **Spend actions** (Recruit, Reinforce, Fortify, Build, Arty) — drop when `Cost > wallet`.
- **Commit actions** (Attack, Intercept, Rapport, Scout) — drop when the roster holds no eligible unit,
  and drop an offensive one whose `P(win)` is below the floor (a doomed assault never scores).

### The score

```
score = archWeight[archetype][actionClass] × P(win) × Value / Cost
```

One number: the expected AP returned per AP spent. `Value` and `Cost` are both Army Power, so `Value /
Cost` is a dimensionless return-on-investment; `P(win)` scales it to the *expected* return; the archetype
weight tilts it by action class. No term normalisation — the units already agree.

| Factor | Is | Reads |
|---|---|---|
| `P(win)` | probability the action succeeds | the force ratio (below) |
| `Value` | AP worth of what the action returns | ground worth, or the locked prize / intel / kills for Recruit / Scout / Arty ([§Value](#value-the-worth-of-the-ground-in-play)) |
| `Cost` | AP the action spends or the force it stakes | a spend action's price, a commit action's force reacquisition ([§Cost](#cost-what-an-action-stakes)) |
| `archWeight` | the archetype's lean on this action class | a per-class table ([§The commander has an archetype](#the-commander-has-an-archetype)) |

### P(win): the force ratio, Lanchester-square

Read the grid's two layers over the target's 3×3 block, `r = Σ friendly / (Σ enemy + 1)`
([§What reads it](#what-reads-it)), and map it:

```
P(win) = r² / (r² + 1)
```

Squared, not linear: combat power compounds with numbers (Lanchester), so parity (`r = 1`) is a coin-flip
(`0.5`), a 2:1 edge (`r = 2`) a strong favourite (`0.8`), and a hopeless ratio floors near 0. The same `r`
also picks the action's **form** through a band; that is *how*, not *whether* — `P(win)` alone scales the
score ([§Action follows the force ratio](#action-follows-the-force-ratio)).

### Value: the worth of the ground in play

A player has no worth of its own — it earns Value only through the ground it threatens, so OPCOM defends
its economy and never chases a lone scout across empty terrain.

| The action | Value |
|---|---|
| takes enemy ground (Attack) | that ground's worth — zone `_points` |
| turns a town (Rapport) | town `civ_town_ap` × the −3 step's progress toward the −10 turn (below) |
| defends own ground (Intercept, Build) | own worth × how threatened it is (`_gridEne` on it) |
| refills a garrison (Reinforce) | own worth × threat × the strength deficit `1 − strength` (below) |
| raises a tier (Fortify) | own worth × threat × the force the next tier adds (below) |
| builds force (Recruit) | per hireable type, the best action that type unlocks (below) |
| buys information (Scout) | Σ over its recon footprint of `cell worth × staleness` (below) |
| attrits force (Arty) | AP-worth of enemy force expected killed — `effForce hit × AP-per-force` (below) |

Enemy ground worth needs `_points` readable at scoring time — currently passed into the capture triggers
only, so stash it in `zone_meta_array` ([§Open questions](#open-questions)).

**Rapport — progress toward the turn.** Rapport delivers a `supply`-flagged unit to a town, stepping its
reputation 3 toward the −10 OPFOR turn threshold; the town only garrisons once it crosses. So a step's Value
is `town worth × how much closer −3 gets it` — a town at −8 turns in one trip and scores near-full worth, a
neutral town about a quarter. OPCOM finishes nearly-turned towns before starting new ones. Passive band
drift already turns a covered town for free, so Rapport earns its keep on towns the drift will not reach
([§Random events](#random-events-what-a-turned-town-does)).

**Reinforce and Fortify — deficit versus ceiling.** Both defend own ground scaled by `own worth × threat`,
differing in the third factor. **Reinforce** refills a garrison's HP toward its current tier, so it scores
the **strength deficit** (`1 − strength`) — a full garrison scores 0, and OPCOM never tops up what is already
full. **Fortify** raises the tier *ceiling*, so it scores the **force the next tier adds** over the current
one (read from the composition table), diminishing as tiers climb — no AP poured into a ceiling that adds
little.

**Recruit — per type, demand-valued.** Recruit is one candidate *per hireable unit type*, each valued by the
best action that type would unlock, so OPCOM hires exactly what it is short of. **Combat / armor**: the
ground it cannot reach for lack of force — scan the Attack candidates that fail the `P(win)` floor, take the
richest, and value one hire at `prize × ΔP(win)`, the win-probability a single added unit buys against that
target; diminishing (the sigmoid flattens past `r ≈ 1`) and self-terminating (once accumulated force clears
the floor the prize becomes a live Attack and the prize drops to the next locked target). **Recon**: the
best Scout Value it would enable. **Supply**: the best Rapport Value it would enable. OPCOM hires the
top-scoring type — massing combat force for an out-of-reach zone, buying eyes when it needs to Scout, a
supply unit when a town is worth turning — and stops when nothing is short.

**Scout — worth at stake × staleness.** Only a recon-flagged unit can Scout, and its footprint is rings
around its drop cell by type — recon team 1 ring, recon car 2, recon helicopter 3. A drop position's Value
is `Σ` over the footprint cells of `cell worth × staleness`, where `cell worth = max(offensive, defensive)`:
offensive is attackable enemy ground worth in the cell, defensive is own ground worth exposed through it. A
wider-range unit covers more cells (higher Value) at a higher reacquisition Cost, so range trades against
unit price on the ROI axis with no extra knob.

**Arty — force killed.** Value is the AP-worth of the enemy force a mission is expected to kill,
`effForce in the blast × AP-per-force`. It targets the exact belief position, not the cell; positional
uncertainty grows with belief staleness, so OPCOM widens saturation (more rounds, more AP) to cover it and
expected kill falls as belief ages — fresh recon makes Arty lethal, stale belief wastes it
([§Indirect-fire hardpoints](#indirect-fire-hardpoints)).

### Cost: what an action stakes

`Cost` is Army Power, but two families stake it differently.

**Spend actions** (Recruit, Reinforce, Fortify, Build, Arty) pay fresh AP from the wallet: `Cost` is the
price — a tier rung, a hardpoint, a hire, a fire mission's rounds × saturation.

**Commit actions** (Attack, Intercept, Rapport, Scout) spend no fresh AP; they stake roster units already
paid for. `Cost` is the **AP to reacquire the force committed** — `Σ effForce × AP-per-force` over the units
in the tasking, so a bigger commit stakes more and must clear a higher bar. `AP-per-force` is one exchange
rate, single-sourced from Recruit's hire price, and it also prices force elsewhere (Arty's kill Value).

**Abandoning defense is part of the cost.** A unit holding threatened own ground is already worth
`own worth × _gridEne` there — the Value a Reinforce would score. Pulling it into an attack forfeits that,
so its commit cost is `reacquisition + defenseAbandoned`: reacquisition AP plus the own-ground worth it was
covering, scaled by the threat rise its removal causes (drop it from `_gridFri`, net threat on nearby own
ground climbs). A unit on quiet ground costs ~reacquisition alone; one on a hot backline costs far more and
stays put unless the prize outweighs losing the ground.

**Force allocation is ROI-optimal.** An Attack is scored at the force size that maximises
`prize × P(win) / Cost` — add units while each one's ΔP(win) still pays for its commit cost, stop when it
does not. Since `P(win)` saturates past `r ≈ 1` this lands near "enough to win plus a small margin", and
the abandonment cost holds the backline without a reserve knob. A Probe inverts the rule — it minimises
stake, not ROI ([§Templates](#templates-the-execution-forms)).

### Action follows the force ratio

*What* form an offensive action takes follows the same `r`, over the target's 3×3 block:

| Ratio `r` | Form (band) |
|---|---|
| ≥ 2 | assault — overwhelming, direct |
| 1 – 2 | flank / encircle — envelop, not a frontal charge |
| 0.5 – 1 | probe (recon-by-fire), or muster and keep buying |
| < 0.5 | hold — do not attack; Fortify or muster instead |

The band selects the **execution template** ([§Templates](#templates-the-execution-forms)) the runner
runs; it does not re-score. `P(win)` (whether) and the band (how) read one `r` and do two jobs. Thresholds
tune in play.

### Weighted random over the top few, not the best

`selectRandomWeighted` over the highest-scoring three, not `argmax` — the mission's existing idiom
(`server/init_zones/fnc_createzone.sqf:129`), weighted by the scores themselves. Zone vehicles are not
picked this way: the tier table names what a zone fields.

Banking (`Bank`) is a candidate, not a policy — a "spend nothing" entry with a low flat score, losing
whenever anything sensible is affordable and winning when everything else has saturated.

## Commitment: intents are sticky

A chosen action becomes an intent record and stays one until it completes, dies, or expires.
Re-scoring next tick fills free capacity. It may **abandon a still-virtual intent** — recall its units to
the roster — but only when the target's ROI has fallen *well below* the commit bar; the hysteresis gap
(`OPCOM_COMMIT_HYSTERESIS`, [§Open questions](#open-questions)) stops a small wobble sending columns
marching back and forth. Once a tasking's units are in contact it is locked ([§There is no retreat](#commitment-intents-are-sticky), below) — the world can shift under a virtual march, never under a firefight.

| Field | Holds |
|---|---|
| type | the action id ([§What the commander spends on](#what-the-commander-spends-on)) |
| target | the objective — a registry index (zone, town) or a cell |
| roles | `[role, unitRef, status]` bindings drawn from the roster: one for a simple tasking, several for a multi-unit template, none for an economic action |
| phase | index into the template's phase list ([§Templates](#templates-the-execution-forms)) |
| expiry | `time` plus the intent's own lifetime |
| state | mustering / ordered / in progress / done |

A released unit is one whose intent has completed; that ownership state is what the reinforcement logic
tests before treating a unit as a valid target.

**One record, every granularity.** An economic spend (Fortify, Build, Bank), a single tasking and a
multi-unit template are the same record — `roles` is empty, one entry, or several. There is no separate
play record ([§Templates](#templates-the-execution-forms)): a simple tasking is the one-role, one-phase
case of a template.

**There is no retreat.** A committed group fights its engagement to a decision: the engine owns a group
in `COMBAT` and will not execute a commanded withdrawal
([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)).
A group that wins drops back to `moving`, resumes its order, and re-virtualises on clearing the ring
([§The virtualisation boundary](#the-virtualisation-boundary)); a group that loses dies. Recovery is
winning, nothing else.

**An assault musters, then launches as one wave.** In state `mustering` an Attack or Intercept intent binds
force across ticks and gathers it at a **safe rally** — a low-threat cell short of the target — until the
full ROI-optimal force ([§Cost](#cost-what-an-action-stakes)) has converged. Only then does it advance, all
together. It does **not** dribble units forward into contact, which no-retreat would turn into defeat in
detail — a player could kill the muster a unit at a time. The gathered force is sized to exceed the believed
player force over the target's 3×3 block on arrival (the grid's two layers read over that block, friendly
known, enemy believed); if the player reinforces the target mid-muster the bar rises and the muster keeps
buying. Mustering is also how a force-short action waits for the units it needs — from the roster, or from
Recruit — rather than committing understrength.

### Unit tasking and status

Each unit carries two orthogonal fields:

- **Tasking** — its standing order: `garrison` (default on spawn — zone-bound reinforcement),
  `guard` (idle hold-anywhere, takes up space), `assault`, `rapport`, `scout`, `move`,
  or a template role. `garrison` and `guard` are the two resting taskings; the rest are active.
- **Status** — how the current tasking is going, read per live group each tick:

| Status | Read |
|---|---|
| `virtual` | intent owns no live group yet — still a cell on a route |
| `moving` | live, no contact — `behaviour` SAFE/AWARE, low `knowsAbout` |
| `engaged` | live and in combat — `behaviour leader _g == "COMBAT"`, or `leader _g knowsAbout <nearest player> > 1.5` (the sighting threshold) |
| `dead` | `count units _g == 0` |

Cheap: a handful of live groups, one `behaviour`/`knowsAbout` read each, alongside the streaming check
that already runs each tick. A virtualised tasking is `virtual` by definition — no read. Coordinated moves and the
reinforcement logic key off both fields.

Numbers and strings only. `time`, not `diag_tickTime`, so an expiry survives a savegame
([`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

### Unit strength

Each tasking unit carries a strength figure, computed and saved the way a zone's is
([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#zone-tiers)) — reuse the zone
helpers (`fnc_zone_strength`, `DUWS_fnc_garrisonStrength`, `DUWS_fnc_garrisonUnlose`), never a parallel
store.

```
fullForce = Σ elementPower                     // the hired composition, fixed
effForce  = Σ elementPower × condition          // current
strength  = effForce / fullForce                // 0..1
```

Condition per element:

| Element | Condition |
|---|---|
| Infantry | alive (1) or dead (0) — unit count falls out of the sum |
| Vehicle | `1 − damage`; crew is never counted (a lost crew refills) |

`effForce` is what the grid deposits ([§The quantity](#the-quantity-force-not-coverage)), so a shot-up
group already weighs less in `r` with no extra logic; `strength` is the normalised figure for display,
heal targets and persistence. Streaming spawns a group to *match* its stored strength (fewer bodies, a
damaged vehicle), and re-virtualising recomputes `effForce` from the live group before it despawns
([§The virtualisation boundary](#the-virtualisation-boundary)).

**`garrison` heals.** A unit in `garrison` regenerates `effForce` toward `fullForce` each tick —
`effForce = min(fullForce, effForce + OPCOM_GARRISON_HEAL_RATE × fullForce)` — mirroring the zone
reinforce path. `guard` does not heal; it only holds ground. The rate is the sole knob (start value open,
[§Open questions](#open-questions)); the per-tick mechanism ships from the start.

A zone's effective strength is its base garrison (the tier composition, which Fortify raises and Reinforce
refills) plus **at most one** `garrison`ed tasking unit, held in a **distinct** slot — so tasking that unit
out subtracts its `effForce` cleanly and Fortify never touches it. The slot caps at one: Recruit targets a
zone whose slot is *free*, so massing force means one recruit per zone across several zones, then pulling
them together at a muster ([§Commitment](#commitment-intents-are-sticky)), not stacking a stack on one zone.

## Movement: a tasking is virtualised until contact

A tasking moves *virtualised*: its position is a **grid cell**, stepped along a route chain
([§Routing](#routing-a-cost-field-over-the-grid)) by a per-type speed model, holding no group handle,
until a player closes to within its streaming ring. Its role binding
([§Commitment](#commitment-intents-are-sticky)) references a cell while virtualised, a live group once it
spawns.
This is the mobile analogue of hardpoint streaming, which wakes and sleeps a fixed emplacement on a
`spawnRadius`/`grace` band
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#streaming-and-garrison)). Movement and streaming
run each loop tick ([§The loop](#the-loop-against-the-engine)).

### One nominal speed per unit type

Model arrival only — which cell the squad is in and when it crosses the streaming ring. One
cross-country speed per type; road versus open ground is unmodelled.

| Unit type | Water | Nominal speed (tune in play) |
|---|---|---|
| Infantry | impassable | ~5 km/h |
| Wheeled | impassable | ~40 km/h |
| Tracked | impassable | ~30 km/h |
| Rotary | passable | ~200 km/h |
| Fixed wing | passable | ~400 km/h |

**Cell-stepped, with a carry.** A tasking holds a cell plus a metre accumulator. Each tick
`acc += speed * dt`; while `acc` covers the next step's length (`OPCOM_GRID_CELL`, or `* sqrt 2`
diagonal), pop the next cell off the route chain and subtract it. A slow infantry crosses one cell over
several passes; a fixed-wing pops many cells in one pass. Position stays a pure cell for streaming, force
deposit and routing; the accumulator is motion bookkeeping only. Water is handled in the route, not per
step — a ground route never contains a water cell ([§Routing](#routing-a-cost-field-over-the-grid)).

Persisted state is the cell, the target and the route mode — all numbers, so a virtualised tasking
serialises with its order ([§Persistence](#persistence)). The accumulator resets to 0 and the chain
recomputes on load.

### The virtualisation boundary

A tasking unvirtualises — spawns as a native A3 group — on either of two triggers: its cell closes to
within **K cells** (Chebyshev, `max(abs(dx), abs(dy))`) of any player's cell, **or** it reaches an opposing
force (an OPFOR assault closing on a BLUFOR-held cell). Inside the ring the group is real, the engine owns
its pathfinding, and the tasking issues its order *best-effort*.

**Streaming is side-symmetric, and the engine resolves combat.** A BLUFOR zone or town garrison is
virtualised and streamed exactly as an OPFOR one — stored as strength and a cell, spawned on contact. An
OPFOR assault that reaches a BLUFOR-held cell unstreams *that garrison too*; both sides go live and the A3
engine fights it out, survivors re-virtualising on clearing ([§Unit strength](#unit-strength)). OPCOM never
dices a combat — `P(win)` is its *scoring* estimate, never a resolver. Off-screen contact (no player near)
still spawns both sides briefly; the per-locality cap bounds it
([§What the commander spends on](#what-the-commander-spends-on)).

**K is per unit type, not one ring** (tune in play) — each type's render range in cells. The streaming
check runs each tick against live player cells, so the margin against a fast player comes from the tick
rate, not a fat ring: even a 200 km/h player crosses ~half a cell (~280 m at a 5 s tick) between ticks and
is caught before contact.

| Unit type | K | ≈ real |
|---|---|---|
| Infantry | 1 | 500 m orthogonal, ~700 m diagonal |
| Wheeled | 2 | ~1–1.4 km |
| Tracked | 2 | ~1–1.4 km |
| Rotary | 5 | ~2.5–3.5 km |
| Fixed wing | 8 | ~4–5.5 km |

**Hysteresis.** A live group stows back to a cell once it passes `K + 1` cells from every player **and holds
no live contact** — one full cell of margin so a group on the edge cannot flicker. A group in a firefight
stays live until it resolves, whether or not a player is near.

The boundary is a square ring in cell space, so a tasking on the diagonal streams in ~1.4x further than
orthogonally — acceptable for spawn-before-contact.

### Spawn posture follows the order

- A **move order** — rapport, scout, a patrol — spawns in `SAFE`/`AWARE` and drives or walks to its
  objective.
- A **combat order** — Attack or Intercept — spawns in `AWARE` with a Seek & Destroy waypoint on the target.

Set the posture at spawn, not a tick later.

## Templates: the execution forms

A template is a unit-dispatching action's execution form — named roles and a phase sequence the runner
steps off unit status. It is **not** a separately scored subsystem: the action is scored
([§Appraisal](#appraisal-expected-ap-return)), the template is *how* it runs. A simple tasking is the
one-role, one-phase template; a coordinated maneuver is a many-role one. One runner executes both, so
adding a coordinated behaviour is adding a bigger template, not a new subsystem — there is no planner.

### The runner

One generic stepper, each tick, over every live intent that holds roles:

1. Refresh each bound unit's status ([§Unit tasking and status](#unit-tasking-and-status)).
2. A required role `dead` or lost → **abort**: release surviving units to the roster (an engaged survivor fights its contact to a decision, a clear one re-virtualises), no AP refund.
3. Otherwise advance `phase` when the current phase's transition predicate holds — predicates read child
   status and geometry, nothing else.
4. Last phase complete → done, release the units.

The runner sequences phases only; bound units move by the route and streaming machinery
([§Routing](#routing-a-cost-field-over-the-grid),
[§Movement](#movement-a-tasking-is-virtualised-until-contact)), it does not path.

### The roster

The free-unit pool: every uncommitted unit — those `garrison`ed on a zone or on a `guard` hold. Binding a
unit to a template pulls it from the pool; drawing a `garrison`ed one strips that zone's reinforcement
([§Unit strength](#unit-strength)). A released unit returns to the pool. One unit, one owner.

### Filling roles

- A template applies only when its band fits ([§Action follows the force ratio](#action-follows-the-force-ratio)),
  enough roles are fillable from the roster, and the geometry holds.
- Committing binds roles from the roster. Short a role, the intent commits in `mustering` and waits —
  Recruit or pull the missing unit — before its first phase ([§Commitment](#commitment-intents-are-sticky)).

### The templates

The band picks one for an Attack or Intercept; the rest are the fixed form of their action.

| Template | Picked when | Roles | Phases (→ on transition) |
|---|---|---|---|
| `assault` | band ≥ 2 | `attacker` ×1 | approach (direct route) → S&D → resolve |
| `flank` | band 1–2, ≥2 mobile, a reachable flank cell | `fix` ×1, `maneuver` ×1+ | form (fix → frontal direct; maneuver → flank cell, λ route) → *(fix `engaged`)* assault (maneuver S&D from the flank) → resolve |
| `encircle` | band 1–2, target pocketed (few escape cells), ≥3 mobile | `blockers` ×N (one per escape corridor), `crushers` ×1–2 | deploy (blockers → corridor cells) → *(blockers in position)* seal → crush (crushers assault inward) → resolve |
| `probe` | band 0.5–1 | `prober` ×1 (cheapest expendable; never armour, air or recon) | approach → make contact → resolve (survives ⇒ belief was soft, escalate; dies fast ⇒ belief confirmed, mass or re-target) |
| `rapport` | a `supply`-flagged unit, a town in reach | `courier` ×1 | move (to the town) → deliver (step rep 3 toward −10) → resolve |
| `scout` | a `recon`-flagged unit, a stale valuable area | `scout` ×1 | move (to the drop position) → reveal (refresh belief over the footprint rings) → resolve |
| `arty` | an observed belief point in range of an owned gun off cooldown, not the HQ circle | owned `guns` ×1–3 (resident hardpoints, not roster — 0 roster taskings), `spotter` ×0–1 | mark (spotter or OP holds observation) → salvo (rounds × saturation on the belief point) → assess (force dropped? re-fire : done) |

- **Escape corridors** (`encircle`): the target cell's neighbours whose enemy-influence gradient points
  outward toward BLU-held ground — the routes out. Blockers occupy them; crushers collapse inward once
  sealed.
- **Saturation** (`arty`): concentrates several guns on the belief point rather than one gun per target,
  over the existing fire-mission machinery and caps ([§Indirect-fire hardpoints](#indirect-fire-hardpoints),
  [§Observation is the trigger](#observation-is-the-trigger)).
- **`probe` is disposable recon-by-fire.** No-retreat forbids poke-and-withdraw, so a probe instead
  converts uncertain belief into *observed defender strength by drawing fire*, reaching what recon cannot
  (a dug-in town garrison). Its force is the cheapest the roster holds and never a high-AP asset (armour,
  air) or a recon unit; the element is expected to be lost and the intel de-risks a bigger commit. Unit
  selection minimises stake — the inverse of the ROI-optimal sizing every other commit uses
  ([§Cost](#cost-what-an-action-stakes)).

| Constant | Value |
|---|---|
| `OPCOM_TEMPLATE_TIMEOUT` | per-template deadline before abort (tune) |

## The loop against the engine

One thread, one cadence, not one thread per action.

| Property | Value |
|---|---|
| Tick | every `OPCOM_TICK_PERIOD` (5 s). Increment the tick counter, then: refresh belief, rebuild the grid, advance in-flight taskings (accumulator + cell pop) and live templates ([§Templates](#templates-the-execution-forms)), refresh live-group status ([§Unit tasking and status](#unit-tasking-and-status)), run the streaming check against live player cells ([§Movement](#movement-a-tasking-is-virtualised-until-contact)), score, commit at most one thing, recompute the routes due for it |
| Scoring pass | inside `isNil { ... }` — unscheduled, runs uninterrupted. `server/init_zones/fnc_moreUrban_locations.sqf:126-138` is the worked example, bounded by a wall-clock deadline. The route search runs outside it |
| Clock | the tick counter `DUWS_opcom_tick` — intent expiries and belief age count in ticks, which persist with the mission namespace where `time` / `diag_tickTime` do not |
| Orders | server-local groups only — waypoints are silently ignored unless the group is local to the issuing machine |
| State | numbers, strings, arrays of those — no group or object handles near the mission namespace |

No `sleep` inside the `isNil` block — unscheduled code cannot suspend. Constants are plain server globals:
the opcom files load by compile-path and read them at runtime, out of a preprocessor macro's reach.

**One cadence; there is no separate reactive fast path.** A fresh sighting is acted on at the next tick,
like everything else, at most `OPCOM_TICK_PERIOD` away. It needs no out-of-band path: **local defense is
emergent** — a player hitting an OPFOR holding streams its garrison in before contact, and the spawned
group fights at once with no OPCOM decision. Intercept is only the *dispatch of a mobile reserve* to
threatened ground with no adequate local garrison, and that reserve must travel regardless, so a one-tick
decision latency is dwarfed by transit. One scoring path, no re-entrancy.

Keeping the tick fast is deliberate, not a cost: a finer tick reads as a more reactive commander, and the
per-tick work scales with it rather than breaking — movement steps shorter (step = nominal speed ×
`OPCOM_TICK_PERIOD`), and the action economy spends in finer grain (balanced on per-action cost and the AP
faucet, gated by affordability, with intent minimum lifetimes holding a commitment steady across the
faster re-scoring — [§Commitment](#commitment-intents-are-sticky)).

## What the commander spends on

> **Built today: the town-garrison ladder only** — the AP tier rungs and the per-tier garrison each
> town fields ([§Town garrisons](#town-garrisons-i-through-iv)). A standalone fortification director also
> shipped but is now disabled ([§What the commander builds](#what-the-commander-builds)). The tasking
> menu and the appraisal that arbitrates the actions are not yet built.

The actions Army Power buys, the archetype that weights the split, and the garrison ladders on both
sides. The director here, the hardpoint director ([§What the commander builds](#what-the-commander-builds)),
and the turned-town behaviour are one actor sharing `WARCOM_opfor_ap`: every action competes in the one
appraisal ([§Appraisal](#appraisal-expected-ap-return)) — no sink runs on its own clock, and none spends
`WARCOM_opfor_ap` unarbitrated. The wallet and its faucets are the economy's
([`economy_second_pass.md`](../economy_second_pass.md#army-power)).

Director spends call `fnc_ap_adjust` directly, as `["OPF", -_cost, _reason] call fnc_ap_adjust`. The
director is server-side and single, so there is no writer to race.

### Actions, sinks and taskings

Three levels, not one:

- **Action** — what OPCOM commits AP to; the unit the appraisal scores and Commitment holds. The flat
  list below.
- **Sink** — how an action is paid and run: a tier purchase, a strength purchase, a hardpoint build, a
  tasking-spawn, or a bought fire mission on an owned gun. A property of the action, not a level OPCOM
  decides at.
- **Tasking** — an order handed to one unit ([§Unit tasking and status](#unit-tasking-and-status)). An
  action emits none (economic), one (a simple tasking), or several (a template,
  [§Templates](#templates-the-execution-forms)).

| Action | Class | Target | Sink | Taskings |
|---|---|---|---|---|
| Attack | offensive | a BLU-held zone | tasking-spawn | 1–N (band picks the template) |
| Intercept (QRF) | defensive | a sighted player near own ground | tasking-spawn | 1–N (band picks the template) |
| Rapport | offensive | a town in reach (needs a `supply` unit) | tasking-spawn | 1 (`supply` courier) |
| Recruit | buildup | the highest-value unmet unit need; spawns `garrison` on a free-slot OPFOR zone | tasking-spawn | 1 (spawned `garrison`) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 |
| Scout | recon | a `recon` unit's drop position covering stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed belief point in range of an owned gun | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 |
| Build | defensive | an own threatened cell | hardpoint build | 0 |
| Bank | — | — | none | 0 |

Value and Cost are [§Appraisal](#appraisal-expected-ap-return); the band and templates are
[§Templates](#templates-the-execution-forms).

**Recruit fills the roster; every other unit-dispatching action drains it.** Recruit is the RTS "hire a
unit": it spawns a group `garrison`ed on a free-slot OPFOR zone (one tasking unit per zone,
[§Unit strength](#unit-strength)). OPCOM then draws that unit for an Attack, Intercept, Rapport or Scout,
which strips the zone. So OPCOM must build up before it can strike, and a lost unit is lost standing strength.

**Recruit chooses the type by demand.** It is scored once per hireable type — combat, armor, `recon`,
`supply` — each against the best action that type unlocks ([§Value](#value-the-worth-of-the-ground-in-play)),
so OPCOM hires eyes when it needs to Scout, a courier when a town is worth turning, and combat force to mass
for an out-of-reach zone. Unit capability flags (`recon` enables Scout, `supply` enables Rapport) ride on
the token composition (below); a plain combat unit carries neither.

Three notes:

- **Random events are not an action.** IEDs, ambushes and sabotage out of a low-reputation town fire on
  their own, rolled against reputation, and cost the commander nothing
  ([§Random events](#random-events-what-a-turned-town-does)).
- **Nothing absorbs a surplus.** Every action is rate-limited; a commander that out-earns them banks the
  difference ([§Open questions](#open-questions)).
- **Scout and Recruit earn no AP directly, but both carry an AP Value** — Recruit's is the locked prize it
  unlocks × the ΔP(win) a hire buys, Scout's is the worth-at-stake × staleness its footprint reveals
  ([§Value](#value-the-worth-of-the-ground-in-play)). Scout is the weak sensor: cheap, recon-flagged units
  only, `reveal` against EAST is the mechanism.

Units spawn only from OPFOR-held ground — a held zone today, the planned OPFOR FOB hardpoint once it
exists — never on demand beside the player. Taking the zone cuts what it can raise.

**The cap is on live groups per locality, not on planning.** Virtualised taskings are cheap and uncapped —
OPCOM may hold many in flight. What binds is spawned AI: the sim only ever holds live groups where a player
or an active contact is, so `OPCOM_MAX_TASKINGS` (start 10) is a budget **per active locality** — a player's
proximity bubble or an off-screen contact point — not one global number. A big offensive on one side of the
map then cannot starve a defender's spawn on the other, and in co-op each player's locality keeps its own
budget ([§The virtualisation boundary](#the-virtualisation-boundary)).

**A unit's force is a token composition.** Drawn from the same `posture:token` vocabulary the garrisons
use ([§What the commander builds](#what-the-commander-builds)) — an array of tokens like `team` or `car`,
resolved by `DUWS_fnc_tokenClass` against the shared roster. Recruit chooses from a menu of compositions;
the exact rows are unset, tuned in one place, never hardcoded at a spawn site.

**Capability flags ride on the composition.** A composition may carry a `recon` or `supply` flag — `recon`
makes the unit eligible to Scout (its range rings by type, [§Value](#value-the-worth-of-the-ground-in-play)),
`supply` makes it eligible to Rapport. A plain combat or armor composition carries neither and can only
Attack, Intercept or hold. Recruit's per-type scoring is a score per flagged composition, so specialist
units enter the roster only when the action they enable is worth their hire.

### The commander has an archetype

One archetype rolled per campaign, deciding how the appraisal weights the action classes
([§Appraisal](#appraisal-expected-ap-return)) — the `archWeight[archetype][actionClass]` factor in the
score.

| Archetype | Weights toward |
|---|---|
| Defensive | Fortify, Reinforce, Build, Recruit, Intercept; hardens and defends what it holds |
| Balanced | No strong lean — the baseline the others are tuned against |
| Aggressive | Attack, Rapport; projects force, leaves ground thin |

A single authored table of per-class weights. Further leans — indirect fire, armour — become entries in
it.

- **Weights, not switches.** An archetype multiplies an action class's score; it never removes an action.
- **It cannot override the ladder.** An Aggressive commander with no armour tier reached fields no
  armour. Archetype decides what the enemy buys, never what it may buy.
- **It is not difficulty.** `opfor_ai_skill` sets how well the enemy shoots.

Rolled once at WARCOM init, never re-rolled — campaign state, in the persistence snapshot.

### Town garrisons: I through IV

Towns gain purchasable garrisons on both sides, benchmarked against a zone garrison (fortified groups
with a squad leader each, occupied buildings, nearby guard towers). Zones carry a tier of their own,
rolled at generation ([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#zone-tiers)).
Towns and zones draw from one token vocabulary but keep separate composition sets.

Both sinks reach both kinds of ground — the commander upgrades and reinforces zones as it does towns.
A retaken zone is floored to `0.3` so there is something to buy back
([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#zone-tiers)).

Extension machinery: a zone's tier is stored per zone, the composition table is indexed by it, and
zone and town strength share one attrition ledger — `fnc_zone_strength`
(`server/init_zones/fnc_zone_state_init.sqf:84`) reads it through `DUWS_fnc_garrisonStrength`, the
store `fnc_town_garrison_reinforce` (`server/civilian/fnc_civ_state_init.sqf:183`) writes through
`DUWS_fnc_garrisonUnlose`. Missing: a zone strength setter — a pair of wrappers, one applying the
reinforcement step to a zone key, one writing a zone tier with a clamp.

Open on the zone side:

- **Whether a zone costs a town's price or more** — same price makes a zone the better buy at every
  tier.
- **Whether zone tiers are capped by the roll** — a zone rolled at I bought to IV makes generation
  weighting a starting position; capping keeps it a character but leaves a soft zone permanently soft.

No purchase refusal on the zone side. A town's `REGROUPING` hold blocks both sinks; a zone has no such
state — a beaten zone garrison means the zone changed hands, and captured ground is not a spend
target.

The OPFOR side is built: tiers 0 to IV in `DUWS_townSpawnTiers`, per-town tier in
`DUWS_townGarrisonTier`, written through `fnc_town_garrison_setTier`
([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv)).

- **Reputation decides whether a town garrisons; AP decides how hard.** Crossing `-10` writes tier I.
- **Clearing a town drops the tier to I, not 0, with no refund.** The director must spend again to
  restore it, and cannot for the three hours the town spends regrouping
  ([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#what-clearing-a-garrison-actually-buys)).
- **A cleared town is pinned to the `0.3` strength floor for the rest of the campaign.**
- **Tier IV is more units, not fortifications** — it reaches the zone benchmark by occupying
  buildings.

| Tier | Adds | Reached by | Starting price |
|---|---|---|---|
| I | Patrol plus one team | reputation `<= -10` | — |
| II | Second team, light vehicle | purchase | 25 |
| III | Armour | purchase | 40 |
| IV | Building-occupying units, on the zone pattern | purchase | 60 |

Tier I is unpriced — the band grants it. To garrison a town, turn it through rapport.

### BLUFOR garrisons accumulate; they are not inherited

The BLUFOR band (`>= 10`) has no garrison today; buying tier I at a held town creates one rather than
upgrades one.

Captured ground carries no tier and no strength — no inherited garrison, no destroyed state. What
OPFOR left is OPFOR's, floored at `0.3`, re-read only when they retake it
([`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#blufor-inherits-nothing)).

Buying tier I creates a garrison at **zero strength**; each reinforcement adds **30 %** — four to
reach full from nothing, three from the `0.3` floor. A tenth-multiple: both strength stores quantise
to tenths.

Open before build:

- **Reinforcement is a second sink, not a second purchase.** Tier says what the garrison *would*
  field, strength how much stands. Whether the two draw on the same pool at the same rate is open.
- **Nothing here needs the OPFOR holds** (`Mobilising`, `Regrouping`) — a BLUFOR garrison never
  arrives on ground it already owns. The presence latch is still wanted, since a BLUFOR town garrison
  streams.

## What the commander builds

The escalation ladder and indirect-fire assets, once the commander is spending on them.

**Built but disabled**: a standalone fortification director (`fnc_WARCOM_opf_hardpoints`) spent OPFOR AP
on three flat-priced build actions — raise a radio tower, top a zone back toward its stored ring cap,
fortify the band, priced `OPCOM_AP_TOWER`/`OPCOM_AP_BAND`/`OPCOM_AP_TOPUP`
([`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting)) — on its
own clock in a fixed priority order, with no appraisal. Its spawn is cut (the file and compile stay), to
be re-driven through the appraisal so build competes with tasking and garrison for the wallet. Nothing
scales garrison size to `WARCOM_opfor_ap`
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#streaming-and-garrison)). Hardpoints otherwise
generate at scenario init only.

**The director builds to need.** It sites a build by reading the influence grid
([§The influence grid](#the-influence-grid-one-spatial-substrate)): a believed BLUFOR build-up — a
cell whose belief-store magnitude has climbed — pulls fortification toward the pressure; a gap in its
own line — a front-contour stretch thin on friendly influence — pulls it toward the hole. This is the
Build action scored like any other; its *target* is the threatened cell, its Value is `own worth × threat`
there ([§Value](#value-the-worth-of-the-ground-in-play)).

**The type is tier-gated and archetype-weighted.** Given the site, the hardpoint type comes from the
earned-AP ladder below (OP/MG → AT → AA/mortar → battery), picked by a weight the archetype tilts — an
indirect-fire lean fields more mortars and batteries, an armour-heavy defence more AT — the same
`archWeight` mechanism the action classes use ([§The commander has an archetype](#the-commander-has-an-archetype)).
The grid is magnitude-only, so the pick is not a typed counter (AT under specifically-armour) until belief
carries threat category ([§Open questions](#open-questions)).

### The director and the escalation ladder

Construction is an OPFOR Army Power sink — an emplacement competes with town garrisons and tasking
orders. No build refund: clearing pays the player CP only (`fnc_mission_reward.sqf:35`,
`fnc_captured.sqf:39`) and returns the enemy nothing.

`WARCOM_opfor_ap` decides how hard a hardpoint is, not just whether the director can afford one. The
deleted patrol/assault spawners stepped up at 10/40/65/100/136 AP
([§Rejected](#rejected-the-opfor-spawners-this-replaces)); these tiers are proposed, not matched to a
surviving precedent:

| Highest OPFOR AP reached | Garrison, any hardpoint | Types the *director* may build |
|---|---|---|
| < 40 | 2-3 infantry | OP, MG |
| 40-99 | 3-4 infantry, one armed car in support | + AT |
| 100-135 | 4-5 infantry, an APC parked on the position | + AA, mortar pit (max 2 alive) |
| 136+ | 4-5 infantry, MBT if `HeavyArmor == 1`, else APC | + artillery battery (max 1 alive) |

**The unlock column binds the director only.** Everything placed at generation — every zone hardpoint
and the seed subset — rolls from the full type list whatever OPFOR AP is at campaign start.

**The garrison column applies to all of them** — composition is read at spawn, not at placement. An AA
position generated in hour one is a real gun with a thin crew; the same position revisited in hour
five has armour parked next to it.

**The ladder is a composition table.** OPFOR garrisons are token compositions — a row of
`posture:token` entries (the tier compositions in `DUWS_zoneSpawnTiers`,
`server/init_zones/fnc_zone_spawn_sizes.sqf:32`) resolved by `DUWS_fnc_tokenClass` (`:91`) against the
shared vocabulary — the team roster in `shared/functions/fnc_spawn_vocab.sqf`, the vehicle rows
`DUWS_spawnVehicles`/`DUWS_spawnVehiclesBlu` (`:183`,`:208`) — scaled, attrition-thinned and raised by
`DUWS_fnc_raiseGarrison` (`:144`). Put the hardpoint tier in that file as its own small table beside
the zone one: the vehicle rows name faction roles not classnames, the row's `setting` column answers
`HeavyArmor`, and a fenced table is editable through the composition TUI
([`info/composition_tooling.md`](../../info/architecture/composition_tooling.md)).

**Both columns key off the highest AP the enemy has reached, never its current balance** — a vehicle
token is gated on `WARCOM_opfor_ap_earned`, the earned high-water counter, not the spendable wallet
(`fnc_zone_spawn_sizes.sqf:107-108`). The hardpoint tier reads the same counter.

| Knob | Value |
|---|---|
| Seed subset | 2-3 at WARCOM init, any type |
| Build tick | one candidate every 20-30 min |
| Build gate | OPFOR AP above 10 |
| Build costs | 8-25 AP by type — cheapest for an OP or MG nest, dearest for the battery |
| Live cap | none — live AI is bounded by player proximity ([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#streaming-and-garrison)) |
| Clear pays | CP only (`fnc_mission_reward.sqf:35`, `fnc_captured.sqf:39`) |

## Indirect-fire hardpoints

Persistent enemy assets that act on the campaign. Two tiers sharing one fire-mission implementation.
None of the fire missions ships today — the mortar and artillery cores exist as clearable emplacements
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#hardpoint-types)) but run no missions.

A zone's own mortar is separate and stays as it is: several zone prefabs site a tube that
`fnc_static_resolve` turns into the holding faction's mortar, crewed by the zone's manning pass, firing
on the engine's judgement, not counted against the caps below.

`doArtilleryFire` must be issued from the machine where the gun is local; both are server-spawned, so
the server issues it — the same locality rule that broke `fnc_helolift`
([`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)).

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static mortar, `opfor_TURRET_MORTAR` | self-propelled gun, `opfor_ARTY_X` |
| Unlocks at | 100 AP | 136 AP |
| Reach | whatever the piece has | whatever the piece has |
| Cooldown | 4-8 rounds, then 25-40 min | 6-10 rounds, then 40-60 min |
| Scatter | tighter | wider |

Reach is the gun's — `inRangeOfArtillery` decides what a piece can touch. The battery is a vehicle, so
pin it: `disableAI "PATH"` on the crew plus `allowFleeing 0`. Killing the crew leaves an intact gun
the player can take, and the unmanned clause counts that as cleared
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#clearance)); the recycle station pays for it
(`fnc_activateBaseRecycleStation.sqf`, an ownership-free faucet in
[`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#campaign-loop)).

Applies to both:

| Property | Rule |
|---|---|
| Target set | BLU-held zone centres, FOB positions, players in the open, each only while observed. **Never** aimed inside the 100 m HQ circle |
| Range gate | `_gun inRangeOfArtillery [[_pos], _mag]`, and nothing else |
| Willingness | the Arty appraisal decides, not an autonomous roll ([§Chance to fire](#chance-to-fire)) |
| Accuracy | deliberate scatter, scaled by range and observation quality ([§Scatter](#scatter)) |
| Ammo | paid in AP per mission, not a finite physical store — the wallet is the limiter |
| Telegraph | Allseer radio line plus a temporary marker ~20 s before impact |

**HQ exclusion.** No fire mission may be *aimed* inside a 100 m radius around `PosOfBLUHQ`. Rounds may
still land there from a barrage aimed at a player 200 m out — the exclusion is on the aim point only.
Define the constant once; both the target filter and the pre-fire re-check read it.

### Observation is the trigger

Nothing is shelled that the enemy has not seen. That single rule replaces every range cap: the
spotter's position decides what gets hit.

| Target | Observed when |
|---|---|
| Player or player-driven vehicle | `east knowsAbout _unit` above roughly `1.5` — side-wide, so a patrol that saw the squad counts and a corpse does not |
| BLU-held zone or FOB | an OP hardpoint covers it, or an OPFOR element has been within ~500 m in the last 15 min |
| Anything inside the 100 m HQ circle | never aimed at, whatever the enemy knows |

OPs are the artillery's eyes; killing them blinds guns. The `1.5` threshold is shared with the
sighting sweep.

The target grid is **latched when the mission is ordered** — a mission stores `[x,y,0]` copied at
order time, never an object reference (which would follow a killed player through a respawn, fast
travel, MHQ respawn or taxi into the HQ circle). Belt and braces: the fire mission re-checks its
latched grid against the HQ circle immediately before firing and drops the mission if it falls inside.

Guarantees: no fire within 300 m of the gun itself, no player-directed mission before the first zone
is captured, plus the per-gun cooldown.

### Scatter

`doArtilleryFire` converges after ranging rounds, so offset rounds from the aim point by a deliberate
radius.

| Term | Effect on the radius |
|---|---|
| Base | mortar pit tighter than battery |
| Range to target | grows with distance |
| Observation quality | shrinks with `knowsAbout`, or with an OP holding direct line of sight |

Starting values (tune in play): 50 m base mortar, 100 m battery, +25 m per km of range, −30 m with
direct observation.

### Chance to fire

A fire mission is the **Arty action**, scored and committed like any other
([§Appraisal](#appraisal-expected-ap-return)): OPCOM buys it with AP, `Cost` scaling with the rounds and
saturation it chooses, and it fires only when that action wins its phase — not on an autonomous schedule.
The owned gun off cooldown and in range is the availability *gate*, nothing more; the appraisal decides
whether and how hard to fire. The cooldown starts when a mission fires; the telegraph (radio line + marker)
is required.

**AP is the ammunition.** Because each mission is paid in AP, there is no separate finite-ammo store to
rearm — the wallet is the limiter and the rearm problem dissolves. The zone's own mortar (above) is the
exception: it fires autonomously on the engine's judgement and is not an OPCOM action.

**Fallback if AI static-mortar fire proves unreliable:** spawn the shells directly, as the player's
own artillery support does (`client/supports/fnc_arty.sqf` creates rounds at 800 m altitude with
downward velocity). Player-facing behaviour is identical; the gun becomes scenery. Try the real gun
first ([§Open questions](#open-questions)).

### The indirect-fire types are capped campaign-wide

**One artillery battery and two mortar pits alive at once, across the whole map.** The cap spans both
flavours — a zone that rolls a mortar pit consumes one of the two. Clearing one frees its slot. Not
enforced today ([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#hardpoint-types)); lands with the
fire missions. These are the only hardpoints with permanent crews — three guns is ~six units that
never despawn.

**If AA is ever made resident, it needs its own cap.** The shipped AA streams like any other type,
waking early on a 5,000 m air ring
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#streaming-and-garrison)); pinning it resident
would add a fourth permanent-crew type.

## Rejected: the OPFOR spawners this replaces

WARCOM's three OPFOR threads — roaming patrols, attack waves, random air — are deleted. Three
behaviours in them are worth rebuilding as commander decisions:

- **Target selection.** The assault waypoint helper sorted BLUFOR zones by distance from the group and
  queued a MOVE at each. The old fallback to `WARCOM_blu_hq_pos` when the player held no zones does not
  carry — a rebuilt target selection reaches HQ only through belief.
- **Dismounts.** Above AP 100 both spawners built a second `opfor_INFTEAM_X` and `joinSilent`ed it
  into the vehicle group. Keep as a composition the commander buys.
- **The ammo truck.** A 45-90 min timer ran `opfor_AMMO_TRUCK_X` along the patrol route and announced
  it over Allseer. Garrison restoration is now the Reinforce action
  ([§Actions, sinks and taskings](#actions-sinks-and-taskings)), an economic top-up — the physical truck,
  and the interdiction target it offered, are not carried ([§Open questions](#open-questions)).

The director must not reproduce their shape: routes closed with a `CYCLE` and never despawned, cadence
was unconditional, AP was read but never spent (a one-way ratchet), and they sited spawns >1500 m from
every player so contact only happened when the player drove into them.

## Random events: what a turned town does

A turned town — reputation `<= -10`, inside the OPFOR band — acts against the player on its own: IEDs
on approach roads, ambushes on passing patrols, sabotage against nearby FOBs. Free, rolled off
reputation, planned outside the town's presence trigger so it can mine a road ahead of the player.

## Persistence

The campaign snapshot ([`campaign_persistence_plan.md`](../campaign_persistence_plan.md)) is planned, not
shipped — persistence today is the engine's `saveGame`. Live squads, spawned garrisons and in-flight
fire missions are never saved; they regenerate on player approach.

| State | Kind | Contract |
|---|---|---|
| Archetype | input | The one string rolled at OPCOM init. Restore feeds it back before the loop runs, never re-rolls ([§The commander has an archetype](#the-commander-has-an-archetype)) |
| Standing units & orders | outcome | One row per unit — its tasking, target, current cell, `strength` ([§Unit strength](#unit-strength)), and a moving one's route mode. Persisted as data, never a live squad: restore resumes each unit at its cell (accumulator 0, chain recomputed [§Routing](#routing-a-cost-field-over-the-grid)) at its saved strength, streaming to a live group on player approach. A `garrison` unit restores onto its zone's reinforcement store |
| Tiers | outcome | `WARCOM_opfor_tier` and its earned counter, owned by [`economy_second_pass.md`](../economy_second_pass.md#the-ratchet-is-otherwise-structural-and-only-in-half-the-read-sites); the archetype rides beside them |

Every persisted field is a number, a string, or an array of those. Time-based fields store on `time`
and are written as remaining durations, never absolute stamps
([`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

Whether the belief store persists is open ([§Open questions](#open-questions)); it is shaped to
serialise, so a restored campaign that omits the key rebuilds belief from its first sensor pass. Belief
ages in ticks ([§Decay](#decay)), so the tick counter persists with the store when it does —
omit both and a restore starts the counter at 0 against freshly stamped belief, no stale ages. The
snapshot is a name-keyed hashmap, so adding the key later shifts nothing an older save's readers see.

## Naming: OPCOM sits inside WARCOM

OPCOM (Opposing Commander) is a component of WARCOM, not a replacement. Prefixes split by ownership;
nothing is mass-renamed, so there is no naming-driven save break.

- **Shared war-economy state stays `WARCOM_`** — `WARCOM_opfor_ap`, `WARCOM_opfor_tier`, its earned
  counter, `WARCOM_zones_controled_by_*`.
- **OPCOM's own state takes `OPCOM_`** — the build-cost constants
  `OPCOM_AP_TOWER`/`OPCOM_AP_BAND`/`OPCOM_AP_TOPUP` already do (`server/server_var_init.sqf:608-610`);
  new intents and archetype follow.
- **The belief store keeps the `DUWS_` prefix with an `opcom_` owner tag** (`DUWS_opcom_belief_*`),
  per the no-namespace convention ([§Shape](#shape)).

## Build order

Each phase is independently playable; the ordering is forced by what the next phase reads.

| Phase | Contains | Reads |
|---|---|---|
| **Belief** | The four arrays, the sighting sweep, town and flip sensors, decay, the influence grid stamped from belief and holdings, the land mask + connectivity, a debug readout | Nothing prior — the artillery observation gate and the intel patrol both consume the belief store; the grid adds its render to `fnc_debug_opcom_view` (AoI circles only today) |
| **The loop** | One thread, one cadence (the tick), the AP-return score and the force-ratio bands, the economic actions (Fortify, Build) and Bank, flat archetype weights | Belief + grid |
| **Intents** | The record (roles + phase), minimum lifetimes, release on completion or death | The loop; lands with the first tasking-spawn actions |
| **Movement** | Virtualised taskings — cell-stepping with the accumulator, cost-field routing (direct/flank λ), cell streaming (Chebyshev K + hysteresis), the tasking/status reads and unit strength | Grid + Intents |
| **Archetype** | The per-class weight sets from [§The commander has an archetype](#the-commander-has-an-archetype) | The loop it modifies |
| **Templates & Recruit** | Recruit and the roster/force-pool, `garrison`/`guard`, mustering to fill roles, the generic runner, the templates (assault / flank / encircle / probe / arty) | Movement, unit strength, the grid, and the indirect-fire missions (`arty`) — lands last |
| **Random events** | The rebuilt hostile-conversion and IED/ambush/sabotage behaviours | The belief store and the OPFOR-band definition the loop establishes |

## Implementation

Build in the [§Build order](#build-order) sequence, each phase shipped runnable and verifiable before the
next. Each phase's implementation spec is its own doc, picked up when the phase is; do not pre-build the
later phases, since the tuning constants and the engine-contact behaviours (streaming, `doArtilleryFire`,
virtual combat) only settle by running the core. The rest of this plan is the design spec those phase
docs draw on.

- Phase 1 — belief, grid, debug overlay: [`phase_1_belief_and_grid.md`](phase_1_belief_and_grid.md)

## Open questions

- **Action-economy granularity against the tick.** The loop is one `OPCOM_TICK_PERIOD` (5 s) tick that
  scores and commits at most one action; the per-action AP costs, the faucet rate, and the intent minimum
  lifetimes that hold a commitment steady across that fast re-scoring all tune in play in Phase 2. The tick
  itself is settled — one cadence, no separate action cooldown clocks ([§The loop](#the-loop-against-the-engine)).
- **Typed belief for counter-building.** The grid is force magnitude only, so Build cannot site a typed
  counter — AT specifically under armour, AA under air. Extending belief to carry a threat category would
  enable it ([§What the commander builds](#what-the-commander-builds)).
- **Whether the belief store should persist** ([§Persistence](#persistence)).
- **What a co-op session does to the sighting sweep.** One call per BLUFOR group, the belief array grows one
  entry per group (players sharing a group are one row, and each human is worth `OPCOM_PLAYER_WORTH`). The
  merge is resolved by [the influence grid](#the-influence-grid-one-spatial-substrate): its enemy layer sums
  every entry in a cell, so the force ratio reads force-at-a-place whether four players or one stand there.
- **Whether the player can perceive that the enemy is acting on stale information**, and whether that
  is worth surfacing. The intel system is the obvious route.
- **Whether an AI gunner in a static mortar or a self-propelled gun reliably executes
  `doArtilleryFire`.** Nothing in the mission has ever issued it — `doArtilleryFire`,
  `commandArtilleryFire` and `inRangeOfArtillery` appear nowhere in the tree. Verify with a throwaway
  console test before writing the indirect-fire missions; if no, the shell-spawn fallback
  (`client/supports/fnc_arty.sqf`) becomes the implementation.
- **Whether the player can learn the commander's archetype, and how** — the intel system
  ([`info/intel_system.md`](../../info/gameplay/intel_system.md)), or observed behaviour.
- **What the commander does with a surplus.** Absorbers: Recruit (only while a locked prize exists — its
  Value is demand-driven, [§Value](#value-the-worth-of-the-ground-in-play)), reinforcing a garrison rather
  than upgrading it, and mustering — an assault that keeps buying force while it waits to clear its commit
  bar ([§Commitment](#commitment-intents-are-sticky)). With no prize and nothing to defend, Bank wins. Town
  events cannot absorb — they are free and rep-driven.
- **The `garrison` heal rate** `OPCOM_GARRISON_HEAL_RATE` — the per-tick fraction restored. The mechanism
  ships; only the value tunes ([§Unit strength](#unit-strength)).
- **The commit hysteresis gap** `OPCOM_COMMIT_HYSTERESIS` — how far below the commit bar a still-virtual
  intent's ROI must fall before it is abandoned. Wide enough to kill flapping, narrow enough to still drop a
  dead prize ([§Commitment](#commitment-intents-are-sticky)).
- **The `AP-per-force` exchange rate** — single-sourced from Recruit's hire price, it prices commit `Cost`
  and Arty's kill Value; the value tunes ([§Cost](#cost-what-an-action-stakes)).
- **The per-locality live-group budget** — the value of `OPCOM_MAX_TASKINGS` per active locality, and how a
  bubble is delimited (a player ring, an off-screen contact) ([§What the commander spends on](#what-the-commander-spends-on)).
- **Whether the commander should be required to spend** rather than merely able to.
