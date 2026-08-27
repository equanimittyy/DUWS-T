# Side missions: rework plan

Working SSOT for the side-mission rework: the catalogue of what each mission is and how it
actually plays, the reward pricing, and the open design ideas. Mission data itself lives in
`src/duws/shared/includes/mission_types.hpp` (one row per type, index-aligned with the launcher
block); this doc is the reasoning behind those numbers, not a second copy of them. The *how-to-add*
lives in [`docs/info/gameplay/side_mission_authoring.md`](../info/gameplay/side_mission_authoring.md).

The reward *pipeline* (how a base CP/AP payout is multiplied and credited) is not restated here --
see [`docs/info/gameplay/economy.md`](../info/gameplay/economy.md#faucets) and
[`docs/economy_second_pass.md`](economy_second_pass.md). In short: a thread's base CP/AP
(`mission_types.hpp`) is scaled by `cp_reward_multiplier` (campaign 1-5), a ×1.5 civs-off CP lift,
and the strategic map's depth boost (deep offers pay 1.5×-2×), then credited in
`src/duws/server/missions/fnc_mission_reward.sqf`. This rework only sets the **base** numbers.

## Status at a glance

17 types (indices 0-16). The rework's shape is settled: each mission should pose a **distinct
problem**, not the same reach-the-marker-and-kill with a bigger garrison (the design bar is in
[`side_mission_authoring.md`](../info/gameplay/side_mission_authoring.md#the-design-bar)).

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

**Complete, kept as a fixed-site destroy (no distinct-verb rework -- accepted as-is):** Destroy Ammo
Cache (9) and Destroy Radar (10). Both are repriced, and the cache's one-shot arsenal reward is
removed; they field the tier-gated vehicle ring (`fnc_missionPatrolswithintel`). They stay the
reach-the-site-and-destroy shape rather than posing a distinct problem, a deliberate exception to the
design bar, not pending work.

**Still stale -- each needs *both* a reprice and a distinct-verb gameplay rework** -- the earlier
"bespoke, review" row (Rescue Pilot) is stale too until reworked, not a reviewed baseline: Steal
Supply Truck (1), Rescue Pilot (4), Steal Builder Vehicle (6), Protect Informant (13), Recover
Humanitarian Supply Truck (14). Ideas per row in the [tracker](#per-mission-rework-tracker).

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
right column and stop it. Win: the HVT dies. Fail: his car reaches the zone, or the deadline. Off the
`fnc_mission_run` spine because the win is a race, not a one-shot predicate polled at a fixed spot;
owns its own site pick, spawn and monitor, like the informant and IDAP. Uses the convoy destination
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
opening is an ambush window. On the `fnc_mission_run` spine (one-shot win predicate). **Reward scales
with the tier fielded**: +10 CP / +5 AP per step above a car patrol, so car / IFV / armour pay
15/20, 25/25, 35/30. The briefing and map print the base (built before the tier rolls), so a heavier
patrol pays the step-up as an unadvertised completion bonus -- inherent to rolling the tier at spawn,
safe because one mission runs at a time.

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

Tunables (defaults, all in the thread): leave 2 steps friendly / 1 step enemy, +16 crowd, zone-reach
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
not retire the live zone. Teardown rides `fnc_mission_end`: prefab by compKey, gunners/teams/car by
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
after an emplacement they have not found; under non-hardcore fog every hardpoint spawns revealed, so
the flag only bites in hardcore mode. Standalone only (`zoneKey ""`): a zone-child emplacement is taken
by capturing its zone and pays no bounty. Wins when the target's `DUWS_hardpoints` row leaves the array
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

The gameplay verb is reworked and shipped; the reward is **not** repriced. 10/35 predates the rework,
when the mission was a single hold-action (effort 1) and the AP read as overpaid. The rework raised the
required fight to a multi-building garrison clear, so the old "trim the AP" rationale is dead -- the
number now wants a fresh read at the new effort, not the old cut.

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
| 2 | Eliminate High-Value Target | elimination | cmd | 40/35/0 | 3 | done |
| 11 | Deny Enemy Armor | elimination | cmd | 15/25/0 | 3 | done |
| 7 | Destroy Vehicle Patrol | elimination | cmd | 15/20/0 (+tier) | 2-4 | done |
| 15 | Informant Manhunt | elimination | cmd | 10/25/0 | 3 | done |
| 12 | Recon Enemy Position | recon | cmd | 10/5/0 | 2 | done |
| 5 | Hunt Sniper Team | elimination | cmd | 20/15/0 | 3 | done |
| 0 | Rescue Assault Team | rescue | cmd | 25/15/0 | 3 | done |
| 3 | Destroy Signal Tower | sabotage | cmd | 30/20/0 | 2 | done |
| 16 | Destroy Hardpoint | sabotage | cmd | 10/10/0 | 2-3 | done |
| 8 | Sabotage Laptop | sabotage | cmd | 30/20/0 | 3 | done |
| 9 | Destroy Ammo Cache | sabotage | cmd | 35/15/0 | 3 | done (fixed-site, repriced; arsenal reward removed) |
| 10 | Destroy Radar | sabotage | cmd | 20/25/0 | 3 | done (fixed-site, repriced) |
| 1 | Steal Supply Truck | requisition | cmd | 35/25/0 | 4 | stale |
| 6 | Steal Builder Vehicle | requisition | cmd | 15/20/0 | 4 | stale (twin of #1, half pay) |
| 4 | Rescue Pilot | rescue | cmd | 25/40/0 | 4 | stale |
| 13 | Protect Informant | defend | civ | 20/10/5 | -- | stale, not analysed |
| 14 | Recover Humanitarian Supply Truck | escort | civ | 20/10/5 | -- | stale, not analysed |

## Pricing rework (command missions)

Principle: base pay tracks required effort, holding the command economy near its aggregate. CP leans
to command/intel/tactical value, AP to materiel destroyed or manpower recovered. The reworked and
repriced missions (Eliminate High-Value Target, Deny Enemy Armor, Destroy Vehicle Patrol, Informant
Manhunt, Recon Enemy Position, Hunt Sniper Team, Rescue Assault Team, Destroy Signal Tower, Sabotage
Laptop) are now priced to effort; the vehicle patrol adds a tier bonus at spawn (see its design
note). Destroy Ammo Cache and Destroy Radar are repriced too, kept as fixed-site destroys. **Every
still-stale mission carries its old numbers and is open pricing work** -- all 5 stale rows, not only
the one below; it is just the worst effort/pay mismatch:

| Mission | Eff | CP/AP now | Note |
|---------|:-:|:-:|------|
| Steal Builder Vehicle | 4 | 15/20 | half its identical twin (steal supply, 35/25) -- match effort |

## Per-mission rework tracker

Status: `done` (shipped) or `stale` (needs rework). **Every `stale` row needs both a reprice and a
distinct-verb gameplay rework, even where the Gameplay change cell names only one.** The Gameplay
change cell is the current idea, not a locked spec.

| Mission | Gameplay change | Status |
|---------|-----------------|:-:|
| Eliminate High-Value Target | three-convoy race, spot the odd unarmed car | done |
| Deny Enemy Armor | repair-race convoy to a broken-down MBT | done |
| Destroy Vehicle Patrol | roving 3-vehicle column, speed-limited until broken, tier-scaled pay | done |
| Informant Manhunt | disguised manhunt in a town crowd | done |
| Recon Enemy Position | standoff binocular hold that reveals a zone | done |
| Rescue Assault Team | evac leg added (heli + on-foot exfil) | done |
| Destroy Signal Tower | target an existing OPFOR radio hardpoint; win when the hardpoint falls | done |
| Destroy Hardpoint | target an existing revealed OPFOR emplacement (any type but radio/minefield); win when the hardpoint falls | done |
| Sabotage Laptop | which-building hunt: laptop hidden in one of 3-5 garrisoned, marked buildings | done |
| Destroy Ammo Cache | kept as fixed-site destroy; repriced, one-shot arsenal reward removed | done |
| Destroy Radar | kept as fixed-site destroy; repriced | done |
| Steal Builder Vehicle | match effort/pay of its twin | stale |
| Steal Supply Truck | distinct verb TBD + reprice | stale |
| Rescue Pilot | distinct verb TBD + reprice | stale |
| Protect Informant | analyse + price (civilian) | stale |
| Recover Humanitarian Supply Truck | analyse + price (civilian) | stale |

## Open decisions

- The distinct verb for each still-stale row (all 5 need both a verb and a reprice; see the tracker).
- Final command prices for the still-stale rows (the pricing table above).
- Whether late-campaign armour creep on ring missions needs pay scaling, or the map depth boost
  already compensates.
- Civilian missions (protect_civ, transport_IDAP): analyse how they play, then price.
