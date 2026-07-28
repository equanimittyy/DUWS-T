# OPFOR retreat: design notes

OPFOR tied to a zone or a town garrison withdraw when the ground stops being theirs, instead of
being deleted where they stand. They move away from the position they were holding and despawn
once they are clear of it and no player is close enough to watch; a retreat that is still being
observed keeps going further out rather than vanishing.

This is split out of the per-town reputation work, which needed an answer for one narrow case —
what happens to a town garrison when reputation rises out of the OPFOR band while its units are
alive ([`info/zone_and_town_generation.md`](info/zone_and_town_generation.md#ownership-bands-and-the-garrison))
— and found the answer was a general behaviour that zones want too.

## What it replaces

Zone despawn is a deletion sweep. `server/init_zones/fnc_spawnWait.sqf:156-168` takes
`nearObjects` over the zone radius plus the AI buffer and calls `deleteVehicle` on every EAST
unit and vehicle it finds. It runs only after the grace period at `:134-146` has confirmed no
BLUFOR nearby for 300 s, so nobody is normally watching — the units blink out of an empty
landscape. That is correct as a resource measure and says nothing about what happened to them.

The gap is the cases where the ground changes hands with the player still on it. A zone
captured while its garrison is alive falls into `fnc_spawnWait.sqf:171-178`, which despawns
nothing and idles until OPFOR hold it again; the surviving garrison simply stays. A town
garrison lifted out of the OPFOR band by aid or heals has no path at all, because the per-town
plan resets reputation on the garrison dying, not the reverse.

## Why retreat rather than a wider deletion

Deleting units a player can see is the one thing a despawn system must not do, and widening the
existing sweep to cover the changed-hands cases would do exactly that. Retreat is also the
cheaper answer to a problem the per-town plan raises separately: a garrison that withdraws out
of the civilian radius clears the ground without every last unit having to die inside it, which
is what the `WEST SEIZED` capture test needs.

## Shape

Three states, per group rather than per unit — waypoints are a group-level command and the
existing spawners produce groups:

| State | Condition | Behaviour |
|---|---|---|
| Holding | the position is still OPFOR's | unchanged; whatever the spawner set up |
| Withdrawing | the position changed hands, or the town left the OPFOR band | move to a point away from the position, `SAFE`/`AWARE`, not seeking contact |
| Released | clear of the position and no player within the observation radius | deleted, crew first |

A group that reaches its withdrawal point while still observed picks a further one and
continues. There is no cap on that loop other than the group eventually leaving the observation
radius, which is what makes it terminate.

**Waypoints require the group to be local to the machine issuing them.**
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) records that flight and waypoint
commands are silently ignored otherwise. These groups are server-spawned, so the server is the
right locality — but a headless client build would move them, and
[`headless_client_plan.md`](headless_client_plan.md) is the doc that has to agree with this one.

## Open questions

- Whether a withdrawing group is still a valid target for the WARCOM director's reinforcement
  logic, or is written off the moment it enters the state.
- Whether retreat is a campaign option. It is a difficulty change in both directions: the
  player loses the clean sweep of a wiped garrison, and gains ground they no longer have to
  clear unit by unit.
- The observation radius, and whether it uses the same `_player_buffer` of 400 m that
  `fnc_spawnWait.sqf:13` uses for spawn decisions or a shorter line-of-sight test.
- Whether vehicles withdraw with their infantry or independently. Mounted crew leaving a
  dismounted team behind is the realistic outcome and the worse-looking one.
