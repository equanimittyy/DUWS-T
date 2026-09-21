# Enemy disguise

The player wears a looted OPFOR uniform and keeps any weapons. OPFOR units ignore the player
(`setCaptive`) until a suspicion meter fills while an OPFOR unit spots the player. The quality of the
kit sets the floor of the meter, so a badly matched kit breaks cover almost at once. This replaces the
removed enemy disguise, which gave 120 s of total invisibility and a free uniform, and broke only on a
shot, a gear change, or an enemy within 10 m. Paths are relative to `src/`.

The plan depends on [`civilian_disguise_fixes_plan.md`](civilian_disguise_fixes_plan.md): phase 1
supplies `fnc_disguise_hunted` and `docs/info/gameplay/disguise.md`, and phase 2 sets the
cooldown-from-blown pattern. Each phase below updates `disguise.md` in the same change.

## Rules

| Rule | Value |
|---|---|
| Uniform | Required: an OPFOR uniform that the player looted, worn or carried |
| Weapons, vest, headgear, backpack, NVG | Any; each item that is not in the OPFOR kit raises the floor |
| Vehicle | An OPFOR or civilian vehicle is fine; any other vehicle raises the floor |
| Game modes | Refused under `CIV_PRESENCE` `NONE`, `RAVAGE` and `WBK`, as for the civilian disguise |
| Activation | Refused on cooldown, while hunted, while an OPFOR unit spots the player, or while the civilian disguise is on |
| Duration | No limit |
| Check interval | 0.5 s |
| Break | The meter reaches 100, or the player fires; in both cases only while an OPFOR unit spots the player |
| Cooldown | 600 s from cover blown |
| Readout | A meter in the hint box |

## Suspicion model

Each disguised player has a meter from 0 to 100 on the server.

**Floor.** The floor is the sum of the penalties for mismatched items, capped at 95. An empty slot adds
nothing. The cap is below 100 so that the floor alone never breaks cover: a break always needs a
spotter. Weapons match by base weapon, resolved as in `server/arsenal/fnc_arsenal_base_weapons.sqf`,
so a looted rifle with a different optic still matches.

| Item | Penalty |
|---|---|
| Primary weapon | 30 |
| Vehicle | 30 |
| Launcher | 20 |
| Vest | 20 |
| Headgear | 20 |
| NVG | 15 |
| Handgun | 10 |
| Backpack | 10 |

**Spotting.** An OPFOR unit spots the player when all three of these are true:

1. It is alive and within 150 m. This includes the crew of vehicles and static weapons.
2. The player is within 60° of its `eyeDirection`.
3. `checkVisibility` from its `eyePos` to the player's `eyePos` is 0.5 or more, so terrain, walls,
   smoke and foliage block it.

The test is geometric, not `nearTargets`. A `nearTargets` fix refreshes on a cycle of about 5 s
([gotchas](../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)),
so at a 0.5 s tick the meter would keep rising for up to 5 s after the player breaks line of sight.

**Rise.** While at least one unit spots the player, the meter rises each second by:

- `10 × 10 / max(d, 10)` for the nearest spotter at distance `d`: 10 at 10 m, 5 at 20 m, 2 at 50 m,
  1 at 100 m.
- 25% of its own rate for each other spotter. A full sum would let a garrison of ten at 50 m break a
  full kit in 5 s, and the disguise exists to move among them.
- Double the total when a dead body is within 20 m of the player.

**Decay.** While no unit spots the player, the meter falls 5 per second, down to the floor. A floor
that rises above the meter lifts the meter at once.

**Break.** Cover breaks when the meter reaches 100 while at least one unit spots the player.

| Kit | Floor | Spotters | Time to break |
|---|---|---|---|
| All OPFOR | 0 | 1 at 50 m | 50 s |
| All OPFOR | 0 | 4 at 50 m | 29 s |
| All OPFOR | 0 | 1 at 10 m | 10 s |
| Wrong rifle and helmet | 50 | 1 at 20 m | 10 s |
| Wrong rifle and helmet, body within 20 m | 50 | 1 at 20 m | 5 s |
| Only the uniform matches | 95 | 1 at 50 m | 2.5 s |
| Only the uniform matches | 95 | 1 at 10 m | 0.5 s |

All numbers are starting values.

**Firing.** `FiredMan` catches shots, throws and placed charges. When a unit spots the player at the
shot, cover breaks at once. Otherwise the shot stamps a time, and cover breaks at once if a unit spots
the player in the next 5 s. The window keeps the rule that only a spotting unit breaks cover, without
letting a player fire unseen and keep the disguise while the victims' squad turns and looks straight
at the shooter.

**Other ends.** The disguise ends without a cooldown when the player dies or wears a uniform that is
not in the OPFOR set. Neither is cover blown.

## Phase 1: OPFOR kit sets

`server/disguise/fnc_scanEnemyGear.sqf` builds server-only sets of OPFOR uniforms, vests, headgear,
backpacks, NVGs, base weapons and vehicle classes, once the OPFOR faction has resolved. It runs next
to the civilian scan at `server/server_init.sqf:435`.

- **Infantry.** For every class in every OPFOR infantry role pool (`DUWS_factionPool_<role>`, or the
  role global when the role has no pool), spawn one temporary unit, read its worn kit, and delete it.
  `server/civilian/fnc_scanCivilianGear.sqf` reads the civilian crowd the same way. A spawned unit
  shows what the engine actually equips, including gear from init scripts that a config read of
  `linkedItems[]` misses. `shared/faction_lib/fnc_faction_schema.sqf` gives the kind of each role.
- **Vehicles.** Every class in every OPFOR vehicle role pool. A civilian vehicle passes by config
  side 3, as the civilian uniform check does.

