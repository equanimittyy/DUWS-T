# Authoring a side mission

How to add a side-mission type, and the bar a new one has to clear. The rework SSOT — per-mission
catalogue, effort ratings, reward pricing — is [`side_missions_working.md`](../side_missions_working.md);
this doc is the *how*, not the *what*. Player-facing wording rules are in
[`player_facing_text.md`](player_facing_text.md).

## The design bar

Every mission should pose a **distinct problem**, not the same problem with more hit points. The verb
is what varies: a generic mission is *reach the marker and kill/destroy the thing*, reskinned with
different classnames and counts. A hand-made mission changes the verb — and the change lives in the
scripts around the objective (siting, behaviour, win condition, teardown), not in a bigger garrison.

Complexity is not the goal; a challenge is. The sniper hunt spawns two men and no vehicles, yet plays
nothing like the others: the problem is *finding* elite marksmen who are hidden, hard to spot, and
quick to kill you. Small mission, real problem.

| Mission | The problem it poses | The script that makes it | Thread |
|---|---|---|---|
| Sniper elimination | find two hidden elite marksmen on open ground | elevation+LOS perch search, sub-skills forced to 1, prone overwatch that flushes on approach or hit | `mission_threads/target_sniper/` |
| HVT convoy hunt | spot which of three armed convoys hides the target and stop it before it reaches a zone | three divergent road approaches, one unarmed car among armed escorts, race-to-zone monitor | `mission_threads/target_hvt/` |
| Deny enemy armour | reach a broken-down MBT before its repair-crew convoy, or intercept on the road | inbound repair convoy, distance-scaled repair timer, tank left unclaimed as the player's prize | `mission_threads/deny_armor/` |
| Vehicle patrol | break a roving vehicle column that stays speed-limited until first blood | tier-rolled 3-vehicle road loop, LIMITED speed until a hit lifts it, tier-scaled reward | `mission_threads/target_armor/` |
| Informant manhunt | find one disguised target in a live crowd before he flees | social "ask a civilian" layer, decoy cars, timed drive to an enemy zone | `mission_threads/informant/` |
| Recon overwatch | hold binocular eyes-on a zone from standoff without being drawn into a fight | mission-owned copy of the zone's own prefab, continuous LOS hold | `mission_threads/recon/` |
| Rescue squad | break a cordon to free a captive squad, then cover its evac | captive-until-reached squad, cordon fight, evac helicopter + on-foot exfil | `mission_threads/rescue_squad/` |
| Generic (tower, cache, laptop, …) | reach the marker, destroy/kill the objective | none bespoke — the shared spine, reskinned | one file per folder |

