# Presence streaming: unification plan

Five systems in this mission answer the same two questions — *are players near this place* and *what
should be standing here when they are* — and each answers them in its own code. This plan makes that
one system: a **site** carries **occupants**, and puts them away when nobody is near by streaming them
off the map or by freezing them where they stand. Everything that differs between a zone garrison, a
town crowd and a FOB's turret ring becomes an occupant kind, a disposal mode, or a row in a table.

The codebase already reached this conclusion twice and stopped short both times.
`server/misc/fnc_garrison_strength_init.sqf:6-10` keys attrition by a string, `zone_<x>_<y>` or
`town_<n>`, on the grounds that "a zone and a town differ in what they *are* — one has an owner, the
other an opinion — but not in how a garrison wears down". `server/misc/fnc_civ_handler.sqf:7-9` opens
by saying that per town it *is* the enemy zone gate from `fnc_spawnWait`. Both observations were
written down and then implemented separately anyway.

How these systems behave today, and what a player sees:
[`info/zones_and_civilians.md`](info/zones_and_civilians.md).

## The shape, written five times

| | Zone garrison | Town garrison | Town crowd | Zone props | FOB |
|---|---|---|---|---|---|
| Owner | `fnc_spawnWait.sqf` + the tail of `fnc_createzone.sqf` | `fnc_civ_garrison.sqf` | `fnc_civ_handler.sqf` | `fnc_composition_stream_init.sqf` | `fnc_guardsFOB.sqf`, `fnc_fortifyFOB.sqf` |
| Threads | 2 permanent per zone + 1 per raise | 1 for all towns + 1 per raise | 1 for all towns + 1 per fill | none — driven by the zone | none |
| Poll | 10 s (`:201`) | 30 s (`:150`) | 10 s (`:23`) | n/a | n/a |
| Arrival | radius + 400, 2 AI or 1 player | radius + 400 | radius + 200 (`:35`) | n/a | **never — it just stands** |
| Confirm | 5 s sleep, re-test | 5 s sleep in the worker | two consecutive polls | n/a | n/a |
| Grace | 120 s (`:26`) | 120 s (`:54`) | 60 s (`:30`) | with the zone | none |
| Slow part | spawned band | spawned raise (`:62`) | spawned fill (`:66`) | n/a | n/a |
| Teardown | roster delete | roster delete | tag scan over `allUnits + allDeadMen` (`:171-179`) | **stow, not delete** | none |

Three of them independently arrived at "the slow part cannot run inside the loop that holds every
other site's clock, so dispatch it to a worker and adopt the result later". That is the most
distinctive thing about the shape, and three separate authors reached it.

The FOB column is the one that never got the shape at all: a FOB's guards and turret ring are spawned
when it is built and stand for the rest of the campaign. A ten-FOB campaign carries every FOB's
garrison permanently, wherever the players are.

## What is already general, and stays

**Object membership and streaming.** `fnc_duws_keep` files an object under a site key and marks it
persistent; `fnc_duws_stow` and `fnc_duws_deploy` take a whole key's objects out and put them back
(`server/misc/fnc_composition_stream_init.sqf:38,88,140`). Membership is already used by four site
kinds — HQ, MHQ, FOB and zone prefabs — so the *keying* is general. Only zones ever call the streaming
half (`fnc_spawnWait.sqf:145,194`), which is the same story as the unit side: a general mechanism with
one caller.

`_pinned` is the precedent this plan builds on. A composition member can declare that its effect
depends on existing rather than on being looked at — an artillery piece, an AA gun — so streaming it
would remove a capability rather than defer a cost (`fnc_composition_stream_init.sqf:33-37`). That is
already a per-occupant streaming rule, written for exactly the reason this plan needs them.

**Composition plumbing.** `DUWS_fnc_raiseGarrison`, `fnc_spawn_team`, `DUWS_fnc_teamRoster`,
`DUWS_fnc_spawnDiff`, `fnc_zone_thin` and the strength store are the layer the lifecycle sits on.

