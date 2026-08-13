# Zone reserve / reinforcement model — design plan

Status: implemented. The decisions section holds the settled parameters; the implementation-notes
section below records where the built code deliberately refined the spec.

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
- **The pool covers the whole composition**, infantry and vehicles alike: `(mult - 1)` copies of the
  x1 tier list, drawn from at *random*. A lost group is answered by any token in the pool — a downed
  tank might bring another tank or a rifle section — so order carries nothing; the pool is a multiset.
- **Refill to the ceiling, never above.** When a zone's live composition group count falls below its x1
  count, reserve squads spawn to restore it. Live composition groups per zone are therefore
  hard-bounded at the x1 count forever; the multiplier only deepens the pool behind it.
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

- **Per-zone live group ceiling** — the zone's full fielded-able x1 capacity (`count` of the filtered
  x1 list), stored per awake session as `DUWS_zoneCeiling_<key>`. Composition groups only: prefab
  static-weapon crews share the roster but are emplacement occupants, not composition, and are excluded
  from the count the refill compares against. Refill stops here.
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
  `DUWS_fnc_opforGroupCount < DUWS_zoneGroupCeiling`: pop a **random fieldable** pool token (a vehicle
  only counts as fieldable at half strength or better, matching the garrison's own thin), spawn it as a
  reinforcement at the zone's **current** strength, append its units to the zone roster.

A quiet zone (no BLUFOR near) is skipped; its pool waits until it is being fought. Reinforcements
spawn at current strength, not the strength when pooled: if the player wears the zone down further
while reserves wait, `zoneReserveMen` shrinks with it and arriving squads are thinner, so a queued
reserve never backfills men the zone has already lost — refunding that attrition is the one thing the
strength model exists to prevent.

## Capture and attrition reconciliation

Three reads of "remaining garrison" must all count the pool, or a zone that spawned short reads as
already-beaten, or one records phantom casualties on stow:

- `fnc_zone_capture_ready.sqf` — break test becomes
  `(fnc_zone_garrison_count(key) + DUWS_fnc_zoneReserveMen(key)) > BREAK_FRACTION * peak`, with
  `BREAK_FRACTION` **0.1**: a zone falls only once one tenth of its full fighting potential — garrison
  plus its whole reserve pool — is all that remains. A zone with a pool cannot fall on an empty
  perimeter: the owed men hold `remaining` above the line until the reserves have spawned and been
  killed, so the player must draw the waves out and beat nine tenths of everything before taking it.
- `fnc_zone_strength_record` (`fnc_zone_state_init.sqf:117`) — `_left` becomes
  `garrison_count + reserveMen`, so a zone that stows with a pool preserves it as strength.
- `fnc_zone_strength_refresh` (`fnc_zone_state_init.sqf:140`) — same `+ reserveMen` on the map read.

`peak` is published from `mult x (x1 tier men)` in `fnc_zone_spawn`, so a x3 zone is measured against
its full intended force whether or not the pool has arrived yet.

## Placement and posture

**Placement — from the enemy rear, preferably unseen.** The requirement is that a player never
watches a squad appear and never gets flanked out of nowhere. Three pulls, in priority order, with a
flat distance as the floor.

- **Opposite the BLUFOR approach (primary, non-negotiable).** Spawn on the side of the zone away from
  the players: `-bluDir`, where `bluDir` is the zone-centre-to-player-centroid direction. Reserves
  then come from the far side and meet the players **head-on as they advance, never from the
  approach direction behind them**. This is the anti-flank rule.
- **Weighted toward another enemy zone (soft).** The bearing is nudged toward the nearest other OPFOR
  zone so reserves read as coming from friendly territory when the geometry allows — a preference,
  yielded whenever it would fight the anti-flank direction.
- **Preferably out of sight (best-effort).** At the chosen distance and bearing, try a small number
  of candidate `BIS_fnc_findSafePos` points and prefer one with no line of sight to any player; take
  the farthest / most-occluded if none is fully hidden within the attempts. A preference, not a hard
  gate — see the cost note.

Distance is the floor: `DUWS_zoneReserveSpawnDist` (default 400 m) minimum from every player, anchored
on the nearest one so it reads the same at a 50 m base and a 1300 m island (a zone-radius-relative
distance would drop reserves a kilometre out of the island and on top of the player in the base).
From there they run in at FULL speed — ~70-80 s for infantry, quicker for vehicles.

**Line-of-sight cost.** Not heavy here. `lineIntersectsSurfaces` is a raycast, expensive only when run
per-frame for many units; this runs at spawn only — a few candidates times the players present, once
per wave every few minutes — so it is dozens of casts spread over time, not per-frame. Bounding the
attempts (prefer-hidden, accept-best) keeps it constant-cost and never blocks a spawn, and a
terrain-only `terrainIntersectASL` is the cheaper option if ridgeline masking is enough and building
occlusion is not needed.

Co-op caveat: with players surrounding a zone no single bearing is head-on for all of them, so the
distance floor and the prefer-hidden pass carry most of the weight and the enemy-rear bearing is
best-effort for the group's centre of mass.

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
  covering infantry **and** vehicles, drawn from at random.
- **Per-zone live composition groups** are hard-capped at the tier's full fielded-able x1 count; refill
  tops up to it from the pool, never beyond, and answers a loss with a random token rather than a like
  replacement.
- **Capture threshold** is `BREAK_FRACTION` **0.1**: a zone falls only once one tenth of its full
  fighting potential (garrison plus its whole reserve pool) remains.
- **Global throttle** `DUWS_zoneGroupCeiling` (130) pauses zone spawns/refills near the engine's
  144-per-side limit — the co-op / hardpoint-dense backstop.
- **Refill cadence**: 5-minute heartbeat plus an event wave when a zone dips below
  `DUWS_zoneReinforceFrac` (0.5) of its ceiling.
- **Priority under load** is by player count — most-crowded contested zone first.
- **Reserve orders** are a new `"hunt"` posture: `AWARE`, speed `FULL`, `SAD` on the nearest player —
  reinforcements run in for urgency.
- **Spawn placement** guards against pop-in and cheap flanking, in priority: opposite the BLUFOR
  approach (head-on, never from behind), nudged toward another enemy zone (soft), preferably out of
  line of sight (best-effort, bounded), with a flat `DUWS_zoneReserveSpawnDist` (400 m) floor from the
  nearest player — not zone-relative, so it reads the same at a 50 m base and a 1300 m island.
- **Recaptured zones** are not special-cased: reserves inherit the 0.3 scratch strength and arrive
  light, moot in practice since little is owed at 0.3.

## Implementation notes

Places where the built code refined the spec above, each a decided thing a reader of the source will
meet:

- **The x1 group ceiling is the full fielded-able capacity, and refill draws at random.** The ceiling
  is `count` of the filtered x1 list — what a full garrison of this tier *can* field given current AP
  and settings — stored per awake session as `DUWS_zoneCeiling_<key>`. Reserves therefore bring a
  mauled or recaptured zone back to its designed group count, not merely back to whatever last
  deployed. The refill draws a random fieldable token each time (a vehicle counts as fieldable only at
  half strength or better), so a lost group is answered by any of the pool, and a token deleted by
  value located fresh keeps two concurrent refills of one zone from stale-index corruption without a
  lock.
- **The refill's live count excludes prefab static crews.** `DUWS_fnc_zoneGroupCount` counts only
  groups the streaming garrison raised — those tagged by `DUWS_fnc_zoneReserveWatch` — so it measures
  the same composition-only population the ceiling does. A prefab's manned static weapons sit on the
  same roster (they count toward the capture peak and `remaining`, consistently) but must not read as
  filling composition slots, or a zone with guns would refill short.
- **Owed men are counted, not built.** `DUWS_fnc_zoneReserveMen` sums `DUWS_fnc_tokenMenCount` over the
  pool rather than `count (DUWS_fnc_teamRoster …)`. The capture trigger polls the owed count several
  times a second; building a roster each poll would both pay faction resolution and jitter the capture
  line, because the roster thin drops men at random. `tokenMenCount` mirrors the roster arithmetic
  (leader kept, the rest thinned to `ceil(strength·count)` min 1) deterministically. It counts role
  slots, so a faction that leaves a role undefined counts a hair high — bounded, and it cancels against
  the baseline, which is built in the same slot units.
- **Peak is measured plus owed, not a men-per-tier table.** `baseline = placed + (mult-1) ·
  tokenListMen(x1, 1)`: the x1 half is the *measured* placement, so vehicle crews are counted once and
  no per-tier men table is needed; the pool half is the infantry-slot count matching
  `DUWS_fnc_zoneReserveMen`. At a full pool `remaining` equals `peak` exactly. The one imprecision is
  that a pooled vehicle's crew arrives as a few extra bodies on `garrison_count` when it spawns — owed
  as zero, arriving as two or three — which is well inside the tenths the strength model quantises to.

Reserves route through `DUWS_fnc_zoneSpawnOne` with a posture override and an explicit spawn position
(new optional trailing params on `fnc_spawn_team` / `fnc_spawn_vehicle`), so the far-side placement and
the hunt orders reuse the ordinary spawners rather than a parallel path. The killed handler tags each
unit with its zone key (not its group, which a dead man can outlive).

## Files touched

| File | Change |
|---|---|
| `server_var_init.sqf` | `DUWS_zoneGroupCeiling`, `DUWS_zoneReinforceFrac`, `DUWS_zoneReserveSpawnDist` |
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
5. Reinforcement spawn: anti-approach bearing + toward-zone nudge + bounded prefer-hidden placement, `"hunt"` posture, infantry and vehicles.
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

## Deferred: attrition by lost tokens, not a random thin

Strength today is a single fraction, and a fraction below one thins each team's *men* at random
(`fnc_zone_thin`) and drops vehicles whole below half. That thins the whole garrison's manpower
uniformly and cheaply, but it does not remember *what* the player destroyed: kill a zone's tank and the
zone comes back a bit thinner everywhere rather than specifically a tank down. The reserve model rides
this same fraction, so a reserve wave is thinned the same undifferentiated way.

The intended replacement turns strength from a scalar into a ledger of surviving composition — destroy
one tank, and that tank is gone from the zone's future raises and from its reserve pool. It is a large
enough behaviour change to get its own plan, and its mechanics are specified in
[`garrison_strength_ledger_plan.md`](garrison_strength_ledger_plan.md). Out of scope for this model.