All the hand-made designs are written up in full in the plan doc's
[§Hand-made mission designs](../side_missions_working.md#hand-made-mission-designs) (the convoy reworks,
plus [§Informant hunt](../side_missions_working.md#informant-hunt) and
[§Recon overwatch](../side_missions_working.md#recon-overwatch)); read the closest one before writing a
new hand-made mission, as the worked example.

## Two build shapes

**Spine-shaped** — for a mission whose win reduces to a one-shot predicate (the thing is dead, the
object is destroyed). Build a spec and hand it to `fnc_mission_run.sqf`; the spine owns the marker,
the task, the intro card and dialogue, the deadline poll, the payout, and teardown. Only two fields
vary and you write both:

- `_build` — `[_targetpos,_randomPos,_radius,_Building] -> handles`. Spawn the objective, claim it
  (below), return whatever `_done` needs to test. Runs after the marker so the player already sees the
  area.
- `_done` — `handles -> bool`. The win predicate, polled every 2 s against the deadline.

The full spec field list is the header of `fnc_mission_run.sqf:16-30`; `target_sniper` is the smallest
complete example. Do not restate the spine's steps in a thread — if you find yourself hooking every
step, you want the other shape.

**Bespoke** — for a mission whose win is continuous or scripted (hold-for-duration, domination,
protect-civ, informant, recon, rescue-squad). The thread calls `fnc_mission_begin` itself, then owns
the whole flow. `fnc_mission_run.sqf:9-11` names why these stay off the spine.

## What every thread owes, either shape

| Obligation | How | Why |
|---|---|---|
| Open with the entry gate | `[_index, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin`; exit if it returns `false` | Enforces the cooldown and sets `DUWS_curReward` / `DUWS_curDeadlineAt` from the table. `remoteExecutedOwner` must be sampled in the thread's own scope (`fnc_mission_begin.sqf:7-8`). The spine does this for you. |
| Find ground, or abort | spine: `fnc_mission_site`; bespoke: your own search, then `[_index, _hintKey, _reason] call fnc_mission_abort` when nothing fits | A called function cannot exit its caller, so both return `[]`/`false` and the thread must exit itself. `fnc_mission_abort` also undoes the entry state. |
| Claim what you spawn | living entities → `fnc_mission_claim`; props → `fnc_duws_keep` (a compKey) | Teardown collects by ownership, not proximity — a patrol wanders out of any radius sweep (`fnc_mission_claim.sqf`). |
| Never claim what the player is handed | leave a rescued squad, a recruited civilian, a captured vehicle unclaimed | A claim is a deletion order (`fnc_mission_claim.sqf:14-15`). |
| Tear down on both exits | spine does it; bespoke calls `fnc_mission_end` on success and `fnc_mission_deadline_fail` on timeout, passing the compKey | Deletes claimed tokens and keyed props; a missed teardown leaks the garrison for the rest of the session. |

## Registration: one row plus the thread

Add a row to `src/duws/shared/includes/mission_types.hpp`, index-aligned with the launcher block.
Columns (full contract in the file header): thread name, cooldown-ready name key, strategic-map
description key, map icon, English debug label, launcher `{ [N] call fnc_mission_launch }`, base CP,
AP, REP, deadline `[minHours,maxHours]`, category (`command`/`civilian`), objective archetype, optional
note key, and a `spawnRule`. CP/AP/REP and the deadline are read only from here — the thread carries no
reward literals.

`spawnRule` is `[needDestZone, minCorridor, routeAvoidBlufor, hardEligible, weight, surveyKind]`.
`weight` and `hardEligible` feed the strategic-map draw: `weight` biases the odds a type is offered
(drawn without replacement, so it shifts presence and order, not duplication), and `hardEligible` is
whether the type may take one of the two deep, difficulty-boosted offer slots — set it false for a type
that cannot sit behind enemy lines. `surveyKind` is the placement survey's candidate source — `"zone"`
(countryside off OPFOR zones, the default) or `"town"` (populated towns, for a type that belongs in a
built-up area). The first three fields are for road convoys: `needDestZone` makes `fnc_mission_findSite`
pick and vet an OPFOR-held destination (at least `minCorridor` out, and with `routeAvoidBlufor` its
straight corridor kept clear of BLUFOR ground) and hand that zone to the thread as a third `params`
argument, so the convoy runs to a haven the offer already vetted. The thread must still re-check the zone
is OPFOR-held at start (it can flip in the gap) and fall back to its own search — which also covers the
debug-force path, where no destination is handed. Default `[false, 0, false, false, 1, "zone"]`.

The thread's global (`fnc_<name>_mission`) must also be registered in the compile list in
`src/duws/server/server_fnc_init.sqf`; there is no manifest of `fnc_*` globals beyond that file.

## Site-finder: demanding particular terrain

Placement is a two-phase survey in `fnc_mission_findSite`: phase 2 shortlists valid locations (zones or
towns per `surveyKind`), phase 3 picks one weighted by the offer's front/deep dial and realizes an exact
position, which `fnc_site_generic.sqf` accepts as-is. A mission that needs specific ground defines
`fnc_<name>_site` and the survey uses it instead of the generic on each realized candidate — a
**propose/accept** handshake:

```
[_candidatePos] call fnc_<name>_site
   -> []                       reject — this spot does not fit me, picker draws another
   -> [_precisePos, _extra...] accept — my objective sits at _precisePos
```

Two constraints, both because the finder runs client-side inside the picker
(`fnc_mission_findSite.sqf`): it may read **only broadcast state** (never a server-only global) and do
**only terrain queries** (no spawning). Only `select 0` reaches the thread — the picker flattens the
result to a 2-D position — so hand back the one position the thread must re-derive from, not a bundle.
The dispatch strips `_mission` (8 chars) off the thread name, so the finder file is
`fnc_<name>_site.sqf` and must be `publicVariable`'d like the picker. A finder gates the offer at
*click* time; a criterion that can only fail *after* the pick (war state moved in the gap) is handled
by the thread aborting with a stable snake_case `_reason` slug — see the abort contract in
[§Architecture](../side_missions_working.md#architecture-mission-owned-site-selection).

## Player-facing text and reward

Briefing lines, callsigns, hint-vs-card split, and punctuation follow
[`player_facing_text.md`](player_facing_text.md); keep strings in `stringtable.xml` (English leads,
other locales lag on purpose). Set the base CP/AP to track the *required effort*, not the archetype —
the pricing rationale and the current effort ratings are in
[`side_missions_working.md`](../side_missions_working.md#pricing-rework-command-missions).

## Recipe

1. Name the problem the mission poses, and the verb that makes it different from the catalogue. If the
   answer is "the same verb with more enemies", it is a generic reskin, not a new type.
2. Pick the shape: one-shot win → spine + a `_build`/`_done` spec; continuous/scripted win → bespoke
   thread off `fnc_mission_begin`.
3. Add the `mission_types.hpp` row and register the thread global in `server_fnc_init.sqf`.
4. Write the thread. Spawn, `fnc_mission_claim` everything you own, never claim the player's reward.
5. If it needs particular terrain, add `fnc_<name>_site`; otherwise it inherits the generic finder.
6. Add the stringtable keys; price the base CP/AP to effort.
7. Test: sqf-vm covers parse and pure helpers only — the spawn, behaviour and teardown need an in-game
   run. Note in the thread header when a mission is parse-tested but not yet play-tested.
