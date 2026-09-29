The player has two disguises. The civilian disguise makes OPFOR and bandits ignore the player while
the player looks like a civilian. The enemy disguise makes OPFOR ignore the player while the player
wears a looted OPFOR uniform, until a bandit sees the player ([Bandits](#bandits)). Both set the
player captive on the server, which is the only reliable "do not shoot" switch in the engine, and one
monitor sets it back when cover breaks. The player starts either one from the disguise panel
(`client/dialog/fnc_disguise_menu.sqf`). Paths are relative to `src/duws/`.

| Part | File |
|---|---|
| Civilian activation and its kit rules | `server/civilian/fnc_disguiseAsCivilian.sqf` |
| Enemy activation | `server/disguise/fnc_disguiseAsEnemy.sqf` |
| The monitor, for both | `server/disguise/fnc_disguise_monitor.sqf` |
| Spotting, floor and meter step | `server/disguise/fnc_disguise_spotters.sqf`, `fnc_disguise_floor.sqf`, `fnc_disguise_suspicion_step.sqf` |
| OPFOR kit | `server/disguise/fnc_scanEnemyGear.sqf`, `fnc_disguise_enemyMismatch.sqf` |
| Client side | `client/disguise/fnc_disguise_meter.sqf` |

The tuning values are `DISGUISE_*` in `server/server_var_init.sqf`.

## Activation

Each activation refuses on the first check that fails, in this order.

| Civilian check | Refusal key |
|---|---|
| Cover was blown less than 300 s ago | `STR_DUWS_T_DISGUISE_COOLDOWN_FMT` |
| A disguise monitor still runs for the player | `STR_DUWS_T_DISGUISE_CANT_OTHER` |
| An OPFOR unit or a bandit hunts the player (`fnc_disguise_hunted`) or spots the player | `STR_DUWS_T_DISGUISE_CANT_HUNTED` |
| A living OPFOR soldier or bandit is within `50 + random 30` m | `STR_DUWS_T_DISGUISE_CANT_ENEMY_NEAR` |
| The player is within a site ring (below) | `STR_DUWS_T_DISGUISE_CANT_SITE` |
| `CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK` | `STR_DUWS_T_DISGUISE_CANT_NOCIV`, `STR_DUWS_T_DISGUISE_CANT_ZOMBIE` |
| The kit fails a civilian rule | `STR_DUWS_T_DISGUISE_CANT_<fault>` |

| Enemy check | Refusal key |
|---|---|
| Cover was blown less than 600 s ago | `STR_DUWS_T_DISGUISE_COOLDOWN_FMT` |
| `CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK` | `STR_DUWS_T_DISGUISE_CANT_ZOMBIE` |
| A disguise monitor still runs for the player | `STR_DUWS_T_DISGUISE_CANT_OTHER` |
| An OPFOR unit or a bandit hunts or spots the player | `STR_DUWS_T_DISGUISE_CANT_HUNTED` |
| The OPFOR kit scan has not finished | `STR_DUWS_T_ENEMY_DISGUISE_CANT_NOKIT` |
| The player does not wear an OPFOR uniform | `STR_DUWS_T_ENEMY_DISGUISE_CANT_UNIFORM` |

The enemy activation hint gives the suspicion floor, names each item that OPFOR does not issue, and
names each empty slot that counts, so the player can fix the kit before moving in.

### The civilian kit rules

`fnc_disguise_civFault` returns the first rule that fails, as the suffix of its key: `WEAPON`, `NVG`
(vanilla NVGs), `NAKED`, `UNIFORM`, `VEST`, `HEADGEAR`, `BACKPACK` or `VEHICLE`. The activation
refuses with `CANT_<fault>` and the monitor breaks with `BROKEN_<fault>`. One function serves both,
so a kit cannot pass the gate and then break on the first tick.

A uniform is civilian when its linked unit class has config side 3, so modded civilian clothes pass.
A vest, headgear or backpack has no side in config. It passes when the slot is empty, when
`fnc_scanCivilianGear` saw a local civilian wear it, or when it is on the whitelist in
`fnc_disguiseAsCivilian.sqf`. A vehicle passes when it is on `DUWS_disguise_civVehicles`.

## The hunted test

`server/disguise/fnc_disguise_hunted.sqf` returns true when a living unit of the given sides within
300 m, crews included, has a `nearTargets` fix on the player that is 5 s old or less. It does not read
`knowsAbout`, because that value is side-wide and decays over minutes, so it reads a player as hunted
long after contact ends. The gate cannot be shorter than 5 s, because the engine re-fixes a watched
target only every few seconds
([gotchas](../architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)).
Both activations call it with OPFOR and bandits; the monitor does not, because a 5 s fix is too slow
for a 0.5 s meter.

## OPCOM sensing

OPCOM does not record a disguised player in its belief store. The sighting sweep, recon and the
interceptor's look skip each man for whom `server/disguise/fnc_disguise_active.sqf` returns true. It
reads the `DUWS_disguised` and `DUWS_enemyDisguised` flags, not the captive state, because the inbound
High Command aircraft and some mission units are also captive, and OPCOM must still see them. A vehicle
is skipped only when every man aboard is disguised. The OP post burst skips the player because it
filters on unit `side`, and a captive unit reads civilian
([gotchas](../architecture/arma_engine_gotchas.md#a-captive-units-side-reads-civilian-but-its-side-group-does-not)).
When cover breaks, the flags clear and the next sweep records the player again.

A squad with a disguised member is still recorded through its undisguised members. The record takes
the position of the leader, or of the first undisguised member while the leader is disguised, and its
strength leaves the disguised members out (`DUWS_fnc_opcom_sightLead` and `DUWS_fnc_opcom_sightStr`,
`server/warcom/opcom/belief/fnc_opcom_force.sqf`). A record made before the player put on the disguise
stays and decays like that of any group that nobody sees.

## The suspicion meter

Each disguised player has a meter from 0 to 100 on the server. The monitor updates it every 0.5 s.

**Spotting.** The observers are OPFOR and bandits for the civilian disguise, and OPFOR for the enemy
disguise. An observer spots the player when all three of these are true
(`fnc_disguise_spotters`):

1. It is alive and within `DISGUISE_SPOT_RANGE` (200 m). Crews of vehicles and static weapons count.
2. The player is within `DISGUISE_SPOT_CONE` (85°) of its `eyeDirection`.
3. `checkVisibility` from its eye to the player's eye is `DISGUISE_SPOT_VIS` (0.5) or more, so
   terrain, walls, smoke and foliage block it. Both vehicles are ignored, because a ray from inside a
   hull hits that hull.

**Rise.** While a unit spots the player, the meter rises each second by the spotter sum, times the
ground rate, times the body multiplier, times the stance multiplier. The spotter sum is
`100 / max(d, 10)` for the nearest spotter at `d` m, plus 25% of its own rate for each other spotter.
The body multiplier applies while a dead body is within 20 m: `DISGUISE_BODY_MULT` (×4) for both
disguises. The stance multiplier is `DISGUISE_CROUCH_MULT` (×1.1) while the player crouches and
`DISGUISE_PRONE_MULT` (×1.3) while the player is prone, for both disguises, because a civilian or a
soldier at ease does not creep.

| Civilian ground | Rate |
|---|---|
| Within a site ring | The first spotter breaks cover at once |
| In the band outside a ring | `DISGUISE_CIV_RATE_BAND` (×6) |
| Anywhere else, including OPFOR-held towns | `DISGUISE_CIV_RATE_OPEN` (×1) |

The enemy disguise rises at `DISGUISE_ENEMY_RATE` (×0.5) everywhere.

**Floor.** The civilian floor is always 0, because the kit rules break on every item that does not
read civilian. The enemy floor is the sum of a penalty per slot: primary weapon 30, vehicle 30,
launcher 20, vest 20, headgear 20, NVG 15, handgun 10, backpack 10. An item that OPFOR does not issue
costs twice its slot's penalty. An empty slot costs the penalty once, but only when every OPFOR class
fills that slot, so a rifleman with no launcher pays nothing. An empty vest or headgear slot always
costs, because a soldier without them reads wrong even where a pilot or an officer goes without. Being
on foot is never an empty vehicle slot. The floor is capped at 95, so the floor alone never breaks
cover.

**Decay.** While no unit spots the player, the meter holds for `DISGUISE_DECAY_DELAY` (5 s) after the
last spotter loses sight. Then it falls 5 per second, down to the floor. While a living observer is
within `DISGUISE_DECAY_NEAR_RANGE` (50 m), crews included, it falls at `DISGUISE_DECAY_NEAR_SCALE`
(a third of) that rate, whether or not that unit can see the player.

| Disguise | Kit or ground | Spotters | Time to break |
|---|---|---|---|
| Civilian | Elsewhere | 1 at 50 m | 50 s |
| Civilian | Elsewhere | 1 at 200 m | 200 s |
| Civilian | Elsewhere, body within 20 m | 1 at 10 m | 2.5 s |
| Civilian | Band | 1 at 50 m | 8.5 s |
| Enemy | All OPFOR | 1 at 50 m | 100 s |
| Enemy | All OPFOR | 4 at 50 m | 57.5 s |
| Enemy | No rifle and no helmet | 1 at 20 m | 20 s |
| Enemy | Only the uniform matches | 1 at 10 m | 1 s |

`tests/unit/cases.sqf` checks these rows and the rest of the model.

## What breaks cover

The monitor checks these every 0.5 s. Each break stamps the cooldown.

| Break | Disguise | Test |
|---|---|---|
| Suspicion | Both | the meter reaches 100 while a unit spots the player |
| Site | Civilian | a unit spots the player within a site ring |
| Attack | Both | a unit spots the player at a shot, throw or placed charge, or within `DISGUISE_FIRE_WINDOW` (5 s) after it |
| Bandit | Enemy | a bandit spots the player |
| Kit | Civilian | `fnc_disguise_civFault` returns a fault |

The enemy disguise ends without a stamp when the player wears a uniform that is not in the OPFOR
kit, because the player took the disguise off. Death ends either disguise without a stamp.

The player can end either disguise without a stamp from the panel, where the active card's button
reads Deactivate (`server/disguise/fnc_disguise_cancel.sqf`). The monitor sees the flag drop at its
next tick, so it can run for up to 0.5 s after the cancel. Both activations therefore refuse while
`DUWS_disguise_monitorRunning` is set, not while a disguise flag is set, or a disguise started in
that tick would get no monitor.

A `FiredMan` handler only stamps the time of the shot. The monitor decides at the next tick, because
only a unit that spots the player breaks cover.

When the meter passes 50 while an OPFOR unit spots the player, a civilian hears one of the
`STR_DUWS_T_DISGUISE_WARNING_*` lines from an OPFOR speaker. A bandit gives no warning, because the
lines are a soldier's.

### Enemy sites

`fnc_disguise_atEnemySite` reads two registries:

| Site | Ring |
|---|---|
| OPFOR zone | the zone radius. The zone must be in `WARCOM_zones_controled_by_OPFOR`. The radius comes from `zone_meta_array`. Rows match by position. |
| OPFOR hardpoint | `DISGUISE_CIV_HP_RING` (50 m) from a `DUWS_hardpoints` row with side `"opfor"` |

The band is `DISGUISE_CIV_SITE_WARN` (100 m) wide outside the ring. The first tick inside the band
shows one hint, and the player gets the hint again only after leaving the band and coming back.

Revealed and hidden sites count alike. A hidden site streams in live and visible, and a player who
comes near reveals it anyway. An OPFOR-held town is in neither registry, so it is safe ground, and
town reputation does not affect the disguise.

## Bandits

Bandits ([`faction_system.md`](faction_system.md#bandits)) watch the civilian disguise the same way as
OPFOR. They count in the activation checks, the meter, the decay and every break.

An OPFOR uniform is a target to a bandit, not a cover. The first bandit that spots a player in the
enemy disguise ([spotting](#the-suspicion-meter)) breaks cover at once and stamps the cooldown. Captive
ends, so the bandits then engage the player. A bandit that hunts or spots the player also refuses the
activation, so the disguise cannot start and break on its first tick. Bandits do not raise the enemy
meter or slow its decay.

## The OPFOR kit

`fnc_scanEnemyGear` runs once at start, next to the civilian gear scan, and fills the server-only
`DUWS_enemyKit`. It spawns one of each OPFOR man class from the roster (`fnc_faction_unit_keylist`),
reads the worn kit, and deletes it. The vehicle set is every OPFOR vehicle and static class. The sets
come from the roster, not config side 0, because auto-detection can field a faction as OPFOR whose
units are side 2 in config. The scan also records each slot that some OPFOR class leaves empty, as
`optional`, and the empty-slot penalty skips those slots.

The sets hold lowercase classes, because `in` compares strings by case. A weapon matches by class or
by its arsenal base row (`fnc_arsenal_base_weapons`), so a looted rifle with a different optic still
matches. A civilian vehicle (config side 3) adds no penalty.

## The info panel

The bottom of the disguise panel lists the rules of the active disguise, or reads "No disguise
active." For the enemy disguise, it also gives the floor and names each item that raises it. The
client cannot calculate the floor, because `DUWS_enemyKit` is server-only. The monitor therefore
publishes `[floor, mismatch]` as `DUWS_enemyDisguise_kit` on the player when either changes. A public
variable is correct here, unlike for the meter, because it changes only when the kit changes. The
panel reads it once, when it opens.

## The readout

The bar stays on screen for the whole disguise, for both disguises. `fnc_disguise_meter` draws it
with 20 segments: grey for the floor, red for the rise above it, and dark for the rest. A line above it
names the active disguise, with the panel's status text. It draws on a
HUD layer (`DUWS_DisguiseMeter` in `description.ext`), not in the hint box, because a bar held in the
hint box for the whole disguise would hide every other hint. The layer uses the same box on the left
of the screen as the OPCOM AI debug overlay, so the two overlap only in a debug session.

The monitor sends `[meter, floor, civ]` to the owner on the first tick and then only when a segment
changes, and sends an empty call when the disguise ends, which hides the bar. The meter goes to the
owner by `remoteExec`, not by a public variable, which would reach every client twice a second.

## Cooldown

The cooldown runs from cover blown, not from activation: 300 s for the civilian disguise
(`DUWS_disguise_blownAt`) and 600 s for the enemy disguise (`DUWS_enemyDisguise_blownAt`).

A rest clears both cooldowns for every player through `fnc_disguise_resetCooldown`, because the rest
skips hours of game time and the stamps count real seconds. The Debug menu's World page has the same
reset for the player who opens it.

`diag_tickTime` counts from the start of the Arma process. When a save resumes in a new Arma session,
every stamp is in the future, so the cooldown sweep in `server/server_init.sqf` clears it.
