# Zone reserve / reinforcement model — design plan

Status: proposal, not yet implemented. This doc is for review; its decisions section holds the
settled parameters.

## Problem

A zone spawns its whole tier composition the moment a player streams it in, and
`enemyunitMultiplier` scales that composition wholesale (`DUWS_fnc_scaleComposition`) — it duplicates
every token. A composition token *is* a group (a team is a group, a vehicle is a group), so the
multiplier is a group multiplier. Tier IV is 27 groups at x1, 54 at x2, 81 at x3, and two tier IV
zones hot at once at x3 want 162 groups from the garrisons alone. The engine caps each side at **144
groups**; past it `createGroup` and `BIS_fnc_spawnGroup` return `grpNull` silently and no AI spawns
(`docs/info/arma_engine_gotchas.md`). So the multiplier both drives the group wall and, as a blunt
"everyone on the field at once" swarm, tanks framerate on the very zones a player is fighting.

## Goal

Turn the multiplier into **reserve depth**, and hard-bound the live group count. A zone always fields
at most its x1 tier composition; the multiplier sets how much *more* force waits behind that as a
reserve pool, delivered in waves that refill the garrison to its x1 ceiling as casualties are taken.
A x3 zone is still worth 3x the men to take — you just never see more than the x1 count of groups on
the ground at once, so the 144 wall is structurally out of reach and the fight is a paced grind
rather than a lag spike.

## Core model

- **Multiplier = reserve depth.** `mult` (1/2/3) sets total intended force = `mult x garrison`. The
  initial garrison is always the x1 tier composition; the surplus `(mult - 1) x` is a reserve pool
  from the start. At x1 the pool is empty and the whole system is inert — behaviour is exactly
  today's.
- **Per-zone live *group* ceiling = the tier's x1 token count.** Each token is one group, so the
  ceiling is `count (DUWS_zoneSpawnTiers select (tier - 1))` — no new table.
- **The pool covers the whole composition**, infantry and vehicles alike: `(mult - 1)` ordered copies
  of the x1 tier list. A destroyed tank can be backfilled by a reserve tank, a wiped squad by a
  reserve squad.
- **Refill to the ceiling, never above.** When a zone's live group count falls below its x1 count,
  reserve squads spawn to restore it. Live groups per zone are therefore hard-bounded at the x1 count
  forever; the multiplier only deepens the pool behind it.
- **Reserves ride the hunt posture** (below), spawned on the far side of the zone.

Worked, tier IV x3: 27 live (18 infantry + 9 vehicle groups), reserve pool = 2 x 27 = 54 more.
Player grinds 81 groups' worth of men total, but never faces more than 27 groups at once. Two hot IV
zones cap at 54 live + hardpoints, comfortably under 144.

| tier | x1 group ceiling | infantry groups | vehicle groups |
|---|---|---|---|
| I | 7 | 6 | 1 |
| II | 14 | 11 | 3 |
| III | 20 | 15 | 5 |
| IV | 27 | 18 | 9 |

## The invariant

**A reserve is deferred force, not lost force.** The pool counts as still-standing garrison for every
measure of the zone's strength until it either spawns-and-dies or the zone stows:

```
peak      = mult x (x1 tier men)          // full intended garrison over the whole grind
remaining = alive-roster-men + pool-men   // what the capture/attrition contract measures
```

At `mult = 1` the pool is empty, `remaining = alive`, and every formula collapses to today's exactly.
The reserve delivery never changes `remaining` — a refill moves men from pool to alive by the same
count; only kills move the number.

## Scope — what the ceilings govern

| Population | In a zone's x1 group ceiling? | Reserve-pooled by the multiplier? | In the global tally? |
|---|---|---|---|
| Zone garrison (infantry + vehicles) | yes | yes | yes |
| Hardpoint garrisons | no (separate sites/rosters) | no | yes — counted, not throttled |
| Town / civilian garrisons | no | no | yes — counted, not throttled |
| BLUFOR | no | no | no |

Hardpoints and towns spawn their own groups on their own rules; the multiplier does not deepen them
and the per-zone ceiling does not bound them. They do count toward the **global** group tally, so a
dense hardpoint field pushes zones to back off and leave engine headroom — which is the global
ceiling's whole job.

## The two ceilings

Both server config settings (`server_var_init.sqf`), fixed:

- **Per-zone live group ceiling** — derived, not stored: the x1 tier token count. Refill stops here.
- `DUWS_zoneGroupCeiling` (default `130`) — the global OPFOR-side group throttle. When
  `count (allGroups select {side _x == east})` reaches it, zone garrison spawns and refills pause and
  their tokens stay in the pool. Leaves ~14 groups of slack below 144 for transient spikes. This is
  the co-op backstop: several players in several zones, plus hardpoints, can sum past 144 even at x1,
  and per-zone bounds alone would not catch it.
- `DUWS_zoneReinforceFrac` (default `0.5`) — the event trigger. A zone whose live groups fall below
  this fraction of its x1 ceiling pulls an immediate refill wave rather than waiting for the poll, so
  reinforcement reads as waves, not one-in-one-out whack-a-mole.

