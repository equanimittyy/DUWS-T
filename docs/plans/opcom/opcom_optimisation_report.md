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

The DEBUG line times each stage of the tick in wall milliseconds. The quiet column is the first fifty ticks, while the
AI mode was `off`, so the pick returned at once; the play column is the next sixty, after the mode was set to
`weighted`, once the commander was hiring, building and shelling. The quiet column therefore compares the commander
off with the commander on, not an idle commander with a busy one. Until about tick 68 the difficulty was 0.5 picks a
tick, so the play column's `pick=0` readings before it are ticks with no pick.

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
| `pick` | 0 | 430-6000 | siting, the targets pass, the ranking, the execute |
| `intel` | 0 | 0, one of 85 | the Intelligence Center roll |

The tick period is 5 s nominal (`OPCOM_TICK_PERIOD`) and it measured 5-9 s in play: the sleep follows the work, so the
work is added to the period.

Three things decide how to read a figure.

- **A scheduled figure is wall time, not CPU time.** Every scheduled script on the host shares about 3 ms per frame
  ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)).
  At the 19 fps the play-test ran at, that is under 60 ms of script time per second for all of them, so a stage that
  needs 50 ms of CPU can read as a second of wall time. Uniform inflation across stages is the contention signature:
  on the tick that read `contested=209 grid=211 taskstep=211`, a need-field rebuild was running in its own thread.
- **The pick's targets pass is unscheduled**, inside `isNil { }` (`warcom/opcom/appraisal/fnc_opcom_pick.sqf:31-43`).
  Its wall time is frame time: a 300 ms pass is a 300 ms frame. The PERF line's minimum frame rate dropped to 5-7 fps
  in four of the play minutes.
- **The debug overlay was open**, so `fnc_debug_opcom_grid` gathered all 2852 box cells and sent them to the client
  every 5-6 s for the whole session. That is a contention source the shipped mission does not carry.

## Findings

Each names the mechanism, the evidence, the fix and what it should change. The [plan of action](#plan-of-action) orders
the work.

### 1. Split the pick timer, and count frames per stage

The play-test's `pick` figure lumped four things of different nature: the siting pass (scheduled,
`warcom/opcom/appraisal/fnc_opcom_siting.sqf:29-75`), the targets pass (unscheduled, inside the `isNil` of
`fnc_opcom_pick.sqf`), the scoring and weighted draw (scheduled) and the execute (scheduled, which hires and routes).
A Bank pick executes nothing, and it measured 430 ms, 741 ms, 1072 ms and 1805 ms, so the parts before the execute
alone cost that much; which of them, the line could not say.

