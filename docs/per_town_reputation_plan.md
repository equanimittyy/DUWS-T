# Per-town reputation: implementation plan

Reputation becomes a per-town number, and that number decides who owns the town. Killing a
civilian in one town stops costing the player standing in a town on the other side of the map;
in exchange, a town's standing now feeds Army Power to whichever side it favours, so civilian
ground becomes territory the campaign fights over — held by an enemy garrison when it turns,
taken back by clearing that garrison. `Player_Reputation` survives as the global readout so the
campaign-wide consumers keep working unchanged; the consumers that are already local —
informants, aid, recruitment — read the town they are acting in.

Civilian *hostility* leaves with this change rather than becoming per-town. Armed civilians and
suicide bombers are deleted; the enemy's answer to a town that hates the player becomes a
garrison now and a planning director later, documented in
[`opfor_commander_plan.md`](opfor_commander_plan.md).

## Why the current system is replaced

| Problem | Where |
|---|---|
| One global scalar carries all reputation. Every civilian death anywhere moves the same number | `server/server_var_init.sqf:215`, sole writer `server/server_fnc_init.sqf:151-159` |
| Six consumers act on one town but read the campaign-wide number — informants, aid, toolkits, recruitment, disguise | table below |
| Two reputation gates run on clients, so they cannot read server-local town state | `shared/functions/fnc_addAskEnemyAction.sqf:36`, `shared/functions/fnc_civ_recruitAction.sqf:18` |
| Passive recovery walks reputation back up on its own, so nothing the player did stays done | `server/misc/fnc_civ_rep_economy.sqf:12-38` |
| That recovery feeds an uncapped CP faucet at `ceil(rep/2)` every 15 minutes | `:41-55` |
| Building damage is charged campaign-wide off a 750 m proximity test, so a house wrecked half a map from the town it stood in still moved the same number | `server/misc/fnc_warcrimes_script.sqf:8-23` |
| Its curve dampens rather than escalates, its threshold never resets, and sub-threshold damage is discarded, so paced demolition is free forever | `:36-43,61` |
| Spawn density saturates at the player's cap from 25 buildings up, so most towns present identically | `server/misc/fnc_civ_handler.sqf:253-254` |
| Civilian towns are inert scenery: holding one changes no campaign number | — |

## Design

### None of this runs in RAVAGE or WBK

Per-town reputation and escalation are both off when `CIV_PRESENCE` is `RAVAGE` or `WBK`. No
`civ_town_rep` or `civ_town_ap` arrays, no enemy-zone `-20`, no bands, no ellipse recolouring,
no garrison, no AP tick, and no escalation at all — no census, no counter, no cost multiplier,
no level-11 loss.

This preserves current behaviour rather than changing it. Both modes already bail out of every
reputation path they can reach: `fnc_civ_rep_Tomata.sqf:12` exits for both, and
`fnc_warcrimes_script.sqf:10-11` does the same. A zombie apocalypse has no civil standing to
lose and nobody to install an OPFOR garrison, so a reputation number there would be a dial with
nothing on the other end of it.

What still applies in those modes is civilian *generation*, which is not reputation: the static
`civ_pop_%1` building count, the density scaling that follows from it, and the removal of the
depopulation blocks. Their towns keep the `Pop:` marker field and hold the neutral ellipse
colour permanently, since the band is the only thing that would ever have repainted it.

Skipping the census is also the one place this saves real time — `nearestTerrainObjects` over
the whole world is the most expensive call the escalation system makes, and these modes never
pay it.

### State

Two index-parallel arrays beside `civ_locations`, not N separate globals. `publicVariable`
broadcasts an absolute with no lock, and one variable per town multiplies both the traffic and
the lost-update surface described in
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md).

| Variable | Shape | Range |
|---|---|---|
| `civ_town_rep` | numbers, index-parallel to `civ_locations` | `[-20, 20]` |
| `civ_town_ap` | numbers, index-parallel | `[1, 3]`, integer |

