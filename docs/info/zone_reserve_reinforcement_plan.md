# Zone reserve / reinforcement model — design plan

Status: proposal, not yet implemented. This doc is for review; its open-questions section
holds the decisions still owed before code starts.

## Problem

A zone spawns its whole tier composition the moment a player streams it in. `enemyunitMultiplier`
scales that composition wholesale (`DUWS_fnc_scaleComposition`), so a tier IV zone at 80 infantry
becomes 160 at x2 and 240 at x3 — and two tier IV zones hot at once double that again. Streaming
caps AI at the *zone* level (a zone is wholly awake or wholly stowed by proximity), but inside an
awake zone every unit simulates. Nothing bounds the total live count across simultaneously-active
zones, and AI count is the dominant server/client CPU cost.

## Goal

Bound the number of simultaneously-simulated *zone-garrison* infantry with a global cap, without
making any zone worth less or any fight easier. The multiplier becomes **depth** (reinforcement
waves) rather than **simultaneity** (everyone on the field at once). A zone the player would have
faced at 80 men still costs 80 men to take; they just arrive in waves as the global count allows.

## Core model — the invariant

**A reserve is deferred garrison, not lost garrison.** When the cap would be exceeded, an infantry
group is not spawned; its token is pushed to the zone's reserve queue. That queued token counts as
*still-standing garrison* for every measure of the zone's strength — the capture test, the attrition
record, the map readout — until it either spawns-and-dies or the zone stows. The cap changes only
*when* a unit physically simulates, never *how many* the zone is worth or *how hard* it is to take.

Concretely, everywhere a zone's remaining garrison is measured, the quantity becomes:

```
remaining = alive-roster-men + owed-reserve-men
peak      = men-placed-at-raise + owed-reserve-men-at-raise   (= full intended garrison)
```

When the cap is never hit, the queue is empty, `owed = 0`, and every formula collapses to today's
behaviour exactly. The change is inert until multiple zones are hot at once.

## Scope — what the cap counts, what it ignores

The cap is tied specifically to **zone rosters** (`fnc_zone_roster` = `fnc_site_roster`).

| Population | Counts toward tally? | Spawn gated by cap? |
|---|---|---|
| Zone garrison infantry | yes — one per on-foot man | **yes** (deferred to reserve) |
| Zone garrison vehicles | yes — **one per vehicle**, crew not counted | no — vehicles always spawn |
| Hardpoint garrisons | no (separate sites/rosters) | no |
| Town / civilian garrisons | no (separate rosters) | no |
| BLUFOR | no | n/a |

Hardpoints are exempt by construction: they are their own streaming sites with their own rosters,
so scoping the tally to zone rosters excludes them without a special case. Vehicles are exempt from
the *gate* by explicit rule (a half-spawned armour push reads worse than a few extra infantry). A
crewed vehicle counts as **one** AI entity in the tally, not its crew man-count — a manoeuvring
vehicle is roughly one entity's worth of cost, and counting each occupant would price armour out of
the cap for no performance reason.

## Data and helpers

New globals (`server_var_init.sqf`, both server config settings, fixed — not scaled by player count):

- `DUWS_zoneAICap` — the entity threshold, default `100`. Above it, further infantry groups defer.
- `DUWS_zoneAIReinforceFrac` — default `0.6`. When the live tally falls below this fraction of the
  cap, the event-driven reinforcement pass fires (see the poll section).

New functions (home: `fnc_zone_state_init.sqf`, which already owns roster/strength/peak/tier and is
load-ordered before any zone spawns — see the load-order note in that file):

- `DUWS_fnc_zoneAILive` — the live **entity** tally: across every zone in `zone_meta_array`, count
  alive on-foot men (`vehicle _x == _x`) plus alive vehicles, one each. Distinct from
  `fnc_zone_garrison_count` (men), which the strength and capture model keep using — the tally
  governs only spawn/defer, the men-count governs how beaten a zone is, and the two need not agree.
- `DUWS_fnc_zoneReserveMen {key}` — the owed **men**: `Σ count (DUWS_fnc_teamRoster [token, "opfor",
  strength])` over the queue. Exact rather than `roster × strength`, so the capture threshold stays
  honest against the leader-kept, men-thinned roster (attrition drops men within a team, never the
  team; a deferred squad is worth its thinned size, floor one for the leader).

New per-zone state:

- `DUWS_zoneReserve_<key>` — the deferred-token queue (array of composition tokens). Lives only while
  the zone is awake; cleared on stow and rebuilt by the gate on re-raise.

## Spawn-time gate

`DUWS_fnc_raiseGarrison` (`fnc_zone_spawn_sizes.sqf:162`) is the per-token spawn loop. It gains
cap-awareness: for each token, before spawning,

- vehicle token → spawn always (never gated);
- infantry token → if `DUWS_fnc_zoneAILive >= DUWS_zoneAICap`, **do not spawn**; append the token to
  this zone's reserve queue and continue.

Because the tally already includes this zone's own men as they land, the running total is naturally
correct across the staggered raise — no separate bookkeeping. `raiseGarrison` returns the groups it
raised as today; the deferred tokens are read back from the queue by the caller.

