# OPFOR retreat: design notes

OPFOR give ground instead of being deleted where they stand. They move away from the position they
were holding and despawn once no player or friendly AI is close enough to watch; a withdrawal that
is still being observed keeps going further out rather than vanishing.

`server/misc/fnc_opfor_retreat.sqf` is the order — `[[_group, …], _holdPos] spawn
fnc_opfor_retreat`, groups or units. It takes arbitrary groups rather than anything the caller
owns, because the town garrison is the first caller and the OPFOR commander
([`opfor_commander_plan.md`](opfor_commander_plan.md)) is the intended second.

## What it replaces

Zone despawn is a deletion sweep. `server/init_zones/fnc_spawnWait.sqf` takes `nearObjects` over
the zone radius plus the AI buffer and calls `deleteVehicle` on every EAST unit and vehicle it
finds. It runs only after the grace period has confirmed no BLUFOR nearby for `_despawn_timer`
seconds, so nobody is normally watching — the units blink out of an empty landscape. That is
correct as a resource measure and says nothing about what happened to them.

The gap is the cases where the ground changes hands with the player still on it. A zone captured
while its garrison is alive falls into the branch that despawns nothing and idles until OPFOR hold
it again; the surviving garrison simply stays. **Zones are not yet wired to the order** — the
garrison is.

## Why retreat rather than a wider deletion

Deleting units a player can see is the one thing a despawn system must not do, and widening the
existing sweep to cover the changed-hands cases would do exactly that. Retreat is also the cheaper
answer to a problem the per-town plan raises separately: a garrison that withdraws out of the
civilian radius clears the ground without every last unit having to die inside it, which is what
the `WEST SEIZED` capture test needs
([`info/zones_and_civilians.md`](info/zones_and_civilians.md#ownership-bands-and-the-garrison)).

## Shape

Per group rather than per unit — waypoints are a group-level command and the existing spawners
produce groups. The force is split on index parity into two elements that alternate roles every
bound, so the callers' spawn order (a patrol, then a team, then a vehicle) already distributes
kinds across both rather than stacking one element with all of anything.

| Constant | Value | What it is |
|---|---|---|
| `BOUND_LENGTH` | 300 m | one element's move before the roles swap; also how often the bearing re-aims |
| `BOUND_TIMEOUT` | 60 s | a bound that has not finished by here swaps anyway |
| `OBSERVE_RADIUS` | 1000 m | no BLUFOR inside this of **any** surviving group and the whole force despawns |
| `SUPPRESS_RANGE` | 400 m | beyond this the covering element holds its fire instead of area-firing |
| `GIVE_UP` | 1200 s | contact never broken: the force stands back up and fights |

| Role | Posture | Orders |
|---|---|---|
| Moving | `AWARE` / `GREEN`, `FULL` speed, `enableAttack false` | one `MOVE` waypoint `BOUND_LENGTH` along the bearing, plus a `doMove` |
| Covering | `COMBAT` / `RED`, `LIMITED` speed | no waypoint at all, `doWatch` the contact, `doSuppressiveFire` re-issued each poll |

`GREEN` on the moving element rather than `BLUE`: they are told to ignore the fight, not to die in
it — they return fire if engaged but never initiate. `enableAttack false` stops them breaking off
to close on a target and stranding themselves outside their partner's arc.

**`enableAttack` is deliberately left alone on the covering element.** Its documented effect is
that a group stops attacking on its own, and attacking on its own is that element's entire job; if
the command is stronger than advertised, the cost is a covering element that never fires. Holding
is enforced by the empty waypoint list instead. The asymmetry is the point — a mover that fails to
shoot is harmless, a coverer that fails to shoot is the feature not working.

**The covering element is split every poll by what each unit knows.** A unit whose
`findNearestEnemy` returns something is left entirely alone and its `doWatch` released — `RED` plus
a live target is what produces kills, and `doSuppressiveFire` is a fire-at-*this-point* order that
would override the engagement the unit was about to make. Only the blind half area-fires.

Their aim point is the latest contact any covering unit knows about, falling back to the bearing
anchor. So a force that loses sight keeps working the spot it last had someone at, rather than the
one the bound opened on sixty seconds earlier. Firing at a *position* rather than at the unit is
deliberate: targeting the object would track a moving player, which is aimed fire wearing
suppression's name.

Suppression is therefore additive and never load-bearing — the element engages what it can see
whether or not `doSuppressiveFire` takes.

`OBSERVE_RADIUS` is a sighting range, not a rendering one — infantry at 500 m are plain to the
naked eye and unmissable through an optic. It is deliberately not tied to the 400 m buffer zone
streaming uses for its own spawn decisions: that figure prices a composition rebuild, this one
prices being seen to cheat. The test is over the whole force, not per group: releasing the lead
element while the rear is still in contact would delete half a firefight.

The bearing runs toward the nearest zone in `WARCOM_zones_controled_by_OPFOR`, but only where that
also opens the range to the nearest BLUFOR — a held zone on the far side of the player would
otherwise route the withdrawal straight back through them. Otherwise it is directly away.

Arrival is never the release. A waypoint statement does not fire on a waypoint the group cannot
reach ([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#a-waypoint-statement-never-runs-if-the-group-cannot-reach-the-waypoint)),
so the bound point is only clamped to the map rather than resolved to a safe position: a bound that
ends in a bay costs one swap and nothing else.

**Nothing is ever deleted in front of a pursuer.** A force that has not broken contact by `GIVE_UP`
stands down instead: `DUWS_retreating` is cleared, `enableAttack` restored, posture set back to
`COMBAT`/`RED`, and they become ordinary OPFOR who happen to be where they are. `allowFleeing` is
left at `0` — a force already ordered out once that could not break contact has nowhere to rout to.
Corpses are never collected on any path: bodies carry the search flag and are the garrison's
payout, and the litter sweep already owns their lifetime.

**Withdrawing units are exempt from zone streaming.** They carry `DUWS_retreating`, and
`fnc_spawnWait.sqf` skips it in both delete clauses. Civilian towns sit on enemy zones by design,
so a town garrison walking out crosses a zone's despawn radius on its way — collecting it there
would delete it in front of the force that pushed it out. The stand-down path drops the flag, so
nothing the order abandons stays exempt.

`allowFleeing 0` is set on every withdrawing group: fleeing AI abandon their waypoints and
scatter, and the bounds are the whole mechanic. `Vcm_Disable` is set for the same reason an AI mod
must not override any other scripted movement.

**A lone group cannot bound.** With one group there is no covering element, so it moves every bound
and the mechanic degrades to a plain withdrawal. This is the common case for a garrison broken at
20 %, where the survivors are often a single team; bounding earns its keep on the band-exit case
and on whatever the OPFOR commander hands over later.

**Waypoints require the group to be local to the machine issuing them.**
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#waypoint-and-flight-commands-are-ignored-unless-the-group-is-local-to-that-machine)
records that flight and waypoint commands are silently ignored otherwise, which is why the order
is registered server-side and not broadcast. A headless client build would move these groups, and
[`headless_client_plan.md`](headless_client_plan.md) is the doc that has to agree with this one.

## Open questions

- Whether a withdrawing group is still a valid target for the WARCOM director's reinforcement
  logic, or is written off the moment it enters the state.
- Whether retreat is a campaign option. It is a difficulty change in both directions: the player
  loses the clean sweep of a wiped garrison, and gains ground they no longer have to clear unit by
  unit.
- Whether vehicles withdraw with their infantry or independently. They currently withdraw
  independently, because the spawners already build each vehicle as its own group — mounted crew
  leaving a dismounted team behind is the realistic outcome and the worse-looking one.
