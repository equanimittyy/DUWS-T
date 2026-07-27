# Known issues and untested surface

What is broken, what is merely unverified, and what the previous developer worked around
rather than fixed. Everything here is reproducible from the source; nothing is speculation.

## Untested since the client/server split

The move to `server/` / `client/` / `shared/` rewrote every script path in the mission.
`tests/run.sh` proves each one resolves and that no function compiled empty, but path
resolution is not execution — only a live run proves the campaign still plays. Zone
generation has been exercised; the rest has not.

- [ ] Capture a zone and confirm the marker flips **on a second machine**, not just the host
- [ ] Run a side mission to completion and confirm the CP/AP reward lands
- [ ] Save and reload mid-campaign — but settle whether a save happens at all first (see below)
- [ ] Call heli-lift **as a non-host player** (see below)
- [ ] Request one support of each family: drop, artillery, UAV, FOB

Zone capture and side missions are server-owned — 16 of 16 zone files and 11 of 12 mission
files run server-side, pushing notifications outward to clients. The client-owned/
server-commanded inversion that made heli-lift unusable cannot occur there, so the residual
risk is narrower: a `publicVariable` that never lands. That is only visible with a second
player connected, which is why the first item above says so explicitly.

## Heli-lift for non-host players

`client/supports/fnc_helolift.sqf` used to create the transport helicopter on the calling
client and then ask the server to give it waypoints. Waypoint and flight commands are only
honoured where the group is local, so this worked for a hosting player — whose client *is*
the server — and silently did nothing for anyone else. `fnc_request_support.sqf` carried an
`if (!isServer) exitWith` that disabled the whole support for non-host players rather than
fix it.

The helicopter is now created and owned by `server/supports/fnc_helolift_spawnHeli.sqf`, and
that gate is gone. **The host case is confirmed working; the non-host case is not, and cannot
be tested solo** — it needs a second player or a dedicated server. If it misbehaves in co-op,
restoring the `!isServer` gate re-hides the feature without reverting the rewrite.

Background on the locality rule: [`docs/info/arma_engine_gotchas.md`](docs/info/arma_engine_gotchas.md).

## Does a multiplayer save happen at all?

Unverified in **either** direction, and worth settling before anyone builds on top of it.

`server/misc/fnc_autoSave.sqf` is the only save in the mission: it re-enables saving if
`savingEnabled` is false, then calls `saveGame`. Its one caller is the SITREP support. The
common understanding is that `saveGame` does nothing in multiplayer, which would make the
whole path dead in co-op — but nothing in this tree demonstrates that. No RPT in `temp/`
contains a single save-related line, and the mission disables saving itself at
`server/server_init.sqf:113` (`enableSaving [false, false]`), which is a mission decision and
says nothing about what the engine would do. Treating "saveGame is a no-op in MP" as
established fact is how an assumption gets promoted to a premise.

Two failure modes are being conflated and need separating, because `fnc_autoSave.sqf:5-8`
actively tries to undo the second one:

- the engine refuses to save in a multiplayer session at all
- saving was switched off at boot and the re-enable does not take

**The test.** Host the mission in multiplayer — hosted counts, `isMultiplayer` is true — call
SITREP, then check whether a resumable save appears. That distinguishes "no save" from "save
works and reload is the untested half". For the diagnosis rather than the symptom, log
`isMultiplayer` and `savingEnabled` either side of the `enableSaving` call, plus a line after
`saveGame` proving it was reached.

Until that runs, the SITREP notification is unsound in one direction or the other: it
broadcasts *"The game has been saved"* to every player unconditionally
(`server/supports/fnc_sitrep_support.sqf`). If MP saves do not work, that message is a lie to
everyone; if they do, it is correct as written. Do not gate it on `isMultiplayer` before
knowing which — the gate would suppress a true message in the case where saving works.

This matters beyond the save button: [`docs/campaign_persistence_plan.md`](docs/campaign_persistence_plan.md)
opens by asserting the current save cannot work, and that assertion rests on the same
unverified premise.

## Open defects

