# Join-in-progress: review and hardening plan

Every `remoteExec` in `duws/` that carries a JIP parameter was traced to its call site, its
removal counterpart (where one exists), and the state a joining client ends up with. Of the 61
JIP-flagged calls, **56 queue under an engine-generated ID that nothing can address, and no site
anywhere removes a queued message** (`remoteExec ["", _id]` appears nowhere in the tree). The
queue is append-only for the whole session.

The civilian half of this is fixed and recorded under
[§What is already correct](#what-is-already-correct); what is left is mostly join cost rather
than wrong state, with one behavioural case remaining: a joiner can re-trigger a side mission
that has already succeeded.

## The mechanism, in the three forms this code uses

`_args remoteExec [_fn, _target, _jip]` — the third parameter decides what a machine joining
*later* receives.

| Third parameter | Effect |
|---|---|
| absent / `false` | fire and forget. Current machines only |
| `true` | append to the JIP queue under an engine-generated ID. Every future joiner runs it. Nothing can ever reference or remove it |
| a string | queue under that ID. A second call with the same ID **replaces** the first, and `remoteExec ["", "thatID"]` deletes it |
| an object | queue under the object's `netId`, and the engine drops the entry when the object is deleted |

The object form is the one the mission already documents as correct, in the `HitPart` entry of
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#practice-targets-ignore-damage-entirely-hitpart-fires-on-the-shooter-not-the-owner).
Five sites use it: `fnc_createKillhouse.sqf:1072`, `fnc_actionRotary.sqf:40`, and the three
civilian adders in `fnc_civ_spawnUnit.sqf:46,48,52`.

Three other channels reach joiners without the queue at all, and the review confirmed all
three are being used correctly, so nothing below proposes touching them: `publicVariable`
values, `missionNamespace setVariable [k, v, true]`, and global marker state (`createMarker`
plus `setMarkerAlpha` and friends).

## Inventory

56 sites pass a bare `true`. By target:

| Target | Sites | Growth rate |
|---|---|---|
| `BIS_fnc_taskSetState` | 27 | one per side-mission state change |
| `remoteExec ["call", 0, true]` — a whole `addAction` body shipped as code | 5 | one per mission prop |
| `fnc_MHQ_addActions` | 4 | one per MHQ deploy *and* one per undeploy |
| `addAction` | 3 | one per FOB, one per sabotage laptop |
| `fnc_addRecruitAction` | 3 | one per recruitable civilian on the WBK and rescue paths only — the plain spawn keys its copy to the unit |
| HQ object actions (`fnc_addQuickChangeActions`, `fnc_addHQBuildingActions`, `fnc_addHQSatelliteActions`, `fnc_addBoardKillhouseActions`, `fnc_addTerminalBlackMarketActions`, `fnc_addRedeployAction`) | 6 | once, at HQ build |
| `fnc_bottom_right_message` | 2 | one per rest-heal, one per mission-slot release |
| `fnc_FOBactions`, `fnc_client_addRepairActions`, `fnc_client_addRecycleActions`, `fnc_intel_container_addAction`, `fnc_corpse_search_action`, `kndr_removeMarker` | 6 | per FOB / station / container / **corpse** / marker |

## What is broken now

| Problem | Where |
|---|---|
| Sabotage laptop: the action is queued for joiners, the removal is not — a joiner can re-hack a completed mission | add `server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:191`, remove `client/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_success.sqf:24` |
| A transient cosmetic OSD is queued permanently; a joiner replays every one at once | `server/dialog/fnc_rest_heal.sqf:24`, `server/missions/fnc_missionTimer.sqf:17` |
| MHQ deploy and undeploy each append an entry, so the queue records the whole toggle history | `server/dialog/fnc_MHQ_deploy.sqf:7`, `fnc_MHQ_undeploy.sqf:47`, `client/dialog/fnc_MHQ_select.sqf:28` |
| One JIP entry per corpse, for the campaign's lifetime | `server/misc/fnc_add_intel_on_death.sqf:6` |
| 27 task-state entries accumulate although each task's history collapses to its final state | the `BIS_fnc_taskSetState` sites listed above |
| Recruit adders on the WBK and rescue paths still pass a bare `true` where the plain spawn path keys to the unit | `server/misc/fnc_civ_handler_wbk.sqf:402,465`, `server/server_fnc_init.sqf:1478` |
| A JIP client can broadcast `serverinit_complete = false` back over the server's `true` | `INIT.sqf:17-19` — no `isServer` gate |
| The only untimed wait in the client boot path is the one gating `allowDamage true` | `client/client_init.sqf:398` vs `initPlayerLocal.sqf:6`; the flag is never set if `server/misc/fnc_intro_heli.sqf:22` takes its early exit |

### Queued code is the heaviest payload

The five `remoteExec ["call", 0, true]` sites
(`destroy_cache:120,154`, `rescue_pilot:336,407`, `steal_supply:84`) queue an entire
`addAction` body as compiled code rather than a function name plus arguments. They are
bounded — one per mission prop — but each entry is far larger than the rest, and they are
the entries a joiner pays most to receive.

### Dead entries are safe but not free

Entries naming objects that no longer exist do not misbehave: `fnc_corpse_search_action` and
every action adder open with `if (isNull _unit) exitWith {}`, and `addAction` on `objNull` is a
silent no-op. The cost is that a joiner still executes the whole backlog — one call per corpse
the campaign ever produced, and one per recruitable the WBK and rescue paths ever spawned —
before it reaches anything that matters.

### Two boot-path hazards that are not queue problems

`INIT.sqf:17` reads `if (isNil "serverinit_complete") then { serverinit_complete = false;
publicVariable "serverinit_complete" }`. On the server's own first run that is the intended
initialisation. On a joining client it depends on the JIP variable sync having landed before
`INIT.sqf` executes, which nothing in the source guarantees; if it has not, the joiner
broadcasts `false` over the server's `true` and every machine still waiting on that flag
(`INIT.sqf:33`, `client_init.sqf:18`, `:137`) stalls. This is also the mission's only
unguarded client write to a shared boot flag, against the rule in
[`info/server_client_authority.md`](info/server_client_authority.md#the-invariant). Gating the
whole block on `isServer` costs one line and removes the question.

`client_init.sqf:398` is `waitUntil { sleep 0.2; !isNil "intro_heli_done" }` — a bare wait,
where every other milestone in that file goes through `fnc_waitLogged` with a timeout and an
escalating log line. It gates the teleport to base *and* `player allowDamage true` at `:421`,
while `initPlayerLocal.sqf:6` has already set `allowDamage false`. `fnc_intro_heli.sqf:22`
exits without publishing `intro_heli_done` when `PosOfBLUHQ` is undefined, and that exit
leaves every client — joining or original — invulnerable and unteleported with no log line
saying why.

## What is already correct

Recording these so a sweep does not "fix" them:

- **Boot flags reach joiners.** `serverinit_complete`, `WARCOM_init_done`,
  `mission_init_complete`, `HQ_pos_found_generated`, `chosen_settings`, `PosOfBLUHQ`,
  `Squad_Leaders`, `game_master`, `CIV_PRESENCE` and `apocalypse_mode` are all broadcast.
- **Hardcore zone reveal is JIP-safe without the queue.** `fnc_zone_reveal.sqf` uses
  `setMarkerAlpha` on global markers, whose state the engine synchronises to joiners.
- **`fnc_createKillhouse.sqf:1072`** passes the object as the JIP parameter, so its entry is
  addressable and self-deleting. It is the template for everything below.
- **The civilian queue is closed.** What was six bare-`true` adders per civilian is now one
  `fnc_civ_clientActions` broadcast keyed to the unit (`fnc_civ_spawnUnit.sqf:52`, with the
  RAVAGE branch keyed the same way at `:46,48`), so a town's entries delete themselves when its
  crowd is recycled instead of accumulating for the session. Spent state is now unit variables —
  `DUWS_civ_stopped`, `DUWS_civ_closed`, `DUWS_civ_arrested`, `isSurrendered` — all broadcast and
  all re-read server-side before anything is applied, so a joiner receiving a restocked action
  cannot spend a civilian twice. See
  [`info/civilian_interaction.md`](info/civilian_interaction.md#state-lives-on-the-civilian).
- **FOB fortify and guard actions** queue once per FOB and skip the re-add on rebuild —
  `fnc_fortifyFOB.sqf:220` off the `_refortify` parameter, `fnc_guardsFOB.sqf:107` off a
  `FOB_guard_action_done` variable on the FOB — so upkeep does not grow the queue.
- **`fnc_corpse_search_action`** guards re-entry per machine, so a joiner cannot double-add.
- **The `PlayerConnected` handler** (`server_init.sqf:237`) resets a rejoining player's kill
  tally, which is keyed by UID and would otherwise carry over from a previous session.

## Fix directions

Ordered by what each buys.

**Give every repeatable entry a JIP ID.** Anything keyed to an object takes the object
(`remoteExec [_fn, 0, _unit]`), which makes the entry replaceable and self-deleting. Anything
keyed to a name takes a string: `"duws_mhq_actions"` for the four MHQ sites collapses the
whole toggle history to one entry that always holds the current state, and
`_VARtaskgeneratedName` for the 27 task-state sites collapses each task to its latest state.

**Delete on the removal path.** Wherever an add is queued and a remove exists, the remove must
also drop the queue entry — `remoteExec ["", _jipId]`. This is the whole fix for the sabotage
laptop.

**Drop the JIP flag where the message is transient.** `fnc_bottom_right_message` is a
date/time/location OSD; a joiner has no reason to receive the last hundred of them.

**Gate `INIT.sqf:17-19` on `isServer`, and put `client_init.sqf:398` behind
`fnc_waitLogged`.** Neither is a queue problem; both are one-line changes that turn a silent
stall into a logged one. `fnc_capture_zones_task.sqf:18` already waits on `intro_heli_done`
through `fnc_waitLogged` with a 420 s bound, so the client is the only unlogged waiter left.

## Open questions

- Whether `BIS_fnc_taskCreate`'s own framework already delivers task state to joiners, which
  would make all 27 `BIS_fnc_taskSetState` broadcasts redundant rather than merely
  ID-less. Keying them is safe either way and does not depend on the answer.
