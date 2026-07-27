# Performance: where the server's time goes

Sustained cost in this mission is dominated by *repeating scans*, not by any one expensive
operation. Everything below was read out of the source rather than profiled in-engine, so
treat the sizes as reasoning about how often code runs and what it touches.

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

## Checked and dismissed

**Unthrottled `waitUntil`.** 35 `waitUntil` blocks contain no `sleep`, so their condition is
re-evaluated every frame. They are not worth changing: almost all are `{dialog}`,
`{!isNull player}` or `{!isNil "someVar"}`, which resolve within a frame or two of being
reached, and every one of the long-lived exceptions tests a single cheap command. Recorded
so the count is not re-investigated — a line-based grep for `waitUntil` without `sleep`
reports roughly double this, because multi-line blocks carry their `sleep` on a later line.
