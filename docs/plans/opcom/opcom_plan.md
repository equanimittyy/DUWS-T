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
| **Commitment** | Turns a choice into an intent with an absolute minimum lifetime and an owner. Re-scoring fills free capacity but cannot re-task a unit until its hold expires, and a de-virtualised unit is out of reach until it re-virtualises | Between ticks |

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
| `DUWS_opcom_belief_str` | believed BLUFOR firepower there ([§The quantity](#the-quantity-force-not-coverage)) — each dismounted man 1, each crewed vehicle its class power, plus `OPCOM_PLAYER_WORTH` added per human aboard, so a group carrying players weighs heavier |

One entry per subject, keyed by `DUWS_opcom_belief_key`; a repeat observation overwrites that entry
rather than appending, and only when an observer is sensing the group *this tick* ([§Sensors](#sensors)),
the reading superseding the stored one outright. Believed force is the observed firepower at that last
sighting, held between sightings — not re-derived each tick. Belief tracks groups, not individual players,
so a squad is one row whether or not it carries a player, and players sharing a group are not
double-counted.

New state takes the `DUWS_` prefix with an `opcom_` tag naming its owner
([`info/architecture.md`](../../info/architecture.md#globals-have-no-namespace)).

Store a position, never an object handle — an object reference re-resolves every tick and follows a
player through respawn, taxi and fast travel. Same latching rule as the artillery target grid
([§Observation is the trigger](#observation-is-the-trigger)).

### Sensors

| Sensor | Writes | Cost |
|---|---|---|
| Direct sighting | each live OPFOR observer's `nearTargets` is swept; a BLUFOR group with a *fresh* position time (sensed this tick) has its leader position, threat (each AI one, each human `OPCOM_PLAYER_WORTH`) and the tick stamped. A group nobody senses this tick is untouched — its stamp holds at last-seen and decays. `knowsAbout` cannot serve here: it lingers side-wide while any unit merely remembers a target, so it reads the same watching a mover as remembering a ghost ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)) | one `nearTargets` per live OPFOR group per tick |
| Absence | a group whose belief row resolves (`groupFromNetId`) to a dead, drained or deleted group is dropped, so a confirmed-gone force stops depositing; server-polled, never a `Killed` handler | one resolve per group-keyed row per tick |
| Observation post | an OP hardpoint covering ground stamps what it sees | [§Observation is the trigger](#observation-is-the-trigger) |
| Area of influence | a BLUFOR group inside OPFOR area of influence (`fnc_aoi_opfor_covers`) stamps a low-strength, delayed entry | one coverage read per group per tick |
| Zone flip | stamps exactly and free | event-driven |
| Intel patrol tasking | a purchased sensor ([§What the commander spends on](#what-the-commander-spends-on)) | the tasking's own cost |

The sighting sweep is one `nearTargets` per live OPFOR group (on its leader), bounded by `OPCOM_SENSE_RANGE`
— no `nearEntities`, no scan over `allUnits`
([`info/performance.md`](../../info/architecture/performance.md#the-pattern-that-costs-the-most-timed-scans-anchored-on-allunits)).
Observers are the OPFOR groups actually spawned near the fight, so a stowed garrison neither senses nor
costs. The artillery observation gate keeps its own `knowsAbout > 1.5` test — a separate, position-free
trigger — so no shared constant is owed here.

Only direct sighting and its absence check are live today. The observation-post, area-of-influence,
zone-flip and intel-patrol sensors each attach with the system that fires them — hardpoints, the AOI
field, the zone-capture event, a purchased tasking — in the phase that lands that system, not before.

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

Static per-cell arrays alongside, built once at init and never rebuilt. They classify each cell into the
three movement domains — land, water, air — that Routing and the transport ferry read:

- **Land mask** `DUWS_opcom_grid_land` — one `surfaceIsWater` at each cell centre (3844 calls, one-time). A
  cell is passable to ground movement only where the mask reads land.
- **Land connectivity** `DUWS_opcom_grid_comp` — a flood-fill of the land mask labelling connected land
  components. A ground tasking is ordered only where source cell and target cell share a component, so
  the director never sends a ground squad at an island it cannot reach ([§Routing](#routing-a-cost-field-over-the-grid)).
- **Water connectivity** `DUWS_opcom_grid_water` — a flood-fill of the *water* cells (the mask's complement),
  each component sized. A component of at least `OPCOM_WATER_MIN_CELLS` (~10 cells) is **navigable water**: a
  boat is ordered only where source and target share one navigable water component, and a boat spawns on the
  nearest such body ([§Transport](#transport-carrying-a-unit-to-the-fight)). A water component below that size
  is **too small for water** — no boat works there.
- **Air** needs no array. A rotary or fixed-wing tasking treats every cell passable and flies over all three
  domains alike — land, navigable water, and the sub-threshold water that only air can cross. So a strait too
  small for a boat is bridged by an air ferry, not a boat.

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

No single cell holds a source's full weight. The deposit discounts each cell by its distance from the
source *position*, and a source rarely sits on a cell centre, so even the nearest cell reads below the
weight and neighbours fall off from there; overlapping sources sum, so a cell can also exceed any one
weight. Every read is a sum over a block ([§What reads it](#what-reads-it)), never one cell against a
headcount — so the debug overlay's per-cell figure is the field value at that cell, not the emitter's men.

**Friendly layer** (`DUWS_opcom_grid_fri`) — OPFOR force, known exactly, no belief scaling. Weight is
category-power ([§The quantity](#the-quantity-force-not-coverage)) summed over the source, condition-scaled
where the source is a unit:

| Source | Position | Weight | Reach |
|---|---|---|---|
| OPFOR-held zone, base garrison | `zone_meta_array` pos (`select 1`) | base-tier composition force (Fortify raises this; recruits do not) | zone size (`select 2`) + `OPCOM_GRID_SPREAD` |
| Banded town garrison | `civ_locations` | `DUWS_townGarrisonTier` composition force | `civ_radii` + `OPCOM_GRID_SPREAD` |
| OPFOR hardpoint | `DUWS_hardpoints` pos (`select 1`) | its crew / weapon power | `OPCOM_GRID_SPREAD` |
| OPFOR unit (`garrison` / `guard` / tasking) | its world position — stored (virtual) or live | its `effForce` ([§Unit strength](#unit-strength)) | `OPCOM_GRID_SPREAD` |

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

Routing branches on movement type. A **wheeled or tracked** tasking routes on roads (below); an **infantry,
air or boat** tasking follows a **cell chain** produced by a shortest-path search over the grid, walking
its cell centres in world space ([§One nominal speed](#one-nominal-speed-per-unit-type)); search cost
per step:

```
cost(step into _cell) = stepLen + OPCOM_ROUTE_LAMBDA * _lambda * (_gridEne select _cell)
```

- `stepLen` is `OPCOM_GRID_CELL` orthogonally, `OPCOM_GRID_CELL * sqrt 2` on a diagonal — 8-neighbour
  steps. Passability is by domain ([§Geometry](#geometry)): **infantry** routes over land cells only (water
  impassable); a **boat** routes over navigable-water cells only, staying inside one water component; **air**
  treats every cell passable, over all three domains.
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
not persisted — it recomputes from its current position's cell to the target on load.

| Constant | Value |
|---|---|
| `OPCOM_ROUTE_LAMBDA` | flank threat-avoidance weight (tune) |
| `OPCOM_ROUTE_RECOMPUTE_TICKS` | ticks between flank re-routes (start 12–24, ~1–2 min; tune) |

**Wheeled and tracked route on roads.** A ground vehicle does not take the grid cost field — it must
travel by road. Its route is the world-space polyline from `fnc_convoy_path` `[start, dest]`, the OPFOR
convoy road router: an A* over the engine road graph (`roadsConnectedTo`) that snaps each end to the
nearest road and returns a chain of `road` and off-road `gap` segments. OPCOM borrows only the *routing* —
`fnc_convoy_path` — never the convoy driving engine. Its world-point steps that polyline exactly as it steps
a cell chain (its own cheap stepper), recomputing when the target moves. On de-virtualisation the vehicle
spawns on the route and takes its normal A3 order ([§Spawn posture](#spawn-posture-follows-the-order)),
driving from there under native AI: there is no `fnc_convoy_drive` and no column to hold, because OPCOM
fields **one hull per tasking**, never a convoy. Reuse the router, do not re-derive road pathing.

- **Off-road only to bridge.** A vehicle leaves the road only on a `gap` segment the router emits where no
  road connects — the stub from each end onto the network, or a crossing between road components A* cannot
  join — then resumes on road; a wholly roadless target is one `gap`.
- **Isolated strips are the router's job, not OPCOM's.** `fnc_convoy_path` already repairs
  sparsely-connected nodes and, when components cannot join, exits on the start-side road nearest the
  destination before the gap, so a unit never snaps onto a disconnected strip and stalls. OPCOM water-checks
  any `gap` (`fnc_route_has_water`) so a bridge never runs a hull into the sea.
- **Roads are distance-first.** The road A* weighs length, not `_gridEne` — a route on rails cannot bend
  around belief the way the λ=1 flank does, so wheeled/tracked take the shortest connecting road path and
  the flank / encircle maneuvers stay grid-routed foot and air plays
  ([§Templates](#templates-the-execution-forms)).

### It is not the area-of-influence field

`fnc_aoi_field_at` is a pointwise, binary read — `+1/-1/0` coverage, no magnitude, no player
knowledge — and it drives town drift and hardpoint siting
([`opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md)). The grid is the
two-sided force magnitude that adds the belief store and only OPCOM's scoring consumes; it touches
neither drift nor siting, and its footprints are small where the AOI reaches are kilometres. Its render
rides on the dev overlay `fnc_debug_opcom_view`, alongside the AoI coverage circles
(`fnc_debug_opcom_grid` / `fnc_debug_opcom_grid_draw`).

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
| Recruit | one per demand group (force / recon / supply / transport) — each the prize that group unlocks ([§Value](#value-the-worth-of-the-ground-in-play)) |
| Reinforce | each own holding below its strength cap |
| Scout | routes for an available recon unit's sweep footprint |
| Arty | each observed belief point in range of an owned gun |
| Fortify | each own holding below its tier ceiling |
| Build | each own threatened / thin-line cell |
| Bank | one null |

The gate splits by how the action pays ([§Cost](#cost-what-an-action-stakes)):

- **Spend actions** (Recruit, Reinforce, Fortify, Build, Arty) — drop when `Cost > wallet`; a supply-gated
  build — Build, or a *town* Reinforce or Fortify — also drops when no `supply` truck is on hand to carry it
  ([§Supply](#supply-gates-the-town-side-builds)).
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
| builds force (Recruit) | per demand group, the best action that group unlocks (below) |
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

**Recruit — per group, demand-valued.** Recruit is one candidate *per demand group*, each valued by the
best action that group would unlock, so OPCOM hires exactly what it is short of. **Force** (any unflagged
row, infantry or armour — both only add force): the ground it cannot reach for lack of force — scan the
Attack candidates that fail the `P(win)` floor, take the richest, and value one hire at `prize × ΔP(win)`,
the win-probability a single added unit buys against that target, taking the unflagged row whose
`ΔP(win) / hire cost` is best; diminishing (the sigmoid flattens past `r ≈ 1`) and self-terminating (once
accumulated force clears the floor the prize becomes a live Attack and the prize drops to the next locked
target). **Recon**: the best Scout Value it would enable. **Supply**: the best delivery it would enable — a Rapport, or a Build,
town Fortify or town Reinforce otherwise gated for want of a truck. **Transport**: the best Attack or Intercept it unlocks by making an out-of-reach objective
reachable — across water, or nearer in transit time than a foot unit could manage
([§Transport](#transport-carrying-a-unit-to-the-fight)). OPCOM hires the top-scoring group — massing force
for an out-of-reach zone, buying eyes when it needs to Scout, a courier when a town is worth turning, a
carrier when the fight is across water — and stops when nothing is short.

**Scout — worth at stake × staleness.** Only a recon-flagged unit can Scout, and its reveal footprint is a
Chebyshev radius set by platform — `recon (foot)` its own cell (radius 0), `recon (car)` the 3×3 around it
(radius 1), `recon (heli)` the 5×5 (radius 2). The reveal is abstract and continuous: each tick along its
one-shot route the unit stamps fresh belief for every BLUFOR within that radius of its current cell, no
line-of-sight — buying perception where OPCOM has no observer. A route's Value is `Σ` over the cells its
footprint sweeps of `cell worth × staleness`, where `cell worth = max(offensive, defensive)`: offensive is
attackable enemy ground worth in the cell, defensive is own ground worth exposed through it. A wider-range
unit sweeps more cells (higher Value) at a higher reacquisition Cost, so range trades against unit price on
the ROI axis with no extra knob.

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

A chosen action becomes an intent record and stays one until it completes, dies, or is re-tasked.
The commit **hold** — `OPCOM_COMMIT_HOLD`, one global span of **6 ticks (30 s)** before OPCOM may re-issue
that unit's order — steadies a commitment against the fast re-score; it is an anti-flap lock, not a deadline
the tasking must succeed within. The hold is **absolute** (KISS): a committed unit is held the full span no
matter what, with no early-abandon escape hatch, so a target that dies mid-hold is simply re-evaluated once
the hold expires. One number covers every active tasking. Resting `garrison` and `guard` taskings are unheld
— hold 0, freely drawable. Re-scoring next tick fills free capacity and may re-task a unit only once its hold
has passed. Once a
tasking's units **de-virtualise** — spawn as a live A3 group — OPCOM can no longer steer them: they run
their spawned order ([§Spawn posture](#spawn-posture-follows-the-order)) and control returns only when they
re-virtualise ([§The virtualisation boundary](#the-virtualisation-boundary)). The world can shift under a
virtual march, never under a spawned group.

| Field | Holds |
|---|---|
| type | the action id ([§What the commander spends on](#what-the-commander-spends-on)) |
| target | the objective — a registry index (zone, town) or a cell |
| roles | `[role, unitRef, status]` bindings drawn from the roster: one for a simple tasking, several for a multi-unit template, none for an economic action |
| phase | index into the template's phase list ([§Templates](#templates-the-execution-forms)) |
| hold | `DUWS_opcom_tick` at commit plus `OPCOM_COMMIT_HOLD` (6 ticks) — earliest tick OPCOM may re-issue this unit's order; a global anti-flap lock, not a success deadline |
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

**A multi-unit assault musters, then launches as one wave.** Mustering is a template behaviour (Phase 5,
[§Build order](#build-order)): the single-unit Attack or Intercept that P3 fields draws one unit and marches
it straight to contact, no gather. When an intent spans several units, in state `mustering` it binds
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

Numbers and strings only. The hold counts in ticks off the shared `DUWS_opcom_tick` counter — the one
clock belief also ages on — never `time` or `diag_tickTime`. One clock means the commitment code never
compares seconds against ticks, and the counter persists with the mission namespace where the two engine
clocks do not ([`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

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
refills) plus its `garrison`ed tasking units. OPCOM may recruit **more than one** into a zone; each is
OPCOM-tracked — its own `effForce`, drawable for an offensive — but distinct from the base tier garrison, so
tasking one out subtracts its `effForce` cleanly and Fortify never touches it. A recruited combatant **feeds the
zone's garrison reserve** ([§Actions](#actions-sinks-and-taskings)): while it rests there it spawns to defend
through the existing garrison-reserve wave (`fnc_garrison_reserve`) when the zone is contested, and OPCOM
draws it back out of the pool to task it offensively. Massing force is stacking recruits on a valuable zone,
then pulling them together for an attack ([§Commitment](#commitment-intents-are-sticky)).

**Combatant and non-combatant.** A recruited unit is a *combatant* by default. The unarmed rows — `boat`,
`trans_heli`, `truck`, `recon_heli` — are *non-combatants*, marked by a `noncombat` flag on their recruit-menu rows
([`fnc_opcom_tasking_init.sqf`](../../../src/duws/server/opcom/fnc_opcom_tasking_init.sqf)). This is a separate
axis from the `transport` flag, which marks lift capacity — an `apc`/`ifv` is transport-flagged yet a
combatant. Only combatants feed the reserve wave. A non-combatant garrisoned in a zone rests **attached** to it
— it still deposits its `effForce` to the grid, so force weighting is unchanged — but never enters the reserve
pool, so the wave never spawns an unarmed hull to drive into a defence. When the zone or town is captured, its
attached non-combatants die with it (their tasking records are dropped). A non-combatant only ever goes live by
being tasked out — a ferry borrow ([`transport_ferry.md`](transport_ferry.md)) or a hand order.

A zone **under attack** locks its recruited garrison units. While its garrison holds live contact with a
BLUFOR force, none of its `garrison`ed units is one any offensive may draw — a contested zone's reserve can
only feed its own defence, never be stripped to mount an attack elsewhere while the player is pressing it.
The lock lifts when contact clears and the zone re-virtualises.

## Movement: a tasking is virtualised until contact

A tasking moves *virtualised*: its position is a **world point** stepping along a planned route chain
([§Routing](#routing-a-cost-field-over-the-grid)) by a per-type speed model, holding no group handle,
until a player closes to within its streaming ring. Like a zone or a hardpoint it is a force source the
grid *reads* at that point ([§Rebuild](#rebuild-deposit-each-source-with-a-linear-falloff)), never bound to
the grid — only sampled by it. Its role binding ([§Commitment](#commitment-intents-are-sticky)) references
that point while virtualised, a live group once it spawns.
This is the mobile analogue of hardpoint streaming, which wakes and sleeps a fixed emplacement on a
`spawnRadius`/`grace` band
([`info/hardpoints.md`](../../info/gameplay/hardpoints.md#streaming-and-garrison)). Movement and streaming
run each loop tick ([§The loop](#the-loop-against-the-engine)).

### One nominal speed per unit type

Model arrival only — which cell the squad is in and when it crosses the streaming ring. One speed per type,
road versus open ground unmodelled, given as **ticks per cell** and tuned for play, not realism: the true
spread (a jet outruns a foot soldier ~80×) is compressed so the virtual layer neither crawls nor teleports.

| Unit type | Water | Ticks per cell | ≈ per cell |
|---|---|---|---|
| Infantry | impassable | 30 | 150 s |
| Wheeled | impassable | 15 | 75 s |
| Tracked | impassable | 20 | 100 s |
| Rotary | passable | 5 | 25 s |
| Fixed wing | passable | 2 | 10 s |
| Boat | water only (land impassable) | 10 | 50 s |

**World-stepped along the route chain.** Each type's ticks-per-cell is a world rate,
`stepMetres = OPCOM_GRID_CELL / ticksPerCell` per tick (infantry ≈17 m, a fixed-wing 250 m). Each tick the
tasking advances its world point that far toward the next **waypoint** on its route chain — a cell centre
on a grid route, a road node on a convoy route ([§Routing](#routing-a-cost-field-over-the-grid)) — then aims
at the one after. On a grid route a diagonal needs no special case; the longer world distance to a corner
cell falls out of the step. The cell for streaming and force deposit is `worldToCell` of that point, computed on
demand ([§Rebuild](#rebuild-deposit-each-source-with-a-linear-falloff)). Water is handled in the route, not
per step — a ground route never contains a water cell ([§Routing](#routing-a-cost-field-over-the-grid)).

Persisted state is the world position, the target and the route mode — all numbers, so a virtualised
tasking serialises with its order ([§Persistence](#persistence)). The route chain recomputes from that
position on load.

### The virtualisation boundary

A tasking unvirtualises — spawns as a native A3 group at its world point — on either of two triggers: its
cell (the `worldToCell` of that point) closes to within **K cells** (Chebyshev, `max(abs(dx), abs(dy))`) of
any player's cell, **or** it reaches an opposing force (an OPFOR assault closing on a BLUFOR-held cell).
Inside the ring the group is real, the engine owns its pathfinding, and the tasking issues its order
*best-effort*.

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
| Boat | 2 | ~1–1.4 km |

**Hysteresis.** A live group stows back to a cell once it passes `K + 1` cells from every player **and holds
no live contact** — one full cell of margin so a group on the edge cannot flicker. A group in a firefight
stays live until it resolves, whether or not a player is near.

The boundary is a square ring in cell space, so a tasking on the diagonal streams in ~1.4x further than
orthogonally — acceptable for spawn-before-contact.

### Spawn posture follows the order

A de-virtualised unit runs a native A3 order that is the **closest engine equivalent of its tasking**, set
at spawn, not a tick later. OPCOM does not steer it after that — a spawned group is out of its hands until
it re-virtualises ([§Commitment](#commitment-intents-are-sticky)), so the spawned order has to carry the
whole intent on its own.

| Tasking | A3 order |
|---|---|
| Assault (Attack / Intercept) | Seek & Destroy on the target point, `AWARE` |
| Supply (Rapport, and a Build / town Reinforce / town Fortify truck) | move to the target cell in `SAFE`; on arrival delete the unit and fire the tasking's success |
| Scout | move to the point in stealth, combat mode `GREEN` — hold fire, return fire only, never initiates |
| Move / reposition | move to the cell in `SAFE` / `AWARE` |
| Guard | hold at its current cell in `SAFE`, defend — takes up a slot, no objective |

`garrison` and Recruit issue no standing order: a recruited combatant joins its zone's garrison reserve
(a non-combatant rests attached, [§Unit strength](#unit-strength)) virtually, and takes an order only when the zone is contested and it
spawns to defend through the existing garrison-reserve wave, or when OPCOM draws it back out to task it for
one of the rows above.

### Transport: carrying a unit to the fight

A `transport`-flagged unit ([§What the commander spends on](#what-the-commander-spends-on)) carries one
other tasking unit to speed its march or cross water it could not. The carry is an explicit **boarding
order** OPCOM issues — it names the transport and the rider and binds the pair — never an automatic embark of
any two units that happen to share a cell. The binding rides on the transport's intent; the ride itself is
best-effort in the A3 sim.

- **Capacity is one unit, any size — seats are not checked to carry.** A transport carries at most one
  infantry tasking unit whatever its headcount, and its hull's cargo seats do not gate the load. This is
  deliberate: a detected faction whose only transport seats two men can still ferry a whole squad
  *virtually*, so the mechanic never depends on a mod fielding a roomy carrier. Seats bind only when the
  pair goes live.
- **Load and transit, virtualised.** Once the boarding order binds them, the pair converges on a shared cell
  and embarks there: the carried unit gives
  up its own cell and route and rides the transport's, stepping at the transport's speed and **ignoring its
  own water-impassability** — so a foot squad crosses a strait it could never walk. Position, force deposit
  and routing all follow the transport's cell while embarked.
- **De-virtualisation is best-effort.** When the pair streams in ([§The virtualisation
  boundary](#the-virtualisation-boundary)) the transport spawns, and the carried unit is `moveInCargo`'d
  into it only if the hull's seats fit the whole load.
  - **Fits** — the unit spawns aboard and is, in the ledger, immediately unloaded onto the transport's cell
    as an independent unit. Its life is no longer tied to the transport: it stays physically seated until
    its AI or an order disembarks it, but if the hull is destroyed with it still aboard, A3 kills the live
    men and the ordinary per-unit status read records the loss — there is no bookkeeping death cascade.
  - **Does not fit** — the carried unit's de-virtualisation is aborted; it stays virtual and tied to the
    transport. If the transport is destroyed while live, the tied unit dies with it, having never got out.
- **Unload at the destination.** At its drop cell the carried unit disembarks, reclaims its own cell at that
  position, and resumes its own tasking and speed.

A **boat** is its own movement type: water-passable and **land-impassable**, the mirror of a ground unit, so
its routes are water-only. It is **armed by default** — the detected `*_BOAT_ARMED_*` gunboat class — so it
both fights on the water and ferries (`transport`), not a ferry-only hull. Its class rides on the existing
faction boat detection (the `_boat` bucket every faction parse fills), which today is exposed only on the
BLUFOR side (`blufor_BOAT_*`); the OPFOR side needs the same role added (`opfor_BOAT_ARMED_X`, mirroring it)
plus a `boat` row in the spawn vocabulary — a wiring of existing detection, not a new token backfill. Where
no boat is detected the sea-ferry falls to a rotary transport. A boat classifies to a small fixed firepower
(`boat` = 2, a light presence on par with an unarmed car), so it deposits a little threat on the grid and its
hire prices at `2 × rate` — no zero-cost carrier. This adds a `boat` bucket to the force model and a `Ship`
branch to the classifier (`isKindOf "Ship"`, the predicate detection already uses), built with the transport.
A boat spawns on the nearest **navigable** water body ([§Geometry](#geometry)) — never on a sub-threshold
puddle or dry ground.

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
| `scout` | a `recon`-flagged unit, a stale valuable area | `scout` ×1 | move (along the route) → reveal (stamp belief within the platform radius each tick) → resolve |
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

### The resolve phase: what ends a template

`resolve` is not a combat step; it is the transition that frees the units and writes the outcome, one
predicate per action.

- **Attack** — resolves when the target zone holds no live BLUFOR. The committed group is live and in
  contact by this phase, so the test is a direct count of BLUFOR within the zone radius, not a belief
  read. On clear, the flip is **not** re-implemented: it reuses the capture path — the zone-capture
  trigger in `fnc_createzone.sqf`, which drives `fnc_captured.sqf` / `fnc_blufor_cap.sqf` to set
  `WARCOM_zones_controled_by_*`, move the markers, and settle the payout. OPCOM owns only the
  precondition (defenders gone); ownership stays single-sourced in that machinery. **Verify before the
  Orchestration phase ships** that the trigger fires for an AI-only fight with no player near — if it is
  gated on player proximity, OPCOM's resolve calls the same capture functions itself rather than
  duplicating the flip.
- **Intercept** — resolves when the threatened ground is clear: the belief entries that scored it have
  decayed or dropped and no live BLUFOR remains in the target block. Nothing changes hands; the units
  release to `garrison` on the ground they were sent to hold.
- **Rapport** — resolves when the courier delivers its step (rep moved 3 toward the −10 turn threshold)
  or dies en route. The town turning is not the resolve — one trip rarely crosses the threshold, and the
  garrison-on-turn belongs to the town-band system ([§Random events](#random-events-what-a-turned-town-does)),
  not the template.

## The loop against the engine

One thread, one cadence, not one thread per action.

| Property | Value |
|---|---|
| Tick | every `OPCOM_TICK_PERIOD` (5 s). Increment the tick counter, then: refresh belief, rebuild the grid, advance in-flight taskings (a world step along the route chain) and live templates ([§Templates](#templates-the-execution-forms)), refresh live-group status ([§Unit tasking and status](#unit-tasking-and-status)), run the streaming check against live player cells ([§Movement](#movement-a-tasking-is-virtualised-until-contact)), score, commit at most one thing, recompute the routes due for it |
| Scoring pass | inside `isNil { ... }` — unscheduled, runs uninterrupted. `server/init_zones/fnc_moreUrban_locations.sqf:126-138` is the worked example, bounded by a wall-clock deadline. The route search runs outside it |
| Clock | the tick counter `DUWS_opcom_tick` — intent expiries and belief age count in ticks, which persist with the mission namespace where `time` / `diag_tickTime` do not |
| Orders | server-local groups only — waypoints are silently ignored unless the group is local to the issuing machine |
| State | numbers, strings, arrays of those — no group or object handles near the mission namespace |
| Fault containment | the tick body is wrapped so a throw in sense / rebuild / score is caught and logged, never silently killing the perception thread for the rest of the mission |

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
| Recruit | buildup | the highest-value unmet unit need; raises a `garrison` unit into an OPFOR zone (a combatant joins its reserve wave; several may stack) | tasking-spawn | 1 (`garrison`, resting — no active order) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 for a zone; 1 (`supply` truck) for a town |
| Scout | recon | a `recon` unit's route sweeping stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed belief point in range of an owned gun | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 for a zone; 1 (`supply` truck) for a town |
| Build | defensive | an own threatened cell | hardpoint build | 1 (`supply` truck) |
| Bank | — | — | none | 0 |

Value and Cost are [§Appraisal](#appraisal-expected-ap-return); the band and templates are
[§Templates](#templates-the-execution-forms).

**Recruit fills the roster; every other unit-dispatching action drains it.** Recruit is the RTS "hire a
unit": it raises a group homed to an OPFOR zone — OPCOM-tracked and distinct from the base
garrison the town/zone Reinforce refills. A combatant feeds the same reserve wave that spawns it to defend
when the zone is contested; a non-combatant rests attached and never joins the wave
([§Unit strength](#unit-strength)). Several may stack on one zone. The unit rests with no
standing order; OPCOM draws it back out for an Attack, Intercept, Rapport or Scout, which strips the zone. So OPCOM must build up before it can strike, and a lost unit is lost standing strength.

**Recruit chooses by demand.** It is scored once per demand group — generic force, `recon`, `supply`,
`transport` — each against the best action that group unlocks ([§Value](#value-the-worth-of-the-ground-in-play)),
so OPCOM hires eyes when it needs to Scout, a courier when a town is worth turning, a carrier when the fight
is across water, and plain force to mass for an out-of-reach zone. Capability flags (`recon` enables Scout,
`supply` a delivery run — Rapport, Build or a town harden, `transport` a carry) ride on the menu row
(below); an unflagged row carries none and can only add force to a fight.

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

**A unit's force is a token composition, hired from one menu.** Each buyable unit is a row in
`DUWS_opcom_recruitMenu`, tuned in that one place and never hardcoded at a spawn site: an id, a composition
(an array of tokens like `squad` or `tank` from the same vocabulary the garrisons use, resolved by
`DUWS_fnc_tokenClass` against the detected faction), and a set of capability flags. The tokens are **bare**
— no posture prefix, so each resolves to the `none` posture and the recruited unit takes its orders from
OPCOM rather than a standing circuit ([§Spawn posture](#spawn-posture-follows-the-order)).

| Row | Composition | Flags |
|---|---|---|
| rifles | `["squad"]` | — |
| weapons team | `["wp_team"]` | — |
| APC | `["apc"]` | `transport` |
| IFV | `["ifv"]` | `transport` |
| MBT | `["tank"]` | — |
| attack helicopter | `["attackheli"]` | — |
| recon (foot) | `["recon"]` | `recon` |
| recon (car) | `["car"]` | `recon` |
| recon (heli) | `["transheli"]` | `recon` |
| truck | `["truck"]` | `supply`, `transport` |
| transport helicopter | `["transheli"]` | `transport` |
| boat | `["boat"]` | `transport` |

The three `recon` rows differ only by platform, which sets the Scout reveal radius
([§Value](#value-the-worth-of-the-ground-in-play)) — OPCOM buys the reach it needs. The vocabulary has no
dedicated scout helicopter, so `recon (heli)` and the transport helicopter share the one `transheli`
platform, told apart by their flag.

**Price is force, not a per-row number.** A hire costs `ceil(force × OPCOM_AP_PER_FORCE)` — the
composition's firepower ([§The quantity](#the-quantity-force-not-coverage)) times the one force→AP rate — so
a tank costs several times a rifle section and no price can drift out of step with what a unit is worth.
That rate is the single force↔AP knob and also prices commit `Cost` and Arty's kill Value
([§Cost](#cost-what-an-action-stakes)), so the menu carries no price column.

**Capability flags decide what a unit unlocks; there is no unit "type".** An unflagged row is generic force,
hired to win a fight and nothing more; a flagged row also unlocks an action. `recon` makes the unit eligible
to Scout (its range rings by type, [§Value](#value-the-worth-of-the-ground-in-play)), `supply` to Rapport,
`transport` to carry another unit ([§Transport](#transport-carrying-a-unit-to-the-fight)); a row may carry
several, as the truck both couriers and ferries and a carrier (APC or IFV) fights while ferrying a section.
Recruit scores one candidate per demand group — force,
`recon`, `supply`, `transport` — so a specialist enters the roster only when the action it enables is worth
its hire.

### Supply gates the town-side builds

A `supply` truck runs one kind of errand — drive from OPFOR ground to a target cell and be spent on arrival
— behind four actions: turn a town (Rapport), build a hardpoint (Build), and restore or upgrade a *town*
garrison (Reinforce refills its strength toward the tier, Fortify raises the tier). Each binds one truck at
commit and does not resolve until that truck arrives.

- **Committed, not guaranteed.** The AP is paid up front — a spend action still pays its price at commit,
  Rapport still stakes its courier — and the order binds to one *specific* truck, sent to the target cell.
  The result lands only when the truck arrives, where it is deleted: the hardpoint spawns, the garrison
  refills, the tier raises, or the town steps toward turning.
- **Interdiction is the counterplay.** Kill the bound truck en route and the order fails outright — no
  build, and the AP is not refunded. Binding to *that* truck rather than "a truck" means the order dies with
  its carrier instead of waiting on one that will never come.
- **No truck, no commit.** These actions gate on a truck being on hand — idle in the roster, or affordable
  to Recruit this tick. With none, the action drops from scoring, so a player who keeps killing trucks keeps
  OPFOR from fortifying its towns and raising new hardpoints at all. OPCOM need not hold a standing truck
  reserve; it may buy one only when it has a build worth making.
- **Zones need no supply.** A zone is where OPFOR originates, so reinforcing or fortifying a *zone* garrison
  resolves on paying AP alone — no truck, no delivery. The asymmetry reads as OPFOR trucking matériel outward
  from its zones to the contested towns and the open field.

The delivery is a plain one-unit courier tasking (move to the cell → deliver → resolve), the same shape as
Rapport's ([§Templates](#templates-the-execution-forms)); the build it triggers reuses the existing purchase
machinery, fired on arrival rather than at commit.

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

OPCOM's tasking store is shaped to serialise (numbers and strings only, no object handles — the live group
is held by netId), but OPCOM does not implement its own save/load: persisting the standing units and orders
below is the campaign snapshot's responsibility, not an OPCOM build phase.

| State | Kind | Contract |
|---|---|---|
| Archetype | input | The one string rolled at OPCOM init. Restore feeds it back before the loop runs, never re-rolls ([§The commander has an archetype](#the-commander-has-an-archetype)) |
| Standing units & orders | outcome | One row per unit — its tasking, target, current world position, `strength` ([§Unit strength](#unit-strength)), and a moving one's route mode. Persisted as data, never a live squad: restore resumes each unit at that position (chain recomputed [§Routing](#routing-a-cost-field-over-the-grid)) at its saved strength, streaming to a live group on player approach. A `garrison` combatant restores onto its zone's reserve; a non-combatant restores attached |
| Tiers | outcome | `WARCOM_opfor_tier` and its earned counter, owned by [`economy_second_pass.md`](../economy_second_pass.md#the-ratchet-is-otherwise-structural-and-only-in-half-the-read-sites); the archetype rides beside them |

Every persisted field is a number, a string, or an array of those. Time-based fields — intent expiries
and belief ages alike — count in ticks off the shared `DUWS_opcom_tick` counter, which persists with the
store, never on `time` or the process-relative `diag_tickTime`
([`info/arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

Whether the belief store persists is open ([§Open questions](#open-questions)); it is shaped to
serialise, so a restored campaign that omits the key rebuilds belief from its first sensor pass. Either
way `fnc_opcom_belief_init` declares each array and the tick counter **init-if-nil** — only where unset,
never unconditionally — so a restore that fed the store back before the loop starts is not wiped, and a
loop restart cannot zero live belief. Belief
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
| **1 — Perception** *(shipped)* | The four belief arrays, the sighting sweep (with its absence check), decay, the influence grid stamped from belief and holdings, the land mask + connectivity, the debug overlay | Nothing prior |
| **2 — Force weighting** | First a standalone single-class classifier (`fnc_classifyVehicle`, reusing the faction detector's per-class leaf predicates, so a sighted enemy class classifies on the fly without touching detection), then replace the men-count metric with firepower: one power table keyed on that category, deposited by **both** grid layers — friendly holdings (via their tokens) and enemy belief (via the classifier) — so the two share one metric. `fnc_opcom_sense` stamps enemy firepower, not headcount | The grid + belief it re-weights |
| **3 — Recruitment & tasking wiring** | The Recruit / spawn mechanism, the roster / force-pool, the intent record and unit strength, movement (world-point stepping, cost-field routing, cell streaming + hysteresis, tasking / status reads), and simple single-unit orders — driven **by hand** through a debug harness (spawn a unit, order it, watch it). No automated decisions | Force weighting + grid |
| **4 — Decision loop** | The scoring pass on the tick: the AP-return score, the force ratio and `P(win)`, the economic actions (Fortify, Build, Bank) and the tasking actions (Recruit, simple orders) committed automatically; the commitment record with the absolute hold; flat archetype weights | The P3 mechanism + grid / force |
| **5 — Orchestration** | Multi-unit templates (assault / flank / encircle / probe / arty), mustering to fill roles, the band → template pick, the generic runner — coordinated AI over the single-unit orders P3/P4 built, and the indirect-fire missions (`arty`) | The loop + movement + templates |
| **6 — Archetype** | The per-class weight sets from [§The commander has an archetype](#the-commander-has-an-archetype), replacing the flat stub | The loop it modifies |

Random events (turned-town IED / ambush / sabotage, hostile conversion) are out of this roadmap — that
behaviour shipped separately; the design section below documents what it does, not an OPCOM build phase.

## Implementation

Build in the [§Build order](#build-order) sequence, each phase shipped runnable and verifiable before the
next. Each phase's implementation spec is its own doc, picked up when the phase is; do not pre-build the
later phases, since the tuning constants and the engine-contact behaviours (streaming, `doArtilleryFire`,
virtual combat) only settle by running the core. The rest of this plan is the design spec those phase
docs draw on.

- Phase 1 — Perception: **shipped**; the code is `src/duws/server/opcom/` and its debug overlay under
  `client/debug/` (the phase doc is retired now the phase is built).
- Phase 2 — Force weighting: **shipped**; the force model is `src/duws/server/opcom/fnc_opcom_force.sqf`
  with the single-class classifier in `shared/factions/MODERN/fn_factionAutoDetect.sqf` (the phase doc is
  retired now the phase is built).
- Phase 4 — Decision loop: an early draft written ahead of its phase — [`phase_4_decision_loop.md`](phase_4_decision_loop.md).
  Covers only the appraisal + economic-actions slice; the tasking-automation half is added when P4 begins.

## Open questions

- **Action-economy granularity against the tick.** The loop is one `OPCOM_TICK_PERIOD` (5 s) tick that
  scores and commits at most one action; the per-action AP costs, the faucet rate and the single global
  commit hold (`OPCOM_COMMIT_HOLD`) that steadies an intent across that fast re-scoring all tune in play in
  the decision loop (Phase 4). The tick itself is settled — one cadence, no separate action cooldown clocks
  ([§The loop](#the-loop-against-the-engine)).
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
- **The `AP-per-force` exchange rate** `OPCOM_AP_PER_FORCE` — the single force→AP knob: a hire costs
  `ceil(force × rate)` and the same rate prices commit `Cost` and Arty's kill Value; only the value tunes
  ([§Cost](#cost-what-an-action-stakes)).
- **The per-locality live-group budget** — the value of `OPCOM_MAX_TASKINGS` per active locality, and how a
  bubble is delimited (a player ring, an off-screen contact) ([§What the commander spends on](#what-the-commander-spends-on)).
- **Whether the commander should be required to spend** rather than merely able to.
