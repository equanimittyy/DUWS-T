# Per-town reputation: implementation plan

Reputation becomes a per-town number, and that number decides who owns the town. Killing a
civilian in one town stops costing the player standing in a town on the other side of the map;
in exchange, a town's standing now feeds Army Power to whichever side it favours, so civilian
ground becomes territory the campaign fights over — held by an enemy garrison when it turns,
taken back by clearing that garrison. `Player_Reputation` survives as the global readout so the
campaign-wide consumers keep working unchanged; the consumers that are already local —
informants, aid, recruitment, fast travel — read the town they are acting in.

Civilian *hostility* leaves with this change rather than becoming per-town. Armed civilians and
suicide bombers are deleted; the enemy's answer to a town that hates the player becomes a
garrison now and a planning director later, documented in
[`opfor_commander_plan.md`](opfor_commander_plan.md).

This plan lands **after** the civilian town-generation rewrite. That rewrite re-keys the town
registry, and per-town reputation keys on the same index.

## Why the current system is replaced

| Problem | Where |
|---|---|
| One global scalar carries all reputation. Every civilian death anywhere moves the same number | `server/server_var_init.sqf:177`, sole writer `server/server_fnc_init.sqf:151-159` |
| Six consumers act on one town but read the campaign-wide number — informants, aid, toolkits, recruitment, fast travel, disguise | table below |
| Two reputation gates run on clients, so they cannot read server-local town state | `shared/functions/fnc_addAskEnemyAction.sqf:36`, `shared/functions/fnc_civ_recruitAction.sqf:18` |
| Passive recovery walks reputation back up on its own, so nothing the player did stays done | `server/misc/fnc_civ_rep_economy.sqf:12-38` |
| That recovery feeds an uncapped CP faucet at `ceil(rep/2)` every 15 minutes | `:41-55` |
| Building damage is charged anywhere on the map and never checks who caused it, so an enemy tank wrecking a house bills the player | `server/misc/fnc_warcrimes_script.sqf:8-23` |
| Its curve dampens rather than escalates, its threshold never resets, and sub-threshold damage is discarded, so paced demolition is free forever | `:36-43,61` |
| Spawn density saturates at the player's cap from 25 buildings up, so most towns present identically | `server/misc/fnc_civ_handler.sqf:253-254` |
| Civilian towns are inert scenery: holding one changes no campaign number | — |

## Design

### State

Two index-parallel arrays beside `civ_locations`, not N separate globals. `publicVariable`
broadcasts an absolute with no lock, and one variable per town multiplies both the traffic and
the lost-update surface described in
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md).

| Variable | Shape | Range |
|---|---|---|
| `civ_town_rep` | numbers, index-parallel to `civ_locations` | `[-20, 20]` |
| `civ_town_ap` | numbers, index-parallel | `[1, 3]`, integer |

Initial reputation **0**, not the global's default of 1 (`server/server_var_init.sqf:177`).
Towns overlapping an enemy zone are the exception, below. Zero makes the bands symmetric — ten
points either way — so neither side is closer to owning a fresh town than the other. The global
keeps its own baseline of 1; it is a different number with different consumers, and moving it
would change what partisan hiring and the CP tick see.

The index is the position in `civ_locations`, assigned by `forEachIndex` after the overlap cull
(`server/misc/fnc_civ_init_Tomata.sqf:163-212`) — the same town ID every civilian consumer
already uses.

**Neither array is broadcast.** `civ_locations` and `civ_radii` are already plain
`missionNamespace setVariable` with no public flag (`fnc_civ_init_Tomata.sqf:163-164`), and the
parallel arrays keep that. Nothing on a client reads them: the two client-side gates move
server-side in this same change, and the map markers are painted by the server with
`setMarkerText` / `setMarkerColor`, both global-effect commands. A broadcast would ship an
N-element array to every machine on every civilian death for no reader.

### The writer

`fnc_town_rep_adjust [_townIndex, _delta, _reason]`, built to the same contract as
`fnc_rep_adjust` (`server/server_fnc_init.sqf:151-159`): server-only, signed delta, the writer
owns the rounding, callers never assign. [`info/server_client_authority.md`](info/server_client_authority.md)
names the delta writers as the mission's authority template, and
[`info/cp_economy.md`](info/cp_economy.md) explains why rounding cannot move to callers —
`abs Player_Reputation` is multiplied into an AI spawn count, so drift reaches AI behaviour.

Order of work, all of it inside the writer:

1. Clamp the new total to `[-20, 20]`.
2. Write `civ_town_rep`.
3. Forward the **applied** delta — the clamped total minus the old total, not the requested
   delta — to `fnc_rep_adjust`, so the global stays the sum of what actually happened. A town
   pinned at `-20` absorbing repeated `-0.3` hits would otherwise drag the global down forever
   while nothing on the map changed.
4. Repaint the town's two markers if the band changed.

### Resolving the town

