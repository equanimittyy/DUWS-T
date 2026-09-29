# Unit spawning: three systems

Groups in `duws/` are raised three ways, chosen by *what* is being raised — a team that patrols or
garrisons, a crew for an emplaced weapon, or a one-off that fits neither. The three are not
interchangeable: each owns concerns the others drop or fight, so picking the wrong one is a bug, not a
style choice. This records the split and the rule for choosing.

## 1. Token spawner — teams that patrol or garrison

`server/placement/fnc_spawn_team.sqf` and `fnc_spawn_vehicle.sqf` raise a team from a composition
*token* — a row on `DUWS_teamRosters` (`shared/functions/fnc_spawn_vocab.sqf`) that names bare roles,
drawn from the detected faction's pools. One call resolves the side, the AI skill, random loot, the
spawn position and the patrol orders. Use it for any team that patrols or garrisons a zone, a base or a
mission objective.

Signature: `[_team, _center, _radius, _posture, _spawnPos, _side, _anchors, _floor] call fnc_spawn_team`.

- **Both armies.** `_side` (`"opfor"` / `"blufor"`, default `"opfor"`) drives the engine side, the
  skill globals and the roster prefix from one string. CIVILIAN is deliberately not a value — only the
  two armies have a role vocabulary and skill globals, so a civilian group has no pool to draw and stays
  bespoke (system 3).
- **A posture, not a hand-written waypoint.** `_posture` selects the circuit and the spawn band through
  `fnc_apply_posture` and `DUWS_postureBands`: a close or wide patrol, a one-squad `garrison`, an
  `hqpatrol` circuit through the `_anchors` points, or `"none"` for exact placement at a supplied
  `_spawnPos`.
- **A player floor, on request.** `_floor` (metres, 0 for none) keeps the band point, and the building a
  `garrison` takes, that far from every living player. A band with no clear point raises nothing
  (`grpNull`). Only the zone and town raise pass one, the reserve floor; see
  [`garrison_and_reserves.md`](../gameplay/garrison_and_reserves.md).
- **Loot is OPFOR's.** Random loot (`fnc_addRandomLoot`) is added only for an OPFOR-side raise: an enemy
  team is the player's to search, a friendly one fought alongside is not. Searchable bodies also feed
  faction detection, so loot must never be added to a group that should carry none — which is why the
  gate is on side, not left to the caller.
- **A token, not a raw class list.** `DUWS_fnc_teamRoster` looks the name up and returns nothing for an
  unknown token, so a one-off or dynamically built class list has no row to name and cannot use this API
  until a row is added for the recurring case.

Data, not code: a team added to the roster table is spawnable without touching a script, which is what
lets the composition TUI add one (see [`composition_tooling.md`](composition_tooling.md)).

## 2. Static crewing — a gunner on an emplaced weapon

Crewing an already-placed static weapon is its own operation: seat the gunner while the gun's simulation
is frozen, then thaw, or the turret spawns unable to traverse (see
[`arma_engine_gotchas.md`](arma_engine_gotchas.md)). It raises no patrol and takes no posture, so it
never routes through the token spawner.

- `DUWS_fnc_seatStatic` crews the statics a zone streams in
  (`server/init_zones/fnc_zone_stream_init.sqf`).
- `server/missions/fnc_place_bunker_guns.sqf` crews the two bunker guns of the destroy-cache and
  destroy-radar objectives — one OPFOR rifleman per gun, merged into a single garrison group.

## 3. Bespoke direct spawn — no team shape to share

Everything else calls `BIS_fnc_spawnGroup` / `BIS_fnc_spawnVehicle` directly, because it shares neither
a roster nor a posture and gains nothing from the token path. These are not unmigrated debt; they are
raises that do not fit a team.

| What | Where | Why bespoke |
|---|---|---|
| Player-summoned assets | CAS, transport and attack helis, paradrop, vehicle drop, ammo box, artillery (`client/supports/`) | offmap or scripted delivery, not a patrolling team |
| Player-hired friendlies | operative recruit, PMC, partisans, HC squads, MHQ deploy (`server/misc/`, `server/dialog/`) | placed on the player, with no zone to garrison under |
| Civilians | the transport-IDAP delivery group, the protect-civ VIP, the RAVAGE/WBK handler | no role vocabulary or skill pool; the WBK handler is mode code kept separate by rule |
| Bandits | `fnc_bandit_spawn` (`server/bandits/`) | a bandit is a re-dressed FIA body, not a roster class, and the token spawner serves only the two armies |
| Rule-scaled, not roster | the side-mission building ring (`fnc_garrisonBuildings`), scaling men by building count | a rule raises the men; no single roster row expresses it |
| Bespoke seating / routing | the deny-armor convoy hulls and their repair crew, the rescue-pilot WEST pilot group | a posture band would fight the self-routing convoy or the follow behaviour |
| Cutscene / training | the intro heli, the killhouse | one-shot scenery |

A single mission thread can use more than one system: `deny_armor` raises its escort dismounts through
the `team` token but its convoy hulls and repair crew direct, and `transport_idap` raises its guards
through tokens but its civilian delivery group direct.

## Migration record and open items

The mission-thread teams that *did* share the team shape were routed onto tokens: the FOB and HQ
patrols, the protect-civ assault, the target-sniper pair, the rescue-squad captives and the hardpoint
garrison. The unwanted BLUFOR strategic patrol (`fnc_WARCOM_blu_patrol`) fit neither the team token
nor the vehicle token and was retired outright rather than migrated, along with the dead WARCOM
attack-wave leftovers. One thing remains:

- **The WEST follow-groups and one-off waves stay direct by choice.** Routing the rescue-pilot pilot or
  the protect-civ VIP through the token spawner would hand it a posture and loot it should not have; each
  stays bespoke until it earns a roster row, which most never will.
