# Side mission catalogue

The per-mission catalogue: what each side mission is, how it actually plays, and the reward pricing --
the *what* that [`side_mission_authoring.md`](side_mission_authoring.md) (the *how-to-add*) delegates to.
Mission data itself lives in `src/duws/shared/includes/mission_types.hpp` (one row per type,
index-aligned with the launcher block); this doc is the reasoning behind those numbers, not a second
copy of them.

The reward *pipeline* (how a base CP/AP payout is multiplied and credited) is not restated here --
see [`economy.md`](economy.md#faucets). In short: a thread's base CP/AP
(`mission_types.hpp`) is scaled by `cp_reward_multiplier` (campaign 1-5), a ×1.5 civs-off CP lift,
and the strategic map's depth boost (deep offers pay 1.5×-2×), then credited in
`src/duws/server/missions/fnc_mission_reward.sqf`. This catalogue only sets the **base** numbers.

## Status at a glance

22 types (indices 0-21). Each mission poses a **distinct problem**, not the same
reach-the-marker-and-kill with a bigger garrison (the design bar is in
[`side_mission_authoring.md`](side_mission_authoring.md#the-design-bar)).

**Hand-made / reworked (a distinct verb, bespoke scripting):**

| # | Mission | The verb that makes it different | Thread |
|--:|---------|----------------------------------|--------|
| 2 | Eliminate High-Value Target | spot which of three armed convoys carries the HVT, stop it before it reaches a zone | `target_hvt/` |
| 5 | Hunt Sniper Team | find two hidden elite marksmen on open ground (elevation+LOS perch search) | `target_sniper/` |
| 7 | Destroy Vehicle Patrol | break a roving 3-vehicle column that runs speed-limited until first blood | `target_armor/` |
| 15 | Informant Manhunt | find one disguised target in a live crowd before he flees by car | `informant/` |
| 12 | Recon Enemy Position | hold binocular eyes-on a zone from standoff without being drawn into a fight | `recon/` |
| 11 | Deny Enemy Armor | reach a broken-down MBT before its repair crew convoy does, or intercept the convoy | `deny_armor/` |
| 0 | Rescue Assault Team | break a cordon to free a captive squad, then cover its evac (heli or on-foot exfil) | `rescue_squad/` |
| 3 | Destroy Signal Tower | wreck an existing standalone OPFOR radio mast; win when its hardpoint row falls | `destroy_tower/` |
| 16 | Destroy Hardpoint | wreck an existing revealed OPFOR emplacement (any type but radio/minefield); win when its hardpoint row falls | `destroy_hardpoint/` |
| 8 | Sabotage Laptop | hunt which of 3-5 marked, garrisoned buildings hides the field laptop, then sabotage it | `sabotage_laptop/` |
| 17 | Eliminate Recon Patrol | hunt an OPFOR recon team hidden in a treeline; a third of the time a standalone AP minefield hardpoint (a streamed belt 500 m across and 100 m deep) sits at the ring edge opposite the patrol, unless the AP minefield cap is full | `target_recon/` |
| 18 | Destroy Patrol Camp | find 1-3 recon camps hidden in treeline by their campfire smoke, wipe out every camp team | `destroy_patrol_camp/` |
| 14 | Recover Humanitarian Supply Truck | seize an OPFOR-guarded aid truck and drive it to the IDAP crew waiting in a neutral/BLUFOR town | `transport_idap/` |
| 13 | Protect Informant | reach the informant, fortify from an R3F crate through a prep window, then hold scaling OPFOR waves until he survives | `protect_civ/` (testing) |
| 19 | Destroy Air Asset | down a tier-gated OPFOR gunship (attack heli / jet) that loiters over the ring, kept fuelled and periodically fixed by Allseer | `destroy_air/` (testing) |
| 20 | Escort Informant | recruit a friendly informant who holds at HQ, then walk or drive him alive to a neutral/BLUFOR town through whatever OPFOR sits on the route | `escort_informant/` (testing) |
| 21 | Deliver Supplies | drive an IDAP aid truck from HQ into a neutral/BLUFOR town and hand it to the waiting aid crew (transport_IDAP run forward) | `deliver_supplies/` (testing) |

**Complete, kept as a fixed-site destroy (no distinct-verb rework -- accepted as-is):** Destroy Ammo
Cache (9) and Destroy Radar (10). Both are repriced, and the cache's one-shot arsenal reward is
removed; they field the tier-gated vehicle ring (`fnc_missionPatrolswithintel`). They stay the
reach-the-site-and-destroy shape rather than posing a distinct problem, a deliberate exception to the
design bar, not pending work.

**Complete, kept as a steal-and-deliver pair (repriced):** Steal Supply Truck (1) and Steal Builder
Vehicle (6). Same verb -- steal a guarded vehicle and drive it back to home HQ -- differing only in the
prize (supply truck vs builder vehicle). Repriced to 20/20 and 20/30; no longer the half-pay twin.

**Built, in play-testing (not yet accepted as *done*):** Destroy Air Asset (19, new), Protect
Informant (13, reworked into defend-and-build), Rescue Pilot (4, escort-home shape kept and repriced),
and the two new civilian escorts Escort Informant (20) and Deliver Supplies (21). All are priced and
playable; they sit apart from *done* only until a play-test signs them off. Designs below.

**No mission is stale.** Every type is repriced and either done or in play-testing. Rescue Pilot is the
lone accepted exception to the distinct-verb bar -- kept as the escort-home shape (fight to the downed
pilot, carry him out, deliver him near HQ), not reworked into a new verb.

## Architecture: mission-owned site selection

Shipped. Placement is a two-phase survey in `fnc_mission_findSite`: phase 2 shortlists valid
locations (zones or towns per the row's `surveyKind`), phase 3 picks one weighted by the offer's
front/deep dial and realizes an exact position. A mission that needs specific ground defines
`fnc_<name>_site` and the survey calls it per realized candidate -- a **propose/accept** handshake:

```
[_candidatePos] call fnc_<name>_site
   -> []                       reject -- this spot does not fit me, picker draws another
   -> [_precisePos, _extra...] accept -- my objective sits at _precisePos
```

Only `select 0` reaches the thread (the picker flattens the result to a 2-D position), so a finder
hands back the one position the thread re-derives from, not a bundle. The finder runs client-side
inside the picker, so it reads **only broadcast state** and does **only terrain queries** (no
spawning, no server-only globals). A missing finder inherits `fnc_site_generic`, which accepts the
candidate as-is -- so a mission without one draws exactly as before. Finders live today for the
missions that demand terrain: informant (a live town near an enemy zone) and recon (LOS onto an
unrevealed zone). Both writeups below.

A finder gates the offer at *click* time. A criterion that can only fail *after* the pick (war state
moved in the gap -- the escape zone was captured, the destination fell) is handled by the thread
calling `fnc_mission_abort` with a stable snake_case `_reason` slug naming the failed criterion: the
grep key for why a type aborts, kept stable when the player-facing wording changes.

**Convoy destination contract.** The two road-convoy missions (Eliminate High-Value Target, Deny
Enemy Armor) also need an
OPFOR-held *destination* zone, not just an anchor. Their `mission_types.hpp` `spawnRule` sets
`needDestZone true` (with a `minCorridor` and `routeAvoidBlufor`), so `fnc_mission_findSite` picks and
vets a held zone at least `minCorridor` out, corridor clear of BLUFOR ground, and hands it to the
thread as a third `params` argument. The thread still re-checks the zone is OPFOR-held at start (it
can flip in the gap) and falls back to its own nearest-held search -- which also covers the
debug-force path, where no destination is handed.

## Hand-made mission designs

The convoy/patrol reworks, the manhunt/recon builds, and the two hardpoint-destruction missions. Read
the closest one before writing a new hand-made mission; each changes the *verb*, and the change lives in
the scripts around the objective, not in a bigger garrison.

### Eliminate High-Value Target

`mission_threads/target_hvt/fnc_target_hvt_mission.sqf`. A high-value target flees to an OPFOR-held
zone in one of **three** armed road convoys, each on its own approach via a divergent mid-route point
so the player cannot cover them all. Exactly one convoy carries the HVT in a single **unarmed** car --
the odd hull among the armed escorts, its type named to the player -- so the mission is to spot the
right column and stop it. Win: the HVT dies. Fail: his car reaches the zone, or the deadline. The win is a
race, not a one-shot predicate polled at a fixed spot; it owns its own site pick, spawn and monitor,
like the informant and IDAP. Uses the convoy destination
contract above.

### Deny Enemy Armor

`mission_threads/deny_armor/fnc_deny_armor_mission.sqf`. A broken-down enemy MBT sits abandoned in
the field; its crew is inbound by road convoy to get it running -- three crew (one an engineer) on
unarmed transport, an escort scaled to what OPFOR can field (car / IFV / tank), a rifle team for
security. The player ambushes the crew at the tank or intercepts the convoy on the road. Win: the tank
denied -- every crewman dead, or the tank destroyed (blowing the derelict early counts). Fail: the
crew reach it, repair it to operational, and drive it home, or the deadline. **Repair time scales
inversely with distance to the nearest OPFOR zone** (long window near their lines, short far out): a
repaired tank near its own lines is the harder denial, so the player gets longer to break the repair
there. The tank is never claimed on a win -- a claim is a deletion order, and this one may end up the
player's ride home. Off the spine for the scripted repair-race fail.

### Destroy Vehicle Patrol

`mission_threads/target_armor/fnc_target_armor_mission.sqf`. A roving column of **three vehicles of
one class**, the class rolled once and gated by OPFOR's earned AP tier (car floor, tank top), patrols
a road loop as one column. Win: every crewman across the three dead. The column holds LIMITED speed
until first hit or a man down, then drops the limit and fights -- "speed-limited until broken", so the
opening is an ambush window. A one-shot win predicate polled at the objective. **Offered only
where OPFOR has earned the Motorised tier** (`fnc_target_armor_site`): a side with no vehicles has no
patrol to break, so below tier 2 the offer is dropped rather than sited on a fallback truck column.
**Reward scales with the tier fielded**: +10 CP per step above a car patrol, AP flat, so car / IFV /
armour pay 15/20, 25/20, 35/20. The briefing and map print the base (built before the tier rolls), so a
heavier patrol pays the step-up as an unadvertised completion bonus -- inherent to rolling the tier at
spawn, safe because one mission runs at a time.

### Informant Manhunt

The informant mission is a manhunt, not a building sweep. An OPFOR informant hides disguised among a
town's civilians; the player finds and kills him before he leaves by car for a distant zone. Thread:
`mission_threads/informant/fnc_informant_mission.sqf`.

**Siting.** `fnc_informant_site` accepts a picker candidate only where a live Tomata civil town sits
within 2.5 km *and* an OPFOR-held zone sits at least 1 km off (the informant's escape), returning that
town's centre; civilians off / RAVAGE / WBK, or a town with no enemy zone to flee to, reject -- so the
offer is dropped rather than sited where it cannot play out. The finder reads only broadcast state
(`duws_town_circles`, `CIV_PRESENCE`, `WARCOM_zones_controled_by_OPFOR`), never the server-only
`civ_town_rep`.

**The informant.** A civilian-model unit in an EAST group (side follows the group), `setCaptive true`
so BLUFOR AI ignores him while he blends. Killing him wins; a kill within townRadius + 300 m of the
nearest town costs -1 reputation (`fnc_town_rep_adjust`), so a clean kill is on the road, not in the
crowd.

**Two branches, on the town's reputation band** (`fnc_civ_repAt`; enemy = OPFOR band or a standing
garrison via `fnc_town_garrison_tierAt`):
- friendly / neutral -- the crowd is thickened, and every added local carries an "Ask about informant"
  action (`fnc_intel_ask_*`) that rolls the shared civilian reaction curve (`fnc_civ_reaction_weights`)
  and, on success, hints his bearing + distance (16-point compass, nearest 5 m) from the asker. A
  bribe result reuses the civilian bribe popup, routed back through `fnc_civ_serve`'s INFORMANT case.
- enemy -- no asking; the informant leaves much sooner, so the player camps the described vehicle.

**The escape.** He leaves at a fixed world-clock time (shown in the briefing) or the moment shots are
fired near him, walks to his car and drives to the nearest OPFOR-held zone >=1 km off -- enemy ground,
never a BLUFOR zone or the player's FOB; reaching it fails the mission. If the last enemy zone in reach
is captured between the offer and the spawn, the thread aborts (nowhere left to run). Three decoy cars
-- one guaranteed his class, so the vehicle description never pins a single car -- scatter on random
bearings when he boards. Car destroyed before he boards, and he arms a pistol and flees on foot. His
leave time is rolled in 10-minute steps of in-game time via `fnc_time_deadline` and shown as a world
clock via `fnc_time_clock`.

Tunables (defaults, all in the thread): leave 4 steps friendly / 2 steps enemy (5-min steps, so 20 /
10 min), +16 crowd, zone-reach
60 m, rep-penalty radius +300 m, pistol `hgun_Rook40_F`, shots trigger = `FiredNear`, ask/bribe price
3.

### Recon Enemy Position

A standoff scout, not a fight. The player infils to a mission-chosen overwatch position, raises
binoculars, and holds eyes-on an unrevealed OPFOR zone long enough to scout it; success lifts that
zone's fog of war on the strategic map. Thread:
`mission_threads/recon/fnc_recon_observe_mission.sqf`.

**Siting.** `fnc_recon_observe_site` snaps a picker candidate to the nearest unrevealed OPFOR-held
zone within 2.5 km, confirms at least one 600-800 m bearing has clear terrain LOS onto it *and* stands
clear of every other enemy zone and hardpoint, then returns the **target zone** -- not the overwatch.
`fnc_mission_findSite` keeps only `select 0`, so the thread cannot be handed both; re-deriving the
target from an overwatch position is ambiguous where zones sit close, so handing back the target makes
the thread's re-derivation exact. The thread then computes the overwatch (fuller terrain+object LOS,
friendly-facing arc, height-favoured, clear of other enemy zones and hardpoints) for the launched
mission. A revealed zone is no target -- the reveal is the payoff -- so with none unrevealed in reach
the offer is dropped.

**Custom streaming, this mission only.** At an 800 m standoff the real garrison is streamed out by the
global site poller, and waking it there would hand the player a live garrison that wanders off the
scouted spot. Instead the thread runs its own streamer: on approach it builds the target zone's OWN
prefab (real structures and crewed statics, via the zone's builder fn resolved from
`DUWS_zoneKind_<key>`), plus two representative infantry teams (`YELLOW`, so they hold rather than
chase an 800 m spotter) and a car, all on `closepatrol`. The prefab is built a step off the zone
centre so its `zone_<x>_<y>` key stays distinct from the real zone's -- releasing the recon copy must
not retire the live zone. Teardown rides `fnc_mission_finish`: prefab by compKey, gunners/teams/car by
the claimed-token sweep plus a proximity pass for the builder-orphaned gunners.

**Observing.** The player-facing half (`client/missions/fnc_recon_observe_layer.sqf`, JIP-keyed to all
clients) draws a 3D "look here" icon over the target and runs the hold: continuous binocular LOS
(`cameraView == "GUNNER"` and the binocular is `currentWeapon`) from within the overwatch area, any
break resetting it, re-checked client-side per tick. On a completed hold the client reports once to
`fnc_recon_observe_success`, which raises the flag the thread's monitor wins on -- a second player or a
stale JIP report cannot double-pay. Soft stealth: the element can see and fire, but the mission never
auto-fails on detection.

**Payoff.** `fnc_zone_reveal` lifts the scouted zone onto the strategic map. The scout also reveals
`rand(0-2)` of the nearest unrevealed positions (the target's own hardpoints, standalone hardpoints,
unrevealed enemy zones, ranked by distance), then the standard CP/AP. The hardpoint parent gate is
respected: a hardpoint under a still-hidden zone is not offered as bonus intel.

Tunables (defaults, all in the thread): overwatch band 600-800 m, LOS range 900 m, observe area 75 m,
hold 12 s, approach ring 200 m, 2 teams + a car, prefab offset 25 m, gunner-claim radius 60 m, up to 2
bonus reveals. Targets zones only for now -- hardpoint targeting as the primary objective is a later
add.

### Destroy Signal Tower

`mission_threads/destroy_tower/`. No stand-in: the mission points at an existing standalone OPFOR RADIO
hardpoint (a `Land_TTowerBig_2_F` mast) picked from `DUWS_hardpoints` nearest the anchor, intel state
ignored, and wins when that hardpoint falls -- its row leaving the array, watched directly, not the tower
object dying (the mission never handles the streamer-owned mast). The streamer removes the row and pays
the bounty when the hardpoint clears. `fnc_destroy_tower_site` gates the offer on a live mast within 2500 m, so once every
tower is down the mission stops being offered. The player collects the 30/20 mission reward on top of the
hardpoint's own [10 CP, 10 AP] destruction bounty and its AoI-coverage drop, all paid by the streamer.
Spawns nothing -- the mast's own inline crew is the whole opposition. Off the spine (the win watches
broadcast state, not a one-shot predicate).

### Destroy Hardpoint

`mission_threads/destroy_hardpoint/`. The Destroy Signal Tower shape generalized to the rest of the
emplacements: the mission points at an existing standalone OPFOR hardpoint of any destructible type
*except* RADIO (its own tower mission) and MINEFIELD (a hazard, not an emplacement) -- so MG, AT, AA,
GMG, roadblock, OP, mortar and artillery are all fair game. Intel *is* required, unlike the tower:
`fnc_destroy_hardpoint_site` accepts only a **revealed** row (index 5), so the player is never sent
after an emplacement they have not found; outside hardcore only generation's hardpoints spawn revealed,
so the flag bites under hardcore and on hardpoints OPFOR built in play. Standalone only (`zoneKey ""`): a zone-child emplacement is taken
by capturing its zone. Wins when the target's `DUWS_hardpoints` row leaves the array
-- the streamer's own per-type clearance test (garrison beaten, guns wrecked) decides "destroyed", so
the mission watches liveness, not any one object. Pays 10/10 on top of the hardpoint's own destruction
bounty (type-scaled: [5,0] for most, [10,5]/[10,0] for artillery/mortar), all credited by the streamer.
Spawns nothing. Off the spine.

### Sabotage Laptop

`mission_threads/sabotage_laptop/`. A which-building hunt, not a walk to one marker. An enemy field
laptop hides in **one** of 3-5 enterable buildings the mission marks with orange crosses; the player is
not told which, so the objective is to clear and search them. `fnc_sabotage_laptop_site` gates the
offer on a cluster of at least three enterable buildings within 350 m -- a hamlet or town block, not a
lone farmhouse -- so a countryside cluster is valid but open ground is not (map survey, no town-tether;
the finder inlines `fnc_usableBuildings`' terrain test so it can run client-side in the picker). Every
candidate building holds a garrisoned `team`, and the cluster is ringed by a mixed patrol (a car, an
IFV where the faction fields one, foot teams). The laptop sits on a spawned desk on a random interior
slot of its building; a `Sabotage` action on it wins, and in hardcore it also carries a body-style
search. Win: the laptop sabotaged. Fail: the deadline. Off the spine (the win comes through the
laptop's own action, watched on a deadline watcher, not a one-shot predicate).

The gameplay verb was reworked first and the reward left at its pre-rework 30/15; the AP is now lifted
to **30/20** to price the mission at the fight it actually demands -- a multi-building garrison clear,
not the single hold-action it once was.

### Recover Humanitarian Supply Truck

`mission_threads/transport_idap/fnc_transport_IDAP_mission.sqf`. An escort in reverse: OPFOR has hijacked
an IDAP aid truck and parked it under guard, and the player fights in, seizes it and drives it back to the
IDAP crew. The truck and its guard force are the stolen-supply shape (`fnc_steal_supply_mission`) -- an
idle team on the prize, close and wide foot patrols, and the tier-gated `DUWS_fnc_tokenClass` car/IFV
patrols -- so the recovery leg reads like a theft the player is undoing. Win: the truck delivered within
50 m of the crew. Fail: the truck destroyed (`> 0.95` damage), or the deadline. The win is a
delivered-vehicle predicate the thread polls itself, like the stolen-supply thread.

**Siting.** `surveyKind "map"`, so the truck spawns on contested ground rather than in a town, and
`fnc_transport_IDAP_site` gates the offer on a neutral/BLUFOR town sitting within 3 km of the sited truck
-- the crew's haven and delivery point. With no such town (civilians off leaves `duws_town_circles`
empty; every town in reach is in the OPFOR band) the offer is dropped. The finder reads only broadcast
state (`duws_town_circles`, `DUWS_enemy_town_pos`). The thread re-derives the nearest non-enemy town from
the same state and aborts (`no_delivery_town`) if the war state flipped the last one hostile in the gap.

**The crew and hand-over.** Three IDAP aid workers stand idle at a safe spot in the delivery town under a
green "IDAP" map marker, one of them marshalling the truck in with a held wave pose. The crew is raised by
the shared `fnc_spawn_aid_crew` (`server/missions/`), which both IDAP-delivery missions call -- it returns
`[group, marshaller, crewPos]`, pins the delivery marker and drop distance on `crewPos`, and holds the
marshaller's gesture against the engine cancelling it until the hand-over clears `DUWS_holdAnim`. Delivery
lifts the town's reputation by +3
(`fnc_town_rep_adjust`, keyed by the town's own index, not `fnc_civ_townAt` on the truck's contested-
ground spawn); losing the truck sours it by -3. `fnc_town_rep_adjust` self-guards an out-of-range index,
so RAVAGE/WBK (towns but no reputation array) take the call harmlessly. The hpp REP column reads 3 to
match the win.

**Dialogue.** IDAP opens with a distress call (VOICE), Overlord copies and tasks the player (NET), the
player's team acknowledges (VOICE); IDAP thanks the player on delivery (VOICE). A destroyed truck is
Overlord's loss to report on NET (`STR_DUWS_T_idaptruckdown`), a deadline the shared
`fnc_mission_timeout_notice` (Overlord, NET). The deadline band is set to 0h30-1h00, matching the
steal-and-drive pair (Steal Supply Truck, Steal Builder Vehicle) whose shape it shares. CP/AP are held
at 25/10: it shares the steal pair's fight but pays less AP because the +3 REP carries part of its
value.

### Protect Informant

`mission_threads/protect_civ/`. Reworked from a passive in-place defend into **defend-and-build**: the
player reaches the informant, fortifies the building from a limited R3F supply crate through a fixed
prep window (skippable via a confirmed action), then holds scaling OPFOR waves long enough for him to
survive. Waves fill toward a budget that tracks BLUFOR headcount, on a deep dip or a 5-minute
heartbeat -- infantry trucked to a debus short of the ring, up to rand(2-4) combat vehicles driving in
from the far side. Leaving the ring empty of BLUFOR for 20 continuous seconds abandons him, counting
as a kill. Prep starts on first player arrival (the deadline is only the never-engaged backstop). Win:
informant alive when the defend window elapses, plus +3 REP to the nearest town. In play-testing; the
thread (`fnc_protect_civ.sqf`) carries the tunables, and the AIS opt-out it needs is in
[`revive_system.md`](../architecture/revive_system.md#ais-traps).

The crate names its composition key in `DUWS_buildKey`, and `DUWS_fnc_buildRegister` files each build from the
crate under the mission key, wherever the player carries it. The teardown releases that key, so every build goes
with the mission, and a build that another factory made near the crate stays. A build that R3F reports after the
release goes to the sweep, because filing it would revive the retired key. A sale at the crate refunds 100% of
the cost, less the object's damage.

### Destroy Air Asset

`mission_threads/destroy_air/`. A moving-target intercept: a lone OPFOR gunship loiters over a 5 km ring
and the player has to bring it down. Which airframe spawns is whatever the side can field -- a jet once
it has reached the Air tier (AP 600), else the attack helicopter earned at Armor (AP 350).
`fnc_destroy_air_site` gates the offer on the Armor tier *and* the AttackHeli campaign toggle, so a
below-tier or air-disabled OPFOR never sees it and the slot draws another type. Win: the aircraft dead.
Fail: the deadline. `surveyKind "map"`; the win polls `alive` on the hull, so it stays off the one-shot
spine. **Reward scales with the airframe**, the way the vehicle patrol scales with its tier: base 25/25,
+10 CP when the side fields the jet over the attack helicopter (AP flat), an unadvertised completion
bonus since the briefing prints the base built before the airframe rolls.

Two engine traps shape the thread. The global ten-minute resupply (`fnc_AI_Master_Control`) only reaches
assets near a player, so a gunship loitering far out runs its tank dry and falls out of the sky before
the player finds it -- the thread refuels and rearms it on its own 300 s clock, unconditional on
proximity. And a fast mover is unfindable from a static marker, so Allseer drops a fix on the airframe
and re-lays it every ~150-210 s (`o_air`, `ColorEAST`), calling it in on the same cadence: a periodic
fix the player races to, not a frame-by-frame blip.

### Escort Informant

`mission_threads/escort_informant/`. The manhunt run backwards: instead of hunting a hidden OPFOR
informant, the player collects a *friendly* one and gets him home. A WEST unit in civilian dress spawns
idle at BLUFOR HQ (`setCaptive false`, `allowDamage true`), so OPFOR treats him as a target and the
escort to the surveyed town is contested. A group leader recruits him with a "Join Group" action (a
"Leave Group" undoes it); the leader gate is in the action body, not its condition, so a non-leader still
sees the action and is told why it did nothing. Join/Leave route through `fnc_escort_informant_group`,
which toggles only `MOVE` (follow when in the group, hold-where-dropped when out) and never touches
`PATH`, keeping his pathing usable. Win: informant alive within 50 m of the town. Fail: informant dead,
or the deadline. The win polls `alive`/`distance2D` itself, so it stays off the one-shot spine.

**Siting and the delivery town.** `surveyKind "town"` with **no** site finder -- it inherits
`fnc_site_generic` and re-derives the target town in-thread: the nearest circle in `duws_town_circles`
that is *not* in `DUWS_enemy_town_pos`, its index (aligned with `civ_locations`) driving the rep call. If
the war state left no non-enemy town in reach, the thread aborts `no_delivery_town`. The informant spawns
on a `BIS_fnc_findSafePos` near HQ.

**Send-off and teardown.** He rides a manhunt-style map marker (`mil_warning`, refreshed every 5 s on a
drone-ping cadence, not per frame) and reuses `protect_civ`'s `DUWS_float_informant` global and client
drawer -- safe because one side mission runs at a time. On a win he is released from the player's group,
set captive so nobody guns down a now-harmless civilian, and walks the Tomata civil stroll into town
(`fnc_civ_wp_Tomata`); on a live timeout he makes his own way there on foot; dead, the corpse rides the
dead-owned census. The +1 REP is paid on a win, -1 on any fail. Spawns no opposition of its own -- the
fight is whatever OPFOR already sits between HQ and the town. See the [engine
gotchas](../architecture/arma_engine_gotchas.md) for the localise-a-finished-sentence trap the win
line hit: the close line names the town, so it is spoken at the call site and `fnc_mission_finish` is
handed `[]`, never a pre-formatted sentence to re-localise.

### Deliver Supplies

`mission_threads/deliver_supplies/`. `transport_IDAP` run forward: the aid truck starts safe at BLUFOR HQ
rather than under OPFOR guard in the field, and the player drives it into the surveyed town where the IDAP
crew waits. A `C_Truck_02_transport_F` spawns near HQ with two IDAP food-sack cargo props attached to the
bed (MODERN version only); an HQ `loc_Truck` marker rides the hull until a BLUFOR crew boards, then clears.
The receiving crew is the shared `fnc_spawn_aid_crew` (same helper as `transport_IDAP`). Win: the truck
within 50 m of the crew's resolved spot (`crewPos`, not the town centre -- else it ticks up to 40 m short
of the drop). Fail: truck destroyed (`> 0.95` damage), crew all dead, or the deadline. The win is a
delivered-vehicle predicate the thread polls itself.

**Siting** mirrors Escort Informant: `surveyKind "town"`, no finder, the same non-enemy-town re-derivation
and `no_delivery_town` abort. **Hand-over** mirrors `transport_IDAP`'s theatre: the marshaller drops its
guide-in pose, IDAP thanks the player in the room (VOICE, naming the town), Overlord signs off over the
net, then the sacks come off the bed and the emptied truck pulls away before teardown. +3 REP on delivery,
-3 on each fail branch. Spawns no opposition -- like Escort Informant, the difficulty is the war state on
the HQ-to-town route.

### Rescue Pilot

`mission_threads/rescue_pilot/`. The escort-home shape kept, not reworked into a distinct verb -- the
accepted exception to the design bar. The player fights in to the crash site, extracts the downed pilot
(the carry system lives in the shared `fnc_pilot_carry`, compiled into the thread), and delivers him
near BLUFOR HQ, typically under pursuit. Win: the pilot alive within **50 m** of HQ (`_pilot distance
PosOfBLUHQ`); a pilot left out of radius past the bleed-out fails. Fail: pilot killed, or the deadline
(3 h fixed). Repriced to 25/25. Open polish, not blocking: widening the delivery radius to 100 m was
floated but is not in the thread, which still delivers at 50 m.

## Mission catalogue (current)

CP/AP are the base payout from `mission_types.hpp` (before any campaign/depth multiplier). Effort is a
1-5 read of the *required* fight. Shared force for the generic threads: garrison ~24
(`fnc_garrisonBuildings`) and/or a patrol ring (`fnc_missionPatrols` 16 inf,
`fnc_missionPatrolswithintel` 12 inf). The intel ring adds up to three vehicle patrols on tier-gated
slots -- car (AP 60), then car/ifv (150), then ifv/tank (350) -- thickening from one car to three
vehicles as OPFOR earns Army Power while its pay stays fixed. The plain ring still fields the older
1 MBT + 2 armed car set.

| # | Mission | Obj | Cat | CP/AP/REP | Eff | State |
|--:|---------|-----|-----|:---------:|:--:|-------|
| 2 | Eliminate High-Value Target | elimination | cmd | 40/30/0 | 3 | done |
| 11 | Deny Enemy Armor | elimination | cmd | 20/20/0 | 3 | done |
| 7 | Destroy Vehicle Patrol | elimination | cmd | 15/20/0 (+tier) | 2-4 | done |
| 15 | Informant Manhunt | elimination | cmd | 10/25/0 | 3 | done |
| 12 | Recon Enemy Position | recon | cmd | 10/5/0 | 2 | done |
| 5 | Hunt Sniper Team | elimination | cmd | 15/15/0 | 3 | done |
| 0 | Rescue Assault Team | rescue | cmd | 25/15/0 | 3 | done |
| 3 | Destroy Signal Tower | sabotage | cmd | 30/20/0 | 2 | done |
| 16 | Destroy Hardpoint | sabotage | cmd | 10/10/0 | 2-3 | done |
| 17 | Eliminate Recon Patrol | elimination | cmd | 10/10/0 | 3 | done |
| 18 | Destroy Patrol Camp | elimination | cmd | 20/15/0 | 3 | done |
| 19 | Destroy Air Asset | elimination | cmd | 25/25/0 (+tier) | 3 | testing |
| 8 | Sabotage Laptop | sabotage | cmd | 30/20/0 | 3 | done |
| 9 | Destroy Ammo Cache | sabotage | cmd | 25/15/0 | 3 | done (fixed-site, repriced; arsenal reward removed) |
| 10 | Destroy Radar | sabotage | cmd | 15/25/0 | 3 | done (fixed-site, repriced) |
| 1 | Steal Supply Truck | requisition | cmd | 20/20/0 | 4 | done |
| 6 | Steal Builder Vehicle | requisition | cmd | 20/30/0 | 4 | done |
| 4 | Rescue Pilot | rescue | cmd | 25/25/0 | 4 | testing (escort-home shape kept, repriced) |
| 13 | Protect Informant | defend | civ | 30/30/3 | 4 | testing (defend-and-build; see rework doc) |
| 14 | Recover Humanitarian Supply Truck | escort | civ | 25/10/3 | 4 | done |
| 20 | Escort Informant | escort | civ | 5/15/1 | 2 | testing (spawns no opposition; route fight is the war state) |
| 21 | Deliver Supplies | escort | civ | 15/5/3 | 2 | testing (spawns no opposition; route fight is the war state) |

## Pricing rework (command missions)

Principle: base pay tracks required effort, holding the command economy near its aggregate. CP leans
to command/intel/tactical value, AP to materiel destroyed or manpower recovered. The reworked and
repriced missions (Eliminate High-Value Target, Deny Enemy Armor, Destroy Vehicle Patrol, Informant
Manhunt, Recon Enemy Position, Hunt Sniper Team, Rescue Assault Team, Destroy Signal Tower, Sabotage
Laptop) are now priced to effort; the vehicle patrol adds a tier bonus at spawn (see its design
note). Destroy Ammo Cache and Destroy Radar are repriced too, kept as fixed-site destroys. Every type
is now priced -- none carries its old numbers. Recover
Humanitarian Supply Truck is fully priced: 25/10, deadline matching the steal-and-drive pair. The five
in play-testing are priced but not yet signed off: Rescue Pilot at 25/25 (3 h fixed), Protect Informant
at 30/30/3 (3 h fixed), Destroy Air Asset at 25/25 (0h30-1h00) with +10 CP when the side fields a jet
over the attack helicopter, and
the two new civilian escorts -- Escort Informant at 5/15/1 (1h00-1h30) and Deliver Supplies at 15/5/3
(0h30-1h00). Both escorts spawn no opposition of their own, so their pay leans low and the REP carries
part of the value, as with Recover Humanitarian Supply Truck.

## Civilian side missions

A civilian side mission is a job that a local gives the player through the civilian menu, not through the
strategic map. It is not a row in `mission_types.hpp`, and it runs beside the HQ mission, never in its
slot. The code is in `src/duws/server/civ_missions/`.

| | HQ side mission | Civilian side mission |
|---|---|---|
| Issued by | the strategic map | the **Work** row, first in the civilian menu |
| At one time | one (`Mission_available`) | up to three (`CIV_MISSION_CAP`) |
| Name | a generated operation name | the giver's town, then the type's name (*Kavala: Clear Bandit Camp*); no title card and no music |
| Deadline | a band per type | none |
| Ends | on the objective | when a player reports to the giver, or cancels; Raise Funds ends on the gift that meets its target |
| Pays | CP and AP | CP, money and town reputation |

| Type | Bandits | Won when | Lost when | CP | Money | REP |
|---|---|---|---|---:|---:|---:|
| Clear Bandit Camp | 6-9, plus 0-2 pairs | every camp bandit is dead | the giver dies | 10 | 3-5 | +3 |
| Recover Stolen Car | 4-6, plus 0-2 pairs | the car stands within 30 m of the giver | the giver dies, or the car is destroyed | 5 | 5-8 | +3 |
| Raise Funds | none | the players give the giver 9-15 money between them | the giver dies | 15 | none | +5 |
| Clear Minefield | 0-10, once the first mine goes | no mine in the field is still armed | the giver dies | 10 | 3-5 | +3 |

The main group walks `closepatrol` round the site at a 100 m radius, as an HQ mission's objective guard
does. The pairs are two riflemen each (`fnc_bandit_pairs`) on `widepatrol` at a 250 m radius, inside the
site's 300 m clearance from every zone. A pair does not count toward the camp's objective.

The CP is scaled by `cp_reward_multiplier`. The money goes into the inventory of the player who reported
the job, and at their feet if it does not fit (`fnc_loot_grant`) — for Raise Funds that is whoever's gift
met the target. A reporter who has left the session is paid at the giver's feet instead. The reputation goes to the giver's town (`fnc_town_rep_adjust`). A cancel ends the mission with no pay
and no other cost, except that money given to Raise Funds is not refunded.

**The offer is a flat 75 %, not the reaction curve** (`fnc_civ_mission_request.sqf`). A hostile town is
where the player most needs the reputation that a mission pays, and the curve offers nothing at -20. A
full cap is a refusal, and like every refusal it spends the civilian.

**An offer waits on the bribe prompt.** The request files the offer in `DUWS_civ_pending` as the row
`"WORK"` and raises `civ_bribe_dialog` with the brief and the reward, as the giver speaks the brief.
`fnc_civ_bribe_answer` proves the answer is the asker's, as for a bribe, and hands it to
`fnc_civ_mission_accept`: Accept starts the mission, and Decline or Escape frees the slot and spends the
civilian. The slot is held while the prompt is open, so an unanswered prompt is declined after 120 s, or
a lost client would hold it for the session.

**Raise Funds is paid for at the giver** (`fnc_civ_mission_funds.sqf`). The target is rolled with the
offer, so the brief names it. Its site is the town centre, and the task pins it with no search area. On the
giver, the first row reads Give Money and opens `civ_give_dialog`, a slider capped at the money that the
player carries and the money that the giver still needs. `fnc_civ_mission_give` runs by `remoteExecCall`,
so it is unscheduled, and two players who give at the same time cannot both pay the same shortfall. Any
player can give, and the gift that meets the target is the report.

**Clear Minefield lays a real OPFOR field** (`fnc_civ_mission_mines.sqf`). The field is 1-2 by 1-2 squares of
50 m, AP or AT at random, laid by `fnc_hardpoint_minefield`. Only 15-22 % of the mines are kept, and at least
one. The field is registered as a standalone `MINEFIELD` hardpoint and revealed at once, so every mine shows on
the map and the hardpoint poller removes the row when the last mine is gone
([`hardpoints.md`](hardpoints.md)). The objective reads the same mines. The field belongs to OPFOR, not to the
giver, so a cancel or the giver's death leaves it on the map. An AT mine does not fire under a man on foot, so
the AT roll is the easier job.

**The first mine to go brings a fight.** When the first mine is disarmed or set off, OPFOR raises 0-1 `team` and
0-2 `patrol` groups (`fnc_spawn_team`), and the bandits roll their own 0-1 and 0-4 of the same rosters in bandit
roles (`fnc_bandit_spawn`). Each side spawns on its own flank, 45° either side of the bearing that points away
from the players within 600 m of the field, or from the town when none is near. OPFOR spawns 200 m beyond the
outermost kept mine and the bandits 300 m, so the bandits are never nearer the field than OPFOR. Each spot is
the one within 40° of its flank that the fewest of those players can see, and each group scatters up to 15 m
from it. Both sides `hunt` the field, so they meet there and fight each other and the players. Neither side
counts toward the objective. The mines are revealed to OPFOR alone, so the bandits walk the field blind.

**The giver goes indoors and stays** (`fnc_civ_mission_accept.sqf`). On the accept, the giver walks to a
ground-floor position in the nearest enterable building within 150 m, off the street where traffic could
run them over, and `PATH` goes off when they arrive. The accept also takes the giver off the town's crowd
roster, so a town that sleeps leaves them standing. A blue `mil_warning` marker, the escort informant's,
follows the giver on the thread's 5 s poll, because the task pin does not follow them. The panic sweep
skips the giver (`fnc_civ_panic.sqf`). While the mission lives, Interact opens the menu on the giver with no
call-over: the first row reads Report, live once the job is done, and Cancel sits beside it. When the
mission ends, the giver walks again and the map sweep collects them once no player is near.

**The thread owns every exit.** A report or a cancel only writes the entry's state, and the thread ends
the mission on its next poll (`fnc_civ_mission_poll.sqf`) through `fnc_civ_mission_finish.sqf`.
Readiness is a separate flag, so a poll never overwrites a report. The objective test is code stored on
the entry and reads the entry it is given, because the request re-runs it at the report and an SQF block
captures no locals.

**A job's men are owned by their group handles, not by the HQ token.** `fnc_mission_claim` defaults to the
running HQ mission's token, which cannot advance while the HQ slot is held. A civilian mission that
advanced it would re-stamp the HQ mission's later claims. The finish writes the same `DUWS_binMe` flag
that `fnc_mission_cleanup` writes. The camp props and the stolen car are kept under the
key `civ_mission_<id>`: an empty car is litter to the map sweep, and a mission with no deadline can
outlast the litter lifetime.

**The site keeps the fight for the player** (`fnc_civ_mission_site.sqf`). It is 300-1200 m beyond the
town's edge, outside every zone's radius + 300 m, outside `AOI_HQ_REACH` of the HQ, and 500 m from any
other live site. A Clear Minefield site is also 100 m or more from any road, so that traffic cannot reach a mine
in the largest field. Bandits fight both armies, and the objective counts every camp bandit dead, whoever killed
them. A town close to HQ often finds no site, so there only a Raise Funds draw becomes a job.

A live civilian mission is not saved. The registry, `DUWS_civMissions`, holds unit handles. The Debug
menu's *Force civilian mission* row makes the civilian under the cursor offer a job, with no roll and no
cap.