Two cases, both already solved somewhere in the tree:

**The event has a unit.** Civilian deaths and looting act on a civilian who already carries its
town: `civ_locIndex`, set at `server/misc/fnc_civ_handler.sqf:492` and read at `:340,:565,:569`.
This is exact — no distance test.

**The event has only a position.** Iterate `civ_locations` / `civ_radii` in parallel and take
the first town whose radius contains the point. `server/misc/fnc_disguiseAsCivilian.sqf:258-268`
already does exactly this and can be lifted verbatim into a helper.

If neither resolves a town — the player is in open country, or civilians are off — the delta
goes to the global only. That is the degradation path and it must be the default, not an error.

Do **not** try to read the presence triggers: `server/misc/fnc_civ_init_Tomata.sqf:178-191`
discards the handle at creation, so there is no `list _trg` to query.

### Ownership bands

| Band | Reputation | Ellipse colour | Pays |
|---|---|---|---|
| BLUFOR | `>= 10` | pale blue | BLUFOR AP |
| Neutral | `-9` … `9` | purple | nobody |
| OPFOR | `<= -10` | pale red | OPFOR AP |

**Not green for the player's band.** Green is Independent in the engine's own colour language,
and this mission sets `resistance` hostile to west (`server/server_init.sqf:28-32`), so a green
disc reads as enemy ground to anyone who knows Arma's map conventions. Blue and red match the
sides that actually own the town.

**Pale, so towns never read as zones.** Enemy zones are saturated `ColorRed`
(`server/init_zones/fnc_createzone.sqf:48,62`) and captured ones `ColorGreen`
(`fnc_captured.sqf:58,60`). A civilian town is not an objective and must not compete with one
for attention at a glance. Desaturating keeps the same side language without the same weight.

### Defining the colours

`setMarkerColor` takes a class name from `CfgMarkerColors`, and the mission defines no such
class — `src/description.ext` carries only `CfgFunctions`. Stock Arma has no pale variants and
nothing named `#(0.5,0,0.5,0.3)`, which is what `fnc_civ_init_Tomata.sqf:198` currently passes;
that string is procedural-texture syntax, not a marker colour, so the neutral ellipses are
probably rendering in the default colour rather than the purple this plan and the code comment
both assume. Confirm on the map before relying on it either way.

Three classes in `description.ext` settle it:

```cpp
class CfgMarkerColors {
    class civ_town_blufor { name = "Town (friendly)";  color[] = {0.45, 0.62, 1.0, 1}; };
    class civ_town_neutral { name = "Town (neutral)";  color[] = {0.6,  0.35, 0.7, 1}; };
    class civ_town_opfor  { name = "Town (hostile)";   color[] = {1.0,  0.45, 0.45, 1}; };
};
```

Translucency comes from `setMarkerAlpha 0.3`, not from the alpha channel in `color[]`, and the
ellipse is created today with no `setMarkerAlpha` call at all
(`fnc_civ_init_Tomata.sqf:196-199`) — so it sits at 1. Creation and every repaint must set it,
or a banded town paints an opaque disc over the terrain.

The same reasoning applies to captured zones painting themselves `ColorGreen`, which has the
identical Independent-reads-as-enemy problem. That is pre-existing and untouched here.

**The band is the only writer of the ellipse colour.** Depopulation paints it black today
(`fnc_civ_handler.sqf:121-129`, `fnc_civ_handler_wbk.sqf:118-126`,
`server_fnc_init.sqf:955-962`); those blocks are deleted with the live population counter,
below, so no second writer survives to race the band.

### What the marker says

The icon text becomes three fields, pipe-separated, replacing the bare population number at
`fnc_civ_init_Tomata.sqf:209`:

```
Pop: 118 | Rep: 12 | +2AP/30min
Pop: 118 | Rep: 3
Pop: 46 | Rep: -20 | +1AP/30min
```

The AP field renders only in the BLUFOR and OPFOR bands. A neutral town pays nobody, so
printing a bonus it does not grant would be a lie — this is the general form of "hide it at
rep 0".

`Pop` is the town's usable-building count and never changes. It is a size figure, not a head
count.

Reputation prints as stored, with no rounding at the display. `fnc_rep_adjust` already snaps to
two decimals and zeroes anything under `0.01`, so a whole number prints whole. Rounding to an
integer for display would print `Rep: 10` for a town sitting at `9.7`, which is neutral — the
number on screen would contradict the colour under it.

**Ten call sites write this text today** and nine of them are deleted outright, because they
exist only to decrement a live head count: `fnc_civ_handler.sqf:129,145,347`,
`fnc_civ_handler_wbk.sqf:126,143,384`, `fnc_recruit_civilian_server.sqf:79`, and
`server_fnc_init.sqf:963` plus `fnc_updateIcon` at `:975,977`. What remains is the creation
write at `fnc_civ_init_Tomata.sqf:209` and one repaint helper called by the reputation writer.
Nothing else touches the marker, so the fields cannot be partially overwritten.

