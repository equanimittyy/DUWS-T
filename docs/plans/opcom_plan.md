# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns,
tasks squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and the faucets
that fill it are the economy's ([`economy_second_pass.md`](economy_second_pass.md#army-power)); the
shipped hardpoint mechanics it draws from are [`info/hardpoints.md`](../info/gameplay/hardpoints.md);
the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../info/gameplay/opfor_area_of_influence.md#band-siting).

## The three layers

Three layers, one thread.

| Layer | Does | Runs |
|---|---|---|
| **Perception** | Maintains the enemy's *belief* about BLUFOR. Never reads live player state | Every tick, one engine call per player |
| **Appraisal** | Scores each candidate `[sink, target]` pair on five named terms, picks by weighted random over the top few | Every tick, one unscheduled batch |
| **Commitment** | Turns a choice into an intent with a minimum lifetime and an owner. Re-scoring fills free capacity; it cannot cancel a live intent | Between ticks |

## Perception: the commander plans against belief, never against truth

The commander reads a belief store. Only the sensors below read truth (`allPlayers`, `getPos`,
`knowsAbout`). Nothing else in OPCOM may read live player position or strength.

### Shape

Parallel arrays, server-local, indexed together, every entry a number or an array of numbers.
Serialisable — the mission namespace is the save file, so state that might outlive a session holds no
handles ([`info/hardpoints.md`](../info/gameplay/hardpoints.md#why-hardpoints-are-not-zones),
[`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).
Model on `DUWS_sites` (server-local, handle-free), not `DUWS_hardpoints` (a single mixed-type,
`publicVariable`d row array). Not broadcast — no client reads belief.

| Array | Holds |
|---|---|
| `DUWS_opcom_belief_key` | what is believed about: a player's `netId`, a zone index, a FOB index, the player HQ |
| `DUWS_opcom_belief_pos` | `[x,y,0]` as last observed, never a live lookup |
| `DUWS_opcom_belief_time` | the strategic-tick counter at the observation |
| `DUWS_opcom_belief_str` | believed BLUFOR strength there |

New state takes the `DUWS_` prefix with an `opcom_` tag naming its owner
([`info/architecture.md`](../info/architecture.md#globals-have-no-namespace)).

Store a position, never an object handle — an object reference re-resolves every tick and follows a
player through respawn, taxi and fast travel. Same latching rule as the artillery target grid
([§Observation is the trigger](#observation-is-the-trigger)).

### Sensors

| Sensor | Writes | Cost |
|---|---|---|
| Direct sighting | `east knowsAbout _p > 1.5` stamps that player's position, group size and `time` | one engine call per player per tick |
| Observation post | an OP hardpoint covering ground stamps what it sees | [§Observation is the trigger](#observation-is-the-trigger) |
| Area of influence | a player standing inside OPFOR area of influence (`fnc_aoi_opfor_covers`) stamps a low-strength, delayed entry | one coverage read per player per tick |
| Zone flip | stamps exactly and free | event-driven |
| Intel patrol tasking | a purchased sensor ([§What the commander spends on](#what-the-commander-spends-on)) | the tasking's own cost |

`east knowsAbout _p` is a side-wide query — the whole sighting sweep is one call per player, no
`nearEntities`, no scan over `allUnits`
([`info/performance.md`](../info/architecture/performance.md#the-pattern-that-costs-the-most-timed-scans-anchored-on-allunits)).
Threshold `1.5` is shared with the artillery observation gate — one constant, do not add a second.

### Decay

Confidence falls with the age of the stamp, counted in **strategic ticks**, not seconds: a stamp holds
the tick counter at observation, and `_age` is the current counter minus it. Two thresholds, in ticks:
`OPCOM_BELIEF_FRESH` 4 and `OPCOM_BELIEF_EXPIRE` 16 (≈ 5 and 20 min at a 60–90 s strategic phase; tune).

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

Every cell holds a **force** figure in headcount-equivalent units — one unit ≈ one infantryman, a
vehicle worth its crew plus a fixed bonus. Two layers carry it: `friendly` is OPFOR force, `enemy` is
believed BLUFOR force. This is the unit the muster check needs; the AOI
field's binary coverage cannot supply it ([§It is not the AOI field](#it-is-not-the-area-of-influence-field)).

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
the AOI coverage projection, so a source spreads over its own body plus one cell, never the 2–5 km AOI
reaches.

**Friendly layer** (`DUWS_opcom_grid_fri`) — OPFOR force, known exactly, no belief scaling:

| Source | Position | Weight | Reach |
|---|---|---|---|
| OPFOR-held zone | `zone_meta_array` pos (`select 1`) | tier headcount (`fnc_zone_tier` 1–4 → I≈6 … IV≈18) | zone size (`select 2`) + `OPCOM_GRID_SPREAD` |
| Banded town | `civ_locations` | `DUWS_townGarrisonTier` headcount, same tier→count map | `civ_radii` + `OPCOM_GRID_SPREAD` |
| OPFOR hardpoint | `DUWS_hardpoints` pos (`select 1`) | crew ≈ 2 | `OPCOM_GRID_SPREAD` |
| OPFOR tasking in flight | intent's stored (virtualised) or live pos | its composition headcount | `OPCOM_GRID_SPREAD` |

**Enemy layer** (`DUWS_opcom_grid_ene`) — believed BLUFOR force:

| Source | Position | Weight | Reach |
|---|---|---|---|
| BLU-held zone | zone pos | its known garrison headcount, nominal where none exists | zone size + `OPCOM_GRID_SPREAD` |
| Belief entry | `DUWS_opcom_belief_pos` | `DUWS_opcom_belief_str` × decay factor | `OPCOM_GRID_SPREAD` |

A belief entry covers a sighted player, a discovered HQ and a discovered FOB alike. The decay factor
is `((OPCOM_BELIEF_EXPIRE - _age) / (OPCOM_BELIEF_EXPIRE - OPCOM_BELIEF_FRESH)) max 0 min 1` with `_age`
in ticks — 1 under `OPCOM_BELIEF_FRESH`, falling to 0 at `OPCOM_BELIEF_EXPIRE` ([§Decay](#decay)); an
expired entry is already dropped from the arrays, so it never deposits.

| Constant | Value |
|---|---|
| `OPCOM_GRID_CELL` | 500 m |
| `OPCOM_GRID_SPREAD` | 500 m — point-source footprint, added to a zone/town radius |

### What reads it

`_gridFri`/`_gridEne` below are `DUWS_opcom_grid_fri`/`DUWS_opcom_grid_ene`. A point read is
`(_gridFri select _cell) - (_gridEne select _cell)` — the signed force balance.

| Read | How |
|---|---|
| **threat** term ([§Five terms](#five-terms)) | `_gridEne select _targetCell` |
| **reach** term | `_gridFri select _targetCell` — high near OPFOR force |
| **vulnerability** term | garrison tier ÷ (`_gridEne select _targetCell` + 1) |
| **Force at a place** (clustering) | `_gridEne select _cell` — the deposit already summed every belief entry in the cell, so a four-to-eight-player co-op stack is one read, no separate clusterer ([§Open questions](#open-questions)) |
| **Muster** ([§Commitment](#commitment-intents-are-sticky)) | clears when `_gridFri select _targetCell > _gridEne select _targetCell`; the assault's own converging taskings raise the friendly side until it does |
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
- `_lambda` is **0 for a direct route** (QRF, supply, rapport — distance only, ignores the enemy) and
  **1 for a flank** (an assault the director judges worth flanking — the path bends around believed
  enemy force). The search is Dijkstra; at 3844 nodes it is cheap, but **not inside the `isNil`
  scoring block** — run it scheduled or on its own bounded pass.
- **When a flank is ordered**: an assault intent, and only where the direct line crosses enemy above a
  threshold *and* a lower-cost detour exists — otherwise it goes direct. Tuning, not fixed here.

**Recompute cadence.** Belief only updates on the strategic phase ([§The loop](#the-loop-against-the-engine)),
so routes recompute there, never on the fast pass. A direct route is recomputed when its target cell
changes; a flank route every `OPCOM_ROUTE_RECOMPUTE_PHASES` strategic phases (belief drifts under it, so
a stale corridor is no longer safe), or immediately if the chain is exhausted before then. The chain is
not persisted — it recomputes from the current cell to the target on load.

| Constant | Value |
|---|---|
| `OPCOM_ROUTE_LAMBDA` | flank threat-avoidance weight (tune) |
| `OPCOM_ROUTE_RECOMPUTE_PHASES` | strategic phases between flank re-routes (start 3–4, tune) |

### It is not the area-of-influence field

`fnc_aoi_field_at` is a pointwise, binary read — `+1/-1/0` coverage, no magnitude, no player
knowledge — and it drives town drift and hardpoint siting
([`opfor_area_of_influence.md`](../info/gameplay/opfor_area_of_influence.md)). The grid is the
two-sided force magnitude that adds the belief store and only OPCOM's scoring consumes; it touches
neither drift nor siting, and its footprints are small where the AOI reaches are kilometres. Its render
is new work on the dev overlay `fnc_debug_opcom_view`, which today draws only AoI coverage circles.

## Appraisal: utility scoring, not search

Enumerate candidate `[sink, target]` pairs, score each, pick. No search, no lookahead — selection is a
flat score; a committed play's phases are authored, not searched
([§Playbook](#playbook-coordinated-multi-unit-plays)). The
candidate set is small — towns in the OPFOR band, held zones, a handful of corridors — tens of pairs,
a full pass every tick.

### Five terms

Five, and no more.

| Term | Reads |
|---|---|
| **value** | what the target is worth: zone worth, town AP income |
| **threat** | believed BLUFOR force near it, from the belief store alone |
| **vulnerability** | its garrison tier against that believed force |
| **reach** | distance from the nearest OPFOR-held ground |
| **price** | the AP cost, as a divisor |

The three spatial terms — *threat*, *vulnerability*, *reach* — are cell reads of
[the influence grid](#the-influence-grid-one-spatial-substrate); *value* and *price* are table
lookups. Archetype scales the terms, never gates the sinks: Defensive weights value and vulnerability
on ground it holds, Aggressive weights threat and reach against ground the player holds.

### Action follows the force ratio

*What* the commander does at a target follows the believed force ratio there, not the raw score alone.
Read the grid's two layers over the target's 3x3 block, `r = friendly / (enemy + 1)`, and let it gate
which actions are candidates:

| Ratio r | Action band |
|---|---|
| >= 2 | assault — overwhelming, commit directly |
| 1 – 2 | maneuver — envelop, not a frontal charge |
| 0.5 – 1 | probe / harass, or muster and keep buying |
| < 0.5 | hold, avoid, or call reinforcement — do not attack |

The bands are candidates, not commands: the weighted-random pick still runs within the band and
archetype still weights the terms. Thresholds tune in play.

### Weighted random over the top few, not the best

`selectRandomWeighted` over the highest-scoring three, not `argmax` — the mission's existing idiom
(`server/init_zones/fnc_createzone.sqf:129`). Zone vehicles are not picked this way: the tier table
names what a zone fields.

Banking is a candidate, not a policy — a "spend nothing" entry with a low flat score, losing whenever
anything sensible is affordable and winning when everything else has saturated.

## Commitment: intents are sticky

A chosen action becomes an intent record and stays one until it completes, dies, or expires.
Re-scoring next tick fills free capacity; it never cancels a live intent.

| Field | Holds |
|---|---|
| type | which sink, or a play id |
| target | index into the registry the sink acts on |
| owner | the live group the intent drives; runtime state, not snapshotted |
| expiry | `time` plus the intent's own lifetime |
| state | mustering / ordered / in progress / done |

A released group is one whose intent has completed; that ownership state is what the director's
reinforcement logic tests before treating a group as a valid target.

**One record type, three granularities.** A garrison purchase, a hardpoint build and a squad tasking
are one intent record, not three subsystems. `price` is the only field a tasking carries that a build
does not — the squad it will own does not exist yet.

**There is no retreat.** A committed group fights its engagement to a decision: the engine owns a group
in `COMBAT` and will not execute a commanded withdrawal
([`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)).
A group that wins drops back to `moving`, resumes its order, and re-virtualises on clearing the ring
([§The virtualisation boundary](#the-virtualisation-boundary)); a group that loses dies. Recovery is
winning, nothing else.

**An assault musters before it commits.** In state `mustering` a QRF or assault intent accumulates
committed force across ticks and executes only once OPFOR force at the target cell exceeds the believed
player force there — the grid's two layers read at that cell (friendly known, enemy believed). Until
then it holds at a staging cell and keeps buying. The bar is the player's force *at the target*, not the
player's whole strength. Mustering is also how a force-short action waits for the units it needs rather
than committing understrength.

### Unit status

The commander reads a status per live group — its own units, known exactly, refreshed on the fast pass.
Coordinated moves and the reinforcement logic both key off it.

| Status | Read |
|---|---|
| `virtual` | intent owns no live group yet — still a cell on a route |
| `moving` | live, no contact — `behaviour` SAFE/AWARE, low `knowsAbout` |
| `engaged` | live and in combat — `behaviour leader _g == "COMBAT"`, or `leader _g knowsAbout <nearest player> > 1.5` (the sighting threshold) |
| `dead` | `count units _g == 0` |

Cheap: a handful of live groups, one `behaviour`/`knowsAbout` read each, on the fast pass the streaming
check already runs. A virtualised tasking is `virtual` by definition — no read.

Numbers and strings only. `time`, not `diag_tickTime`, so an expiry survives a savegame
([`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

## Movement: a tasking is virtualised until contact

A tasking moves *virtualised*: its position is a **grid cell**, stepped along a route chain
([§Routing](#routing-a-cost-field-over-the-grid)) by a per-type speed model, holding no group handle,
until a player closes to within its streaming ring. Its intent's `owner`
([§Commitment](#commitment-intents-are-sticky)) is null while virtualised, a live group once it spawns.
This is the mobile analogue of hardpoint streaming, which wakes and sleeps a fixed emplacement on a
`spawnRadius`/`grace` band
([`info/hardpoints.md`](../info/gameplay/hardpoints.md#streaming-and-garrison)). Movement and streaming
run on the loop's fast base pass, not the strategic tick ([§The loop](#the-loop-against-the-engine)).

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

**Cell-stepped, with a carry.** A tasking holds a cell plus a metre accumulator. Each fast pass
`acc += speed * dt`; while `acc` covers the next step's length (`OPCOM_GRID_CELL`, or `* sqrt 2`
diagonal), pop the next cell off the route chain and subtract it. A slow infantry crosses one cell over
several passes; a fixed-wing pops many cells in one pass. Position stays a pure cell for streaming, force
deposit and routing; the accumulator is motion bookkeeping only. Water is handled in the route, not per
step — a ground route never contains a water cell ([§Routing](#routing-a-cost-field-over-the-grid)).

Persisted state is the cell, the target and the route mode — all numbers, so a virtualised tasking
serialises with its order ([§Persistence](#persistence)). The accumulator resets to 0 and the chain
recomputes on load.

### The virtualisation boundary

A tasking unvirtualises — spawns as a native A3 group — when its cell closes to within **K cells**
(Chebyshev, `max(abs(dx), abs(dy))`) of any player's cell. Inside the ring the group is real, the engine
owns its pathfinding, and the tasking issues its order *best-effort*.

**K is per unit type, not one ring** (tune in play) — each type's render range in cells. The streaming
check runs on the fast base pass against live player cells, so the margin against a fast player comes
from the loop rate, not a fat ring: even a 200 km/h player crosses ~half a cell between passes and is
caught before contact.

| Unit type | K | ≈ real |
|---|---|---|
| Infantry | 1 | 500 m orthogonal, ~700 m diagonal |
| Wheeled | 2 | ~1–1.4 km |
| Tracked | 2 | ~1–1.4 km |
| Rotary | 5 | ~2.5–3.5 km |
| Fixed wing | 8 | ~4–5.5 km |

**Hysteresis.** A live group stows back to a cell once it passes `K + 1` cells from every player — one
full cell of margin so a group on the edge cannot flicker — whether or not it has fired.

The boundary is a square ring in cell space, so a tasking on the diagonal streams in ~1.4x further than
orthogonally — acceptable for spawn-before-contact.

### Spawn posture follows the order

- A **move order** — patrol, supply, rapport — spawns in `SAFE`/`AWARE` and drives or walks to its
  objective.
- A **combat order** — QRF, assault — spawns in `AWARE` with a Seek & Destroy waypoint on the target.

Set the posture at spawn, not a tick later.

## Playbook: coordinated multi-unit plays

A play commits several units in named roles and runs a fixed phase sequence off their status. It is a
composite intent ([§Commitment](#commitment-intents-are-sticky)) and a scored candidate like any sink;
the influence grid carries the spatial work, the play sequences the coordination. Plays are an authored
list — a new play is an entry, like an archetype
([§The commander has an archetype](#the-commander-has-an-archetype)); there is no planner.

### The play record

The composite intent extends the §Commitment record with two fields:

| Field | Holds |
|---|---|
| roles | array of `[role, unitRef, status]` bindings |
| phase | index into the play's phase list |

`type` is the play id (`flank` / `encircle` / `arty_saturation`); `target` is the objective cell.

### Candidacy, scoring, mustering

- A play enters the candidate set only when it *applies*: the force-ratio band fits
  ([§Action follows the force ratio](#action-follows-the-force-ratio)), enough roles are fillable from
  the roster, and the geometry holds.
- Scored on the five terms, archetype-weighted, picked by the same weighted-random as any sink
  ([§Weighted random over the top few, not the best](#weighted-random-over-the-top-few-not-the-best)).
- Committing binds roles from the roster. Short a role, the play commits in `mustering` and waits —
  buying or pulling the missing unit — before its first phase ([§Commitment](#commitment-intents-are-sticky)).

### The roster

The free-unit pool: live groups and virtualised taskings whose intent is released — never assigned, or
an order or play completed. A unit bound to a play leaves the pool and returns on the play's end or
abort. One unit, one owner.

### The play-runner

One generic stepper, on the strategic phase:

1. Refresh each bound unit's status ([§Unit status](#unit-status)).
2. A required role `dead` or lost → **abort**: release surviving units to the pool (an engaged survivor fights its contact to a decision, a clear one re-virtualises), no AP refund.
3. Otherwise advance `phase` when the current phase's transition predicate holds — predicates read child
   status and geometry, nothing else.
4. Last phase complete → done, release the units.

The runner sequences phases only; bound units move by the route and streaming machinery
([§Routing](#routing-a-cost-field-over-the-grid),
[§Movement](#movement-a-tasking-is-virtualised-until-contact)), it does not path.

### The three plays

| Play | Applies | Roles | Phases (→ on transition) |
|---|---|---|---|
| `flank` | ratio 1–2, ≥2 mobile groups, a reachable flank cell | `fix` ×1, `maneuver` ×1+ | form (fix → frontal, direct route; maneuver → flank cell, λ route) → *(fix `engaged`)* assault (maneuver S&D from the flank) → resolve |
| `encircle` | friendly force leads across the ring of cells around the target, ≥3 mobile groups, target in a pocket (few escape cells) | `blockers` ×N (one per escape corridor), `crushers` ×1–2 | deploy (blockers → corridor cells) → *(blockers in position)* seal → crush (crushers assault inward) → resolve |
| `arty_saturation` | a battery/mortar off cooldown, an observed `ene`-high cell, not the HQ circle | `guns` ×1–3, `spotter` ×0–1 | mark (spotter holds observation) → salvo (guns concentrate on the one cell, K rounds) → assess (cell force dropped? re-fire : done) |

- **Escape corridors** (`encircle`): the target cell's neighbours whose enemy-influence gradient points
  outward toward BLU-held ground — the routes out. Blockers occupy them; crushers collapse inward once
  sealed.
- **Saturation** (`arty_saturation`): concentrates several guns on one cell rather than one gun per
  target, over the existing fire-mission machinery and caps
  ([§Indirect-fire hardpoints](#indirect-fire-hardpoints),
  [§Observation is the trigger](#observation-is-the-trigger)).

| Constant | Value |
|---|---|
| `OPCOM_PLAY_TIMEOUT` | per-play deadline before abort (tune) |

## The loop against the engine

One thread, a phase counter splitting two cadences, not one thread per sink.

| Property | Value |
|---|---|
| Fast base pass | ~2-5 s. Advance in-flight taskings (accumulator + cell pop), refresh live-group status ([§Unit status](#unit-status)), run the streaming check against live player cells ([§Movement](#movement-a-tasking-is-virtualised-until-contact)). Cheap only — no scoring, no routing search |
| Strategic phase | every 12-18 base passes (60-90 s). Refresh belief, rebuild the grid, advance live plays ([§Playbook](#playbook-coordinated-multi-unit-plays)), score, commit at most one thing, recompute routes due for it. The sinks keep their own cooldowns |
| Scoring pass | inside `isNil { ... }` — unscheduled, runs uninterrupted. `server/init_zones/fnc_moreUrban_locations.sqf:126-138` is the worked example, bounded by a wall-clock deadline. The route search runs outside it |
| Clock | `time` — intent expiries and belief stamps must survive a savegame |
| Orders | server-local groups only — waypoints are silently ignored unless the group is local to the issuing machine |
| State | numbers, strings, arrays of those — no group or object handles near the mission namespace |

No `sleep` inside the `isNil` block — unscheduled code cannot suspend. Constants take the `#define`
form the zone and town garrisons use.

## What the commander spends on

> **Built today: the town-garrison ladder only** — the AP tier rungs and the per-tier garrison each
> town fields ([§Town garrisons](#town-garrisons-i-through-iv)). A standalone fortification director also
> shipped but is now disabled ([§What the commander builds](#what-the-commander-builds)). The tasking
> menu and the appraisal that arbitrates the sinks are not yet built.

The four sinks Army Power buys, the archetype that weights the split, and the garrison ladders on both
sides. The director here, the hardpoint director ([§What the commander builds](#what-the-commander-builds)),
and the turned-town behaviour are one actor sharing `WARCOM_opfor_ap`: build, tasking and garrison
compete in the one appraisal ([§Appraisal](#appraisal-utility-scoring-not-search)) — no sink runs on its
own clock, and none spends `WARCOM_opfor_ap` unarbitrated. The wallet and its faucets are the economy's
([`economy_second_pass.md`](economy_second_pass.md#army-power)).

Director spends call `fnc_ap_adjust` directly, as `["OPF", -_cost, _reason] call fnc_ap_adjust`. The
director is server-side and single, so there is no writer to race.

| Sink | Effect | Throttled by | Saturates? |
|---|---|---|---|
| Town garrison upgrade | Raises the purchased tier of one town | Tier ceiling of IV times the towns in the OPFOR band | Yes |
| Tasking order | Gives a newly spawned squad a job | The rate squads spawn at | No |
| Hardpoint construction | Builds an emplacement | One build attempt every 20-30 min | No, but capped at one purchase per tick |

**Random events are not a sink.** IEDs, ambushes and sabotage out of a low-reputation town fire on
their own, rolled against reputation, and cost the commander nothing
([§Random events](#random-events-what-a-turned-town-does)).

Every sink is rate-limited and none absorbs a surplus. A commander that out-earns all three banks the
difference ([§Open questions](#open-questions)).

Taskings spawn only from OPFOR-held ground — a held zone today, the planned OPFOR FOB hardpoint once
it exists — never on demand beside the player. Taking the zone cuts the squads it was launching.

| Tasking | Job |
|---|---|
| QRF | Respond to contact, under a commander that decides whether to spend the reserve |
| Supply | Move between held towns and zones, restoring garrison strength en route |
| Rapport | Occupy a town and drag its reputation toward OPFOR |
| Intel patrol | Sweep for BLUFOR and report what it finds, feeding target selection |

Intel patrol is the weak one — cheap, buys knowledge not force, and goes looking for the player.
`reveal` against EAST is the mechanism.

Rapport moves a town's reputation; the random-event sink spends the reputation a town already has.

**A tasking's force is a token composition.** Drawn from the same `posture:token` vocabulary the
garrisons use ([§What the commander builds](#what-the-commander-builds)) — an array of tokens like
`team` or `car`, resolved by `DUWS_fnc_tokenClass` against the shared roster. The commander chooses
from a menu of compositions per tasking; the exact rows are unset, tuned in one place, never hardcoded
at a spawn site.

### The commander has an archetype

One archetype rolled per campaign, deciding how the director splits income across the sinks.

| Archetype | Spends toward |
|---|---|
| Defensive | Town garrisons and hardpoints; fortifies what it holds |
| Balanced | No strong lean — the baseline the others are tuned against |
| Aggressive | Taskings, especially QRF and rapport; projects force, leaves ground thin |

A single authored list. Further leans — indirect fire, armour — become entries in it.

- **Weights, not switches.** An archetype biases the roll via `selectRandomWeighted`; it never removes
  a sink.
- **It cannot override the ladder.** An Aggressive commander with no armour tier reached fields no
  armour. Archetype decides what the enemy buys, never what it may buy.
- **It is not difficulty.** `opfor_ai_skill` sets how well the enemy shoots.

Rolled once at WARCOM init, never re-rolled — campaign state, in the persistence snapshot.

### Town garrisons: I through IV

Towns gain purchasable garrisons on both sides, benchmarked against a zone garrison (fortified groups
with a squad leader each, occupied buildings, nearby guard towers). Zones carry a tier of their own,
rolled at generation ([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#zone-tiers)).
Towns and zones draw from one token vocabulary but keep separate composition sets.

Both sinks reach both kinds of ground — the commander upgrades and reinforces zones as it does towns.
A retaken zone is floored to `0.3` so there is something to buy back
([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#zone-tiers)).

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
([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv)).

- **Reputation decides whether a town garrisons; AP decides how hard.** Crossing `-10` writes tier I.
- **Clearing a town drops the tier to I, not 0, with no refund.** The director must spend again to
  restore it, and cannot for the three hours the town spends regrouping
  ([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#what-clearing-a-garrison-actually-buys)).
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
([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#blufor-inherits-nothing)).

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
([`info/opfor_area_of_influence.md`](../info/gameplay/opfor_area_of_influence.md#band-siting)) — on its
own clock in a fixed priority order, with no appraisal. Its spawn is cut (the file and compile stay), to
be re-driven through the appraisal so build competes with tasking and garrison for the wallet. Nothing
scales garrison size to `WARCOM_opfor_ap`
([`info/hardpoints.md`](../info/gameplay/hardpoints.md#streaming-and-garrison)). Hardpoints otherwise
generate at scenario init only.

**The director builds to need.** It sites a build by reading the influence grid
([§The influence grid](#the-influence-grid-one-spatial-substrate)): a believed BLUFOR build-up — a
cell whose belief-store magnitude has climbed — pulls fortification toward the pressure; a gap in its
own line — a front-contour stretch thin on friendly influence — pulls it toward the hole. This is the
same `[sink, target]` score the appraisal runs; a build's *target* is a site, its threat and
vulnerability terms are the "need".

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
([`info/composition_tooling.md`](../info/architecture/composition_tooling.md)).

**Both columns key off the highest AP the enemy has reached, never its current balance** — a vehicle
token is gated on `WARCOM_opfor_ap_earned`, the earned high-water counter, not the spendable wallet
(`fnc_zone_spawn_sizes.sqf:107-108`). The hardpoint tier reads the same counter.

| Knob | Value |
|---|---|
| Seed subset | 2-3 at WARCOM init, any type |
| Build tick | one candidate every 20-30 min |
| Build gate | OPFOR AP above 10 |
| Build costs | 8-25 AP by type — cheapest for an OP or MG nest, dearest for the battery |
| Live cap | none — live AI is bounded by player proximity ([`info/hardpoints.md`](../info/gameplay/hardpoints.md#streaming-and-garrison)) |
| Clear pays | CP only (`fnc_mission_reward.sqf:35`, `fnc_captured.sqf:39`) |

## Indirect-fire hardpoints

Persistent enemy assets that act on the campaign. Two tiers sharing one fire-mission implementation.
None of the fire missions ships today — the mortar and artillery cores exist as clearable emplacements
([`info/hardpoints.md`](../info/gameplay/hardpoints.md#hardpoint-types)) but run no missions.

A zone's own mortar is separate and stays as it is: several zone prefabs site a tube that
`fnc_static_resolve` turns into the holding faction's mortar, crewed by the zone's manning pass, firing
on the engine's judgement, not counted against the caps below.

`doArtilleryFire` must be issued from the machine where the gun is local; both are server-spawned, so
the server issues it — the same locality rule that broke `fnc_helolift`
([`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)).

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
([`info/hardpoints.md`](../info/gameplay/hardpoints.md#clearance)); the recycle station pays for it
(`fnc_activateBaseRecycleStation.sqf`, an ownership-free faucet in
[`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#campaign-loop)).

Applies to both:

| Property | Rule |
|---|---|
| Target set | BLU-held zone centres, FOB positions, players in the open, each only while observed. **Never** aimed inside the 100 m HQ circle |
| Range gate | `_gun inRangeOfArtillery [[_pos], _mag]`, and nothing else |
| Willingness | a roll per opportunity ([§Chance to fire](#chance-to-fire)) |
| Accuracy | deliberate scatter, scaled by range and observation quality ([§Scatter](#scatter)) |
| Ammo | finite (`setVehicleAmmo`); a gun that runs dry goes quiet |
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

A gun off cooldown with a valid observed target rolls rather than firing on a schedule — roughly 40 %
for a mortar pit, 30 % for a battery, evaluated every five minutes. The cooldown starts only when a
mission fires. The telegraph (radio line + marker) is required. Finite ammo gives an OPFOR resupply
run an interdiction target.

**Fallback if AI static-mortar fire proves unreliable:** spawn the shells directly, as the player's
own artillery support does (`client/supports/fnc_arty.sqf` creates rounds at 800 m altitude with
downward velocity). Player-facing behaviour is identical; the gun becomes scenery. Try the real gun
first ([§Open questions](#open-questions)).

### The indirect-fire types are capped campaign-wide

**One artillery battery and two mortar pits alive at once, across the whole map.** The cap spans both
flavours — a zone that rolls a mortar pit consumes one of the two. Clearing one frees its slot. Not
enforced today ([`info/hardpoints.md`](../info/gameplay/hardpoints.md#hardpoint-types)); lands with the
fire missions. These are the only hardpoints with permanent crews — three guns is ~six units that
never despawn.

**If AA is ever made resident, it needs its own cap.** The shipped AA streams like any other type,
waking early on a 5,000 m air ring
([`info/hardpoints.md`](../info/gameplay/hardpoints.md#streaming-and-garrison)); pinning it resident
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
  it over Allseer — the germ of the Supply tasking.

The director must not reproduce their shape: routes closed with a `CYCLE` and never despawned, cadence
was unconditional, AP was read but never spent (a one-way ratchet), and they sited spawns >1500 m from
every player so contact only happened when the player drove into them.

## Random events: what a turned town does

A turned town — reputation `<= -10`, inside the OPFOR band — acts against the player on its own: IEDs
on approach roads, ambushes on passing patrols, sabotage against nearby FOBs. Free, rolled off
reputation, planned outside the town's presence trigger so it can mine a road ahead of the player.

## Persistence

The campaign snapshot ([`campaign_persistence_plan.md`](campaign_persistence_plan.md)) is planned, not
shipped — persistence today is the engine's `saveGame`. Live squads, spawned garrisons and in-flight
fire missions are never saved; they regenerate on player approach.

| State | Kind | Contract |
|---|---|---|
| Archetype | input | The one string rolled at OPCOM init. Restore feeds it back before the loop runs, never re-rolls ([§The commander has an archetype](#the-commander-has-an-archetype)) |
| Standing orders (taskings) | outcome | One row per order — type, target, route mode, current cell, budget spent. Persisted as the order and its virtualised cell, never a live squad: restore resumes the tasking at its cell (accumulator 0, chain recomputed [§Routing](#routing-a-cost-field-over-the-grid)) and it streams to a live group on player approach |
| Tiers | outcome | `WARCOM_opfor_tier` and its earned counter, owned by [`economy_second_pass.md`](economy_second_pass.md#the-ratchet-is-otherwise-structural-and-only-in-half-the-read-sites); the archetype rides beside them |

Every persisted field is a number, a string, or an array of those. Time-based fields store on `time`
and are written as remaining durations, never absolute stamps
([`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

Whether the belief store persists is open ([§Open questions](#open-questions)); it is shaped to
serialise, so a restored campaign that omits the key rebuilds belief from its first sensor pass. Belief
ages in strategic ticks ([§Decay](#decay)), so the tick counter persists with the store when it does —
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
| **The loop** | One thread, the two cadences (fast pass + strategic phase), the five terms and the force-ratio bands, two sinks (garrison upgrade and hardpoint build), flat archetype weights | Belief + grid |
| **Intents** | The record, minimum lifetimes, release on completion or death | The loop; lands with the third sink (taskings) |
| **Movement** | Virtualised taskings — cell-stepping with the accumulator, cost-field routing (direct/flank λ), cell streaming (Chebyshev K + hysteresis), the unit-status read | Grid + Intents |
| **Archetype** | The weight sets from [§The commander has an archetype](#the-commander-has-an-archetype) | The loop it modifies |
| **Playbook** | The composite intent, the roster, mustering to fill roles, the generic play-runner, the three plays | Movement, unit status, the grid, and the indirect-fire missions (`arty_saturation`) — lands last |
| **Random events** | The rebuilt hostile-conversion and IED/ambush/sabotage behaviours | The belief store and the OPFOR-band definition the loop establishes |

## Open questions

- **The tick interval against the sink cooldowns.** A 60-90 s tick against a 20-30 min build tick
  means the commander's reaction time to a sighting is set by whichever sink it wants. Whether QRF
  needs a faster path than the shared tick is a play question.
- **Whether the belief store should persist** ([§Persistence](#persistence)).
- **What a co-op session does to the sighting sweep.** One call per player, the belief array grows one
  entry per player. The merge is resolved by [the influence grid](#the-influence-grid-one-spatial-substrate):
  its enemy layer sums every entry in a cell, so the strength term reads force-at-a-place whether four
  players or one stand there.
- **Whether the player can perceive that the enemy is acting on stale information**, and whether that
  is worth surfacing. The intel system is the obvious route.
- **Whether an AI gunner in a static mortar or a self-propelled gun reliably executes
  `doArtilleryFire`.** Nothing in the mission has ever issued it — `doArtilleryFire`,
  `commandArtilleryFire` and `inRangeOfArtillery` appear nowhere in the tree. Verify with a throwaway
  console test before writing the indirect-fire missions; if no, the shell-spawn fallback
  (`client/supports/fnc_arty.sqf`) becomes the implementation.
- **Whether the player can learn the commander's archetype, and how** — the intel system
  ([`info/intel_system.md`](../info/gameplay/intel_system.md)), or observed behaviour.
- **What the commander does with a surplus.** Two absorbers: reinforcing a garrison rather than
  upgrading it, and mustering — an assault intent that keeps buying force while it waits to clear its
  commit bar ([§Commitment](#commitment-intents-are-sticky)). Town events cannot be it — they are free
  and rep-driven.
- **Whether the commander should be required to spend** rather than merely able to.