The sets come from the roster, not from config side 0. Auto-detection can field a faction as OPFOR
whose units are side 2 (INDEP) in config, and a side test would reject its uniforms. The removed
version scanned every live EAST unit instead. That needed a permanent `EntityCreated` handler, sent a
broadcast for every new class, and knew nothing until units spawned.

A mod that randomises gear on each spawn shows the scan only one roll per class, so its other rolls
read as mismatched. If play shows false penalties from this, add the live spawns to the sets.

## Phase 2: suspicion functions

Two pure functions in `server/disguise/`, pure in the same way as `shared/functions/fnc_stealth_coef.sqf`:

- `fnc_disguise_floor` takes the list of mismatched slots and returns the capped floor. It holds the
  penalty table.
- `fnc_disguise_suspicion_step` takes the meter, the floor, the spotter distances, whether a body is
  near, and the time step, and returns the new meter. It holds the rise, decay, multi-spotter and body
  values.

Add both to `tests/unit/functions.txt` and add cases to `tests/unit/cases.sqf`: each row of the
worked table, the floor cap, decay that stops at the floor, and a floor rise that lifts the meter. The
spotting values (150 m, 60°, 0.5 visibility, 5 s fire window) go in `server/server_var_init.sqf` as
`DISGUISE_ENEMY_*`.

## Phase 3: activation and monitor

`server/disguise/fnc_disguiseAsEnemy.sqf` is compiled and broadcast in `server/server_fnc_init.sqf`,
as `fnc_disguiseAsCivilian` is (`:333-334`).

Activation checks, in this order:

1. Cooldown: `DUWS_enemyDisguise_blownAt` less than 600 s ago. The hint gives the time left.
2. Game mode: `CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK`.
3. The civilian disguise is on (`DUWS_disguised`). The civilian activation gets the matching refusal
   while `DUWS_enemyDisguised` is true.
4. `fnc_disguise_hunted` returns true, or an OPFOR unit spots the player.
5. Uniform: the worn uniform is in the OPFOR set, or the player carries one. A carried uniform is
   swapped on. With neither, refuse.

Then set captive on the server and through `fnc_disguise_setCaptiveLocal`, set `DUWS_enemyDisguised`
(broadcast, for the panel), show the activation readout (phase 4), and start the monitor.

**The uniform swap.** The engine does not let a player put on a uniform whose unit class excludes the
player's side (`modelSides[]`), so a player usually cannot wear a looted OPFOR uniform by hand.
`setUnitLoadout` ignores that lock; the removed version relied on it. The swap puts the carried uniform
in the uniform slot with the old uniform's contents, and puts the old uniform in the container that the
new one came from. Nothing is lost and nothing is created. Log this trap in
[`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) in the same change.

**The monitor.** A server loop runs every 0.5 s for each disguised player:

1. End, without a stamp, if the player is dead or the uniform is not in the OPFOR set.
2. Compute the floor from the current kit and vehicle.
3. Find the spotters: OPFOR men and crews within 150 m (`nearEntities`), then the cone and
   `checkVisibility` tests.
4. Break if the player fired in the last 5 s and a unit spots the player.
5. Only when a unit spots the player, look for a dead body within 20 m.
6. Step the meter. Break if it reaches 100 while a unit spots the player.
7. Send the meter to the client (phase 4).

A break sets captive false at both ends, clears `DUWS_enemyDisguised`, stamps
`DUWS_enemyDisguise_blownAt`, removes the `FiredMan` handler, and shows one break hint per cause
(suspicion, firing). Add `DUWS_enemyDisguise_blownAt` to the cooldown sweep list at
`server/server_init.sqf:447`.

The monitor runs on the server because the captive state and the stamp belong to the server, as in
the civilian disguise. Its cost for each disguised player every 0.5 s is one `nearEntities` query and
one `checkVisibility` call for each unit in the cone.

## Phase 4: hint meter

`client/disguise/fnc_disguise_meter.sqf` is compiled in `client/client_init.sqf` next to
`fnc_disguise_setCaptiveLocal` (`:416`), so the client has it before the server calls.

- The server sends `[meter, floor]` to the owner on each tick while the meter is above the floor, and
  once more when it reaches the floor.
- The client draws a label and a 20-segment bar with `hintSilent` structured text. The floor segments
  and the rise above them use different colours.
- At the floor, the sends stop and the box fades. `hint` has no duration
  ([gotchas](../info/architecture/arma_engine_gotchas.md#hint-takes-no-duration-so-a-longer-readout-must-be-re-issued)).
- At activation, one hint gives the floor and names each mismatched item, so the player can fix the
  kit before moving in.

While the meter moves, it owns the hint box, and any other hint shows for 0.5 s at most. This is
accepted: when an enemy spots the player, the meter is what the player must read. The meter goes by
`remoteExec` to the owner, not by a public variable, which would reach every client twice a second.

## Phase 5: panel and strings

Put the enemy card back in `shared/includes/disguise_menu.hpp`: frame idc 8003, description 8104,
Activate 8202, all free since the removal. Lay the panel out for two cards again; git history holds the
earlier two-card layout. In `client/dialog/fnc_disguise_menu.sqf`, the status row gains an Enemy state
tinted red, the enemy colour of SUB-NET
([`player_text_style_guide.md`](../info/gameplay/player_text_style_guide.md)). The enemy card greys
out under `NONE`, `RAVAGE` and `WBK`, as the civilian card does. The server checks again on activation.

New keys use the `STR_DUWS_T_ENEMY_DISGUISE_*` prefix, with English text only.

## Verification

Run `tests/run.sh` (lint and unit) and the sqf-vm parse check on each touched file. The phase 2 cases
cover the suspicion model. The server paths in phases 1 and 3 cannot run in sqf-vm.
