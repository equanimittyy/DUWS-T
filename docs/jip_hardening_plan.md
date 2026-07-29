# Join-in-progress: review and hardening plan

Every `remoteExec` in `duws/` that passes a third parameter was traced to its call site, its
removal counterpart (where one exists), and the state a joining client ends up with.

| Third parameter | Sites | Effect |
|---|---|---|
| explicit `false` | 78 | fire and forget, current machines only |
| bare `true` | 52 | queued under an engine-generated ID that nothing can address |
| an object or a string | 14 | queued under an addressable, removable ID |

**No site anywhere removes a queued message** — `remoteExec ["", _id]` appears nowhere in the
tree — so for the 52 the queue is append-only for the whole session.

One behavioural bug remains (a joiner can re-hack a completed sabotage mission); the rest is
join cost rather than wrong state. The civilian and FOB-upkeep halves are already closed and
are recorded under [§What is already correct](#what-is-already-correct) so a sweep does not
"fix" them again.

## The mechanism

`_args remoteExec [_fn, _target, _jip]` — the third parameter decides what a machine joining
*later* receives.

| Third parameter | Effect |
|---|---|
| absent / `false` | fire and forget. Current machines only |
| `true` | append to the JIP queue under an engine-generated ID. Every future joiner runs it. Nothing can ever reference or remove it |
| a string | queue under that ID. A second call with the same ID **replaces** the first, and `remoteExec ["", "thatID"]` deletes it |
| an object | queue under the object's `netId`, and the engine drops the entry when the object is deleted |

Three other channels reach joiners without the queue at all, and all three are already used
correctly, so nothing below proposes touching them: `publicVariable` values, `missionNamespace
setVariable [k, v, true]`, and global marker state (`createMarker` plus `setMarkerAlpha` and
friends).

### An object-keyed ID *is* that object's netId

Two entries keyed to the same object therefore evict one another — the second add replaces the
first, and only the survivor reaches joiners. This is the constraint that shapes most of the
work below, and the mission already carries a case of it: `server/init_hq/fnc_fortifyFOB.sqf:225`
and `server/init_hq/fnc_guardsFOB.sqf:113` both hang an action off the same FOB, so each
suffixes a string ID (`format ["fob_defences_%1", netId _fob]`) rather than passing the object.

It also means the naive fix is wrong wherever one object carries several adders. In
`server/init_hq/fnc_BluHQinit.sqf`, `_hqObj` carries three (`:670`, `:679`, `:732`) and
`_medTent` carries two (`:674`, and `:675` which is *already* object-keyed). Keying those to
their objects would silently drop four of the five.

## Inventory of the 52 bare-`true` sites

| Target | Sites | Growth rate |
|---|---|---|
| `BIS_fnc_taskSetState` | 27 | one per side-mission state change |
| `remoteExec ["call", 0, true]` — a whole `addAction` body shipped as code | 5 | one per mission prop |
| HQ object action adders (`fnc_addQuickChangeActions`, `fnc_addBoardKillhouseActions`, `fnc_addHQBuildingActions`, `fnc_addHQSatelliteActions`, `fnc_addTerminalBlackMarketActions`, `fnc_addRedeployAction`) | 6 | once, at HQ build |
| `fnc_MHQ_addActions` | 4 | one per MHQ deploy *and* one per undeploy |
| `fnc_addRecruitAction` | 3 | one per recruitable on the WBK and rescue paths only — the plain spawn keys its copy to the unit |
| `fnc_bottom_right_message` | 2 | one per rest-heal, one per mission-slot release |
| `fnc_client_addRepairActions`, `fnc_client_addRecycleActions` | 2 | one per station |
| `fnc_FOBactions`, `fnc_intel_container_addAction`, `fnc_corpse_search_action` | 3 | per FOB / container / **corpse** |

### Queued code is the heaviest payload

The five `remoteExec ["call", 0, true]` sites (`destroy_cache:123,158`,
`rescue_pilot:336,407`, `steal_supply:87`) queue an entire `addAction` body as compiled code
rather than a function name plus arguments. They are bounded — one per mission prop — but each
entry is far larger than the rest, and they are the entries a joiner pays most to receive.
Converting them to a named function plus arguments is what makes them keyable at all.

### Dead entries are safe but not free

Entries naming objects that no longer exist do not misbehave:
`client/misc/fnc_corpse_search_action.sqf:10` and every action adder open with an `isNull`
exit, and `addAction` on `objNull` is a silent no-op. The cost is that a joiner still executes
the whole backlog — one call per corpse the campaign ever produced — before it reaches anything
that matters.

## What is broken now

| Problem | Where |
|---|---|
| Sabotage laptop: the add is keyed to the laptop, but the laptop is never deleted and no removal drops the entry, so a joiner can re-hack a completed mission | add `server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:193`, removal missing from `client/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_success.sqf` |
| One JIP entry per corpse, for the campaign's lifetime | `server/misc/fnc_add_intel_on_death.sqf:6` |
| 27 task-state entries accumulate although each task's history collapses to its final state | the `BIS_fnc_taskSetState` sites |
| MHQ deploy and undeploy each append an entry, so the queue records the whole toggle history | `server/dialog/fnc_MHQ_deploy.sqf:10,78`, `fnc_MHQ_undeploy.sqf:47`, `client/dialog/fnc_MHQ_select.sqf:28` |
| A transient cosmetic OSD is queued permanently; a joiner replays every one at once | `server/dialog/fnc_rest_heal.sqf:24`, `server/missions/fnc_missionTimer.sqf:17` |
| Recruit adders on the WBK and rescue paths pass a bare `true` where the plain spawn keys to the unit | `server/misc/fnc_civ_handler_wbk.sqf:402,465`, `server/server_fnc_init.sqf:1484` |
| A JIP client can broadcast `serverinit_complete = false` back over the server's `true` | `INIT.sqf:17-19` — no `isServer` gate |
| The only untimed wait in the client boot path is the one gating `allowDamage true` | `client/client_init.sqf:403` vs `initPlayerLocal.sqf:6`; the flag is never set if `server/misc/fnc_intro_heli.sqf:22` takes its early exit |

### Two boot-path hazards that are not queue problems

`INIT.sqf:17` reads `if (isNil "serverinit_complete") then { serverinit_complete = false;
publicVariable "serverinit_complete" }`. On the server's own first run that is the intended
initialisation. On a joining client it depends on the JIP variable sync having landed before
`INIT.sqf` executes, which nothing in the source guarantees; if it has not, the joiner
broadcasts `false` over the server's `true` and every machine still waiting on that flag
(`INIT.sqf:33`, `client_init.sqf:20`, `:139`) stalls. This is also the mission's only unguarded
client write to a shared boot flag, against the rule in
[`info/server_client_authority.md`](info/server_client_authority.md#the-invariant). Gating the
whole block on `isServer` costs one line and removes the question.

`client_init.sqf:403` is `waitUntil { sleep 0.2; !isNil "intro_heli_done" }` — a bare wait,
where every other milestone in that file goes through `fnc_waitLogged` with a timeout and an
escalating log line. It gates the teleport to base *and* `player allowDamage true` at `:426`,
while `initPlayerLocal.sqf:6` has already set `allowDamage false`. `fnc_intro_heli.sqf:22`
exits without publishing `intro_heli_done` when `PosOfBLUHQ` is undefined, and that exit leaves
every client — joining or original — invulnerable and unteleported with no log line saying why.
`server/misc/fnc_capture_zones_task.sqf:18` already waits on the same flag through
`fnc_waitLogged` with a 420 s bound, so the client is the only unlogged waiter left.

## What is already correct

Recording these so a sweep does not "fix" them:

- **Boot flags reach joiners.** `serverinit_complete`, `WARCOM_init_done`,
  `mission_init_complete`, `HQ_pos_found_generated`, `chosen_settings`, `PosOfBLUHQ`,
  `Squad_Leaders`, `game_master`, `CIV_PRESENCE` and `apocalypse_mode` are all broadcast.
- **Hardcore zone reveal is JIP-safe without the queue.** `fnc_zone_reveal.sqf` uses
  `setMarkerAlpha` on global markers, whose state the engine synchronises to joiners.
- **The civilian queue is closed.** What was six bare-`true` adders per civilian is now one
  `fnc_civ_clientActions` broadcast keyed to the unit (`fnc_civ_spawnUnit.sqf:52`, with the
  RAVAGE branch keyed the same way at `:46,48`), so a town's entries delete themselves when its
  crowd is recycled. Spent state is unit variables — `DUWS_civ_stopped`, `DUWS_civ_closed`,
  `DUWS_civ_arrested`, `isSurrendered` — all broadcast and all re-read server-side before
  anything is applied, so a joiner receiving a restocked action cannot spend a civilian twice.
  See [`info/civilian_interaction.md`](info/civilian_interaction.md#state-lives-on-the-civilian).
- **FOB fortify and guard actions** carry suffixed string IDs and are added once per FOB
  (`fnc_fortifyFOB.sqf:225` off the `_refortify` parameter, `fnc_guardsFOB.sqf:113` off a
  `FOB_guard_action_done` variable), so upkeep does not grow the queue.
- **The killhouse is the template for every form.** `fnc_createKillhouse.sqf:1118,1319` key to
  the object; `:1326,1328` suffix a string ID because both hang off the same terminal.
- **Ammobox and MHQ crate entries** are keyed to their crate (`client/supports/fnc_ammobox.sqf:108`,
  `server/dialog/fnc_MHQ_deploy.sqf:50`), which matters because undeploy deletes the crate.
- **`fnc_corpse_search_action`** guards re-entry per machine, so a joiner cannot double-add.
- **The `PlayerConnected` handler** (`server_init.sqf:240`) resets a rejoining player's kill
  tally, which is keyed by UID and would otherwise carry over from a previous session.

## Work, in order

Each step is independently shippable and independently testable. The verification that matters
throughout is a two-machine test — host plus one client that connects *after* the state exists —
because a single hosted session never exercises the queue at all.

- [ ] Close the sabotage re-hack. Route a queue removal through the server on the success path,
      alongside the reward the function already sends to target 2. Verify: hack the laptop, then
      connect a second client — the sabotage action is absent from the laptop and the mission
      cannot be completed twice. While in the file, note that
      `fnc_sabotage_laptop_success.sqf:24` removes action index `0` rather than a captured
      `addAction` return, which is fragile once the hardcore rotary action shares the laptop;
      flag it, decide separately.
- [ ] Key the corpse entry to the corpse (`remoteExec [..., 0, _unit]`).
      `server/missions/fnc_missionTimer.sqf:18` already deletes every dead body on each
      mission-slot release, so the entries then self-drain on a path that already runs. Verify:
      after several missions, a joining client's corpse-action backlog is bounded by the corpses
      currently on the map rather than by the campaign's total.
- [ ] Key the 27 `BIS_fnc_taskSetState` sites to their task name (`_VARtaskgeneratedName`, and
      `_taskID` in `protect_civ`). Each task then holds one entry at its latest state. Verify: a
      joiner's task list shows each side mission once, in its current state, with no replay of
      superseded transitions.
- [ ] Collapse the four `fnc_MHQ_addActions` sites onto one string ID. Each branch opens with
      `removeAllActions MHQ1`, and only one of deploy/undeploy is ever current, so replacement is
      correct; the `"select"` call at `fnc_MHQ_select.sqf:25` goes to target 2 without a JIP flag
      and must not share the ID. Verify: toggle deploy/undeploy several times, then join — the
      new client sees exactly the action matching the MHQ's current state.
- [ ] Drop the JIP flag from the two `fnc_bottom_right_message` sites. It is a date/time/location
      OSD; a joiner has no reason to receive the last hundred. Verify: a joiner gets no burst of
      stacked OSDs.
- [ ] Key the three `fnc_addRecruitAction` sites to the unit, matching `fnc_civ_spawnUnit.sqf:48`.
- [ ] Key the remaining per-object adders: `fnc_FOBactions` to the FOB,
      `fnc_intel_container_addAction` to the container, the repair and recycle adders to their
      depot. One entry per object, so the object form is safe here.
- [ ] Key the six HQ adders in `fnc_BluHQinit.sqf` with **suffixed string IDs**, not the object —
      `_hqObj` carries three and `_medTent` two, and object keys would evict each other. Verify:
      a joining client gets every HQ action, not just the last one added per object.
- [ ] Convert the five `remoteExec ["call", 0, true]` sites to a named function plus arguments,
      then key them to their prop. This is the only step that is a refactor rather than a
      parameter change; it can be deferred without blocking anything above.
- [ ] Gate `INIT.sqf:17-19` on `isServer`. Verify: a client joining a running campaign does not
      reset `serverinit_complete`, and no machine stalls at `INIT.sqf:33`.
- [ ] Put `client_init.sqf:403` behind `fnc_waitLogged` with a bound. Verify: with `PosOfBLUHQ`
      forced undefined, the client logs the timeout and reaches `allowDamage true` instead of
      staying invulnerable and silent.
- [ ] Move [§The mechanism](#the-mechanism) — the parameter table and the netId-collision rule —
      into [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) before retiring this plan.
      That doc currently mentions the JIP parameter only in passing inside its `HitPart` entry,
      and the rule is the load-bearing half; retiring the plan without moving it loses it.

Worth deciding once the sweep is done: whether a lint check belongs in `tests/lint/` to keep
bare-`true` JIP flags from creeping back, following the `paths_baseline.txt` pattern already
used there to gate regressions without being blocked by legacy debt.

## Open questions

- Whether `BIS_fnc_taskCreate`'s own framework already delivers task state to joiners, which
  would make all 27 `BIS_fnc_taskSetState` broadcasts redundant rather than merely ID-less.
  Every `BIS_fnc_taskCreate` call in the tree runs server-side under a plain `call` and is never
  broadcast, yet clients do see the tasks — which suggests the framework distributes them
  itself. Keying the state calls is safe either way and does not depend on the answer.