Initial reputation **0**, not the global's default of 1 (`server/server_var_init.sqf:215`).
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
   pinned at `-20` absorbing repeated `-2` hits would otherwise drag the global down forever
   while nothing on the map changed.
4. Repaint the town's two markers if the band changed.

### No caller announces a reputation total

Seven notification sites predict the post-write total and print it: `STR_DUWS_T_0pluxey2`
("Your Reputation is now: %1") at `fnc_civ_rep_Tomata.sqf:30`, `fnc_civ_rep_economy.sqf:32`,
`fnc_protect_civ.sqf:204,219`, `fnc_transport_IDAP_mission.sqf:235,251` and
`fnc_civ_healAction.sqf:72`, plus the same pattern under a different key at
`fnc_civ_lootAction.sqf:43-45`. Every one is deleted; the titles above them survive, so the
player still learns a civilian died or an informant was won.

They cannot be made correct, only relocated. A caller computes its number *before* the write
lands, so it is a prediction, and the clamp means the writer may apply less than was asked — a
town at `-20` absorbing another `-2` announces a change that did not happen. Two of them are
already wrong today for a simpler reason: `fnc_protect_civ.sqf:204` re-reads the global after
firing an asynchronous `remoteExec`, so it prints the *pre-change* value. Rewriting seven sites
to display a number the writer would have to hand back, in a system where the meaningful number
is now the town's rather than the campaign's, buys a worse readout than the map already gives.
The marker carries `Rep:` per town and SITREP carries the global.

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

`setMarkerColor` accepts an inline `#(r,g,b,a)` string as well as a `CfgMarkerColors` class
name. `fnc_civ_init_Tomata.sqf:198` passes `#(0.5,0,0.5,0.3)` and the neutral ellipse does
render purple, so the three bands are inline strings and `src/description.ext` needs no
`CfgMarkerColors` block:

```sqf
"#(0.45,0.62,1.0,1)"   // BLUFOR
"#(0.6,0.35,0.7,1)"    // neutral
"#(1.0,0.45,0.45,1)"   // OPFOR
```

Set `setMarkerAlpha 0.3` at creation and on every repaint anyway. What is confirmed is the
colour, not that the trailing channel in the string is what produces the translucency, and the
ellipse carries no `setMarkerAlpha` call today (`fnc_civ_init_Tomata.sqf:196-199`). If the
channel is inert the marker sits at alpha 1 and a banded town paints an opaque disc over the
terrain.

The same reasoning applies to captured zones painting themselves `ColorGreen`, which has the
identical Independent-reads-as-enemy problem. That is pre-existing and untouched here.

**The band is the only writer of the ellipse colour.** Depopulation paints it black today
(`fnc_civ_handler.sqf:121-129`, `fnc_civ_handler_wbk.sqf:118-126`,
`server_fnc_init.sqf:1150-1156`); those blocks are deleted with the live population counter,
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
count. In RAVAGE and WBK it is the only field, because those modes carry no reputation to
print.

Reputation prints as stored, with no rounding at the display. `fnc_rep_adjust` already snaps to
two decimals and zeroes anything under `0.01`, so a whole number prints whole. Rounding to an
integer for display would print `Rep: 10` for a town sitting at `9.7`, which is neutral — the
number on screen would contradict the colour under it.

**Eleven call sites write this text today** and ten of them are deleted outright, because they
exist only to decrement a live head count: `fnc_civ_handler.sqf:129,145,347`,
`fnc_civ_handler_wbk.sqf:126,143,384`, `fnc_recruit_civilian_server.sqf:79`, and
`server_fnc_init.sqf:1159` plus `fnc_updateIcon` at `:1170,1172`. `fnc_updateIcon` is
`publicVariable`d and reached by `remoteExec` from `:1056` and `:1147`, so both call sites go
with it. What remains is the creation write at `fnc_civ_init_Tomata.sqf:209` and one repaint
helper called by the reputation writer. Nothing else touches the marker, so the fields cannot be
partially overwritten.

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

