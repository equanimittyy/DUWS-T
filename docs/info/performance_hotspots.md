# Performance: where the server's time goes

Sustained cost in this mission comes from two shapes, neither of which is an expensive
operation: *repeating scans*, which cost the same on the first minute as on the fourth hour,
and *state that never shrinks*, which does not. Everything below was read out of the source
rather than profiled in-engine, so treat the sizes as reasoning about how often code runs and
what it touches.

## The pattern that costs the most: timed scans anchored on `allUnits`

The expensive shape is a loop that wakes on a timer and walks every unit in the mission to
find something near it. It reads as cheap because each iteration is small, and it is not:
the anchor set grows with the campaign, so a mission that plays fine at two zones degrades
steadily as more are captured and more AI exist.

Two things make it worse than the iteration count suggests. Scheduled scripts share about
3 ms per frame between them, so a long scan stretches over many frames and crowds out
everything else — see
[§Scheduled scripts share ~3 ms per frame](arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate).
And squad-mates stand within metres of each other, so anchoring a radius query on every unit
asks the same question about the same patch of ground once per man.

**The rule for new code:** anchor a proximity scan on players, or hand the search to the
engine with `nearEntities` / `nearestObjects`, which use the spatial index. Anchor on
`allUnits` only when the answer genuinely differs per unit.

One live instance of the shape, for a reader who wants to see it rather than take the rule on
faith: `src/duws/server/missions/fnc_opf_heli_reinforce.sqf:23-32` re-filters `allUnits` by
side and distance every 5 s, one monitor per zone, and keeps doing it until that zone's
defenders fall to a quarter of their starting count — which for a zone the player never
attacks is never. `nearEntities` answers the same question off the spatial index.

## AI caching ships disabled, and re-enabling it is not a one-line change

`modules/zbe_cache/` is present and complete, and the call that would start it is commented
out at `src/duws/server/server_var_init.sqf:251-254`. Distant AI are therefore fully
simulated for as long as they exist.

Caching is normally the largest single lever in a dynamic Arma campaign, so the temptation is
to switch it on. The reason not to do that blind: `src/duws/server/init_zones/fnc_spawnWait.sqf`
already implements a coarser version of the same idea, one instance per zone. It waits for
BLUFOR within the zone radius plus 400 m, holds the zone spawned for a 5-minute grace period
after they leave, and then **deletes** the units outright (`:111-123`).

Two systems that both despawn and restore AI, one deleting and one caching, do not compose.
The failure modes to check for before enabling anything are a zone that never repopulates
because the cache restored units the zone logic had already deleted, and a garrison that
doubles because both systems restored it. Any evaluation has to decide which system owns
zone AI, not run both.

## The enemy gear table never shrinks

`DUWS_enemyGear_scannedUnits` (`src/duws/server/misc/fnc_scanEnemyGear.sqf:19`) is a hashmap
keyed by `netId`, used to avoid re-reading gear off a unit already scanned. Nothing prunes
it, so it holds an entry for every EAST unit ever spawned, including long-dead ones whose
netIds will never be seen again.

Each entry is small and the campaign would have to run a long time for this to matter, which
is why it is recorded rather than fixed. It is listed because the growth is invisible: the
symptom would be a slow server memory climb with no obvious owner.

The same file publishes eight whole arrays with `publicVariable` (`:38-47`), one per gear
category, every time a *new* item is seen. That converges quickly — once the common kit is
known, later units add nothing — but the initial sweep over `allUnits` can fire a burst of
them.

Its `EntityCreated` handler (`:75-92`) also spawns a scheduled script per infantry unit created,
for the rest of the mission, each one only to re-check a table that converged in the first
minutes. Individually trivial; the point is that it never stops, so the cost is proportional to
every unit the campaign will ever spawn rather than to the information gained.

## State that grows for the whole session

The gear table above is one instance of a wider pattern; these are the rest. They share a
symptom that makes them hard to attribute: the mission plays well for an hour and worse at
four, with no single call to point at, because what grew is the size of what every pass has to
walk.

### Task forces are created on a timer and never capped

`src/duws/server/warcom/fnc_WARCOM_blu_assault.sqf:50-113` spawns a BLUFOR task force every 30
minutes for as long as the mission runs, pushes it onto `blu_taskforces_standby` (`:100-102`)
and parks it on a MOVE/CYCLE waypoint pair at HQ (`:88-97`) until the player launches it. That
array shrinks only on launch (`fnc_blu_taskforces_launch.sqf`) or when the group is wiped
(`fnc_WARCOM_gps_marker.sqf:54-58`). Nothing bounds how many may be standing by at once.

Nothing else will collect them either: zone despawn deletes `side _x == EAST` only
(`init_zones/fnc_spawnWait.sqf:110-117`) and mission cleanup skips WEST
(`missions/fnc_mission_cleanup.sqf`). So a task force the player ignores is permanently
simulated AI parked next to the base — inside view distance, never a despawn candidate. Live AI
count is what Arma's frame time tracks, which makes this the mission's largest growth term at
roughly two groups an hour.

