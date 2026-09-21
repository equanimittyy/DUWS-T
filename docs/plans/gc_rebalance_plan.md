# GC rebalance

The map cleanup (`server/misc/fnc_repetitive_cleanup.sqf`) runs a pass every 10 s. Each pass makes 11
`allMissionObjects` calls, a crew check on every vehicle, and a flag check on every unit and vehicle.
This plan cuts the pass rate to one every 30 s, sets the default litter lifetime to 5 min, and makes
mission leftovers, hardpoint defenders, released props and the defused IED pile use that default.
Paths are relative to `src/`.

Per-object deadlines stay. The cost is in the pass rate, not in the deadlines: a deadline is one
`getVariable` for each object on each pass. The explicit lifetimes that set an event's duration or a
short delete order stay, except the sniper event, which drops to 1200 s.

## Values

| Value | Now | Plan |
|---|---|---|
| Pass interval | 10 s | 30 s |
| Census log line | Every 30th pass (5 min) | Every 10th pass (5 min) |
| Default lifetime (`DUWS_CleanupLifetime`) | 900 s | 300 s |
| Hardpoint defenders, side-mission and civ-mission leftovers | 300 s, fixed | Default lifetime |
| Released composition props | 300 s, fixed | Default lifetime |
| Defused IED pile | 1800 s | Default lifetime |
| Enemy sniper event | 1800 s | 1200 s |

These lifetimes do not change:

| Lifetime | What |
|---|---|
| 30 s | Reserve and protect_civ delivery trucks; they now go at 30–60 s |
| 300 s + 90 s | Mob event crowd |
| 1200 s | Enemy car event, recon patrol event, IED junk pile |

## Phase 1: pass interval

- `fnc_repetitive_cleanup.sqf:71`: change `time + 10` to `time + 30`.
- The comment at `:67-70` says a forced sweep would otherwise wait "ten seconds". Change it to thirty
  seconds.
- Change `LOG_EVERY` (`:27`) from 30 to 10, so the census line stays 5 min apart. Update
  `docs/info/architecture/performance.md:187` ("every 30th pass") to match.

## Phase 2: default lifetime param

- `shared/includes/params_modern.hpp:73-78`: change `default` from 900 to 300, and change the title
  from "Garbage Collection" to "Default Garbage Lifetime". The comment at `:67-71` names the new users
  of the value: mission leftovers, hardpoint defenders and released props.
- Change the fallback from 900 to 300 in `server/server_init.sqf:220` and
  `client/misc/fnc_duws_config.sqf:104`. The config-panel label at `fnc_duws_config.sqf:103` takes the
  new title.
- The class name `DUWS_CleanupLifetime` stays. It already names a lifetime, and
  [`campaign_persistence_plan.md`](campaign_persistence_plan.md) refers to it.
- The floor `_lifetime max 300` (`fnc_repetitive_cleanup.sqf:32`) stays, because 300 is the lowest
  option.
- Fix the comments that name the old values:
  - `server/civilian/fnc_civ_loopRoute.sqf:4-5`: "~15 min" becomes "5 min by default".
  - `server/server_var_init.sqf:195`: "a 30 min deadline" becomes "the lifetime".
  - `server/misc/fnc_composition_stream_init.sqf:186`: "does not wait 30 min" becomes "does not wait
    out the lifetime".

The 5 min default has two gameplay effects:

- A body more than 300 m from every player goes after 5 min, not 15. The search window for a distant
  kill is shorter.
- The ambient entities on the default lifetime live 5 min out of player range, not 15: the event
  helicopter, the civilian event car, the car bomb, the convoy, the stranded civilian, driving civilian
  traffic, and a civ-mission giver.

## Phase 3: living leftovers use the default

Delete the `DUWS_binAt` write and keep `DUWS_binMe`. The sweep's flagged-entity pass stamps
`time + _lifetime` when it first sees a flagged unit that has no deadline.

- `server/init_zones/fnc_hardpoint_stream.sqf:197`: the living defenders of a cleared hardpoint.
- `server/missions/fnc_mission_cleanup.sqf:36`: the claimed units of a finished side mission. The
  comment at `:27-28` says `time + 300` matches the released composition. After phase 4 both use the
  default lifetime, so the comment says that instead.
- `server/civ_missions/fnc_civ_mission_finish.sqf:43`: the men of a finished civ mission. It writes
  the same flag pair as `fnc_mission_cleanup`, so it changes with it.
- `docs/info/gameplay/hardpoints.md:230` and `docs/info/gameplay/side_mission_catalogue.md:532-533`
  name the `DUWS_binMe` / `DUWS_binAt` pair. Remove `DUWS_binAt`. The line references in
  `hardpoints.md:230-233` (`:192-193`, `:197`) are already stale; fix them in the same change.

## Phase 4: released props use the default

- `fnc_duws_disposeAfter` (`server/misc/fnc_composition_stream_init.sqf:12-13`): `_ttd` has no
  default. An omitted `_ttd` stays nil in the `DUWS_disposables` entry.
- The drain (`fnc_repetitive_cleanup.sqf:142`) reads `_x params ["_obj", ["_ttd", _lifetime]]`.
  `params` uses the default for a nil element, so an entry with no seconds gets the default lifetime.
- `fnc_duws_release` (`fnc_composition_stream_init.sqf:56-57`, `:65`) drops its `_ttd` param and
  passes only the object.
- The defused IED pile (`server/events/fnc_random_event_ied_defuse.sqf:23`) passes no seconds, so it
  moves from the old 1800 s default of `fnc_duws_disposeAfter` to the default lifetime. The call does
  not change.
- `server/server_var_init.sqf:171`: the comment says "[object, seconds] pairs". It becomes
  "[object, seconds] entries, where nil seconds means the default lifetime".

## Phase 5: sniper event lifetime

`server/events/fnc_random_event_enemy_sniper.sqf:17`: change `LIFETIME` from 1800 to 1200, the same
as the enemy car and recon patrol events.

## Verification

- Run `tests/run.sh` (lint and unit) and the sqf-vm parse check on each touched SQF file. The sweep is
  server code and cannot run in sqf-vm.
- `grep -rn 'DUWS_binAt", time + 300' src` returns nothing.
- In the RPT, the `[CLEANUP] litter census` line comes about every 5 min.
