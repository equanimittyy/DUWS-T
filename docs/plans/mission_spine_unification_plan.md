# Plan: put the simple and medium side missions on one shared spine

## Goal

`fnc_mission_run` (`src/duws/server/missions/fnc_mission_run.sqf`) is the shared spine for
default-shaped side missions: `fnc_mission_begin` -> `fnc_mission_site` -> marker ->
`fnc_missionTaskCreate` -> run `_build` (spawn + claim the objective, return handles) -> play
`_brief` -> `sleep 5` -> `waitUntil {sleep 2; (_handles call _done) || time > _deadline}` -> on
timeout `fnc_mission_deadline_fail`, else `_endLine` + SUCCEEDED + reward + `fnc_mission_end`. Only
three of nineteen threads use it today (`target_armor`, `target_sniper`, `target_recon`); the other
sixteen inline their own copy of that sequence.

Move every mission whose win reduces to a single 2-second-pollable predicate onto the spine, so the
sequence lives in one file and a new simple mission is a spec, not a copied thread. Six missions whose
logic is a multi-stage state machine stay hand-written on purpose (see
[Why six stay bespoke](#why-six-stay-bespoke)). Target end state: ~12-13 threads on the spine, 6
bespoke.

## Scope: all nineteen classified

The deadline footer ("You have until HH:MM") is already universal and unaffected by this work: it is
appended centrally in `fnc_missionTaskCreate.sqf:16-20`, gated on a live `DUWS_curDeadlineAt`, which
every row in `src/duws/shared/includes/mission_types.hpp` carries. Migrating a thread does not touch
it — the spine calls the same `fnc_missionTaskCreate`.

| Bucket | Missions | Action |
|---|---|---|
| On spine already | target_armor, target_sniper, target_recon | none |
| Tier 1 — one predicate + timeout | destroy_radar, destroy_patrol_camp, destroy_cache, steal_supply, steal_builder, transport_idap | migrate |
| Tier 2 — one predicate, bespoke siting | destroy_tower, destroy_hardpoint, sabotage_laptop | migrate |
| Assess | recon_observe | decide on read |
| Bespoke — multi-stage | rescue_squad, target_hvt, rescue_pilot, deny_armor, protect_civ, informant | leave |

Tier 1 is genuine copy-paste of the spine and pays to consolidate. Tier 2 shares the same
win/fail/teardown boilerplate but finds its target a different way, so it migrates only once siting is
pluggable. The bespoke tier shares almost no code between its members; forcing it onto a common runner
adds indirection without removing duplication.

## Harness extensions

Four optional additions to the spec, all with defaults that reproduce today's behaviour byte-for-byte.

**Core invariant: every new field is default-off, and the shared `waitUntil` predicate must
short-circuit on an empty `_lost` so the three current callers and every already-migrated mission stay
identical.** A change to the poll line is the one edit that touches all callers at once; guard it.

- `_lost` — list of `[predicate, [speakerKey, msgKey]]`. Early-lose paths (the prize is destroyed
  before delivery) that are not the timeout. Polled beside `_done`; on trip, speak the line, end the
  task FAILED, call `fnc_mission_end`. Default `[]` (no extra predicate, no branch).
- `_onWin` — callback run after the task is set SUCCEEDED and before reward/teardown. Post-win side
  effects that are not standard teardown. Default `{}`.
- `_cleanup` — callback run on both exit paths. For loose `spawn`/`execVM` side-threads that group
  claim (`fnc_mission_claim` + composition key) does not cover. Default `{}`.
- `_site` — strategy returning `[_randomPos, _Building, _targetpos]`. Default is the current inline
  `fnc_mission_site` call. Overrides: enumerate an existing hardpoint row; scan a town building.

Each field is added in the phase whose first mission needs it, never ahead of a caller. Add fields at
the tail of the `_spec params` list (`fnc_mission_run.sqf:33-36`) so the existing three specs keep
parsing unchanged, and update the spec-doc header in the same edit.

## Phases

Ordered low-risk first. Each phase is independently shippable; stop at any.

### Phase 0 — baseline

Before touching a target, play-test it once and keep the RPT (the repo convention is
`workspace/temp/logs`), noting task text, dialogue order, and beat timing. This is the diff reference
every later migration is checked against.

### Phase 1 — no harness change

Migrate `destroy_radar`, then `destroy_patrol_camp`. Each: write the spec (`_build` = the existing
spawn block, `_done` = the existing win predicate, dialogue -> `_brief` / `_endLine` / `_failLine`),
delete the inline spine, terminate with `[_MissionPos, _mission_name, _spec] call fnc_mission_run`.
`destroy_patrol_camp`'s multi-camp spawn loop moves wholesale into `_build` and returns the camp-unit
array its `all-dead` predicate tests. Nothing is shared-code here, so the three missions already on the
spine cannot regress.

### Phase 2 — add `_onWin`

Migrate `destroy_cache`. Its win is a compound predicate on the two boxes; the post-win cook-off
becomes the `_onWin` body, or a killed-event-handler inside `_build` if that reads cleaner on the file.
Re-test one existing spine mission to confirm the default `{}` hook is a true no-op.

### Phase 3 — add `_lost`; introduce the dressing helper

Migrate `steal_supply`, the cleanest of the delivery set: win is
`_truck1 distance PosOfBLUHQ < 100` (`fnc_steal_supply_mission.sqf:104-106`); the destroyed path folds
into the timeout branch today (`:111-116`), so `_lost = [[{!alive _truck1}, [OVERLORD, supplytruckfail]]]`
reproduces it. Decide when editing whether to keep the `setDamage 1` inside the lost handler. Same
commit introduces `fnc_mission_dressing [_vehpos, _compKey]` for the cosmetic clutter block
(`CargoNet_01_barrels_F` x3 + `CamoNet_INDP_open_F`) duplicated across `steal_supply:68-79`,
`steal_builder:60-71`, and `transport_idap:55-66`. Verify the destroyed, timeout, and win paths
separately.

### Phase 4 — steal_builder and transport_idap

Both reuse `_lost` + `_onWin` and add `_cleanup`.

`steal_builder`: `_lost` on `!alive BLD1`; `_onWin` runs the R3F factory `execVM` and client
`BIS_fnc_MP` init (`fnc_steal_builder_mission.sqf:111-116`). The pre-`fnc_mission_begin` gate that
refuses when a builder already exists (`:7-11`) stays in the thread wrapper — it runs before begin, so
it cannot live in the spec; the wrapper does the guard, then calls `fnc_mission_run`.

`transport_idap`: `_lost` on the truck's destruction; the spawned smoke and unit-animation threads go
in `_cleanup` (or become claimed handles). Decide on read.

### Phase 5 — add `_site`; the hardpoint pair

Migrate `destroy_tower` and `destroy_hardpoint`. Their win is a valid predicate — a row leaving the
`DUWS_hardpoints` global — so what blocks them is only siting: they enumerate an existing emplacement
instead of calling `fnc_mission_site`. `_site` = hardpoint-enumerate, `_done` =
`{(DUWS_hardpoints findIf {...}) < 0}`, `_build` minimal (the target pre-exists, nothing to spawn).

### Phase 6 — sabotage_laptop

`_site` = town-building scan. `_build` places the laptop plus a holdAction that sets a mission flag on
completion, and spawns the garrison. `_done` polls that flag. Drop the bespoke spawned timeout watcher
— the spine owns the timeout. Test the flag's server broadcast under the holdAction carefully.

### Phase 7 — assess recon_observe

Deep-read first. Migrate only if the win reduces to a predicate and the client-side reveal layer can
ride `_onWin` or a `remoteExec` inside `_build`; otherwise leave it bespoke.

## Why six stay bespoke

`rescue_squad`, `target_hvt`, `rescue_pilot`, `deny_armor`, `protect_civ`, and `informant` are
multi-stage: sequential stages with per-stage task updates and dialogue (`rescue_pilot` reach ->
escort -> extract), parallel monitor threads (`informant` hunt + exfil + win-monitor at once), or a
convoy race with a custom progress loop (`deny_armor`, `target_hvt`). Unifying these means turning the
spine into a stage runner — a list of stages each with its own build / task / done / fail / dialogue,
plus a cleanup registry and thread supervision — which is a mission-scripting subsystem, not a hook.

The spine's value is deleting copy-paste. These six do not copy each other; each is unique logic with
little to share, so a common runner would remove no duplication and only add a layer between the reader
and already-bespoke code. Every general hook added to swallow them also taxes the simple missions that
are the point. The honest architecture is a spine for the simple and medium tiers and hand-written
threads for the complex ones — not one spine for all nineteen.

## Verify protocol

One mission per cycle: migrate, play-test, diff the RPT against the Phase 0 baseline, confirm the task
footer, deadline, dialogue order, and teardown match, then move to the next. No batch migrations. After
any edit to `fnc_mission_run`, re-test one pre-existing spine mission to confirm the new hook is a
no-op when unset. Commit per mission or per phase.

## Decisions (settled)

1. **Boundary** — spine for Tier 1 + Tier 2 (~12-13 missions); the six multi-stage missions stay
   hand-written. One spine for all nineteen is possible but a net-negative trade (framework trap).
2. **Hooks are incremental** — `_onWin`, `_lost`, `_cleanup`, `_site` are added one per phase, each
   driven by the first mission that needs it, each default-off. No speculative hooks.
3. **Default-off is the safety contract** — the migration cannot change behaviour for any mission
   already on the spine; the empty-`_lost` short-circuit on the shared `waitUntil` is the load-bearing
   guard.
4. **steal_builder's pre-begin gate stays in the wrapper** — it must run before `fnc_mission_begin`,
   so it cannot be a spec field.
5. **Dressing helper lands in Phase 3** — `fnc_mission_dressing` collapses the three duplicated
   cosmetic-clutter blocks; folded in when `steal_supply` is migrated, not as separate churn.

## Task list

- [ ] Phase 0: baseline play-test + saved RPT for every target mission.
- [ ] Phase 1: migrate `destroy_radar`, then `destroy_patrol_camp`; no harness change.
- [ ] Phase 2: add `_onWin` (default `{}`); migrate `destroy_cache`; re-test one existing spine mission.
- [ ] Phase 3: add `_lost` (default `[]`, short-circuited in the poll); add `fnc_mission_dressing`; migrate `steal_supply`; verify destroyed / timeout / win paths.
- [ ] Phase 4: add `_cleanup` (default `{}`); migrate `steal_builder` (keep the pre-begin gate in the wrapper) and `transport_idap`.
- [ ] Phase 5: add `_site` (default = inline `fnc_mission_site`); migrate `destroy_tower` and `destroy_hardpoint`.
- [ ] Phase 6: migrate `sabotage_laptop` (town-building `_site`, holdAction flag `_done`, drop its own timeout watcher).
- [ ] Phase 7: assess `recon_observe`; migrate or leave bespoke.
- [ ] Update the `fnc_mission_run` spec-doc header on every field addition.
