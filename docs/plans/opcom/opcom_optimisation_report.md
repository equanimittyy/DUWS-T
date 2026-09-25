# OPCOM optimisation report

This report covers the OPCOM tick (`warcom/opcom/belief/fnc_opcom_perception_run.sqf`) and everything it calls: the
belief stages, the grid rebuild, the tasking step, the attack runner and the pick. It was read out of the source and
checked against one play-test on Altis with 4 zones, 19 towns, about 10 hardpoints at the start and one player, with
the OPCOM debug overlay open. The road-graph fix for the convoy search (`server/convoy/fnc_convoy_graph.sqf`) landed
after that play-test, so the 15-128 s picks it caused are excluded from every figure below. The general rules the
findings apply are in [`performance.md`](../../info/architecture/performance.md#an-opcom-stage-costs-what-changed-not-what-exists).

Every cost below grows with the zone, town and hardpoint counts. The play-test campaign sits at the small end of what
the mission generates, so a full-size campaign multiplies each figure rather than adding to it.

## What the play-test measured

The DEBUG line times each stage of the tick in wall milliseconds. The quiet column is the first fifty ticks, before the
commander bought anything; the play column is the hour's next sixty, once it was hiring, building and shelling.

| Stage | Quiet | In play | What it runs |
|---|---|---|---|
| `sense`, `decay`, `prune` | 0-1 | 0-1, one `decay` of 152 | belief sensors and ageing |
| `patrol` | 0-2 | 0-2, one of 97 | cover stamps and recon sweeps |
| `opsense` | 0-1 | 0-1, spikes of 59 and 174 | OP post bursts |
| `contested` | 0 | 0-1, spikes of 49-209 | site contest from belief |
| `grid` | 0-2 (1157 on the first tick) | 35-360 | force grid rebuild |
| `taskstep` | 0-2 | 30-211 | movement, streaming, status |
| `attacks` | 0 | 0-1, spikes of 56-521 | attack runner |
| `need` | 0 | 0-2, one of 39 | need field signature check |
| `pick` | 0 | 430-6000 | siting, the targets pass, the execute |
| `intel` | 0 | 0, one of 85 | the Intelligence Center roll |

The tick period is 5 s nominal (`OPCOM_TICK_PERIOD`) and it measured 5-9 s in play: the sleep follows the work, so the
work is added to the period.

Three things decide how to read a figure.

- **A scheduled figure is wall time, not CPU time.** Every scheduled script on the host shares about 3 ms per frame
  ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)).
  At the 19 fps the play-test ran at, that is under 60 ms of script time per second for all of them, so a stage that
  needs 50 ms of CPU can read as a second of wall time. Uniform inflation across stages is the contention signature:
  on the tick that read `contested=209 grid=211 taskstep=211`, a need-field rebuild was running in its own thread.
- **The pick's targets pass is unscheduled**, inside `isNil { }` (`warcom/opcom/appraisal/fnc_opcom_pick.sqf:16-23`).
  Its wall time is frame time: a 300 ms pass is a 300 ms frame. The PERF line's minimum frame rate dropped to 5-7 fps
  in four of the play minutes.
- **The debug overlay was open**, so `fnc_debug_opcom_grid` gathered all 2852 box cells and sent them to the client
  every 5-6 s for the whole session. That is a contention source the shipped mission does not carry.

## Findings

Ranked by expected gain per unit of work. Each names the mechanism, the evidence, the fix and what it should change.

### 1. Split the pick timer, and count frames per stage

The `pick` figure lumps three things of different nature: the siting pass (scheduled,
`warcom/opcom/appraisal/fnc_opcom_siting.sqf:29-75`), the targets pass (unscheduled, `fnc_opcom_pick.sqf:16-23`) and
the execute (scheduled, `fnc_opcom_pick.sqf:89`, which hires and routes). A Bank pick executes nothing, and it measured
430 ms, 741 ms, 1072 ms and 1805 ms, so the first two parts alone cost that much; which of the two, the line cannot
say.

**Fix.** Time the three parts in `fnc_opcom_pick` and print them on the DEBUG line, and beside every stage's
milliseconds print the frames it spanned (`diag_frameNo` delta). A stage with a large wall figure over many frames is
scheduled work or contention; one over zero or one frame is a frame stall. This is the one finding the rest depend
on: it turns the estimates below into measurements.

