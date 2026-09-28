# Zones, towns and civilians

Two placement subsystems that both "put things at towns", plus the civilian layer built on the
second. They are no longer independent: civilian selection consumes the zone system's output, and the
dependency runs one way.

- **Enemy zone siting** ("More Urban"): where OPFOR objectives spawn — the red `"Bravo (Outpost)"`
  markers you capture.
- **Civilian town selection**: a subset of the map's real towns near the fighting, each seeded with a
  persistent civilian population. Purely civilian — not an objective.

Both are server-only and run near campaign start; civilians are registered once zone build-out has
finished. For the boot order see [`architecture.md`](../architecture.md#boot-flow).
The shopkeepers that stand in the civilian towns are in [`civilian_shops.md`](civilian_shops.md).

## Enemy zone siting ("More Urban")

Default-on (`moreUrban = 1`, `src/duws/server/server_var_init.sqf:140`; campaign menu can set `0`,
`fnc_process_campaign_menu.sqf:189-203`). Three stages during `server_init.sqf`.

| Stage | File | Produces |
|---|---|---|
| 1. Survey | `server/init_zones/fnc_moreUrban_locations.sqf` | `MASTER_allLocations_filtered` (Locations, town-weighted, shuffled) |
| 2. Siting | `server/init_zones/fnc_locatorzones_random.sqf` | one `_zonePos` per zone -> `fnc_createZone` |
| 3. Build-out | `server/init_zones/fnc_createzone.sqf` | markers, prefab, fortifications, triggers |

**Survey** enumerates `CfgLocationTypes`, pulls map Locations and towns within
`zones_max_dist_from_hq` of HQ (optionally a 135-degree arc), and requires non-town locations to hold
>5 `House` objects within 100 m (`:132-137`). The result is `towns ++ filtered-locations` (`:147`);
towns can appear in both lists, which is the only real "weighting" — the concatenation order is inert,
since siting picks uniformly at random.

**Siting** loops `zones_number` times. The `moreUrban` branch (`:92-126`): pick a random anchor, take
the centroid of `House`/`Building` objects within 400 m (`:96-117`), `findSafePos` 0-10 m around it
(`:113`), nudge 5 m off the nearest road (`:119-123`). Then distance-from-HQ (`:131`), spacing
(`:133-145`) and 500 m origin keep-out (`:148-151`) gates, then `spawn fnc_createZone` (`:158`). The
spacing gate measures edge to edge: `zones_spacing` is the gap between two zones' discs, half the
maximum radius, so the contact trigger at 1.5 times a zone's radius stops short of its neighbour. The
`else` branch (`:127-150`) is the older random-then-snap-to-building behaviour, with a 10-try
validation loop.

**Build-out** places markers, clears obstacles for prefab zones (`:61-87`), spawns a weighted prefab
(`:89-139`), and wires the spawn-wait, presence and capture triggers. A ring of 3-4 fortification
towers used to sit between the prefab and the triggers; it was deleted rather than tuned, because
siting emplacements by a random bearing at a random distance is the job
[`hardpoints.md`](hardpoints.md) now does against terrain.

**Naming.** `fnc_zone_name` (`fnc_zone_state_init.sqf`) hands each zone one phonetic-alphabet word,
drawn without repeats and pairing two distinct words past the twenty-sixth. It is called from
`fnc_createzone` rather than from either locator, because manual placement's map-click body runs on
the clicking client where a server-side allocator does not exist; both locators pass an empty name to
ask for the next one. The words carry no stringtable key for the same reason squad callsigns do not —
a translated phonetic alphabet is a different alphabet, not a translation. The prefab's kind
("Comm Station") never enters the name: it used to overwrite it, which is why a capture once reported
a kind while the map called the same ground by a number. It is a map label — marker text and the
click readout, which reads it from `DUWS_zoneKind_<key>` rather than unpicking the marker string.
Radio traffic, notifications and task text use the callsign alone.

> `getPos` on a Location is *not* a bug. The civilian system relies on it throughout
> (`fnc_civ_selectTowns.sqf`, `fnc_civ_init_Tomata.sqf`, `fnc_civ_handler.sqf:32`) and the towns
> render, so it resolves a Location's position fine; it is only stylistically inconsistent with the
> `position`/`locationPosition` used elsewhere. Whichever is chosen, selection and the runtime must
> use the *same* one or a town's trigger and its eligibility test measure different points.

### What captures a zone

One function decides every capture: `DUWS_fnc_siteTaken {key, profile, side, foe}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf`). A zone capture, a zone retake and a town clear
all call it, with only the sides swapped. It needs three tests to hold together, unbroken, for
`DUWS_captureHold` (20 s); losing any one restarts the count. The function stamps the hold itself.
Every zone and every town asks it from its own trigger, every 0.5 s.

| Test | Counts | Threshold |
|---|---|---|
| Presence | ground units of the attacking side inside the site radius | at least one |
| Garrison beaten (`DUWS_fnc_garrisonBeaten`) | **only groups this site raised**, by roster, wherever they are, plus the tokens still in its reserve pool | at or below 15 % of the site's full token count. Skipped at tier 0, which holds no garrison: a town the bands leave neutral, or ground its holder has bought no tier on |
| Ground held | **any** ground unit of either side inside the streaming ring (radius + 400 m), whoever raised it; aircraft do not count | the attacker outnumbers the defender |

The zone capture trigger has no activation. A `this` gate would stop the function from being asked
while the attacker is outside the radius, so the hold stamp would never reset. For an OPFOR-held zone
nobody is near, the garrison's live check fails first, which keeps the half-second cost to a variable
read; a BLUFOR-held zone pays one spatial query over its radius, and once the player has built a garrison
on it the live check gates that one too.

The line is 15 % rather than a tenth because a group counts as one whole token while any of its men
stands.

**The strength test counts by ownership, not by position.** Every unit a zone raises is appended to
the zone's garrison roster — the spawn band appends what every token it raises hands back, and
the zone's emplacement occupant appends the turret crews it re-mans the composition with. The raise worker empties the roster when it deploys the
composition, one act with the generation bump, so it describes the garrison now on the ground rather
than every garrison the zone has ever had. The clear has to happen there rather than where the band
is raised, because the turret crews are placed first and a later clear would drop them.

Two things follow. Units that are not the zone's own cannot restore it: a side mission's guard ring
or a neighbouring town's garrison is not on the roster, so a beaten garrison stays beaten however
many of them arrive to stand on it. And a patrol that has wandered clear of the zone is still the
zone's and still has to be dealt with.

A roster rather than a flag on each unit, because the capture condition runs twice a second while a
zone's garrison is live — walking `allUnits` to find stamped ones would put a several-hundred-entry
scan on exactly the frames a firefight is using. Anything spawned into a zone and not appended is
invisible to the test, which is the trap for whoever raises men into a zone outside its composition.

**The second test is deliberately owner-blind.** It asks whether the ground is physically held, and
anyone standing on it counts for their side whoever spawned them — a side mission's guards inside the
ring do contest a capture, even though they cannot un-beat the garrison. It counts over the whole
streaming ring, not the zone radius, so a flip leaves no outer-ring force the attacker never had to
beat.

Turret crews are on the roster so that a stream-out or a flip collects them. They are not tokens, so
they do not count toward the break line, but they contest the ground test for as long as they live.

**A beaten garrison is not the whole condition.** The garrison falling to 15 % only satisfies one test
of `DUWS_fnc_siteTaken`; another asks whether BLUFOR outnumber the OPFOR still standing
anywhere in the ring. A remnant that stays and fights therefore delays the capture only while it can
still contest the ground, rather than for as long as one man is alive somewhere in the radius.

**A flip leaves its survivors where they stand.** An engaged group cannot be ordered to withdraw
([engine gotchas](../architecture/arma_engine_gotchas.md)), so none is. `DUWS_fnc_garrisonRelease`
moves the survivors to the site's `leftover` roster and clears their garrison key, so a later wipe
records nothing against the ledger the flip has just reseeded. They fight on, and they count for OPFOR
in the retake test. `DUWS_fnc_garrisonLeftoverSweep`, run on every zone and town tick, deletes each
one once no player is within 500 m. A town clear releases its survivors the same way.

**A flip removes every OPCOM unit garrisoned at the site** (`DUWS_fnc_opcom_siteLost`), combatants
included. The break line lets a garrison fall with OPCOM tokens still unspawned in the reserve pool. A
combatant released instead would stand up inside ground that OPFOR no longer hold. A defender already on
the ground is a garrison group, so it stays as a survivor, as above.

