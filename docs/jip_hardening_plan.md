# Join-in-progress: review and hardening plan

Every `remoteExec` in `duws/` that passes a third parameter was traced to its call site, its
removal counterpart (where one exists), and the state a joining client ends up with.

| Third parameter | Sites | Effect |
|---|---|---|
| explicit `false` | 80 | fire and forget, current machines only |
| bare `true` | 5 | queued under an engine-generated ID that nothing can address |
| an object or a string | 59 | queued under an addressable, removable ID |

The five that remain are one shape — a whole `addAction` body shipped as compiled code — and
they are the only outstanding queue work. Everything else is keyed, replaced or dropped.

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
correctly: `publicVariable` values, `missionNamespace setVariable [k, v, true]`, and global
marker state (`createMarker` plus `setMarkerAlpha` and friends).

### An object-keyed ID *is* that object's netId

Two entries keyed to the same object therefore evict one another — the second add replaces the
first, and only the survivor reaches joiners. This is the trap that shaped most of the work, and
it had already cost the mission a bug: the sabotage laptop carried both its own `addAction` and,
in hardcore mode, the intel rotary from `server/dialog/fnc_actionRotary.sqf:28`, so the rotary
evicted the sabotage action and a joining client could not complete the mission at all.

The rule that follows: **wherever one object carries two entries that must both survive, every
entry on it suffixes a string ID.** In use now — `fob_defences_%1` / `fob_guards_%1` on a FOB,
`killhouse_arsenal_%1` / `killhouse_kits_%1` on a terminal, `hq_repair_%1` / `hq_recycle_%1` on
the shared HQ depot, the six `hq_*_%1` ids on the HQ building and medical tent, and
`sabotage_action_%1` on the laptop.

Coexistence is the test, not sharing an object. Where a later entry is *meant* to supersede an
earlier one, the object form is right and the eviction is the mechanism: a mission target keyed
to a rotary at `target_armor_mission.sqf:173` takes a corpse entry on the same unit when it dies
(`fnc_add_intel_to_group` over `units _group`, which includes it), and the live-body search is
spent by then. `fnc_missionPatrolswithintel` does the same across every EAST unit in radius.

The cost of the string form is that nothing deletes it implicitly, so an entry naming a deleted
object lingers. That is bounded and small here (a handful per FOB lost, one per abandoned
sabotage mission) and it is the right trade against a collision, which is silent and breaks
behaviour. Where an object carries exactly one entry the object form is still preferred, because
it self-cleans.

## What remains

The five `remoteExec ["call", 0, true]` sites (`destroy_cache:123,158`, `rescue_pilot:336,407`,
`steal_supply:87`) queue an entire `addAction` body as compiled code rather than a function name
plus arguments. They are the entries a joiner pays most to receive, and they cannot be keyed as
they stand — the body has to become a named function taking arguments first.

`fnc_sabotage_laptop_success.sqf` removes action index `0` rather than a captured `addAction`
return. It works today because insertion order puts the sabotage add before the `spawn`ed rotary
on original and joining clients alike, but the laptop demonstrably carries two actions, which is
exactly the condition under which index-`0` removal stops being safe.

The `sabotage_action_%1` id is hand-written in two files (`fnc_sabotage_laptop_mission.sqf:196`
and the success path). A typo in either fails silently — the removal simply does nothing — so if
a second string id ever needs sharing across files, that is the point to reach for a macro.

One unbounded wait on networked state remains in the client boot path, and it is on the joiner's
branch: `client_init.sqf:140` blocks on `HQ_pos_found_generated && chosen_settings` with no
timeout, reached only when `WARCOM_init_done` is false — which is the JIP case. It is not the
same defect as the two that were bounded, and the fix is not the same either: it hints the player
every five seconds that the host is still in setup, so the stall is visible, and proceeding on a
timeout would boot the client into a campaign whose settings never arrived. What it lacks is a
log line. Decide what a timeout should *do* before bounding it.

The other unbounded waits in the file (`:17,127,327,335`) test local player readiness rather than
a broadcast, so they resolve on any machine with an interface.

## What is already correct

Recording these so a sweep does not "fix" them:

- **Boot flags reach joiners.** `serverinit_complete`, `WARCOM_init_done`,
  `mission_init_complete`, `HQ_pos_found_generated`, `chosen_settings`, `PosOfBLUHQ`,
  `Squad_Leaders`, `game_master`, `CIV_PRESENCE` and `apocalypse_mode` are all broadcast.
  `INIT.sqf:21` defaults the flag locally on every machine but broadcasts only from the server,
  so a joiner whose JIP sync has not landed cannot publish `false` over the server's `true`.
- **The corpse entry is the right thing to key, not delete.** `fnc_corpse_search_action` reveals
  the current *mission* target and `fnc_intel_search_action` is the generic body-search trickle;
  they are separate mechanics and the overlap on a mission target's corpse is deliberate. See
  [`info/intel_system.md`](info/intel_system.md#the-body-search-looks-outward-so-it-scales-with-players-not-corpses),
  which names the per-corpse JIP cost as tolerable only while bounded — keying is what bounds it.
- **Hardcore zone reveal is JIP-safe without the queue.** `fnc_zone_reveal.sqf` uses
  `setMarkerAlpha` on global markers, whose state the engine synchronises to joiners.
- **The civilian queue is closed.** What was six bare-`true` adders per civilian is now one
  `fnc_civ_clientActions` broadcast keyed to the unit (`fnc_civ_spawnUnit.sqf:52`, with the
  RAVAGE branch keyed the same way at `:46,48`), so a town's entries delete themselves when its
  crowd is recycled. Spent state is unit variables — `DUWS_civ_stopped`, `DUWS_civ_closed`,
  `DUWS_civ_arrested`, `isSurrendered` — all broadcast and all re-read server-side before
  anything is applied, so a joiner receiving a restocked action cannot spend a civilian twice.
  See [`info/civilian_interaction.md`](info/civilian_interaction.md#state-lives-on-the-civilian).
- **Task state collapses to one entry per task.** The 27 `BIS_fnc_taskSetState` broadcasts key to
  the task name, so a joiner receives each side mission once, at its latest state.
- **Corpse and recruit entries die with their unit**, and `fnc_missionTimer.sqf:18` already
  clears `allDeadMen` on every mission-slot release, so the corpse backlog drains on a path that
  already runs.
- **MHQ actions hold one entry.** The four `fnc_MHQ_addActions` callers share
  `"duws_mhq_actions"`, and each branch opens with `removeAllActions`, so the queue carries the
  current state rather than the toggle history.
- **`fnc_corpse_search_action`** guards re-entry per machine, so a joiner cannot double-add.
- **The `PlayerConnected` handler** (`server_init.sqf:240`) resets a rejoining player's kill
  tally, which is keyed by UID and would otherwise carry over from a previous session.

## Work, in order

- [ ] Convert the five `remoteExec ["call", 0, true]` sites to a named function plus arguments,
      then key each to its prop. Verify: the mission prop still carries its action, and a client
      joining after the prop spawns receives exactly one copy.
- [ ] Move [§The mechanism](#the-mechanism) — the parameter table and the netId-collision rule —
      into [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) before retiring this plan.
      That doc currently mentions the JIP parameter only in passing inside its `HitPart` entry,
      and the collision rule is the load-bearing half; retiring the plan without moving it loses
      it.

Worth deciding once the last five are done: whether a lint check belongs in `tests/lint/` to keep
bare-`true` JIP flags from creeping back, following the `paths_baseline.txt` pattern already used
there to gate regressions without being blocked by legacy debt.

The verification that matters for all of it is a two-machine test — host plus one client that
connects *after* the state exists — because a single hosted session never exercises the queue.

## Open questions

- Whether `BIS_fnc_taskCreate`'s own framework already delivers task state to joiners, which
  would make the 27 `BIS_fnc_taskSetState` broadcasts redundant rather than merely keyed. Every
  `BIS_fnc_taskCreate` call in the tree runs server-side under a plain `call` and is never
  broadcast, yet clients do see the tasks — which suggests the framework distributes them itself.
  Keying them was safe either way and does not depend on the answer.
- Whether `remoteExec ["", _id]` removes a queue entry when issued from a client. The one removal
  in the tree (`fnc_sabotage_laptop_success.sqf`) hands the call to the server rather than rely on
  it, which is also what the authority model in
  [`info/server_client_authority.md`](info/server_client_authority.md#the-invariant) would ask for.