`fnc_zone_spawn` (`fnc_zone_spawn_sizes.sqf:278`) then sets the peak from the **intended** force:

```
_placed   = fnc_zone_garrison_count(key)          // what actually stood up (incl. vehicle crews)
_owed     = DUWS_fnc_zoneReserveMen(key)          // what the cap deferred
_intended = _placed + _owed
```

and publishes `DUWS_zoneBase_<key>` / `DUWS_zonePeak_<key>` from `_intended` rather than `_placed`.
When nothing deferred, `_owed = 0` and this is byte-for-byte today's behaviour.

## Capture and attrition reconciliation (the delicate part)

These three read "remaining garrison" and all must count owed reserves, or the model breaks in one
of two directions — a zone that spawned short reads as already-beaten (captured without a fight), or
a zone records phantom casualties on stow (comes back permanently weaker).

- `fnc_zone_capture_ready.sqf:36` — change the break test to
  `(fnc_zone_garrison_count(key) + DUWS_fnc_zoneReserveMen(key)) > BREAK_FRACTION * peak`.
  A zone with owed reserves cannot fall: the owed men hold `remaining` above the 0.2 line until the
  reserves have actually spawned and been killed. The player must draw the waves out and beat them.
- `fnc_zone_strength_record` (`fnc_zone_state_init.sqf:117`) — `_left` becomes
  `garrison_count + reserveMen`, so a zone that stows with reserves still owed preserves them as
  strength instead of recording them as casualties.
- `fnc_zone_strength_refresh` (`fnc_zone_state_init.sqf:140`) — same `+ reserveMen` on the map-read
  path.

## The reinforcement poll (5-minute timer)

The reinforcement pass is one function, `DUWS_fnc_zoneReservePass`, fired from two triggers:

- **Primary — a 5-minute loop.** A single server-side `while {true}` launched once at server init
  beside the other loops (pattern: `fnc_zonesundercontrol.sqf`, `fnc_repetitive_cleanup.sqf`),
  `uiSleep 300`. The steady heartbeat that trickles waves in even during a slow grind.
- **Event-driven — on a sharp drain.** When the live tally crosses below
  `DUWS_zoneAIReinforceFrac × DUWS_zoneAICap` (0.6 × cap), fire the pass immediately, so a wave that
  gets wiped pulls the next one in seconds rather than up to five minutes later. Implementation: a
  debounced `killed` handler on zone-roster units re-checks the tally on each death and invokes the
  pass once when it dips under the fraction (debounce so a mass-casualty moment fires one pass, not
  fifty). A short watchdog loop is the simpler alternative if per-unit handlers prove noisy.

Each pass, take the contested OPFOR zones — those in `WARCOM_zones_controled_by_OPFOR` with a
published peak, a non-empty reserve queue, and BLUFOR near (`fnc_duws_bluforNear` over
`radius + margin`) — and **sort them by player count present, most players first**, so the fight the
most people are in gets resupplied before a lightly-contested one. Then for each, in that order:

- while the queue is non-empty **and** `DUWS_fnc_zoneAILive < DUWS_zoneAICap`: pop a token, spawn it
  as a reinforcement squad at the zone's **current** strength, append its units to the zone roster.
  `owed` shrinks and `alive` grows by the same men, so `remaining` is unchanged by the arrival
  itself — only by kills.

Because the tally counts men (each on-foot man is one entity), the loop spends cap headroom
per man, so a worn zone's thin teams pack in denser — the same headroom fields more small teams than
few full ones, with no special logic. Reinforcements spawn at the zone's current strength, not the
strength when the token was deferred: if the player wears the zone down further while reserves wait,
`zoneReserveMen` shrinks with it and the arriving teams are thinner, so a queued reserve never
backfills men the zone has already lost. Refunding that attrition is the one thing the strength model
exists to prevent, and the reserve must not reopen it.

A quiet zone (no BLUFOR near) is skipped: its reserves wait until it is actually being fought.

## Reinforcement placement and posture

**Same squads.** A reinforcement is the exact token the cap deferred — same roster, same strength —
so the zone fields precisely what it would have without the cap. Only the placement and the orders
differ from a normal garrison raise.

**Placement — far side, toward friendly ground, away from the player.** Compute a spawn bearing off
the zone centre:

- *away vector*: from the centroid of BLUFOR (players + WEST units within `radius + margin`) through
  the zone centre and out the far side;
- *toward vector*: from the zone centre toward the nearest *other* zone (`zone_meta_array` minus
  self) — the direction reinforcements would plausibly come from;
- blend (suggest weight 0.7 away, 0.3 toward), take the bearing, spawn at `centre getPos [radius*0.9,
  bearing]`, then `BIS_fnc_findSafePos`. If no BLUFOR is found (edge), fall back to the toward vector
  alone.