## The model

### A site

A keyed place with a position and a radius that streams occupants on player presence. Zones, towns,
FOBs, the HQ, and hardpoints when they exist. Its key is the one already in use: `zone_<x>_<y>`,
`town_<n>`, `FOB_<n>`, `HQ`.

A site holds **one record per occupant it carries**, so a town is one site with two occupants — a
crowd and, when the reputation band says so, a garrison — rather than two systems that happen to share
a radius.

### An occupant kind

Kinds differ in what they are made of and how they come and go. Everything else is data.

| Kind | Made of | Teardown | Attrition | Counts for a clear | Capped |
|---|---|---|---|---|---|
| `infantry` | men on foot | delete by roster | yes | yes | no |
| `garrison` | men inside buildings | delete; sheds whole buildings when thinned | yes | yes | no |
| `vehicle` | a vehicle and its crew | delete together, crew first | yes | yes | no |
| `emplacement` | a static weapon and its crew | **crew deletes, the weapon stows** | crew only | yes | no |
| `structure` | props, walls, a prefab | **stow only, never deleted** | no | no | no |
| `crowd` | civilians | delete by roster | no | no | **yes** |

Teardown above is what a **streamed** site does with each kind. A frozen site does none of it.

`emplacement` is the row that explains why the split is by *what is streamed* rather than by side or by
system. A zone's turret is one object and one man, and they do not stream the same way: the weapon is
campaign property that belongs to whoever holds the ground, and the man is a defender. Today that
split is expressed by `_manStatics` crewing the guns on deploy and `_stowZone` crewing them out before
the stow (`fnc_spawnWait.sqf:45,140`) — correct, and written twice inside one file because nothing
named the rule.

### Disposal: a site streams, or a site freezes

**What happens when the players leave is a property of the site, not of the kind.** A zone's infantry
is deleted and a FOB's infantry is frozen, and they are the same kind — so the strategy sits one level
up.

| Mode | Sites | What happens |
|---|---|---|
| `stream` | zones, towns | occupants are taken off the map: men deleted, structures stowed |
| `freeze` | **the HQ and every FOB, and nothing else** | everything stays exactly where it is with simulation off |

Under `stream`, the kind decides which half applies:

- **Delete** suits anything cheap to rebuild and meaningless while unobserved — men, crowds, crews.
  What was lost is remembered as attrition rather than as objects.
- **Stow** suits anything the player will meet again unchanged — a prefab, a turret. Rebuilding those
  from scratch would restore damage the player did.
- **Pinned** suits anything whose effect is its existence — artillery, AA. Already modelled
  (`fnc_composition_stream_init.sqf:33-37`).

Under `freeze`, none of that applies and nothing is rebuilt. `fnc_FOBgarrisonSleep.sqf:7-12` already
states why, and the reasoning is the whole justification for the exception:

> *"A zone garrison belongs to OPFOR and is rebuilt from a table, so deleting it loses nothing. A
> FOB's belongs to the player: rebuilding it would hand back every soldier who had been killed, which
> is a free version of the 2 CP redeploy bought by walking away for two minutes. Freezing keeps each
> unit's identity and damage, and simulation is where nearly all of an idle soldier's cost sits."*

A player's base is not a composition to be re-derived. Its garrison is a thing they paid for, lost men
from, and may have re-equipped; its buildings carry damage; and a FOB is a respawn point, so it has to
be able to receive a player who arrives in an instant with no approach to notice. Freezing satisfies
all three, and it is why the HQ and FOBs are the only sites that do not stream.

**Only registered occupants freeze.** A vehicle the player parked at base is their property and not
the site's, so it is left alone — which also keeps the freeze off anything the base-keep radius in
`fnc_repetitive_cleanup` already exists to protect. A FOB itself owns no vehicles: its `createVehicle`
calls are the building, the fortification props and the turrets, so its occupants are guards
(`infantry`), the turret ring and its crews (`emplacement`) and the structures.

