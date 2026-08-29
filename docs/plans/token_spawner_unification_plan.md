# Plan: route team spawns through the token spawner

Many scripted spawns called `BIS_fnc_spawnGroup` directly. The token spawner — `fnc_spawn_team` /
`fnc_spawn_vehicle` over the `DUWS_teamRosters` table, the faction pools and the posture applier — is
the intended way to raise a team that patrols or garrisons, and this plan routed the remaining team
callers through it.

The scope is deliberately narrow: a **team raised from a roster row under a posture**. Individual-unit
spawns, civilians, air support and static-weapon crewing are out — they do not share that shape and
gain nothing from it.

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
  `garrison` posture — it raises men by a rule, not a roster. And the WARCOM BLUFOR patrol
  (`fnc_WARCOM_blu_patrol`) spawns a whole faction section — a vehicle plus its roster dismounts,
  pre-built in `fnc_BLUFOR_squad_init` — which is neither a roster team nor a single vehicle; it is
  slated for removal (see Cleanup).
- **Out, separate concern:** static-weapon crewing — putting a gunner on an emplaced gun is not raising
  a patrol. It is its own refactor, tracked elsewhere, and never part of this plan.

## Done

The migration is complete on disk (unverified in-game). Every hardcoded team classlist now resolves a
faction-safe roster token:

- **`_anchors` passthrough.** `fnc_spawn_team` forwards `fnc_apply_posture`'s fixed-anchor argument, so
  an `hqpatrol` team — a circuit through caller-named points rather than a radius band — can be raised
  through the token spawner.
- **Loot gated to OPFOR.** `fnc_spawn_team` and `fnc_spawn_vehicle` add random loot only for an
  OPFOR-side raise: an enemy is the player's to search, a friendly team is not.
- **FOB and HQ patrols on the `squad` token**, walking their corner and tower anchors under `hqpatrol`;
  `base_patrol_squad` is deleted, both patrols being whole-team tokens now rather than a scaled count.
- **Mission and zone teams on their tokens.** The protect_civ assault (`squad`), the target_sniper pair
  (`sniper_element`), the rescue_squad captives (`recon`) and the hardpoint garrison teams (their own
  token) each replaced a hardcoded classlist with a pool draw under posture `none` or the token's own.

## Cleanup

- **Retire `fnc_WARCOM_blu_patrol`.** The BLUFOR strategic patrol is unwanted: drop the thread, its
  spawn in `fnc_WARCOM_init.sqf:62`, and its compile in `server_fnc_init.sqf:272`. It runs today rather
  than being literally dead, so the removal is a deliberate feature retirement, not a dead-code sweep.

## Decisions (settled)

1. **The token spawner raises roster teams under a posture.** Individual units, civilians, air support
   and static crewing stay out — none share the roster / posture shape.
2. **A count-scaled *patrol* converts to a fixed roster token; a building ring does not.** The FOB and
   HQ patrols became `squad` — a perimeter or tower circuit maps onto a whole-team token. The
   side-mission building ring stays bespoke: it scales by building count and holds via
   `fnc_spreadIntoBuildings`, a shape no single roster expresses.
3. **No new roster rows.** Every migrated caller mapped onto an existing token — `squad`,
   `sniper_element`, `recon`, the hardpoint's own — so the shared table and the composition tool gained
   nothing to maintain.
4. **Loot is OPFOR's.** Only an OPFOR-side raise drops lootable gear; a friendly team does not.
5. **The RAVAGE/WBK civilian handler stays separate**, per the existing mode-separation rule.

## Task list

- [ ] Play-test the migrated spawns — FOB and HQ patrols, the protect_civ assault, the target_sniper
      pair, the rescue_squad captives, the hardpoint garrison — code-complete but unverified in-game.
- [ ] Retire `fnc_WARCOM_blu_patrol` (the thread, its spawn call, and its compile registration).