### Static population, scaled civilian density

`civ_pop_%1` stops being a live counter. It is set once at registration to the town's usable
building count and never written again, which deletes the whole `_initialPop` derivation
(`fnc_civ_init_Tomata.sqf:72-83`) — the `× 2`, the `min 280` cap, the random 6–12 floor and the
RAVAGE doubling all go. The count is already carried in from selection for the radius and the
AP rank, so this removes a calculation rather than adding one.

Civilian density follows from it, unchanged in shape: `_spawnCount = _targetPop min
_maxSpawnPerVisit` (`fnc_civ_handler.sqf:253-254`), with `_targetPop` now the raw building count
instead of `buildings × 2`.

The effect is where saturation sits. `civ_maxSpawnPerVisit` defaults to 50 and is the player's
performance ceiling, set from the environment menu
(`client/dialog/fnc_process_enviro_menu.sqf:58`); it stays exactly that. But at `buildings × 2`
the ceiling binds from 25 buildings upward, which is most real Altis towns, so every town from a
market village to Kavala presents the same 50 concurrent civilians. Dropping the multiplier
moves the bind to 50 buildings and lets twice as much of the map's size range show on the
ground before the cap flattens it.

The trade is fewer civilians in mid-size towns — 25 buildings goes from 50 concurrent to 25.
Raising `civ_maxSpawnPerVisit` is the player's answer to that if they have the frames for it,
which is what the setting is for.

`civ_remaining_%1` is unaffected in shape: still `_targetPop - _spawnCount`, still consumed by
the replacement path on each death (`fnc_civ_handler.sqf:353-360`), so a large town keeps
absorbing casualties longer than a small one. The pool is half what it was, in proportion.

The `min 280` cap disappears as dead code — at any plausible `civ_maxSpawnPerVisit` the spawn
ceiling binds first.

**Depopulation goes with the counter.** The ghost-town notification, the black marker, the
`Pop: X` state and the `+15` CP scorched-earth reward all hang off `_currentPop <= 1`
(`fnc_civ_handler.sqf:121-142`, `fnc_civ_handler_wbk.sqf:118-139`, `server_fnc_init.sqf:955-968`),
which a static figure never reaches. All three blocks are deleted, removing a CP faucet
[`info/cp_economy.md`](info/cp_economy.md) already lists along with the AP and reputation
penalties that rode with it.

### Scorched earth is retired, its menu slot reused

Depopulation was the only thing that could fire it, so the campaign option goes rather than
sitting in the menu doing nothing. Its control becomes the Escalation enabler — the slot has
been recycled before (`enviro_menu.hpp:157` marks it as the former VCOM control), and reusing it
means no relayout. The full surface:

| Piece | Where |
|---|---|
| Reward block, both handlers | `fnc_civ_handler.sqf:133-142`, `fnc_civ_handler_wbk.sqf:131-140` |
| Menu controls `SE_frame` (1807) and `SE_combo` (2106) — retitled, not removed | `shared/includes/enviro_menu.hpp:157-176` |
| Combo population — relabelled to the escalation toggle | `client/dialog/fnc_enviro_menu.sqf:55-57` |
| Setting read and broadcast — becomes `escalation_enabled` | `client/dialog/fnc_process_enviro_menu.sqf:89-90` |
| Settings-summary entry — renamed | `client/dialog/fnc_callsign_confirm.sqf:60` |
| Campaign-start reminder | `client/client_init.sqf:387-389` |
| Intro-helicopter briefing line | `server/misc/fnc_intro_heli.sqf:226-229` |
| `SE` notification class | `shared/includes/notifications.hpp:347` |
| Strings `_title`, `_tooltip`, `_effect1`, `_effect2`, `_effect3`, `STR_DUWS_T_SEEsub` | `src/stringtable.xml:1689-1713` |

**Do not remove `STR_DUWS_T_x4zs3lsg0` / `STR_DUWS_T_vk37aebo`.** They read as the generic
disabled/enabled pair and are shared by the apocalypse, simple-zones and hardcore combos
(`fnc_enviro_menu.sqf:50-51,72-73,126-127`) — and the escalation toggle wants the same pair.

### AP worth from the map's own size distribution

Every town gets an integer worth of 1, 2 or 3, fixed at registration. The scale is a **rank
within the campaign's own kept set** — bottom third, middle third, top third — not an absolute
building count:

```sqf
private _smaller = { _x < _buildings } count _allBuildingCounts;
private _ap = 1 + floor (3 * _smaller / _n);
```

Linear in rank position, so the three bands hold equal shares of the town list. No clamp is
needed: `_smaller` counts towns *strictly* smaller, so it never exceeds `_n - 1` and the
expression cannot reach 4.

Two properties this buys, and one it does not:

- **Portable.** Altis cities and a small map's hamlets both span 1 to 3, because the ranking is
  relative to what that campaign actually selected. An absolute threshold table would pay 1 AP
  everywhere on a sparse map.