## Multiplier application

`DUWS_fnc_zoneSpawnList` stops scaling the live composition. The initial garrison is the **x1** tier
list (thinned by strength, filtered by what the side can field). A new step seeds the zone's reserve
pool with `(mult - 1)` ordered copies of the same x1 list. `DUWS_fnc_scaleComposition` retires from
the live path; the multiplier now sizes the pool, not the garrison. Vehicles in the pool still gate
on earned AP at spawn (`DUWS_fnc_tokenClass`), so a reserve tank fields only once OPFOR has the rung.

## Data and helpers

New per-zone state:

- `DUWS_zoneReserve_<key>` — the reserve pool: an ordered token list. Lives only while the zone is
  awake; cleared on stow, rebuilt on re-raise. At `mult = 1` it is empty.

New functions (home: `fnc_zone_state_init.sqf`, which already owns roster/strength/peak/tier and is
load-ordered before any zone spawns):

- `DUWS_fnc_zoneGroupCount {key}` — the zone's live group count: distinct alive groups in its roster.
  Compared against the x1 ceiling to decide refills.
- `DUWS_fnc_opforGroupCount` — `count (allGroups select {side _x == east})`, the global throttle input.
- `DUWS_fnc_zoneReserveMen {key}` — owed men: `Sigma count (DUWS_fnc_teamRoster [token, "opfor",
  strength])` over the pool, exact against the leader-kept, men-thinned roster. Feeds `remaining`.

## Refill — the reinforcement pass

One function, `DUWS_fnc_zoneReservePass`, fired from two triggers:

- **Primary — a 5-minute loop.** A single server-side `while {true}` launched once at server init
  beside the other loops (pattern: `fnc_zonesundercontrol.sqf`), `uiSleep 300`. The heartbeat that
  tops zones back up during a steady grind.
- **Event-driven — on a deep dip.** A debounced `killed` handler on zone-roster units re-checks the
  zone when a group dies; if live groups fall below `DUWS_zoneReinforceFrac` of the x1 ceiling, it
  fires the pass at once (debounced so a mass-casualty moment triggers one wave, not fifty).

Each pass, take the contested OPFOR zones — those in `WARCOM_zones_controled_by_OPFOR` with a
published peak, a non-empty pool, and BLUFOR near (`fnc_duws_bluforNear` over `radius + margin`) — and
**sort by player count present, most first**, so the most-crowded fight resupplies before a lightly
contested one. Then for each, in that order:

- while `DUWS_fnc_zoneGroupCount(key) < x1-ceiling` **and** the pool is non-empty **and**
  `DUWS_fnc_opforGroupCount < DUWS_zoneGroupCeiling`: pop the next pool token, spawn it as a
  reinforcement at the zone's **current** strength, append its units to the zone roster.

A quiet zone (no BLUFOR near) is skipped; its pool waits until it is being fought. Reinforcements
spawn at current strength, not the strength when pooled: if the player wears the zone down further
while reserves wait, `zoneReserveMen` shrinks with it and arriving squads are thinner, so a queued
reserve never backfills men the zone has already lost — refunding that attrition is the one thing the
strength model exists to prevent.

## Capture and attrition reconciliation

Three reads of "remaining garrison" must all count the pool, or a zone that spawned short reads as
already-beaten, or one records phantom casualties on stow:

- `fnc_zone_capture_ready.sqf:36` — break test becomes
  `(fnc_zone_garrison_count(key) + DUWS_fnc_zoneReserveMen(key)) > BREAK_FRACTION * peak`. A zone with
  a pool cannot fall: the owed men hold `remaining` above the line until the reserves have spawned and
  been killed. The player must draw the waves out and beat them.
- `fnc_zone_strength_record` (`fnc_zone_state_init.sqf:117`) — `_left` becomes
  `garrison_count + reserveMen`, so a zone that stows with a pool preserves it as strength.
- `fnc_zone_strength_refresh` (`fnc_zone_state_init.sqf:140`) — same `+ reserveMen` on the map read.

`peak` is published from `mult x (x1 tier men)` in `fnc_zone_spawn`, so a x3 zone is measured against
its full intended force whether or not the pool has arrived yet.

## Placement and posture

**Placement — far side, toward friendly ground, away from the player.** Bearing off the zone centre:
away from the BLUFOR centroid (players + WEST units within `radius + margin`), nudged toward the
nearest other zone (weight ~0.7 away, 0.3 toward); spawn at `centre getPos [radius * 0.9, bearing]`
then `BIS_fnc_findSafePos`. No BLUFOR found → the toward vector alone.

**Posture — a new `"hunt"` case** in `fnc_apply_posture`: a `SAD` waypoint on the **nearest player's
position**, `AWARE`, speed `FULL`, then a `CYCLE`. Speed is deliberate — a reinforcement runs, it
does not stroll; the wave has to carry a sense of urgency, arriving as pressure rather than a slow
trickle. Spawned on the far edge with the player on the near side, this drives reserves at a run
across the zone onto the player. It applies to a mounted group too — a reserve vehicle hunts the same
way. The pool token's own stored posture is ignored for reserves.