### 2. The need field rebuilds on every hardpoint build, at 6-13 s each

`DUWS_fnc_opcom_needSig` (`warcom/opcom/appraisal/value/fnc_opcom_need.sqf:27-35`) includes every OPFOR hardpoint key,
so a mortar pit, an OP post or a minefield the commander builds changes the signature and `DUWS_fnc_opcom_needRefresh`
spawns a full rebuild. The play-test rebuilt five times in eleven minutes, at 6.1 s, 9.5 s, 6.3 s, 13.5 s and 9.6 s
of wall time, and every other stage inflated while each one ran.

The band test is what costs: `DUWS_fnc_opcom_needBuild` runs `fnc_aoi_field_at` and `fnc_aoi_in_any_zone` over every
land cell in the box (`fnc_opcom_need.sqf:66-75`). A hardpoint that is not a radio tower changes no coverage, only the
deposit it spreads (`:53-58`), and a spread is 49 cell writes.

**Fix.** Split the signature: a band signature (BLUFOR zones, FOBs, the HQ, banded towns, radio tower keys) and a
deposit signature (the band signature plus every OPFOR hardpoint key). A deposit-only change keeps
`DUWS_opcom_bandCells` and re-runs only the spreads and the band base add. That removes four of the five rebuilds seen,
and the fifth becomes finding 3's.

### 3. Coverage is asked point by point; rasterise it once

`DUWS_fnc_aoi_covers` (`warcom/fnc_aoi_init.sqf:17-58`) answers one point by walking every emitter: a `findIf` over
the hardpoints, a `findIf` over the zones that re-resolves each zone's owner with an inner `findIf` over the BLUFOR
list, the FOB list, and a loop over the towns with a `getPos` per Location. Nothing in it is cached, and OPCOM asks it
thousands of times a tick:

| Caller | Queries | When |
|---|---|---|
| the need band test (`fnc_opcom_need.sqf:70`) | two per land cell in the box, about 2800 cells | each rebuild |
| `DUWS_fnc_opcom_gunShare` (`value/fnc_opcom_gun.sqf:6-23`) | 81 per gun Value, up to 16 gun Values a tick | each siting pass while the memo is cold |
| `DUWS_fnc_opcom_towerValue` (`value/fnc_opcom_tower.sqf:18-26`) | one per town, and the town list is rebuilt per sample cell | each siting pass |
| `DUWS_fnc_opcom_rapportOffer` (`fnc_opcom_buy_holding.sqf:81`) | one per town | each pick, unscheduled |
| `DUWS_fnc_opcom_qrfSweep` (`fnc_opcom_commit.sqf:166`) | one per sighting | each pick, unscheduled |

The siting memo (`fnc_opcom_siting.sqf:53-55`) keys by band cell, warms eight random cells a tick out of about 580,
and resets whenever the need signature or the type's asset list changes, which is what a landed build does. In a
campaign that builds, it is cold most of the time. That is why the pick cost 700-2500 ms on ticks with no belief, no
BLUFOR ground and so no attack, QRF, probe or fire targets to score.

**Fix.** Keep a coverage layer per side on the grid, built per emitter: stamp each emitter's disc onto the layer with
the bounded loop `DUWS_fnc_opcom_deposit` already uses (`belief/fnc_opcom_grid_sources.sqf:8-26`). That is emitters
times disc cells, a few thousand writes, against cells times emitters today. Rebuild it in the need thread on the band
signature from finding 2, and read it at one index per query from the band test, `gunShare`, `towerValue`,
`rapportOffer` and `qrfSweep`. The layer is 500 m coarse where the point query is exact; the band test and `gunShare`
already sample cell centres, and for a town centre or a sighting the answer changes only at a band edge.
`DUWS_fnc_opcom_buildCand` (`taskings/fnc_opcom_deliver.sqf:14`) runs once per build off the tick and keeps the exact
call. With the layer, a rebuild falls from seconds to the spreads alone, and the siting pass stops paying for a cold
memo.

### 4. A patrol's swept cells are gathered with `pushBackUnique`