- **Ties pay equally.** Two towns of identical size get identical worth, which ranking by
  sorted position would not give. The cost is that a large tie block sits at the rank its
  *bottom* edge occupies: ten towns tied at the top of a twenty-town set all score 2, not 3.
  The degenerate case — every kept town exactly the same size — pays 1 across the board. Exact
  ties in building counts are rare enough that this is a floor, not a behaviour.

**Measured on building count, not radius.** The count already travels with the town from
selection (`fnc_civ_selectTowns.sqf:138`) and registration already derives radius and population
from it. Radius is the wrong input twice over: it clips at 500 (`fnc_civ_init_Tomata.sqf:62`),
so every large town measures the same, and overlap resolution then shrinks it
(`:126,:136`) until it describes the neighbour rather than the town.

### No naturally spawning resistance fighters

Three mechanics are deleted, not converted to read town reputation:

| Mechanic | Where | Why it goes |
|---|---|---|
| Hostile civilian conversion | `fnc_civ_handler.sqf:531-558` | Re-sides up to 70 % of a town's groups to `resistance`, which is hostile to west (`server/server_init.sqf:28-32`) |
| Hostile replacement spawn | `:381-383` | 30 % of replacement civilians spawn `resistance` at negative reputation |
| Suicide bombers | `:563-588`, `fnc_civ_suicideBomberBehaviour.sqf` | Counted off the resistance headcount, so conversion's removal zeroes them anyway |

Hostility against the player comes back under the OPFOR commander feature — IEDs, ambushes and
sabotage planned against a town's surroundings rather than spawned inside it. Both removed
mechanics are documented in full in [`opfor_commander_plan.md`](opfor_commander_plan.md),
including the two properties any replacement has to keep: the `isHostile` flag that stops a
threatening civilian's death counting as a war crime, and the gap between the 10 m side flip and
the 5 m detonation that gives the player a legal window to shoot.

`fnc_civ_lootAction.sqf:219-221` stays. Looting a civilian gives a 70 % chance the town's
civilians arm up and turn on the looter — that is a direct, immediate consequence of a player
action, not a population that spawns hostile because a number is negative.

The `resistance` centre itself stays (`server/server_init.sqf:23,28-32`): WBK survivors spawn
into it (`server_fnc_init.sqf:892`) and the loot reprisal needs it.

**This closes the zone-lock problem.** With nothing civilian-sided spawning hostile, a town
sitting on an enemy zone can no longer hold that zone's `WEST SEIZED` trigger
(`server/init_zones/fnc_createzone.sqf:274`) against the player. The `-20` overlap rule below
becomes purely economic — the enemy draws Army Power from that ground — rather than a way to
make a zone uncapturable.

### The enemy garrison

A town in the OPFOR band carries an enemy garrison, and clearing it is how the player takes the
town back: **the garrison dying resets that town's reputation to 0**, out of the band, off the
enemy's books. This is the reset path that passive recovery used to be, except it costs a
firefight instead of fifteen quiet minutes.

| Tier | Reputation | Garrison |
|---|---|---|
| 1 | `-10` … `-14` | infantry only |
| 2 | `-15` … `-19` | + a second team and a light vehicle |
| 3 | `-20` | + armour |

Built on the existing OPFOR spawners — `fnc_createoppatrol2`, `fnc_createopteam2` and
`fnc_random_veh`, composed the way the zone size tiers already compose them
(`server/init_zones/fnc_zone_spawn_sizes.sqf`). They read `OPFOR_Faction_X`, so the garrison
inherits faction auto-detection with no extra work.

The garrison spawns and despawns on the town's existing presence trigger, like the civilians
do; nothing persistent sits on the map. A town whose reputation is driven back below `-10`
after being cleared gets a new garrison — the band is the condition, not a one-shot flag.

### Escalation replaces war crimes

`fnc_warcrimes_script.sqf` is retired whole. It charged reputation for any non-military `House`
destroyed within 750 m of a player, anywhere on the map, on a curve that was a dampener rather
than the escalator it looked like — the threshold starts at 1 and rises by 2 per charge, so
total reputation lost worked out at `0.4 × sqrt(buildings)`, and levelling a hundred buildings
cost four points. It also never checked *who* destroyed the building, so an enemy tank wrecking
a house during a firefight billed the player, and it discarded any remainder below the threshold
each tick, so one building a minute was free forever.

**Escalation is a plain counter with no attribution.** Every non-military building destroyed
anywhere on the map increments it. Not who did it, not whether anyone was watching, not whether
it stood in a town — the war is getting worse and both sides are making it worse. That is the
whole simplification: attribution via `setShotParents` and per-building damage handlers is
unnecessary if nobody is being blamed, and a proximity test is unnecessary if location does not
matter.