**Depopulation goes with the counter.** The ghost-town notification, the black marker and the
`Pop: X` state all hang off the population reaching zero — `_currentPop <= 1` in the two
handlers (`fnc_civ_handler.sqf:121-142`, `fnc_civ_handler_wbk.sqf:118-139`) and `_newPop == 0`
in the WBK kill handler (`server_fnc_init.sqf:1150-1160`) — which a static figure never
reaches. All three blocks are deleted. The `+15` CP scorched-earth reward rides on only the
first two (`fnc_civ_handler.sqf:133-142`, `fnc_civ_handler_wbk.sqf:131-140`); its removal takes
out a CP faucet [`info/cp_economy.md`](info/cp_economy.md) already lists, along with the AP and
reputation penalties that came with it.

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
| Campaign-start reminder | `client/client_init.sqf:395-396` |
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
(`server/init_zones/fnc_zone_spawn_sizes.sqf`, which is nothing but those three). They read
`OPFOR_Faction_X`, so the garrison inherits faction auto-detection with no extra work. **Units
only.** A town gets no fortification ring and no prefab composition; the static emplacements a
zone carries are what make a zone an objective, and a town must not read as one.

**Presence is decided by `fnc_spawnWait`, not by the town's own trigger.** The trigger at
`fnc_civ_init_Tomata.sqf:178-191` hardcodes its statements to the civilian handler and discards
its handle, so there is nothing to hook. More to the point, that trigger fires the instant
anyone crosses the radius, and a garrison is exactly the commitment `fnc_spawnWait.sqf:108-115`
was built to defer: it re-tests five seconds after first contact, so grazing the perimeter no
longer spawns a garrison for someone already leaving. Despawn is the same file's grace period
(`:134-146`) — presence resampled every 10 s with the clock restarting on each sighting, so a
fought-over town is never left standing for the campaign.

A town whose reputation is driven back below `-10` after being cleared gets a new garrison —
the band is the condition, not a one-shot flag. A town lifted out of the band by aid or heals
while its garrison is alive loses it the same way, and how those units leave is
[`opfor_retreat_plan.md`](opfor_retreat_plan.md) rather than the deletion sweep zones use
today.

**Cleared is decided by a trigger, not by counting the garrison.** The three spawners are
fire-and-forget: they are `spawn`ed, and none of them returns or registers the group it built,
so there is no handle to watch die. The zone capture trigger has the same problem and solves it
by testing the ground instead of the units — `setTriggerActivation ["WEST SEIZED", "PRESENT",
true]` with `setTriggerTimeout [30, 40, 50, true]` (`server/init_zones/fnc_createzone.sqf:274-279`).
`SEIZED` is the engine's own "this side present, the opposing side absent" test, and the
interruptable timeout restarts the clock if OPFOR walk back in, so the player must hold the town
clear rather than sprint through it. The town gets the same construction sized to its civilian
radius, and the spawners stay untouched.

**Verify that civilian presence does not block `SEIZED`.** Zones carry no civilians, so the
existing use of this activation proves nothing about a town full of CIVILIAN-side units. If they
block it, the fallback is a plain condition trigger counting hostile units in `thisList`. The
retreat behaviour in [`opfor_retreat_plan.md`](opfor_retreat_plan.md) reduces the exposure
either way: a garrison that withdraws out of the radius clears the ground without every last
unit having to die inside it.

### Escalation replaces war crimes

`fnc_warcrimes_script.sqf` is retired whole. It charged reputation for any non-military `House`
destroyed within 750 m of a player, anywhere on the map, on a curve that was a dampener rather
than the escalator it looked like — the threshold starts at 1 and rises by 2 per charge, so
total reputation lost worked out at `0.4 × sqrt(buildings)`, and levelling a hundred buildings
cost four points. Its 750 m proximity test also meant a house charged the campaign-wide number
from wherever it happened to fall, and it discarded any remainder below the threshold each tick,
so one building a minute was free forever.