**Assumed: a frozen unit comes back correctly.** `enableSimulationGlobal false` stops AI, physics and
animation, and the whole exception rests on a unit resuming cleanly from it — mid-animation, mid-path,
or standing at a turret. The existing FOB freeze has never been played against, so this is taken as
true and listed as untested rather than treated as an open design question; if it turns out false, the
answer is not a different disposal mode but a thaw that re-issues orders.

### Waking a frozen site takes either side

A streamed site wakes on **players**. A frozen site must wake on **players or hostiles**, because a
garrison that cannot be woken by an attacker is a garrison that loses its base while nobody is
looking. Today's implementation is players-only, and its comment explains why the shared test could
not be used:

> *"fnc_duws_bluforNear is the shared test everywhere else, and it cannot be used here: its AI arm
> exists to notice BLUFOR arriving on OPFOR ground, so at a friendly base it would count the garrison
> standing in the middle of the radius and never let it sleep."*

Right diagnosis, half a fix. The missing half is a hostile count, which `fnc_opfor_count_at` already
provides and is already owner-blind. Nothing attacks a FOB unattended today — the WARCOM OPFOR
spawners are gone — so this is dormant rather than live, and it stops being dormant the moment the
OPFOR commander ships ([`opfor_commander_plan.md`](opfor_commander_plan.md)).

### Hooks

Per occupant, not per site, because a town's crowd and its garrison answer them differently.

| Hook | What it answers | Example |
|---|---|---|
| `present` | should this occupant exist at all right now | zone: OPFOR hold it; town garrison: reputation `<= -10`; crowd: always |
| `composition` | what it fields | a token list, or a count for a crowd |
| `capacity` | how many may be placed at this moment | crowds only — `fnc_civ_liveTarget`; unset elsewhere |
| `onCleared` | what a clear pays | zone: ownership flip, CP, AP. Crowd: absent |

`capacity` is the one genuinely new concept civilians bring. The crowd cap is not a balance knob: every
civilian gets its own group so it can wander, and the engine stops issuing groups at roughly 144 per
side, so a campaign-wide ceiling is what stops towns silently failing to populate
(`server/misc/fnc_civ_liveTarget.sqf`). No garrison kind sets it.

### The store

    DUWS_sites        hashmap: siteKey -> site record        (plain values only)
    DUWS_occupants    hashmap: siteKey -> [occupant record, ...]
    DUWS_siteHooks    hashmap: siteKey -> hooks              (CODE, never saved)

    site:      key, pos, radius, buffer, grace, nextDue, disposal, awaitVacate, emptySince, awake
    occupant:  kind, side, roster, baseline, tier, strength, deployedList,
               deployedStrength, trg, hold, raising, withdrawing

**Hooks live in their own hashmap so the records stay serializable.** The mission namespace is written
into save games and everything in it must have a serialized form
([gotchas](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)),
so keeping `CODE` out of the record means
[`campaign_persistence_plan.md`](campaign_persistence_plan.md) gets one saveable thing per site instead
of state scattered across six variables and three private thread locals.

**`buffer` and `grace` are per site, not constants.** Today they are 400/120 for zones, 400/120 for
town garrisons, 200/60 for crowds and 500/120 for a FOB's freeze
(`base_garrison_sleep_range`, `base_garrison_sleep_delay`), and each figure has a reason recorded
where it is defined —
towns can sit 210 m apart where zones are held 1200 m apart by `zones_spacing`, and a long grace on a
crowd leaves a trail of populated towns behind a player crossing the map. Carrying them as fields
preserves every one of those decisions and changes no behaviour.

**`nextDue` makes the tick per site**, and today every site asks for 10 s: crowds already poll at that
(`fnc_civ_handler.sqf:23`), zones already poll at that (`fnc_spawnWait.sqf:201`), and only the town
garrison is slower at 30 s (`fnc_civ_garrison.sqf:150`). The poll interval is how long a player stands
somewhere before anything appears, and a garrison materialising late is the pop-in every hold and latch
in these systems exists to prevent — so the responsive figure wins.

