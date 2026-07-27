# Hardpoint system: implementation plan

Add a third objective tier between side missions and zone capture. A **hardpoint** is a small
garrisoned emplacement — one destructible *core object*, a handful of guards, some cover — that
the player clears on foot. Two flavours, differing only in where they sit and what they are for:

| Flavour | Sited | Purpose |
|---|---|---|
| **Zone hardpoints** | inside an enemy zone, count scaled to its radius | all of them must be cleared before the zone can be captured |
| **Normal hardpoints** | on the corridors between enemy zones and BLUFOR-held ground | standalone CP objectives; a few exist at start, the enemy director builds more |

Zone hardpoints turn zone capture from "stand in the circle until the trigger fires" into a
sequence of small fights whose length the zone's own radius already decides. Normal hardpoints
are the tier that gives a CP-starved player something to do that also removes a standing threat
— a gun covering a road, an observation post feeding the enemy what it sees.

Hardpoints run on their own state and their own clear handler. They must not pass through
`fnc_createZone` or `fnc_zone_control_set`, for reasons set out under
[§Why hardpoints cannot be small zones](#why-hardpoints-cannot-be-small-zones).

Background on how zones are placed, captured and consumed:
[`info/zone_and_town_generation.md`](info/zone_and_town_generation.md).

## Why hardpoints cannot be small zones

`fnc_createZone` writes five campaign registries in its first fourteen lines
(`server/init_zones/fnc_createzone.sqf:19-32`) and `fnc_zone_control_set` moves four globals
as one atomic transition (`server/server_fnc_init.sqf:81-120`). Both are all-or-nothing.
Routing a hardpoint through either puts it into every consumer of zone state at once:

| Global | Written by | What breaks if a hardpoint increments it |
|---|---|---|
| `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-20` | The campaign never ends. The win condition is `zoneundercontrolblu >= amount_zones_created` (`server/misc/fnc_capture_zones_task.sqf:33`). FOB cap inflates too (`client/supports/fnc_request_fob.sqf:16`) |
| `zoneundercontrolblu` | `server/server_fnc_init.sqf:97,110` | Passive income becomes `(zones + hardpoints) * 6` per 30 min (`server/misc/fnc_zonesundercontrol.sqf:11`) — the largest balance blow-up available |
| `WARCOM_zones_controled_by_OPFOR` | `server/server_fnc_init.sqf:95,107-108` | Index 0 is the OPFOR primary assault target. A lost hardpoint redirects the entire enemy war effort. 25+ read sites |
| `zone_namePOS_pairs` | `server/init_zones/fnc_createzone.sqf:28-29` | Intel reveals pick a random entry (`client/misc/fnc_found_intel.sqf:5`), so hardpoints dilute what intel is worth |
| `zone_spawn_array` | `:32` | Lookup is positional — `find [_zone_num,false,false]` (`:221`) — so a duplicate number matches the wrong entry |

The hardpoint tier therefore gets parallel state built to the same template, and touches none
of the above. The one deliberate coupling is a *read*: the zone capture trigger reads a
per-zone hardpoint counter, covered in [§The capture gate](#the-capture-gate).

## Hardpoint types

One core object per hardpoint. The core is what the player is told to destroy, what the map
icon marks, and the only thing the clear rule looks at.

| Type | Core | Effect while alive | Clear pays | Sited toward |
|---|---|---|---|---|
| Observation post | vanilla tower or radar prop | `reveal`s BLUFOR within ~800 m to EAST, so patrols and QRF react to what it sees | 2 CP zone / 5 CP normal | high ground, long sightlines |
| MG nest | `opfor_TURRET_HMG` + sandbags | covers an approach on foot | 2 / 5 CP | open approaches, dead ground below it |
| AT position | `opfor_TURRET_AT` | kills anything wheeled or tracked using the road it covers | 3 / 6 CP | road overwatch (`BIS_fnc_nearestRoad`, as `fnc_createzone.sqf:182` uses it) |
| AA position | `opfor_TURRET_AA` | denies the air corridor — taxi, helolift, CAS | 3 / 8 CP | open sky, away from tree cover |
| Mortar pit | `opfor_TURRET_MORTAR` | light indirect fire out to a few km ([§Indirect fire](#indirect-fire-hardpoints)) | 3 / 8 CP | defilade behind the line it supports |
| Artillery battery | `opfor_ARTY_X` (self-propelled gun) | heavy indirect fire over a region | 4 / 12 CP | rear areas, near a road for the look of resupply |

Garrison size is not per type — it comes from the AP ladder
([§The director and the escalation ladder](#the-director-and-the-escalation-ladder)). Crewed
cores add their gunner on top.

### Choosing a type

**Site first, then type.** Find a position that passes the generic rejection rules, read what the
ground there is good for, and roll a type weighted by that. The reverse order — roll a type, then
hunt for terrain that suits it — can fail to place anything, and zone hardpoints must place
reliably because the capture gate counts them.

Base weights differ by flavour, because the two exist for different reasons. A zone hardpoint
guards an objective; a normal hardpoint is infrastructure feeding the wider war, which is why the
observation post leads there and trails inside a zone, where the player is already in contact and
being seen changes little.

| Type | Zone | Normal |
|---|---|---|
| MG nest | 1.0 | 0.7 |
| AT position | 0.6 | 0.6 |
| Observation post | 0.4 | 1.0 |
| AA position | 0.3 | 0.4 |
| Mortar pit | 0.15 | 0.25 |
| Artillery battery | 0.05 | 0.1 |

Terrain then multiplies what the site actually supports: AT roughly triples with a road inside
30 m and all but disappears without one (`BIS_fnc_nearestRoad`, as `fnc_createzone.sqf:182` uses
it), AA doubles on open high ground, mortar doubles in defilade, OP doubles with sightlines. The
weights are a starting point to tune in play; the *shape* — common infantry positions, uncommon
specialised ones, rare guns — is the part that matters.

Three exclusions drop an entry from the array before the roll rather than zeroing it, since a
zero weight relies on `selectRandomWeighted` semantics that are not worth depending on:

- the type is at its campaign cap ([below](#the-indirect-fire-types-are-capped-campaign-wide));
- a specialised type (AA, mortar, battery) is already in this zone, so a five-hardpoint zone
  cannot be five AA guns;
- for director builds only, OPFOR AP has not unlocked it.

`selectRandomWeighted` is the mission's idiom for exactly this — `fnc_createzone.sqf:113-121`
picks prefabs with it and the WARCOM wave tables pick vehicles with it
(`fnc_WARCOM_opf_assault.sqf:23-28`).

### The indirect-fire types are capped campaign-wide

**One artillery battery and two mortar pits, alive at once, across the whole map.** The cap spans
both flavours: a zone that rolls a mortar pit consumes one of the two, and the director cannot
build a battery while one already stands. Clearing one frees its slot, so destroying the battery
buys quiet until the enemy fields another rather than ending indirect fire for the campaign.

Three reasons the number is this small:

- **Indirect fire is the only threat that reaches past the fight the player chose.** Rare enough
  to be an event, and destroying one should feel like removing something from the war.
- **These are the only hardpoints with permanent crews**
  ([§Distance gating](#distance-gating-replaces-a-live-cap)). Three guns is six or so units that
  never despawn — a bounded cost, where an uncapped count would not be.
- **The other five types are already bounded by the player's own movement.** Only these act at
  range, so only these need a number.

Counting is a filter over `hardpoint_type_array` where `hardpoint_state_array` is `0`; no new
state. **Claim the slot in the same unsuspended block that reads the count.** Zones build
concurrently — `fnc_locatorzones_random.sqf:180` spawns one `fnc_createZone` per zone, and each
siting loop sleeps — so a read, a `sleep`, then a placement lets two zones both see an empty slot
and both take it. SQF only yields where the script says so, which is what makes decide-and-claim
in one block sufficient.

At cap the type simply leaves the weighted array, so the site gets whatever else fits it and the
hardpoint is still placed. There is no separate substitution rule to keep in step with the weights
— one mechanism decides every type, and the capture gate counts what the player expects.

Because generation is not AP-gated, the caps are usually spent before the director draws breath:
if zone build-out rolls the battery, the enemy cannot field another until the player destroys that
one. That is the intended shape — the guns are part of the world the player walks into, and the
director's job is replacing them. It is also why the guns sit at the bottom of the weight table: without
that, the first three zones would hold every interesting emplacement in the campaign.

Unit classnames come from the `opfor_*_X` faction globals exactly as
`server/init_zones/fnc_createopfortified.sqf:14,23,43` does. Hardcoding unit or turret
classnames is the single change that would break mod-free operation and faction
auto-detection; hardcoding vanilla `Land_*` structures is fine, and the zone code already does
it (`fnc_createzone.sqf:145-151`).

**`opfor_TURRET_HMG` already exists and is used nowhere.** Every faction file defines it
(`shared/factions/MODERN/*_opfor.sqf:35-36`, `AUTODETECT_opfor.sqf:115`) and no script reads
it. The MG nest is its first consumer.

**The other four globals do not exist yet, but the data does.** `fnc_parseFaction` already
returns `_turretAT`, `_turretAA`, `_turretMortar` and `_arty`
(`shared/factions/MODERN/fn_factionAutoDetect.sqf:583-586,614`); the OPFOR generator discards all
four, while the BLUFOR one keeps its turret equivalents (`AUTODETECT_blufor.sqf:118-121`). Four
lines in each autodetect generator plus entries in `o_arraysToRandomize`
(`AUTODETECT_opfor.sqf:186`) closes the gap.

| New global | Parsed from | Vanilla fallback |
|---|---|---|
| `opfor_TURRET_AT` | `_turretAT` | `O_static_AT_F` |
| `opfor_TURRET_AA` | `_turretAA` | `O_static_AA_F` |
| `opfor_TURRET_MORTAR` | `_turretMortar` | `O_Mortar_01_F` |
| `opfor_ARTY_X` | `_arty` | `O_MBT_02_arty_F` |

The 132 hand-authored faction files must **not** be swept to add them. Read each as
`missionNamespace getVariable ["opfor_TURRET_AT", "O_static_AT_F"]` — the fallback is what the
`fnc_selectNonEmpty` chains in autodetect already end in, and it keeps a faction file that
predates this feature working untouched. `_arty` is the one most likely to come back empty on a
mod faction, so its fallback earns its keep.

## Zone hardpoints

### Where the pass runs

Inside `fnc_createZone`, not in a separate siting pass off `serv_zones_array`. Three reasons,
all decisive:

- **Radius is in hand there.** `serv_zones_array` entries are two-element `[x,y]`
  (`fnc_locatorzones_random.sqf:180`), so a pass driven off that array would have to read the
  radius back out of `zone_meta_array` (`fnc_createzone.sqf:30-36`); inside `fnc_createZone` it
  is the `_size` argument.
- **Both locators already funnel through it.** Random placement `spawn`s it (`:185`); manual
  placement `remoteExec`s it to target 2 (`fnc_locatorzones_manual.sqf:94`). A pass inside
  `fnc_createZone` is server-side in both cases and needs no wait on a client-published array.
- **The zone index is in hand.** `_zone_num` keys the per-zone counter the capture trigger
  reads, and it is unique by construction, unlike the coordinate-derived names used elsewhere.

Placement point: after the fortification ring (`fnc_createzone.sqf:199`), before the QRF object
(`:201`). That is upstream of the `zones_buildout_done` increment at `:221`, so the "Building
zones..." prompt and the civilian-generation gate keep describing reality
(`fnc_init_OPFOR_WARCOM.sqf:39-49`).

### Count and siting

Radius is in `(zones_min_radius, zones_max_radius]` — `(200, 1000]` as shipped
(`server/server_var_init.sqf:216-220`):

```sqf
private _count = ((1 + floor (_size / 220)) + floor (random 2)) min 6;
```

200 m gives 1-2, 500 m gives 3-4, 1000 m gives 5-6. The `min 6` matters: `zones_max_radius` is
player-settable and a 6-zone campaign at 5 hardpoints each is already 30 extra emplacements.

Sited in the annulus between `0.35 * _size` and `0.9 * _size`: outside the 35 m the prefab pass
clears (`:66`), inside the capture trigger, whose area is `[_size, _size]` — `_size` is the
*radius* of a circular trigger, not a diameter (`:267`).

Rejection rules, cheapest first: 120 m from another hardpoint, 40 m from a placed fortification
(the ring stores its objects at `:198`), not on water.

**Do not reuse the fortification ring's collision test.** `:188-189` rejects a spot if
`nearestObjects [_safePos, [], 8]` finds anything, and the empty type filter makes that include
terrain objects, so in the dense towns `moreUrban` targets almost every spot is rejected — the
documented reason fortification towers barely appear in towns
([`info/zone_and_town_generation.md`](info/zone_and_town_generation.md#defects-subsystem-a)).
Inheriting it here would silently produce zones with zero hardpoints, which is worse than a
missing tower: it makes the whole gate transparent. Filter to the classes that actually block
placement.

### The capture gate

One broadcast number per zone, `zone_hp_left_<zone_num>`, read directly in the capture
trigger's condition (`fnc_createzone.sqf:266-270`):

```sqf
_trg setTriggerStatements [
    format ["this && ((missionNamespace getVariable ['zone_hp_left_%1', 1]) <= 0)", _zone_num],
    format ["[""%1"",%2,""%3"",""%4"",%5,%6] spawn fnc_captured", …], ""];
```

Single quotes inside the condition, so the `format` needs no doubled-quote escaping — the
activation statement below it shows what the alternative reads like.

**The gate has to live in the condition, not in the handler.** A trigger fires on a false→true
transition. If `fnc_captured` instead refused a capture while hardpoints remained, the condition
would stay true for as long as the player stood in a cleared zone, so it would never re-fire:
the zone would become permanently uncapturable until everyone left and came back.

**The default is `1`, not `0`.** A global trigger is evaluated on every machine, which is why
`fnc_captured` asserts `isServer` at all (`fnc_captured.sqf:12-14`). Defaulting to "one left"
means a machine that has not yet received the broadcast cannot evaluate the gate as satisfied.

**A zone with zero placed hardpoints is capturable immediately.** That is the intended failure
mode: siting can legitimately place nothing (a zone centred on a lake shore), and the counter is
written from what was actually placed, never from the rolled count. A zone that cannot be
captured is unrecoverable; a zone that is slightly easier is not.

### Reveal

Zone hardpoint markers are visible from campaign start, like the zone markers themselves. The
player plans the assault off the map rather than discovering the objective count after walking
in, which is what makes a strict all-of-them gate fair: the hunt for a last unseen emplacement
across a 1,000 m zone is the failure mode this avoids. The zone-entry notification
(`server/misc/fnc_enterlocation.sqf:15`) still reports how many are left, because a count is
faster to read than icons are to tally.

The cost is map density — up to 36 icons on a six-zone campaign — so hardpoints get an icon and
no ellipse ([§Markers](#markers)), and the icon carries the type, so a cluster of six still reads
as information rather than clutter.

**Hardcore mode is the one exception, and it is mandatory.** Hardcore hides zone markers until
intel or entry reveals them (`fnc_createzone.sqf:45-49,58-62`, `fnc_zone_reveal.sqf`). A visible
hardpoint icon inside a hidden zone gives the zone's position away, which defeats the mode
outright. So in hardcore, hardpoint markers start at alpha 0 and are revealed by
`fnc_zone_reveal` along with their parent.

That function resolves its target by position, not by index (`fnc_zone_reveal.sqf:11-22`), and
the hardpoint registry has no position-to-zone-number lookup. Filter spatially instead: reveal
every marker whose `hardpoint_zone_array` entry is `>= 0` and whose position is within
`zones_max_radius` of the revealed zone. Both arrays are broadcast, so this needs no new state,
and normal hardpoints are excluded by the flag rather than by distance.

Normal hardpoints appear when the director builds them, with a notification. The player seeing
enemy construction as it happens is the point — it is the only feedback that the OPFOR side is
spending anything.

## Normal hardpoints

### Siting

Anchored on a *pair*: an OPFOR zone (`WARCOM_zones_controled_by_OPFOR`) and the nearest
BLUFOR-held position. Placed 35-65% along the segment between them with lateral jitter, so
hardpoints appear on the ground the player has to cross rather than at either end.

BLUFOR anchors available today: `WARCOM_zones_controled_by_BLUFOR`, `PosOfBLUHQ`, and
`Array_of_FOBpos` (`server/supports/fnc_fob_server.sqf:84`), which is index-parallel to
`Array_of_FOBS` and holds positions rather than building objects.

Rejection rules: 800 m from `PosOfBLUHQ` and from any FOB, `zones_max_radius * 0.9` from any
zone centre (a hardpoint inside a zone would be a zone hardpoint that does not gate it), 400 m
from another hardpoint, 1000 m from any player, not on water. The player keep-out reads
`allPlayers`, never `player` — a bare `player` read server-side is `objNull` on a dedicated
server and the distance test then always passes, which is exactly the bug
`fnc_WARCOM_blu_patrol.sqf` shipped with
([`info/server_client_authority.md`](info/server_client_authority.md#dedicated-server-compatibility)).

**The civilian-town anchor is a named seam, not a dependency.** The design intent is corridors
between enemy zones and *enemy-held towns*, but towns have no ownership today:
`fnc_civ_init_Tomata.sqf:163-164` registers `civ_locations` / `civ_radii` with no side, and the
registry is server-local rather than broadcast — which is fine here, because siting is
server-side anyway. When town ownership exists it appends to the anchor list and nothing else
changes. Building on it now would mean inventing the ownership model inside this plan.

### The director and the escalation ladder

**No Army Power changes hands in either direction.** The director does not buy hardpoints and
clearing one does not debit OPFOR. A cost-and-refund model is farmable: build 25, clear −25,
repeat, and the enemy's pool never reaches the escalation thresholds that make it dangerous.
Clearing pays the player CP and nothing else, so there is no loop to run.

`WARCOM_opfor_ap` decides **how hard a hardpoint is**, not whether it exists. It is already the
enemy's escalation ladder — patrol and assault composition step up at 10/40/65/100/136 AP
(`fnc_WARCOM_opf_assault.sqf:8-21`, `fnc_WARCOM_opf_patrol.sqf:8-14`) — so hardpoints join the
ladder every other OPFOR element is already on:

| OPFOR AP | Garrison, any hardpoint | Types the *director* may build |
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

Vehicle classes come from the same `opfor_ARMED_CAR1_X` / `opfor_APC1_X` / `opfor_MBT_TANK1_X`
globals the wave tables use, so a hardpoint late in a campaign is defended by whatever the enemy
is fielding everywhere else.

**Composition is read when the garrison spawns, not when the hardpoint is built.** With garrisons
distance-gated ([§Distance gating](#distance-gating-replaces-a-live-cap)), a hardpoint the player
walks past in hour one and returns to in hour five is defended at hour five's strength. That is
what makes the ladder felt: the map does not get more hardpoints so much as harder ones, and it
costs nothing to implement, because the spawn already happens on approach.

| Knob | Value | Why |
|---|---|---|
| Seed subset | 2-3 at WARCOM init, any type | The player meets the mechanic before the director has produced anything |
| Build tick | one candidate every 20-30 min | Slower than the 45-90 min patrol cadence (`fnc_WARCOM_opf_patrol.sqf:178`), faster than the 30 min assault cycle |
| Build gate | OPFOR AP above 10 | A suppressed enemy stops fortifying; matches the threshold its first assault wave uses |
| Live cap | none | ([§Distance gating](#distance-gating-replaces-a-live-cap)) |
| Clear pays | CP only | Missions and zone capture remain the AP faucets (`fnc_mission_reward.sqf:20`, `fnc_captured.sqf:44-47`) |

The director is one thread, `spawn`ed from `fnc_WARCOM_init.sqf` beside the four that already
launch there (`:51-63`). It runs after both side lists exist (`:38-45`), which is what its
anchor pairs read.

### Distance gating replaces a live cap

There is no ceiling on how many normal hardpoints exist. Two things bound them instead:

- **AP is the real cap.** At 8-25 AP each against income the enemy also spends on assault waves,
  and one build attempt every 20-30 min, the director cannot run away with it. A constant would
  only be overriding a budget that already says no.
- **Only what a player is near is rendered.** Garrisons spawn and despawn on player distance, so
  the AI cost tracks where the player is rather than how long the campaign has run.

Cores, cover and markers are **not** despawned — they are static objects and a marker, and the
player was promised they stay on the map. What cycles is the garrison. That is the same split
`fnc_spawnWait.sqf:107-121` already produces for zones, where the cleanup skips `StaticWeapon`
and leaves gunners inside statics alone.

Thresholds match the zone gate so the two feel the same: spawn at 600 m from any player, despawn
after 300 s with nobody inside 600 m (`fnc_spawnWait.sqf:11-13` uses a 400 m buffer on the zone
radius and the same 300 s timer).

**Indirect-fire hardpoints keep their crew permanently.** A gun that only works when a player is
standing next to it cannot shell a FOB across the valley, which is the entire reason those types
exist. The campaign-wide cap of three such guns is what makes that affordable: six or so units
that never despawn, fixed, rather than growing with the campaign.

## Indirect-fire hardpoints

The types that justify the tier: persistent enemy assets that act on the campaign, so destroying
one changes the player's situation rather than incrementing a counter. Two tiers, sharing one
fire-mission implementation.

Real crewed guns, not a virtual effect. `doArtilleryFire` must be issued from the machine where
the gun is local, and both are server-spawned, so the server issues it — the same locality rule
that silently broke `fnc_helolift`
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)).

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static mortar, `opfor_TURRET_MORTAR` | self-propelled gun, `opfor_ARTY_X` |
| Unlocks at | 100 AP | 136 AP |
| Reach | whatever the piece has | whatever the piece has |
| Cooldown | 4-8 rounds, then 25-40 min | 6-10 rounds, then 40-60 min |
| Scatter | tighter | wider |

**Reach is the gun's, not a design constant.** `inRangeOfArtillery` decides what a piece can
touch, so a mod faction's heavier tube simply reaches further and a light one does not. What
keeps a long-ranged battery from making its own position irrelevant is not a distance cap — it is
that nothing fires at what the enemy has not seen.

**The battery is a vehicle, so it needs pinning.** `disableAI "PATH"` on the crew plus
`allowFleeing 0`, or it relocates and the marker lies. Killing the crew leaves an intact gun the
player can take, and the unmanned clause already counts that as cleared
([§Clearance](#clearance)) — capturing one is a legitimate prize for a hard fight, and the
recycle station will pay for it (`fnc_activateBaseRecycleStation.sqf`, a documented
ownership-free faucet in [`info/cp_economy.md`](info/cp_economy.md#balance-concerns)).

Everything below applies to both.

| Property | Rule |
|---|---|
| Target set | BLU-held zone centres, FOB positions, players in the open, each only while observed. **Never** aimed inside the 100 m HQ circle |
| Range gate | `_gun inRangeOfArtillery [[_pos], _mag]`, and nothing else |
| Willingness | a roll per opportunity, not a schedule ([§Chance to fire](#chance-to-fire)) |
| Accuracy | deliberate scatter, scaled by range and by how well the target is observed ([§Scatter](#scatter)) |
| Ammo | finite (`setVehicleAmmo`); a gun that runs dry goes quiet |
| Telegraph | Allseer radio line plus a temporary marker ~20 s before impact |

**The HQ is the one standing exception, in the other direction.** The enemy plainly knows where
the player's main base is, so the observation rule would permit shelling it. It is excluded
anyway: the HQ is the one position the player cannot abandon, cannot move, and cannot leave
unoccupied, so fire on it is attrition against a fixed address rather than a fight. Assault waves
already pressure the base and can be met.

The exclusion is on the **aim point**, over a 100 m radius around `PosOfBLUHQ` — the same circle
the HQ icon already uses (`client/init_hq/fnc_draw_HQicon.sqf:8`, and the civilian keep-out uses
the same figure). No fire mission may be *aimed* inside it.

Rounds may still land there. A barrage aimed at a player 200 m out will spill onto the base once
scatter is applied, and that is the intended behaviour: what is denied is deliberate, accurate
fire on a fixed address the player cannot move. Being near the base is not immunity, and stray
rounds in the motor pool read as a war rather than as a rule. A wider sanctuary would buy nothing
except a sterile ring the enemy cannot shoot into, which is a worse answer to the same problem.

Define the constant once and let both the target filter and the pre-fire re-check read it.

### Observation is the trigger

Nothing is shelled that the enemy has not seen. That single rule replaces every range cap: a gun
with map-wide reach is still blind without eyes, so **the spotter's position is what decides what
gets hit**, and spotters are things the player can kill.

The test differs by target kind, because the engine only tracks knowledge of *objects*:

| Target | Observed when |
|---|---|
| Player or player-driven vehicle | `east knowsAbout _unit` above roughly `1.5` — side-wide, so a patrol that saw the squad counts and a corpse does not |
| BLU-held zone or FOB | an OP hardpoint covers it, or an OPFOR element has been within ~500 m in the last 15 min |
| Anything inside the 100 m HQ circle | never aimed at, whatever the enemy knows — see below |

Observation posts are therefore the artillery's eyes, and killing them blinds guns without
touching them. A battery with no spotter in the area is a stationary target that never fires,
which is exactly the counterplay the type needs: the player can answer artillery without being
able to reach it.

The target grid is **latched when the mission is ordered**, never tracked. A mission stores
`[x,y,0]` copied at order time and never an object reference, because an object reference
re-resolves every tick and a position cannot move. Rounds land where the player *was*, so moving
is always the answer and standing still is what gets punished.

That is not only a fairness rule, it is what closes the back door into the HQ exclusion: a player
who is spotted, killed, and respawns at base would otherwise be *followed* there, and the rounds
would arrive at the one place nothing is allowed to shell. Fast travel, an MHQ respawn and a taxi
extraction all produce the same jump. Storing a position immunises against every one of them at
once, and a dead or deleted target leaves no null handle to guard.

Belt and braces: the fire mission re-checks its latched grid against the HQ circle immediately
before firing and drops the mission if it falls inside. That covers the case the latch cannot — a
player spotted while standing at home.

Guarantees on top of that: no fire within 300 m of the gun itself, no player-directed mission
before the first zone is captured, and the per-gun cooldown, so a squad cannot be walked from one
barrage into the next.

### Scatter

`doArtilleryFire` converges after ranging rounds, so an untreated AI gun is a sniper. Rounds are
offset from the aim point by a deliberate radius, and the size of that radius is where observation
quality becomes something the player can feel rather than a boolean:

| Term | Effect on the radius |
|---|---|
| Base | mortar pit tighter than battery |
| Range to target | grows with distance, so a gun at the edge of its reach is guessing |
| Observation quality | shrinks with `knowsAbout`, or with an OP holding direct line of sight |

So the same battery is dangerous when an OP overlooks the target and a nuisance when a patrol
merely passed through last week. It also means the first mission of a barrage is the least
accurate, which reads as the enemy walking their fire in.

Starting values worth tuning in play rather than deriving: 50 m base for a mortar, 100 m for a
battery, +25 m per kilometre of range, −30 m with direct observation.

### Chance to fire

A gun off cooldown with a valid observed target does not fire on a schedule — it rolls. Roughly
40% for a mortar pit and 30% for a battery, evaluated every five minutes.

Predictable shelling is either ignorable or oppressive: a player who can set a watch by it either
routes around it forever or resents it. A roll turns the same average cadence into a risk the
player weighs each time they cross open ground, and it costs one `random` call. The cooldown only
starts when a mission actually fires, so a quiet gun is a gun waiting for a chance, not a broken
one.

The telegraph is not politeness. Without it the mechanic reads as random damage rather than as
"there is a mortar out there and I should find it", which is the entire point of making the gun
a real object. It works with the visible markers: a player under fire can see on the map which
emplacement is doing it, so the counterplay is legible from the first barrage.

Finite ammo also gives the existing OPFOR ammo-truck patrol (`fnc_WARCOM_opf_patrol.sqf:141-175`)
something to be for: intercepting it silences guns the player cannot reach. That is a follow-on,
not part of this plan.

**Fallback if AI static-mortar fire proves unreliable:** spawn the shells directly, as the
player's own artillery support does (`client/supports/fnc_arty.sqf` creates rounds at 800 m
altitude with a downward velocity). Player-facing behaviour is identical and the AI dependency
disappears, at the cost of the gun becoming scenery. Try the real gun first;
[§Open questions](#open-questions) records what has to be verified.

## Clearance

Latched per hardpoint, evaluated by the shared monitor. Cleared when **any** of:

```
isNull _core || !alive _core || damage _core >= 0.9
             || (_core unmanned && no live EAST within 60 m)
```

- `isNull _core` is the important one. `fnc_mission_cleanup.sqf:24-40` deletes every non-WEST,
  non-civilian object within `_radius * 1.2` of a finished side mission, and only skips the sweep
  when an OPFOR zone is within `zones_max_radius * 1.2`. A normal hardpoint in a corridor is
  squarely in scope. Without this clause a deleted core would leave its parent zone permanently
  uncapturable — the single worst failure this design can produce.
- **`isNull` and despawn must never overlap.** A core that is deleted on despawn would satisfy
  the clause and clear itself for free, handing the player every distant hardpoint on the map.
  This is why cores are exempt from distance gating
  ([§Distance gating](#distance-gating-replaces-a-live-cap)): nothing but destruction or a
  cleanup sweep ever deletes one, so `isNull` keeps meaning what it says. If a core ever does
  become despawnable, the clear rule has to be gated on a spawned flag first, and the flag has to
  be written *before* the delete.
- The unmanned-and-clear clause is what makes the tier playable with rifles. A zone gated on
  *destroying* five static weapons is uncappable for a squad without explosives, and an
  observation-post core built from a `Land_*` prop cannot be destroyed by small arms at all.
  Explosives remain the fast path.
- Latched, so a QRF re-manning an abandoned gun cannot un-clear a hardpoint and re-lock a zone
  the player already captured.

Detection is polling, not a `Killed` event handler. The unmanned clause is a state, not an
event, so a poll is needed regardless, and one mechanism means one place for the idempotency
guard. Polling is also the codebase's existing idiom for exactly this
(`shared/functions/fnc_MHQ_destroyed.sqf:4`).

## State

Broadcast parallel arrays, indexed together, all entries numbers or strings — which keeps them
serialisable, since the mission namespace is the save file
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).

| Variable | Shape | Broadcast |
|---|---|---|
| `hardpoint_pos_array` | `[[x,y,0], …]` | on placement |
| `hardpoint_type_array` | `"MG"` / `"OP"` / `"AA"` / `"ARTY"` | on placement |
| `hardpoint_zone_array` | zone number, or `-1` for a normal hardpoint | on placement |
| `hardpoint_state_array` | `0` live, `1` cleared | on every transition |
| `zone_hp_left_<n>` | number per zone | on every transition (the trigger condition reads it) |

Core objects and garrison groups are **not** in the broadcast registry. They go in server-local
namespace keys, `hardpoint_core_<i>`, the way the zone code holds its triggers and fortifications
(`fnc_createzone.sqf:198,274`). Nothing publicVariables an object handle. The garrison-spawned
flag is server-local for the same reason it is not broadcast: only the monitor reads it, and it
changes far more often than anything a client needs.

Because the registry is append-only and unbounded, every entry has to stay cheap — which the
shapes above already are. Growth is data, not objects.

One writer, `fnc_hardpoint_state_set [_index, _state]`, in `server/server_fnc_init.sqf` beside
`fnc_zone_control_set` (`:81-120`). It owns `hardpoint_state_array` and `zone_hp_left_<n>`
together, broadcasts both, and pays the reward through the existing delta writers
`fnc_cp_adjust` and `fnc_ap_adjust` (`:12,41`) — CP to the player, AP off the OPFOR pool only,
never `x = x + n; publicVariable "x"` from a trigger or monitor body. It is idempotent on an
already-cleared index, because two clauses of the clear rule can become true in the same tick.

## Spawn, despawn and cost

**One monitor thread for all hardpoints**, ticking every 20-30 s over the registry: clear
detection, garrison spawn and despawn on player distance, artillery cadence. Not one thread each.
The server already runs 40 `while {true}` loops across 23 files
([`campaign_persistence_plan.md`](campaign_persistence_plan.md)), and one thread per hardpoint
would grow that without bound, for work that is a single pass over a few short arrays. A pass over
50 hardpoints against 8 players is 400 distance tests every 20-30 s, which is noise.

Zone hardpoint garrisons ride the zone's existing spawn/despawn cycle
(`server/init_zones/fnc_spawnWait.sqf`), whose radius is `_size + 400` and therefore already
covers the whole annulus. Two properties of its cleanup at `:107-121` decide the design:

- It skips `StaticWeapon`, so hardpoint **cores survive a despawn**. The re-spawn path must
  re-crew the existing core, never create a second one, or a zone accumulates a fresh turret on
  every despawn cycle.
- A crewman inside a static is caught by neither delete clause — the first excludes
  `StaticWeapon`, the second requires `vehicle _x == _x` — so **gunners survive too**. Only the
  loose garrison despawns, which is the desired behaviour and costs nothing to implement.

Normal hardpoints sit outside every zone, so the zone gate never reaches them and the monitor
does the same job itself at 600 m / 300 s
([§Distance gating](#distance-gating-replaces-a-live-cap)). The rule it has to match is the one
above: re-crew the surviving core, never build a second one.

## Markers

Named `hardpoint_<i>`. They must not use the coordinate-derived scheme: zones use
`<round x><round y>` (`fnc_createzone.sqf:38,52`), side missions use
`<markerText><round x><round y>` (`server/missions/fnc_missionMarkerData.sqf:7,17`), and
`createMarker` on a taken name returns `""` with no error. A hardpoint sited within a metre of
either would fail silently.

One icon each, no ellipse. A hardpoint has no radius worth drawing, and since the markers are up
from campaign start, ellipses would put six translucent discs inside every zone's own disc.

Icon by type, so the map can be read before committing: `o_hq` for an OP, `o_support` for
artillery and mortars, `o_installation` for MG, AT and AA. `ColorRed` while live; deleted, not recoloured, on
clear — a cleared hardpoint is not a holding the player keeps, and a green icon would imply it
is.

## Files touched

| File | Change |
|---|---|
| `server/init_zones/fnc_hardpoint_place.sqf` | New. Builds one hardpoint of a given type at a given position: core, cover, garrison; returns the core. Shared by both flavours. |
| `server/init_zones/fnc_hardpoint_zone_pass.sqf` | New. Count from radius, siting inside the zone, writes `zone_hp_left_<n>` from what was actually placed. |
| `server/warcom/fnc_WARCOM_opf_hardpoints.sqf` | New. Director: seed subset, corridor picking, AP spend, live cap. |
| `server/misc/fnc_hardpoint_monitor.sqf` | New. The single shared loop: clear detection, proximity garrison spawn, artillery cadence. |
| `server/server_fnc_init.sqf` | New `fnc_hardpoint_state_set` beside `fnc_zone_control_set:81-120`; registry lines for the new functions. |
| `server/server_var_init.sqf` | Declare and broadcast the four hardpoint arrays. |
| `server/init_zones/fnc_createzone.sqf:199,266-270` | Call the zone pass; extend the capture trigger condition. |
| `server/warcom/fnc_WARCOM_init.sqf:51-63` | Spawn the director beside the existing four. |
| `server/misc/fnc_enterlocation.sqf:15` | Report how many of this zone's hardpoints are left, in the zone-entry notification. |
| `server/init_zones/fnc_zone_reveal.sqf:11-22` | Hardcore only: reveal this zone's hardpoint markers with the zone, filtered spatially. |
| `shared/factions/MODERN/AUTODETECT_opfor.sqf:115,186`, `AUTODETECT_RANDOM_opfor.sqf:81,129` | Define the four new turret and gun globals from the already-parsed `_turretAT` / `_turretAA` / `_turretMortar` / `_arty`. |
| `client/missions/fnc_stratmap.sqf:147-155` | Add a 250 m hardpoint keep-out to side-mission siting. Missions already keep out of zones; without this they spawn on top of a hardpoint — and then the cleanup sweep deletes its core. |
| `shared/includes/notifications.hpp` | One notification class for a hardpoint cleared, beside `CPadded:87`. |
| `stringtable.xml` | Six hardpoint type names, clear notification, incoming-fire warning line (Allseer), marker labels. |
| `info/zone_and_town_generation.md` | Document the tier, the capture gate and its state contract. |
| `info/cp_economy.md` | Two faucet rows and one AP-sink note. |

## Task list

- [ ] Write `fnc_hardpoint_place.sqf` for the MG type only, called by hand from the debug console. Verify: core, cover and garrison appear, and no hardcoded unit classname is used with a faction mod loaded.
- [ ] Add `fnc_hardpoint_zone_pass.sqf` and call it from `fnc_createZone`. Verify: `bash tests/run.sh` passes the path lint; hardpoint count per zone tracks radius; nothing lands on water or inside the prefab's 35 m.
- [ ] Add the registry, `fnc_hardpoint_state_set` and the monitor's clear detection. Verify: destroying a core decrements `zone_hp_left_<n>` exactly once, and so does killing the crew and walking away.
- [ ] Extend the capture trigger condition. Verify: a zone with hardpoints left cannot be captured; the last clear makes it capturable *without* the players leaving and re-entering; `zoneundercontrolblu` and `amount_zones_created` are unchanged by any clear.
- [ ] Delete a core with `deleteVehicle` mid-campaign. Verify: the zone still becomes capturable. This is the `fnc_mission_cleanup` failure mode and must be tested directly rather than waited for.
- [ ] Add the remaining types and the faction-global fallbacks. Verify: an AT hardpoint kills a vehicle on the road it covers; an AA one engages a heli taxi; an OP's `reveal` reaches the QRF; every core resolves to a real classname with no faction mod loaded and with one.
- [ ] Add the director and seed subset. Verify: clearing a hardpoint moves no AP in either direction, and the director stops building below 10 AP.
- [ ] Add the AP-scaled garrison ladder. Verify: the same hardpoint spawns 2-3 infantry early and infantry plus armour late; composition is read at spawn, so leaving and returning to one changes what defends it.
- [ ] Add garrison distance gating to the monitor. Verify: garrisons disappear 300 s after the last player leaves 600 m and come back on approach; cores, cover and markers never disappear; a re-crewed hardpoint has one turret, not two.
- [ ] Let a campaign run several hours without visiting the corridors, then count units. Verify: live AI tracks player position rather than campaign length — this is the test that replaces the live cap.
- [ ] Enforce the indirect-fire caps. Verify: never more than one live battery or two live mortar pits with every zone generated and the director running for hours; a zone at cap places a substitute type rather than nothing; clearing one lets another be built.
- [ ] Add mortar-pit fire missions against fixed positions. Verify: rounds land only on BLU-held zones and FOBs within `inRangeOfArtillery`, the warning precedes impact, and a dry tube stops.
- [ ] Add the artillery battery on the same implementation. Verify: it stays put, reaches as far as its own gun does, and killing its crew leaves a capturable gun that counts as cleared.
- [ ] Add the observation gate, scatter and the fire roll. Verify: a gun with no spotter in the area never fires however long it sits; killing the OP that overlooks a FOB stops fire on that FOB; scatter widens with range and tightens under direct observation.
- [ ] Verify no mission is ever aimed inside the 100 m HQ circle, including when a player standing at the flagpole is the spotted target. Rounds spilling in from a barrage aimed outside it are expected, not a failure.
- [ ] Get spotted in the field, die, and respawn at base. Verify: the rounds arrive where the body fell, not where the player is — this is the failure mode the latched grid exists to prevent.
- [ ] Add player-directed missions and the OP spotter link. Verify: rounds land on the grid held when the mission was ordered, not on the player's current position; killing the OP stops player-directed fire while fixed-position fire continues.
- [ ] In hardcore: confirm hardpoint markers stay hidden until their zone is revealed. A leaked icon defeats the mode.
- [ ] In-game: capture every zone and confirm the campaign still ends.
- [ ] In-game: repeat with manual zone placement, where `fnc_createZone` arrives by `remoteExec` from a client.
- [ ] On a dedicated server: confirm the capture gate and the director both work. A hosted session is both server and client and will mask locality faults.
- [ ] Update `info/zone_and_town_generation.md` and `info/cp_economy.md`.

## Decided trade-offs

**Hardpoints cannot be retaken.** Clearing is one-way; there is no `EAST SEIZED` re-arm as zones
have (`fnc_captured.sqf:66-71`). The director builds *new* hardpoints instead, which gives the
enemy a way to reapply pressure without teaching WARCOM's assault, QRF and patrol logic — all of
which read `WARCOM_zones_controled_by_*` — about a second kind of holding.

**Zone hardpoints are placed once and never replaced.** The director builds outside zones only.
A zone the player half-cleared and walked away from stays half-cleared, so progress against a
zone is never taken back — the enemy answers by fortifying the ground around it instead. It also
keeps the gate honest: `zone_hp_left_<n>` only ever counts down, so it cannot re-lock a zone
between the trigger's condition passing and its handler running.

**Army Power is read, never moved.** Neither building nor clearing a hardpoint touches either
pool. Any version where the enemy pays to build and refunds on destruction is farmable — the
player clears them as fast as they appear and pins OPFOR below its first escalation threshold,
which is the one number that decides how dangerous the rest of the campaign is. Reading AP for
composition instead means the enemy's strength is a consequence of the war, and hardpoints are
where the player *meets* it rather than a lever on it.

**There is no passive income term.** Zone capture pays `radius/10` halved plus `zones_held * 6`
every 30 min; side missions pay 5-45 CP. A third recurring faucet would feed the snowball the
economy review already flags
([`info/cp_economy.md`](info/cp_economy.md#balance-concerns)), and it is not needed: what makes a
hardpoint worth clearing is the zone it unlocks and the threat it stops being.

**Zone hardpoints pay less than normal ones.** Clearing a zone hardpoint is work the zone payout
already prices, so 2 CP is an acknowledgement rather than a wage — it exists so a player who
clears three and then dies has something to show. Normal hardpoints are the whole objective, so
they carry the whole reward.

**Zone capture gets slower, deliberately.** Every zone now needs 1-6 emplacements cleared first,
and the biggest zones need the most. The campaign lengthens and a single zone stops being a
ten-minute errand. If that reads as too slow in play, the lever is the divisor in the count
formula, not the gate.

**Legibility beats fog.** Every hardpoint is on the map from the moment it exists, so the player
plans against known positions rather than discovering them. That is what earns the strict
all-of-them gate and the lethal AA: a threat the player can see on the map before they commit is
a threat they can be held responsible for walking into. Outside hardcore, no part of this tier
is hidden.

**The count is a formula, not a setting.** `zones_number` already ranges widely and the hardpoint
count multiplies it; a separate knob invites 6 zones x 8 hardpoints and 48 extra garrisons. The
`min 6` clamp is there because `zones_max_radius` *is* player-settable.

**No dependency on town ownership or on the civilian system.** The corridor anchors are the zone
lists, the HQ and FOBs — all broadcast, all present with civilians switched off. Towns join the
anchor list when they have an owner.

## Open questions

Both are in-game observations that decide implementation details, not design choices.

**Does an unmanned EAST static weapon block `WEST SEIZED`?** Zone capture fires on a
`["WEST SEIZED","PRESENT",true]` trigger (`fnc_createzone.sqf:268`). If an empty enemy-sided
static counts as enemy presence, a cleared MG nest whose turret still stands would hold its own
zone, and the clear rule would additionally have to delete or re-side the core. The tree offers
no evidence either way: the statics in the prefabs are BLUFOR- and independent-classed
(`server/init_zones/prefabs/modern/*.sqf`), and `opfor_TURRET_HMG` has never been spawned by
anything. Test before writing the clear handler.

**Will an AI gunner in a static mortar or a self-propelled gun reliably execute
`doArtilleryFire`?** If not, the
shell-spawn fallback above becomes the implementation, and the gun is a target rather than a
weapon.