**Escalation is a plain counter with no attribution.** Every non-military building destroyed
anywhere on the map increments it. Not who did it, not whether anyone was watching, not whether
it stood in a town — the war is getting worse and both sides are making it worse. That is the
whole simplification: attribution via `setShotParents` and per-building damage handlers is
unnecessary if nobody is being blamed.

**A building inside a town also costs that town `-2`.** The destruction handler resolves the
town by position, exactly as §Resolving the town describes, and charges it through
`fnc_town_rep_adjust` on top of the escalation increment. Both, not either: escalation counts
the map's total ruin and reputation records who has to live in it, so the same collapsed house
is legitimately two different facts. Counting it once and splitting by location would also
desynchronise the census from the counter — the budget is 10 % of every `House` on the terrain,
and buildings that could never reach the counter would leave escalation permanently slower than
its own budget claims.

**The reputation charge is gated on a player being there; the counter is not.** A building
charges its town only if a player is within 200 m of it when it falls. That is the same test
the civilian-death path applies (`fnc_civ_rep_Tomata.sqf:17-23`), and the two share one helper
rather than each carrying its own `BIS_fnc_ListPlayers` sweep. The escalation increment is
ungated and lands either way, so a building levelled in empty country still advances the war
without moving anyone's standing.

Presence is a proxy for fault, not a replacement for it. Inside 200 m the charge still does not
ask who fired, so an enemy tank wrecking a house in a firefight the player is standing in costs
the player standing with that town. What the guard buys is the case that actually mattered: a
WARCOM assault or a side mission fought in a town the player is nowhere near can no longer hand
it to the enemy. The garrison's own armour does still charge the town while it is being cleared,
because the player is present by definition for that fight — the clamp bounds it at `-20`, and
clearing the garrison discharges the debt in full.

| Property | Value |
|---|---|
| Counter | one integer: non-military `House` objects destroyed, anywhere, campaign-wide, with no location or attribution test |
| Budget | 10 % of the map's total `House` count, censused once at init |
| Tier size | budget divided by 11 |
| Level | `floor (destroyed / tierSize)`, 0 to 11 |
| Effect | CP and AP costs multiply by `1 + (level / 10)` — level 1 is 1.1x, level 10 is 2.0x |
| Level 11 | campaign lost |
| Town charge | `-2` to the containing town, and only with a player inside 200 m; nothing if the building stood outside every civilian radius |

**The counter never depends on the civilian system.** Only the reputation charge does, and it
degrades the way every other town lookup does: no town resolves, so nothing is charged and the
increment still lands. A campaign with `CIV_PRESENCE == "NONE"` therefore escalates normally
while registering no towns, and the existing gate at
`server/warcom/fnc_init_OPFOR_WARCOM.sqf:54` stays exactly as it is.

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

**Everything costs more, and one place does the charging.** `fnc_pool_try_spend`
(`server/server_fnc_init.sqf:170-184`) is the server half of the purchase handshake and already
handles both pools — `case "CP"` and `case "AP"` — so scaling `_cost` on entry covers all
forty-seven `fnc_pool_spend` sites at once. It is a sibling of the existing
`cp_reward_multiplier`, applied to the sink side instead of the faucet side. The four
server-side paths that bypass the handshake and call `fnc_cp_adjust` directly
(`fnc_redeployHQUnits`, `fnc_activateBaseRepairStation`, `fnc_uav_scanner`,
`fnc_pylon_set_with_cost`) scale too, each applying the multiplier itself;
[`info/cp_economy.md`](info/cp_economy.md) already names them as the handshake's exceptions and
they stay exceptions, just no longer unscaled ones.

**Displaying it is the expensive half.** Charging is one line; showing the player what they
will actually pay is not, for three reasons:

| Obstacle | Where |
|---|---|
| Costs are baked into the label strings — `STR_DUWS_T_5n277nzo` is `"Supply Drop (5CP) Radio"` | 262 stringtable lines contain `CP)`, across all five language variants |
| The menu builder does not know the costs. It only `lbAdd`s labels; the numbers are magic constants in the *handler's* case bodies | `client/dialog/fnc_HQ_Request_Menu.sqf:81-119` against `fnc_request_support.sqf:13,31,52,…` |
| The multiplier is server state, so nothing client-side can compute a scaled price | new, alongside the counter |

**The labels are left alone and the scaled figure is appended.** A base-cost table, readable
client-side, is added and the menu-population sites suffix each row with the escalated price
only when the multiplier is not 1 — `Supply Drop (5CP) Radio → 7 CP`. The baked number reads as
the base and the suffix as what escalation has done to it.

Stripping the numbers out and re-formatting from a placeholder is the tidier shape and it is
rejected on localisation grounds: a `%1` added to English but not to German, Spanish and
Chinese leaves those languages silently printing the stale baked figure, because `format`
returns a string containing no placeholder unchanged. That is a wrong number on screen, not the
ordinary translation lag described in
[`info/stringtable_and_localisation.md`](info/stringtable_and_localisation.md). The base-cost
table is needed for the suffix regardless, so nothing is lost by deferring the strip.

**The census and the counter must apply the same filters.** Both sides of the ratio have to mean
the same thing, or the level runs past 11 on a map that is not flattened. The destruction
handler keeps the two filters worth keeping from the old script — `editorSubcategory !=
"EdSubcat_Military"` and an object type of `House` — and the census counts `House` on the same
terms. Military structures stay excluded on both sides for a gameplay reason, not a symmetry
one: destroying enemy fortifications is the objective, and counting it would mean every zone
capture pushed the campaign toward its own loss condition.

**`BuildingChanged` is a local event and the script is server-only.** Whether a dedicated server
receives it for damage a client caused is unverified, and the replacement is built on it
anyway: if the event does not arrive, this mechanic has never worked in dedicated MP and the
rewrite is no worse than what it replaces. The risk is that escalation is silently
single-player-only. Confirm it in a dedicated play-test before tuning anything downstream of
the counter.

**The level-11 loss restructures the campaign task rather than adding a thread.**
`server/misc/fnc_capture_zones_task.sqf:48` is a blocking `waitUntil` on the win condition, so
the script is parked there for the whole campaign and a loss check appended after it would
never be reached. The wait becomes a test of both conditions, and the branch below it picks
which ending fired — one thread, and the same single place that ends the campaign. Two details
the existing success path does not cover: `description.ext` defines no `CfgDebriefing` at all,
and `"island_captured_win" call BIS_fnc_endMissionServer` (`:61`) takes the one-argument form,
which defaults victory to `true`. The loss needs the two-argument form with `false`, mirroring
the `["Campaign", "SUCCEEDED"]` update at `:59` with `"FAILED"`.

**The toggle does not gate the town charge.** `escalation_enabled` off stops the counter, the
cost multiplier and the level-11 loss. Destroying a building still costs the containing town
`-2` under the same 200 m rule, because that charge is civilian reputation rather than
escalation — it is one of only two negative routes into the OPFOR band, and the fast one. So
the `BuildingChanged` handler is installed whenever `CIV_PRESENCE` is not RAVAGE or WBK, and
only the escalation half of its body reads the toggle.

### Towns overlapping an enemy zone start enemy-held