The patrol spawner shows what a cap looks like here: `fnc_WARCOM_blu_patrol.sqf:55` gates on
`blufor_patrol_count` and stops once it has one patrol per held zone. The assault spawner has no
equivalent, and OPFOR assault (`fnc_WARCOM_opf_assault.sqf:59-124`) spawns two groups per 30
minutes on the same open-ended terms — those at least get engaged and killed.

### The GPS marker loop appends a position every four seconds

`src/duws/server/warcom/fnc_WARCOM_gps_marker.sqf:70` calls `_primary_waypoint insert [0, …]`
inside a loop that ticks every 4 s (`:103`). `insert` appends where the intent was to replace:
only index 0 is ever read (`:24`, `:88`). The array therefore gains ~900 entries an hour per
task force, and because the write lands at the front, each tick shifts every element already
there — so the per-tick cost rises with the array rather than staying flat. One of these loops
runs per task force, and the section above is why that count grows too. `set [0, …]` is the
whole fix.

### A marker that is never removed, and a script error every four seconds

`src/duws/client/misc/fnc_kndr_unit_markers.sqf:81` passes the loop *index* where
`kndr_removeMarker` (`:183-195`) expects the object, so `kndr_objs find <number>` returns -1 and
`kndr_mrks select -1` raises `Index out of range`. The entry is never removed and the local
marker never deleted, so the 4 s update loop (`:203-208`) retries that same dead entry for the
rest of the mission and throws once per pass. The leaked marker costs nothing; the permanent
error rate does, because every throw writes to the RPT.

It starts the moment a marked object dies — MHQ1 (`server/dialog/fnc_MHQ_deploy.sqf:63`) or the
mission builder BLD1
(`missions/mission_threads/steal_builder/fnc_steal_builder_mission.sqf:239`). The `remoteExec`
callers pass the object and are correct; only the internal update path is wrong.

Separately, `shared/functions/fnc_MHQ_addActions.sqf:11` assigns a marker with no preceding
remove, so re-running it stacks a second marker on the same object.

### `damagedBuildings` holds an object reference per damaged house

`src/duws/server/misc/fnc_warcrimes_script.sqf:21` pushes every damaged non-military house near
a player, and only `count` is ever read (`:35`). The array is cleared in WBK mode (`:30`) and
never otherwise, so it holds one object reference per building for the whole session where an
integer would carry the same information.

Its `BuildingChanged` handler also does a config read, a `BIS_fnc_objectType` call and a
player-distance scan per damage event mission-wide, so it arrives as a burst under artillery
rather than as a trickle.

### Unverified: paradrop canopies

`src/duws/server/missions/fnc_opf_heli_reinforce.sqf:132` creates a `Steerable_Parachute_F` per
dropped trooper, 12 to 20 per reinforcement, and nothing in this tree deletes it.
`misc/fnc_repetitive_cleanup.sqf` will not: its categories are weapon holders, timebombs,
smokes, dead bodies, dead vehicles and *immobile* vehicles, and a landed canopy still reports
`canMove`. Whether the engine reaps them unprompted is not answered anywhere in the source, so
this is the one item here that needs a live check before a fix —
`count (allMissionObjects "ParachuteBase")` after a few reinforcements settles it.

## Checked and dismissed

**VCOM AI is compiled but never started.** `description.ext` includes
`modules/vcom/cfgFunctions.hpp`, so every `VCM_fnc_*` exists and greps as live code, but nothing
calls `VCM_fnc_VcomInit` — the only reference is the commented example at
`modules/VCOM/cfgFunctions.hpp:33`. Its per-frame mine monitor and its AI scheduler are both
registered *inside* that init (`modules/VCOM/Functions/fn_VcomInit.sqf:63`, `:80`), so neither
ever runs, and the `Vcm_Disable` variables set on individual units around the mission are inert.
Worth knowing before reading a VCOM function as a cost.

**R3F's `Draw3D` handler is behind a disabled `#ifdef`.**
`modules/R3F_LOG/fonctions_generales/lib_geometrie_3D.sqf:1018` gates it on
`R3F_LOG_3D_dev_mode`, which the line above leaves commented out, so the per-frame bounding-box
sweep it registers never runs.

**Marker creation is paired with deletion.** Every `createMarker` in the mission threads and
supports has a matching `deleteMarker` on the paths that end the mission; the one exception is
the kndr defect recorded above. The subtitle queue is also bounded —
`client/misc/fnc_duws_dialogue_drain.sqf` dequeues on every pass and expires radio lines older
than 8 s rather than letting them accumulate.

**Unthrottled `waitUntil`.** 35 `waitUntil` blocks contain no `sleep`, so their condition is
re-evaluated every frame. They are not worth changing: almost all are `{dialog}`,
`{!isNull player}` or `{!isNil "someVar"}`, which resolve within a frame or two of being
reached, and every one of the long-lived exceptions tests a single cheap command. Recorded
so the count is not re-investigated — a line-based grep for `waitUntil` without `sleep`
reports roughly double this, because multi-line blocks carry their `sleep` on a later line.