**Fix.** The DEBUG line now prints every stage as `ms/frames`, splits the pick into `site`, `targets`, `rank` and
`exec`, and times each action row of the targets pass that takes 1 ms or more
([`performance.md` §Reading the cost from a playtest](../../info/architecture/performance.md#reading-the-cost-from-a-playtest)).
The need-field rebuild line names the signature parts that forced the rebuild and the frames it spanned. This is the
one finding the rest depend on: it turns the estimates below into measurements.

### 2. The need field rebuilt on every hardpoint build, at 6-13 s each

In the play-test, the need signature included every OPFOR hardpoint key, so a mortar pit, an OP post or a minefield
the commander built changed it, and `DUWS_fnc_opcom_needRefresh` spawned a full rebuild. The play-test rebuilt five
times in eleven minutes, at 6.1 s, 9.5 s, 6.3 s, 13.5 s and 9.6 s of wall time, and every other stage inflated while
each one ran.

The band test is what costs: it runs `fnc_aoi_field_at` and `fnc_aoi_in_any_zone` over every land cell in the box
(`warcom/opcom/appraisal/value/fnc_opcom_need.sqf:66-75`). A hardpoint that is not a radio tower changes no coverage,
only the deposit it spreads (`:81-87`), and a spread is 49 cell writes.

**Fix.** The signature is split (`fnc_opcom_need.sqf:27-42`): a band signature (BLUFOR zones, FOBs, the HQ reveal,
banded towns, radio tower keys) and a deposit signature (every OPFOR hardpoint key). The zone spreads, the town
spreads and the band base add read only band-signature inputs, so `DUWS_fnc_opcom_needBandBuild` caches them with
`DUWS_opcom_bandCells`. A deposit-only change then re-spreads the hardpoint deposits over that cache inside the tick,
with no thread.

Of the five rebuilds seen, the first was the boot build on tick 1, and the second followed a radio tower, which moved
the band from 466 to 580 cells. The other three followed a mortar, an OP and a second mortar, and the split removes
them. The OP landed while the mortar's rebuild ran, so it forced a second full rebuild 14 s after the first.

The siting memo stamped with the whole need signature, so it also reset on every build. A mortar's, a battery's and
an OP's Value read only the area of influence and the assets of their own type, so their memos now stamp on the band
signature and their own assets (`fnc_opcom_siting.sqf:55`), and stay warm across the other builds. A radio tower's
Value multiplies by `DUWS_fnc_opcom_defend`, which reads every OPFOR hardpoint (`value/fnc_opcom_exposure.sqf:49`), so
its memo also stamps on the deposit signature.

### 3. Coverage is asked point by point

`DUWS_fnc_aoi_covers` (`warcom/fnc_aoi_init.sqf:17-58`) answers one point by walking every emitter: a `findIf` over
the hardpoints, a `findIf` over the zones that re-resolves each zone's owner with an inner `findIf` over the BLUFOR
list, the FOB list, and a loop over the towns with a `getPos` per banded town. Nothing in it is cached, and OPCOM
asks it thousands of times a tick:

| Caller | Queries | When |
|---|---|---|
| the need band test (`fnc_opcom_need.sqf:70`) | two per land cell in the box, about 2800 cells | each rebuild |
| `DUWS_fnc_opcom_gunShare` (`value/fnc_opcom_gun.sqf:6-23`) | 81 per gun Value, up to 16 gun Values a tick | each siting pass while the memo is cold |
| `DUWS_fnc_opcom_towerValue` (`value/fnc_opcom_tower.sqf:18-26`) | one per town, and the town list is rebuilt per sample cell | each siting pass |
| `DUWS_fnc_opcom_rapportOffer` (`fnc_opcom_buy_holding.sqf:81`) | one per town | each pick, unscheduled |
| `DUWS_fnc_opcom_qrfSweep` (`fnc_opcom_commit.sqf:166`) | one per sighting | each pick, unscheduled |

The siting memo (`fnc_opcom_siting.sqf:55-57`) keys by band cell and warms eight random cells a tick out of about
580. In the play-test it reset on every landed build, so in a campaign that builds it was cold most of the time. It
is the suspected cause of the 700-2500 ms picks on ticks with
no belief, no BLUFOR ground and so no attack, QRF, probe or fire targets to score. The patrol sweep and the buy rows
still ran on those ticks, so the `site` and `rows(…)` figures decide it.

**Fix.** After finding 2, the band test runs only when the band changes, and the gun memos stay warm across the
other builds. The callers left on every pick are `towerValue`, `rapportOffer` and `qrfSweep`. Two steps, smallest
first:

1. Build `towerValue`'s town list once per siting pass, not once per sample cell: 19 queries a pass, not up to 152.
2. For the OPCOM callers, flatten the emitters into one `[position, reach]` list per side, rebuilt on the band
   signature, so that a query is one `findIf` over that list. The answer stays exact, so `rapportOffer` and
   `qrfSweep` keep their behaviour.

A coverage layer per side on the grid comes after those two steps, and only if the `site` and `rows(…)` figures still
ask for it: stamp each emitter's disc with the bounded loop that `DUWS_fnc_opcom_deposit` uses
(`belief/fnc_opcom_grid_sources.sqf:8-26`), and read one index per query. The layer is 500 m coarse where the point
query is exact. The band test and `gunShare` sample cell centres, but a town centre or a sighting can read the wrong
side of a band edge. `DUWS_fnc_opcom_buildCand` (`taskings/fnc_opcom_deliver.sqf:14`) runs once per build off the tick
and keeps the exact call.

### 4. A patrol's swept cells are gathered with `pushBackUnique`

`DUWS_fnc_opcom_patrolCells` (`value/fnc_opcom_patrol.sqf:21-35`) samples the straight line every 250 m, then for each
line cell inserts its k-block into the result with `pushBackUnique`. Each insert scans the whole result, so the cost
is quadratic in the swept cell count: a 10 km line at k 3 inserts about a thousand cells into a set of a few hundred.
`DUWS_fnc_opcom_patrolSweep` (`fnc_opcom_commit.sqf:214-248`) runs it once per distinct start cell and reach for each of
eight destinations, inside the unscheduled pass. It is suspected as the largest single term in that pass; the
`patrol` row's figure confirms or clears it.

**Fix.** Append each k-block to the result, then remove the duplicates once with `_cells arrayIntersect _cells`, a
native call. A hashMap is not a sure gain: its insert is still one interpreted command per cell, where the scan in
`pushBackUnique` is native. The line sampling and the k-block stay as they are.

### 5. The grid A* kept its frontier in a flat list

In the play-test, the cell-chain branch of `fnc_opcom_route` (`taskings/fnc_opcom_route.sqf`) had the shape the road
search had before the road-graph fix: it filled two full-grid arrays of 3844 cells per call and took the next node by
a linear scan of the open list in SQF. It runs for every
infantry, air and boat order (`fnc_opcom_task.sqf:99`), every replan when a route empties
(`fnc_opcom_movement_core.sqf:24`), every cell a QRF's sighting moves (`fnc_opcom_intercept.sqf:39`), twice per lift
bind (`appraisal/fnc_opcom_lift.sqf:82-83`), once per lift execute (`:139`), per taxi bind (`fnc_opcom_taxi.sqf:61`)
and for the off-road tail of a bent road route (`fnc_opcom_route.sqf:40`). A route at lambda above 0 opens far more
cells than a direct one, and every attack launch routes each of its units in one tick.

**Fix.** The search takes the next node with `_openF find (selectMin _openF)`, and starts `_g` and `_from` as `+`
copies of `DUWS_opcom_routeBlank`, an array of -1 built once at grid init. Both are native, and the pop still takes
the first minimum, so routes are unchanged. The road search's heap is the wrong model here: a
heap written in SQF runs interpreted steps on every push and pop, and they lose to a native linear scan at open lists
of a few hundred cells. Scheduled work, so the gain is tick wall time, not frame time.

### 6. Per-pick work that repeats the same reads

Each of these is small and none is the bottleneck; together they are a steady share of the unscheduled pass.

- `DUWS_fnc_opcom_freeSource` (`appraisal/fnc_opcom_sources.sqf:55-59`) prices each free unit's commit cost with a site
  read and a nine-cell block sum, and eight call sites rebuild the same rows each pick (`fnc_opcom_commit.sqf:51`,
  `:160`, `:217`, `:273`, `:311`, `fnc_opcom_lift.sqf:33`, `:110`, `fnc_opcom_supply.sqf:10`). One `tickCached` key
  holds them.
- `DUWS_fnc_opcom_zoneSlotsUsed` (`fnc_opcom_buy_build.sqf:10-13`) counts the hardpoint registry per zone, for every
  zone, in each of the five zone-build rows. `DUWS_fnc_opcom_hpSweep` (`fnc_opcom_assets.sqf:17-40`) walks the same
  registry once a pick and can return the per-zone counts.
- `DUWS_fnc_opcom_zoneFortifyTargets` (`fnc_opcom_buy_holding.sqf:35-39`) diffs two spawn lists per open zone per pick,
  each a token-class resolution per token. The owed force depends only on the tier, the multiplier and which tokens
  the earned AP has unlocked (`DUWS_fnc_tokenLocked`); memoise it on those as `DUWS_fnc_opcom_tierForce` does
  (`value/fnc_opcom_holding.sqf:24-41`). The label and the hold value still vary per zone.
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

### 7. Small and pervasive: the play box through `missionNamespace`

In the play-test, `DUWS_fnc_opcom_w2c` and `DUWS_fnc_opcom_blockCells` (`belief/fnc_opcom_grid_coords.sqf:9`, `:27`)
read `DUWS_opcom_box` through `missionNamespace getVariable` with a default array on every call. They are the innermost
calls of the whole appraisal, tens of thousands of calls a pick. `DUWS_opcom_box` exists from `fnc_opcom_grid_init`
on, and `DUWS_fnc_opcom_deposit` already reads it directly (`fnc_opcom_grid_sources.sqf:13`).

**Fix.** `fnc_opcom_grid_init.sqf` set `DUWS_opcom_grid_w` before the box, with a town loop that can yield between
them; it now sets the box first. The coordinate functions require a caller to guard on `isNil "DUWS_opcom_grid_w"`
(`fnc_opcom_grid_coords.sqf:2`), so the five reads that had a default (these two, `fnc_opcom_route.sqf`,
`fnc_opcom_ports.sqf` and `debug/fnc_debug_opcom_grid.sqf`) read the box directly.

### 8. The tick period stretches under load

`fnc_opcom_perception_run.sqf:88` sleeps `OPCOM_TICK_PERIOD` after the work, so the period is the work plus 5 s; in
play it measured 5-9 s. `DUWS_fnc_opcom_advance` (`fnc_opcom_movement_core.sqf:33`) moves a virtual unit one cell per
`DUWS_opcom_speed` ticks, so its ground speed falls by the same ratio, and every tick-counted span (`OPCOM_COMMIT_HOLD`,
the muster expiries, belief ageing) stretches with it. This is a consequence of findings 1-5, not a separate fix: a
shorter sleep under load would add load.

## Checked and dismissed

- **The sighting sweep** (`belief/fnc_opcom_sense.sqf`) batches `nearTargets` over `OPCOM_SENSE_BATCH` observers a
  tick and read 0-1 ms throughout.
- **`decay`, `prune` and `contested`** are linear over the belief rows or the site keys. Their 49-209 ms readings
  arrived on ticks where every stage inflated together, the contention signature.
- **The intel contact scripts** that the PERF line lists twelve to twenty of (`fnc_intel_contact_init.sqf x20`) are
  one `sleep DUWS_intel_contact_life` thread per plotted contact (`search/fnc_intel_contact_init.sqf:57-59`). They
  sleep; they do not poll.
- **`fnc_taskforce_tick`** exits on an empty task-force list, which is the whole play-test.
- **The DEBUG line's own grid scans** are gated on the log level (`fnc_opcom_perception_run.sqf:76`).
- **The grid stage's re-pricing of awake sites** (`fnc_opcom_grid_rebuild.sqf:51-54`, through
  `DUWS_fnc_garrisonForce`) is linear in the men and objects of the sites near the player: a team-row lookup per man,
  and an `alive` and `isKindOf` check on each of the 65 or more objects of a deployed zone. A static-force cache cleared
  by a Killed handler would lose its handler on the next stream cycle: zone statics are streamed, not pinned
  (`fnc_static_place` files them without the pin, `shared/functions/fnc_static_roles.sqf:169`). The `grid` stage's
  frame count shows how much of its 35-360 ms is its own work.
- **The class-power memo and the tier-force memo** already hold; nothing re-prices a class per tick.
- **The road search** is fixed by the road graph and the heap; the 15-128 s picks in the play-test predate it.

## Plan of action

Three steps: update the DEBUG lines, measure, review. The first step is finding 1, and it also carries findings 2, 5
and 7: the play-test already shows the cost of finding 2, and findings 5 and 7 change no behaviour, so the
measurement checks those three rather than decides them.

### Measure

Play-test at DEBUG, with the OPCOM debug overlay closed so that its cell gather adds no contention, in a campaign
where the commander builds. Each figure settles a question:

| Figure | Question it settles |
|---|---|
| `need field rebuilt (…)`, `need deposits re-spread` | Finding 2: that only a band input still forces a rebuild, and what a re-spread costs |
| `site` and `siteValues` | Findings 2 and 3: the siting pass's share of the pick, and how many Values a pass still computes |
| `targets` and `rows(…)` | Findings 3, 4 and 6: which rows carry the unscheduled pass (`patrol` for finding 4, `rapport` and `attack_qrf` for finding 3) |
| `route[…]` | Finding 5: the A* searches of a tick, the cells they expand and their ms/frames |
| the frame count of `grid` | Whether the re-pricing of awake sites, dismissed above, is its own cost or contention |

### Review

Decide each open finding against those figures, and drop any finding whose cost the figures do not show. Where the
costs are confirmed, the review starts from this order, cheapest change first:

1. Finding 3: the town list once per pass, then the flat emitter list.
2. Findings 4 and 6, for the rows that `rows(…)` names.