A town whose civilian disc overlaps an enemy zone's disc is initialised at `-20` instead of `0`.
The enemy already holds that ground; the civilians there start out with them. Like everything
else here, this does not apply in RAVAGE or WBK.

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
| Building damage | `server/misc/fnc_warcrimes_script.sqf` | **town** at `-2` inside a radius with a player within 200 m, and the escalation counter either way |
| Informant spawn chance | `server/misc/fnc_civ_informant_system.sqf:16` | **town** |
| Develop informant | `server/misc/fnc_civ_developInformantServer.sqf:15` | **town** |
| Ask for aid | `server/misc/fnc_civ_askForAid_server.sqf:15` | **town** |
| Ask for toolkit | `server/misc/fnc_civ_askForToolkit_server.sqf:15` | **town** |
| Recruit civilian | `shared/functions/fnc_civ_recruitAction.sqf:18` | **town** — must move server-side first |
| Ask enemy location | `shared/functions/fnc_addAskEnemyAction.sqf:36` | **town** — must move server-side first |
| Disguise break: reputation fell since the disguise went on | `server/misc/fnc_disguiseAsCivilian.sqf:105,253-255` | deleted, both ends of the chain |
| Disguise break inside an enemy-held town | `:257-268` | **town**, and the gate becomes the OPFOR band rather than any negative value |
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
| `server/server_fnc_init.sqf` | New `fnc_town_rep_adjust` beside `fnc_rep_adjust:151-159`; new `fnc_civ_townAt` position→index helper; new `fnc_civ_townRender` marker repaint; registry lines. Delete the WBK depopulation block `:1150-1160` and `fnc_updateIcon` `:1167-1175` with the live counter, plus its two `remoteExec` call sites `:1056,:1147`; drop the pop decrements in `fnc_wbk_survivorKilled_server` `:1040-1124` and `fnc_wbk_unitKilled_server` `:1127-1164`, keeping the `civ_remaining_%1` increment that feeds WBK replacements. |
| `server/misc/fnc_civ_init_Tomata.sqf` | Initialise `civ_town_rep` at 0; compute `civ_town_ap` from the kept set's building counts; `-20` for enemy-zone overlaps; delete the `_initialPop` derivation `:72-83` and store the building count as `civ_pop_%1`; three-field marker text at `:209`. |
| `server/misc/fnc_civ_rep_economy.sqf` | Delete the recovery thread `:12-38`; add the 30-minute AP tick; rewrite the file docstring. |
| `server/misc/fnc_civ_rep_Tomata.sqf` | Civilian death goes from `-0.3` to `-1` and routes through the town writer, resolving the town from the victim's `civ_locIndex` `:27`. Both existing gates stay, one retuned: the charge rate `:15` drops from 50 % to 30 % (`random 10 < 7`), and the 200 m player-present test `:17-23` is unchanged — so three in ten of the deaths a player is near are charged, an effective `-0.3` per death against `-0.15` today. Drop the notification `:28-31` and the `CIV_deaths` bump `:34-35`. |
| `server/server_var_init.sqf:79,93` | Remove `CIV_deaths`. Replace the `damagedBuildings` array with a single escalation counter: nothing reads the objects back, and an array holding a reference per destroyed house grows for the whole session — [`info/performance_hotspots.md`](info/performance_hotspots.md) already lists it as unbounded session state. |
| `info/performance_hotspots.md` | Drop the `damagedBuildings` entry from the session-growth section once the array is gone. |
| `server/misc/fnc_civ_handler.sqf` | Delete hostile conversion `:531-558`, hostile replacement `:381-383`, suicide bombers `:563-588`, and the depopulation block `:121-142` with its scorched-earth reward. Density from building count `:253-254`. Drop the pop decrement `:344-347`. |
| `server/init_zones/fnc_spawnWait.sqf` | Generalise the arrival re-test `:108-115` and despawn grace period `:134-146` so a town garrison uses them; the composition stow/deploy and `_manStatics` paths stay zone-only, since a town carries no props. |
| `server/misc/fnc_civ_handler_wbk.sqf` | Delete the depopulation block `:118-139`; drop the marker-text writes `:126,143,384`. Density `:251`. |
| `server/misc/fnc_civ_suicideBomberBehaviour.sqf` | Delete; behaviour preserved in `opfor_commander_plan.md`. |
| `server/misc/fnc_recruit_civilian_server.sqf:78-79` | Drop the population decrement and marker write. |
| `server/misc/fnc_warcrimes_script.sqf` | Delete; replaced by `fnc_escalation.sqf` — whole-map census, counter, level, cost multiplier, the level-11 loss, and the `-2` town charge when the building stood inside a civilian radius with a player within 200 m. The player-proximity test moves out of `fnc_civ_rep_Tomata.sqf:17-23` into a helper both paths call. |
| `server/server_fnc_init.sqf:170-184` | Scale `_cost` by the escalation multiplier in `fnc_pool_try_spend`, and `publicVariable` the multiplier so the menus can display it. |
| `server/misc/fnc_redeployHQUnits.sqf`, `fnc_activateBaseRepairStation.sqf`, `fnc_uav_scanner.sqf`, `fnc_pylon_set_with_cost.sqf` | Apply the multiplier individually: these four call `fnc_cp_adjust` directly and never reach the handshake. |
| `client/dialog/fnc_request_support.sqf` and its siblings | Lift the magic cost constants (`:13,31,52,…`) into one base-cost table the menu builder can read. Charging still goes through `fnc_pool_spend`. |
| `client/dialog/fnc_HQ_Request_Menu.sqf:81-119` | Suffix each row with the escalated price when the multiplier is not 1. Labels and stringtable keys untouched. |
| `server/misc/fnc_capture_zones_task.sqf:48,59-61` | Wait on win *or* level-11 loss, then branch. The loss path sets the `Campaign` task `FAILED` and calls `BIS_fnc_endMissionServer` in its two-argument form with `false`. |
| `server/misc/fnc_civ_informant_system.sqf:16`, `fnc_civ_developInformantServer.sqf:15` | Town rep. |
| `server/misc/fnc_civ_askForAid_server.sqf:15`, `fnc_civ_askForToolkit_server.sqf:15` | Town rep. |
| `server/misc/fnc_civ_fast_travel_server.sqf:13` | Destination town's rep. |
| `server/misc/fnc_disguiseAsCivilian.sqf` | Delete the `DUWS_disguise_startRep` snapshot `:105` and the fell-since-you-put-it-on test `:253-255`. The town test `:257-268` keeps its shape but gates on the OPFOR band instead of any negative value, and its lookup becomes the shared helper. |
| `shared/functions/fnc_civ_recruitAction.sqf`, `fnc_addAskEnemyAction.sqf` | Move the gate server-side, then read town rep. |
| `shared/functions/fnc_civ_lootAction.sqf:43-45`, `fnc_civ_healAction.sqf:69,72` | Resolve the town from the civilian acted on; drop the predicted-total line from both notifications. |
| `server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf:199,204,218-219` | Resolve from the escorted civilian; fall back to global. Drop both predicted-total notifications. |
| `server/missions/mission_threads/transport_idap/fnc_transport_IDAP_mission.sqf:231-233,247-249` | Resolve from delivery position; fall back to global. Drop both predicted-total notifications. |
| `shared/includes/enviro_menu.hpp:157-176` | Retitle `SE_frame` and `SE_combo` to the escalation toggle. Geometry and idcs are untouched, so no row below moves. |
| `shared/includes/notifications.hpp:347` | Delete the `SE` notification class. |
| `client/dialog/fnc_enviro_menu.sqf:55-57`, `fnc_process_enviro_menu.sqf:89-90`, `fnc_callsign_confirm.sqf:60` | Drop the scorched-earth setting. |
| `client/client_init.sqf:395-396`, `server/misc/fnc_intro_heli.sqf:226-229` | Drop the scorched-earth announcements. |
| `src/stringtable.xml` | Remove `STR_DUWS_T_repup`, `STR_DUWS_T_0pluxey2`, the six scorched-earth keys, and the suicide-bomber / ghost-town keys orphaned by the deletions; add the marker field labels and a numberless replacement body for the loot notification. Keep the shared enabled/disabled pair. |
| `info/cp_economy.md` | Second reputation writer, the `±20` clamp, the town AP faucet, recovery removed. Its reputation-tick row still points at `fnc_civ_init_Tomata.sqf:237`; the loop moved to `fnc_civ_rep_economy.sqf`. |
| `info/zone_and_town_generation.md` | The enemy-zone overlap rule, and its Defects-B entry on towns blocking capture, which removing hostile civilians resolves. |
| `info/arma_engine_gotchas.md` | `setMarkerColor` accepts an inline `#(r,g,b,a)` string, not only a `CfgMarkerColors` class name. |

