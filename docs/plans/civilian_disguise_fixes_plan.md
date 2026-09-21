# Civilian disguise fixes

The civilian disguise (`server/civilian/fnc_disguiseAsCivilian.sqf`) gets four rule changes and one
dead-code removal. Its core stays: no weapons, a civilian kit, and a break when an OPFOR unit stays
inside the alert radius (50–80 m) for a second check. The enemy disguise
([`enemy_disguise_plan.md`](enemy_disguise_plan.md)) depends on phase 1, which adds the shared hunted
test, and copies the cooldown pattern of phase 2. Paths are relative to `src/`.

| Rule | Now | After |
|---|---|---|
| Activation | cooldown, game mode, kit, vehicle | also refused while hunted, or with an OPFOR unit inside the alert radius |
| Cooldown | 300 s from activation | 300 s from cover blown |
| Enemy zones and hardpoints | no rule | cover breaks near a revealed OPFOR zone or hardpoint |
| OPFOR-held towns | cover breaks at reputation −10 or lower | no rule; an OPFOR-held town is safe ground |
| `DUWS_disguise_paused` | read, never set true | removed |

Phase 1 creates `docs/info/gameplay/disguise.md` with the civilian rules as they stand after it. No
disguise reference doc exists today. Each later phase updates that doc in the same change. New hint
text follows [`player_text_style_guide.md`](../info/gameplay/player_text_style_guide.md).

## Phase 1: activation gate

A new server helper, `server/disguise/fnc_disguise_hunted.sqf`, takes a player and returns true when a
living OPFOR unit within 300 m holds a `nearTargets` fix on that player with an age of 5 s or less. It
does not use `knowsAbout`, because that value is side-wide and decays over minutes, so it reads a
player as hunted long after contact ends. The 5 s gate matches the engine's re-fix cycle
([gotchas](../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)),
the same test as the rescue-hostage cordon
(`server/missions/mission_threads/rescue_hostage/fnc_rescue_hostage_mission.sqf:156-157`). The enemy
disguise calls this helper too, so it goes in a new `server/disguise/` folder, not in `civilian/`.
`server/server_fnc_init.sqf` compiles it next to `fnc_disguiseAsCivilian` (`:333`). Only the server
calls it, so it is not broadcast.

Activation adds two refusals after the cooldown check:

| Condition | New refusal key |
|---|---|
| `fnc_disguise_hunted` returns true | `STR_DUWS_T_DISGUISE_CANT_HUNTED` |
| A living OPFOR unit is inside the alert radius | `STR_DUWS_T_DISGUISE_CANT_ENEMY_NEAR` |

The alert radius (`50 + random 30`) is rolled at activation, before the gate, and stored on the
player for the monitor. Today the monitor rolls it (`:137-138`). The gate and the monitor must read
one value. If they read different values, the disguise can activate and then break on the next check,
which is the failure the comment at `:14-18` warns about.

## Phase 2: cooldown from cover blown

`_fnc_breakDisguise` and the `FiredMan` handler stamp `DUWS_disguise_blownAt` with `diag_tickTime`.
These are the only two break paths. Activation stops stamping, and the cooldown check reads
`DUWS_disguise_blownAt` against the same 300 s. Every break stamps, including a break that the player
causes, for example by picking up a weapon. The end of the monitor on death does not stamp, because
the enemy did not see through the disguise.

`DUWS_disguise_lastUse` is removed. Replace it with `DUWS_disguise_blownAt` in the cooldown sweep list
at `server/server_init.sqf:447`. The new stamp also counts from process start, so the sweep must also
clear it after a save resumes in a new Arma session.

## Phase 3: enemy zones and hardpoints

The monitor breaks cover, and activation refuses, when the player is at either of these places:

| Site | Test | Sources |
|---|---|---|
| OPFOR zone | inside the zone radius + 150 m | positions in `WARCOM_zones_controled_by_OPFOR`; radius from `zone_meta_array` (`[num, pos, size, …]`, `server/init_zones/fnc_createzone.sqf:30`); revealed flag from `zone_namePOS_pairs` (`[name, pos, revealed]`, `:25`) |
| OPFOR hardpoint | within 150 m | `DUWS_hardpoints` rows `[key, pos, type, side, zone, revealed, dir]` with side `"opfor"` (`server/init_zones/fnc_hardpoint_stream.sqf:447`) |

Match a zone across the three arrays by position, as `server/init_zones/fnc_zone_reveal.sqf:31` does.
The 150 m margin is a starting value, `DISGUISE_CIV_SITE_MARGIN` in `server/server_var_init.sqf`.
The new keys are `STR_DUWS_T_DISGUISE_BROKEN_SITE` and `STR_DUWS_T_DISGUISE_CANT_SITE`.

**Only revealed sites count.** A break near a hidden site tells the player that the site exists, and
hidden sites are what intel pays for
([`intel_system.md`](../info/gameplay/intel_system.md#what-is-hidden-depends-on-when-it-came-into-existence)).
When the garrison of a hidden site comes within 50–80 m, the alert-radius rule still breaks cover.

**Towns do not count.** An OPFOR-held town is in neither registry, so this test does not see it.

## Phase 4: OPFOR-held towns stop breaking cover

Delete the reputation check at `fnc_disguiseAsCivilian.sqf:232-234`. Delete the key
`STR_DUWS_T_DISGUISE_BROKEN_REP_TOWN` (`stringtable.xml:2671`) from every language.

Three places name the disguise as a consumer of the OPFOR reputation band. Update each one:

- The comment at `server/civilian/fnc_civ_garrison.sqf:15`.
- The comment at `server/vendors/fnc_vendor_buy.sqf:34`. The vendor refusal keeps its own −10 test;
  only the comment names the disguise.
- The "three consumers" sentence at `docs/info/gameplay/zones_and_civilians.md:360`. Count the
  consumers again: the disguise leaves the list, and the vendor refusal also reads the band.

## Phase 5: dead pause flag

`DUWS_disguise_paused` is read in the monitor loop (`:159`) and reset at activation (`:114`) and
teardown (`:245`). Nothing sets it true. Delete the read and both writes.

## Verification

Run `tests/run.sh` (lint and unit) and the sqf-vm parse check on each touched file. These phases add
no pure logic, so they add no unit cases.
