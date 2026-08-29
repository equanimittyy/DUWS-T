# Plan: route team spawns through the token spawner

Many scripted spawns still call `BIS_fnc_spawnGroup` / `BIS_fnc_spawnVehicle` directly. The token
spawner — `fnc_spawn_team` / `fnc_spawn_vehicle` over the `DUWS_teamRosters` table, the faction pools
and the posture applier — is the intended way to raise a team that patrols or garrisons, and this plan
finishes routing the remaining team callers through it.

The scope is deliberately narrow: a **team raised from a roster row under a posture**. Individual-unit
spawns, civilians and air support are out — they do not share that shape and gain nothing from it.

Companion documents: the [architecture hardening plan](./architecture_hardening_plan.md), whose Phase 3
owns this migration at a high level, and the
[mission spine unification plan](./mission_spine_unification_plan.md).

## Goal

One entry point raises every team that patrols or garrisons a zone, a base or a mission objective: it
resolves a roster token, draws from the side's faction pool, takes a posture, and returns the handle
the caller keeps. The payoff is that the roster / pool / posture / attrition model applies everywhere
rather than being hand-rolled at each call site.

## Scope

- **In:** enemy zone and garrison teams, HQ and FOB patrols, and mission-thread combat teams —
  anything raised from a roster row under a posture.
- **Out, stays bespoke:** individual-unit spawns (posed scenery, single sentries, a mission's VIP or
  downed pilot) — not teams, with no roster or posture to share; all civilian spawns (civilians are
  never auto-detected, so `civ_array` is a flat list a caller reads directly and a token over it
  abstracts nothing); air support (offmap scripted flight, ammo-stripped); and the RAVAGE/WBK civilian
  handler.
- **Out, bespoke by design:** the side-mission building ring (`fnc_garrisonBuildings`) scales its men
  by building count and spreads them with `fnc_spreadIntoBuildings`, not the one-squad-one-structure
  `garrison` posture; its own header records the choice. It raises men by a rule, not a roster, so no
  token expresses it.
- **Separate function:** static weapon crewing — crewing a gun is not raising a patrol.

## Landed

- **`_anchors` passthrough.** `fnc_spawn_team` now forwards `fnc_apply_posture`'s fixed-anchor
  argument, so an `hqpatrol` team — a circuit through caller-named points rather than a radius band —
  can be raised through the token spawner.
- **FOB patrol on the `squad` token.** `fnc_guardsFOB` was a count-scaled draw — `base_patrol_squad`
  copies of a random guard type — and is now the shared `squad` composition drawn from the faction
  pool, walking its corner anchors under `hqpatrol`. This is a deliberate change: a fixed whole-team
  token replaces a hand-scaled count, which is the model the spawner is built on (attrition is a ledger
  of lost whole tokens). It drops the `base_patrol_squad` tuning for the FOB; the HQ patrol still reads
  that global until it is migrated the same way.

## Remaining

| caller | cost | move |
|---|---|---|
| `placeHQUnits.sqf:171` (HQ patrol) | cheap | mirror the FOB migration: `squad` token, `hqpatrol`, the tower anchors — retires the last `base_patrol_squad` reader |
| `hardpoint_place.sqf:150` | cheap | already reimplements `fnc_spawn_team` inline; replace with a real `call`, keep the maxSpot skill boost on the returned units |
| `target_sniper_mission.sqf:65` | cheap | resolves the shipped `sniper_element` row; raise with `none` posture and the perch as `_spawnPos`, keep the per-man perch spread on the handle |
| `protect_civ.sqf:221` | cheap | the existing `squad` token, `none` posture at the spawn point; keep the assault settings (AWARE, RED, allowFleeing 0) on the returned handle — accepts the eight-man leaderless assault becoming the nine-man squad |
| `rescue_squad_mission.sqf:62` | medium | men are the shipped `recon` row; raise with `none` posture, then apply the captive state and per-building pin on the handle |
| `WARCOM_blu_patrol.sqf:67` | medium | route through `fnc_spawn_vehicle`; guard the tier-1 case where the patrol "type" is a lone infantryman rather than a vehicle class |

## Static-crewing function

`fnc_crew_static [_weapons, _soldierClass, _side]`: raise the crew, seat them while frozen
(`DUWS_fnc_seatStatic`), thaw, then `taskDefend`. Seating before the thaw is required, or the turret
fires straight ahead and never traverses. Absorbs the eleven crew-for-static callers:
`hardpoint_place.sqf:113` and `:126`, `zone_stream_init.sqf:197` and `:232`,
`modern_simple_zone.sqf:106` and `:113`, `place_bunker_guns.sqf:10` and `:12`,
`deny_armor_mission.sqf:120`, `fortifyFOB.sqf:165`, and `placeHQUnits.sqf:95`.

## Decisions (settled)

1. **The token spawner raises roster teams under a posture.** Individual units, civilians and air
   support stay bespoke — none share the roster / posture shape.
2. **A count-scaled *patrol* converts to a fixed roster token; a building ring does not.** The FOB
   patrol became `squad` — a perimeter patrol maps onto a whole-team token, which is the model the
   spawner is built on. The side-mission building ring stays bespoke: it scales by building count and
   holds via `fnc_spreadIntoBuildings`, a shape no single roster expresses.
3. **No new roster rows.** Every remaining team caller maps onto an existing token — `squad` for the
   patrols and the assault, `sniper_element`, `recon`, the hardpoint's own — so the shared table and
   the composition tool gain nothing to maintain.
4. **Static crewing is its own function**, never the team spawner.
5. **The RAVAGE/WBK civilian handler stays separate**, per the existing mode-separation rule.

## Task list

- [ ] Migrate the HQ patrol to the `squad` token (mirror of the FOB patrol) and delete `base_patrol_squad`.
- [ ] Route the remaining roster-team callers onto existing tokens (`squad`, `sniper_element`, `recon`,
      the hardpoint token), cheap swaps first; each verified by `bash tests/run.sh` and a play-test of
      the one behaviour it touched.
- [ ] `fnc_crew_static`; migrate the eleven crew-for-static callers.
