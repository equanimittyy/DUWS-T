# Composition streaming: implementation plan

Delete a composition's props when no player is near it, and rebuild them from a record when one
returns. Garrison AI already cycles this way (`server/init_zones/fnc_spawnWait.sqf`); this
extends the same gate to the static objects the garrison stands in.

## Why

A zone prefab places 37-72 objects (`server/init_zones/prefabs/modern/*.sqf`), plus five ammo
crates, a light, 3-4 fortification buildings and a flagpole from `fnc_createzone.sqf:151-206` —
call it 65. Zones alone are bounded: `zones_number` tops out at 40
(`client/dialog/fnc_process_campaign_menu.sqf:149`), so ~2,600 objects.

[`hardpoint_system_plan.md`](hardpoint_system_plan.md) is what breaks that. At one composition per
hardpoint and 1-6 per zone (`:192`), plus director-built normals with no ceiling, a large campaign
reaches five figures.

The cost is entity-shaped, not draw-shaped. Rendering is already view-distance culled and
simulation is already off on the props (`fnc_modern_outpost1.sqf:103` and the same block in the
other seven), so hiding objects fixes nothing — a hidden object is still a network entity, still
in `allMissionObjects`, still walked by `nearObjects` at `fnc_spawnWait.sqf:107`, still fed to the
curator loop at `fnc_zeus_objects_init.sqf:26`. Only deleting them moves the number.

## The mechanism

`fnc_duws_keep` already files every composition member under a key in `DUWS_compositions`
(`server/server_fnc_init.sqf:286-300`). That registry is the streaming handle: the members of a
composition are known by name, so nothing has to be inferred from position or class.

Two new verbs beside the existing pair, sharing the registry:

| Verb | Does |
|---|---|
| `fnc_duws_stow` | Record each live member, `deleteVehicle` it, move the key to `DUWS_stowed` |
| `fnc_duws_deploy` | Recreate from the record, re-file through `fnc_duws_keep`, drop the record |

A key lives in exactly one of `DUWS_compositions` and `DUWS_stowed`. That invariant is what makes
"is this composition on the map" answerable without touching an object.

**Records are built at stow time, not at build-out.** Capturing the live objects as they are
means damage, looted crates and player-moved props are caught for free, and there is no standing
memory cost or staleness window. It also means the record is transient — a stow record never
outlives the session, so [`campaign_persistence_plan.md`](campaign_persistence_plan.md) needs no
new save input. A restore replays the builders and every composition comes back deployed.

**The builders are never re-run.** They cannot be: `fnc_createzone.sqf:157-198` rolls the
fortification ring live — count, angle, distance, class and heading are all `random` — so calling
the builder twice produces two different zones. Replaying a record sidesteps determinism entirely,
which is also why hardpoints need no streaming work of their own beyond calling `fnc_duws_keep`.

### What a record holds

| Field | Why it is not inferable on deploy |
|---|---|
| `typeOf` | — |
| `getPosWorld` | Prefabs mix `setPosATL` and `setPosWorld` (`fnc_modern_outpost1.sqf:95,127`); world coordinates collapse the two |
| `vectorDirAndUp` | Tilt types take `surfaceNormal` (`:99`), and heading is rolled for fortifications |
| `simulationEnabled` | Props ship with simulation off and static weapons get it back when crewed (`:156`); a deploy that skips this silently re-simulates the whole map |
| `isDamageAllowed` | Several prefab props and the camp light are `allowDamage false` (`:107,180`) |
| cargo, for `ReammoBox_F` | `fnc_fill_ammobox` rolls contents, so replaying the classname alone refills a crate a player emptied |

Dead and null members are not recorded, so a demolished bunker stays demolished. Its ruin is a
separate object already claimed by the `BuildingChanged` handler
(`server/misc/fnc_repetitive_cleanup.sqf:60-70`) and expires on the normal lifetime.

### What is lost

Partial damage. A prop at 60% health returns intact. This is the accepted price of the tier, and
it is the same thing a save/restore already does — `campaign_persistence_plan.md:230` calls a
restore *"a fresh world with an old ledger."* The difference is that a restore is a deliberate
act and crossing a 600 m boundary is not, so the reset is newly visible even though it is not new.

Recording destruction rather than health is what keeps that from reading as a bug: the case a
player notices is the wall they blew open, not the wall they scratched.

## Ordering: the garrison leaves first

`fnc_spawnWait.sqf:111-119` deletes EAST vehicles and EAST men on foot, but its second clause
tests `vehicle _x == _x` — so **a gunner sitting in a static weapon is deliberately left alive**.
Stowing the props under that gunner would delete a manned gun.

Stow therefore runs after the garrison pass, and the garrison pass gains a `deleteVehicleCrew`
over the composition's static weapons. Getting this backwards produces an AI standing in the air
where its turret used to be, which is the failure mode to watch for when testing step 3.

## Interactions

**The sweep needs no change.** Stowed members are deleted outright rather than handed to
`fnc_duws_disposeAfter`, so they leave `allMissionObjects` immediately and the litter census
(`fnc_repetitive_cleanup.sqf:100`) drops with them. Stow is not `fnc_duws_release`: release drops
the persistent flag, hands members to the sweep on a lifetime, and does `deleteAt _key`
(`server_fnc_init.sqf:308-312`), which destroys exactly the record streaming depends on.

**Zeus reveal improves.** At `ZeusStatus == 2` the curator loop adds `allMissionObjects "ALL"`
every 30 s (`fnc_zeus_objects_init.sqf:26`); a stowed composition is not in it. At the menu
default of `ZeusStatus == 1` (`client/dialog/fnc_enviro_menu.sqf:47`) enemy compositions were
never added in the first place, so nothing changes there.

**Player property is untouched.** Stow deletes recorded members only, so a vehicle parked or a
crate dropped inside a zone is not swept up with the prefab.

## Files touched

| File | Change |
|---|---|
| `server/server_fnc_init.sqf` | New `fnc_duws_stow` and `fnc_duws_deploy` beside the existing helpers; registry line for `DUWS_stowed` |
| `server/server_var_init.sqf` | `DUWS_stowed = createHashMap` |
| `server/init_zones/fnc_spawnWait.sqf` | Crew the static weapons out in the despawn pass; stow after it, deploy on the spawn side |
| `server/init_zones/fnc_createzone.sqf` | Nothing, if the fortification ring keeps filing under the zone key as it does at `:204` |
| `docs/hardpoint_system_plan.md` | The "cores, cover and markers are not despawned" split no longer holds |
| `docs/info/performance_hotspots.md` | Record what streaming removes |

## Task list

- [ ] `fnc_duws_stow` / `fnc_duws_deploy` and the `DUWS_stowed` registry. Verify: stow and deploy a zone from the debug menu, walk it, geometry and headings match.
- [ ] Cargo and destruction capture. Verify: empty a crate and blow a bunker, stow, deploy — the crate stays empty and the bunker stays gone.
- [ ] Wire into `fnc_spawnWait`, garrison pass first. Verify: the 300 s timer cycles props with AI and leaves no gunner standing where a turret was.
- [ ] Confirm the census and curator numbers move. Verify: `allMissionObjects "All"` and the cleanup census log both drop when zones stow.
