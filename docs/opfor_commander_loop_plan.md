# OPFOR commander: the decision loop

Three docs describe the OPFOR commander and none of them owns how it decides. `economy_plan.md`
has its wallet, its sinks and its archetype ([§The OPFOR commander](economy_plan.md#the-opfor-commander));
[`hardpoint_system_plan.md`](hardpoint_system_plan.md#the-director-and-the-escalation-ladder) has
what it builds; [`opfor_commander_plan.md`](opfor_commander_plan.md) has the free town events that
sit beside it. This doc holds the part between them: what the commander wakes on, what it is
allowed to know, and how it ranks one town against another.

## The recommendation

Three layers, one thread. Only the first is unusual; the other two are small.

| Layer | Does | Runs |
|---|---|---|
| **Perception** | Maintains the enemy's *belief* about BLUFOR. The commander never reads live player state | Every tick, one engine call per player |
| **Appraisal** | Scores each candidate `[sink, target]` pair on five named terms, picks by weighted random over the top few | Every tick, one unscheduled batch |
| **Commitment** | Turns a choice into an intent with a minimum lifetime and an owner. Re-scoring fills free capacity; it cannot cancel a live intent | Between ticks |

**Perception is what makes the enemy read as intelligent, not appraisal.** A commander with
perfect information acting imperfectly reads as stupid; a commander with imperfect information
acting correctly on it reads as a person, because a QRF converging on where the player was ten
minutes ago is a decision the player can reconstruct and blame themselves for. Everything else in
this doc is cheaper than that layer is valuable.

## Perception: the commander plans against belief, never against truth

Cheating in a strategy AI is three things — resource bonuses, spawn-on-demand, and map hack. The
economy plan already refuses the first two: enemy income comes from towns and retakes the player
can contest ([§Where OPFOR army power comes from](economy_plan.md#where-opfor-army-power-comes-from)),
and enemy capability is ratcheted by a tier the player can watch. **Map hack is the one nothing
currently forbids, and in SQF it is the default** — `allPlayers` and `getPos` are free, and every
OPFOR behaviour the mission has ever shipped read them directly.

So the commander reads a belief store, and only the sensors below read truth.

### Shape

Parallel arrays, server-local, indexed together, every entry a number or an array of numbers. The
same shape and the same reason as the hardpoint registry
([`hardpoint_system_plan.md`](hardpoint_system_plan.md#state)): the mission namespace is the save
file, so state that might outlive a session has to be serialisable
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).
Not broadcast — no client reads it, and a belief the player could inspect is a belief the player
can route around.

| Array | Holds |
|---|---|
| `DUWS_opcom_belief_key` | what is believed about: a player's `netId`, a zone index, a FOB index |
| `DUWS_opcom_belief_pos` | `[x,y,0]` as last observed, never a live lookup |
| `DUWS_opcom_belief_time` | `time` at the observation |
| `DUWS_opcom_belief_str` | believed BLUFOR strength there |

New state takes the `DUWS_` prefix regardless of the pending WARCOM-to-OPCOM rename, per
[`info/architecture.md`](info/architecture.md#globals-have-no-namespace).

A position is stored, never an object handle. That is the same latching rule the artillery target
grid already uses and for the same reason
([`hardpoint_system_plan.md`](hardpoint_system_plan.md#observation-is-the-trigger)): an object
reference re-resolves every tick and follows a player through a respawn, a taxi and a fast travel,
which is a map hack arriving by the back door.

### Sensors

Each writer is something the player can find and kill.

| Sensor | Writes | Cost |
|---|---|---|
| Direct sighting | `east knowsAbout _p > 1.5` stamps that player's position, group size and `time` | one engine call per player per tick |
| Observation post | an OP hardpoint covering ground stamps what it sees | the mechanic [`hardpoint_system_plan.md`](hardpoint_system_plan.md#observation-is-the-trigger) already specifies |
| Banded town | a player inside a town at reputation `<= -10` stamps a low-strength, delayed entry | players x banded towns distance tests |
| Zone or FOB flip | stamps exactly and free — the enemy knows what it lost | event-driven |
| Intel patrol tasking | a purchased sensor, which is what `economy_plan.md` already wants it to be | the tasking's own cost |

**`knowsAbout` with a side on the left is the whole sighting sweep.** It is a side-wide query, so
"has any OPFOR unit seen this player" is one call per player — no `nearEntities`, no scan over
`allUnits`, and nothing that grows with the campaign. That is the rule in
[`info/performance.md`](info/performance.md#the-pattern-that-costs-the-most-timed-scans-anchored-on-allunits)
satisfied by construction rather than by care.

The threshold is `1.5` because that is the figure the artillery observation gate already uses.
One number, one meaning; a second threshold elsewhere would drift.

### Decay is the feature

Confidence falls with the age of the stamp. An entry older than its horizon stops being a target
and starts being a guess, and the commander acts on the guess.

| Age of stamp | Treated as |
|---|---|
| under 5 min | current — full weight in scoring |
| 5-20 min | stale — weight falls off, still worth acting on |
| over 20 min | expired — dropped from the array |

Getting it wrong is what the player reads as intent. An enemy that is never wrong is one the
player concludes is reading the save file.

### What the enemy knows for free

The carve-out has to be explicit or it grows.

- **What it owns**: its towns, garrison tiers, hardpoints, its own wallet and tier.
- **Where the player HQ is.** The plan already grants this for artillery targeting
  ([`hardpoint_system_plan.md`](hardpoint_system_plan.md#indirect-fire-hardpoints)), and denying it
  would be a fiction — the enemy watched the player build it.
- **Which zones and FOBs the player holds**, since both are territorial facts with public
  consequences.

Everything about the player's *current position and strength* goes through belief. That is the
line, and anything that crosses it is a map hack whatever it is called.

## Appraisal: utility scoring, not search

Enumerate candidate `[sink, target]` pairs, score each, pick. No search, no plan, no chaining.

The candidate set is small by construction — towns in the OPFOR band, held zones, a handful of
corridors — so it is tens of pairs, not thousands, and a full pass is affordable every tick.

### Five terms

Five, and no more, or nobody will be able to tune it.

| Term | Reads |
|---|---|
| **value** | what the target is worth: zone worth, town AP income |
| **threat** | believed BLUFOR force near it, from the belief store alone |
| **vulnerability** | its garrison tier against that believed force |
| **reach** | distance from the nearest OPFOR-held ground |
| **price** | the AP cost, as a divisor |

Archetype scales the terms rather than gating the sinks, which is what
[`economy_plan.md`](economy_plan.md#the-commander-has-an-archetype) already committed to when it
chose weights over switches: Defensive weights value and vulnerability on ground it holds,
Aggressive weights threat and reach against ground the player holds.

### Weighted random over the top few, not the best

`selectRandomWeighted` over the highest-scoring three, not `argmax`. Argmax is deterministic and a
player reads it inside two campaigns; sampling among the top few keeps every decision defensible
while keeping the campaign unpredictable. It is also the mission's existing idiom —
`server/init_zones/fnc_createzone.sqf:142` picks prefabs with it. Zone vehicles are deliberately not
picked: the tier table names what a zone fields, so nothing rolls where a table could not see it.

**Banking is a candidate, not a policy.** A "spend nothing" entry with a low flat score loses
whenever anything sensible is affordable and wins when everything else has saturated. That is what
makes a forced-spend rule unnecessary, and a rule is what would make the commander predictable.

## Commitment: intents are sticky

A chosen action becomes an intent record and stays one until it completes, dies, or expires.
Re-scoring next tick fills free capacity; it never cancels a live intent.

| Field | Holds |
|---|---|
| type | which sink |
| target | index into the registry the sink acts on |
| expiry | `time` plus the intent's own lifetime |
| state | ordered / in progress / done |

This is the layer naive utility systems omit and always regret. Without it a commander
re-evaluating every tick oscillates between two near-equal options and reads as noise, which is
worse than the fixed thresholds the WARCOM spawners were deleted for.

It is needed for an unrelated reason anyway: whether a withdrawing group is still a valid target for
the director's reinforcement logic. That is an intent-ownership question and has no answer until
intents exist — a withdrawing group is one whose intent has been released.

Numbers and strings only, for the same serialisation reason as the belief store, and `time` rather
than `diag_tickTime` so an expiry survives a savegame
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

## Why not GOAP

Goal-Oriented Action Planning searches for the *chain* between a world state and a goal, and the
chain is the product. Three reasons the commander has no chain to find:

- **The sinks do not compose.** Buying a garrison at one town does not enable a QRF, and building a
  hardpoint does not enable rapport. They are parallel actions sharing a wallet, so a planner over
  them degenerates to picking the cheapest action that satisfies the goal — a one-step utility
  choice carrying a search's machinery.
- **The decision is spatial, not symbolic.** The question is never "garrison or QRF" but *which
  town*. A symbolic planner answers that by multiplying operators by targets — four sinks against
  twenty towns is eighty before zones are added — or by pushing target choice into the action's
  execution, at which point the planner has stopped deciding the thing that matters.
- **Replanning is the cost, and it lands in the worst place.** GOAP replans whenever the world
  state moves. Scheduled scripts share about 3 ms per frame between them
  ([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)),
  so a node-expansion loop settles at roughly one expansion per frame. It can be escaped by
  batching, but the batching would be funding a search with nothing to search.

There is also a horizon mismatch: the hardpoint build tick is 20-30 minutes, and a three-step plan
over that horizon is invalidated by the player before its second step.

**Planning would earn its keep one layer down, not here** — a single squad ordered to retake a town
deciding mount, route, dismount, assault. That layer is worth hand-authoring as an explicit state
machine rather than searching.

An **influence map** — a coarse grid holding decayed per-side influence — is the standard upgrade
to the *reach* and *threat* terms, and it would produce the front line as a by-product, which is
what [`hardpoint_system_plan.md`](hardpoint_system_plan.md#siting) currently approximates by hand
with "35-65% along the segment between an OPFOR zone and the nearest BLUFOR anchor". It buys better
siting and nothing else, so it is an upgrade path rather than part of the first build.

## The loop against the engine

**One thread with a phase counter, not one per sink.** The hardpoint plan already made this call
for its monitor ([§Spawn, despawn and cost](hardpoint_system_plan.md#spawn-despawn-and-cost)); it
binds harder here, because `src/duws` carries 36 `while {true}` loops across 27 files today.

| Property | Value | Why |
|---|---|---|
| Outer tick | 60-90 s | Refresh belief, score, commit at most one thing. The sinks keep their own cooldowns; the tick decides only whether this is a spending tick |
| Scoring pass | inside `isNil { ... }` | Unscheduled, so it runs uninterrupted instead of being sliced at ~3 ms a frame. `server/misc/fnc_moreUrban_locations.sqf:134-152` is the worked example, bounded by a wall-clock deadline rather than an iteration count |
| Clock | `time` | Intent expiries and belief stamps have to survive a savegame |
| Orders | server-local groups only | Waypoints are silently ignored unless the group is local to the issuing machine |
| State | numbers, strings, arrays of those | No group or object handles anywhere near the mission namespace |

No `sleep` inside the `isNil` block — unscheduled code cannot suspend, which is also what makes the
scoring pass atomic against the rest of the mission.

Constants take the `#define` form the zone and town garrisons use, so the tuning surface is the top
of one file.

## What this settles elsewhere

Two of the economy plan's open questions dissolve rather than get answered, and both dissolve for
the same reason — they are questions about a rule set, and this is not one.

- **What the commander does with a surplus.** Add *reinforce an existing garrison* as a candidate
  action with a low base score. It loses while anything better is affordable and wins once the
  throttled sinks have saturated. No ceiling, no special case, and the player still sees the money
  spent.
- **Whether the commander should be required to spend.** No. Banking is a candidate that scores
  low, so a rich commander with nothing worth buying banks by arithmetic.

## Build order

Each phase is independently playable, and the ordering is forced by what the next phase reads.

| Phase | Contains | Why it is gated here |
|---|---|---|
| **Belief** | The four arrays, the sighting sweep, town and flip sensors, decay, a debug readout | Independently useful and independently testable — the artillery observation gate and the intel patrol both consume it, and it can be verified before a commander exists |
| **The loop** | One thread, the tick, the five terms, two sinks (garrison upgrade and hardpoint build), flat archetype weights | Smallest thing that produces visible enemy behaviour |
| **Intents** | The record, minimum lifetimes, release on completion or death | Lands with the third sink: taskings are where thrash starts costing |
| **Archetype** | The weight sets from [`economy_plan.md`](economy_plan.md#the-commander-has-an-archetype) | Tuning, and it needs the loop it modifies |

## Open questions

- **The tick interval against the sink cooldowns.** A 60-90 s tick against a 20-30 min build tick
  means most ticks decide nothing, which is cheap but means the commander's reaction time to a
  sighting is set by whichever sink it wants rather than by the tick. Whether QRF needs a faster
  path than the shared tick is a play question.
- **Whether the belief store should persist.** It is shaped to serialise, but a campaign resumed
  with the enemy's knowledge intact and one resumed with the enemy blind are different difficulties,
  and neither is obviously right.
- **What a co-op session does to the sighting sweep.** One call per player is cheap at four and
  still cheap at eight; the term that grows is the belief array, since each player is a separate
  entry and squads move together. Whether beliefs should be merged by proximity into one entry per
  *element* rather than one per player decides whether the strength term means anything.
- **Whether the player can perceive that the enemy is acting on stale information**, and whether
  that is worth surfacing. It is the difference between the mechanic working and the mechanic being
  appreciated, and the intel system is the obvious route.