`DUWS_fnc_opcom_patrolCells` (`value/fnc_opcom_patrol.sqf:21-35`) samples the straight line every 250 m, then for each
line cell inserts its k-block into the result with `pushBackUnique`. Each insert scans the whole result, so the cost
is quadratic in the swept cell count: a 10 km line at k 3 inserts about a thousand cells into a set of a few hundred.
`DUWS_fnc_opcom_patrolSweep` (`fnc_opcom_commit.sqf:214-248`) runs it once per distinct start cell and reach for each of
eight destinations, inside the unscheduled pass. It is the largest single term suspected in that pass; finding 1
confirms or clears it.

**Fix.** Collect the cells in a hashMap keyed by cell index and return its keys, so an insert is constant time. The
line sampling and the k-block stay as they are.

### 5. The grid A* keeps its frontier in a flat list

The cell-chain branch of `fnc_opcom_route` (`taskings/fnc_opcom_route.sqf:97-146`) has the shape the road search had
before the road-graph fix: it initialises two full-grid arrays of 3844 cells per call (`:97-99`), takes the next node
by a linear scan of the open list (`:116`) and tests membership with `find` (`:137`). It runs for every infantry, air
and boat order (`fnc_opcom_task.sqf:98`), every replan when a route empties (`fnc_opcom_movement_core.sqf:24`), every
cell a QRF's sighting moves (`fnc_opcom_intercept.sqf:39`), twice per lift bind (`appraisal/fnc_opcom_lift.sqf:82-83`),
per taxi bind (`fnc_opcom_taxi.sqf:61`) and for the off-road tail of a threat-priced road route (`fnc_opcom_route.sqf:37`).
A route at lambda above 0 opens far more cells than a direct one, and every attack launch routes each of its units in
one tick.

**Fix.** The road search's heap, with a visited flag per cell and the cost and predecessor maps kept sparse, so a
call no longer pays the full-grid initialisation. Scheduled work, so the gain is tick wall time, not frame time.

### 6. The grid stage re-prices every awake site from live objects each tick

`fnc_opcom_grid_rebuild.sqf:51-54` deposits each awake site at `DUWS_fnc_garrisonForce`
(`garrison/fnc_garrison_strength_init.sqf:74-80`) every tick. That walks the ledger with a quadratic `spawnDiff`,
counts the live roster with a `getVariable` and a team-row lookup per man, and prices the centre statics by walking the
whole composition with `alive` and `isKindOf` per object (`belief/fnc_opcom_force.sqf:122-139`), which is 65 or more
objects for a deployed zone. The cost follows the size of the sites near the player, not what changed on them; the
grid stage read 35-360 ms in play against 0-2 ms on a quiet map, most of that contention, some of it this.

**Fix.** Cache the static force per key while the site is deployed and clear it from a Killed handler on the pinned
statics, which `fnc_duws_keep` already pins; recompute the men from the roster, which is the part that changes.

### 7. Per-pick work that repeats the same reads

Each of these is small and none is the bottleneck; together they are a steady share of the unscheduled pass.

- `DUWS_fnc_opcom_freeSource` (`appraisal/fnc_opcom_sources.sqf:55-59`) prices each free unit's commit cost with a site
  read and a nine-cell block sum, and seven sweeps rebuild the same rows each pick (`fnc_opcom_commit.sqf:51`, `:160`,
  `:216`, `:272`, `:311`, `fnc_opcom_lift.sqf:32`, `fnc_opcom_supply.sqf:9`). One `tickCached` key holds them.
- `DUWS_fnc_opcom_zoneSlotsUsed` (`fnc_opcom_buy_build.sqf:10-13`) counts the hardpoint registry per zone, for every
  zone, in each of the five zone-build rows. `DUWS_fnc_opcom_hpSweep` (`fnc_opcom_assets.sqf:17-40`) walks the same
  registry once a pick and can return the per-zone counts.
- `DUWS_fnc_opcom_zoneFortifyTargets` (`fnc_opcom_buy_holding.sqf:35-39`) diffs two spawn lists per open zone per pick,
  each a token-class resolution per token. The result depends only on the tier, the multiplier and the earned AP;
  memoise it as `DUWS_fnc_opcom_tierForce` does (`value/fnc_opcom_holding.sqf:24-41`).
- `DUWS_fnc_opcom_rosterSweep` (`fnc_opcom_sources.sqf:27-29`) resolves a token class, faction pick included, for every
  menu row per pick. The open set changes only when the earned AP crosses a rung or a toggle flips.
