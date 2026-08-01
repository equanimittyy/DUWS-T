# OPFOR commander: design notes

An OPFOR-side director that makes low-reputation towns fight back. Where the player has turned
a town against them, the enemy uses it: IEDs on the approach roads, ambushes on patrols passing
through, sabotage against nearby FOBs and parked vehicles. Reputation stops being a modifier on
civilian spawn behaviour and becomes the input to an actor that plans against the player.

This document exists because the per-town reputation change deleted the two mechanics that did
this job badly. They are recorded here in full, because they are the raw material for the
low-reputation events this feature will generate.

## Why the old mechanics were removed rather than kept

Both spawned `resistance`-sided fighters out of the civilian population, and that side is
hostile to west (`server/server_init.sqf:28-32`). Three problems, none fixable in place:

- **They could make a zone uncapturable.** A zone is captured on a `WEST SEIZED` trigger
  (`server/init_zones/fnc_createzone.sqf:277`). Civilian towns sit on enemy zones by design, so
  hostile civilians standing in one hold it against the player indefinitely.
- **They fired off the global reputation**, so misbehaviour anywhere armed civilians
  everywhere. Per-town reputation fixes the input; it does not fix the fact that the response
  is generated inside the town's own spawn routine, which only runs when a player walks in.
- **A spawn routine cannot plan.** Sabotage, ambush siting and IED placement are decisions
  about where the player *will be*, and the civilian handler only knows where they already are.

The behaviours themselves were sound. They are worth rebuilding under a director that owns
them.

## Preserved: hostile civilian conversion

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

## Preserved: suicide bombers

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

## Rejected: the OPFOR spawners this replaces

WARCOM ran three OPFOR threads of its own — roaming patrols, attack waves and random air — and all
three are gone. They are recorded for the opposite reason to the two mechanics above: the director
will be asked to produce enemy pressure, and this is the shape it must not take.

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

## What the director needs

The director's own decision machinery — belief, scoring and commitment — is
[`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md). What follows is what the town-event
half of it requires on top.

Decided so far:

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
  Whether the regroup hold should silence events along with the garrison is open — a town that keeps
  mining roads while it visibly has nobody in it is either a good scare or an obvious tell.

Open, and to be settled before implementation:

- The roll itself: what rate a town at `-10` generates events at against one at `-20`, and whether
  the curve between them is worth having or the band alone should decide.
- Whether IED placement is persistent terrain state or spawned per approach, and how it
  interacts with despawn.
- Whether ambush groups count against the same population caps as civilians
  (`civ_maxSpawnPerVisit`) or against the WARCOM wave budget.

## Naming: WARCOM becomes OPCOM

The system is renamed **OPCOM** (Opposing Command) when the commander lands, globals included:
`WARCOM_opfor_ap` becomes `OPCOM_opfor_ap`, and so on across the prefix.

WARCOM is inherited naming and describes what the system was — a mirrored pair of spawn timers,
one per side. It no longer describes either half. BLUFOR's commander is the player: task forces
provision at the HQ, wait on `blu_taskforces_standby`, and move only when the player issues a
launch order and clicks a target (`server/warcom/fnc_blu_taskforces_launch.sqf`,
`client/warcom/fnc_WARCOM_mapclick_assault.sqf`). OPFOR's commander is the actor this document
describes. Naming the enemy is what distinguishes the mission from the versions it descends from.

Two constraints on when the rename lands:

- **It breaks saves.** Persistence is vanilla `saveGame` with no custom serialization
  ([`architecture.md`](info/architecture.md)), and the engine snapshots `missionNamespace` by
  variable name, so a renamed broadcast global reads back `nil` in a campaign resumed across the
  change. The AP rework already breaks the format; landing both in one release makes the player
  cross one broken-save boundary instead of two.
- **The zone-control arrays are the wide part.** `WARCOM_zones_controled_by_OPFOR` and
  `WARCOM_zones_controled_by_BLUFOR` account for roughly 50 references across 21 files, and index
  0 of the OPFOR list is the primary assault target. A mechanical replace across
  `server_fnc_init.sqf` and `server_var_init.sqf` also has to leave `fnc_zone_state_init` loading
  before any zone spawns.

Player-facing exposure is three boot-time strings, so the rename is almost entirely internal.
