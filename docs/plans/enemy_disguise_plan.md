# Enemy disguise and the suspicion meter

Both disguises use one suspicion meter. OPFOR units ignore the player (`setCaptive`) until the meter
fills while an OPFOR unit spots the player. The civilian disguise moves onto the meter first and
keeps its own constraints: no weapons or NVG, civilian kit and vehicles, and faster detection near
enemy sites and bodies. The meter replaces only its two-check proximity break and its breaks on a
body or a throw that no enemy sees. The enemy disguise then adds a floor from mismatched kit, so a
badly matched kit breaks cover almost at once. The enemy disguise replaces the removed one, which
gave 120 s of total invisibility and a free uniform, and broke only on a shot, a gear change, or an
enemy within 10 m. Paths are relative to `src/duws/`.

The plan starts from the civilian disguise as [`disguise.md`](../info/gameplay/disguise.md)
describes it. Each phase below updates `disguise.md` in the same change.

## Rules

| Rule | Civilian | Enemy |
|---|---|---|
| Uniform | Civilian (config side 3), as today | An OPFOR uniform that the player looted, worn or carried |
| Vest, headgear, backpack | Civilian or empty, as today; anything else refuses or breaks | Any; each item that is not in the OPFOR kit raises the floor |
| Weapons, NVG | None, as today | Any; each item that is not in the OPFOR kit raises the floor |
| Vehicle | The civilian list only, as today | An OPFOR or civilian vehicle is fine; any other vehicle raises the floor |
| Floor | Always 0 | The sum of the mismatch penalties, capped at 95 |
| Rise by ground | Instant inside an OPFOR site, ×3 in the band outside it, ×0.25 elsewhere | ×1 everywhere |
| Rise near a body | ×4 while a dead body is within 20 m | ×2 |
| Game modes | Refused under `CIV_PRESENCE` `NONE`, `RAVAGE` and `WBK` | The same |
| Activation | Refused on cooldown, while hunted, while an OPFOR unit spots the player, while an OPFOR soldier is within `50 + random 30` m, at an OPFOR site, or while the enemy disguise is on | Refused on cooldown, while hunted, while an OPFOR unit spots the player, or while the civilian disguise is on |
| Duration | No limit | No limit |
| Check interval | 0.5 s | 0.5 s |
| Break | The meter reaches 100, or the player fires; in both cases only while an OPFOR unit spots the player | The same |
| Cooldown | 300 s from cover blown | 600 s from cover blown |
| Readout | A meter in the hint box, and one hint on the way into the band of an OPFOR site | A meter in the hint box |

## Suspicion model

Each disguised player has a meter from 0 to 100 on the server.

**Floor.** The civilian floor is always 0, because the civilian kit rules refuse or break on every
item that does not read civilian. The enemy floor is the sum of the penalties for mismatched items,
capped at 95. An empty slot adds nothing. The cap is below 100 so that the floor alone never breaks
cover: a break always needs a spotter. Weapons match by base weapon, resolved as in
`server/arsenal/fnc_arsenal_base_weapons.sqf`, so a looted rifle with a different optic still matches.

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
3. `[vehicle _unit, "VIEW", vehicle _player] checkVisibility [eyePos _unit, eyePos _player]` is 0.5
   or more, so terrain, walls, smoke and foliage block it. Both vehicles are ignored, because a ray
   from inside a hull hits that hull and reads 0.

The test is geometric, not `nearTargets`. A `nearTargets` fix refreshes on a cycle of about 5 s
([gotchas](../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)),
so at a 0.5 s tick the meter would keep rising for up to 5 s after the player breaks line of sight.
`checkVisibility` is the only visibility command that smoke blocks. `fnc_sightline_clear` and
`fnc_duws_posSeenBy` test only terrain, objects and foliage.

**Rise.** While at least one unit spots the player, the meter rises each second by the spotter sum,
times the ground rate, times the body multiplier:

- Spotter sum: `10 × 10 / max(d, 10)` for the nearest spotter at distance `d` (10 at 10 m, 5 at
  20 m, 2 at 50 m, 1 at 100 m), plus 25% of its own rate for each other spotter. A full sum would
  let a garrison of ten at 50 m break a full kit in 5 s, and the disguise exists to move among them.
- Body multiplier: while a dead body is within 20 m of the player, ×4 for a civilian and ×2 for the
  enemy disguise; otherwise ×1.

**Ground rate.** The enemy disguise rises at ×1 everywhere. The civilian rate depends on where the
player stands, measured with the rings of `fnc_disguise_atEnemySite`:

| Civilian ground | Rate |
|---|---|
| Inside an OPFOR zone's radius + `DISGUISE_CIV_SITE_MARGIN` (150 m), or within that margin of an OPFOR hardpoint | Instant: the first spotter breaks cover |
| In the `DISGUISE_CIV_SITE_WARN` (100 m) band outside that ring | ×3 |
| Anywhere else, including OPFOR-held towns | ×0.25 |

The rings do not test whether a site is revealed. A hidden site streams in live and visible, and a
player who comes near reveals it anyway.

**Decay.** While no unit spots the player, the meter falls 5 per second, down to the floor. A floor
that rises above the meter lifts the meter at once.

**Break.** Cover breaks when the meter reaches 100 while at least one unit spots the player.

| Disguise | Kit or ground | Spotters | Time to break |
|---|---|---|---|
| Civilian | Elsewhere | 1 at 50 m | 200 s |
| Civilian | Elsewhere | 4 at 50 m | 114 s |
| Civilian | Elsewhere | 1 at 10 m | 40 s |
| Civilian | Elsewhere, body within 20 m | 1 at 10 m | 10 s |
| Civilian | Band | 1 at 50 m | 17 s |
| Civilian | Inside a site | 1 at any range | Instant |
| Enemy | All OPFOR | 1 at 50 m | 50 s |
| Enemy | All OPFOR | 4 at 50 m | 29 s |
| Enemy | All OPFOR | 1 at 10 m | 10 s |
| Enemy | Wrong rifle and helmet | 1 at 20 m | 10 s |
| Enemy | Wrong rifle and helmet, body within 20 m | 1 at 20 m | 5 s |
| Enemy | Only the uniform matches | 1 at 50 m | 2.5 s |
| Enemy | Only the uniform matches | 1 at 10 m | 0.5 s |

All numbers are starting values.

**Firing.** `FiredMan` catches shots, throws and placed charges. A civilian carries no weapon, so for
a civilian this means throws and charges. When a unit spots the player at the shot, cover breaks at
once. Otherwise the shot stamps a time, and cover breaks at once if a unit spots the player in the
next 5 s. The window keeps the rule that only a spotting unit breaks cover, without letting a player
fire unseen and keep the disguise while the victims' squad turns and looks straight at the shooter.

**Other ends.** The civilian kit, weapon, NVG and vehicle rules stay as they are today: each one
breaks cover and stamps the cooldown, with no spotter needed. The enemy disguise ends without a
cooldown when the player wears a uniform that is not in the OPFOR set, because it is the player who
takes the disguise off. Both disguises end without a cooldown when the player dies.

## Phase 1: suspicion functions

Two pure functions in `server/disguise/`, pure in the same way as `shared/functions/fnc_stealth_coef.sqf`:

- `fnc_disguise_floor` takes the list of mismatched slots and returns the capped floor. It holds the
  penalty table. Only the enemy disguise calls it.
- `fnc_disguise_suspicion_step` takes the meter, the floor, the spotter distances, the rate
  multiplier and the time step, and returns the new meter. It holds the rise, decay and
  multi-spotter values. The monitor builds the multiplier from the ground rate and the body
  multiplier.

