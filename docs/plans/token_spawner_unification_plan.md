# Plan: route scripted spawns through one token spawner

Most scripted group spawns in the mission still call `BIS_fnc_spawnGroup` / `BIS_fnc_spawnVehicle`
directly, each open-coding the same five decisions — engine side, crew skill, which men to draw,
what the group then does, and (for a posed unit) a broadcast animation. The token spawner already
folds those into one place for the zone bands and a few missions, but only for the two armies and
only for combat postures. This plan widens it to a single spawner that serves BLUFOR, OPFOR and
CIVILIAN over one token grammar, with animation expressed as a posture.

The companion documents are the [architecture hardening plan](./architecture_hardening_plan.md),
whose Phase 3 owns this migration at a high level and points here for the detail, and the
[mission spine unification plan](./mission_spine_unification_plan.md), which is the parallel
"finish one migration" effort for the mission lifecycle.

## Goal

One entry point raises every scripted group: a zone garrison, a mission assault, an HQ sentry and a
civilian all resolve a token, draw from the right side's pool, take a posture, and return a handle
the caller can post-process. The payoff is not the call-site count — that is small — but that the
recurring correctness traps (a local-effect animation that never reaches joined clients, a nil role
that silently spawns a man short, a side/skill mismatch) are solved once in the shared shape instead
of re-solved per caller.

## Scope

- **In:** enemy zone and garrison groups, mission-thread combat groups, HQ base guards and poses,
  and civilian spawns once civilians are tokenised.
- **Out, stays bespoke:** air support (offmap scripted flight, ammo-stripped, per-sortie event
  handlers — no gain from the shared shape), and the RAVAGE/WBK civilian handler (mode-specific
  survivor/zombie logic kept off the vanilla civilian path).
- **Separate function, not the team spawner:** static weapon crewing. Crewing a gun is not raising a
  patrol; it belongs in its own helper (Phase C).

## What the spawner is missing

Three gaps stand between today's spawner and the scope above.

- **Civilians have no abstraction key.** `civ_array` (`shared/factions/CIV_FACTIONS.sqf:6`) is one
  flat, map/mod-gated list of civilian man classes, and there is no civilian-vehicle list at all.
  There is no `civ_*` DUWS key the spawner can resolve one civilian, or one civilian vehicle, from —
  the way a soldier resolves from `blufor_SOLDIER_X`.
- **Animation is not a posture.** Posed units hand-roll a broadcast-keyed `switchMove` at each site.
- **Small gaps.** `fnc_spawn_team` does not pass `fnc_apply_posture`'s optional `_anchors`, and two
  in-scope compositions have no roster row yet.

## Phase A — animation in the shared shape

Animation belongs to posture, because a posture already answers "what does this group do once it is
standing." A sentry that plays a guard idle is one decision, not a stance plus a separate animation
axis.

- Add a `sentry` posture to `fnc_apply_posture` (`server/init_zones/fnc_apply_posture.sqf:65`): hold
  position (`disableAI` PATH/MOVE) and play an idle stance. It sits beside the existing `none` case
  (`:247`), which already places on an exact point and leaves orders to the caller.
- Provide a pose helper that plays the animation with `remoteExec ["switchMove", 0, "<netId-key>"]`.
  This is the load-bearing constraint: `switchMove` / `playMove` are local-effect, so a server-side
  pose animates only on the host and is lost on every join-in-progress. The HQ code already proves
  the pattern (`server/init_hq/fnc_BluHQinit.sqf:415`, `:455`; `protect_civ.sqf:95`) — centralising
  it removes the footgun where a caller forgets the key. Use a raw `switchMove`, not
  `BIS_fnc_ambientAnimCombat`, which breaks its own animation (`fnc_BluHQinit.sqf:367`).
- Name poses as presets in a posture→animation table (data), so a token names `sentry` and the
  animation stays out of the token string — the composition TUI splits on commas and colons and
  cannot carry a free animation name. A genuine one-off pose is passed as an optional caller
  argument, used only by `call`-site callers, never by TUI compositions.
- Pass `_anchors` through `fnc_spawn_team` to `fnc_apply_posture`, so the `hqpatrol` posture that
  walks caller-named towers and corners becomes reachable from a token raise.

Migrates the HQ guards and poses (`guardsFOB`, `placeHQUnits`, `fortifyFOB`, `BluHQinit`) and the
posed mission units that raise-then-pose (`rescue_pilot`, the captive in `rescue_squad`).

## Phase B — a civilian abstraction key

Civilians need one DUWS key that abstracts "a civilian man" and one that abstracts "a civilian
vehicle" — resolved the same way a soldier resolves from `blufor_SOLDIER_X`. They do **not** need
team-roster rows (a civilian is placed one at a time, not as a five-man card) and they do **not**
belong in `fnc_faction_schema`, whose two-column BLUFOR/OPFOR shape drives the player-facing
confirmation screen that civilians never appear on. Keeping civ out of that apparatus is what makes
this phase small.