**Confirm is two consecutive polls, not a sleep.** Both forms exist for the same reason: a helicopter
crossing a radius should not commit a fill. The crowd handler's is cheaper and, as its comment says,
does not stall the loop that holds every other site's clock.

## Composition: one row table, one filter

A composition is a list of strings and each string names something to spawn. The move to that shape
converted **teams** and stopped: `patrol`, `team`, `sniper`, `wpteam` and `fortified` are rows in
`DUWS_teamRosters`; everything else is a hardcoded branch. `DUWS_fnc_zoneSpawnOne` tells them apart by
asking whether the roster table claims the token, so a mistyped team name does not fault — it falls
through and is treated as a vehicle request.

Two things follow from the half that never converted, and both are wrong rather than untidy.

**A category is being used as a thing to spawn.** `armored` is not tested for anywhere in
`fnc_random_veh`; it lands in a shared `_anyveh` pool weighted across four trucks, an armed car, three
APCs and a tank. Roughly one armour slot in six spawns a supply truck, and the radius bands multiply
the armour category, so a large zone rolls that dip twice.

**A slot that cannot be filled is substituted rather than dropped.** The air branch tests
`_vehClass == "air" && AttackHeli == 1`; a campaign with attack helicopters off fails it and falls to
the same `_anyveh`, so every air slot becomes a random ground vehicle. The player asked for no
helicopters and got an extra truck per slot. Nothing chose that — it is the shape of the `if` leaking.

**One row table covers every token**: what it is called, which category scales it, what it fields, and
what it requires. A composition names what it fields, never a bucket to roll in — `armored` is not a
token, `apc` and `tank` are.

**One filter covers three separate reasons a token cannot be fielded**, and all three drop it rather
than substituting:

- the faction does not define the classname, the rule `fnc_opforRoles` already applies to infantry
- the campaign settings exclude it — `HeavyArmor` and `AttackHeli` become access rules, not branches
- the side has not unlocked it — the Army Power gate

**The ladder it gates on already exists and already has numbers.** BLUFOR wave tiers step at `10`,
`40`, `65`, `100` and `136` (`server/warcom/fnc_WARCOM_blu_assault.sqf:19-33`); OPFOR has one rung at
`100` (`server/missions/fnc_missionPatrols.sqf:30`). The filter needs no new thresholds, it needs the
existing ladder to reach more than one thing.

That surviving rung is the shape in miniature and shows what changes. It reads
`if (WARCOM_opfor_ap > 100) then { "armored" } else { "car" }` — an access test that **substitutes**.
Under the filter it becomes two tokens, the heavier requiring `100`, the lighter standing whether or
not the heavier is dropped. The fallback moves from a branch inside a spawner to a line in a table.

**The filter runs after the radius expansion and before the strength thin.** Filtering first thins the
force the side can actually field; thinning first reduces a composition and then reduces it again.

**A token stays a bare string.** Making it `[name, options]` is rejected: `fnc_zone_thin`,
`DUWS_fnc_spawnDiff` and `DUWS_fnc_spawnCategory` all assume strings, and `spawnDiff` compares them by
value to decide what a tier upgrade owes. A zone that wants different building parameters from a side
mission gets `fortbuildings` as its own row.

## Strength thins men, not tokens

Attrition currently deletes whole entries from the composition list (`fnc_zone_thin`), and an entry is
not a unit: `patrol` is two men, `team` is five, `car` is a vehicle. A zone at half strength keeps
`ceil(0.5 x entries)` entries chosen at random, so two zones reported as equally worn can differ by
twenty men. The figure the readout draws as a bar and the capture rule measures against does not mean
what it says.

**Strength becomes a fraction of men.** It is already that one level down — `DUWS_fnc_teamRoster` thins
men inside a team and never takes the leader — so this applies the same rule across the whole
composition rather than only within each entry.