| Property | Value |
|---|---|
| Counter | non-military `House` objects destroyed, anywhere, campaign-wide |
| Budget | 10 % of the map's total `House` count, censused once at init |
| Tier size | budget divided by 11 |
| Level | `floor (destroyed / tierSize)`, 0 to 11 |
| Effect | CP and AP costs multiply by `1 + (level / 10)` — level 1 is 1.1x, level 10 is 2.0x |
| Level 11 | campaign lost |

**It does not touch the civilian system at all.** No town lookup, no civilian-zone dependency,
no reason for civilian generation to run when `CIV_PRESENCE == "NONE"` — the existing gate at
`server/warcom/fnc_init_OPFOR_WARCOM.sqf:54` stays exactly as it is, and a civilians-off
campaign generates no towns, as today.

**`ESCALATION_FRACTION` is 10 %.** A whole-map census counts every `House` on the terrain, the
overwhelming majority of which sit in settlements no campaign ever visits, so the raw total is
far larger than anything a player could plausibly destroy. The fraction exists to bring the
budget back to a number a campaign can approach: a tenth of the map's housing stock is the
loss condition, and a ninetieth of it advances one level. Log the census total to the RPT on the
first Altis run and check the resulting tier is wide enough that a single fire mission cannot
advance a level.

**The census is one engine call, and it is not cheap.** `nearestTerrainObjects` over the whole
world returns every matching object as an array before it can be counted:

```sqf
private _total = count (nearestTerrainObjects
    [[worldSize / 2, worldSize / 2, 0], ["House"], worldSize, false]);
```

The fourth argument is `sortByDistance` — passing `false` skips ordering an array of many
thousands of entries, which is the bulk of the avoidable cost. This runs once during generation,
where the map is already open behind a progress banner and heavier scans are already happening.
Time it before assuming it is free.

**The multiplier has one application point.** `fnc_pool_try_spend`
(`server/server_fnc_init.sqf:170-184`) is the server half of the purchase handshake and already
handles both pools — `case "CP"` and `case "AP"` — so scaling `_cost` on entry covers all forty
client purchase sites at once. It is a sibling of the existing `cp_reward_multiplier`, applied
to the sink side instead of the faucet side. The four server-side paths that bypass the
handshake and call `fnc_cp_adjust` directly (`fnc_redeployHQUnits`,
`fnc_activateBaseRepairStation`, `fnc_uav_scanner`, `fnc_pylon_set_with_cost`) need the
multiplier applied individually or they stay unscaled; that is a choice, not an oversight, and
[`info/cp_economy.md`](info/cp_economy.md) already names them as the handshake's exceptions.

**The census and the counter must apply the same filters.** Both sides of the ratio have to mean
the same thing, or the level runs past 11 on a map that is not flattened. The destruction
handler keeps the two filters worth keeping from the old script — `editorSubcategory !=
"EdSubcat_Military"` and an object type of `House` — and the census counts `House` on the same
terms. Military structures stay excluded on both sides for a gameplay reason, not a symmetry
one: destroying enemy fortifications is the objective, and counting it would mean every zone
capture pushed the campaign toward its own loss condition.

**`BuildingChanged` is a local event and the script is server-only.** Whether a dedicated server
receives it for damage a client caused is unverified. If it does not, this mechanic has never
worked in dedicated MP and neither will its replacement. Test before building on it.

### Towns overlapping an enemy zone start enemy-held

A town whose civilian disc overlaps an enemy zone's disc is initialised at `-20` instead of `1`.
The enemy already holds that ground; the civilians there start out with them.

The test runs in registration, after the overlap cull has finalised every radius — the same
reason the HQ keep-out lives there and not in selection. Radii come from `zone_meta_array`
(`server/init_zones/fnc_createzone.sqf:34`, entries `[num, pos, size, points, fortified,
prefab]` where `size` is the zone radius), not `serv_zones_array`, which stores positions only.
The array is populated before civilian registration runs: `fnc_createzone` pushes to it on
entry, and civilian init is gated behind `zones_buildout_done >= count serv_zones_array`
(`server/warcom/fnc_init_OPFOR_WARCOM.sqf:40-49`).

Disc against disc, not centre against centre: `_dist < _civRadius + _zoneRadius`. A civilian
area whose edge reaches into the zone still puts civilians inside it.

### The AP income tick

A third loop in `server/misc/fnc_civ_rep_economy.sqf`, on the same 30-minute cadence as the
territory-hold CP tick (`server/misc/fnc_zonesundercontrol.sqf`) so the two land together and
the marker's `/30min` stays honest.

Each tick sums `civ_town_ap` over the towns in each band and makes **two** `fnc_ap_adjust`
calls, one per side — not one per town. The writer `publicVariable`s and logs on every call
(`server/server_fnc_init.sqf:41-55`), so per-town calls would broadcast the same global twenty
times a tick for one net change.

### Removing passive recovery