- Add the single-key resolution path to the spawner: a token that matches no `DUWS_teamRosters` row
  is treated as one DUWS key, `<side>_<name>`, resolved through the faction pool to raise one man
  (`fnc_spawn_team`) or one vehicle (`fnc_spawn_vehicle`). This is the individual-key half of the
  grammar and is uniform across all three sides; today a non-team token resolves to nothing.
- Define the two civilian keys where `civ_array` already lives (`shared/factions/CIV_FACTIONS.sqf`):
  a man key backed by `civ_array`, and a vehicle key backed by a new civilian-vehicle list,
  map/mod-gated the way `civ_array` already is. Publish the civilian pools the way the AutoDetect
  files publish theirs. No `fnc_faction_schema` row, no confirmation-screen change.
- Thread `_side = "civ"` through `fnc_spawn_team` and `fnc_spawn_vehicle`: engine side CIVILIAN, the
  `civ_*` pool prefix, and no combat skill — there is no `civ_ai_skill`, and a civilian needs none,
  so default it low rather than falling back to the OPFOR skill.

Migrates the vanilla civilian spawns — the protected VIP (`protect_civ.sqf:64`) and the IDAP delivery
(`transport_IDAP.sqf:137`). It does **not** touch the RAVAGE/WBK handler. The hired partisans and PMC
draw `civ_array` as WEST-side combatants, not civilians, and stay as they are.

## Phase C — a static-crewing function

`fnc_crew_static [_weapons, _soldierClass, _side]`: raise the crew, seat them while frozen
(`DUWS_fnc_seatStatic`), thaw, then `taskDefend`. Seating before the thaw is required or the turret
fires straight ahead and never traverses. This absorbs the eleven crew-for-static callers, none of
which want a patrol circuit: `hardpoint_place.sqf:113` and `:126`, `zone_stream_init.sqf:197` and
`:232`, `modern_simple_zone.sqf:106` and `:113`, `place_bunker_guns.sqf:10` and `:12`,
`deny_armor_mission.sqf:120`, `fortifyFOB.sqf:165`, and `placeHQUnits.sqf:95`.

## Phase D — route the combat groups

Six callers raise a combat group that the team or vehicle spawner should own.

| caller | cost | move |
|---|---|---|
| `hardpoint_place.sqf:150` | cheap | already reimplements `fnc_spawn_team` inline; replace with a real `call`, keep the maxSpot skill boost on the returned units |
| `target_sniper_mission.sqf:65` | cheap | resolves the shipped `sniper_element` row; raise with `none` posture and the perch as `_spawnPos`, keep the per-man perch spread on the handle |
| `garrisonBuildings.sqf:45` | dear | needs a new `DUWS_teamRosters` row for the town mix `[SOLDIER, AA, AR, AT, LAT, SL]`; scale by building count with `DUWS_fnc_scaleComposition`; the `garrison` posture replaces the hand-rolled `fnc_spreadIntoBuildings` |
| `protect_civ.sqf:221` | dear | needs a new row for the eight-man leaderless assault `[2 SOLDIER, 3 AR, LAT, GL]`; `none` posture plus the caller's own SAD waypoint |
| `rescue_squad_mission.sqf:62` | medium | men are the shipped `recon` row; raise with `none` posture, then apply the captive state and per-building pin on the returned handle |
| `WARCOM_blu_patrol.sqf:67` | medium | route through `fnc_spawn_vehicle`; guard the tier-1 case where the patrol "type" is a lone infantryman rather than a vehicle class |

## Decisions (settled)

1. **One spawner, three sides, one grammar.** BLUFOR, OPFOR and CIVILIAN resolve the same token
   through per-side pools. Air support stays bespoke.
2. **Civilians get abstraction keys, resolved by the single-key path.** One civilian-man key and one
   civilian-vehicle key, resolved as `<side>_<name>` like any DUWS key — not team-roster rows and not
   the two-army schema/confirmation apparatus, which civilians never touch.
3. **Animation is a posture, and the broadcast key is mandatory.** `switchMove` is local-effect; a
   pose without `remoteExec [..., 0, key]` is invisible to joined and JIP clients.
4. **Static crewing is not a team.** It gets its own function; the team spawner never crews a gun.
5. **The RAVAGE/WBK civilian handler stays separate**, per the existing mode-separation rule.

## Task list

- [ ] Phase A: `sentry` posture, broadcast-keyed pose helper, posture→animation table, `_anchors`
      passthrough; migrate the HQ guards/poses and the posed mission units.
- [ ] Phase B: single-key resolution path; two civilian keys (man + vehicle) with a civilian-vehicle
      list, `_side = "civ"` plumbing and pool publish; migrate the VIP and IDAP civilian spawns.
- [ ] Phase C: `fnc_crew_static`; migrate the eleven crew-for-static callers.
- [ ] Phase D: two new roster rows; migrate the six combat callers, cheap swaps first, each verified
      by `bash tests/run.sh` and a play-test of the one behaviour it touched.