**Posture — a new `"hunt"` case.** Reinforcements do not patrol or garrison. A new posture in
`fnc_apply_posture` gives them one order: a `SAD` (search-and-destroy) waypoint on the **nearest
player's position**, `AWARE` behaviour, then a `CYCLE`. Spawned on the far edge with the player on
the near/BLUFOR side, this drives them straight across the zone onto the player and lets them engage
on contact. The waypoint takes the nearest player at spawn; `SAD` + `AWARE` means they sweep that
area and fight whatever they meet, so a player who has moved on is still hunted rather than walked
around. The token's own stored posture is ignored for reserves. Living in `fnc_apply_posture` keeps
the order with the other postures rather than inline in the spawn path.

## Streaming interaction

When a zone stows (`DUWS_fnc_zoneStow`, `fnc_zone_stream_init.sqf:281`), the order matters and follows
the existing strength contract:

1. `fnc_zone_strength_record` (now counting owed) — preserves un-arrived reserves as strength;
2. clear `DUWS_zoneReserve_<key>`;
3. collect the roster;
4. `fnc_zone_garrison_dropped` (clears the peak).

On re-raise, `fnc_zone_spawn` thins the full intended list by the recorded strength and the gate
re-defers whatever is still over cap, rebuilding the queue. The queue is therefore per-awake-session
state, never persisted, and always consistent with the zone's recorded strength.

## Failure modes and edge cases

- **Global cap saturated by several hot zones.** Reserves for a zone spawn only as slots free. But a
  player making progress kills men, which frees slots, which spawns the next wave on the following
  tick — self-resolving while the player advances. A player who sits still gets no waves and takes no
  ground; that stalemate is intended, not a bug.
- **Cap below one squad.** The gate defers at `>= cap`; at tally 0 it still spawns one squad (a
  slight overshoot), so no deadlock. A sane floor (`cap >= largest squad`) avoids the overshoot.
- **owed-men vs the tally.** Two different measures on purpose. Owed men (`zoneReserveMen`) is the
  exact thinned roster a deferred token will spawn, feeding the men-based capture/strength contract;
  the tally (`zoneAILive`) is an entity count feeding the cap. A deferred infantry token thus removes
  its whole roster from the tally at once but is owed at the man level — the gate and the strength
  model stay each in their own unit, which is why the queue stores tokens, not counts.
- **Reinforcements pathing through the player.** Possible when the "far side" still lies across the
  player's axis; accepted — they are reinforcing a contested objective.

## Decisions

Settled parameters, reflected in the sections above:

- **Cap** is a fixed server config setting (`DUWS_zoneAICap`, 100), not scaled by player count.
- **Two triggers**: the 5-minute heartbeat plus an event-driven pass at `DUWS_zoneAIReinforceFrac`
  (0.6) of the cap, so a wiped wave pulls the next in immediately.
- **Priority under load** is by player count — the most-crowded contested zone resupplies first.
- **Reserve orders** are a new `"hunt"` posture: `AWARE`, `SAD` on the nearest player.
- **Tally** counts a vehicle as one entity, not its crew.
- **Recaptured zones** are not special-cased: reserves inherit the 0.3 scratch strength and arrive
  light, which is moot in practice — at 0.3 a retaken zone already has most of its (thin) garrison on
  the ground, so little is ever owed.

## Files touched

| File | Change |
|---|---|
| `server_var_init.sqf` | `DUWS_zoneAICap`, `DUWS_zoneAIReinforceFrac` |
| `fnc_zone_state_init.sqf` | `zoneAILive` (entity tally), `zoneReserveMen` (exact), reserve-queue accessors; `+ reserveMen` in strength record/refresh |
| `fnc_zone_spawn_sizes.sqf` | gate infantry tokens in `raiseGarrison`; peak = placed + owed in `fnc_zone_spawn` |
| `fnc_zone_capture_ready.sqf` | remaining = garrison_count + reserveMen |
| `fnc_zone_stream_init.sqf` | clear reserve queue in `DUWS_fnc_zoneStow`, after the strength record |
| `fnc_apply_posture.sqf` | new `"hunt"` posture (SAD on nearest player, AWARE, cycle) |
| new `fnc_zone_reserve.sqf` (or fold into state_init) | reinforcement spawn fn, the 5-minute loop, and the debounced `killed`-handler event path; launched at server init |

## Task breakdown

1. Cap + entity tally (`zoneAILive`) + exact `zoneReserveMen` helpers (no behaviour change).
2. Gate + reserve queue + peak = placed + owed.
3. Capture / strength reconciliation (`+ reserveMen`) — the correctness core.
4. Stow queue-clear in the right order.
5. Reinforcement spawn (placement math + `"hunt"` posture).
6. Five-minute loop + the event-driven `killed`-handler path + launch.
7. Tests.

## Test plan

- **Unit (sqf-vm, alongside the existing 303):** `zoneAILive` counts on-foot men plus one per
  vehicle; `zoneReserveMen` sums the exact thinned roster; the gate defers the right tokens against a
  stubbed cap; `peak = placed + owed`; capture remaining counts owed; strength record counts owed.
- **Manual/integration:** two tier IV zones with `cap = 100` → total live holds near 100, deferred
  groups queue, reinforcements arrive far-side over successive 5-minute ticks, and neither zone is
  capturable until its owed + alive garrison is beaten below the break fraction.