The recovery thread (`server/misc/fnc_civ_rep_economy.sqf:12-38`) is deleted outright rather
than rewritten per town. Reputation is now territory: ground that walks itself back to neutral
while the player is elsewhere means nothing either side did stays done, and it would fight the
OPFOR town-capture mechanism directly — the enemy taking a town and the town un-taking itself
fifteen minutes later. Standing is earned back the way it was lost, through what happens in the
town.

Two things this orphans, both to be removed in the same change:

- `CIV_deaths` (`server/server_var_init.sqf:79`, written at `fnc_civ_rep_Tomata.sqf:34-35`).
  The recovery thread's quiet-period test is its only reader; without it the counter is
  write-only.
- `STR_DUWS_T_repup`, whose only use is the recovery announcement at
  `fnc_civ_rep_economy.sqf:33`. `STR_DUWS_T_rqwho9bq` and `STR_DUWS_T_0pluxey2` stay — the
  mission and heal paths still use them.

The CP tick at `:41-55` stays as it is. Deleting recovery is what bounds it: the global now
moves only on events, so `ceil(rep/2)` every 15 minutes stops being an unbounded faucet without
the tick itself changing.

### Which consumers move

| Consumer | Where | Reads |
|---|---|---|
| Hostile civilian conversion | `server/misc/fnc_civ_handler.sqf:531-558` | deleted |
| Suicide bombers | `:563-588` | deleted |
| Hostile replacement spawn | `:381-383` | deleted |
| Enemy garrison tier | new, in the town spawn path | **town** |
| Building damage | `server/misc/fnc_warcrimes_script.sqf` | neither — becomes escalation, which touches no reputation |
| Informant spawn chance | `server/misc/fnc_civ_informant_system.sqf:16` | **town** |
| Develop informant | `server/misc/fnc_civ_developInformantServer.sqf:15` | **town** |
| Ask for aid | `server/misc/fnc_civ_askForAid_server.sqf:15` | **town** |
| Ask for toolkit | `server/misc/fnc_civ_askForToolkit_server.sqf:15` | **town** |
| Recruit civilian | `shared/functions/fnc_civ_recruitAction.sqf:18` | **town** — must move server-side first |
| Ask enemy location | `shared/functions/fnc_addAskEnemyAction.sqf:36` | **town** — must move server-side first |
| Disguise break inside a town | `server/misc/fnc_disguiseAsCivilian.sqf:253-268` | **town** |
| Fast travel | `server/misc/fnc_civ_fast_travel_server.sqf:13` | **town** (destination) |
| Hire partisans | `server/misc/fnc_hirePartisans.sqf:22` | global |
| CP income tick | `server/misc/fnc_civ_rep_economy.sqf:46-48` | global |
| SITREP display | `client/misc/fnc_sitrep_display.sqf:28` | global |

The two client-side gates have to move server-side before they can read town state, following
`fnc_civ_askForAid_server.sqf` as the pattern — its siblings already work this way. Leaving
them client-side and broadcasting the registry instead is the wrong trade: it exports civilian
internals to every machine to serve two `addAction` conditions.

## Files touched

