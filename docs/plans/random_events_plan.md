# Random events: what a turned town does

A turned town is a behaviour the OPCOM director consumes, not part of the commander's
economy, so it lives here rather than inside the commander plan
([`opcom_plan.md`](opcom_plan.md)). It ships as a phase of that director's build order
and reads the belief store and OPFOR-band definition the loop establishes.

Where the player has driven a town into the OPFOR band, the enemy uses it: IEDs on the approach
roads, ambushes on patrols passing through, sabotage against nearby FOBs and parked vehicles.
Reputation stops being a modifier on civilian spawn behaviour and becomes the input to an actor that
plans against the player. The per-town reputation change deleted the two mechanics that did this job
badly; they are recorded below because they are the raw material the director is meant to rebuild.

Decided:

- **Events are free and rolled, not bought.** Reputation is the whole input: a town deep enough
  into the OPFOR band generates them on its own, and the commander that buys garrisons, taskings
  and hardpoints neither funds them nor schedules them
  ([§What the commander spends on](opcom_plan.md#what-the-commander-spends-on)). Charging Army Power for
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
  ([`info/zones_and_civilians.md`](../info/gameplay/zones_and_civilians.md#what-clearing-a-garrison-actually-buys)).

## The runner

A single server daemon drives events, on its own clock beside the OPCOM hardpoint director
(`src/duws/server/warcom/fnc_WARCOM_init.sqf`). Each pass it rolls once for an event; on a hit it
picks a live player, finds the town nearest them within a threshold distance, reads that town's
reputation, and rolls the reputation band's table for what happens. The pipeline is three seams so
the plumbing never changes as events are added: the daemon
(`fnc_random_event_runner.sqf`), a rep-to-weights table (`fnc_random_event_table.sqf`), and a
kind-to-behaviour dispatch (`fnc_random_event_fire.sqf`). Adding an event is one table row plus one
dispatch case.

The table is data-driven: each band is a reputation range with its own weighted menu, and every band
whose range contains the town's reputation contributes to one merged roll — so ranges can partition the
spectrum or overlap to stack a broad menu with a narrow deep-reputation one. The default rows reproduce
the town economy's edges (`fnc_civ_townIncome`): hostile at `<= -10`, friendly at `>= 10`, neutral
between. A friendly town offering the player something is the same mechanism as a turned one acting
against them, so the runner is agnostic and the bands own the menu.

**It anchors on a present player, not on the player's projected path.** This is a deliberate
simplification of the predictive version above: rather than mine a road ahead of where the player is
going, the runner fires near a player already close to a turned town, so the event lands where a
player can witness it. The cost is that a turned town no player is near stays quiet.

It runs on the plain civilian path only — `civ_town_rep` and the town arrays it reads do not exist
under `NONE`, `RAVAGE` or `WBK` — and it is not the blind spawn timer the commander plan rules out:
it spends no Army Power and drips nothing onto an empty map on a clock.

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

`Vcm_Disable` was set on the unit so an AI mod could not override the approach behaviour. Any
scripted-movement event needs the same.

## Open questions

- **The random-event roll itself:** what rate a town at `-10` generates events at against one at
  `-20`, and whether the curve between them is worth having or the band alone should decide.
- **Whether the regroup hold silences events along with the garrison.** A town that keeps mining
  roads while it visibly has nobody in it is either a good scare or an obvious tell.
- **Whether IED placement is persistent terrain state or spawned per approach**, and how it
  interacts with despawn.
- **Whether ambush groups count against the same population control as civilians**
  (the `civ_density` target `fnc_civ_liveTarget` enforces) or against a director budget of their own.