## Remaining verification

The code is in; these are the play-test checks that cannot be settled from the source. Two of
them can invalidate a section, so run them before tuning anything downstream.

- [ ] Confirm a dedicated server receives `BuildingChanged` for damage a client caused. Verify: a client-destroyed house increments the counter on a dedicated host. If it does not, escalation is single-player-only and that gets recorded rather than worked around.
- [ ] Confirm CIVILIAN-side units do not block `WEST SEIZED`. Verify: a garrison cleared in a populated town fires its trigger. If civilians block it, swap to a condition trigger counting hostile units in `thisList`.
- [ ] Confirm `ESCALATION_FRACTION` at 10 % against the measured Altis census, and that the census cost is tolerable. Both are logged to the RPT on the first run. Verify: a single fire mission cannot advance a level.
- [ ] Confirm the neutral ellipse renders translucent, which settles whether the inline string's alpha channel does anything or `setMarkerAlpha` is carrying it alone.
- [ ] Confirm the global still gates partisan hiring and the CP tick as before.
- [ ] Confirm RAVAGE and WBK register towns with a `Pop:`-only marker and a permanently neutral ellipse, spawn no garrison, never scale prices, and log no census line.

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

**The routes into each band are not symmetric, and the negative one is far shorter.** From the
baseline of 0 both bands are ten points away, but the travel costs are nothing alike. Going
negative is incidental and cheap: a civilian death at `-1` (`fnc_civ_rep_Tomata.sqf:27`, charged
three times in ten and only with a player inside 200 m, so about thirty-three kills) puts a town
on the band edge, a building at `-2` under the same 200 m guard gets there in five, and a failed
IDAP at `-5` covers half the distance on its own. Going positive is deliberate and slow: healing
a civilian at `+0.5` needs twenty heals to reach the BLUFOR band, against IDAP success at `+5`
and protect-civ success.