| Defect | Where | Effect |
|---|---|---|
| `localize "STR_DUWS_T_jjztkt04"` names a key that has never existed in `stringtable.xml` | `client/supports/fnc_siva_drop.sqf:88` | The player sees the raw key name on screen instead of a message |
| `random_placement` is set on the client and never `publicVariable`'d | `client/dialog/fnc_HQ_random_place.sqf`, `fnc_HQ_faction_dialog.sqf`, `fnc_startup_faction_flow.sqf` | Harmless today — its only reader is client-side on the same machine — but it fails silently the moment anything server-side reads it |
| Two registered functions are never called from anywhere | `server/missions/fnc_missionPatrolsSmall.sqf`, `server/misc/fnc_findSafeMissionPos.sqf` | Dead weight; both carry a `Locality: unreferenced` header saying so |
| Two script paths in `paths_baseline.txt` point at files that do not exist | `client/misc/fnc_player_markers.sqf`, `server/misc/fnc_repetitive_cleanup.sqf` | Pre-dates the test suite; baselined so the linter gates regressions without being blocked by it |
| Six `format[...]` calls wrap a single literal with no placeholders | `client/supports/fnc_helolift.sqf` | Cosmetic — a wasted call per invocation |
| `fnc_log` calls itself instead of writing the line | `shared/functions/fnc_log_init.sqf:25` | Unbounded recursion on every line at or below the active level: nothing reaches the RPT and the first logged milestone kills the boot. The `diag_log` -> `fnc_log` sweep has to skip this one file — it is where `diag_log` lives |

## Zone generation is slow at large radii

`server/misc/fnc_moreUrban_locations.sqf` filters candidate zone sites by asking the engine
how many buildings sit within 100 m of each — one `nearestTerrainObjects` sweep per
candidate. Logged runs at `zones_max_dist_from_hq = 15000` took 20 s, 70 s and 114 s for
1144, 3392 and 5909 candidates: a flat ~50 candidates/second, so the spread is candidate
count and not lookup speed. What moves the count is the arc filter, whose yield depends on
where HQ landed relative to the map — the same radius left 1144 of 6145 candidates in one
run and 5909 of 6064 in another.

A flat rate that tracks frame rate rather than workload is the scheduler rationing the pass,
so the sweeps are now batched unscheduled
([§scheduled scripts](docs/info/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)).
**Unmeasured in game so far**: the `ZONES` line now reports the pass as wall-clock versus
time spent sweeping, and those two figures decide whether anything further is worth doing.
If they converge, the engine lookups are the floor and only cutting the candidate count
helps — capping the survivor pool would do it, at the cost of variety in zone siting and in
the side-mission locations that reuse the same pool.

Reading those logs: [`docs/info/testing.md`](docs/info/testing.md#runtime-logging-reading-the-rpt).

## Zone and civilian siting defects

Thirteen defects in the zone-siting and Dynamic Town subsystems are catalogued with their
failure modes alongside the explanation of how those systems work, rather than restated
here: [`docs/info/zone_and_town_generation.md`](docs/info/zone_and_town_generation.md#defects-subsystem-a).

The two worth knowing before a long campaign: the origin keep-out uses `exitWith` inside a
loop, so a rejected candidate silently costs a zone slot and you get fewer zones than
requested; and dynamic towns can spawn on top of enemy zones because the exclusion wait
never actually blocks.

## Worked around, not fixed

Carried from the previous developer and left alone deliberately.

- **`Land_GuardTower_02_F` reports one building position with a wrong Z**, and `modelToWorld`'s
  Z is unusable on it too. `server/init_hq/fnc_BluHQinit.sqf:348` combines model-space XY with
  world-space Z to place the tower garrison. The comment there records the reasoning.
- **Zone selection can pick a centre that surprises BLUFOR.** Three WARCOM spawners
  (`fnc_WARCOM_opf_patrol.sqf`, `fnc_WARCOM_opf_qrf.sqf`, `fnc_random_veh_opf_patrol.sqf`)
  each place their units deliberately far from the zone centre to compensate. The underlying
  selection is untouched.
