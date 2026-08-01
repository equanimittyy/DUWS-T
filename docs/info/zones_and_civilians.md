# Zones, towns and civilians

Two placement subsystems that both "put things at towns", plus the civilian layer built on the
second. They are no longer independent: civilian selection consumes the zone system's output, and the
dependency runs one way.

- **Enemy zone siting** ("More Urban"): where OPFOR objectives spawn — the red `"Bravo (Outpost)"`
  markers you capture.
- **Civilian town selection**: a subset of the map's real towns near the fighting, each seeded with a
  persistent civilian population. Purely civilian — not an objective.

Both are server-only and run near campaign start; civilians are registered once zone build-out has
finished. For the boot order see [`architecture.md`](architecture.md#boot-flow); siting defects are
catalogued in [`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#zone-and-civilian-siting-defects).

## Provenance: what 5U5 changed vs inherited

The fork chain is Kibot's DUWS -> Tomata's DUWS_X -> 5U5's DUWS_T. 5U5's additions carry Chinese
comments; DUWS-era code is English. Comment language is a proxy, not proof, but here it lines up with
explicit author annotations (`// LESS URBAN 保持不变` = "keep unchanged", `修复` = "fix",
`改进版` = "improved version"):

**Enemy zone placement is largely inherited.** 5U5 did *not* rewrite the core siting. The "More
Urban" survey (`fnc_moreUrban_locations.sqf`) is untouched Tomata code. In the siting loop 5U5
replaced only the `moreUrban == 1` branch (building-cluster centroid) and added the origin guard; the
less-urban branch, the outer loop, the distance/spacing gates and the failsafes are inherited. Manual
placement is untouched. `fnc_createzone.sqf` keeps its inherited core (markers, prefab, triggers,
spawn loop) with 5U5 features *bolted on*: obstacle clearing, heli reinforcement and the offset flag.

**The civilian population system is 5U5's own work**, layered on Tomata's civilian-presence concept
and rewritten again since: the map-wide building-cluster scan and the synthetic "Dynamic Town N"
locations it invented are gone, replaced by the selection pass in `fnc_civ_selectTowns.sqf`.

So the honest summary for a reviewer: the classic DUWS objective placement was tweaked and decorated,
not overhauled; the substantial new system is civilian population.

## Enemy zone siting ("More Urban")

Default-on (`moreUrban = 1`, `src/duws/server/server_var_init.sqf:140`; campaign menu can set `0`,
`fnc_process_campaign_menu.sqf:189-203`). Three stages during `server_init.sqf`.

| Stage | File | Produces |
|---|---|---|
| 1. Survey | `server/misc/fnc_moreUrban_locations.sqf` | `MASTER_allLocations_filtered` (Locations, town-weighted, shuffled) |
| 2. Siting | `server/init_zones/fnc_locatorzones_random.sqf` | one `_zonePos` per zone -> `fnc_createZone` |
| 3. Build-out | `server/init_zones/fnc_createzone.sqf` | markers, prefab, fortifications, triggers |

**Survey** enumerates `CfgLocationTypes`, pulls map Locations and towns within
`zones_max_dist_from_hq` of HQ (optionally a 135-degree arc), and requires non-town locations to hold
>5 `House` objects within 100 m (`:132-137`). The result is `towns ++ filtered-locations` (`:147`);
towns can appear in both lists, which is the only real "weighting" — the concatenation order is inert,
since siting picks uniformly at random.

**Siting** loops `zones_number` times. The `moreUrban` branch (`:92-126`): pick a random anchor, take
the centroid of `House`/`Building` objects within 400 m (`:96-117`), `findSafePos` 0-10 m around it
(`:113`), nudge 5 m off the nearest road (`:119-123`). Then distance-from-HQ (`:155`), spacing
(`:159-169`) and 500 m origin keep-out (`:171-177`) gates, then `spawn fnc_createZone` (`:185`). The
`else` branch (`:127-150`) is the older random-then-snap-to-building behaviour, with a 10-try
validation loop.

**Build-out** places markers, clears obstacles for prefab zones (`:61-87`), spawns a weighted prefab
(`:89-139`), and wires the spawn-wait, presence and capture triggers. A ring of 3-4 fortification
towers used to sit between the prefab and the triggers; it was deleted rather than tuned, because
siting emplacements by a random bearing at a random distance is the job
[`../hardpoint_system_plan.md`](../hardpoint_system_plan.md) exists to do against terrain.

**Naming.** `fnc_zone_name` (`fnc_zone_state_init.sqf`) hands each zone one phonetic-alphabet word,
drawn without repeats and pairing two distinct words past the twenty-sixth. It is called from
`fnc_createzone` rather than from either locator, because manual placement's map-click body runs on
the clicking client where a server-side allocator does not exist; both locators pass an empty name to
ask for the next one. The words carry no stringtable key for the same reason squad callsigns do not —
a translated phonetic alphabet is a different alphabet, not a translation. The prefab's kind
("Comm Station") is a marker subtitle only; it used to overwrite the name, which is why a capture
once reported a kind while the map called the same ground by a number.

> `getPos` on a Location is *not* a bug. The civilian system relies on it throughout
> (`fnc_civ_selectTowns.sqf`, `fnc_civ_init_Tomata.sqf`, `fnc_civ_handler.sqf:32`) and the towns
> render, so it resolves a Location's position fine; it is only stylistically inconsistent with the
> `position`/`locationPosition` used elsewhere. Whichever is chosen, selection and the runtime must
> use the *same* one or a town's trigger and its eligibility test measure different points.

### What captures a zone

BLUFOR take a zone on two tests, both in `fnc_zone_capture_ready.sqf`, evaluated from the capture
trigger while any WEST unit is inside the zone radius:

| Test | Counts | Threshold |
|---|---|---|
| Garrison beaten | **only units this zone spawned**, by roster, wherever they are | at or below a fifth of the zone's *original* garrison — the same fraction a town garrison breaks at |
| Objective clear | **any** OPFOR, within 50 m of the composition centre | none alive |

**The strength test counts by ownership, not by position.** Every unit a zone raises is appended to
`DUWS_zoneUnits_<key>` — the spawn band appends what its spawners hand back,
`fnc_createopfortified` appends each of the five groups it builds, and `fnc_spawnWait` appends the
turret crews it re-mans the composition with. `fnc_spawnWait` empties the roster when it deploys the
composition, one act with the generation bump, so it describes the garrison now on the ground rather
than every garrison the zone has ever had. The clear has to happen there rather than where the band
is raised, because the turret crews are placed first and a later clear would drop them.

Two things follow. Units that are not the zone's own cannot restore it: a side mission's guard ring
or a neighbouring town's garrison is not on the roster, so a beaten garrison stays beaten however
many of them arrive to stand on it. And a patrol that has wandered clear of the zone is still the
zone's and still has to be dealt with.

A roster rather than a flag on each unit, because the capture condition runs twice a second while a
player stands in the zone — walking `allUnits` to find stamped ones would put a several-hundred-entry
scan on exactly the frames a firefight is using. Anything spawned into a zone and not appended is
invisible to the test, which is the trap for whoever adds a sixth group to the fortification builder.

**The centre test is deliberately owner-blind.** It asks whether the objective is physically held,
and anyone standing on it denies that whoever spawned them — a side mission's guards parked on the
flag do block capture, even though they cannot un-beat the garrison. Withdrawing units are excluded
from both tests, so a retreat bounding across the centre cannot stall a capture.

Turret crews are on the roster for exactly that reason. They sit inside the composition, so they
deny the centre test for as long as they live; off the roster they counted toward neither the peak
nor the break line, and killing one was progress the zone never registered — a gun crew alone could
hold a zone whose field garrison had been wiped, with nothing on screen to say why.

**A beaten garrison leaves rather than waiting to be finished.** The moment the roster falls to or
below the same fifth, `fnc_spawnWait`'s presence poll orders the survivors out through
`server/misc/fnc_opfor_retreat.sqf`. Because withdrawing units are excluded from both tests, the
withdrawal is also what clears the objective: the remnant walks off the centre and the zone falls
once it has, rather than the player hunting the last four men through a composition. Latched per
deploy cycle, since the count drops to zero as soon as they are flagged.

### Zone tiers

Every zone rolls a tier I to IV when it is generated, and keeps it for the campaign. **Tier picks
which composition the zone fields; strength is how much of that is left.** Weights are 1/2/3/4, so
the roll is skewed to the top: most zones are the full objective and a low roll is the occasional
soft one worth taking early.

`DUWS_zoneSpawnTiers` holds one composition per tier, **absolute rather than cumulative** — a row is
the whole garrison, so what a tier IV zone is reads off one line instead of being assembled from
four. Tier reaches only the units a zone spawns alongside itself; the prefab, the fortification
scatter and their crews are not part of it.

`fnc_zone_tier_roll` refuses to roll twice. `fnc_createzone` is re-entrant by design — `zone_meta_array`
exists so a zone can be rebuilt through it — and a rebuild that re-rolled would change what the ground
is worth behind the player's back and disagree with the garrison peak already measured against the old
tier. A zone with no tier recorded reads as IV, so a save written before tiers existed comes back at
the strength it had rather than silently halving.

Zone tiers are not purchasable and no commander raises them, which is what separates them from a
town's ([§Garrison tiers 0 to IV](#garrison-tiers-0-to-iv)): a town's tier is bought and can change
mid-campaign, a zone's is the ground's fixed character.

#### Radius multiplies each category, not the whole list

A tier composition says *what* a zone fields; its radius says *how many*. Every token belongs to a
category (`DUWS_spawnCategories`), and `DUWS_zoneRadiusMult` gives one multiplier per category per
radius band — because a zone's radius scales its garrison unevenly. More ground needs proportionally
more infantry to cover it and does not need more aircraft, and a flat multiplier on the whole list
would buy the biggest zones three times the air support alongside three times the riflemen.

**The two tables are positionally locked**: one multiplier per category, in `DUWS_spawnCategories`
order, after the radius ceiling. Reordering either without the other scales armour by the air column,
which is a balance change with nothing in the log to show for it.

An unlisted token is a vehicle classname a faction file named directly, which `fnc_random_veh`
resolves. Those count as `light` — multiplier one everywhere — so a mod's own class still spawns and
never at three times the intended count.

`DUWS_zoneCoopExtra` is appended **after** the multiply, so a session with more than two players
gains a flat handful of groups rather than another multiplied band.

Zones cap at what the largest radius asks of a tier IV composition, which is where the old
radius-band table topped out. Towns are not multiplied by radius at all — see
[§Garrison tiers 0 to IV](#garrison-tiers-0-to-iv).

### Attrition carries between visits

A zone remembers what was left of its garrison when it streamed out. `fnc_spawnWait` calls
`fnc_zone_strength_record` on the despawn exit — before the peak is cleared and before the sweep
deletes the survivors it counts — and that stores `survivors / original` in tenths, rounded up and
floored at `0.3`. Everything the zone raises on its next arrival scales by that fraction: the tier
composition drops tokens at random (`fnc_zone_spawn_sizes.sqf`), the fortification builder thins its
defence section and holds fewer buildings and fewer towers (`fnc_createopfortified.sqf`), and fewer
of the composition's statics are re-crewed (`fnc_spawnWait.sqf`). The mortar pair is the one
exception — two men, and the zone's only indirect fire, so a fraction of it is none of it.

**Attrition and tier are separate axes.** Tier chooses the list, attrition thins whatever that list
produced, and only the spawn list is tiered — the fortification garrison and the prefab's gun crews
scale by attrition alone. It is also why the readout can show a tier I zone at a full bar: small, but
not yet fought over.

**The peak is anchored, not re-based.** `DUWS_zoneBase_<key>` is the men the zone's first completed
cycle placed, and every later cycle publishes that same figure as `DUWS_zonePeak_<key>`. A garrison
that redeploys at three tenths is therefore measured against the ten: the men killed last visit stay
killed, and taking a zone you softened means killing a *tenth* of its original strength with the
objective held. Re-basing the peak on the reduced garrison would restore the full 80%-to-beat every
time the zone streamed out — the refund the mechanic exists to stop.

The `0.3` floor is what keeps that from becoming a walk-in, and it is also structural: a zone allowed
to redeploy empty would be uncapturable outright, because a zero peak refuses capture.

Strength only ever falls. It resets to full when BLUFOR take the zone, since whatever OPFOR garrison
it after retaking the ground is a fresh force; nothing else restores it. `fnc_zone_strength_set` is
the only writer, so a mechanic that lets OPFOR rebuild a mauled zone has one place to go through.

**Where the player reads it.** The request menu's View Map mode answers zones as well as towns. A click
goes to `fnc_map_readout_query` on the server, which picks whichever revealed zone or town disc the
click landed in with the **nearest centre** — zone circles and town discs overlap by design, so the
tie has to break on something — and `fnc_map_readout_draw` draws the answer. A zone prints its tier in
roman above its garrison bar, and the bar as twenty segments, green for what is left and grey for what
is gone. A streamed-in zone counts live
men against its baseline and gets all twenty, so a couple of kills move the bar; a stowed one reports
the strength it will redeploy at, quantised to the tenths that strength is stored in and doubled, so
it steps two segments at a time and cannot disagree with what arrives. A zone the player holds prints
no bar: a full run of grey would read as a garrison wiped rather than one that was never there.

Opening the map runs `fnc_zone_strength_refresh` first, which records every deployed zone's live
strength. Without it the stored figure was written only by the streaming teardown, so a zone the
player mauled and left still read at its old strength for the two minutes before it packed up —
which is exactly when the map gets opened. The refresh only ever lowers a zone, for the same reason
the teardown record does.

### Why a pack-up cannot read as a capture

Streaming deletes a zone's units after 120 s with no BLUFOR in reach, which would leave the garrison
count at zero. Three things keep that from being read as a garrison wiped:

- `fnc_spawnWait` clears the peak on **both** its exits, before the sweep runs. No peak means no
  capture, so an empty stowed zone is never takeable — nor is one still mid-spawn.
- The condition is `this && {...}`, and `this` is `WEST PRESENT`. The expensive half never runs
  unless BLUFOR are inside the zone, and their presence is also what stops the despawn clock.
- A spawn band can outlive its own zone: a large band takes longer to place than the 120 s grace.
  Each spawn cycle carries a generation number, bumped by `fnc_createzone` when it starts and by
  `fnc_spawnWait` when it tears down, and a band whose generation is stale publishes nothing —
  otherwise it would write a fresh peak seconds after the sweep deleted what it counted.

**This replaced `WEST SEIZED`.** SEIZED requires the whole trigger area to be empty of OPFOR, which
made a capture a sweep of every last patrol out to the zone radius, and — as the town garrison's
trigger still can — could be held indefinitely by anything the engine counts as present. What is
left in the ring when the zone flips withdraws instead.

The OPFOR-takes-it-back direction still uses `EAST SEIZED`: there is no BLUFOR garrison figure to
judge a retake against, and retakes are driven by WARCOM assault waves rather than by a force being
ground down. Both directions are re-armed on every ownership change, in `fnc_captured.sqf`,
`fnc_blufor_cap.sqf` and `fnc_opfor_cap.sqf`, so the condition lives in four places and has to move
in all of them at once.

The capture trigger is created **server-local**, unlike the notification trigger beside it, because
the condition reads a server-side global. That also settles the evaluation-locality question the
capture handlers previously guarded against with an `isServer` assert.

## Civilian town selection

Selects real map towns near the fighting and gives each a persistent civilian population with map
markers. Gated on `CIV_PRESENCE`; no synthetic locations are created.

| Stage | File | Produces |
|---|---|---|
| 1. Selection | `server/misc/fnc_civ_selectTowns.sqf` | ranked shortlist of `[Location, buildingCount, hqQuota]` |
| 2. Registration | `server/misc/fnc_civ_init_Tomata.sqf` | `civ_locations` / `civ_radii`, per-town runtime gate and markers |
| 3. Runtime | `server/misc/fnc_civ_handler.sqf` (`_ravage` / `_wbk` twins) | fill the town on arrival, empty it after departure |

**Selection** takes the BLUFOR HQ plus every entry of `serv_zones_array` as anchors and pulls
city/village/local Locations with one `nearestLocations` call, keeping those within 5,000 m of *any*
anchor that hold at least three usable buildings within 350 m. Anchors then draw in turn: each ranks
its own disc by that building count, takes three, and skips whatever earlier anchors took. A second
wave adds `count serv_zones_array` more, drawn at random across the whole union. What is left over
comes back alongside the selection as a replacement queue. No side effects; the caller owns
everything else.

Size is measured in standing buildings, not `size _loc`: a Location's `radiusA`/`radiusB` come out of
`CfgWorlds`, are hand-authored per map, and routinely put a hamlet level with a city, so an
extent-ranked pass spent slots on empty ground. Distance is a gate only — inside a disc the bigger
town wins however far back it sits, because blending in closeness let roadside hamlets outrank the
cities behind them. Anchors draw in turn rather than from one ranking over the union because a global
top-N let the densest cluster of anchors win every slot, leaving a remote zone with no civilian town
in reach. The random second wave exists so the result does not read as exactly three towns ringing
every objective. The count travels with the location rather than being recounted downstream: it is
the heaviest engine work in the civilian pass, and both stages need the same figure over the same
`getPos` centre.

**Registration** derives radius and starting population from that count, drops any town whose disc
overlaps the 100 m keep-out around `PosOfBLUHQ` and pulls a stand-in off the replacement queue in its
place, resolves overlapping towns by shrinking or dropping the smaller, then creates the ellipse
marker, the population icon, and the town's runtime gate — a streaming thread for plain civilians, a
presence trigger for RAVAGE and WBK. The overlap loser is dropped from the registry only — never
`deleteLocation`d, because these are the map's own Locations and removing one takes it away from
side-mission siting (`fnc_findSafeMissionPos.sqf:30`) and the player's location readout
(`fnc_bottom_right_message.sqf:152`) for the rest of the mission.

The HQ keep-out is disc-against-disc, not centre-against-centre: a civilian area whose edge reaches
the base still spawns civilians inside it. It sits in registration because that is where the radius
formula lives. Enemy zones get no such gate; a contested town is the point.

Registration also decides each town's starting reputation and its Army Power worth. Both run after the
overlap cull has finalised every radius, for the same reason the HQ keep-out does: the enemy-zone test
is disc-against-disc, and it reads radii out of `zone_meta_array` (entry index 2) rather than
`serv_zones_array`, which stores positions only. A town whose disc reaches into an enemy zone opens at
`-20` — the enemy already holds that ground and the civilians there start with them. Worth is a rank
within the campaign's own kept set rather than an absolute building count, so Altis cities and a
sparse map's hamlets both span 1 to 3.

In hardcore it also decides what starts on the map: the towns the HQ anchor claimed in selection's
first wave are visible, and every other one is hidden until it is walked into or bought with intel,
exactly as an enemy zone is. The flag travels on the shortlist entry rather than being recomputed from
distance later, because the stand-in swap and the overlap cull both reshuffle the registry — the HQ's
opening three are a selection fact, not a geometric one. Hiding is marker alpha and nothing else:
trigger, garrison and population run either way. `civ_visible` holds the state; the reveal machinery
is in [`intel_system.md`](intel_system.md).

### Ownership bands and the garrison

A town's reputation runs `-20 … 20` and three consumers read it as a *band* rather than a magnitude,
so the thresholds are a contract between them:

| Band | Reputation | Pays | Garrison |
|---|---|---|---|
| BLUFOR | `>= 10` | BLUFOR AP | tier 0 |
| Neutral | `-9` … `9` | nobody | tier 0 |
| OPFOR | `<= -10` | OPFOR AP | tier I, and no higher from reputation |

### Garrison tiers 0 to IV

**Reputation decides *whether* a town garrisons; it does not decide how hard.** Crossing `-10` is the
capture — it writes tier I and nothing deeper in the negative writes more. Tiers II to IV are the
OPFOR commander's to buy, so a town the player has merely ruined is not automatically a hard one:
the enemy has to have spent on it. Tier 0 is a town OPFOR does not hold, which is where both the
neutral and the BLUFOR band sit.

The tier is stored per town in `DUWS_townGarrisonTier` and written only through
`fnc_town_garrison_setTier` (`server/misc/fnc_civ_state_init.sqf`) — a number per town, so it
serialises. Towns that start inside an enemy zone are seeded at tier I rather than 0: they are enemy
ground before anyone has played a minute, and reading them as ungarrisoned would have the commander
appraise them as neutral.

| Tier | Fields | Reached by |
|---|---|---|
| 0 | — | not OPFOR ground |
| I | Patrol, team | reputation `<= -10` |
| II | Patrol, two teams, light vehicle | purchase |
| III | Patrol, two teams, light vehicle, armour | purchase |
| IV | The above plus building-occupying units | purchase |

The compositions live as data in `DUWS_townSpawnTiers`, in the token vocabulary
`DUWS_fnc_zoneSpawnOne` already understands — the same spawner the zone compositions use, so a town
garrison inherits faction auto-detection for free.

**A town's set is its own, and is deliberately smaller than any zone's.** It is also *not* multiplied
by the town's radius the way a zone composition is ([§Radius multiplies each category](#radius-multiplies-each-category-not-the-whole-list)):
a large town scaled like a large zone stops being a garrison and becomes a zone that happens to have
civilians in it, which is the distinction static emplacements exist to draw.

**Rows are absolute, not cumulative** — a row is the whole garrison for that tier. A tier bought
while the garrison stands raises `DUWS_fnc_spawnDiff` of the standing composition against the new
one, counting duplicates, so going from one team to two owes one team rather than two. The men that
reinforcement adds are *added* to the strength baseline rather than re-measured from it, so
casualties the player has already inflicted are not refunded. A retuned table cannot order a standing
garrison to shrink: a smaller composition diffs to nothing rather than to something negative.

**Buying a tier and the men arriving are separate acts.** Reinforcement is deferred while the
garrison is withdrawing, and while BLUFOR are within the same radius the arrival test uses — men
materialising around a player who is already in contact reads as the mission cheating, which is the
pop-in the holds exist to prevent, and worse mid-fight.

**A hold covers upgrades too, by structure rather than by a second test.** Reinforcement requires a
standing garrison, and only the hold-gated branch raises one — so a tier bought seconds after a town
falls cannot arrive early. It raises the stored tier, and the first spawn reads that tier whole once
the hold lapses: a town captured and immediately bought up to III arrives as a full
tier III garrison in one go, not as a tier I followed by a top-up. The tier stays owed and lands on a
later cycle rather than being lost, so the commander may raise a contested town at any time and pays
for it whether or not the player is standing there. This is why the deferral lives in the garrison
thread rather than in the commander's appraisal: a purchase made while the player is far away would
otherwise still pop its men in the moment they walked back.

**It is units only — no static emplacements and no prefab**, because built defences are what make a
zone an objective and a town must not compete with one. Tier IV reaches the zone benchmark
(`fnc_createopfortified`: eight buildings at three men each) by occupying buildings instead.

**Clearing destroys the purchase, not the ownership.** The tier files back down to I rather than to
0 — the town is still enemy ground, and what was beaten is the commander's spending, not the enemy's
claim. No refund either: with one, a player clearing towns would hand the enemy its AP back and the
enemy would never climb.

### Arrival, holds and the clear

Presence uses the same arrival test zones use (`fnc_duws_bluforNear`) rather than a presence trigger of
its own, which would fire the instant anyone crossed the radius and whose handle is discarded at
creation anyway. The clear itself is decided by a `WEST SEIZED` trigger rather than by counting the
garrison dead: a garrison that withdraws has cleared the town as surely as one that was wiped, and
only the trigger sees both.

### Holds: one mechanism, two reasons

A town raises no garrison while it is *holding*, and the two things that arm a hold are the two
moments a garrison arriving would land on the player who caused it.

| Kind | Armed when | Length | Also blocks | Readout |
|---|---|---|---|---|
| `TAKEN` | reputation crosses `-10` | 30 min | — | `Mobilising` |
| `REGROUP` | its garrison is cleared | 3 h | reinforcement, tier purchase | `Regrouping` |

Both exist because reputation is spent *inside* a town — you lose it by killing civilians there or
wrecking its buildings — so at the instant a town flips, and again at the instant its garrison dies,
the player is standing in it by definition.

**`TAKEN` does not block a purchase; `REGROUP` does.** A town that has only just fallen is exactly
the ground the enemy should be free to commit to, and the men have not arrived either way, so a tier
bought inside that window is folded into the first spawn rather than arriving as a second wave. A
town whose garrison was just destroyed is the opposite case: without the refusal the commander could
buy it up to IV in the hours nobody is watching, and the player would meet a tier IV where they had
destroyed a tier I.

**The clock lapsing is not on its own permission to spawn.** A player who took or cleared a town and
never left is still standing in it when the hold ends, and the arrival test would read them as having
just walked up. So arming a hold also latches the town until it has been empty of BLUFOR once —
leaving and coming back is the only way to meet the garrison, whichever hold deferred it.

Holds store a `diag_tickTime` deadline, which is wall clock and so cannot be shortened by the
mission's time multiplier. A savegame does not restore that clock, so `fnc_town_garrison_holdAt`
treats a deadline further out than the longest hold as one this session cannot have written and
spends it; otherwise a reload would pin a town for the rest of the run.

Towns seeded into the band at campaign start — the ones whose radius overlaps an enemy zone — arm no
hold, because nothing crossed. They are pre-existing enemy ground and garrison on sight.

The garrison does hold a roster — every spawner returns its group — but it reads it for
strength, never for the clear. At or below a fifth of the men the town was given, what is left
withdraws rather than being finished off in place, through the same `fnc_opfor_retreat`.

**A town garrison streams like a zone.** It is raised when a player arrives and deleted once the town
has been empty for two minutes, so a long session no longer leaves live men in every town anyone has
ever walked through. Three things fall out of that and each is load-bearing:

- **What it took is recorded before it goes.** The stream-out writes `survivors / baseline` into the
  town's strength, floored and never raised, so a garrison ground to one man comes back ground to one
  man. Without it, streaming would refund every casualty on the walk home.
- **The clear trigger is deleted with the men.** Left armed over a town whose garrison had merely
  streamed out, it would read `WEST SEIZED` the moment a player walked back in and pay them a clear —
  the reputation step, the tier reset and the three-hour hold — for a fight that never happened.
- **The cycle ends there.** Nothing after the teardown describes a town without a garrison, and the
  reinforcement test in particular would read the emptied deployment against a live tier and raise
  the whole composition again, streaming the garrison out and back in on the same pass.

Units are deleted rather than walked out through `fnc_opfor_retreat`: by definition nobody is inside
the radius plus 400 when this runs, so there is no one to watch them vanish and a withdrawal nobody
sees is a cost with no audience.

The band is the condition, not a one-shot flag — a town driven back below `-10` gets a new garrison,
and a town lifted out of the band while its garrison lives sees it withdraw.

### What clearing a garrison actually buys

Four things, and only one of them is reputation:

| | |
|---|---|
| Reputation | `+5`, an instalment against the debt — not a discharge |
| Tier | back to I, so the commander's spending is gone but the town is not |
| Strength | pinned to the `0.3` floor, and nothing ever restores it |
| Regroup hold | 3 hours of wall clock in which the town raises nothing, takes no reinforcement and cannot be bought up |

**The reputation step is deliberately an instalment.** Discharging the whole debt let a player ruin a
town to `-20` and walk away square on a single fight, which made the reputation that the garrison was
supposed to be the price of effectively free. At `+5` a town driven to the floor takes four clears to
reach neutral, and the step is self-limiting: only a town at or below `-10` can hold a garrison to
clear at all, so the most this path can ever reach is `-5`. Reputation cannot be turned friendly by
force — aid and heals are still the only way into the BLUFOR band.

**The strength floor is the lasting half.** A town fought out once fields `0.3` of its tier from then
on and never recovers, so what comes back is a shell. That is what makes clearing worth doing when
the reputation step alone would not be: the enemy cannot walk the loss back by waiting.

**The hold is the mechanic, not the wait.** For those three hours the town is enemy ground standing
undefended: no garrison, no reinforcement, no purchase. That is the one stretch of a campaign where
its civilians can be worked without men in the way, which is what the window is for — the redemption
cost lands on the clock rather than on the fighting, and deliberately so. When it lapses the town
garrisons on the ordinary streaming rule, and the commander may buy it up again.

**The hold expiring is not enough on its own.** A player who cleared the town and never left is still
standing in it three hours later, and the arrival test would read them as having just walked up. So a
clear also latches the town until it has been empty of BLUFOR once: leaving and coming back is the
only way to meet the new garrison, and it cannot appear around someone who never went away. After the first real fight
a `0.3` tier I thins to a single group, so later clears are small actions far apart. If that reads
wrong in play, the levers in order are the reputation step, the floor, and the hold.

**Regrouping is a state the player can see.** `fnc_map_readout_query` reports the hold and the readout
prints `Garrison Tier: Regrouping` in place of the numeral. Not "destroyed": the men are coming back,
and a word that said otherwise would have the player write the town off. The hold is per-town state
rather than a thread local precisely because two other things read it — the readout, and
`fnc_town_garrison_setTier`, which refuses a *raise* while it is live so the commander cannot buy a
beaten town up to IV while nobody is looking. Lowering is always allowed, since that is how the clear
files the town back down to I.

The hold stores a `diag_tickTime` deadline, which a savegame does not restore. `fnc_town_garrison_holdAt`
treats a deadline further out than the hold's own length as one this session cannot have written, and
spends it — otherwise a reload would pin a town for the rest of the run.

### Population is a size figure, not a head count

`civ_pop_<n>` is set once at registration to the town's usable building count and never written again.
It is a ceiling, not a head count: a town holds at most `min(civ_density, civ_pop_<n>)` civilians while
players are in it, less if the campaign-wide throttle below applies. So `civ_density` (5–20,
environment menu) is the dial a player turns down for frames, and the building count is what stops a
hamlet presenting as a city.

Because the figure never decrements, nothing can reach zero, which is why the depopulation path —
ghost-town notification, black marker, and the scorched-earth CP reward that rode on it — no longer
exists.

### A town streams like a zone

Per town, `fnc_civ_handler.sqf` is the enemy zone gate from `fnc_spawnWait.sqf`: a town fills once it
has been occupied on two consecutive polls, and everything tagged `civ_locIndex` is deleted once the
grace period since the last sighting expires. The grace restarts on every sighting, so leaving starts
the clock rather than how long you stayed, and the confirmation is what stops a helicopter crossing the
disc filling a town for someone already past it.

Presence is players only, where the zone gate counts friendly AI as well (`fnc_duws_bluforNear`): a
town fills so there is somebody to talk to, and an AI squad passing through has nobody to talk to it.

Two numbers differ from the zone gate's, both because towns outnumber zones.

| | Zone | Town | Why |
|---|---|---|---|
| Threads | one per zone | one for all | 3 towns per anchor plus a top-up wave ≈ `4 × zones + 3`, so a 40-zone campaign registers over 160 towns against 40 zones. One thread builds the player list once a tick and tests every town against it. |
| Grace | 300 s | 60 s | Towns are disjoint, so a player is inside at most one, and a five-minute grace leaves a trail of populated towns behind anyone crossing the map. |
| Reach | radius + 400 | radius + 200 | `zones_spacing` holds zones 1200 m apart, so 400 is a third of the guaranteed separation. Towns are only culled until their discs stop touching — `(r1 + r2) × 1.05` — so two 100 m towns can sit 210 m apart, and 400 would stream three in at once. |

The reach buffer applies to arrival only; the fill still uses the town's own radius, or the crowd would
be spread over the open ground the buffer reaches into. What it does double-trigger is self-limiting:
radius is `buildings × 10` floored at 100, so the tightly packed pairs are the ≤10-building towns, and
`civ_pop_<n>` caps their population at that same count.

That trail is the thing to keep bounded, because the ceiling only thins it. `fnc_civ_liveTarget` gives
one town the density setting in full, soft-caps the campaign at three towns' worth, then throttles the
rest proportionally down to a floor of three apiece — so every occupied town still reads as inhabited,
and the overshoot tracks how many towns are occupied at once rather than the density setting. The grace
period is what decides that count, which is why it is 60 s and not 300. The bound matters because every
civilian holds its own group so it can wander independently, and the engine stops issuing groups at
roughly 144 per side; past that `createGroup` returns `grpNull` and a fill produces nobody. That is why
the top option is 20 and not 30: at 30 the tail reaches roughly 145 groups across six concurrent towns,
level with the limit, where 20 tops out near 97 and leaves the setting safe at any number of towns a
campaign can actually occupy.

The throttle is applied at fill time and never revisited, so the order towns fill in decides who is
thinned: the first town in keeps its full crowd while later ones are cut. Under the old model the
recycle pass re-ran the same calculation every 90 s; nothing does now.

The single-thread collapse does **not** transfer to zones. It works here because presence is a
player-list scan — one global list, then a cheap per-town distance test. `fnc_duws_bluforNear` is a
per-position `nearEntities` query with crew resolution, which cannot be shared across zones at
different centres; folding it into one pass means a global `allUnits` sweep per tick, the
`O(zones × all units)` shape `fnc_spawnWait.sqf:20-22` records as deliberately removed.

This replaced a second answer to the same two questions — an engine presence trigger, a single-slot
global mutex serialising town fills, and a 90 s pass that deleted civilians the players had walked away
from and re-spawned them nearer. The ceiling was not one of those answers and stayed. RAVAGE and WBK
still run on all of it (`fnc_civ_handler_ravage.sqf`, `fnc_civ_handler_wbk.sqf`), which is why
`fnc_civ_recycle.sqf` is still in the tree.

### Ordering

Civilian generation is a step of zone generation, not a parallel system racing it. The kick-off lives
in `fnc_init_OPFOR_WARCOM.sqf` after its `serv_zones_array` wait and fires once
`zones_buildout_done >= count serv_zones_array`.

That counter exists because `amount_zones_created` cannot answer the question: `fnc_createzone.sqf:19`
bumps it on entry, so it counts zones *started*, and the function never returns — its tail is a
permanent despawn monitor. The comparison is against `count serv_zones_array` rather than
`zones_number` because the origin keep-out (`fnc_locatorzones_random.sqf:171-177`) can silently drop a
zone slot, and a `zones_number` target would then never be reached.

Nothing in this chain times out. Everything the player reads as "the campaign has started" blocks on
`mission_init_complete`: the MISSION INITIALIZATION COMPLETE banner and settings summary, the map
closing (`client_init.sqf`), and the intro helicopter (`server_init.sqf`). The flag is published by the
same spawn that runs the kick-off, once civilian registration returns, so an abort inside the civilian
pass still releases the start — no exit-path discipline required inside `fnc_civ_init_Tomata.sqf`. The
completion announcements were moved out of both zone locators to get this; left there they fired as
soon as zone *positions* were final, telling the player the campaign was ready while towns were still
being placed.

The Capture the Zones task (`fnc_capture_zones_task.sqf`) sits one step further out again: it waits on
`mission_init_complete`, then on `intro_heli_done`, so orders reach the player after the fast-rope
rather than during generation. Only the first wait is retried — `fnc_intro_heli` has exit paths that
never publish the second, and a campaign with no main task has no win condition at all, so that wait
falls through on timeout with the earlier gate holding the line.

## Talking to a civilian

What a local will do for the player sits behind one dialog, built like the Requests and Squad Manager
screens. The town's reputation is rolled *against* rather than gated on, so the `-20 … 20` scale above
has a consumer reading more of it than `> 0`.

Civilians are primarily an **information** channel: locals are how the player learns where the enemy
is. Everything else the menu offers is secondary to that.

### The reaction curve

Every request rolls one of three reactions, weighted by the town's reputation
(`fnc_civ_reaction_weights`, `src/duws/server/misc/fnc_civ_state_init.sqf:60-71`). With `t = rep / 20`
clamped to `[-1, 1]`:

```sqf
accept = if (t <= 0) then { (1 + t) / 3 } else { (1/3) + t * (0.9 - 1/3) };
refuse = accept evaluated at -t;      // exact mirror
bribe  = 1 - accept - refuse;         // the remainder
```

| Rep | Accept | Bribe | Refuse |
|---:|---:|---:|---:|
| −20 | 0 % | 10 % | 90 % |
| −10 | 17 % | 22 % | 62 % |
| 0 | 33 % | 33 % | 33 % |
| +10 | 62 % | 22 % | 17 % |
| +20 | 90 % | 10 % | 0 % |

Piecewise linear with a kink at zero, because accept climbs faster above neutral than below it. Refuse
is written as accept's mirror rather than as its own expression, so the curve cannot drift out of
symmetry by being maintained twice. Bribe is a symmetric tent peaking at neutral: a town that neither
likes nor hates the player is where money talks loudest, and at both extremes standing decides instead
of coins.

**There is no hard refusal wall.** A town at `-20` still takes a bribe one time in ten, so hostile
ground is expensive rather than closed. **And the band boundary is not a cliff on this curve** — `±10`
reads 62 % / 17 %, so the ellipse colour hints at the reception rather than predicting it. That is a
deliberate loss of map legibility in exchange for reputation mattering continuously instead of at two
thresholds.

### One conversation per civilian

The roll is scoped to the individual, not the town, and every outcome ends the conversation: accept
and a paid bribe serve the request, refuse and an unaffordable or declined bribe do not, and in all
four cases the civilian walks off and will not talk again.

This is what stops the curve being decorative. A per-attempt roll with no cost lets a player at `-20`
work down a fifty-strong town until one civilian says yes — the failure the old heal action had before
`fnc_civ_healed.sqf` replaced it, where a failed roll consumed nothing so the player simply clicked
again. A refusal costs a person, so a hostile town burns through roughly ten civilians per successful
deal against one in ten at a friendly one, and the population is finite until it respawns. A person
who has helped is as finished with the player as one who refused.

**One per civilian, not one per player, and claimed when the row is picked rather than when the roll
resolves.** `fnc_civ_request` sets `DUWS_civ_closed` before the three-second pause it spends speaking
the opener, so the flag is broadcast while the exchange is still in flight. Written on the way out
instead — in `fnc_civ_serve` or `fnc_civ_close` — it left three seconds in which a second player stood
at the same local passed the same check, and the person answered both: two medikits, two intel drops,
or a recruit joining one group while already in another.

An arrest is one of the exchanges a civilian only has one of, so it and a conversation block each
other. `fnc_civ_arrest` claims `DUWS_civ_arrested` before its own pause and tests `DUWS_civ_closed`;
`fnc_civ_request` tests both. Neither flag is ever cleared, so a detainee who is released stays spent.

### Range: two distances, on purpose

| Step | Reach | Source |
|---|---:|---|
| Call over | 6 m | `src/duws/shared/functions/fnc_civ_stopCommand.sqf:59` |
| Interaction menu | 3 m | `src/duws/shared/functions/fnc_civ_menuAction.sqf:44` |
| Every menu row, re-tested server-side | 3 m | `src/duws/server/misc/fnc_civ_request.sqf:22` |
| Search (the player's own action, via `cursorObject`) | 3 m | `client/misc/fnc_intel_search_action.sqf` |
| Release | 3 m | `fnc_civ_release_action.sqf:27` |

The call-over reaches twice as far as everything it gates. Halting a local you can see, walking up to
them, and only then getting an exchange is the shape of the interaction; matching the two distances
meant standing close enough to talk before being allowed to ask for attention. The call-over also
carries a 15° facing cone — `abs (180 - getRelDir) > 165`, close to an aim test — so it picks the
person meant rather than whoever is standing beside them.

Call over is the gate on everything else: the menu action does not appear until the local has been told
to stop, so a player cannot work a whole town without announcing themselves to anyone in it. Panicking
civilians drop out of the call-over entirely, and the entry coming back is what tells the player the
town has settled.

### The dialog

`shared/includes/civ_menu.hpp` holds two dialogs: `civ_dialog` on idc block **8300-8399** and the bribe
prompt on **8400-8499**, both clear of every idc the mission ships (the nearest neighbours are the
disguise panel's 8000-8203 and `fobmanager.hpp`'s lone 9745). Five framed rows — intel, aid, toolkit,
recruit, arrest — each `closeDialog 0` and `remoteExec` the work to the server.

**The client does not need the town's reputation.** The rows are the same whatever the band; only the
outcome differs, and that is rolled server-side when a row is picked. `civ_town_rep` therefore stays
server-side. The per-civilian state below is a different thing and does go out.

**Rows carry no price, and a bribe gets its own prompt.** The reaction is unknown until the roll, so a
price on the row would be a guess at a demand that arrives two thirds of the time at best. Picking a row
is free of commitment; if the roll comes back `bribe`, a second dialog states the amount and the player
answers it — on `onUnload` rather than a send on each button, so closing with Escape answers too, since
an offer left hanging would block the civilian silently.

The prompt carries the demand, an **In Inventory: X** readout of the player's `Money_roll` count, and
Accept / Refuse, with Accept disabled when the count falls short so an unaffordable demand reads as
unaffordable instead of failing on click. Refusing, and being unable to pay, both close the civilian:
what the prompt buys is knowing the price before losing the contact, not a free look.

#### Everything the client greys, the server re-checks

Three client-side conditions decide what a row looks like, and none of them decides anything:

| Greyed when | Read from | Why the server cannot trust it |
|---|---|---|
| The player cannot afford a bribe | `magazines player` | A snapshot; in co-op two players can spend the same coins |
| The civilian is closed | the unit's own variables | Broadcast state a client machine holds a copy of |
| The player has already asked a local for intel this tick | `DUWS_civ_intel_asked` on the player | Broadcast state, and a dialog left open across a tick boundary reads the value it opened with |

The deduction, the spend and the range test all stay server-side, exactly as
[`economy.md`](economy.md) describes for the client-side CP pre-filters. Range is no longer greyed at
all: the action that opens the menu is itself gated to the 3 m the rows work at, so a row cannot be
reached from further away than it functions. What greying is left is defensive — a dialog already open
when a flag lands still has its rows live, and the flag only ever arrives over the wire.

#### State lives on the civilian

| Variable | Locality | Purpose |
|---|---|---|
| `DUWS_civ_stopped` | broadcast | Set when call over is answered. The menu action's condition gates on it, so nothing before it exists as an entry point |
| `DUWS_civ_closed` | broadcast | Claimed when any player picks a conversational row, whatever the roll then answers |
| `DUWS_civ_arrested` | broadcast | One hands-up attempt per civilian, claimed the same way |
| `DUWS_civ_panicked` | broadcast | Set by the panic sweep, cleared after a flat 60 s. Suppresses the call-over |
| `isSurrendered` | broadcast | Held at gunpoint. Gates Search and Release, and makes the panic sweep skip them |
| `DUWS_civ_pending` | server only | `[caller, row, amount]`, written when a roll returns `bribe`, cleared when the prompt is answered |

Everything but `DUWS_civ_pending` is broadcast because it is read off the server: the dialog is built on
the client that opens it and has to know at open time which rows are dead, and the `addAction`
conditions are evaluated on every machine that carries them. A boolean pushed when it changes beats a
request-and-wait handshake in front of every open, which would either delay the menu or pop rows grey
after the player is already looking at them — the same trade the search flag makes
([`intel_system.md`](intel_system.md#the-success-roll-is-spent-at-spawn-so-the-price-is-the-fight)).

`DUWS_civ_stopped` is written server-side, in the call-over's own server function rather than in the
client action body that triggers it: a client that owns the flag can open the menu on a local it never
actually stopped.

`DUWS_civ_pending` is the opposite case and must not be broadcast. The Accept button sends only *I
accept* — the server reads which row and how much from its own record, so a client cannot claim a bribe
it was never offered or name its own price. It records the caller too, so in co-op a second player
cannot answer someone else's prompt.

All of it lives on the unit, so it dies with the civilian and needs no registry.

### What an accepted request pays

**Intel** hands off to `fnc_intel_payout`, the single point where intel becomes something for every
source in the mission — [`intel_system.md`](intel_system.md#one-writer-per-reveal-flag-one-function-for-payout)
owns that contract, including which payout kinds exist. The menu is a faucet like the body search, and
what a faucet pays is not the faucet's business. The one thing this row must pass is an origin — the
asking player's position — because the town bucket ranks by distance.

Intel is the one row with a cap on top of the one-conversation rule: **one ask per player per 30-minute
economy tick**, spent on the attempt whatever the local answers, and greyed in the menu once spent. It
rides the same clock and the same sweep as the body search rather than starting a timer of its own.
Spending it on the attempt is what stops a player working a hostile town local by local until one of
them says yes — the reaction curve prices that walk in people, and this prices it in time.

**Recruit** reaches `fnc_recruitSuccessServer`, which clears captive and broadcasts it itself.

**Aid and toolkit are one choice, not two.** A civilian answers one request and then walks, which is
what removes the old dominance without inventing a number: same price, same odds, and the only
difference left is which item the player needs. Aid drops a medikit *and three first aid kits* — a
medikit is unusable without the medic trait, so a squad without one got nothing it could spend out of
the only favour that person does. Both items carry the same 60 s despawn: the item is handed over to be
picked up, not left as a supply dump, and a persistent one would let a single friendly town furnish a
squad's repairs for the rest of the campaign.

### Arrest

The arrest row orders hands up and nothing else. It rolls no reaction and takes no bribe — a town's
opinion does not change whether a person raises their hands. It is still one of the exchanges a civilian
only has one of, so someone already talked to is spent.

**One attempt per civilian, spent on the attempt.** A dialog row is redrawn on every open, so
`DUWS_civ_arrested` is what stops the player holding the row until the 90 % surrender lands, which would
make both the reputation hit and the 10 % runner free. Same rule and same reason as the body search,
whose claim is taken before its payout resolves (`server/misc/fnc_search_claim.sqf`).

**The town is charged −1 whether or not they comply**, because it saw the weapon raised either way. The
notification names the figure; a town already at the `-20` floor absorbs less than was asked, and the
town marker carries the standing that actually resulted.

**Two scroll actions follow a surrender, and both stay off the dialog.** They work on a civilian standing
still with their hands up, and the menu — which hides on `isSurrendered` — would have to close, wait out
the animation and reopen to offer either. Search ends in the loot table below; Release clears
`isSurrendered`, ends the surrender pose on every machine, re-enables `PATH` and has `fnc_civ_resume`
draw a fresh walking circuit.

Release exists because `PATH` is disabled from the arrest onwards and the panic sweep refuses to touch
anyone surrendered: without it a detainee keeps their hands up until the town is recycled. It returns no
reputation — the town saw the weapon raised, and letting the player undo that by being polite afterwards
would make the arrest free. **A search carries no reprisal** for the same reason: the price of an arrest
is the reputation it costs, charged the moment hands go up. Arming the detainee on a coin flip and
turning them on whoever frisked them priced it a second time, in a way no decision the player made could
influence.

#### What a search turns up

Every arrested civilian is flagged searchable, so the odds live entirely in the `civ_frisk` payout table
(`server/server_var_init.sqf`), drawn by weight rather than by a threshold ladder:

| Weight | Outcome |
|---:|---|
| 3 / 8 | 1–5 `Item_Money_roll` on the ground |
| 1 / 8 | exactly one item from Wallet_traitor / FlashDisk / SmartPhone / MobilePhone |
| 4 / 8 | nothing |

Three quarters of what is found is cash, so a frisk is a gamble on pocket change rather than a way to
farm intel. Phones share the pool with the documents because both exist only to be turned in at the HQ
terminal, which prices a phone above a wallet — a branch of their own was two names for one outcome. The
file is the one document absent from that pool, because it is also what `fnc_addRandomLoot` puts on 80 %
of enemies: pricing it for a search would price every corpse in the campaign. The intel drop is capped at
one item, since three documents off one person is three searches' worth of CP for a single frisk.

Civilians carry no coins of their own. This table is the whole of what a person is worth in cash, so the
coins in a town are a function of how many people the player is willing to hold at gunpoint.

#### What a bribe costs

Per row (`fnc_civ_rowPrice`, `src/duws/server/misc/fnc_civ_state_init.sqf:81-90`), and **not** scaled by
reputation — the curve already carries that signal by deciding whether money is asked for at all, so a
reputation term in the amount would count it twice.

| Row | Bribe |
|---|---:|
| Intel | 3 |
| Recruit | 2 |
| Aid | 2 |
| Toolkit | 2 |
| Arrest | — |

**These are placeholders chosen to make the framework testable, not balanced figures**
([`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#economy-balance)). They are anchored on the black
market, which is the price scale the player already reads — goggles at 1, pistol and optic at 5 — so
intel sits between the two. An unrecognised row returns a negative price, and callers treat that as a
reject: rows only ever come off the wire, so that is the fail-closed edge for a client sending one the
menu never offered.