| File | Change |
|---|---|
| `server/server_fnc_init.sqf` | New `fnc_town_rep_adjust` beside `fnc_rep_adjust:151-159`; new `fnc_civ_townAt` position→index helper; new `fnc_civ_townRender` marker repaint; registry lines. Delete the WBK depopulation block `:955-968` and `fnc_updateIcon` `:971-979` with the live counter; drop the pop decrements at `:856-861,:941-943`, keeping the `civ_remaining_%1` increment that feeds WBK replacements. |
| `server/misc/fnc_civ_init_Tomata.sqf` | Initialise `civ_town_rep` at 0; compute `civ_town_ap` from the kept set's building counts; `-20` for enemy-zone overlaps; delete the `_initialPop` derivation `:72-83` and store the building count as `civ_pop_%1`; three-field marker text at `:209`. |
| `server/misc/fnc_civ_rep_economy.sqf` | Delete the recovery thread `:12-38`; add the 30-minute AP tick; rewrite the file docstring. |
| `server/misc/fnc_civ_rep_Tomata.sqf:27,34-35` | Route the civilian-death `-0.3` through the town writer, resolving the town from the victim's `civ_locIndex`; drop the `CIV_deaths` bump. |
| `server/server_var_init.sqf:79,93` | Remove `CIV_deaths`; `damagedBuildings` becomes per-town. |
| `server/misc/fnc_civ_handler.sqf` | Delete hostile conversion `:531-558`, hostile replacement `:381-383`, suicide bombers `:563-588`, and the depopulation block `:121-142` with its scorched-earth reward. Density from building count `:253-254`. Drop the pop decrement `:344-347`. Garrison spawn on the town's tier. |
| `server/misc/fnc_civ_handler_wbk.sqf` | Delete the depopulation block `:118-139`; drop the marker-text writes `:126,143,384`. Density `:251`. |
| `server/misc/fnc_civ_suicideBomberBehaviour.sqf` | Delete; behaviour preserved in `opfor_commander_plan.md`. |
| `server/misc/fnc_recruit_civilian_server.sqf:78-79` | Drop the population decrement and marker write. |
| `server/misc/fnc_warcrimes_script.sqf` | Delete; replaced by `fnc_escalation.sqf` — whole-map census, counter, level, cost multiplier and the level-11 loss. |
| `server/server_fnc_init.sqf:170-184` | Scale `_cost` by the escalation multiplier in `fnc_pool_try_spend`. |
| `server/misc/fnc_civ_informant_system.sqf:16`, `fnc_civ_developInformantServer.sqf:15` | Town rep. |
| `server/misc/fnc_civ_askForAid_server.sqf:15`, `fnc_civ_askForToolkit_server.sqf:15` | Town rep. |
| `server/misc/fnc_civ_fast_travel_server.sqf:13` | Destination town's rep. |
| `server/misc/fnc_disguiseAsCivilian.sqf:253-268` | Town rep; the town lookup here becomes the shared helper. |
| `shared/functions/fnc_civ_recruitAction.sqf`, `fnc_addAskEnemyAction.sqf` | Move the gate server-side, then read town rep. |
| `shared/functions/fnc_civ_lootAction.sqf:44`, `fnc_civ_healAction.sqf:69` | Resolve the town from the civilian acted on. |
| `server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf:199,218` | Resolve from the escorted civilian; fall back to global. |
| `server/missions/mission_threads/transport_idap/fnc_transport_IDAP_mission.sqf:233,249` | Resolve from delivery position; fall back to global. |
| `shared/includes/enviro_menu.hpp:157-176` | Delete the scorched-earth frame and combo; shift every row below up two grid units. |
| `shared/includes/notifications.hpp:347` | Delete the `SE` notification class. |
| `client/dialog/fnc_enviro_menu.sqf:55-57`, `fnc_process_enviro_menu.sqf:89-90`, `fnc_callsign_confirm.sqf:60` | Drop the scorched-earth setting. |
| `client/client_init.sqf:387-389`, `server/misc/fnc_intro_heli.sqf:226-229` | Drop the scorched-earth announcements. |
| `src/description.ext` | New `CfgMarkerColors` with the three town-band colours. |
| `src/stringtable.xml` | Remove `STR_DUWS_T_repup`, the six scorched-earth keys, and the suicide-bomber / ghost-town keys orphaned by the deletions; add the marker field labels. Keep the shared enabled/disabled pair. |
| `info/cp_economy.md` | Second reputation writer, the `±20` clamp, the town AP faucet, recovery removed. Its reputation-tick row still points at `fnc_civ_init_Tomata.sqf:237`; the loop moved to `fnc_civ_rep_economy.sqf`. |
| `info/zone_and_town_generation.md` | The enemy-zone overlap rule, and its Defects-B entry on towns blocking capture, which removing hostile civilians resolves. |

## Task list

- [ ] Delete hostile conversion, hostile replacement, suicide bombers and `fnc_civ_suicideBomberBehaviour.sqf`. Verify: `bash tests/run.sh`; a campaign driven deeply negative spawns no `resistance` unit from any town.
- [ ] Make `civ_pop_%1` static from the building count; delete the `_initialPop` derivation and the depopulation blocks. Verify: towns between 25 and 50 buildings now spawn visibly different counts instead of all hitting the cap, and no town reaches a ghost-town state.
- [ ] Retire scorched earth across all nine sites, relaying out the environment menu. Verify: `bash tests/run.sh`; the menu has no gap where the combo was, and `grep -r scorched src/` returns nothing.
- [ ] Add `civ_town_rep` at baseline 0 and `civ_town_ap`. Verify: `bash tests/run.sh`; both array lengths match `count civ_locations` after the overlap cull; AP values span 1–3 across an Altis campaign in the RPT, in roughly equal thirds.
- [ ] Apply `-20` to towns overlapping an enemy zone. Verify: the RPT names them, and their markers are red at campaign start.
- [ ] Write `fnc_town_rep_adjust`, `fnc_civ_townAt`, `fnc_civ_townRender`. Verify: a civilian killed in town A moves only town A's entry; a town driven to `-20` stops moving and the global stops moving with it.
- [ ] Add `CfgMarkerColors` and repaint the ellipse from it at creation, with `setMarkerAlpha 0.3`. Verify: a neutral town renders visibly purple and translucent, which settles whether the current `#(...)` string ever worked.
- [ ] Three-field marker text and band repaint. Verify: a town crossing 10 turns pale blue with its AP field appearing, crossing back to 9 turns purple with it gone; neither shade competes with a zone marker at map zoom-out.
- [ ] Delete the recovery thread; remove `CIV_deaths` and the orphaned stringtable keys. Verify: `bash tests/run.sh`; a campaign left idle after one civilian death shows no reputation movement.
- [ ] Move the two client-side gates server-side, unchanged in behaviour, before touching what they read. Verify: recruit and ask-enemy still work for a non-host player.
- [ ] Convert the per-town consumers in the table above.
- [ ] Replace `fnc_warcrimes_script.sqf` with `fnc_escalation.sqf`: whole-map census, counter, level 0–11, and the `1 + level/10` multiplier applied in `fnc_pool_try_spend`. Verify: the census total and its wall-clock cost are logged to the RPT; destroying a tier's worth of buildings moves prices from 1.0x to 1.1x; reputation does not move; a civilians-off campaign escalates normally.
- [ ] Confirm 10 % holds against the measured Altis census. Verify: a single fire mission cannot advance a level.
- [ ] Add the level-11 loss condition and the enviro-menu toggle in the vacated slot. Verify: the menu reads Escalation with the shared enabled/disabled pair; disabling it stops both the multiplier and the loss.
- [ ] Add the enemy garrison with its three tiers, and the clear-to-reset rule. Verify: a town at `-20` spawns the armour tier, and killing the garrison sets it to 0 with the marker returning to purple.
- [ ] Add the 30-minute AP tick. Verify: the RPT shows one BLU and one OPF `fnc_ap_adjust` entry per tick, and the totals match the sum of the banded towns' worth.
- [ ] In-game: confirm the global still gates partisan hiring and the CP tick as before.
- [ ] Update `info/cp_economy.md` and `info/zone_and_town_generation.md`.

