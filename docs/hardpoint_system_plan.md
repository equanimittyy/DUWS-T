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
[`info/zones_and_civilians.md`](info/zones_and_civilians.md).

## Why hardpoints cannot be small zones

`fnc_createZone` writes five campaign registries in its opening block
(`server/init_zones/fnc_createzone.sqf:23-39`) and `fnc_zone_control_set` moves four globals
as one atomic transition (`server/init_zones/fnc_zone_state_init.sqf:219-257`). Both are all-or-nothing.
Routing a hardpoint through either puts it into every consumer of zone state at once:

| Global | Written by | What breaks if a hardpoint increments it |
|---|---|---|
| `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:23-24` | The campaign never ends. The win condition is `zoneundercontrolblu >= amount_zones_created` (`server/misc/fnc_capture_zones_task.sqf:63`). FOB cap inflates too (`client/supports/fnc_request_fob.sqf:16`) |
| `zoneundercontrolblu` | `server/init_zones/fnc_zone_state_init.sqf:235,248` | Passive income becomes `(zones + hardpoints) * 6` per 30 min (`server/misc/fnc_zonesundercontrol.sqf:52`) — the largest balance blow-up available |
| `WARCOM_zones_controled_by_OPFOR` | `server/init_zones/fnc_zone_state_init.sqf:245-246` | Index 0 is the OPFOR primary assault target. A lost hardpoint redirects the entire enemy war effort. 25+ read sites |
| `zone_namePOS_pairs` | `server/init_zones/fnc_createzone.sqf:32-33` | Intel reveals pick a random entry from the unrevealed set (`server/misc/fnc_intel_payout.sqf:31,73`), so hardpoints dilute what intel is worth |

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
| AT position | `opfor_TURRET_AT` | kills anything wheeled or tracked using the road it covers | 3 / 6 CP | road overwatch (`BIS_fnc_nearestRoad`, as `fnc_locatorzones_random.sqf:107,133` uses it) |
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
30 m and all but disappears without one (`BIS_fnc_nearestRoad`, as `fnc_locatorzones_random.sqf:107,133`
uses it), AA doubles on open high ground, mortar doubles in defilade, OP doubles with sightlines. The
weights are a starting point to tune in play; the *shape* — common infantry positions, uncommon
specialised ones, rare guns — is the part that matters.

Three exclusions drop an entry from the array before the roll rather than zeroing it, since a
zero weight relies on `selectRandomWeighted` semantics that are not worth depending on:

- the type is at its campaign cap ([below](#the-indirect-fire-types-are-capped-campaign-wide));
- a specialised type (AA, mortar, battery) is already in this zone, so a five-hardpoint zone
  cannot be five AA guns;
- for director builds only, OPFOR AP has not unlocked it.

`selectRandomWeighted` is the mission's idiom for exactly this — `fnc_createzone.sqf:150-158` picks
prefabs with it. Zone vehicles are no longer picked at all: a composition names what it fields, and
`fnc_spawn_vehicle.sqf` places that class.

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
concurrently — `fnc_locatorzones_random.sqf:171` spawns one `fnc_createZone` per zone, and each
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

Unit classnames come from the `opfor_*_X` faction globals exactly as the garrison placers in
`server/misc/fnc_garrison*.sqf` do. Hardcoding unit or turret
classnames is the single change that would break mod-free operation and faction
auto-detection; hardcoding vanilla `Land_*` structures is fine, and every zone prefab already does
it (`server/init_zones/prefabs/modern/*.sqf`).

**Four of the five emplacement types are static roles, and those are not this plan's to define.**
`opfor_TURRET_HMG`, `_AT`, `_AA` and `_MORTAR` — what fills them, why the 254 hand-authored faction
files are not swept to add them, and how a composition's vanilla placeholder resolves to a mod's
own gun — are [`static_abstraction_plan.md`](static_abstraction_plan.md). That work is a
prerequisite for the MG nest, the AT position, the AA position and the mortar pit alike, and it is
worth landing on its own: it also fixes the 41 prefab rows standing NATO guns on CSAT ground.

**The artillery battery's global is this plan's, because a battery is a vehicle.**
`fnc_parseFaction` already returns `_arty` from the artillery editor subcategory
(`shared/factions/MODERN/fn_factionAutoDetect.sqf:590,616`) and the OPFOR generator discards it.
One line in each autodetect generator fills `opfor_ARTY_X`; `o_arraysToRandomize` derives from
`fnc_faction_schema` (`AUTODETECT_opfor.sqf:164`, `AUTODETECT_RANDOM_opfor.sqf:110`), so a schema
row reaches `fnc_faction_pools_publish` without a second edit.

Read it as `missionNamespace getVariable ["opfor_ARTY_X", "O_MBT_02_arty_F"]`. `_arty` is the
bucket most likely to come back empty on a mod faction, so its fallback earns its keep.

## Zone hardpoints

### Where the pass runs

Inside `fnc_createZone`, not in a separate siting pass off `serv_zones_array`. Three reasons,
all decisive:

- **Radius is in hand there.** `serv_zones_array` entries carry a position and nothing else
  (`fnc_locatorzones_random.sqf:171-173`), so a pass driven off that array would have to read the
  radius back out of `zone_meta_array` (`fnc_createzone.sqf:38-39`); inside `fnc_createZone` it
  is the `_size` argument.
- **Both locators already funnel through it.** Random placement `spawn`s it
  (`fnc_locatorzones_random.sqf:171`); manual placement `remoteExec`s it to target 2
  (`fnc_locatorzones_manual.sqf:94`). A pass inside `fnc_createZone` is server-side in both cases
  and needs no wait on a client-published array.
- **The zone index is in hand.** `_zone_num` keys the per-zone counter the capture trigger
  reads, and it is unique by construction, unlike the coordinate-derived names used elsewhere.

Placement point: where the fortification ring stood, after the prefab composition is dispatched and
before the site registration at `fnc_createzone.sqf:269-282`. Two things bound it, and both are the
tail of that function rather than the middle of it:

- **Upstream of the `zones_buildout_done` increment at `:260`**, so the "Building zones..." prompt
  and the civilian-generation gate keep describing reality
  (`server/warcom/fnc_init_OPFOR_WARCOM.sqf:37-46`).
- **Upstream of the opening stow at `:295-298`**, which waits for the prefab builder and then puts
  the whole composition away if nobody is near. A hardpoint placed after it is placed into ground
  that has already been stowed, and the zone comes back carrying it only if it was filed under the
  key first. Filing before the stow is what makes the hardpoint part of the composition rather than
  a straggler beside it.

### Count and siting

Radius is in `(zones_min_radius, zones_max_radius]` — `(200, 1000]` as shipped
(`server/server_var_init.sqf:331,333`):

```sqf
private _count = ((1 + floor (_size / 220)) + floor (random 2)) min 6;
```

200 m gives 1-2, 500 m gives 3-4, 1000 m gives 5-6. The `min 6` matters: `zones_max_radius` is
player-settable and a 6-zone campaign at 5 hardpoints each is already 30 extra emplacements.

Sited in the annulus between `0.35 * _size` and `0.9 * _size`: outside the 35 m the prefab pass
clears (`:97`), inside the capture trigger, whose area is `[_size, _size]` — `_size` is the
*radius* of a circular trigger, not a diameter (`:307`).

Rejection rules, cheapest first: 120 m from another hardpoint, 40 m from the prefab composition's own
objects, not on water.

**Do not reject on an unfiltered proximity test**, which is what the deleted fortification ring did:
it refused a spot if `nearestObjects [_pos, [], 8]` found anything, and the empty type filter makes
that include terrain objects, so in the dense towns `moreUrban` targets almost every spot was
refused — which is why those towers barely appeared in towns at all. Repeating it here would
silently produce zones with zero hardpoints, and that is worse than a missing tower: it makes the
whole capture gate transparent. Filter to the classes that actually block placement.

### Facing is part of siting, not decoration

**A hardpoint that faces the wrong way is not a hardpoint.** An MG nest is a firing position with
an arc; a roadblock is a barrier across a line of approach. Both are defined by where they point.
The fortification ring this system replaces had no answer for that — it rolled a heading at random,
so an embrasure as often faced the objective it was meant to defend as the ground it was meant to
cover, and that is half of why the ring was deleted rather than tuned. Siting by luck and facing by
luck are the same defect; a system that reads terrain has to answer both.

So every hardpoint carries a heading, derived at siting time from what the type is for. The **Sited
toward** column of [§Hardpoint types](#hardpoint-types) already names the intent; this is that
intent turned into an angle:

| Type | Faces |
|---|---|
| MG nest, roadblock | the approach it covers — the road when one is within 30 m, otherwise outward from the anchor it guards |
| AT position | the road it overwatches; without a road it is not sited at all, which the terrain weighting already makes rare |
| Observation post | its longest sightline |
| AA position | flat — the arc is the sky, and heading is cosmetic |
| Mortar pit, artillery battery | the line they support, so the tubes read as pointing at the war |

Two things this forces:

- **Facing is state, not a placement detail.** `hardpoint_dir_array` joins the parallel arrays in
  [§State](#state) — one number per hardpoint, which is as serialisable as the rest. Without it a
  stowed hardpoint redeploys pointing somewhere else, and the composition's props rotate away from
  the core they were built around.
- **A multi-object hardpoint rotates as one body.** The core plus its sandbags is a composition, so
  each prop's offset rotates with the heading rather than each prop being placed and then turned in
  place. A per-object `setDir` on an unrotated offset is the failure that leaves a sandbag line
  beside a turret instead of in front of it.

Model-relative correction belongs in the type table rather than in the siting maths: a class whose
front is not at 0 degrees needs one constant, and burying it in the bearing calculation makes every
later type inherit a fudge that was only ever true of one model.

### The capture gate

One number per zone, `zone_hp_left_<zone_num>`, refused inside `fnc_zone_capture_ready`, beside
the two questions it already asks — is the garrison beaten, and does BLUFOR outnumber what is left
standing (`server/init_zones/fnc_zone_capture_ready.sqf`). The gate is one `exitWith` alongside the
garrison-peak refusal at `:31`; nothing about the trigger changes.

**Nothing is formatted into the trigger.** The capture trigger's condition is already a call —
`"this && {[thisTrigger] call fnc_zone_capture_ready}"` (`fnc_createzone.sqf:321`) — and the zone's
position and key ride the trigger as variables rather than as text (`:317-318`). Formatting a zone
number into a condition string would put this counter back through the float round trip that
convention exists to avoid
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#a-trigger-statement-is-a-string-so-anything-formatted-into-it-is-a-float-round-trip)).

**The gate has to live in the condition, not in the handler.** A trigger fires on a false→true
transition. If `fnc_captured` instead refused a capture while hardpoints remained, the condition
would stay true for as long as the player stood in a cleared zone, so it would never re-fire:
the zone would become permanently uncapturable until everyone left and came back.

**The counter is read server-side, so it needs no defensive default.** The capture trigger is
created server-local for exactly this reason — the condition already reads the garrison peak, a
server-side global — so there is no machine evaluating it without the state
(`fnc_createzone.sqf:306`, `fnc_zone_capture_ready.sqf:1-3,15`). It is still broadcast, because the
markers and the readout count it on the client.

**A zone with zero placed hardpoints is capturable immediately.** That is the intended failure
mode: siting can legitimately place nothing (a zone centred on a lake shore), and the counter is
written from what was actually placed, never from the rolled count. A zone that cannot be
captured is unrecoverable; a zone that is slightly easier is not.

### Reveal

Zone hardpoint markers are visible from campaign start, like the zone markers themselves. The
player plans the assault off the map rather than discovering the objective count after walking
in, which is what makes a strict all-of-them gate fair: the hunt for a last unseen emplacement
across a 1,000 m zone is the failure mode this avoids.

The count of what is left belongs on the zone's own marker text, beside the name and kind it
already carries (`fnc_createzone.sqf:169`). Not on zone entry: that notification was deleted as
noise — a zone the player is standing in does not need naming to them — and its only remaining job
is the hardcore reveal (`server/misc/fnc_enterlocation.sqf:2-5`). Putting a count back on arrival
would reopen that decision to save a glance at the map.

The cost is map density — up to 36 icons on a six-zone campaign — so hardpoints get an icon and
no ellipse ([§Markers](#markers)), and the icon carries the type, so a cluster of six still reads
as information rather than clutter.

**Hardcore mode is the one exception, and it is mandatory.** Hardcore hides zone markers until
intel or entry reveals them (`fnc_createzone.sqf:57-61,70-74`, `fnc_zone_reveal.sqf`). A visible
hardpoint icon inside a hidden zone gives the zone's position away, which defeats the mode
outright. So in hardcore, hardpoint markers start at alpha 0 and are revealed by
`fnc_zone_reveal` along with their parent.

That function resolves its target by position, not by index (`fnc_zone_reveal.sqf:33-34`), and
the hardpoint registry has no position-to-zone-number lookup. Filter spatially instead: reveal
every marker whose `hardpoint_zone_array` entry is `>= 0` and whose position is within
`zones_max_radius` of the revealed zone. Both arrays are broadcast, so this needs no new state,
and normal hardpoints are excluded by the flag rather than by distance.

**Normal hardpoints are hidden in both modes.** The rule that decides visibility is not the
difficulty setting but *when the thing came into existence*: what the campaign generated at the
start is on the map in normal mode, and what OPFOR build during play is not. A hardpoint the
director raised behind the lines is a position the player has not found yet, and putting it
straight on the map is the map answering a question intel exists to ask.

| | Zone hardpoints | Normal hardpoints, start batch | Normal hardpoints, director-built |
|---|---|---|---|
| Normal | visible | visible | hidden, construction announced |
| Hardcore | hidden with their parent zone | hidden | hidden, nothing announced |

The two normal-hardpoint columns are the same objects in the same registry, differing only in
when they were created. Nothing needs to record which is which: the start batch exists before
the campaign begins and is painted from `hardcore_mode_enable` like everything else generation
produces, and the director's are created at alpha 0 unconditionally.

**Only hardcore goes silent.** In normal mode the build still fires a notification — it says
OPFOR are fortifying, not where, so the player keeps the one signal that the enemy is spending
without being handed the location. Hardcore drops even that, because an alert is a tell on its
own: it says a hardpoint now exists to hunt and roughly when it appeared.

The cost is that hardcore gives up its only OPFOR-spending feedback. That is the trade the mode
exists to make, and it is the reason the reveal below matters: without it a hardcore player has
no route to a normal hardpoint except walking into its fire.

A hidden normal hardpoint has no parent zone, so `fnc_zone_reveal`'s spatial filter above cannot
reach it. It needs its own reveal in **both** modes now, not only hardcore, and the civilian
interaction menu is the intended source:
[`info/intel_system.md`](info/intel_system.md#one-writer-per-reveal-flag-one-function-for-payout)
lists an unrevealed normal hardpoint as one of the kinds `fnc_intel_payout` draws from, and
[`info/zones_and_civilians.md`](info/zones_and_civilians.md) hands its intel row to that
function. The corpse and side-mission paths already reach it on the same terms
(`server/misc/fnc_search_claim.sqf:95` and the `fnc_intel_payout` calls in the mission threads),
so a hardpoint kind added to the payout is surfaced by every source at once. The payout's own
comment already names an unrevealed normal hardpoint as a kind waiting for the system behind it
(`server/misc/fnc_intel_payout.sqf:26-28`).

Revealing one is a marker alpha change on a single index — the registry is broadcast and
`hardpoint_zone_array` is `-1` for exactly this set, so a reveal picks from entries with that
flag and an alpha still at 0. No new state.

## Normal hardpoints

Two origins, and they behave differently on the map. A small batch is generated once at campaign
start, fortifying the ground OPFOR already hold; the rest are raised by the director during play
as the war escalates. Everything below applies to both unless it says otherwise.

### The campaign-start batch

A one-time pass during generation, siting a handful of normal hardpoints across OPFOR-held
ground so the enemy rear is not bare at hour zero. Without it every normal hardpoint on the map
is something the player watched appear, and the OPFOR side reads as having built its whole
defensive depth after the shooting started.

**They follow the generation rule for visibility: shown in normal mode, hidden in hardcore.**
That is the same line zones and zone hardpoints sit on — what generation produced is on the map
unless the mode hides everything — and it is what separates them from the director's later work,
which stays hidden in both ([§Reveal](#reveal)).

Their siting differs from the director's for the same reason their visibility does. The
director aims at the corridor between OPFOR ground and the player's, because that is where a new
fortification is a response. The start batch has no engagement to respond to, so it distributes
around OPFOR-held zones instead. Every rejection rule below still applies, including the HQ and
player keep-outs — a campaign must not open with a hardpoint overlooking the base.

### Siting

Anchored on a *pair*: an OPFOR zone (`WARCOM_zones_controled_by_OPFOR`) and the nearest
BLUFOR-held position. Placed 35-65% along the segment between them with lateral jitter, so
hardpoints appear on the ground the player has to cross rather than at either end.

BLUFOR anchors available today: `WARCOM_zones_controled_by_BLUFOR`, `PosOfBLUHQ`, and
`Array_of_FOBpos` (`server/supports/fnc_fob_server.sqf:112`), which is index-parallel to
`Array_of_FOBS` and holds positions rather than building objects.

Rejection rules: 800 m from `PosOfBLUHQ` and from any FOB, `zones_max_radius * 0.9` from any
zone centre (a hardpoint inside a zone would be a zone hardpoint that does not gate it), 400 m
from another hardpoint, 1000 m from any player, not on water. The player keep-out reads
`allPlayers`, never `player` — a bare `player` read server-side is `objNull` on a dedicated
server and the distance test then always passes, which is the bug `fnc_WARCOM_blu_patrol.sqf`
shipped with and now states in place of
(`server/warcom/fnc_WARCOM_blu_patrol.sqf:60-63`,
[`info/server_client_authority.md`](info/server_client_authority.md#dedicated-server-compatibility)).

**The civilian-town anchor is a named seam, not a dependency.** The design intent is corridors
between enemy zones and *enemy-held towns*, but towns have no ownership today:
`fnc_civ_init_Tomata.sqf:165-166` registers `civ_locations` / `civ_radii` with no side, and the
registry is server-local rather than broadcast — which is fine here, because siting is
server-side anyway. When town ownership exists it appends to the anchor list and nothing else
changes. Building on it now would mean inventing the ownership model inside this plan.

### The director and the escalation ladder

**The director pays to build; clearing refunds nothing.** Construction is one of the OPFOR Army
Power sinks in [`economy_plan.md`](economy_plan.md), so an emplacement competes with town
garrisons and tasking orders for the same points — that competition is the reason the sink
exists. The refund is what stays forbidden: cost-and-refund is farmable — build 25, clear −25,
repeat, and the enemy's pool never reaches the escalation thresholds that make it dangerous.
Clearing pays the player CP and returns the enemy nothing, so the only loop on offer is one that
costs the enemy AP to run.

`WARCOM_opfor_ap` also decides **how hard a hardpoint is**, not just whether the director can
afford one. The patrol and assault spawners that used to step up at 10/40/65/100/136 AP have been
deleted, so hardpoints would be the first thing to put rungs back on the enemy's ladder rather than
joining one already there — the tiers below are proposed, not matched to a surviving precedent:

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
distance-gated ([§Distance gating](#distance-gating-replaces-a-live-cap)), a hardpoint the player
walks past in hour one and returns to in hour five is defended at hour five's strength. That is
what makes the ladder felt: the map does not get more hardpoints so much as harder ones, and it
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
| Live cap | none | ([§Distance gating](#distance-gating-replaces-a-live-cap)) |
| Clear pays | CP only | Missions and zone capture remain the AP faucets (`fnc_mission_reward.sqf:19`, `fnc_captured.sqf:38-41`) |

The director is one thread, `spawn`ed from `fnc_WARCOM_init.sqf` beside the two that still launch
there (`:44-50`). It runs after both side lists exist (`:33-40`), which is what its anchor pairs
read.

**Whether it is a thread at all is not this plan's call to make.**
[`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md) puts the hardpoint build in one
commander loop as one of two Army Power sinks, and defers to this document for what a hardpoint
*is*. Everything above is the spend rule; where the tick lives belongs to whichever lands first,
and writing a second AP-spending loop to be deleted is the outcome to avoid.

### Distance gating replaces a live cap

There is no ceiling on how many normal hardpoints exist. Two things bound them instead:

- **AP is the real cap.** At 8-25 AP each against income the enemy also spends on assault waves,
  and one build attempt every 20-30 min, the director cannot run away with it. A constant would
  only be overriding a budget that already says no.
- **Only what a player is near exists.** Garrisons and props both spawn and despawn on player
  distance, so the cost tracks where the player is rather than how long the campaign has run.

Props cycle with the garrison, per
[§Map object count](info/performance.md#map-object-count-is-bounded-by-proximity-not-campaign-length).
Even at a dozen objects to a hardpoint — a gun, its cover, a crate, a net, not a zone prefab's
worth — a six-zone campaign with the director running carries several hundred props that exist for
no one, and the count only ever grows. Filing them under a key with `fnc_duws_keep` is the whole
integration: streaming reads the registry, so no hardpoint code places or removes an object itself.

Only the map marker stays. A cleared hardpoint's marker is the record the player was promised,
and it costs nothing to keep.

**A normal hardpoint registers as a site rather than being polled by hand.** `fnc_site_register`,
`fnc_site_occupant_register` and `fnc_site_hooks_set` (`server/misc/fnc_site_stream_init.sqf:30,66,98`)
are the mechanism a zone already uses for exactly this, on a shared 10 s tick that builds its player
list once and distance-tests every site against it. Writing a second proximity loop would pay a
spatial query per hardpoint per pass for the sake of thresholds this store already holds.

The occupant split is the zone's too — `structure` for the composition, `emplacement` for the core,
`garrison` for the men (`fnc_createzone.sqf:269-282`) — because the ordering constraint is the same
one: the props have to stand before anyone is placed on them, and the gun has to be empty before the
composition holding it can be stowed.

Thresholds match the zone gate so the two feel the same: spawn at 600 m from any player, despawn
after 300 s with nobody inside 600 m (a zone's occupant carries a 400 m buffer on its radius and a
120 s grace, `fnc_createzone.sqf:270`).

### Which key a hardpoint files under decides its whole lifecycle

The two flavours land in different persistence buckets, and the line between them is whether the
player ends up owning the ground it sits on.

| Flavour | Key | Bucket | On clear |
|---|---|---|---|
| Zone | the zone's own `zone_<x>_<y>` | persistent | nothing — it is inside territory the player is taking, and stays like the rest of the zone's furniture |
| Normal | its own `hardpoint_<x>_<y>` | semi-persistent | `fnc_duws_release`, then the sweep collects on the configured lifetime |

Zone hardpoints filing under the zone key is what keeps this cheap: they stream with the zone,
stay persistent with the zone and survive its capture with it, so they need no key, no gate and
no release path of their own. Siting puts them at `0.35-0.9 * _size`, comfortably inside the
zone's own `_size + 400` trigger, so one gate covers both. The only per-hardpoint state left is
whether it has been cleared, and that is a number in `hardpoint_state_array`, not an object.

Releasing them instead would leave a captured zone where the prefab's furniture stayed and the
hardpoints' vanished, inside the same circle. Normal hardpoints have the opposite problem: they
sit on ground nobody holds, the director keeps building more, and a spent turret left in an empty
field forever is the accumulation this tier would otherwise create.

**Sharing the zone's key means sharing its stow, and that is what forces every core to be pinned.**
A stow deletes its members and a deploy rebuilds them as new objects
(`server/misc/fnc_composition_stream_init.sqf:124,137-139`) — the key is the only identity a
composition carries across one. An unpinned core therefore goes null on the first despawn, and
`isNull _core` clears the hardpoint for free ([§Clearance](#clearance)). Pinning is
[§Types whose effect depends on existing](#types-whose-effect-depends-on-existing-are-not-stowed),
applied to all six rather than three.

**Retirement is already explicit, and the release path already answers it.** `fnc_duws_release`
clears `DUWS_stowed` alongside `DUWS_compositions` and files the key in `DUWS_retired`
(`fnc_composition_stream_init.sqf:61-75`), which is a terminal state a gate can read rather than
infer from an absent key; re-filing under a retired key revives it (`:47-50`), so a hardpoint built
at the same rounded coordinates as a cleared one does not inherit its predecessor's retirement. What
a cleared normal hardpoint still owes is `fnc_site_retire` (`fnc_site_stream_init.sqf:173`), so the
poller stops asking whether anybody is standing where the emplacement used to be.

### Types whose effect depends on existing are not stowed

**Every core is pinned; three of them keep their crew as well.** The mechanism exists:
`fnc_duws_keep` takes a `_pinned` flag that files a member as `DUWS_noStow`, `fnc_duws_stow`
leaves those standing and excludes them from its crewed-member refusal, and the zone's
static-rebuild path already carries the flag across a replacement
(`fnc_composition_stream_init.sqf:38-46,93,100`, `fnc_zone_stream_init.sqf:85-101`). Nothing passes
`true` yet — this tier is its first caller.

Pinning every core is what keeps `isNull _core` meaning destruction rather than distance
([§Clearance](#clearance)). It costs one object per hardpoint: the gun stays, the cover around it
streams like any other prop.

Two hooks in the zone's own cycle have to learn about pinned members, or the pin buys nothing:

- `DUWS_zoneEmplacementHooks` "sleep" crews out every `StaticWeapon` in the composition without
  testing `DUWS_noStow` (`fnc_zone_stream_init.sqf:254-258`), so a gun that is meant to keep its
  crew loses it on the first despawn.
- `DUWS_fnc_zoneManStatics` re-crews every empty static in the composition and appends the gunners
  to the zone's roster (`:207-242`), which would fold hardpoint crews into the zone's garrison peak
  and its capture break-line — a hardpoint's men are not the zone's garrison, and counting them
  makes clearing one look like beating the other.

Three types then keep their crew on top of the pin, because they act at ranges far beyond the gate
that would stow them, so streaming the core removes the capability rather than deferring it:

| Type | Why the core stays resident |
|---|---|
| Artillery battery | Shells a region. A gun that exists only while a player stands next to it cannot shell a FOB across the valley, which is the entire reason the type exists |
| Mortar pit | Same, at shorter range |
| AA position | Denies an air corridor. A jet crosses a 450 m trigger in about three seconds — deploy cannot finish before the aircraft is past, so a streamed AA gun never engages anything |

**The core and its crew stay; the furniture around it streams normally.** That is the split worth
having — one gun and two men against everything else the emplacement is built from.

Indirect fire is already capped at three guns campaign-wide
([§The indirect-fire types are capped](#the-indirect-fire-types-are-capped-campaign-wide)), and
that cap exists precisely because permanent crews are the expensive part. **AA needs its own cap
for the same reason**: an uncapped type with a resident crew reintroduces exactly the unbounded
live-AI growth the indirect-fire cap was written to prevent.

## Indirect-fire hardpoints

The types that justify the tier: persistent enemy assets that act on the campaign, so destroying
one changes the player's situation rather than incrementing a counter. Two tiers, sharing one
fire-mission implementation.

**A zone's own mortar is a different thing and stays as it is.** Several zone prefabs site a tube
that `fnc_static_resolve` turns into whichever mortar the holding faction fields, and its fire is
whatever the engine's AI decides on its own. It belongs to the prefab, it is crewed by the zone's
manning pass, and it is not counted against the caps below. What is capped is the emplacement kind:
a sited, crewed, map-marked gun that keeps firing while nobody is there.

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
ownership-free faucet in [`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md#economy-balance)).

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

The exclusion is on the **aim point**, over a 100 m radius around `PosOfBLUHQ`. No fire mission
may be *aimed* inside it.

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

Finite ammo also gives an OPFOR resupply run something to be for: intercepting it silences guns
the player cannot reach. The ammo-truck patrol that would have carried it went with the rest of the
WARCOM OPFOR spawners, so this is a follow-on for whatever commander replaces them, not part of
this plan.

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

- `isNull _core` is the safety net, and what it guards against is a core deleted by something that
  never asked whether it mattered. A side mission's teardown is the near miss: it deletes what it
  finds within `_radius * 1.2` of a finished objective, and a normal hardpoint in a corridor is
  squarely in that circle — but the sweep spares anything flagged `persistent` and anything a site
  owns (`server/missions/fnc_mission_cleanup.sqf:117-127`), and `fnc_duws_keep` sets that flag on
  everything it files. So a filed core is already out of scope. The clause stays because a core that
  goes missing for any reason at all must clear its hardpoint rather than leave a zone permanently
  uncapturable, which is the single worst failure this design can produce.
- **`isNull` and despawn must never overlap.** A core deleted on despawn satisfies the clause and
  clears itself for free, handing the player every distant hardpoint on the map. In this codebase
  that is not hypothetical: `fnc_duws_stow` deletes composition members outright
  (`server/misc/fnc_composition_stream_init.sqf:124`), so an unpinned core is deleted the first time
  its zone streams out. Pinning every core is what closes it
  ([§Types whose effect depends on existing](#types-whose-effect-depends-on-existing-are-not-stowed));
  it is a correctness requirement, not a performance choice. If a core ever does become stowable,
  the clear rule has to be gated on a deployed flag first, and the flag has to be written *before*
  the delete.
- The unmanned-and-clear clause is what makes the tier playable with rifles. A zone gated on
  *destroying* five static weapons is uncappable for a squad without explosives, and an
  observation-post core built from a `Land_*` prop cannot be destroyed by small arms at all.
  Explosives remain the fast path.
- Latched, so a QRF re-manning an abandoned gun cannot un-clear a hardpoint and re-lock a zone
  the player already captured.

Detection is polling, not a `Killed` event handler. The unmanned clause is a state, not an
event, so a poll is needed regardless, and one mechanism means one place for the idempotency
guard. Polling is also the codebase's existing idiom for exactly this
(`shared/functions/fnc_MHQ_destroyed.sqf:11`).

## State

Broadcast parallel arrays, indexed together, all entries numbers or strings — which keeps them
serialisable, since the mission namespace is the save file
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).

| Variable | Shape | Broadcast |
|---|---|---|
| `hardpoint_pos_array` | `[[x,y,0], …]` | on placement |
| `hardpoint_dir_array` | heading in degrees, from [§Facing](#facing-is-part-of-siting-not-decoration) | on placement |
| `hardpoint_type_array` | `"MG"` / `"OP"` / `"AA"` / `"ARTY"` | on placement |
| `hardpoint_zone_array` | zone number, or `-1` for a normal hardpoint | on placement |
| `hardpoint_state_array` | `0` live, `1` cleared | on every transition |
| `zone_hp_left_<n>` | number per zone | on every transition (`fnc_zone_capture_ready` reads it) |

Core objects and garrison groups are **not** in the broadcast registry. They go in server-local
namespace keys, `hardpoint_core_<i>`, the way the zone code holds its capture trigger
(`fnc_createzone.sqf:328-330`) and its flagpole (`:347-348`). Nothing publicVariables an object
handle. The garrison-spawned flag is server-local for the same reason it is not broadcast: only the
monitor reads it, and it changes far more often than anything a client needs.

**A core handle is only durable because the core is pinned.** A stow replaces every member of a
composition with a fresh object on the next deploy (`fnc_composition_stream_init.sqf:137-139`), so a
handle held in `hardpoint_core_<i>` would go stale on the first despawn of an unpinned core — the
same fact the clear rule turns into a free capture
([§Clearance](#clearance)). Pinning is what lets the registry hold a handle at all.

Because the registry is append-only and unbounded, every entry has to stay cheap — which the
shapes above already are. Growth is data, not objects.

One writer, `fnc_hardpoint_state_set [_index, _state]`, in
`server/init_zones/fnc_zone_state_init.sqf` beside `fnc_zone_control_set` (`:219-257`). It owns
`hardpoint_state_array` and `zone_hp_left_<n>` together, broadcasts both, and pays the reward
through the existing delta writers `fnc_cp_adjust` and `fnc_ap_adjust`
(`server/misc/fnc_economy_init.sqf:14,43`) — CP to the player, AP off the OPFOR pool only,
never `x = x + n; publicVariable "x"` from a trigger or monitor body. It is idempotent on an
already-cleared index, because two clauses of the clear rule can become true in the same tick.

## Spawn, despawn and cost

**One monitor thread for all hardpoints**, ticking every 20-30 s over the registry: clear detection
and artillery cadence. Not one thread each. The server runs 25 `while {true}` loops across 19 files
as it is ([`campaign_persistence_plan.md`](campaign_persistence_plan.md)), and one thread per
hardpoint would grow that without bound for work that is a single pass over a few short arrays.

**Presence is not its job.** Spawning and despawning on player distance belongs to the site poller,
which already builds one player list per pass and tests every site against it
([§Distance gating](#distance-gating-replaces-a-live-cap)). A monitor doing its own proximity work
would duplicate the one thing that store exists to share.

Zone hardpoint garrisons ride the zone's existing cycle
(`server/init_zones/fnc_zone_stream_init.sqf`), whose radius is the zone's plus its 400 m buffer and
therefore already covers the whole annulus. Two properties of that cycle decide the design, and
neither is the one an earlier draft of this plan assumed:

- **A teardown takes the men, whoever they are.** `fnc_site_collect` deletes everything on the
  occupant's roster (`server/misc/fnc_site_stream_init.sqf:201-217`) and the emplacement hook crews
  out the statics first (`fnc_zone_stream_init.sqf:254-258`), so a gunner sitting in a turret is
  removed like any other defender. Hardpoint crews are only exempt where they are pinned
  ([§Types whose effect depends on existing](#types-whose-effect-depends-on-existing-are-not-stowed)).
- **The core survives only because it is pinned**, not because statics are skipped. `fnc_site_collect`
  spares a vehicle carrying the `persistent` flag (`:208`), so the garrison teardown leaves it — and
  the composition stow deletes it a moment later unless `DUWS_noStow` says otherwise.

The re-spawn path must therefore re-crew the standing core and never create a second one, or a zone
accumulates a fresh turret on every cycle. Normal hardpoints sit outside every zone, so the zone's
occupants never reach them; they register occupants of their own on the same terms.

## Markers

Named `hardpoint_<i>`. They must not use the coordinate-derived scheme: zones use
`<round x><round y>` (`fnc_createzone.sqf:50,64`), side missions use
`<round x><round y>cache` (`server/missions/fnc_missionMarkerData.sqf:18`), and
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
| `server/init_zones/hardpoint_compositions.sqf` | New. One fenced `--DUWS-COMPOSITION--` array per type, authored in Eden through the TUI. Offsets in a frame whose +Y is the hardpoint's facing, so a heading rotates the whole layout ([§Facing](#facing-is-part-of-siting-not-decoration)). |
| `server/init_zones/fnc_hardpoint_place.sqf` | New. Builds one hardpoint of a given type at a given position and heading: rotates the composition's offsets, resolves the core's faction role, files everything through `fnc_duws_keep` with the core pinned, raises the garrison; returns the core. Shared by both flavours. **The shared placer it borrows does not rotate** — `fnc_static_place` ([`static_abstraction_plan.md`](static_abstraction_plan.md)) resolves the core's class and puts one object down at a world-axis offset with a per-row heading, which is every placer in the tree. Rotating the composition's offsets around the hardpoint's facing is this function's own work. |
| `server/init_zones/fnc_hardpoint_zone_pass.sqf` | New. Count from radius, siting inside the zone, writes `zone_hp_left_<n>` from what was actually placed. |
| `server/warcom/fnc_WARCOM_opf_hardpoints.sqf` | New. Director: seed subset, corridor picking, AP spend. Folds into the OPFOR commander loop if that lands first. |
| `server/misc/fnc_hardpoint_monitor.sqf` | New. The single shared loop: clear detection and artillery cadence. Presence belongs to the site poller. |
| `server/init_zones/fnc_zone_state_init.sqf` | New `fnc_hardpoint_state_set` beside `fnc_zone_control_set:219-257`. |
| `server/init_zones/fnc_zone_spawn_sizes.sqf` | Hardpoint garrison tiers as a fenced token table beside the zone one (`:115-121`). |
| `server/server_fnc_init.sqf` | Registry lines for the new functions. |
| `server/server_var_init.sqf` | Declare and broadcast the five hardpoint arrays. |
| `server/init_zones/fnc_createzone.sqf:260,269` | Call the zone pass, above the buildout increment and above the site registration and opening stow. |
| `server/init_zones/fnc_zone_capture_ready.sqf:31` | The capture gate: refuse while this zone has hardpoints left, beside the garrison-peak refusal. |
| `server/init_zones/fnc_zone_stream_init.sqf:207-242,254-258` | Exclude pinned cores from the emplacement crew-out, and hardpoint cores from the zone's re-crew and roster. |
| `server/warcom/fnc_WARCOM_init.sqf:44-50` | Spawn the director beside the two that still launch there. |
| `server/init_zones/fnc_zone_reveal.sqf:33-34` | Hardcore only: reveal this zone's hardpoint markers with the zone, filtered spatially. |
| `shared/factions/MODERN/AUTODETECT_opfor.sqf:121`, `AUTODETECT_RANDOM_opfor.sqf:90` | Define `opfor_ARTY_X` from the already-parsed `_arty`. The four turret globals belong to [`static_abstraction_plan.md`](static_abstraction_plan.md). |
| `shared/functions/fnc_pos_claimed.sqf` | Add a hardpoint keep-out to the shared "is this ground claimed" test. One edit reaches every mission siting path at once — `fnc_stratmap.sqf:93`, `fnc_findSafeMissionPos.sqf:33,38`, `fnc_missionTargetPos.sqf:45` — where a bespoke test in one of them leaves the others placing missions on top of an emplacement. |
| `shared/includes/notifications.hpp` | One notification class for a hardpoint cleared, beside `CPadded:41`. |
| `stringtable.xml` | Six hardpoint type names, clear notification, incoming-fire warning line (Allseer), marker labels. |
| `info/zones_and_civilians.md` | Document the tier, the capture gate and its state contract. |
| `info/economy.md` | Two faucet rows and one AP-sink note. |

## Task list

- [ ] Land [`static_abstraction_plan.md`](static_abstraction_plan.md), which fills the four turret globals. Then add `opfor_ARTY_X` and its fallback to both autodetect generators. Verify: it resolves to a real classname with no mod loaded and with a faction mod loaded, and a hand-authored faction file that defines none of the five still boots.
- [ ] Author the MG nest composition in Eden through the TUI and fence it in source. Verify: import, rearrange, export, re-import returns the identical layout, and `DUWS_FRONT` stands on the side the gun faces.
- [ ] Write `fnc_hardpoint_place.sqf` for the MG type only, called by hand from the debug console. Verify: core, cover and garrison appear; the whole layout rotates with the heading rather than the core turning inside a fixed ring of sandbags; no hardcoded unit classname is used with a faction mod loaded.
- [ ] Add `fnc_hardpoint_zone_pass.sqf` and call it from `fnc_createZone`. Verify: `bash tests/run.sh` passes the path lint; hardpoint count per zone tracks radius; nothing lands on water or inside the prefab's 35 m.
- [ ] Add the registry, `fnc_hardpoint_state_set` and the monitor's clear detection. Verify: destroying a core decrements `zone_hp_left_<n>` exactly once, and so does killing the crew and walking away.
- [ ] Add the capture gate to `fnc_zone_capture_ready`. Verify: a zone with hardpoints left cannot be captured; the last clear makes it capturable *without* the players leaving and re-entering; `zoneundercontrolblu` and `amount_zones_created` are unchanged by any clear.
- [ ] Pin every core, and exclude hardpoint cores from the zone's emplacement crew-out and re-crew. Verify: walk a zone's hardpoints out of streaming range and back — the cores are the same objects, the zone's garrison peak did not move, and no hardpoint has grown a second turret.
- [ ] Delete a core with `deleteVehicle` mid-campaign. Verify: the zone still becomes capturable. The cleanup sweep can no longer reach a filed core, so this is a test of the safety net rather than of a live failure mode, and it has to be provoked directly.
- [ ] Author the remaining five compositions and add their types. Verify: an AT hardpoint kills a vehicle on the road it covers; an AA one engages a heli taxi; an OP's `reveal` reaches the QRF.
- [ ] Add the director and seed subset. Verify: building debits OPFOR AP, clearing refunds none, and the director stops building below 10 AP.
- [ ] Add the AP-scaled garrison tiers as a token table. Verify: the same hardpoint spawns 2-3 infantry early and infantry plus armour late; composition is read at spawn, so leaving and returning to one changes what defends it; the TUI lists the new table and can edit a row.
- [ ] Register normal hardpoints as sites with their own occupants. Verify: garrisons disappear 300 s after the last player leaves 600 m and come back on approach; cores and markers never disappear; a re-crewed hardpoint has one turret, not two; a cleared one is retired from the site store rather than polled for the rest of the campaign.
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
- [ ] Update `info/zones_and_civilians.md` and `info/economy.md`.

## Decided trade-offs

**Hardpoints cannot be retaken.** Clearing is one-way; there is no `EAST SEIZED` re-arm as zones
have (`fnc_captured.sqf:66`). The director builds *new* hardpoints instead, which gives the
enemy a way to reapply pressure without teaching WARCOM's assault, QRF and patrol logic — all of
which read `WARCOM_zones_controled_by_*` — about a second kind of holding.

**Zone hardpoints are placed once and never replaced.** The director builds outside zones only.
A zone the player half-cleared and walked away from stays half-cleared, so progress against a
zone is never taken back — the enemy answers by fortifying the ground around it instead. It also
keeps the gate honest: `zone_hp_left_<n>` only ever counts down, so it cannot re-lock a zone
between the trigger's condition passing and its handler running.

**Army Power is paid to build, never refunded on clearing.** The refund is the farmable half: with
one, the player clears hardpoints as fast as they appear and pins OPFOR below its first escalation
threshold, which is the one number deciding how dangerous the rest of the campaign is. Without
one, clearing costs the enemy what it spent, and rebuilding costs it again — pressure on the pool
rather than a lever on it. Composition is read from the tier the enemy has reached rather than its
balance ([above](#the-director-and-the-escalation-ladder)), so the strength of what defends a
hardpoint stays a consequence of the war and not of the enemy's last purchase.

**There is no passive income term.** Zone capture pays `radius/10` halved plus `zones_held * 6`
every 30 min; side missions pay 5-45 CP. A third recurring faucet would feed the snowball the
economy review already flags
([`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md#economy-balance)), and it is not needed: what makes a
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

**Does an unmanned EAST static weapon block an OPFOR retake?** The BLUFOR direction is settled and
needs no test: capture is `["WEST","PRESENT",true]` plus `fnc_zone_capture_ready`
(`fnc_createzone.sqf:312,321`), and the OPFOR half of that condition is `fnc_opfor_count_at`, which
unpacks `crew` — an empty turret contributes nobody
(`server/misc/fnc_opfor_count_at.sqf:19-23`). The retake direction still re-arms to
`["EAST SEIZED","PRESENT",true]` (`fnc_captured.sqf:66`), and `SEIZED` demands the area be clear of
the other side rather than counting anyone. So the question that remains is narrower: does a cleared
hardpoint's standing turret, still EAST-sided, hold a zone against OPFOR retaking it? If it does,
that is a zone the enemy can never win back, and the clear rule has to delete or re-side the core.
No evidence in the tree either way — the statics in the prefabs are BLUFOR- and
independent-classed (`server/init_zones/prefabs/modern/*.sqf`) and `opfor_TURRET_HMG` has never been
spawned by anything.

**Will an AI gunner in a static mortar or a self-propelled gun reliably execute
`doArtilleryFire`?** Nothing in the mission has ever issued it: `doArtilleryFire`,
`commandArtilleryFire` and `inRangeOfArtillery` appear nowhere in the tree, and the mortar a zone
prefab sites fires or does not fire entirely on the engine's own judgement. Answer this with a
throwaway console test before writing any
of [§Indirect-fire hardpoints](#indirect-fire-hardpoints): if the answer is no, the shell-spawn
fallback becomes the implementation and the gun is a target rather than a weapon, which is a
different feature wearing the same name.