- `DUWS_fnc_opcom_batteryPieces` (`taskings/fnc_opcom_fires.sqf:20-25`) reads config per gun on every call, and
  `DUWS_fnc_opcom_fireTargets` asks two or three times per battery per pick. Mortars and batteries never stream, so the
  piece list holds while the composition stands.
- `fnc_zone_key` formats a string per call and sits inside `findIf` loops: `fnc_zone_bluforHeld` formats every BLUFOR
  zone key per call (`init_zones/fnc_zone_state_init.sqf:114-117`), and `DUWS_fnc_opcom_zonesOpenSweep`,
  `DUWS_fnc_opcom_zoneLabel` and `DUWS_fnc_opcom_fireClear` call it per zone per candidate. A key-to-index map built
  once a tick removes the formatting.
- `DUWS_fnc_hardpointOPBurst` (`init_zones/fnc_hardpoint_stream.sqf:253-258`) filters `allUnits` per OP post that
  fires, the scan shape [`performance.md`](../../info/architecture/performance.md#the-pattern-that-costs-the-most-timed-scans-anchored-on-allunits)
  rules against; `nearEntities` on the post's position answers the same question off the spatial index.

### 8. Small and pervasive: the play box through `missionNamespace`

`DUWS_fnc_opcom_w2c` and `DUWS_fnc_opcom_blockCells` (`belief/fnc_opcom_grid_coords.sqf:9`, `:27`) read
`DUWS_opcom_box` through `missionNamespace getVariable` with a default array on every call. They are the innermost
calls of the whole appraisal, tens of thousands of calls a pick. `DUWS_opcom_box` exists from `fnc_opcom_grid_init`
on, and `DUWS_fnc_opcom_deposit` already reads it directly (`fnc_opcom_grid_sources.sqf:13`). A guard on the one call
site that can run before init is cheaper than the lookup on all of them.

### 9. The tick period stretches under load

`fnc_opcom_perception_run.sqf:82` sleeps `OPCOM_TICK_PERIOD` after the work, so the period is the work plus 5 s; in
play it measured 5-9 s. `DUWS_fnc_opcom_advance` (`fnc_opcom_movement_core.sqf:32`) moves a virtual unit one cell per
`DUWS_opcom_speed` ticks, so its ground speed falls by the same ratio, and every tick-counted span (`OPCOM_COMMIT_HOLD`,
the muster expiries, belief ageing) stretches with it. This is a consequence of findings 1-5, not a separate fix: a
shorter sleep under load would add load.

### 10. The plan names a pick deadline the code does not have

[`opcom_plan.md` §Appraisal](opcom_plan.md#appraisal-phase-4) says the targets pass runs "under a wall-clock budget,
`OPCOM_SCORE_DEADLINE`". No such constant exists, and `fnc_opcom_pick` enumerates every row unbounded. A deadline
would hide the cost rather than remove it, and a pass cut short biases the draw toward the rows enumerated first.
Once finding 1 shows the pass fits a frame, drop the sentence from the plan.

## Checked and dismissed

- **The sighting sweep** (`belief/fnc_opcom_sense.sqf`) batches `nearTargets` over `OPCOM_SENSE_BATCH` observers a
  tick and read 0-1 ms throughout.
- **`decay`, `prune` and `contested`** are linear over the belief rows or the site keys. Their 49-209 ms readings
  arrived on ticks where every stage inflated together, the contention signature.
- **The intel contact scripts** that the PERF line lists twelve to twenty of (`fnc_intel_contact_init.sqf x20`) are
  one `sleep DUWS_intel_contact_life` thread per plotted contact (`search/fnc_intel_contact_init.sqf:57-59`). They
  sleep; they do not poll.
- **`fnc_taskforce_tick`** exits on an empty task-force list, which is the whole play-test.
- **The DEBUG line's own grid scans** are gated on the log level (`fnc_opcom_perception_run.sqf:70`).
- **The class-power memo and the tier-force memo** already hold; nothing re-prices a class per tick.
- **The road search** is fixed by the road graph and the heap; the 15-128 s picks in the play-test predate it.

## Order of work

Finding 1 first, since it measures the rest. Then finding 2, the smallest change with the largest contention effect,
and finding 3, which finishes what 2 starts and pays into the siting pass and the unscheduled pass at once. Findings
4 and 5 follow once the split timer says which of the pass and the execute carries the time.
