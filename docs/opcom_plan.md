# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure on the
player: it garrisons towns, tasks squads, builds hardpoints, and lets low-reputation towns fight
back. This document owns how it decides — what it wakes on, what it is allowed to know, how it ranks
one target against another — what it builds, and the town events it triggers. Its wallet, its sinks
and its archetype are the economy's ([`economy_plan.md`](economy_plan.md#opcom-the-opposing-commander)); the
shipped hardpoint mechanics it draws from are [`info/hardpoints.md`](info/hardpoints.md); the
standalone-siting economics already in play are
[`info/opfor_area_of_influence.md`](info/opfor_area_of_influence.md#band-siting).

## The three layers

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
([`info/hardpoints.md`](info/hardpoints.md#why-hardpoints-are-not-zones)): the mission namespace is the save
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
([§Observation is the trigger](#observation-is-the-trigger)): an object
reference re-resolves every tick and follows a player through a respawn, a taxi and a fast travel,
which is a map hack arriving by the back door.

### Sensors

Each writer is something the player can find and kill.

| Sensor | Writes | Cost |
|---|---|---|
| Direct sighting | `east knowsAbout _p > 1.5` stamps that player's position, group size and `time` | one engine call per player per tick |
| Observation post | an OP hardpoint covering ground stamps what it sees | the mechanic [§Observation is the trigger](#observation-is-the-trigger) specifies |
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
- **Where the player HQ is.** [§Indirect-fire hardpoints](#indirect-fire-hardpoints) below grants
  this for artillery targeting, and denying it would be a fiction — the enemy watched the player
  build it.
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
worse than the fixed thresholds the [WARCOM spawners](#rejected-the-opfor-spawners-this-replaces)
were deleted for.

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
to the *reach* and *threat* terms. The front line it would produce as a by-product is now produced by
the area-of-influence coverage field ([`opfor_area_of_influence.md`](info/opfor_area_of_influence.md)),
which sites standalone hardpoints in the OPFOR band and replaced the hand-drawn corridor an earlier
design once used. The *grid* itself is still
deferred: it buys a cheap "how contested is this whole region" read for scoring that a point-sampled
field does not, so it stays an upgrade path rather than part of the first build.

## The loop against the engine

**One thread with a phase counter, not one per sink.** The shipped hardpoint monitor already made
this call — one shared loop over the whole registry, not one thread each
([`info/hardpoints.md`](info/hardpoints.md#streaming-and-garrison)); it binds harder here, because
`src/duws` carries 25 `while {true}` loops across 19 files today.

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

## What the commander builds

`economy_plan.md` names the sinks and the wallet; this section is how the escalation ladder and the
indirect-fire assets behave once the commander is spending on them.

**This is the intended ladder, not the shipped director.** What shipped is deliberately simpler: a
uniform per-type garrison and three flat-priced build actions — raise a radio tower, top a zone back
toward its stored ring cap, fortify the band — priced `OPCOM_AP_TOWER`/`OPCOM_AP_TOPUP`/`OPCOM_AP_BAND`
([`info/opfor_area_of_influence.md`](info/opfor_area_of_influence.md#band-siting)), and nothing scales
garrison size to `WARCOM_opfor_ap` today
([`info/hardpoints.md`](info/hardpoints.md#streaming-and-garrison)). The ladder below is the
escalation this loop is meant to layer onto that director.

### The director and the escalation ladder

**The director pays to build; clearing refunds nothing.** Construction is one of the OPFOR Army
Power sinks in [`economy_plan.md`](economy_plan.md), so an emplacement competes with town garrisons
and tasking orders for the same points — that competition is the reason the sink exists. The refund
is what stays forbidden: cost-and-refund is farmable — build 25, clear −25, repeat, and the enemy's
pool never reaches the escalation thresholds that make it dangerous. Clearing pays the player CP and
returns the enemy nothing, so the only loop on offer is one that costs the enemy AP to run.

`WARCOM_opfor_ap` also decides **how hard a hardpoint is**, not just whether the director can afford
one. The patrol and assault spawners that used to step up at 10/40/65/100/136 AP
([§Rejected](#rejected-the-opfor-spawners-this-replaces)) have been deleted, so hardpoints would be
the first thing to put rungs back on the enemy's ladder rather than joining one already there — the
tiers below are proposed, not matched to a surviving precedent:

| Highest OPFOR AP reached | Garrison, any hardpoint | Types the *director* may build |
|---|---|---|
| < 40 | 2-3 infantry | OP, MG |
| 40-99 | 3-4 infantry, one armed car in support | + AT |
| 100-135 | 4-5 infantry, an APC parked on the position | + AA, mortar pit (max 2 alive) |
| 136+ | 4-5 infantry, MBT if `HeavyArmor == 1`, else APC | + artillery battery (max 1 alive) |

The unlock order tracks what the player fields. AT arrives once they are buying vehicles, AA once
they are flying, and the artillery battery only at the top, because it is the one type whose
position barely constrains what it can reach.

**The unlock column binds the director only.** Everything placed at generation — every zone
hardpoint and the seed subset — rolls from the full type list whatever OPFOR AP happens to be at
campaign start. AP gates what the enemy can *newly field*, not what was already dug in when the
player arrived, and gating generation would make the first hours of every campaign a tour of
identical MG nests.

The garrison column still applies to all of them, because composition is read at spawn rather than
at placement. So an AA position generated in hour one is a real gun with a thin crew, and the same
position revisited in hour five has armour parked next to it. The emplacement is what the map
rolled; the troops around it are what the war has become.

**The ladder is a composition table, not a bespoke list.** OPFOR garrisons are token compositions
now — a row of `posture:token` entries resolved against the team, vehicle and special tables in
`server/init_zones/fnc_zone_spawn_sizes.sqf:115-121,308-314,345-358`, scaled, attrition-thinned and
raised by `DUWS_fnc_raiseGarrison` (`:242`). A hardpoint tier belongs in that file as its own small
table beside the zone one, for three reasons: the vehicle rows already name faction roles rather
than classnames, so a hardpoint late in a campaign is defended by whatever the enemy fields
everywhere else; the row's `setting` column already answers `HeavyArmor`; and a fenced table is
editable through the composition TUI, where a list hardcoded in a placer is not
([`info/composition_tooling.md`](info/composition_tooling.md)).

**Composition is read when the garrison spawns, not when the hardpoint is built.** With garrisons
distance-gated ([`info/hardpoints.md`](info/hardpoints.md#streaming-and-garrison)), a hardpoint the
player walks past in hour one and returns to in hour five is defended at hour five's strength. That
is what makes the ladder felt: the map does not get more hardpoints so much as harder ones, and it
costs nothing to implement, because the spawn already happens on approach.

**It reads the tier, not the pool.** Both columns key off the highest AP the enemy has reached,
never its current balance — otherwise paying for one hardpoint thins the garrisons of every
hardpoint already standing, and the player watches the war get easier because the enemy invested
in it.

That is not what the existing tables do. `DUWS_fnc_tokenClass` gates a vehicle token on the
*current* `WARCOM_opfor_ap` (`fnc_zone_spawn_sizes.sqf:211,354`), so a zone raised the moment after
the commander spends fields less armour than the same zone raised a minute earlier. Nothing tracks a
high-water mark today, so one of the two has to give: either this tier accepts the existing rule, or
a high-water global is written once and both read it. Two rules for one idea is the outcome to
avoid, because the difference is invisible in play and only shows up as a zone that got easier.

| Knob | Value | Why |
|---|---|---|
| Seed subset | 2-3 at WARCOM init, any type | The player meets the mechanic before the director has produced anything |
| Build tick | one candidate every 20-30 min | Slow enough that the map changes between visits rather than while the player is looking at it |
| Build gate | OPFOR AP above 10 | A suppressed enemy stops fortifying |
| Build costs | 8-25 AP by type | Cheapest for an OP or MG nest, dearest for the battery — the same order the clear payouts run in |
| Live cap | none | live AI is bounded by player proximity, not a count ([`info/hardpoints.md`](info/hardpoints.md#streaming-and-garrison)) |
| Clear pays | CP only | Missions and zone capture remain the AP faucets (`fnc_mission_reward.sqf:19`, `fnc_captured.sqf:38-41`) |

## Indirect-fire hardpoints

The types that justify the hardpoint tier: persistent enemy assets that act on the campaign, so
destroying one changes the player's situation rather than incrementing a counter. Two tiers, sharing
one fire-mission implementation. None of the fire missions below ships today — the mortar and
artillery cores exist as clearable emplacements
([`info/hardpoints.md`](info/hardpoints.md#hardpoint-types)) but do not run missions; this is the
behaviour the commander loop is meant to give them.

**A zone's own mortar is a different thing and stays as it is.** Several zone prefabs site a tube
that `fnc_static_resolve` turns into whichever mortar the holding faction fields, and its fire is
whatever the engine's AI decides on its own. It belongs to the prefab, it is crewed by the zone's
manning pass, and it is not counted against the caps below. What is capped is the emplacement kind:
a sited, crewed, map-marked gun that keeps firing while nobody is there.

Real crewed guns, not a virtual effect. `doArtilleryFire` must be issued from the machine where the
gun is local, and both are server-spawned, so the server issues it — the same locality rule that
silently broke `fnc_helolift`
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)).

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static mortar, `opfor_TURRET_MORTAR` | self-propelled gun, `opfor_ARTY_X` |
| Unlocks at | 100 AP | 136 AP |
| Reach | whatever the piece has | whatever the piece has |
| Cooldown | 4-8 rounds, then 25-40 min | 6-10 rounds, then 40-60 min |
| Scatter | tighter | wider |

**Reach is the gun's, not a design constant.** `inRangeOfArtillery` decides what a piece can touch,
so a mod faction's heavier tube simply reaches further and a light one does not. What keeps a
long-ranged battery from making its own position irrelevant is not a distance cap — it is that
nothing fires at what the enemy has not seen.

**The battery is a vehicle, so it needs pinning.** `disableAI "PATH"` on the crew plus
`allowFleeing 0`, or it relocates and the marker lies. Killing the crew leaves an intact gun the
player can take, and the unmanned clause already counts that as cleared
([`info/hardpoints.md`](info/hardpoints.md#clearance)) — capturing one is a legitimate prize for a
hard fight, and the recycle station will pay for it (`fnc_activateBaseRecycleStation.sqf`, a
documented ownership-free faucet in [`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md#economy-balance)).

Everything below applies to both.

| Property | Rule |
|---|---|
| Target set | BLU-held zone centres, FOB positions, players in the open, each only while observed. **Never** aimed inside the 100 m HQ circle |
| Range gate | `_gun inRangeOfArtillery [[_pos], _mag]`, and nothing else |
| Willingness | a roll per opportunity, not a schedule ([§Chance to fire](#chance-to-fire)) |
| Accuracy | deliberate scatter, scaled by range and by how well the target is observed ([§Scatter](#scatter)) |
| Ammo | finite (`setVehicleAmmo`); a gun that runs dry goes quiet |
| Telegraph | Allseer radio line plus a temporary marker ~20 s before impact |

**The HQ is the one standing exception, in the other direction.** The enemy plainly knows where the
player's main base is, so the observation rule would permit shelling it. It is excluded anyway: the
HQ is the one position the player cannot abandon, cannot move, and cannot leave unoccupied, so fire
on it is attrition against a fixed address rather than a fight. Assault waves already pressure the
base and can be met.

The exclusion is on the **aim point**, over a 100 m radius around `PosOfBLUHQ`. No fire mission may
be *aimed* inside it. Rounds may still land there: a barrage aimed at a player 200 m out will spill
onto the base once scatter is applied, and that is intended — what is denied is deliberate, accurate
fire on a fixed address the player cannot move. Being near the base is not immunity, and stray
rounds in the motor pool read as a war rather than as a rule. Define the constant once and let both
the target filter and the pre-fire re-check read it.

### Observation is the trigger

Nothing is shelled that the enemy has not seen. That single rule replaces every range cap: a gun
with map-wide reach is still blind without eyes, so **the spotter's position is what decides what
gets hit**, and spotters are things the player can kill.

The test differs by target kind, because the engine only tracks knowledge of *objects*:

| Target | Observed when |
|---|---|
| Player or player-driven vehicle | `east knowsAbout _unit` above roughly `1.5` — side-wide, so a patrol that saw the squad counts and a corpse does not |
| BLU-held zone or FOB | an OP hardpoint covers it, or an OPFOR element has been within ~500 m in the last 15 min |
| Anything inside the 100 m HQ circle | never aimed at, whatever the enemy knows |

Observation posts are therefore the artillery's eyes, and killing them blinds guns without touching
them. A battery with no spotter in the area is a stationary target that never fires, which is exactly
the counterplay the type needs: the player can answer artillery without being able to reach it. This
is the same belief the perception layer above maintains — the `1.5` threshold is shared with the
sighting sweep so a second one cannot drift.

The target grid is **latched when the mission is ordered**, never tracked. A mission stores `[x,y,0]`
copied at order time and never an object reference, because an object reference re-resolves every
tick and a position cannot move. Rounds land where the player *was*, so moving is always the answer
and standing still is what gets punished.

That is not only a fairness rule, it is what closes the back door into the HQ exclusion: a player who
is spotted, killed, and respawns at base would otherwise be *followed* there, and the rounds would
arrive at the one place nothing is allowed to shell. Fast travel, an MHQ respawn and a taxi
extraction all produce the same jump. Storing a position immunises against every one of them at once,
and a dead or deleted target leaves no null handle to guard. Belt and braces: the fire mission
re-checks its latched grid against the HQ circle immediately before firing and drops the mission if
it falls inside — that covers the case the latch cannot, a player spotted while standing at home.

Guarantees on top: no fire within 300 m of the gun itself, no player-directed mission before the
first zone is captured, and the per-gun cooldown, so a squad cannot be walked from one barrage into
the next.

### Scatter

`doArtilleryFire` converges after ranging rounds, so an untreated AI gun is a sniper. Rounds are
offset from the aim point by a deliberate radius, and the size of that radius is where observation
quality becomes something the player can feel rather than a boolean:

| Term | Effect on the radius |
|---|---|
| Base | mortar pit tighter than battery |
| Range to target | grows with distance, so a gun at the edge of its reach is guessing |
| Observation quality | shrinks with `knowsAbout`, or with an OP holding direct line of sight |

So the same battery is dangerous when an OP overlooks the target and a nuisance when a patrol merely
passed through last week. It also means the first mission of a barrage is the least accurate, which
reads as the enemy walking their fire in. Starting values worth tuning in play rather than deriving:
50 m base for a mortar, 100 m for a battery, +25 m per kilometre of range, −30 m with direct
observation.

### Chance to fire

A gun off cooldown with a valid observed target does not fire on a schedule — it rolls. Roughly 40%
for a mortar pit and 30% for a battery, evaluated every five minutes. Predictable shelling is either
ignorable or oppressive: a player who can set a watch by it either routes around it forever or
resents it. A roll turns the same average cadence into a risk the player weighs each time they cross
open ground, and it costs one `random` call. The cooldown only starts when a mission actually fires,
so a quiet gun is a gun waiting for a chance, not a broken one.

The telegraph is not politeness. Without it the mechanic reads as random damage rather than as
"there is a mortar out there and I should find it", which is the entire point of making the gun a
real object. It works with the visible markers: a player under fire can see on the map which
emplacement is doing it, so the counterplay is legible from the first barrage. Finite ammo also gives
an OPFOR resupply run something to be for: intercepting it silences guns the player cannot reach.

**Fallback if AI static-mortar fire proves unreliable:** spawn the shells directly, as the player's
own artillery support does (`client/supports/fnc_arty.sqf` creates rounds at 800 m altitude with a
downward velocity). Player-facing behaviour is identical and the AI dependency disappears, at the
cost of the gun becoming scenery. Try the real gun first; [§Open questions](#open-questions) records
what has to be verified.

### The indirect-fire types are capped campaign-wide

**One artillery battery and two mortar pits, alive at once, across the whole map.** The cap spans
both flavours: a zone that rolls a mortar pit consumes one of the two, and the director cannot build
a battery while one already stands. Clearing one frees its slot, so destroying the battery buys quiet
until the enemy fields another rather than ending indirect fire for the campaign. No such cap is
enforced today ([`info/hardpoints.md`](info/hardpoints.md#hardpoint-types)); it lands with the fire
missions above.

Three reasons the number is this small:

- **Indirect fire is the only threat that reaches past the fight the player chose.** Rare enough to
  be an event, and destroying one should feel like removing something from the war.
- **These are the only hardpoints with permanent crews.** Three guns is six or so units that never
  despawn — a bounded cost, where an uncapped count would not be.
- **The other types are already bounded by the player's own movement.** Only these act at range, so
  only these need a number.

**If AA is ever made resident, it needs its own cap for the same reason.** The shipped AA streams
like any other type, waking early on a 5,000 m air ring rather than staying resident
([`info/hardpoints.md`](info/hardpoints.md#streaming-and-garrison)). Were it pinned resident to
guarantee it engages what crosses its ring in seconds, it would be a fourth permanent-crew type and
would reintroduce exactly the unbounded live-AI growth this cap exists to prevent.

## Rejected: the OPFOR spawners this replaces

WARCOM ran three OPFOR threads of its own — roaming patrols, attack waves and random air — and all
three are gone. They are recorded because the director will be asked to produce enemy pressure, and
this is the shape it must not take.

They shared one structure: a type-picker thread walking an Army Power ladder with `waitUntil`, and
a main loop sleeping a fixed interval and spawning whatever the picker happened to hold. Patrols
and waves used the same ladder.

| OPFOR AP | Type spawned |
|---|---|
| below 40 | `opfor_INFTEAM_X` |
| above 40 | `opfor_INFSQUAD_X` |
| above 65 | `opfor_INFWEPSQUAD_X` |
| 100-135 | weighted roll: armed car, APC1, APC2 at 1.0, AA APC at 0.5 |
| 136+ | the same roll plus `opfor_MBT_TANK1_X`, and only when `HeavyArmor == 1` |

Cadence and gating differed:

| Thread | First spawn | Interval | Bound |
|---|---|---|---|
| Patrol | ~4 min after init | 45-90 min | `floor (count serv_zones_array / 2) + 1` spawns for the whole campaign — the counter only ever incremented, so it bounded lifetime spawns, not live ones. OPFOR holding 2+ zones |
| Assault | 30 min | 30 min against zones, 30-60 min against the HQ | Two groups per cycle, 120 s apart |
| Air | on reaching AP 150 | 20-40 min | Two live airframes, counted by `alive`; `AttackHeli` enabled |

Three behaviours in them are worth rebuilding as commander decisions rather than thresholds:

- **Target selection.** The assault waypoint helper sorted BLUFOR zones by distance from the group
  and queued a MOVE at each, falling back to `WARCOM_blu_hq_pos` when the player held no zones.
  This was the only genuine decision in the three files; everything else was a clock.
- **Dismounts.** Above AP 100 both spawners built a second `opfor_INFTEAM_X` and `joinSilent`ed it
  into the vehicle group, so armour never arrived alone. Worth keeping as a composition the
  commander buys, not as something an AP threshold grants for free.
- **The ammo truck.** A separate 45-90 min timer inside the patrol loop ran `opfor_AMMO_TRUCK_X`
  along the patrol route and announced it over Allseer, handing the player an interdiction target.
  It is the germ of the Supply tasking.

Four properties are why they could not stay:

- **Nothing terminated.** The patrol waypoint helper closed its route with a `CYCLE`, so a group
  circulated between zones for the rest of the campaign — no despawn, and no ceiling on how much
  simulation accumulated behind the player.
- **The cadence was unconditional.** The loop never asked whether a patrol was wanted. The sleep
  expired and something spawned.
- **AP was read, never spent.** Every gate was a comparison, so the ladder was a one-way ratchet:
  enemy field strength could rise and never fall, whatever the player did to it.
- **They aimed away from the player.** Patrol and air required their chosen zone to be over 1500 m
  from every player, the assault its spawn position. Contact happened only when the player drove
  into a group that had been sited to avoid them, which is the reverse of a director planning
  against where the player will be.

## Town events: what a turned town does

Where the player has driven a town into the OPFOR band, the enemy uses it: IEDs on the approach
roads, ambushes on patrols passing through, sabotage against nearby FOBs and parked vehicles.
Reputation stops being a modifier on civilian spawn behaviour and becomes the input to an actor that
plans against the player. The per-town reputation change deleted the two mechanics that did this job
badly; they are recorded below because they are the raw material the director is meant to rebuild.

Decided:

- **Events are free and rolled, not bought.** Reputation is the whole input: a town deep enough
  into the OPFOR band generates them on its own, and the commander that buys garrisons, taskings
  and hardpoints neither funds them nor schedules them
  ([`economy_plan.md`](economy_plan.md#what-the-commander-spends-on)). Charging Army Power for
  them would price a thing the player has already paid for by letting the town fall.
- **Rapport moves a town's reputation; events are what a low reputation does.** Both act on a town
  in the OPFOR band, so the division has to be stated or the two drift into each other. Rapport is
  the commander's purchased way of dragging a town down; events are the free consequence of it
  already being down.
- It acts on towns in the OPFOR band (reputation `<= -10`), the same band that pays OPFOR Army
  Power and spawns a garrison.
- It plans outside the town's presence trigger. The civilian handler runs only when a player is
  inside the radius; a director that can only act then cannot mine a road ahead of the player.
- Events are attributed to the town, so clearing that town's garrison damps its events by lifting
  its reputation a step. It no longer stops them outright: a clear is worth `+5` rather than a
  discharge, so a town driven to `-20` is still deep in the band after one
  ([`info/zones_and_civilians.md`](info/zones_and_civilians.md#what-clearing-a-garrison-actually-buys)).

### Preserved: hostile civilian conversion

Ran at town spawn when reputation was negative, in the civilian handler. The code is gone; what it
did is recorded here because the director is meant to rebuild it.

| Property | Value |
|---|---|
| Count | `(abs rep * 3) min _totalGroups`, then capped at `floor (0.7 * _totalGroups)` |
| Selection | the first N groups of the town's spawned groups |
| Side | re-sided to `resistance` via a fresh group, old group deleted |
| Armament | one entry from an 8-weapon pool of civilian-plausible small arms — PDW2000, AKS, SMG_05, both Hunter shotguns, DMR_06, P07, Pistol_01 — plus three magazines |
| Interaction | `removeAllActions` locally and on every client, so no recruit/heal prompts remain |
| Reputation | `isHostile` set true, which exempts their death from the civilian-death penalty |

The 70 % ceiling means any town at or past `-7` was already saturated; the `abs rep * 3` term
only mattered between `0` and `-7`.

### Preserved: suicide bombers

Ran immediately after conversion, in the same spawn pass, with the behaviour itself in a
`fnc_civ_suicideBomberBehaviour` helper. Both are gone.

Selection: `ceil (count _resistanceUnitsInTown * 0.1)` — a tenth of the converted hostiles,
which is why deleting conversion silently zeroed this too. Candidates were civilian-sided units
in the same town not already flagged, shuffled, each moved into its own `deleteGroupWhenEmpty`
civilian group.

Behaviour, a 0.5 s loop while alive:

| Range to nearest player | Behaviour |
|---|---|
| > 10 m | civilian-sided, `CARELESS`/`BLUE`, fleeing disabled, random speed mode; 90 % walks at the player, 10 % wanders to a point 50–200 m off |
| <= 10 m | re-sides to `EAST`, `isHostile` set true, switches to `COMBAT`/`RED` |
| <= 5 m | spawns `Bo_GBU12_LGB` at its own position, broadcasts a hint, calls the shared civilian killed handler |

**Two properties any replacement must keep.** First, `isHostile` is what decouples *this
civilian is a threat* from *killing this civilian is a war crime* — without it the player is
penalised for defending themselves, and the reputation spiral becomes unrecoverable. Second,
the side flip happens at 10 m but detonation at 5 m, which is deliberately a window: the bomber
becomes a legal target before it becomes lethal. An IED or ambush event that skips either
property is a trap, not a mechanic.

`VCOM_Disable` was set on the unit so an AI mod could not override the approach behaviour. Any
scripted-movement event needs the same.

## Persistence

The commander is campaign state, and the campaign snapshot
([`campaign_persistence_plan.md`](campaign_persistence_plan.md)) carries the part of it that a single
function can rebuild from numbers and strings. Live squads, spawned garrisons and in-flight fire
missions are never saved — they regenerate on player approach like everything else in a restored
campaign. What the commander contributes to the snapshot:

| State | Kind | Contract |
|---|---|---|
| Archetype | input | The one string rolled at OPCOM init. Restore feeds it back before the loop runs and never re-rolls it, or the war the player has been fighting changes under them ([`economy_plan.md`](economy_plan.md#the-commander-has-an-archetype)) |
| Standing orders (taskings) | outcome | One row per order — type, target, budget already spent. Persisted as orders, not squads: the squad was live state the director was spawning anyway, so restore re-issues the order to the next squad the director spawns. Storing anything about the squad would store a group handle |
| Tiers | outcome | `OPCOM_opfor_tier` and its earned counter, owned by [`economy_plan.md`](economy_plan.md#the-ratchet-is-otherwise-structural-and-only-in-half-the-read-sites); the archetype rides in the snapshot beside them |

Every persisted field is a number, a string, or an array of those — the same rule the belief store
and the intent records already follow ([§Shape](#shape), [§Commitment: intents are sticky](#commitment-intents-are-sticky)),
because the mission namespace is the save file. Time-based fields store on `time` and are written as
remaining durations, never absolute stamps: `diag_tickTime` restarts with the process, so an absolute
stamp sits in the future in the next session
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

**Whether the belief store persists is open.** It is shaped to serialise, so carrying it costs
nothing to build — but a campaign resumed with the enemy still knowing where it last saw the player
and one resumed with the enemy blind are different difficulties, and neither is obviously right. It
stays out of the snapshot until that is decided ([§Open questions](#open-questions)); a restored
campaign that omits the key simply rebuilds belief from its first sensor pass. Because the snapshot
is a name-keyed hashmap, adding the key later shifts nothing an older save's readers see.

## Naming: WARCOM becomes OPCOM

The system is renamed **OPCOM** (Opposing Commander) when it lands, globals included:
`WARCOM_opfor_ap` becomes `OPCOM_opfor_ap`, and so on across the prefix.

WARCOM is inherited naming and describes what the system was — a mirrored pair of spawn timers,
one per side. It no longer describes either half. BLUFOR's commander is the player: task forces
provision at the HQ, wait on `blu_taskforces_standby`, and move only when the player issues a
launch order and clicks a target (`server/warcom/fnc_blu_taskforces_launch.sqf`,
`client/warcom/fnc_WARCOM_mapclick_assault.sqf`). OPCOM is the actor this document
describes. Naming the enemy is what distinguishes the mission from the versions it descends from.

Two constraints on when the rename lands:

- **It breaks saves.** The engine snapshots `missionNamespace` by variable name, and the campaign
  snapshot ([`campaign_persistence_plan.md`](campaign_persistence_plan.md)) keys on name too, so a
  renamed broadcast global reads back `nil` in a campaign resumed across the change. The AP rework
  already breaks the format; landing both in one release makes the player cross one broken-save
  boundary instead of two.
- **The zone-control arrays are the wide part.** `WARCOM_zones_controled_by_OPFOR` and
  `WARCOM_zones_controled_by_BLUFOR` account for roughly 50 references across 21 files, and index
  0 of the OPFOR list is the primary assault target. A mechanical replace across
  `server_fnc_init.sqf` and `server_var_init.sqf` also has to leave `fnc_zone_state_init` loading
  before any zone spawns.

Player-facing exposure is three boot-time strings, so the rename is almost entirely internal.

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
| **Town events** | The rebuilt hostile-conversion and IED/ambush/sabotage behaviours, rolled off reputation outside the presence trigger | Reads the belief store and the OPFOR-band definition the loop establishes; the free consequence of a turned town, not a sink |

## Open questions

- **The tick interval against the sink cooldowns.** A 60-90 s tick against a 20-30 min build tick
  means most ticks decide nothing, which is cheap but means the commander's reaction time to a
  sighting is set by whichever sink it wants rather than by the tick. Whether QRF needs a faster
  path than the shared tick is a play question.
- **Whether the belief store should persist.** It is shaped to serialise
  ([§Persistence](#persistence)), but a campaign resumed with the enemy's knowledge intact and one
  resumed with the enemy blind are different difficulties, and neither is obviously right.
- **What a co-op session does to the sighting sweep.** One call per player is cheap at four and
  still cheap at eight; the term that grows is the belief array, since each player is a separate
  entry and squads move together. Whether beliefs should be merged by proximity into one entry per
  *element* rather than one per player decides whether the strength term means anything.
- **Whether the player can perceive that the enemy is acting on stale information**, and whether
  that is worth surfacing. It is the difference between the mechanic working and the mechanic being
  appreciated, and the intel system is the obvious route.
- **Whether an AI gunner in a static mortar or a self-propelled gun reliably executes
  `doArtilleryFire`.** Nothing in the mission has ever issued it — `doArtilleryFire`,
  `commandArtilleryFire` and `inRangeOfArtillery` appear nowhere in the tree, and the mortar a zone
  prefab sites fires on the engine's own judgement. Verify with a throwaway console test before
  writing the indirect-fire missions above; if the answer is no, the shell-spawn fallback
  (`client/supports/fnc_arty.sqf`) becomes the implementation and the gun is a target rather than a
  weapon, which is a different feature wearing the same name.
- **The town-event roll itself:** what rate a town at `-10` generates events at against one at
  `-20`, and whether the curve between them is worth having or the band alone should decide.
- **Whether the regroup hold silences events along with the garrison.** A town that keeps mining
  roads while it visibly has nobody in it is either a good scare or an obvious tell.
- **Whether IED placement is persistent terrain state or spawned per approach**, and how it
  interacts with despawn.
- **Whether ambush groups count against the same population caps as civilians**
  (`civ_maxSpawnPerVisit`) or against the WARCOM wave budget.
</content>
</invoke>
