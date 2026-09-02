# Garrison strength and reserves

Every OPFOR-held zone and town fields a garrison whose strength is a ledger of destroyed
composition tokens, and whose live footprint is capped and topped up from a reserve pool. This
doc is the reference for that model; where it and the source (`src/duws/server`) disagree, the
source wins.

## One model, two site kinds

A garrison is a **site**: the shared `fnc_site_*` store (key, pos, radius, roster) that zones and
towns both register in. A site raises a composition, gets ground down by the same player, and
comes back at what was left, not what it started with — one model, whichever kind of ground holds
it. The only differences are which tier table it draws from (`DUWS_zoneSpawnTiers`,
`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf:32`, vs `DUWS_townSpawnTiers`,
`src/duws/server/misc/fnc_civ_state_init.sqf:63`) and what happens once it's beaten: a zone flips
to BLUFOR, a town is cleared back toward neutral and bought up again by the commander.

## The ledger

Strength is not a scalar fraction. It is a multiset of composition tokens the garrison could ever
field (`full`), minus the tokens it has actually lost (`lost`):

```
full      = mult copies of the filtered x1 tier list, stamped at raise
              (filtered = what the side can currently field, given AP and settings)
lost      = flat token list, persists across a stow
surviving = full minus lost, by value                    (DUWS_fnc_garrisonSurviving)
pool      = surviving beyond the standing template        (the reserve)
garrison  = surviving capped to the standing template     (what deploys)
strength  = (fullMen - lostMen) / fullMen, clamped [0,1]   (DUWS_fnc_garrisonStrength)
```

A token is lost when its **group is wiped** — destroy one tank, lose one tank. A squad that takes
casualties but keeps a survivor is not recorded: it streams out and comes back whole next raise.
Chip damage does not persist; only a wipe does.