### Zone tiers

Every zone rolls a tier I to IV when it is generated. The tier belongs to whoever holds the ground, and a
flip in either direction drops it to 0 — no garrison, and the ledger forgotten with it. An OPFOR retake
then resets it to I; BLUFOR buy their first tier like every one above it.
**Tier picks
which composition the zone fields; strength is how much of that is left.** Weights are 1/2/3/4, so
the roll is skewed to the top: most zones are the full objective and a low roll is the occasional
soft one worth taking early.

`DUWS_zoneSpawnTiers` (OPFOR) and `DUWS_zoneSpawnTiersBlu` (BLUFOR) each hold one composition per tier,
**absolute rather than cumulative** — a row is
the whole garrison, so what a tier IV zone is reads off one line instead of being assembled from
four. Tier reaches only the units a zone spawns alongside itself; the prefab, the fortification
scatter and their crews are not part of it.

**Tier moves the whole fight, dug-in slots included.** A repeated entry is how a tier fields two of
something; nothing about the *ground* multiplies a row afterwards, and the one thing that does — the
campaign's enemy multiplier — scales whole cards and applies to every OPFOR zone alike. The dug-in slots,
`garrison:garrison_element`, climb from none at tier I to four at tier IV on OPFOR's rows and three on
BLUFOR's, so only a heavier zone digs in.
`fnc_zone_tier_roll` refuses to roll twice, and tests for a missing tier rather than a positive one, so a
stored 0 never re-rolls. `fnc_createzone` is re-entrant by design — `zone_meta_array`
exists so a zone can be rebuilt through it — and a rebuild that re-rolled would change what the ground
is worth behind the player's back and disagree with the garrison peak already measured against the old
tier. A zone with no tier recorded reads as IV, so a save written before tiers existed comes back at
the strength it had rather than silently halving.

