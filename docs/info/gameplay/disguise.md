The civilian disguise makes OPFOR ignore the player while the player looks like a civilian. The server
sets the player captive, which is the only reliable "do not shoot" switch in the engine, and a
monitor sets it back when cover breaks. The player starts it from the disguise panel
(`client/dialog/fnc_disguise_menu.sqf`). The server runs all of it in
`server/civilian/fnc_disguiseAsCivilian.sqf`. Paths are relative to `src/duws/`.

## Activation

The server refuses activation on the first check that fails, in this order:

| Check | Refusal key |
|---|---|
| Cover was blown less than 300 s ago | `STR_DUWS_T_DISGUISE_COOLDOWN_FMT` |
| An OPFOR unit hunts the player (`fnc_disguise_hunted`) | `STR_DUWS_T_DISGUISE_CANT_HUNTED` |
| A living OPFOR soldier is inside the alert radius | `STR_DUWS_T_DISGUISE_CANT_ENEMY_NEAR` |
| The player is at a revealed OPFOR site | `STR_DUWS_T_DISGUISE_CANT_SITE` |
| The player is in a vehicle that is not on the civilian list | `STR_DUWS_T_DISGUISE_CANT_VEHICLE` |
| `CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK` | `STR_DUWS_T_DISGUISE_CANT_NOCIV`, `STR_DUWS_T_DISGUISE_CANT_ZOMBIE` |
| The player carries a weapon or wears vanilla NVGs | `STR_DUWS_T_DISGUISE_CANT_WEAPON`, `STR_DUWS_T_DISGUISE_CANT_NVG` |
| The uniform, vest, headgear or backpack is not civilian | `STR_DUWS_T_DISGUISE_CANT_*` for each slot |

The alert radius is `50 + random 30` m. Activation rolls it once and stores it on the player as
`DUWS_disguise_alertDist`, and the monitor reads that value. If the gate and the monitor rolled
separately, a disguise could pass the gate and then break on the first check.

A uniform is civilian when its linked unit class has config side 3, so modded civilian clothes pass.
A vest, headgear or backpack has no side in config. It passes when the slot is empty, when
`fnc_scanCivilianGear` saw a local civilian wear it, or when it is on the whitelist in
`fnc_disguiseAsCivilian.sqf`.

## The hunted test

`server/disguise/fnc_disguise_hunted.sqf` returns true when a living OPFOR unit within 300 m, crews
included, has a `nearTargets` fix on the player that is 5 s old or less. It does not read
`knowsAbout`, because that value is side-wide and decays over minutes, so it reads a player as hunted
long after contact ends. The gate cannot be shorter than 5 s, because the engine re-fixes a watched
target only every few seconds
([gotchas](../architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)).
The test is in `server/disguise/` because the enemy disguise
([plan](../../plans/enemy_disguise_plan.md)) will call it too.

## What breaks cover

A `FiredMan` handler breaks cover at once on a shot, a throw or a placed charge. The monitor checks
the rest every 5 s:

| Break | Test |
|---|---|
| Weapon or NVGs | the same test as activation |
| Kit | the uniform, vest, headgear or backpack stops reading civilian |
| Body | a dead man within 20 m |
| Enemy site | a revealed OPFOR site, as below |
| Enemy near | an OPFOR soldier inside the alert radius on one check, and still inside it on the next check while the player has moved less than 1.5 × the radius from where the warning started |
| Vehicle | the player gets into a vehicle that is not on the civilian list |

The first enemy-near check only warns: an OPFOR voice line and a hint. The player keeps cover by
moving away before the next check.

### Enemy sites

`fnc_disguise_atEnemySite` reads two registries:

| Site | Test |
|---|---|
| OPFOR zone | inside the zone radius + `DISGUISE_CIV_SITE_MARGIN` (150 m). The zone must be in `WARCOM_zones_controled_by_OPFOR` and revealed in `zone_namePOS_pairs`. The radius comes from `zone_meta_array`. Rows match by position. |
| OPFOR hardpoint | within `DISGUISE_CIV_SITE_MARGIN` of a `DUWS_hardpoints` row with side `"opfor"` and the revealed flag set |

Only revealed sites count. A break near a hidden site would tell the player that the site exists, and
hidden sites are what intel pays for
([`intel_system.md`](intel_system.md#what-is-hidden-depends-on-when-it-came-into-existence)). When
the garrison of a hidden site comes inside the alert radius, the enemy-near rule still breaks cover.

An OPFOR-held town is in neither registry, so it is safe ground. Town reputation does not affect the
disguise.

## Cooldown

The cooldown is 300 s from cover blown, not from activation. Every break stamps
`DUWS_disguise_blownAt` with `diag_tickTime`, including a break that the player causes, for example by
picking up a weapon. Death ends the disguise without a stamp, because the enemy did not see through
it.

`diag_tickTime` counts from the start of the Arma process. When a save resumes in a new Arma session,
every stamp is in the future, so the cooldown sweep in `server/server_init.sqf` clears it.