**The thinning happens before the spawn, not after.** Deleting men once they stand is the same
arithmetic and costs three things: it creates every man a full-strength garrison would to throw most of
them away, on the frame budget of a player who is arriving — a tier IV zone at 0.3 would place eighty
and delete fifty-six; it leaves vehicles crewless unless crew are special-cased anyway; and it cannot
honour the two places that want whole-unit granularity. Each token declares how many men it would
place, the reduction is distributed, and each token spawns its reduced share.

Two rules survive that distribution, both already stated in the code they come from:

- **A mortar pair is all or nothing.** Two men carry a tube and its ammunition one backpack each.
- **Buildings empty whole.** Three men to a house is what makes clearing one cost something; a house
  with one man in it is a house the player walks through.

## Two semantic differences the merge resolves

**What attrition is measured against.** A zone anchors `DUWS_zoneBase_<key>` to the men its *first
completed cycle* placed and never re-bases (`fnc_zone_spawn_sizes.sqf:296-302`). A town re-measures
`baseline` from whatever the current raise placed (`fnc_civ_garrison.sqf:224`) and adds to it on
reinforcement. The zone's is correct and the town's leaks: re-basing on a reduced garrison is the
refund attrition exists to stop. **The merge takes the zone's rule**, and it is a behaviour change to
towns.

**Who owns the clear trigger.** A zone's is created once with the zone and re-armed on every ownership
change (`fnc_createzone.sqf:270-289`, `fnc_captured.sqf`, `fnc_blufor_cap.sqf`); a town's is created by
the raise and deleted with the men (`fnc_civ_garrison.sqf:110-114`). The town's lifetime generalises: a
trigger outliving the garrison it judges can report a clear for a fight that never happened. **The
occupant owns its trigger**, and the re-arming in the two capture handlers goes.

## What stays out