Add both to `tests/unit/functions.txt` and add cases to `tests/unit/cases.sqf`: each row of the
worked table except the instant break, which the monitor applies, and also the floor cap, decay that
stops at the floor, and a floor rise that lifts the meter. The spotting values (150 m, 60°, 0.5
visibility, 5 s fire window), the civilian ground rates (×3, ×0.25) and the body multipliers (×4,
×2) go in `server/server_var_init.sqf` as `DISGUISE_*`, next to `DISGUISE_CIV_SITE_MARGIN` (`:549`).

## Phase 2: shared monitor and the civilian disguise

`server/disguise/fnc_disguise_monitor.sqf` is the one server loop for both disguises. It takes the
player and the kind (`"civ"` or `"enemy"`). The kind picks the kit test, the floor, the ground rate,
the body multiplier, the cooldown variable and the break hints. Every 0.5 s it runs these steps:

1. End if the player is dead. Run the kit test of the kind: a civilian kit failure breaks with its
   own hint, as today; an enemy uniform that is not in the OPFOR set ends without a stamp.
2. Compute the floor: 0 for a civilian, `fnc_disguise_floor` for the enemy disguise.
3. For a civilian, show the band hint once on the way into the band of an OPFOR site, as today.
4. Find the spotters: OPFOR men and crews within 150 m (`nearEntities`), then the cone and
   `checkVisibility` tests.
5. Break if the player fired in the last 5 s and a unit spots the player.
6. Only when a unit spots the player: look for a dead body within 20 m, and for a civilian, find the
   ground rate. Break at once if a civilian is inside a site ring.
7. Step the meter. Break if it reaches 100 while a unit spots the player.
8. Send the meter to the client.

A break sets captive false at both ends, clears the disguise flag, stamps the cooldown variable of
the kind, removes the `FiredMan` handler, and shows one break hint for each cause (suspicion, site,
firing). The monitor runs on the server because the captive state and the stamp belong to the
server. Its cost for each disguised player every 0.5 s is one `nearEntities` query and one
`checkVisibility` call for each unit in the cone. One loop runs for each disguised player, as the
civilian monitor does today. A single loop over all players does the same work per tick and adds
bookkeeping and a shared fault, and it gains only a global cap on rays.

**The hint meter.** `client/disguise/fnc_disguise_meter.sqf` is compiled in `client/client_init.sqf`
next to `fnc_disguise_setCaptiveLocal` (`:423`), so the client has it before the server calls.

- The server sends `[meter, floor]` to the owner on each tick while the meter is above the floor, and
  once more when it reaches the floor.
- The client draws a label and a 20-segment bar with `hintSilent` structured text. The floor segments
  and the rise above them use different colours.