Both negative routes require the player to be present, so a town only changes hands over things
that happened in front of them. Demolition is much the faster of the two — five buildings
against thirty-odd deaths — because the building charge carries no rate roll at all. That gap is
intended. The rate roll is what stops a firefight in a populated town from turning it on stray
rounds, and it can sit as low as 30 % precisely because reputation is localised now: a bad
engagement costs the campaign nothing outside the town it happened in. Deliberate demolition
carries no such excuse, so it is charged every time.

That gap is the mechanic, not an oversight. Ordinary fighting drags a town toward the enemy and
no amount of ordinary fighting drags it back, so the routes out of the OPFOR band are the ones
built for it: clearing the garrison, which discharges the whole debt at once, and the aid
missions. The `-0.3` civilian cost this replaces was small enough that a town could absorb
sixty-odd deaths without changing hands, which is what made civilian ground inert.

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

**Towns key on the array index, not on their name.** `civ_town_rep` and `civ_town_ap` are
index-parallel to `civ_locations`, which is what every existing civilian consumer already keys
on. Keying on the town name would read better in the RPT but breaks the moment two map towns
share a name, which Altis does not guarantee. The registry has no fixed length: the selector
takes `_PER_ANCHOR_CAP` towns per anchor plus a top-up sized to the zone count
(`server/misc/fnc_civ_selectTowns.sqf:16,107,115`), and the overlap cull then shortens it, so
both arrays are built against `count civ_locations` rather than any assumed town count.
