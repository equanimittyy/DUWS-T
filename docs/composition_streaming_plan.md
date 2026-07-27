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

`DUWS_compositions` holds whatever is currently on the map; `DUWS_stowed` holds a key exactly
while that composition's streamable members are off it. Presence in `DUWS_stowed` is therefore the
answer to "is this stowed", without touching an object.

The two are not mutually exclusive, because pinned members stay behind when the rest of their
composition leaves. A hardpoint whose gun never stows keeps that gun in `DUWS_compositions` while
its sandbags sit in `DUWS_stowed`.

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

### Members that must never be stowed

Some objects earn their keep by existing rather than by being looked at, and stowing those removes
a capability instead of deferring a cost. The artillery, mortar and AA hardpoint cores are the
known cases ([`hardpoint_system_plan.md`](hardpoint_system_plan.md)) — all three act at ranges far
beyond the gate that would stow them, and an AA gun is the sharpest illustration: a jet crosses a
450 m trigger in about three seconds, so deploy cannot finish before the aircraft is past.

The exemption is per member, not per composition. A pinned core stays resident while the sandbags
and netting around it stream normally, which is where the saving was anyway — one object against
roughly 65.

Marked at `fnc_duws_keep` time rather than tested by class at stow time: only the code that placed
the object knows whether its presence is the point, and a class test would have to be kept in step
with every faction mod's turret names.

## Ordering: the garrison leaves first

`fnc_spawnWait.sqf:111-119` deletes EAST vehicles and EAST men on foot, but its second clause
tests `vehicle _x == _x` — so **a gunner sitting in a static weapon is deliberately left alive**.
Stowing the props under that gunner would delete a manned gun.

Stow therefore runs after the garrison pass, and the garrison pass gains a `deleteVehicleCrew`
over the composition's static weapons. Getting this backwards produces an AI standing in the air
where its turret used to be, which is the failure mode to watch for when testing step 3.

### And comes back separately

Turret gunners are assigned by the prefab at build time (`fnc_modern_outpost1.sqf:146-156`), and
the prefab never runs again — so a deployed composition returns with empty guns unless something
re-crews them. `fnc_spawnWait` owns that, not `fnc_duws_deploy`: deploy is generic and also
rebuilds the HQ and FOBs, which must not acquire OPFOR gunners.

Re-crewing is skipped once the zone is BLUFOR's, for the same reason zone compositions are
persistent rather than released on capture — the emplacements are the player's to use.

### Arrival is confirmed before anything is built

The gate re-tests five seconds after it first sees BLUFOR inside the perimeter, and only then
deploys and spawns. Grazing the edge — a helicopter transiting, a patrol that turns back — used to
commit a garrison; now it also commits a 65-object rebuild, which is enough to make a false
trigger worth waiting out. Garrison and props share the decision because they share the branch.

Two AI raise a zone, one holds it. The asymmetry is deliberate: a zone that needed two to stay up
would flicker off around the edges of the force that just took it.

### Departure is a grace period, not a deadline

Presence is re-sampled every 10 s for as long as the zone is up, and the clock restarts each time
BLUFOR are seen; the zone despawns `_despawn_timer` seconds after the last sighting.

The shape this replaces sampled once, at the timer mark, and pinned the zone permanently if anyone
happened to be inside at that instant — so an assault that ran longer than the timer left the zone
standing for the rest of the campaign. Harmless when only AI cycled. With props on the same gate it
meant streaming helped for zones a player drove past and did nothing for zones they fought over,
which is the wrong way round.

A zone that changes hands is not despawned — its emplacements are the player's now — and its gate
idles until OPFOR hold it again rather than re-entering the arrival branch, which would spawn an
OPFOR garrison inside a zone BLUFOR own.

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

**Release has to clear the stow record, and does not.** `fnc_duws_release`
(`server_fnc_init.sqf:305-313`) walks `DUWS_compositions` and deletes that key; it never looks at
`DUWS_stowed`. Retiring a stowed composition therefore succeeds while changing nothing, and the
composition redeploys intact on the next approach.

Unreachable while zones are the only thing that streams, because nothing releases a zone. It goes
live with normal hardpoints, which release on clear — so it has to be closed before that lands,
not after. Retiring a composition should be terminal whichever map its key is in.

**A retired composition's gate must be stopped explicitly.** After release the key is absent from
`DUWS_compositions`, so `fnc_duws_stow` returns false and does nothing. That is the right outcome
reached the wrong way: it depends on a membership test rather than on anything knowing the
composition is finished. Left alone it also leaks one idle loop per retired composition for the
rest of the campaign.

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
- [ ] Per-member stow exemption, set through `fnc_duws_keep`. Verify: a pinned member survives a stow that removes everything around it.
- [ ] `fnc_duws_release` clears `DUWS_stowed` as well. Verify: release a stowed composition, approach it, nothing comes back.
- [ ] Terminal retirement a gate can read, so a released composition's loop exits. Verify: no thread survives its composition.