**The commander buys a zone's tier and strength as it does a town's.** `fnc_zone_garrison_fortify`
raises the tier by one, clamped at IV whatever the zone rolled, and re-stamps the full potential; the
zone's hardpoint cap rises with it (`fnc_hardpoint_zone_cap`). The buy fields only a tenth of the tokens
the new tier adds, rounded up, and files the rest as lost (`DUWS_fnc_garrisonBuyTier`), so the commander
must reinforce to field the whole tier. At multiplier 1 a step adds at most seven tokens, so a fortify
fields one of them until a reinforcement buys the rest back.
`fnc_zone_garrison_reinforce` buys back one `0.3` step through the shared ledger
(`DUWS_fnc_garrisonReinforce`, the step a town takes). On a standing garrison both re-stand it
(`DUWS_fnc_garrisonRestand`), so the refill walks the men in. Both serve whichever side holds the zone
and neither charges, so the price stays the caller's: OPCOM's candidate lists skip BLUFOR-held zones, and
OPCOM lands its own buys with no truck
([`opcom_plan.md`](../../plans/opcom/opcom_plan.md#what-ap-buys)). A reinforcement is refused at tier 0,
where there is no garrison to put men back into.

**Nothing else writes either purchase.** `fnc_zone_tier_roll` declines a second roll, so a bought tier
survives a rebuild through `fnc_createzone`, which would otherwise reshuffle ground the player has already
fought over. A zone's strength rises only through a reinforcement: the loss record lowers it. A retake
resets both: the tier to I and the strength to `0.1`.

#### Radius reaches placement, not composition

**A composition must not be scaled by a zone's radius.** The map reports a zone's tier, so a radius
multiplier puts two zones the readout calls tier IV on the ground at different strengths, for a
reason the player cannot read off either. `DUWS_fnc_zoneSpawnList` therefore takes only the tier and the
side, and nothing about the site itself.

What radius does decide is where the same men stand and what the ground is worth: the spread
`DUWS_fnc_raiseGarrison` places them over, the capture trigger's area, the map marker, and the CP
value (`round (radius / 10)`, `fnc_locatorzones_random.sqf:46`). A large zone is the same garrison
sitting thinner, which is the difference a player can see.

Towns are not scaled by radius either, so both kinds of ground size themselves the same way — see
[§Garrison tiers 0 to IV](#garrison-tiers-0-to-iv).

#### A posture reaches groups, and only groups

A zone is described by two arrays that never meet in source, and the tier reaches one of them.

| | Holds | Tiered | Where |
|---|---|---|---|
| Composition | one entry per A3 group, `posture:token` | yes, a row per tier | `DUWS_zoneSpawnTiers`, `DUWS_zoneSpawnTiersBlu` |
| Prefab | one row per object — sandbags, wire, bunkers, towers and the guns alike | no, drawn by weighted roll at zone creation (`fnc_createzone.sqf:130-140`) | the Eden composition each `init_zones/prefabs/modern/fnc_modern_*.sqf` reads (`duws_zone_*` in `src/duws/compositions/`) |

**A prefab object cannot carry a posture, because a posture is an order and there is no group to
give it to.** What carries one is whatever occupies the object, and every occupancy is discovered at
runtime rather than written down anywhere:

- a `garrison:` slot claims the nearest structure that both matches the class list in
  `fnc_apply_posture` and has `buildingPos` entries, within `GARRISON_REACH`;
- the emplacement occupant mans whatever `isKindOf "StaticWeapon"` it finds in the zone's
  composition membership. That is a seat rather than a building position, so it never passes through
  a posture at all and its orders cannot be named from a composition;
- sandbag lines, HESCO and wire are cover for whoever is near them and are occupied by nobody.

Nothing marks a prefab row as garrisonable. `isWeapon` is the only flag one carries and it exists for
placement — a gun keeps its Z so it lands on the bunker roof rather than in the dirt.

**So what is built does not scale with tier.** The prefab draw does not read the tier, which is easy
to misread now that the dug-in half of a garrison is six rows of the tier table: those rows scale the
men *holding* the ground, never what stands on it. Tiering built defences means either weighting the
prefab draw by tier, or a composition entry that places an object rather than a group — which is what
[`hardpoints.md`](hardpoints.md) does.

### Attrition carries between visits

A zone remembers what was left of its garrison when it streamed out. The zone tick calls
`fnc_zone_strength_record` on the despawn exit — before the peak is cleared and before the sweep
deletes the survivors it counts — and that stores `survivors / original` in tenths, rounded up and
floored at `0.3`.

**Garrison men are deleted by roster, never by proximity, and the rule is campaign-wide.** Town discs
overlap zone circles by design and a side mission lands where it lands, so any sweep that collects by
radius will find another system's men standing in its circle. Delete them and that system measures
its survivors against its baseline, records a mauling that never happened, and comes back thinned
every visit after.

Zones and towns each stream their own out by roster. A sweep that has no roster — `fnc_mission_cleanup`
is the one left — instead spares anything on a site roster, which is every man `DUWS_fnc_raiseGarrison`
raises and every turret crew the emplacement occupant mans. Vehicles ride along with their crew, or
deleting a transport takes its occupants with it. Everything the zone raises on its next arrival scales by that fraction: the tier
composition drops the vehicles it can no longer crew (`fnc_zone_spawn_sizes.sqf`) and every team
thins the men inside it. A garrison slot is a team, so a worn zone holds the **same** buildings with
fewer men in each rather than fewer buildings — one squad to one structure, however thin the squad
has become.

**Attrition and tier are separate axes.** Tier chooses the list, attrition thins whatever that list
produced. The prefab's gun crews are outside the tier list entirely and scale by attrition alone;
the garrison slots are on it, and are identical across tiers only because the rows say so. It is also why the readout can show a tier I zone at a full bar: small, but
not yet fought over.

**The peak is anchored, not re-based.** `DUWS_zoneBase_<key>` is the men the zone's first completed
cycle placed, and every later cycle publishes that same figure as `DUWS_zonePeak_<key>`. A garrison
that redeploys at three tenths is therefore measured against the ten: the men killed last visit stay
killed, and taking a zone you softened means killing a *tenth* of its original strength with the
objective held. Re-basing the peak on the reduced garrison would restore the full 80%-to-beat every
time the zone streamed out — the refund the mechanic exists to stop.

The `0.3` floor is what keeps that from becoming a walk-in, and it is also structural: a zone allowed
to redeploy empty would be uncapturable outright, because a zero peak refuses capture.

**Strength falls unless the commander pays, and a retake resets it.** Only a bought reinforcement restores a zone. `fnc_opfor_cap`
resets the tier to I and keeps a tenth of the tier I tokens, rounded up, when OPFOR take a zone back
(`DUWS_fnc_garrisonSeedOpforCap`), so what they put on ground they had to retake is a scratch force.
Every retake costs them the same, and a zone traded back and forth cannot converge on full strength. It used to reset to full on the BLUFOR capture instead, on
the reasoning that a retaken zone is manned by a fresh garrison; that handed the player's grinding
straight back the moment they lost the ground again.

**No hold beside it, unlike a town's.** A retake can land with players still inside the radius
(`DUWS_fnc_siteTaken`): the ground changes hands under a live fight. The presence latch the retake
re-arms keeps the seeded garrison from raising around them; it arrives on the ordinary streaming rule once
the ring has been empty.

**Where the player reads it.** The request menu's View Map mode answers zones as well as towns. A click
goes to `fnc_map_readout_query` on the server, which picks whichever revealed zone or town disc the
click landed in with the **nearest centre** — zone circles and town discs overlap by design, so the
tie has to break on something — and `fnc_map_readout_draw` draws the answer. A zone prints its tier in
roman above its garrison bar, and the bar as twenty segments, green for what is left and grey for what
is gone. The bar is the ledger's token strength. The ledger loses a token the moment its group is
wiped, so a streamed-in zone and a stowed one read the same figure, and it cannot disagree with what
arrives. A zone the player holds at tier 0 prints no bar: a full run of grey would read as a garrison
wiped rather than one that was never there.

**Where the player buys.** On a zone BLUFOR hold or a town in the BLUFOR band, the readout adds a
Reinforce and a Fortify button under the banner. Each spends BLUFOR AP at OPCOM's price for the same buy
(`OPCOM_AP_REINFORCE` 10, `OPCOM_AP_FORTIFY` 15), and a town's buy lands at once, with no truck. A button
shows only when its buy changes something: Reinforce needs a lost token and a step of at least one token,
and Fortify needs a tier below IV. While OPCOM counts the site as contested (an OPFOR sighting of BLUFOR
within the site's radius plus one grid cell, `DUWS_fnc_opcom_siteContested`), the buttons are disabled
and the readout says so. `fnc_map_readout_offer` decides what the buttons offer, and
`fnc_map_readout_buy` asks it again on the server before it spends, so a stale button cannot buy.

### Why a pack-up cannot read as a capture

Streaming deletes a zone's units after 120 s with no BLUFOR in reach, which would leave the garrison
count at zero. Two things keep that from being read as a garrison wiped:

- The zone tick clears the garrison's live flag (`fnc_zone_garrison_dropped`) on **both** its exits,
  before the sweep runs. The capture condition refuses a zone that is not live, so an empty stowed
  zone is never takeable — nor is one still mid-spawn.
- A spawn band can outlive its own zone: a large band takes longer to place than the 120 s grace.
  The raise flag stops a second cycle starting until the first reports.

**This replaced `WEST SEIZED`.** SEIZED requires the whole trigger area to be empty of OPFOR, which
made a capture a sweep of every last patrol out to the zone radius, and could be held indefinitely by
anything the engine counts as present. Counting both sides instead means a lone survivor delays a
capture only while BLUFOR do not outnumber him.

The OPFOR-takes-it-back direction is the same `DUWS_fnc_siteTaken` with the sides swapped: an OPFOR
unit inside the radius and OPFOR outnumbering BLUFOR over the same ring, held for the same
`DUWS_captureHold`. A BLUFOR-held zone starts at tier 0, so there is no garrison test until the player
buys one. A virtual OPCOM attacker has no units to count, so OPCOM runs the zone's retake statement itself
once one has stood inside the radius for `DUWS_captureHold` — but only on a zone at tier 0
(`fnc_opcom_capture.sqf`). A garrisoned zone has to be beaten, and standing its men up is what renders the
attacker to fight them: the site poller wakes a BLUFOR-held site for a virtual attacker as readily as a
live one, and any live WEST group renders an OPCOM tasking within K. Both directions are re-armed on every ownership change, in `fnc_captured.sqf`,
`fnc_blufor_cap.sqf` and `fnc_opfor_cap.sqf`, so the statement lives in four places and has to move in
all of them at once.

The capture trigger is created **server-local**, unlike the notification trigger beside it, because
the condition reads a server-side global. That also settles the evaluation-locality question the
capture handlers previously guarded against with an `isServer` assert.

### Fortifying a held zone, the HQ and a FOB

A zone's flag, the HQ building and each FOB building are R3F creation factories (`placement/fnc_site_build.sqf`).
Every factory builds from the `Fortifications` and `Static` categories. The player opens a factory with R3F's own
"Open the creation factory" action. Only a zone with a flag has one, so a zone's factory needs `VERSION_X == "MODERN"`
or `simple_zones_enable`.

**A built static weapon gets a gunner.** A zone's wake mans its builds with its own guns, for the side that holds
the zone (`DUWS_fnc_zoneManStatics`). A gun placed while the zone's garrison stands is manned at once, and a base mans
every built gun when it is placed and when a load restores it (`DUWS_fnc_buildCrewSite`). The 2 CP redeploy of the HQ
or a FOB deletes the dead build gunners and mans every empty built gun (`DUWS_fnc_buildRecrew`). A living gunner keeps
his seat. The gunners are not saved.
A zone's sleep and a FOB's teardown delete the build gunners but not a squadmate. A zone does not stow its builds
while a squadmate mans one of them (`DUWS_fnc_zoneBuildSleep`), because a stow would delete the gun with its crew. The
`Static` category holds only the statics whose config names it as their `vehicleClass`, so a mod's statics show only
if the mod uses that category.

**A held zone's flag redeploys its gun crews for 2 CP.** The flag's Redeploy Gun Crews action does the same to the
zone's prefab guns and its builds together (`DUWS_fnc_zoneRedeploy`, `fnc_zone_build.sqf`). It works only on a zone
at tier I or higher. A zone with a tier raises, and the raise adopts every seated gunner into the garrison roster that
the zone's stream-out collects (`DUWS_fnc_zoneManStatics`). A tier-0 zone never raises, so nothing would collect its
gunners. The action sits under Clear and does not need Fortification I.

**R3F moves and sells a manned build.** R3F refuses to move or sell an object with a crew. A build whose only crew is
friendly AI outside every player's group is the exception (`DUWS_fnc_buildCrewFree`): the Move action and the direct
sale have the server delete that crew first, and the drop mans the gun again. An enemy gunner, a squadmate or a
drone's own AI keeps the gun where it is.

**A factory opens only with Fortification I.** Until the team buys it, every factory's gate (`R3F_LOG_CF_disabled`)
stays closed, which hides the Open, Clear and sell-back actions. `DUWS_fnc_baseBuildArm` closes a new base's factory
when no level is owned, and the first purchase opens every base and held zone factory (`DUWS_fnc_baseBuildGrant`,
`DUWS_fnc_zoneFortGrant`).

**A zone's factory also follows ownership.** `fnc_zone_flag_logistics` sets the factory gate with the carry gate,
so the factory works only while BLUFOR hold the zone. When OPFOR retake the zone, the builds stay and OPFOR can fight
from them. When BLUFOR take the zone back, the builds count against the flag again. A base's factory stays open for
as long as the base stands.

**The credits are R3F's own running balance.** R3F spends a factory's credits on a build and refunds them on a
sale. A destroyed build is lost: nothing refunds it. A build costs at most 150 credits
(`usine_creation/determiner_cout_creation.sqf`). What adds credits depends on the site:

| Site | Credits added | Source |
|---|---|---|
| Zone | the difference between the two allowances, on each tier purchase and each Fortification purchase; a capture sets the balance to 0 with the tier | `DUWS_zoneBuildPoints`, `DUWS_fnc_zoneBuildGrant`, `DUWS_fnc_zoneFortGrant` (`init_zones/fnc_zone_build.sqf`) |
| HQ | the allowance of the current Fortification level, when the HQ is built; the difference between the two levels' allowances, on each Fortification purchase | `DUWS_baseBuildPoints`, `DUWS_fnc_baseBuildArm`, `DUWS_fnc_baseBuildGrant` |
| FOB | the same as the HQ, from when the FOB is built | `DUWS_baseBuildPoints`, `DUWS_fnc_baseBuildArm`, `DUWS_fnc_baseBuildGrant` |

| Zone tier | 0 | I | II | III | IV |
|---|---|---|---|---|---|
| Allowance (R3F credits) | 0 | 250 | 500 | 1000 | 2000 |

The zone table gives the total allowance at each tier. A zone gets the allowance of the lower of its tier and the
Fortification level, so a zone at tier III with Fortification I has 250. Tier 0 gives no allowance, so the player
must buy a garrison tier and Fortification I before they can fortify a zone.

| Fortification level | none | I | II | III | IV |
|---|---|---|---|---|---|
| Allowance per base (R3F credits) | 0 | 250 | 500 | 1000 | 2000 |
| Price | none | 10 CP | 15 CP, 15 AP | 25 CP, 20 AP | 30 CP, 25 AP |
| BLUFOR AP tier that shows the row | none | 2 | 3 | 4 | 5 |

**Fortification is a permanent support that sets the bases' allowance and caps the zones'.** The team buys its levels
in order (`fort1` to `fort4`, `client/supports/fnc_supports_init.sqf`). With no level, no factory opens. On each
purchase, `fnc_support_perm_grant` recounts `DUWS_fortLevel` from `DUWS_support_permanent`. It then adds the step to
the HQ, to every standing FOB, and to every held zone whose tier is above the old level. A FOB built later gets the
whole allowance of the current level. A restore recounts the level from the restored record, as it does for the radio
and intel levels.

**A build belongs to the factory that made it.** R3F reports each build to `DUWS_fnc_buildRegister`, which files it
under the factory's own key, `<siteKey>_builds`. That key is separate from the site's key, so a clear removes the
builds and leaves the site's composition. A zone's wake and sleep hooks deploy and stow the key with the zone
(`fnc_zone_stream_init.sqf`). The sleep does not stow it while a build is carried or loaded in a vehicle,
because a stow deletes the object from R3F's hands. A base never streams, so its builds always stand. A FOB's
builds go to the sweep when the FOB is dismantled or destroyed (`fnc_fob_deregister.sqf`).

**A carried object stays frozen until the server checks its drop.** Every R3F carry freezes the object at pickup
(`deplacer.sqf`), as the depot freezes a vehicle. After a drop, the carrier sees "Placing ..." for R3F's 5 s wait.
Then the server checks the position where the carrier set the object down, not a position where it fell
(`DUWS_fnc_carryDropped`). The server thaws the object under a 2 s damage guard and tells the carrier that the object
is placed. It mans a built gun only after the guard ends.

**A build and a zone's flag must stay within 100 m of the site's centre.** If a drop is out of reach,
the server moves the object back to its last good position and tells the carrier. A new build and a build unloaded
from a vehicle both start as a carry, so the one check covers creation, unloading and moving. A new build that is
dropped out of reach has no good position, because R3F creates it high in the sky before the carry. So the server
deletes it and refunds its full cost to the factory that made it (`DUWS_buildFactory`). A flag always has a good
position, because `fnc_zone_flag_logistics` records its spawn position.

**The builder vehicle cannot fortify a base.** R3F's client-side factory condition (`config.sqf`) refuses the
builder vehicle's factory while the vehicle stands inside the ring of the HQ or a FOB (`DUWS_base_keep_radius`,
250 m, the ring on the map). The drop check also moves a builder-vehicle build that is dropped inside a ring back to
its last good position. It deletes a new one without a refund, because the builder vehicle builds for free. So only a
base's own budget fortifies it. The ring is wider than the 100 m reach of a
base's builds, so no factory can build between 100 m and 250 m from a base.

**Clear Fortifications removes every build of that factory at once** and refunds the full cost of each one that is
intact. A wreck refunds nothing, as a sale of it would not. The action sits directly under R3F's "Open the creation
factory" action and shows under the same condition. It leaves a build that a player carries or a vehicle holds.

**A sale refunds 100%.** `R3F_LOG_CFG_CF_sell_back_bargain_rate` is 1 for every factory
(`config_creation_factory.sqf`), and R3F still reduces the refund by the object's damage. A deploy rebuilds each
build as a new object, so `DUWS_fnc_siteBuildDeploy` sets R3F's factory marker (`R3F_LOG_CF_depuis_usine`) and the
build's site (`DUWS_buildSite`) again. Without the marker, a redeployed build cannot be sold.

**A site's build sells back to its own factory from anywhere in the site.** R3F's direct sale ("Send back to the
factory" on the build) asks `DUWS_fnc_canSellTo` which factories accept the build. A build with a site
(`DUWS_buildSite`, broadcast) goes only to the factory of the same site, at any distance, because the drop check
already holds it within 100 m of that site. Every other build keeps R3F's rule: the nearest factory within 20 m.

**The builds and the balances are saved.** The snapshot key `zoneBuilds` holds each zone's balance and builds, and
`baseBuilds` holds the HQ's and each FOB's, as a class, a world position and an orientation per build
([`campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#world-and-placement)). A FOB is saved by
its position, because its site key carries a netId that a load renews.

## Civilian town selection

Selects real map towns near the fighting and gives each a persistent civilian population with map
markers. Gated on `CIV_PRESENCE`; no synthetic locations are created.

| Stage | File | Produces |
|---|---|---|
| 1. Selection | `server/civilian/fnc_civ_selectTowns.sqf` | ranked shortlist of `[Location, buildingCount, hqQuota]` |
| 2. Registration | `server/civilian/fnc_civ_init_Tomata.sqf` | `civ_locations` / `civ_radii`, per-town runtime gate and markers |
| 3. Runtime | `server/civilian/fnc_civ_handler.sqf` (`_ravage` / `_wbk` twins) | fill the town on arrival, empty it after departure |

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
sparse map's hamlets both span 1 to 5.

In hardcore it also decides what starts on the map: the towns the HQ anchor claimed in selection's
first wave are visible, and every other one is hidden until it is walked into or bought with intel,
exactly as an enemy zone is. The flag travels on the shortlist entry rather than being recomputed from
distance later, because the stand-in swap and the overlap cull both reshuffle the registry — the HQ's
opening three are a selection fact, not a geometric one. Hiding is marker alpha and nothing else:
trigger, garrison and population run either way. `civ_visible` holds the state; the reveal machinery
is in [`intel_system.md`](intel_system.md).

### Ownership bands and the garrison

A town's reputation runs `-20 … 20`, and every system that reads ownership from it reads it as a *band*
rather than a magnitude, so the thresholds are a contract between them:

| Band | Reputation | Pays | Garrison |
|---|---|---|---|
| BLUFOR | `>= 10` | BLUFOR AP | tier 0, and every tier above it is bought |
| Neutral | `-9` … `9` | nobody | none, and none can be bought |
| OPFOR | `<= -10` | OPFOR AP | tier I, and no higher from reputation |

The bands are read through `fnc_civ_townOwner`, the one place the two thresholds are spelled out, so the
markers, the income and the garrison cannot disagree about which side a town is on.

A town that enters a new band posts a card to every player, as a zone capture does: `town_blufor`,
`town_opfor` or `town_neutral` (`fnc_town_rep_adjust`). The card fires even when the passive AoI drift
causes the crossing, because a crossing is rare and the drift's own reputation cards are silenced. A
hidden town that enters the BLUFOR band is revealed first, quietly, so its `town_blufor` card is the
only announcement. A hidden town that enters another band gets no card, because the card would name
ground that the map does not show.

### Garrison tiers 0 to IV

**Reputation decides *whether* a town garrisons; it does not decide how hard.** Crossing `-10` is the
capture — it writes tier I and nothing deeper in the negative writes more. Tiers II to IV are the
OPCOM's to buy, so a town the player has merely ruined is not automatically a hard one:
the enemy has to have spent on it. Crossing `+10` hands BLUFOR nothing at all: every tier of a friendly
town's garrison is bought, the first one included. Tier 0 is a town nobody garrisons, which is where the
neutral band and an unbuilt BLUFOR town both sit.

The tier is stored per town in `DUWS_townGarrisonTier` and written only through
`fnc_town_garrison_setTier` (`server/civilian/fnc_civ_state_init.sqf`) — a number per town, so it
serialises. `DUWS_townGarrisonOwner` is stamped beside it by that same writer, and says whose tier it is:
one reputation step can carry a town across both bands at once, and the tier alone cannot say whose men
it owes. Any change of owner discharges the garrison and forgets its ledger before the new owner is
served. Towns that start inside an enemy zone are seeded at tier I rather than 0: they are enemy
ground before anyone has played a minute, and reading them as ungarrisoned would have the commander
appraise them as neutral.

| Tier | Fields | Reached by |
|---|---|---|
| 0 | — | not OPFOR ground |
| I | Patrols, a team, a weapons team, a car | reputation `<= -10` |
| II | The above heavier, plus a sniper pair, an APC and a dug-in element | purchase |
| III | The above heavier, with wide-patrol teams, a second APC and a second dug-in element | purchase |
| IV | The above, plus a lone IFV and more building-occupying units | purchase |

A BLUFOR town fields a thinner set of rows: no sniper pair, one patrol fewer at every tier, a weapons team
only from tier III, and at most two dug-in elements and one APC.

A purchased tier arrives mostly owed. `fnc_town_garrison_fortify` raises the tier by one, never from
tier 0, and files all but a tenth of the tokens the raise adds, rounded up, as lost
(`DUWS_fnc_garrisonBuyTier`), exactly as a zone fortify does. A town step adds at most five tokens per
multiplier copy, so below multiplier 2 a town buy fields one new token until
`fnc_town_garrison_reinforce` buys the rest back. The step from 0 to I is the reputation band's,
written through `fnc_town_garrison_setTier`, and fields whole. On a standing garrison the garrison
thread re-stands the town at the new tier on its next tick.

The compositions live as data in `DUWS_townSpawnTiers` and `DUWS_townSpawnTiersBlu`, in the token vocabulary
`DUWS_fnc_zoneSpawnOne` already understands — the same spawner the zone compositions use, so a town
garrison inherits faction auto-detection for free.

**A town's set is its own, carrying a zone tier's infantry weight but none of its heavy armour or
air — no tanks, no attack helicopters, armour held to a lone IFV at tier IV.** Neither set is scaled
by the ground's radius ([§Radius reaches placement, not composition](#radius-reaches-placement-not-composition)):
a large town scaled up stops being a garrison and becomes a zone that happens to have civilians in
it, which is the distinction static emplacements and armour exist to draw.

**Rows are absolute, not cumulative** — a row is the whole garrison for that tier. A tier bought
while the garrison stands raises `DUWS_fnc_spawnDiff` of the standing composition against the new
one, counting duplicates, so going from one team to two owes one team rather than two. The men that
reinforcement adds are *added* to the strength baseline rather than re-measured from it, so
casualties the player has already inflicted are not refunded. A retuned table cannot order a standing
garrison to shrink: a smaller composition diffs to nothing rather than to something negative.

**Buying a tier and the men arriving are separate acts.** Reinforcement is deferred while BLUFOR
are within the same radius the arrival test uses — men
materialising around a player who is already in contact reads as the mission cheating, which is the
pop-in the hold exists to prevent, and worse mid-fight.

**A hold covers upgrades too, by structure rather than by a second test.** Reinforcement requires a
standing garrison, and only the hold-gated branch raises one — so a tier bought seconds after a town
falls cannot arrive early. It raises the stored tier, and the first spawn reads that tier whole once
the hold lapses: a town captured and immediately bought up to III arrives as a
tier III garrison in one go, not as a tier I followed by a top-up. The tier stays owed and lands on a
later cycle rather than being lost, so the commander may raise a contested town at any time and pays
for it whether or not the player is standing there. This is why the deferral lives in the garrison
thread rather than in the commander's appraisal: a purchase made while the player is far away would
otherwise still pop its men in the moment they walked back.

**It is units only — no static emplacements and no prefab**, because built defences are what make a
zone an objective and a town must not compete with one. Its dug-in squads hold buildings instead, one
fewer at tier IV than a tier IV zone of the same side.

**Clearing destroys the purchase, not the ownership.** The tier files back down to I rather than to
0 — the town is still enemy ground, and what was beaten is the commander's spending, not the enemy's
claim. No refund either: with one, a player clearing towns would hand the enemy its AP back and the
enemy would never climb.

### Arrival, the hold and the clear

Presence uses the same arrival test zones use (`fnc_duws_bluforNear`) rather than a presence trigger of
its own, which would fire the instant anyone crossed the radius and whose handle is discarded at
creation anyway. The clear is decided by the rule that takes a zone, `DUWS_fnc_siteTaken`: a BLUFOR
unit inside the town radius, the garrison beaten to 15 %, and BLUFOR outnumbering OPFOR over the
town's streaming ring, all held for `DUWS_captureHold`. As at a zone, each town asks it from its own
trigger every 0.5 s, with the sides swapped when the town is BLUFOR's — its garrison is cleared by
OPFOR on the same terms. The trigger asks only at tier I or above, because a tier 0 town garrisons
nobody and has nothing to clear. OPFOR do not wait to be walked into either: OPCOM's Attack targets a
garrisoned BLUFOR town alongside its zones, and marches a unit at it
([`../../plans/opcom/opcom_plan.md`](../../plans/opcom/opcom_plan.md#appraisal)).

A cleared BLUFOR town files back to tier 0, not tier I, and its ledger is forgotten: nobody hands BLUFOR
a first tier, so a beaten garrison cannot leave them one. The reputation step is toward neutral either
way, so neither side can be shoved past the middle by force alone.

### The mobilising hold

A town raises no garrison for 30 minutes after its reputation crosses `-10`, and the readout names
that window `Mobilising`. Reputation is spent *inside* a town — you lose it by killing civilians there
or wrecking its buildings — so at the instant a town flips, the player is standing in it by definition.

**`MOBILISING` does not block a purchase.** A town that has only just fallen is exactly the ground the
enemy should be free to commit to, and the men have not arrived either way, so a tier bought inside
that window is folded into the first spawn rather than arriving as a second wave.

A clear arms no hold. The commander may reinforce or fortify a cleared town at once; OPCOM's
reinforce is what rebuilds it.

**The clock lapsing is not on its own permission to spawn.** A player who took or cleared a town and
never left is still standing in it, and the arrival test would read them as having just walked up. So
the crossing and the clear both latch the town until it has been empty of BLUFOR once — leaving and
coming back is the only way to meet the garrison.

The hold stores a `diag_tickTime` deadline, which is wall clock and so cannot be shortened by the
mission's time multiplier. A savegame does not restore that clock, so `fnc_town_garrison_holdAt`
treats a deadline further out than the hold as one this session cannot have written and spends it;
otherwise a reload would pin a town for the rest of the run.

Towns seeded into the band at campaign start — the ones whose radius overlaps an enemy zone — arm no
hold, because nothing crossed. They are pre-existing enemy ground and garrison on sight.

**A town garrison streams like a zone.** It is raised when a player arrives and deleted once the town
has been empty for two minutes, so a long session no longer leaves live men in every town anyone has
ever walked through. Three things fall out of that and each is load-bearing:

- **What it took is already recorded.** Each wiped group filed its token on the ledger as it fell,
  so a garrison ground to one group comes back as one group. Streaming refunds nothing on the walk
  home.
- **The live flag goes with the men.** The clear refuses a town that is not live, so a player walking
  back into a town whose garrison merely streamed out is not paid a clear — the reputation step and
  the tier reset — for a fight that never happened. A raise with nothing to stand is adopted, so a
  player standing in the town does not re-raise it every tick, but it never goes live.
- **The cycle ends there.** Nothing after the teardown describes a town without a garrison, and the
  reinforcement test in particular would read the emptied deployment against a live tier and raise
  the whole composition again, streaming the garrison out and back in on the same pass.

Deleting them outright is safe here: by definition nobody is inside the radius plus 400 when this
runs, so there is no one to watch them vanish.

**Both streams start latched, zones included.** The arrival test fires on anyone inside the radius
plus the buffer and cannot tell somebody walking up from somebody already standing in the middle — so
an occupant whose first pass finds a player there would raise the garrison around them. The zone
and `fnc_civ_garrison` both begin held until their ground has been seen empty once, which costs a
single poll for the ordinary zone or town nobody is near and is the whole guard for the case that
matters: a campaign generated under a player, or a town seeded into the band at start with one
already inside.

A stream-out needs no latch, because it only happens once the player has left. **A zone retake does**:
it can land with players still inside the radius, and the arrival test reaches 400 m further, so anyone
on the approach counts as near too — so the zone tick re-latches when the zone returns to OPFOR hands and
holds until the whole ring is empty, exactly as at campaign start.

The town side latches on the same flag on the crossing and on the clear.

The band is the condition, not a one-shot flag — a town driven back below `-10` gets a new garrison,
and a town lifted out of the band while its garrison lives has it cleared off the map.

`fnc_town_rep_adjust` applies a crossing when it writes the reputation, through `DUWS_town_band`
(`fnc_civ_garrison`), so the tier changes with the map colour and not on the next poller pass. Leaving
the band forgets the town's ledger, removes OPCOM's units garrisoned there and releases the rest bound to
it, whether or not a garrison stands. The next garrison tick then collects any men still standing.

### What clearing a garrison actually buys

Three things, and only one of them is reputation:

| | |
|---|---|
| Reputation | `+10`, an instalment against the debt — not a discharge |
| Tier | back to I, so the commander's spending is gone but the town is not |
| Strength | `0`: every tier I token is filed lost; only a paid reinforcement buys them back, `+30 %` each |

**The reputation step is deliberately an instalment.** Discharging the whole debt let a player ruin a
town to `-20` and walk away square on a single fight, which made the reputation that the garrison was
supposed to be the price of effectively free. At `+10` a town driven to the floor takes two clears to
reach neutral — `-20`, `-10`, out at `0` — because the band is inclusive at `-10` and a town sitting
exactly there still garrisons. The step is self-limiting for the same reason: only a town at or below
`-10` can hold a garrison to clear at all, so the most this path can ever reach is `0`.
Reputation cannot be turned friendly by force — aid and heals are still the only way into the BLUFOR
band. The mirror holds on the other side: OPFOR clearing a town the player garrisoned pays `-10`, toward
neutral and no further, so neither side reaches the other's band by beating men.

**The empty garrison is the lasting half, and it is a bill rather than a brand.** The clear stamps
the town's full at tier I and files every token lost, so it comes back with nothing standing, and
nothing restores that on its own — but the commander can buy it back, `+30 %` a reinforcement. That is
what makes clearing worth doing when the reputation step alone would not be: the enemy cannot walk the
loss back by waiting, only by *paying*, out of the same pool they would rather spend on ground they
have not lost.

**A town must be resupplied before it can be cleared again.** An empty raise never goes live, and the
clear refuses a town that is not live, so the `+10` is paid only for a garrison that stood. The
commander has to reinforce or fortify the town, or home an OPCOM defender there, and its next raise
stands those men.

**Upgrade and reinforce are two sinks, not one.** The tier says what the town would field; the
strength says how much of it stands. A commander can hold a tier IV town hollow, fill a tier I one, or
pay for both, and each costs separately. Folding them together would make a beaten town cheap to
restore precisely *because* it was beaten, since one payment would buy back the composition and the
men at once. `fnc_civ_garrison` raises men on either moving, so a reinforcement bought against a
standing garrison arrives the same way an upgrade does.

**A clear latches the town.** A player who cleared the town and never left is still standing in it,
and the arrival test would read them as having just walked up. So a clear latches the town until it
has been empty of BLUFOR once: leaving and coming back is the only way to meet the new garrison, and
it cannot appear around someone who never went away. The clear files the town back down to I through
`fnc_town_garrison_setTier`, which records ownership and refuses nothing.

### Zone and town, side by side

The two systems answer the same four questions differently, and the differences are not arbitrary:
a zone is ground with an owner, a town is ground with an opinion.

| | Enemy zone | Civilian town |
|---|---|---|
| "OPFOR holds it" means | it is in `WARCOM_zones_controled_by_OPFOR` | its reputation is `<= -10` |
| How OPFOR come to hold it | generated that way, or retaken | the player ruined it — killed civilians, wrecked buildings |
| The player's win | ownership flips, permanently, and pays a CP bounty | the garrison is cleared, worth `+10` reputation — an instalment, not the ground |
| How OPFOR get it back | stand inside the radius and outnumber BLUFOR over radius + 400 m for 20 s, players there or not (`DUWS_fnc_siteTaken`) | reputation falls back below `-10` |
| Strength when OPFOR take it | tier I at `0.1` on the retake (`fnc_opfor_cap`) | tier I at `0.1` on crossing `-10` |
| Strength after being beaten | none — a beaten zone is BLUFOR's, at tier 0 until they buy one | tier I at `0` on the clear, or tier 0 if the town was BLUFOR's |
| Time gate | none | `MOBILISING` 30 min |
| Presence latch | thread start, and every retake | thread start, every crossing and every clear |
| Mobilising | on a retake, until the peak publishes | on crossing `-10`, until the hold and latch both clear |

**Why the zone needs no time gate and the town does.** A zone is retaken by force on the ground — the
attackers who won it already stand there — and the latch the retake re-arms holds the seeded garrison
until the ring has been empty once. A town's flip has no such force: reputation is spent *inside* the
town, so the player is standing in it at the exact moment it crosses. The hold is what buys that
garrison its distance.

**Why the strength seed is symmetric anyway.** Both sides of that difference converge on the same
rule for ground OPFOR have just taken: a zone retaken and a town that crosses `-10` each start at tier I
and `0.1`. Neither climbs back on its own, only by a purchased reinforcement, so grinding either one
down is worth something that outlasts the visit.

### The life of a zone, and the life of a town

The mechanics are in the sections around this one; what they do not give is the order. Both traces
name the player-visible state at each step, so a reader can find which section owns a step they care
about.

**A zone.**

| Step | What happens | State on the readout |
|---|---|---|
| Generated | OPFOR-held. Rolls a tier I–IV, weighted to IV. Strength `1.0`. No men | tier + full bar |
| You come within radius + 400 m | Props deploy, turret crews man the prefab's guns, the garrison is raised: the tier composition less its lost tokens | tier + bar |
| You leave for 2 min | The zone's own men deleted by roster, props stowed. Losses are already on the ledger | tier + the bar it will return at |
| You stand inside the radius, beat it to 15 % **and** outnumber OPFOR over radius + 400 m, all for 20 s | Ownership flips. First-capture bonus, AP swings. Tier drops to 0 and the ledger is forgotten. Survivors fight on where they stand and are collected once no player is within 500 m. The prefab and its turrets stay, yours now | `Held by BLUFOR` |
| You buy a tier on it | Tier I, a tenth of its tokens fielded and the rest owed. Your garrison raises when you next come within radius + 400 m, crews the prefab's guns, and wears down on the same ledger | tier + bar |
| OPFOR retake (`DUWS_fnc_siteTaken`) | OPFOR stand inside the radius and outnumber BLUFOR over radius + 400 m for 20 s, players inside or not — and beat your garrison first, if you built one. Tier reset to I, a tenth of its tokens kept, rounded up. Streaming re-latches | **`Mobilising`** |
| Either commander spends | Fortify buys composition, reinforce buys strength — the same two sinks a town has, landed with no truck. Whoever holds the ground may buy for it | tier + bar |
| You return, after the ring has been empty once | Garrison raised at whatever it now stands at | tier + bar |

**A town.**

| Step | What happens | State on the readout |
|---|---|---|
| Generated | Neutral — unless its radius overlaps an enemy zone, which starts it at `-20`, tier I, no hold | none |
| You ruin it past `-10` | Tier I written at once, a tenth of its tokens kept, rounded up: enemy ground on paper. 30 min hold, latch armed | **`Mobilising`** |
| Hold lapses, you have left once, you return | Garrison raised: the tier composition less its lost tokens | tier |
| The commander spends | Upgrade buys composition, reinforce buys `+30 %` strength. Independent, and both land as men when you are not looking | tier |
| You stand inside the radius, beat it to 15 % **and** outnumber OPFOR over radius + 400 m, all for 20 s | `+10` rep, tier back to I at strength `0`, survivors fight on, latch armed | tier |
| …unless that `+10` cleared `-10` | Tier 0, garrison deleted | none — neutral |
| You aid it past `+10`, then buy a tier | Your own garrison, bought from nothing, streaming and wearing down as the enemy's did. OPFOR clear it on the same rule with the sides swapped, for `-10` rep, and it files back to tier 0 | tier |
| You leave for 2 min | Men deleted by roster; losses are already on the ledger | as above |
| You have left once, you return | Garrison raised from whatever the commander has bought since. With nothing bought, nothing stands and the town cannot be cleared | tier |

The shape to take away: **a zone changes hands, a town changes its mind.** Everything else follows
from that.

### What the two share, and what they do not

A zone and a town differ in what they *are*; they do not differ in how a garrison is raised or how it
wears down. Those two mechanisms are shared outright, and everything else is deliberately separate.

| Shared | Where | Why it can be |
|---|---|---|
| Attrition | `fnc_garrison_strength_init.sqf` | One token ledger keyed by a string — `zone_<x>_<y>` or `town_<n>`. Owns the seeds and the reinforce step. `fnc_zone_strength` and `fnc_town_garrison_strengthAt` are thin wrappers naming their key |
| Taking ground | `DUWS_fnc_siteTaken`, `DUWS_fnc_garrisonBeaten`, `DUWS_fnc_garrisonRelease` | Presence, the break line, the count over the streaming ring, the hold and what happens to survivors are one rule the player learns once |
| Raising men | `DUWS_fnc_raiseGarrison` | The stagger and the search flag are rules about raising a garrison, not about which ground is raising one |
| Token vocabulary | `DUWS_fnc_zoneSpawnOne`, `DUWS_fnc_teamRoster`, `fnc_zone_thin`, `DUWS_fnc_spawnDiff` | A team means the same thing wherever it is raised, down to the men it fields |
| Standing orders | `fnc_apply_posture` | A composition entry is `posture:token`. What a group does is a property of the ground it was raised on, not of its roster, so the same team patrols at one site and holds a building at the next |

**Not shared, and not candidates for it:** ownership (a list versus a reputation band), what a capture
means, the hold, the two purchases, and composition props — a zone stows and redeploys a prefab and
re-crews its turrets, a town has no composition at all. Merging the two threads would put one large
conditional through the middle of a lifecycle rather than remove anything.

The gain is not line count. It is that a rule now has one place to be wrong in: the tenths
quantisation was written out twice and the `survivors / baseline` record three times, so a change to
either used to mean finding every copy.

### The OPFOR mobilising state

`Mobilising` means OPFOR own the ground and their men are not on it yet: a town that crossed `-10`, or a
zone retaken off BLUFOR. It exists because printing a tier in that window would report a garrison that
is not there. A town worked back out of the band is neutral, and `fnc_town_garrison_clearHold` drops
its hold with the claim.

**A second condition is not a state.** OPFOR hold it, no men are standing, and
nothing has changed hands — the garrison merely streamed out, or nobody has ever visited. The readout
prints the tier, which is the honest answer: that is what the player will meet when they arrive.
`Mobilising` cannot be inferred from the absence of a garrison for exactly this reason, which is why
a zone carries an explicit `DUWS_zoneMobilising_<key>` flag rather than testing for a missing peak.

### Tuning: the levers, and what each is wired to

All of it is expected to move once it has been played. What follows is where each number lives and —
more usefully — **which of them cannot be moved alone.**

| Lever | Where | Moves |
|---|---|---|
| `TOWN_HOLD_MOBILISING` `1800` | `fnc_civ_state_init` | how long after falling a town stays empty |
| `REINFORCE_STEP` `0.3` | `fnc_garrison_strength_init` | what one reinforcement buys, town or zone |
| Break line `0.15` | `DUWS_fnc_garrisonBeaten` | how far a garrison must be worn before its ground can be taken |
| `DUWS_captureHold` `20` | `server_var_init` | how long both capture conditions must hold, zone, town and OPCOM alike |
| `CLEAR_REP` `10` | `fnc_civ_garrison` | what one clear repays |
| `OPFOR_BAND` `-10` | `fnc_civ_garrison` | where a town changes sides |
| `grace` `120` | the occupant record, for both zones and town garrisons | how long empty ground waits before streaming out |
| `buffer` `400` | the occupant record | how far out arrival is noticed (a town's crowd uses 200) |
| `GARRISON_REACH` `300` | `fnc_apply_posture` | how far a garrison squad looks for a building to hold |
| Tier roll weights | `fnc_zone_state_init` | how often a zone is soft |
| The composition tables | `fnc_zone_spawn_sizes`, `fnc_civ_state_init` | what a tier *is*, editable through the TUI |

**Couplings that fail quietly.**

- **The OPFOR cap seed sits at the break line.** A site OPFOR have just taken keeps a tenth of its
  tier I tokens, rounded up, which is at or under the `0.15` line at every multiplier except a tier I
  town at multiplier 1 (one token of five). Such a site reads beaten from its first raise, and only
  the count over the ring holds it until the commander reinforces. Moving either number changes that
  for every capture at once.
- **`CLEAR_REP` decides the clear count non-obviously.** The band is inclusive at `-10`, so `+10` takes
  a town from `-20` in two clears, not one. Any change here should be checked against the sequence
  rather than divided.
- **`TOWN_HOLD_MOBILISING` doubles as the stale-deadline bound.** `fnc_town_garrison_holdAt` treats a
  deadline further out than the hold as one a previous session wrote. Add a longer hold without
  moving that bound and a genuine deadline gets discarded as stale.

**A figure that is arithmetic rather than balance.** OPFOR's tier IV zone row lands on twenty-seven groups,
which at full garrison density is also the site's group ceiling — raising it raises what every tier IV zone on the map costs
the server, not just the one in front of the player.

### BLUFOR inherits nothing

**There is no destroyed state, and a captured zone or town hands the player no garrison.** When
BLUFOR take ground it simply has none — no tier, no strength, the ledger forgotten with the flip —
and building one is the player's job and their expense.

A bought tier fields a tenth of what it adds and owes the rest, so the first buy stands a thin tier I
that climbs by **30 % per reinforcement** — the same two sinks and the same ledger the enemy commander
spends on. The garrison itself is the same model on its own weaker tier rows, with no enemy-multiplier reserve copies, raised through BLUFOR's hulls and
their own Army Power rungs, streaming and wearing down exactly as the enemy's does
([`garrison_and_reserves.md`](garrison_and_reserves.md#whose-garrison-it-is)).

So the BLUFOR side is not a mirror of the OPFOR one. OPFOR garrisons *decay* from a tier they were
given and are rebuilt by a commander spending AP; BLUFOR garrisons *accumulate* from nothing at the
player's cost. A beaten town garrison files back to tier I for OPFOR and to tier 0 for BLUFOR, for the
same reason: nobody hands BLUFOR a tier, so nothing can leave them one. `Mobilising` is an OPFOR-only
label because only OPFOR arrive on ground they already own — a BLUFOR garrison never arrives, it gets
built.

**The player pays OPCOM's price in AP.** Neither buy charges on its own; the View Map readout charges
`OPCOM_AP_REINFORCE` and `OPCOM_AP_FORTIFY` from BLUFOR's AP
([§Attrition carries between visits](#attrition-carries-between-visits)).

### The guards belong to streaming, not to a side

Every latch, hold and presence test above exists for one reason: **a force that arrives on its own
must not materialise in a player's view.** Today that is OPFOR-only, but only because OPFOR is the
only side with anything that streams. The rule is about *how* a force arrives, not whose it is.

Three cases, and the distinction that separates them is whether the player asked:

- **Summoned — no guard, ever.** A requested squad arrives where the player asked, when they asked;
  the pop-in *is* the delivery. Guarding it would be guarding against the feature.
- **Streamed — guarded.** The zone band and the town garrison arrive under their own schedule, so
  they get the latch, and towns get holds on top because their flip happens under the player's feet.
- **Neither — nothing to guard.** The HQ and FOB garrisons are placed once with the base and never
  respawn, so there is no arrival to hide.

**A BLUFOR-held zone or town is the second case too**, and it streams on the machinery the enemy's
does — the same latch, the same grace, the same worker. It takes no holds: those exist because OPFOR
arrive on ground they already own, and a BLUFOR garrison never arrives, it is built
([§BLUFOR inherits nothing](#blufor-inherits-nothing)). There is nothing to defer.

**One test had to widen for it, and one had to narrow.** The shared presence answer watches for BLUFOR,
which on BLUFOR ground would leave an assault walking into an empty site and taking it off men who never
rendered. A site declaring `enemyAware` also wakes, while its ground is BLUFOR's, for an attacker inside
the ring — including a virtual OPCOM one, which stands on no unit list and would otherwise be invisible
to it (`fnc_site_hostileNear`, the one place that question is answered). That wake is also what renders
the attacker: `fnc_opcom_task_step` renders a tasking within K of any live WEST group, so the garrison
standing up is what brings the fight into the world.

The narrowing is the friendly half. On ground BLUFOR hold, presence counts **players only** — a garrison
the player built is friendly AI standing inside its own ring, so the AI arm of `fnc_duws_bluforNear`
would read it as an arrival and hold the site awake for the rest of the campaign. A site that never
sleeps never re-raises, which is how the player would come back to an empty town. The helper takes a
`_playersOnly` flag for it, and the poller, the zone raise worker and the town raise worker all set it
off the same owner derivation.

**Bases are a special case, and fast travel is why.** The `freeze` disposal mode freezes their garrisons
rather than deleting it, and the usual reason given — that rebuilding would hand back every soldier
who had been killed, a free version of the redeploy the player would otherwise pay for — is only half
of it. The other half is that a FOB is a *fast-travel destination*: a player can be standing in one
with no approach at all, so a garrison that streamed would have to arrive around them every single
time they travelled. Freezing sidesteps the problem instead of guarding against it, because a frozen
unit never has to arrive.

**That generalises into the one thing that would break these guards.** Every presence test here
assumes the player *approaches* — that they cross the ring from outside before they reach the middle.
Any instant insertion defeats that assumption, and fast travel is the mechanic that does it. The HQ
and the FOBs are safe because neither streams.

The rally point is the one destination that can stand anywhere, so it is the one that can land inside
a zone or a town radius. What bounds it is the rally's own clearance rule rather than a latch: the
flag is deleted as soon as a hostile is within 200 m of it
([`fnc_rally_init.sqf`](../../../src/duws/server/supports/fnc_rally_init.sqf)), so a rally cannot stand
where a woken garrison already rendered, and a garrison that streams in behind a traveller does so from
at least that far off. The latch is deliberately *not* re-armed on arrival: holding the garrison down
until the ring cleared would hand the traveller the zone uncontested, which is worse than the pop-in
it would hide.

HALO and paradrop do not have this problem, and it is worth knowing why rather than assuming.
`fnc_duws_bluforNear` measures in three dimensions — `nearEntities` is a sphere and `distance` is 3D
— so a player inserted at altitude over a zone is thousands of metres away by its reckoning and does
not trip it until they are genuinely close.

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

Per town, `fnc_civ_handler.sqf` is the enemy zone gate: a town fills once it
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
| Grace | 120 s | 60 s | Towns are disjoint, so a player is inside at most one, and a long grace leaves a trail of populated towns behind anyone crossing the map. Exactly half, which is what `fnc_civ_handler.sqf:25` records itself as. |
| Reach | radius + 400 | radius + 200 | `zones_spacing` keeps zone edges only half the maximum radius apart (250 m by default), so 400 can stream a neighbour zone in as well, and zones are few enough to afford that. Towns are only culled until their discs stop touching — `(r1 + r2) × 1.05` — so two 100 m towns can sit 210 m apart, and 400 would stream three in at once. |

The reach buffer applies to arrival only; the fill still uses the town's own radius, or the crowd would
be spread over the open ground the buffer reaches into. What it does double-trigger is self-limiting:
radius is `buildings × 10` floored at 100, so the tightly packed pairs are the ≤10-building towns, and
`civ_pop_<n>` caps their population at that same count.

That trail is the thing to keep bounded, because the ceiling only thins it. `fnc_civ_liveTarget` gives
one town the density setting in full, soft-caps the campaign at three towns' worth, then throttles the
rest proportionally down to a floor of three apiece — so every occupied town still reads as inhabited,
and the overshoot tracks how many towns are occupied at once rather than the density setting. The grace
period is what decides that count, which is why it is 60 s and not the zone gate's 120. The bound matters because every
civilian holds its own group so it can wander independently, and the engine stops issuing groups at
roughly 144 per side; past that `createGroup` returns `grpNull` and a fill produces nobody. That is why
the top option is 20 and not 30: at 30 the tail reaches roughly 145 groups across six concurrent towns,
level with the limit, where 20 tops out near 97 and leaves the setting safe at any number of towns a
campaign can actually occupy.

The throttle is applied at fill time and never revisited, so the order towns fill in decides who is
thinned: the first town in keeps its full crowd while later ones are cut. Under the old model the
recycle pass re-ran the same calculation every 90 s; nothing does now.

The collapse extends to `fnc_civ_garrison`, which is the harder case: it polls on
`fnc_duws_bluforNear` rather than on a player list, and that helper is a per-position `nearEntities`
query with crew resolution that cannot be shared across centres. What the single thread does instead
is *gate* it. One pass builds the BLUFOR positions, and a town with none of them inside its reach
cannot pass the helper, so it is never asked. The helper still decides every arrival, which is the
point of sharing it with the zone gate at all. This is not the `O(zones × all units)` shape
the streaming loop recorded as deliberately removed: the list is built once a tick and holds
BLUFOR only, so what each town is tested against is the friendly force, not every unit in the mission.

The garrison's raise cannot run in that thread — it confirms over five seconds, then waits on the
spawners and on OPFOR actually appearing, up to a minute — so it is dispatched to a worker per town
and adopted on a later cycle, exactly as `fnc_civ_handler` dispatches its fill. A town with a raise in
flight is skipped entirely until it reports, or the reinforcement test would read the still-empty
roster as owing the whole composition and raise it a second time.

It is not worth transferring to zones. There are at most 40 of them against 160 towns, and a zone
thread does more than poll — it owns the spawn, the turret crews and the stow, with blocking sections
throughout — so collapsing them buys a fraction of the saving for a much larger rewrite.

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
(`fnc_civ_reaction_weights`, `src/duws/server/civilian/fnc_civ_state_init.sqf:60-71`). With `t = rep / 20`
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
at the same local passed the same check, and the person answered both: two medikits or two intel drops.

An arrest is one of the exchanges a civilian only has one of, so it and a conversation block each
other. `fnc_civ_arrest` claims `DUWS_civ_arrested` before its own pause and tests `DUWS_civ_closed`;
`fnc_civ_request` tests both. Neither flag is ever cleared, so a detainee who is released stays spent.

### Range: two distances, on purpose

| Step | Reach | Source |
|---|---:|---|
| Call over | 6 m | `src/duws/shared/civ/fnc_civ_stopCommand.sqf:41` |
| Interaction menu | 3 m | `src/duws/shared/civ/fnc_civ_menuAction.sqf:44` |
| Every menu row, re-tested server-side | 3 m | `src/duws/server/civilian/fnc_civ_request.sqf:22` |
| Search (the player's own action, via `cursorObject`) | 3 m | `client/search/fnc_intel_search_action.sqf` |
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

`shared/includes/civ_menu.hpp` holds three dialogs: `civ_dialog` on idc block **8300-8399**, and the bribe
prompt and Raise Funds' `civ_give_dialog` on **8400-8499**, both clear of every idc the mission ships (the nearest neighbours are the
disguise panel's 8000-8203 and `fobmanager.hpp`'s lone 9745). Five framed rows — work, intel, aid,
toolkit, arrest — each `closeDialog 0` and `remoteExec` the work to the server. Work asks for a
civilian side mission and reaches its own server function, `fnc_civ_mission_request`; on the giver of a
live one it becomes Report, or Give Money for Raise Funds, with Cancel beside it
([`side_mission_catalogue.md`](side_mission_catalogue.md#civilian-side-missions)).

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
| `DUWS_civMission_state` | broadcast | `"active"` or `"ready"` while this civilian is the giver of a live civilian side mission. Opens Interact with no call-over, and turns the first row into Report |
| `DUWS_civMission_funds` | broadcast | `[raised, target]` while this civilian is the giver of a live Raise Funds mission. Turns the first row into Give Money |

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
whose claim is taken before its payout resolves (`server/search/fnc_search_claim.sqf`).

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

Per row (`fnc_civ_rowPrice`, `src/duws/server/civilian/fnc_civ_state_init.sqf:196-204`), and **not** scaled by
reputation — the curve already carries that signal by deciding whether money is asked for at all, so a
reputation term in the amount would count it twice.

| Row | Bribe |
|---|---:|
| Intel | 3 |
| Aid | 2 |
| Toolkit | 2 |
| Arrest | — |

**These are placeholders chosen to make the framework testable, not balanced figures.** They are
anchored on the black market, which is the price scale the player already reads — goggles at 1,
pistol and optic at 5 — so intel sits between the two. An unrecognised row returns a negative price,
and callers treat that as a reject: rows only ever come off the wire, so that is the fail-closed edge
for a client sending one the menu never offered.