- At the floor, the sends stop and the box fades. `hint` has no duration
  ([gotchas](../info/architecture/arma_engine_gotchas.md#hint-takes-no-duration-so-a-longer-readout-must-be-re-issued)).
- For a civilian, one of the `STR_DUWS_T_DISGUISE_WARNING_1`–`_5` voice lines plays when the meter
  rises past 50. This keeps the spoken cue of today's first warning.

While the meter moves, it owns the hint box, and any other hint shows for 0.5 s at most. This is
accepted: when an enemy spots the player, the meter is what the player must read. The meter goes by
`remoteExec` to the owner, not by a public variable, which would reach every client twice a second.

**The civilian disguise.** In `server/civilian/fnc_disguiseAsCivilian.sqf`:

- The activation keeps its alert radius refusal (`fnc_disguise_enemyNear`, `50 + random 30` m). The
  spotting test joins the hunted refusal and shares its hint, `STR_DUWS_T_DISGUISE_CANT_HUNTED`
  ("The enemy has eyes on you."). The monitor no longer reads the radius, so the roll stays local to
  the activation.
- `fnc_disguise_atEnemySite` drops its revealed test.
- The `FiredMan` handler and the monitor (`:149-280`) are replaced by a call to the shared monitor
  with kind `"civ"`.
- The proximity warning state (`DUWS_disguise_warningActive`, `DUWS_disguise_warningPos`,
  `DUWS_disguise_alertDist`) goes. `DUWS_disguise_siteWarned` stays for the band hint.

Two strings lose their only use and are deleted: `STR_DUWS_T_DISGUISE_WARNING_HINT`, because the
meter now shows the rising suspicion, and `STR_DUWS_T_DISGUISE_BROKEN_CORPSE`, because a body no
longer breaks cover on its own. `STR_DUWS_T_DISGUISE_BROKEN_DISTANCE` becomes
`STR_DUWS_T_DISGUISE_BROKEN_SUSPICION`. The English text changes for
`STR_DUWS_T_DISGUISE_BROKEN_SITE` and `STR_DUWS_T_DISGUISE_CANT_SITE`, which must not say "known",
and for the panel description `STR_DUWS_T_DISGUISE_MENU_CIV_DESC`. The other languages catch up
later.

`disguise.md` gets a new section on the meter, a rewrite of "What breaks cover", and a rewrite of
"Enemy sites", which today counts revealed sites only.

## Phase 3: OPFOR kit sets

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

## Phase 4: enemy activation

`server/disguise/fnc_disguiseAsEnemy.sqf` is compiled and broadcast in `server/server_fnc_init.sqf`,
as `fnc_disguiseAsCivilian` is (`:335-336`).

Activation checks, in this order:

1. Cooldown: `DUWS_enemyDisguise_blownAt` less than 600 s ago. The hint gives the time left.
2. Game mode: `CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK`.
3. The civilian disguise is on (`DUWS_disguised`). The civilian activation gets the matching refusal
   while `DUWS_enemyDisguised` is true.
4. `fnc_disguise_hunted` returns true, or an OPFOR unit spots the player.
5. Uniform: the worn uniform is in the OPFOR set, or the player carries one. A carried uniform is
   swapped on. With neither, refuse.

Then set captive on the server and through `fnc_disguise_setCaptiveLocal`, set `DUWS_enemyDisguised`
(broadcast, for the panel), and start the shared monitor with kind `"enemy"`. At activation, one hint
gives the floor and names each mismatched item, so the player can fix the kit before moving in. Add
`DUWS_enemyDisguise_blownAt` to the cooldown sweep list at `server/server_init.sqf:447`.

**The uniform swap.** The engine does not let a player put on a uniform whose unit class excludes the
player's side (`modelSides[]`), so a player usually cannot wear a looted OPFOR uniform by hand.
`setUnitLoadout` ignores that lock; the removed version relied on it. The swap puts the carried uniform
in the uniform slot with the old uniform's contents, and puts the old uniform in the container that the
new one came from. Nothing is lost and nothing is created. Log this trap in
[`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) in the same change.

## Phase 5: panel and strings

Put the enemy card back in `shared/includes/disguise_menu.hpp`: frame idc 8003, description 8104,
Activate 8202, all free since the removal. Lay the panel out for two cards again; git history holds the
earlier two-card layout. In `client/dialog/fnc_disguise_menu.sqf`, the status row gains an Enemy state
tinted red, the enemy colour of SUB-NET
([`player_text_style_guide.md`](../info/gameplay/player_text_style_guide.md)). The enemy card greys
out under `NONE`, `RAVAGE` and `WBK`, as the civilian card does. The server checks again on activation.

The enemy disguise reuses the civilian keys where the text fits both, such as the cooldown, hunted
and suspicion lines. New keys use the `STR_DUWS_T_ENEMY_DISGUISE_*` prefix, with English text only.

## Verification

Run `tests/run.sh` (lint and unit) and the sqf-vm parse check on each touched file. The phase 1 cases
cover the suspicion model. The server paths in phases 2 to 4 cannot run in sqf-vm.