Both the raise and a town's tier buy call one shared derivation, `DUWS_fnc_garrisonDerive {key,
x1, mult, stand}` (`src/duws/server/misc/fnc_garrison_strength_init.sqf:62`): it stamps `full`,
computes `surviving`, and splits it against `_stand` (the density-thinned standing template) into
`[garrison, pool]`. Losses come out of the pool before they ever thin the standing garrison.

The ledger API, all in `src/duws/server/misc/fnc_garrison_strength_init.sqf`:

| Function | Does |
|---|---|
| `DUWS_fnc_garrisonSetFull {key, full}` | Stamp `full` and its man count. Called at raise, and on a town tier buy. |
| `DUWS_fnc_garrisonLost {key}` | The lost token list. |
| `DUWS_fnc_garrisonSurviving {key}` | `full` minus `lost`, by value. |
| `DUWS_fnc_garrisonRecordLoss {key, token}` | Push one lost token, bounded at its count in `full` — a double-fire of the killed handler is a no-op. |
| `DUWS_fnc_garrisonStrength {key}` | The live `[0,1]` projection the map bar reads. |
| `DUWS_fnc_garrisonSeed {key, frac}` | Mark random tokens lost until survival is at or under `frac`, spending the pool before the garrison. Recapture and a town clear both call it with `0.3`. |
| `DUWS_fnc_garrisonUnlose {key, target}` | Remove random lost entries until survival reaches `target`. The town reinforce purchase's hook — a paid replacement, not a heal. |
| `DUWS_fnc_garrisonForget {key}` | Clear `full`/`lost` entirely. Called only when a town leaves the OPFOR band, so a garrison re-earned later starts fresh instead of redeploying the remains of ground that stopped being contested. |
| `DUWS_fnc_garrisonHeld {key}` | Liveness: true from the moment a raise finishes placing men to the stow or capture that tears it down. Gates the capture test and the refill pass. |

`DUWS_fnc_garrisonSetLive {key, live}` (same file) is the only writer of `DUWS_fnc_garrisonHeld`,
and it doubles as the registry maintainer: it pushes or drops `key` on `DUWS_garrisonSites`, the
list the refill pass iterates. A site is on that list exactly while it's live, kept in lockstep
because both are written in the one place.

Hardpoints are not on this ledger. An emplacement's liveness is its own broadcast `DUWS_hardpoints`
row — present means alive, the streamer deletes it on clear — read client-side by the strat-map
pickers and latched (a cleared hardpoint never returns). That broadcast, one-shot model doesn't fit
this server-only, graded, recapturable one, so the two are kept deliberately separate. The streamer's
`DUWS_hpPeak_<key>` is its server-side deployed-gate, the analogue of `garrisonLive`.

An old save's strength is not migrated: nothing has stamped `full` yet, so the first raise after
an upgrade starts every garrison fresh.

## Recording a loss

`DUWS_fnc_garrisonReserveWatch {key, grps}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf:192`) tags each unit with its group's source
token — stamped on the group at raise by `DUWS_fnc_zoneSpawnOne`
(`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf:251`) — and hangs a `Killed` handler on it.
The handler checks that the whole group is down (`{alive _x} count units (group _unit) == 0`)
before calling `DUWS_fnc_garrisonRecordLoss`; a unit dying with squadmates still up records
nothing. The tag rides the *unit*, not the group, since a dead man can outlive it. The same
handler also fires the event-refill trigger (below).

## Reserve depth and the group ceiling

`enemyunitMultiplier` is reserve depth, not a live-force multiplier. A site always stands up its
**x1** tier composition; the surplus `(mult - 1)` copies wait as a pool that refills the garrison
as casualties are taken. This exists because a composition token is a group, and the engine
silently drops any `createGroup`/`BIS_fnc_spawnGroup` call once a side passes **144 groups**
(`docs/info/architecture/arma_engine_gotchas.md`) — scaling the live composition wholesale at x3 could ask for
triple a tier's groups on one site alone, and two hot sites at once would blow the wall.

Per-site, the live *composition* group count is capped at the standing template's count, stored
as `DUWS_zoneCeiling_<key>`. `DUWS_fnc_garrisonGroupCount {key}`
(`src/duws/server/init_zones/fnc_zone_state_init.sqf:164`) counts distinct alive groups the
streaming garrison raised; a prefab's manned static weapons sit on the same roster but are
excluded, so a site with guns doesn't read as already at its ceiling. Globally,
`DUWS_zoneGroupCeiling` (130, `src/duws/server/server_var_init.sqf:505`) pauses all garrison
spawns and refills once every OPFOR group on the map (`DUWS_fnc_opforGroupCount`) reaches it —
slack for hardpoints and town garrisons, which raise their own groups outside any per-site cap but
still count against this wall.

## The refill pass

`DUWS_fnc_garrisonReservePass` (`src/duws/server/init_zones/fnc_garrison_reserve.sqf:547`) walks
every site on `DUWS_garrisonSites` that is held, has a non-empty pool, and has BLUFOR nearby;
sorts the candidates by player count present, most-crowded first; and spawns
`DUWS_fnc_garrisonReserveRefillOne` per site. That worker pops random fieldable tokens from the
pool and delivers them until the site's group count reaches its ceiling, the pool empties, or the
global throttle is hit. Infantry tokens now ride in trucks, batched — consecutive squads share one
until it's at least half full, then it's dispatched — rather than walking in on foot; a vehicle
token drives itself in, unbatched.

Two triggers fire the pass: a 5-minute heartbeat (`DUWS_fnc_garrisonReserveLoop`,
`DUWS_zoneReservePollPeriod = 300`) for the steady grind, and a debounced
(`DUWS_zoneReserveEventDebounce = 20`s) event on a deep dip — a site whose live groups fall below
`DUWS_zoneReinforceFrac` (0.5) of its ceiling pulls an immediate wave rather than waiting for the
beat, so reinforcement reads as waves, not one-in-one-out whack-a-mole.

A reserve counts as still-owed force for every measure of the site's strength until it either
arrives-and-dies or the site stows: `DUWS_fnc_garrisonReserveMen {key}` sums the men still in the
pool, and both the break test and the strength readouts add it to what's standing. Delivering a
wave moves men from pool to alive without changing that total; only a kill does.

## Placement: keeping a wave off the player's back

`DUWS_fnc_garrisonReservePos {center, radius}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf:36`) chooses where a wave stands up, in
priority order over a flat distance floor, so a player never watches a squad appear and never gets
flanked from their own approach direction:

1. **Opposite the player approach (non-negotiable).** The spawn bearing is `-bluDir`, where
   `bluDir` is the site-centre-to-player-centroid direction — reserves come from the far side and
   meet the advance head-on, never from behind it.
2. **Nudged toward the nearest other OPFOR zone (soft).** The bearing bends up to 50 degrees
   toward a neighbouring zone so a wave reads as coming from friendly ground, clamped so it can
   never fight the anti-flank rule.
3. **Preferably out of sight (best-effort).** A handful of candidate points along the bearing are
   tried with `BIS_fnc_findSafePos`; the one fewest players have line of sight to wins. Not a hard
   gate — a widened fallback runs if every candidate on the preferred arc is bad ground (most often
   a far side facing open water).

Distance is a flat floor, `DUWS_zoneReserveSpawnDist` (400 m,
`src/duws/server/server_var_init.sqf:515`), measured from the nearest player rather than scaled to
the site radius — a radius-relative distance would drop a wave a kilometre off a small island and
on top of the player at a large base.

**Line-of-sight cost.** `lineIntersectsSurfaces` is a raycast, expensive only when run per-frame
across many units. Here it runs at spawn time only — a handful of candidates times the players
present, once per wave every few minutes — so it's dozens of casts spread over time, not a
frame-budget item. Bounding the candidate count and accepting the best-seen point rather than
demanding a fully-hidden one keeps the cost constant and never blocks a spawn.

## Hunt posture

Reserves are ordered with a dedicated `"hunt"` case in
`src/duws/server/init_zones/fnc_apply_posture.sqf:219`: `AWARE` behaviour, `YELLOW` combat mode,
`FULL` speed, a `SAD` waypoint, then a cycle. Speed is deliberate — a reinforcement runs, it does
not patrol; the wave has to arrive as pressure, not a slow trickle. It applies unchanged to a
mounted group or aircraft, each hunting at its own pace.

The `SAD` target is the **site centre**, not the player's position: aiming at a player's
spawn-time location let a wave walk off the objective if the player withdrew before it arrived,
leaving the ground taken and the counterattack chasing nothing. A centre destination still crosses
the wave through the players on the way in, since it spawns on the far side.

Vehicle reserves under `"hunt"` are filtered to hulls that can fight infantry.
`DUWS_fnc_classGroundCapable` (`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf`) rejects a class
whose only armament is guided missiles or rockets, because the `SAD` waypoint lets a pure-ATGM carrier
or a missile-armed AA hull park at missile range and duel from spawn rather than close — reading as a
reinforcement idling. The role pool is re-rolled for a gun-armed variant first; the garrison reserve
(hunt branch of `DUWS_fnc_zoneSpawnOne`) then drops the slot if the pool offers only missile carriers,
and the protect-informant assault (`src/duws/server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf`)
falls back to a squad. Defensive garrison postures are unaffected — a dug-in AT or AA hull is fine
where it holds.

## The break test

`DUWS_fnc_garrisonBeaten {key}` (`src/duws/server/init_zones/fnc_garrison_reserve.sqf:17`) is the
one capture/clear line for both site kinds: live men plus reserve-owed men, worn to **a tenth of
full fighting potential** (`fullMen`, the ledger's denominator). A site with an unspent pool
cannot fall on an empty perimeter — the owed men hold `remaining` above the line until the waves
have spawned and been killed, so a player has to draw out and beat nine tenths of everything the
site was ever worth, not just what happened to be standing when they arrived.

- **Zone capture** (`src/duws/server/init_zones/fnc_zone_capture_ready.sqf:32`) additionally
  requires BLUFOR outnumber whatever OPFOR is still present in the trigger area — `garrisonBeaten`
  alone isn't enough, the player also has to hold the ground.
- **Town clear** fires on `garrisonBeaten` alone, checked on the poller tick
  (`src/duws/server/misc/fnc_civ_garrison.sqf:303`) rather than an `EmptyDetector`, so a town can
  no longer be cleared by OPFOR merely withdrawing. Clearing pays a reputation credit and a
  `REGROUPING` hold, drops the tier to I — not 0; ownership survives, only the purchase was beaten
  — and reseeds the garrison to a scratch `0.3` rather than clearing it outright.
