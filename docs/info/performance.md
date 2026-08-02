# Performance: where the server's time goes

Sustained cost in this mission comes from two shapes, neither of which is an expensive operation:
*repeating scans*, which cost the same on the first minute as on the fourth hour, and *state that
never shrinks*, which does not. This doc covers both, and the design decisions taken against them.
Everything here was read out of the source rather than profiled in-engine, so treat sizes as
reasoning about how often code runs and what it touches.

Two of the three growth terms this tree carried are bounded now, and the shape of the bound is worth
knowing because the symptom they shared was a mission that plays well for an hour and worse at four,
with no single call to point at. BLUFOR task forces stop at one standing by
(`warcom/fnc_WARCOM_blu_assault.sqf`), so an ignored one no longer accumulates as permanently
simulated AI beside the base. The task-force waypoint slot is written rather than appended to
(`warcom/fnc_WARCOM_gps_marker.sqf`), where only index 0 was ever read. The third, the enemy gear
scan, still runs for the whole session, and why a convergence ceiling is not the fix for it is in
[`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#the-enemy-gear-scan-runs-for-the-whole-session).

## The pattern that costs the most: timed scans anchored on `allUnits`

The expensive shape is a loop that wakes on a timer and walks every unit in the mission to find
something near it. It reads as cheap because each iteration is small, and it is not: the anchor set
grows with the campaign, so a mission that plays fine at two zones degrades steadily as more are
captured and more AI exist.

Two things make it worse than the iteration count suggests. Scheduled scripts share about 3 ms per
frame between them, so a long scan stretches over many frames and crowds out everything else — see
[§Scheduled scripts share ~3 ms per frame](arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate).
And squad-mates stand within metres of each other, so anchoring a radius query on every unit asks the
same question about the same patch of ground once per man.

**The rule for new code:** anchor a proximity scan on players, or hand the search to the engine with
`nearEntities` / `nearestObjects`, which use the spatial index. Anchor on `allUnits` only when the
answer genuinely differs per unit.

The shape's worst instance is gone with the airdrop reinforcement it belonged to: one monitor per zone
re-filtered `allUnits` by side and distance every 5 s, and kept doing it until that zone's defenders
fell to a quarter of their starting count — which for a zone the player never attacks is never.
`fnc_spawnWait.sqf:23-26` is the shape done right, and answers a comparable question per zone off the
spatial index instead.

## AI caching ships disabled, and re-enabling it is not a one-line change

`modules/zbe_cache/` is present and complete, and the call that would start it is commented out at
`src/duws/server/server_var_init.sqf:251-254`. Distant AI are therefore fully simulated for as long as
they exist.

Caching is normally the largest single lever in a dynamic Arma campaign, so the temptation is to
switch it on. The reason not to do that blind: `src/duws/server/init_zones/fnc_spawnWait.sqf` already
implements a coarser version of the same idea, one instance per zone. It waits for BLUFOR within the
zone radius plus 400 m, holds the zone spawned for a 5-minute grace period after they leave, and then
**deletes** the units outright (`:144-155`).

Two systems that both despawn and restore AI, one deleting and one caching, do not compose. The
failure modes to check for before enabling anything are a zone that never repopulates because the
cache restored units the zone logic had already deleted, and a garrison that doubles because both
systems restored it. Any evaluation has to decide which system owns zone AI, not run both.

## A FOB garrison sleeps rather than despawning

`server/init_hq/fnc_FOBgarrisonSleep.sqf` stops simulating a FOB's twelve soldiers once no player
has been within `base_garrison_sleep_range` for `base_garrison_sleep_delay`. Nothing culled them
before, so the count grew with the campaign: the FOB cap is `floor(zones x 0.7)`, which is 168
permanently-simulated soldiers on a 20-zone map.

**Frozen, not deleted, which is the one place this departs from zone streaming.** A zone garrison is
OPFOR's and is rebuilt from a table, so deleting it loses nothing. A FOB's belongs to the player, and
rebuilding it would hand back every soldier who had been killed — a free version of the 2 CP
redeploy, bought by walking away for two minutes. Freezing keeps identity and damage; simulation is
where nearly all of an idle soldier's cost sits, so the saving is most of it either way.

Two consequences worth knowing. Object count is *not* bounded by this, unlike the composition
streaming below — the units still exist, so this trades CPU without trading slots. And the proximity
test is players-only rather than `fnc_duws_bluforNear`: that helper's AI arm exists to notice BLUFOR
arriving on OPFOR ground, and at a friendly base it would count the garrison standing in the middle
of its own radius and never let it sleep.

## Map object count is bounded by proximity, not campaign length

The same gate cycles a zone's props. `fnc_duws_stow` records each composition member and deletes it;
`fnc_duws_deploy` rebuilds from the record when BLUFOR return. What stays resident therefore tracks
where the players are rather than how many zones were generated.

The arithmetic is what forces it. A zone prefab places 37-72 objects
(`server/init_zones/prefabs/modern/*.sqf`) plus five crates, a light, 3-4 fortification buildings and a
flagpole (`fnc_createzone.sqf:151-206`) — call it 65. Zones alone are bounded, since `zones_number`
tops out at 40, so roughly 2,600. [`hardpoint_system_plan.md`](../hardpoint_system_plan.md) is what
breaks that: one composition of the same size per hardpoint, 1-6 per zone, plus director-built normals
with no ceiling, reaches five figures on a large campaign.

**Deleted rather than hidden.** A hidden object is still a network entity, still returned by
`allMissionObjects`, still walked by `nearObjects`, and still enumerated every 30 s by
`misc/fnc_zeus_objects_init.sqf` at `ZeusStatus == 2`, which sweeps `allMissionObjects "ALL"` whether
or not anything in it is new to the curator. Rendering was never the cost — the
engine culls that by view distance already, and the prefabs ship with simulation off. Only deleting the
entity moves the number.

**Replayed from a record rather than rebuilt by the builder.** A zone builder is not deterministic:
the prefab itself is drawn with `selectRandomWeighted`, and inside one, `fnc_modern_simple_zone`
sites its mortar and both AA guns by rolling positions until one is flat and dry — so calling the
builder a second time produces a different zone. Recording the placed result sidesteps determinism
entirely, and it is why a composition needs no streaming code of its own beyond filing its objects
through `fnc_duws_keep`. Because the record is built when a composition is stowed rather than when it
is placed, damage, looted crates and player-moved props are captured as they actually are, and nothing
outlives the session — [`campaign_persistence_plan.md`](../campaign_persistence_plan.md) gains no save
input.

Order matters at the despawn end: the garrison pass runs first, then static weapons are crewed out,
then the composition stows. `fnc_duws_stow` refuses while a streamable member has living crew, so a
zone whose turret still holds a gunner stays on the map and retries next cycle. Members whose effect
depends on existing at all — an artillery, mortar or AA core — are pinned at `fnc_duws_keep` time and
stay resident while the furniture around them streams.

## The escalation census is a frame stall, so it is placed rather than removed

`src/duws/server/misc/fnc_escalation.sqf` does a config read and a `BIS_fnc_objectType` call for every
building damaged anywhere on the map, and a player-distance scan for each one that passes those
filters, so the cost arrives as a burst under artillery rather than as a trickle.

Its census (`nearestTerrainObjects` for `"House"` across the whole map) is the single most expensive
call the system makes, measured at **5.03 s for Altis's 17472 houses**. It is one engine call, so it is
a frame stall rather than five seconds of shared scheduler time and nothing about the 3 ms budget above
applies to it: it cannot be sliced, and there is no incremental form of the command.

Two things follow. The search radius is `worldSize * 0.7072`, the distance from the map's centre to its
corner, rather than `worldSize` — both cover the square and return the same count, but the larger radius
scans twice the area for it. And because the remaining cost cannot be removed, it is *placed* instead:
the census is the last step of generation, called from `fnc_init_OPFOR_WARCOM` after civilian towns are
registered, behind its own `fnc_map_prompt` banner, so the stall lands inside a wait the player is
already watching. Spawned off `WARCOM_init_done`, where it used to sit, it landed on the frame the
banner cleared and the player took control.

The banner is `remoteExec`'d, and a `remoteExec` to your own machine still runs a frame later, so
without a wait the frame freezes before anything draws and the banner is never seen. The census waits on
the draw rather than on a fixed delay: `fnc_map_prompt` writes `DUWS_map_prompt_shown` as it commits the
control, and the census blocks until that reads back its own banner. A fixed delay is a guess in both
directions — too short on a loaded frame, paid in full when the draw was instant. A shut map
short-circuits the wait, which is what a dedicated server has: it draws nothing locally and freezes no
player's client. A three-second deadline backstops a draw that never arrives, so a failed banner cannot
wedge generation.

Two alternatives were rejected. Caching the count per world does not hold: the mission is map-portable
and mod-tolerant, so a stored figure goes stale silently whenever terrain content changes. Tiling the
count across frames removes the stall but raises total work for edge handling, and it is only worth
revisiting if the placement above proves insufficient.

## Checked and dismissed

**Paradrop canopies no longer leak.** OPFOR reinforcement used to create a `Steerable_Parachute_F` per
dropped trooper and nothing deleted them; that whole feature is removed. `misc/fnc_repetitive_cleanup.sqf`
collects a landed canopy either way: `ParachuteBase` is one of its litter classes, and the vehicle clause
takes anything unmanned. Worth knowing for the BLUFOR paradrop support and for anything that reintroduces
a scripted drop.

**VCOM AI is compiled but never started.** `description.ext` includes `modules/vcom/cfgFunctions.hpp`,
so every `VCM_fnc_*` exists and greps as live code, but nothing calls `VCM_fnc_VcomInit` — the only
reference is the commented example at `modules/VCOM/cfgFunctions.hpp:33`. Its per-frame mine monitor and
its AI scheduler are both registered *inside* that init
(`modules/VCOM/Functions/fn_VcomInit.sqf:63`, `:80`), so neither ever runs, and the `Vcm_Disable`
variables set on individual units around the mission are inert. Worth knowing before reading a VCOM
function as a cost.

**R3F's `Draw3D` handler is behind a disabled `#ifdef`.**
`modules/R3F_LOG/fonctions_generales/lib_geometrie_3D.sqf:1018` gates it on `R3F_LOG_3D_dev_mode`, which
the line above leaves commented out, so the per-frame bounding-box sweep it registers never runs.

**Marker creation is paired with deletion.** Every `createMarker` in the mission threads and supports has
a matching `deleteMarker` on the paths that end the mission. The subtitle queue is also bounded —
`client/misc/fnc_duws_dialogue_drain.sqf` dequeues on every pass and expires radio lines older than 8 s
rather than letting them accumulate.

**Unthrottled `waitUntil`.** 36 `waitUntil` blocks contain no `sleep`, so their condition is re-evaluated
every frame. They are not worth changing: almost all are `{dialog}`, `{!isNull player}` or
`{!isNil "someVar"}`, which resolve within a frame or two of being reached, and every one of the
long-lived exceptions tests a single cheap command. Recorded so the count is not re-investigated — a
line-based grep for `waitUntil` without `sleep` reports roughly double this, because multi-line blocks
carry their `sleep` on a later line.