## Streaming interaction

When a zone stows (`DUWS_fnc_zoneStow`, `fnc_zone_stream_init.sqf:281`), order follows the strength
contract:

1. `fnc_zone_strength_record` (now counting the pool) — preserves un-arrived reserves as strength;
2. clear `DUWS_zoneReserve_<key>`;
3. collect the roster;
4. `fnc_zone_garrison_dropped` (clears the peak).

On re-raise, `fnc_zone_spawn` fields the x1 tier thinned by the recorded strength and reseeds the pool
with `(mult - 1)` copies, so the pool is per-awake-session state, never persisted, always consistent
with the zone's recorded strength.

## Failure modes and edge cases

- **Global ceiling saturated by many zones + hardpoints.** New spawns and refills pause; pools hold.
  As the player kills, `opforGroupCount` falls and the next pass resumes. A player making progress
  always frees room; a player sitting still gets no waves and takes no ground, which is intended.
- **grpNull backstop.** Every group is `deleteGroupWhenEmpty true` so dead groups free their slot, and
  a spawn that still hits the engine limit returns `grpNull` and is dropped rather than erroring — the
  130 ceiling keeps the fight off that edge, the drop catches the rare overrun.
- **Refill vs strength.** A refill moves men pool -> alive without changing `remaining`; only kills
  reduce it. So refilling to the group ceiling never restores strength — the pool is spent, not
  regenerated.
- **Reinforcements pathing through the player.** Possible when the far side lies across the player's
  axis; accepted — they are reinforcing a contested objective.

## Decisions

- **Multiplier** is reserve depth: initial garrison always x1, pool = `(mult - 1) x` the x1 list,
  covering infantry **and** vehicles.
- **Per-zone live groups** are hard-capped at the tier's x1 token count; refill tops up to it, never
  beyond.
- **Global throttle** `DUWS_zoneGroupCeiling` (130) pauses zone spawns/refills near the engine's
  144-per-side limit — the co-op / hardpoint-dense backstop.
- **Refill cadence**: 5-minute heartbeat plus an event wave when a zone dips below
  `DUWS_zoneReinforceFrac` (0.5) of its ceiling.
- **Priority under load** is by player count — most-crowded contested zone first.
- **Reserve orders** are a new `"hunt"` posture: `AWARE`, speed `FULL`, `SAD` on the nearest player —
  reinforcements run in for urgency.
- **Recaptured zones** are not special-cased: reserves inherit the 0.3 scratch strength and arrive
  light, moot in practice since little is owed at 0.3.

## Files touched

| File | Change |
|---|---|
| `server_var_init.sqf` | `DUWS_zoneGroupCeiling`, `DUWS_zoneReinforceFrac` |
| `fnc_zone_state_init.sqf` | `zoneGroupCount`, `opforGroupCount`, `zoneReserveMen`, reserve-pool accessors; `+ reserveMen` in strength record/refresh |
| `fnc_zone_spawn_sizes.sqf` | initial spawn = x1 tier (drop the live `scaleComposition`); seed the pool with `(mult - 1)` copies; peak = `mult x` tier men |
| `fnc_zone_capture_ready.sqf` | remaining = garrison_count + reserveMen |
| `fnc_zone_stream_init.sqf` | clear reserve pool in `DUWS_fnc_zoneStow`, after the strength record |
| `fnc_apply_posture.sqf` | new `"hunt"` posture (SAD on nearest player, AWARE, cycle) |
| new `fnc_zone_reserve.sqf` (or fold into state_init) | reinforcement pass, the 5-minute loop, and the debounced `killed`-handler event path; launched at server init |

## Task breakdown

1. Ceilings + `zoneGroupCount` + `opforGroupCount` + exact `zoneReserveMen` helpers (no behaviour change).
2. Multiplier recast: initial = x1 tier, seed pool `(mult - 1) x`, peak = `mult x` men.
3. Capture / strength reconciliation (`+ reserveMen`) — the correctness core.
4. Stow pool-clear in the right order.
5. Reinforcement spawn (placement math + `"hunt"` posture, infantry and vehicles).
6. Refill pass: 5-minute loop + the event-driven `killed`-handler path + the global throttle + launch.
7. Tests.

## Test plan

- **Unit (sqf-vm, alongside the existing 303):** the x1 ceiling equals the tier token count; the pool
  is `(mult - 1)` copies; `zoneReserveMen` sums the exact thinned roster; a refill stops at the
  ceiling and pauses at the global throttle; `peak = mult x` men; capture remaining counts the pool;
  strength record counts the pool.
- **Manual / integration:** a tier IV x3 zone holds at 27 live groups while a 54-group pool grinds in
  as waves; two hot IV zones stay under the global ceiling; neither is capturable until its pool plus
  alive garrison is beaten below the break fraction.