**RAVAGE and WBK.** They keep a third civilian implementation, trigger-driven rather than polled
(`fnc_civ_handler_ravage.sqf`, `fnc_civ_handler_wbk.sqf`), and [`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md)
parks both until base DUWS is whole. Dragging a parked area into an active refactor buys nothing and
costs the ability to say what broke.

**Side-mission spawns.** A mission's guards are event-driven, not presence-driven: they exist because
a mission is running, and they leave when it ends. The site model would have to model "present because
something else is true", which is what the mission thread already is.

**Not the HQ.** It was going to be listed here as a site that never streams, and that is the wrong
reading: it is not an exception to the model, it is the second member of the `freeze` mode — and the
one with no implementation at all today. `fnc_FOBgarrisonSleep.sqf:4-5` says so directly: *"Neither does the HQ's,
but there is one of those and the player is usually stood in it."* That held when base was where you
were; with fast travel, an MHQ and FOBs it is a base garrison standing fully simulated for a campaign
while the player is somewhere else.

## What this buys

Measured against a 40-zone campaign with about 160 towns and ten FOBs, which is the shape a full game
takes.

| | Today | After |
|---|---|---|
| Permanent scheduled threads | 80 (two per zone) + 2 town pollers + 10 FOB sleepers = **92** | **1** |
| Player-list builds per minute | ~**308** | **6** |
| `nearEntities` spatial queries per minute | **240** | **~6-12** |
| Passes over the town list per minute | 8 | 6 |

**The saving is the shared pre-gate, not the thread count.** `fnc_spawnWait` calls
`fnc_duws_bluforNear` every tick unconditionally, and that runs a `nearEntities` over radius + 400 as
well as a `BIS_fnc_ListPlayers`: forty zones at six ticks a minute is 240 spatial queries a minute
across a map that is empty of players almost everywhere. Each zone also carries a second permanent
thread — `fnc_createzone`'s tail loop, polling at the same 10 s for an array slot the first one sets.

The crowd handler already does the cheap thing and states the principle
(`server/misc/fnc_civ_handler.sqf:13-17`): build the player list once, distance-test every site
against it, and only pay for a spatial query where somebody actually is. Zones never got that gate
because each has a thread of its own and nothing to share a list with. Unification extends the gate to
the forty sites still paying full price.

**The global 10 s tick is not added on top of what exists.** Towns are walked by two loops today — the
crowd at 10 s and the garrison at 30 s — and afterwards by one at 10 s, so the town side does six list
walks a minute rather than eight. The garrison logic runs three times as often, but it is a hashmap
read and a distance compare riding a pass that was already happening for the crowd.

**The risk this shape takes on is one long pass.** Scheduled scripts share about 3 ms per frame between
them ([gotchas](info/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)),
so a pass that outgrows the budget is split across frames and the sites at the tail are serviced later
than those at the head. Two hundred and fifty cheap distance tests sit well inside it. It stops sitting
inside it if per-site work grows, which is the constraint the poller is written to: **gate, then
dispatch — never do real work inline.** Log the pass duration and watch whether it ever approaches a
frame.

## Migration order

Each step lands and is playable on its own. No step requires the next to be correct.

1. **Delete co-op scaling.** A zone's composition is its tier and its radius; player count does not
   enter into it. Drops `DUWS_zoneCoopExtra` and its fenced table (`fnc_zone_spawn_sizes.sqf:82-92`),
   the `_coop` parameter and its append (`:98,114`), the `BIS_fnc_listPlayers` call at the one call
   site (`:263`), and the case covering it (`tests/unit/cases.sqf:409,442-444`). **Changes behaviour.**
2. **One row table and the access filter.** Vehicles and specials get rows, vehicle tokens are named
   for what they field, and the branches in `DUWS_fnc_raiseGarrison` and `fnc_random_veh` go.
   **Changes behaviour**: an armour slot stops spawning supply trucks, and an excluded slot leaves a
   gap rather than a substitute.
3. **One composition table per zone.** Fold `fnc_createopfortified`'s four passes into tier-row tokens
   with the `fortification` category, the `mortar` row and its exemption, the `dig-in` behaviour and
   the building parameters. Delete the file. Behaviour-neutral: every token goes on every tier row and
   the new category multiplies by one.
4. **Strength thins men.** Each token declares its man count and `fnc_zone_thin` distributes the
   reduction. **Changes behaviour** at every strength below 1.
5. **Rosters.** Town garrison and crowd rosters become units in `missionNamespace`, keyed like the
   zone's. Behaviour-neutral, and it retires the crowd's `allUnits + allDeadMen` scan.
6. **The store.** `DUWS_sites`, `DUWS_occupants`, `DUWS_siteHooks`; the three existing loops read and
   write them. Behaviour-neutral.
7. **Baseline semantics.** Towns take the zone's anchored baseline. **Changes behaviour.**
8. **The poller.** Write it against the store and move the **crowd** onto it first — it is the
   simplest occupant, it already runs at the target cadence and shape, and a fault is visible in
   seconds rather than after a fight.
9. **Town garrisons onto the poller.** They pick up the 10 s tick here. **Changes behaviour**: a town
   garrison begins arriving sooner after a player walks in.
10. **Zones onto the poller.** Retire the `zone_spawn_array` handshake, fold `fnc_zone_spawn` into the
    shared raise worker, move the clear trigger onto the occupant, and carry the post-capture
    withdrawal over as the `withdrawing` state. The generation counter goes with the handshake.
11. **Emplacements and structures become occupant kinds.** `_manStatics` and `_stowZone` become the
    `emplacement` kind; the prefab becomes `structure`. Behaviour-neutral for zones.
12. **The freeze becomes a disposal mode.** `fnc_FOBgarrisonSleep`'s per-FOB thread folds into the
    poller as `disposal = freeze`, and the wake gains its hostile half so an unattended base can be
    woken by an attacker. Behaviour-neutral for the guards it already covers; the hostile wake is
    dormant until something attacks a FOB.
13. **FOBs register everything they own.** Not just `FOB_guardGroups` — the turret ring from
    `fnc_fortifyFOB` and its crews as `emplacement`, and the FOB building and its props as
    `structure`, so the whole site freezes rather than its infantry alone. There are no vehicles to
    register: a FOB's `createVehicle` calls are the building, the fortification props and the turrets.
    **Changes behaviour**: a FOB's turrets and their crews stop being simulated while nobody is near.
14. **The HQ joins.** Registers its garrison and its composition as a frozen site. **Changes
    behaviour**: the base garrison stops being simulated when every player is away from it.
15. **Drop the flag.** `DUWS_garrisonUnit` becomes a store lookup in `fnc_mission_cleanup`.

## Testing this without a regression harness

None of these systems has been played end to end — see the unexercised sections in
[`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md). The mitigation is not to wait but to make each step
falsifiable:

- Steps 3, 5, 6, 11, 12 and 15 are behaviour-neutral by construction, so **any** observed change is a
  fault. Step 3 is the largest of them, and `deployed N men at tier` proves it: the figure must not
  move.
- Steps 1, 2, 4, 7, 9, 13 and 14 each change behaviour deliberately and are alone in their step for
  that reason. Step 2 is the one a play-test has to *look* at rather than read from a log — the man
  count barely moves, but what is parked on the objective does.
- Steps 8, 9, 10, 13 and 14 move one occupant kind or one site kind at a time, so a fault that appears
  at step *n* and was absent at *n-1* belongs to that one and nothing else.
- The freeze steps are judged differently from the rest: nothing appears or disappears, so the test is
  that a base still fights. Walk away past 500 m, come back, and confirm the garrison reacts; then the
  same with a hostile arriving instead of a player, once anything attacks a FOB.
- **The freeze's one assumption is that a unit resumes cleanly**, and it wants deliberate checking
  because every base garrison depends on it: freeze a man mid-patrol, a man posed at a turret and a
  man walking a fortification ring, thaw all three, and confirm each carries on rather than standing
  still or losing its waypoints.
- The instrumentation exists already: `deployed N men at tier`, `Garrison tier N spawned at town`,
  `garrison streamed out holding X of Y`, and `Town N filled with M of a target T`.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_site_stream_init.sqf` | new: the stores, the poller, the raise worker, register/retire |
| `server/misc/fnc_civ_handler.sqf` | reduced to the crowd's hooks and its capacity rule |
| `server/misc/fnc_civ_garrison.sqf` | reduced to the town garrison's hooks and its reputation band |
| `server/init_zones/fnc_spawnWait.sqf` | deleted; its work becomes occupant kinds |
| `server/init_zones/fnc_createzone.sqf` | registers the site instead of running the tail loop |
| `server/init_zones/fnc_createopfortified.sqf` | deleted; its four passes become tokens |
| `server/init_zones/fnc_zone_spawn_sizes.sqf` | the `composition` hook; `fortification` category, `mortar` row, `dig-in` behaviour, never-thinned marker |
| `server/init_zones/fnc_random_veh.sqf` | reduced to placing a named vehicle; the pools and the `if` chain go |
| `server/init_zones/fnc_zone_state_init.sqf` | roster, count, generation and peak accessors move to the store; `fnc_zone_thin` distributes a man count |
| `server/init_zones/fnc_captured.sqf`, `fnc_blufor_cap.sqf` | clear-trigger re-arming removed |
| `server/misc/fnc_civ_state_init.sqf` | town holds, tier and reinforce accessors move to the store |
| `server/misc/fnc_garrisonBuildings.sqf` | parameterised so the zone's building pass can share it |
| `server/init_hq/fnc_FOBgarrisonSleep.sqf` | deleted; the freeze becomes a disposal mode on the poller |
| `server/init_hq/fnc_guardsFOB.sqf`, `fnc_fortifyFOB.sqf` | register frozen occupants instead of spawning and forgetting |
| `server/init_hq/fnc_BluHQinit.sqf`, `fnc_placeHQUnits.sqf` | register the HQ as a frozen site |
| `server/missions/fnc_mission_cleanup.sqf` | flag test becomes a store lookup |
| `tests/unit/cases.sqf` | co-op composition case removed |
| `info/zones_and_civilians.md` | one lifecycle described once, with the kind and hook tables |

## Task list

- [x] Co-op composition scaling deleted, table and unit case with it
- [x] One row table for every token, vehicles named for what they field
- [x] The access filter: faction, campaign settings and AP gate, all dropping rather than substituting
- [x] `fnc_createopfortified` folded into tier-row tokens and deleted
- [x] `fnc_zone_thin` thins men across the composition, not entries out of it
- [x] Town garrison and crowd rosters become units in the mission namespace
- [x] `DUWS_sites`, `DUWS_occupants`, `DUWS_siteHooks`
- [x] Towns take the zone's anchored baseline
- [x] The poller, with the crowd migrated onto it
- [x] Town garrisons migrated
- [ ] Zones migrated; handshake, generation counter and trigger re-arming retired
- [ ] `emplacement` and `structure` kinds; `_manStatics` and `_stowZone` retired
- [ ] Freeze becomes a disposal mode; `fnc_FOBgarrisonSleep`'s thread retired, hostile wake added
- [ ] FOBs register their turrets and vehicles, not only their guards
- [ ] The HQ registers as a frozen site
- [ ] `DUWS_garrisonUnit` replaced by a store lookup
- [ ] `info/zones_and_civilians.md` rewritten around one lifecycle

## Decided trade-offs

**The split is by what is streamed, not by side or by system.** A zone's turret and the man on it are
one emplacement and stream differently — the weapon stows because it is ground the player will own, the
man deletes because he is a defender. Splitting by side would put that man and that gun in the same
bucket and force a special case; splitting by kind names the rule once.

**One poller replaces every per-site thread.** Two permanent threads per zone against one poller is the
trade the town side already made when a thread per town was collapsed into one. A thread that wakes to
learn nobody is there is a thread that did not need to exist.

**A composition is deterministic.** A tier row says what a site fields; it never says "roll something
from this bucket". Randomness the tables cannot see is randomness nobody can balance against, and it
made the armour category mean whatever the pool returned. Variety is a row a composition chooses, not a
dip a spawner takes on its behalf.

**A garrison does not scale with player count.** Two players and eight meet the same zone. Difficulty
is the tier, the radius band and the attrition the site carries — three levers the player can see and
the commander can spend against. Head-count scaling is none of those, and it made co-op zones harder
while leaving co-op towns untouched, which nothing ever chose.

**Records are one hashmap, not parallel arrays.** The crowd handler keeps `_filled`, `_seenLast` and
`_lastSeen` as three arrays indexed alike; the town garrison already rejected that shape in writing —
fields indexed the same way are one transposition from a site reinforcing against another's
composition.

## Deferred balance decisions

Neither is an open question about the design. Both are tuning that wants play behind it, and both are
recorded so the refactor is not tempted to answer them by accident.

- **Which tokens hang off which Army Power rung.** The thresholds are settled — the ladder has them
  already — but nothing yet says armour requires `100` and air requires more, or whether the OPFOR
  rungs should mirror BLUFOR's five. Per-row data rather than a mechanism, and it decides how many
  hours into a campaign the enemy fields armour at all.
- **What a zone's tier should buy.** Only one of a zone's two spawners reads the tier today: the tier
  row scaled by radius is about seventeen men on a tier I zone at 500 m, and the dug-in half is about
  thirty and identical at every tier. The I-to-IV ladder therefore moves roughly sixteen men out of
  fifty. Step 3 does not change that — it makes it visible in one table for the first time, which is
  the point at which it becomes worth deciding.

A refactor that also re-tunes what a zone *is* cannot be judged by whether anything changed, which is
the whole reason both are held back rather than folded in.