## Decided trade-offs

**The global receives the applied delta, not one derived from nearby towns.** The original
suggestion was to compute the global's plus/minus from the reputation of towns near the
player. Feeding it the delta the town actually absorbed keeps the global's behaviour
bit-for-bit outside the clamp, and means every consumer still reading the global is unaffected
by this change. If the global later needs to be a genuine aggregate, that is a separate change
with its own regression risk, and it should not ride along with the per-town split.

**The global is not clamped.** Per-town pools cap at `±20`; the global is their running sum and
would need a cap of `20 × town count` to mean the same thing, which is not a cap. Its consumers
— partisan hiring, the CP tick, SITREP — all read it as a magnitude, and clamping it would
silently change what they see.

**AP is a threshold ladder, not a pool, so this faucet is inflationary.** Nothing spends AP.
The WARCOM director reads it as a series of gates — BLUFOR wave tiers at 10, 40, 65, 100 and
136 (`server/warcom/fnc_WARCOM_blu_assault.sqf:11-25`), OPFOR air above 150
(`fnc_WARCOM_opf_air.sqf:11`), OPFOR patrols above 100 (`server/missions/fnc_missionPatrols.sqf:18`)
— and the only subtraction anywhere is losing a zone. A 20-town campaign averaging 2 AP pays at
most 40 AP per 30 minutes with every town banded, against roughly 50 AP for capturing a 500 m
zone. Civilian income therefore reads as a fraction of a capture rather than a replacement for
one, and reaching the 136 top rung on towns alone takes hours of holding most of the map. The
ladder still only goes up, so the escalation is permanent once earned; the 1–3 scale sets how
long that takes.

**The routes into each band are not symmetric, even though the thresholds are.** From the
baseline of 0 both bands are ten points away, but the ways to travel are not alike. Going
negative is incidental: civilian deaths at `-0.3` (`fnc_civ_rep_Tomata.sqf:27`, applied half the
time and only with a player inside 200 m, so about 67 kills), building damage inside the town,
a failed IDAP at `-5`. Going positive is deliberate: healing a civilian at `+0.5`, IDAP success
at `+5`, protect-civ success. A town therefore drifts toward the enemy through ordinary
fighting and only comes back through work aimed at it — or through clearing its garrison, which
is the fast path and the reason the garrison exists.

**Reputation now has a floor, and the floor is what tiers the garrison.** Previously unbounded
on the negative side, on the grounds that negative reputation is the mechanic. With hostile
conversion deleted there is no longer a consumer that multiplies `abs rep` into a spawn count,
so the clamp costs nothing; `-20` instead becomes a meaningful bottom, the point at which the
garrison reaches its armour tier and the town pays the enemy its full worth.

**Clearing a garrison is worth more than the reputation it resets.** The player who flattens a
town's reputation to `-20` and then kills the garrison lands back at 0 having paid nothing for
the civilian deaths that got them there — the reset discards the whole debt in one action. That
is deliberate: the alternative is a town the player can permanently ruin with no route back,
which is what passive recovery used to prevent. The garrison is the price, and its three tiers
are the dial. If the reset proves too cheap, raising the tier strengths is the lever, not
partial resets.

**Towns are re-keyed by the civilian rewrite.** `civ_town_rep` and `civ_town_ap` key on the
array index, and the town-generation rewrite replaces the selector and caps towns at 21.
Landing this plan first means re-keying it twice. Keying on town name instead would survive the
rewrite but breaks the moment two map towns share a name, which Altis does not guarantee.
