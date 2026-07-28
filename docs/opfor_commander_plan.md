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

Ran at town spawn when reputation was negative (`server/misc/fnc_civ_handler.sqf:531-558` before
removal).

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

Ran immediately after conversion, in the same spawn pass
(`server/misc/fnc_civ_handler.sqf:563-588` and `server/misc/fnc_civ_suicideBomberBehaviour.sqf`
before removal).

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

## What the director needs

Decided so far:

- It acts on towns in the OPFOR band (reputation `<= -10`), the same band that pays OPFOR Army
  Power and spawns a garrison.
- It plans outside the town's presence trigger. The civilian handler runs only when a player is
  inside the radius; a director that can only act then cannot mine a road ahead of the player.
- Events are attributed to the town, so clearing that town's garrison — which resets its
  reputation to `0` — also stops its events.

Open, and to be settled before implementation:

- Event budget: whether sabotage draws from OPFOR Army Power, from a separate per-town pool, or
  fires on a timer.
- Whether IED placement is persistent terrain state or spawned per approach, and how it
  interacts with despawn.
- Whether ambush groups count against the same population caps as civilians
  (`civ_maxSpawnPerVisit`) or against the WARCOM wave budget.
