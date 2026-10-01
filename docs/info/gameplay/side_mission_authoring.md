# Authoring a side mission

How to add a side-mission type, and the bar a new one has to clear. The per-mission catalogue —
what each mission is, its effort rating, its reward pricing — is
[`side_mission_catalogue.md`](side_mission_catalogue.md); this doc is the *how*, not the *what*. Player-facing wording rules are in
[`player_text_style_guide.md`](player_text_style_guide.md).

## The design bar

Every mission should pose a **distinct problem**, not the same problem with more hit points. The verb
is what varies: a generic mission is *reach the marker and kill/destroy the thing*, reskinned with
different classnames and counts. A hand-made mission changes the verb — and the change lives in the
scripts around the objective (siting, behaviour, win condition, teardown), not in a bigger garrison.

Complexity is not the goal; a challenge is. The sniper hunt spawns two to six men and no vehicles, yet plays
nothing like the others: the problem is *finding* elite marksmen who are hidden, hard to spot, and
quick to kill you. Small mission, real problem.

| Mission | The problem it poses | The script that makes it | Thread |
|---|---|---|---|
| Hunt Sniper Team | find 1-3 pairs of elite marksmen that patrol the zone's high ground | high-ground perch pool, sub-skills forced to 1, prone overwatch that moves perch to perch and flushes on approach or hit | `mission_threads/target_sniper/` |
| Eliminate High-Value Target | spot which of three armed convoys hides the target and stop it before it reaches a zone | three divergent road approaches, one unarmed car among armed escorts, race-to-zone monitor | `mission_threads/target_hvt/` |
| Deny Enemy Armor | reach a broken-down MBT before its repair-crew convoy, or intercept on the road | inbound repair convoy, distance-scaled repair timer, tank left unclaimed as the player's prize | `mission_threads/deny_armor/` |
| Destroy Vehicle Patrol | break a roving vehicle column that stays speed-limited until first blood | tier-rolled 3-vehicle road loop, LIMITED speed until a hit lifts it, tier-scaled reward | `mission_threads/target_armor/` |
| Informant Manhunt | find one disguised target in a live crowd before he flees | social "ask a civilian" layer, decoy cars, timed drive to an enemy zone | `mission_threads/informant/` |
| Recon Enemy Position | hold binocular eyes-on a zone from standoff without being drawn into a fight | mission-owned copy of the zone's own prefab, continuous LOS hold | `mission_threads/recon/` |
| Rescue Assault Team | break a cordon to free a captive squad, then cover its evac | captive-until-reached squad, cordon fight, evac helicopter + on-foot exfil | `mission_threads/rescue_squad/` |
| Generic (tower, cache, laptop, …) | reach the marker, destroy/kill the objective | none bespoke — the shared helper sequence, reskinned | one file per folder |

All the hand-made designs are written up in full in the plan doc's
[§Hand-made mission designs](side_mission_catalogue.md#hand-made-mission-designs) (the convoy reworks,
plus [§Informant Manhunt](side_mission_catalogue.md#informant-manhunt) and
[§Recon Enemy Position](side_mission_catalogue.md#recon-enemy-position)); read the closest one before writing a
new hand-made mission, as the worked example.

## The shape every thread runs

There is no runner. Every thread inlines the same sequence from shared helpers and ends through one
chokepoint. A one-shot win (the thing is dead) and a continuous one (hold eyes-on, cover the evac)
differ only in what step 6 polls, not in the code path. `destroy_tower` is the smallest complete
example; `rescue_squad` and `recon` run the same sequence around a scripted win.

1. **Sample the requester, open the gate.** Take `remoteExecutedOwner` in the thread's own scope
   (a called function reads its caller's, not the thread's), then
   `if (!([_index, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};`
   (`fnc_mission_begin.sqf:5`).
2. **Find ground, or abort.** `[_MissionPos, _radius, _index, _requester] call fnc_mission_site`
   returns `[_randomPos, _Building, _targetpos]` or `[]`; a thread that builds its own site searches
   directly instead. `fnc_mission_site` auto-aborts on `[]`, so `exitWith` there.
3. **Announce the build.** `[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice`.
4. **Spawn and claim.** Build the objective; `fnc_mission_claim` every group and vehicle you own.
5. **Present.** `[_pos, _radius, _taskId, _descText, _mission_name, _taskType, _brief] call
   fnc_mission_present` draws the search marker, issues the task and plays the opening brief, and
   returns the marker name (`fnc_mission_present.sqf:5`).
6. **Poll to the deadline.** `waitUntil { sleep N; <win> || time > DUWS_curDeadlineAt }`. The win
   predicate is the only part that varies by mission.
7. **Finish.** `[_mission_name, _taskId, "SUCCEEDED"|"FAILED", _pos, _radius, [_marker], …] call
   fnc_mission_finish` on **both** exits — the single terminal step that speaks the outcome line,
   clears markers, sets task state, tears down, and pays on a win. Full field list in its header
   (`fnc_mission_finish.sqf:11-15`).

## What every thread owes

| Obligation | How | Why |
|---|---|---|
| Open with the entry gate | `[_index, _MissionPos, _mission_name, _requester] call fnc_mission_begin`; exit if it returns `false` | Enforces the cooldown and sets `DUWS_curReward` / `DUWS_curDeadlineAt` from the table (`fnc_mission_begin.sqf:53,68`). Sample `remoteExecutedOwner` into `_requester` in the thread's own scope, not inside a called helper. |
| Find ground, or abort | `fnc_mission_site`, or your own search then `[_index, _requester, _reason] call fnc_mission_abort` when nothing fits | A called function cannot exit its caller, so both return `[]`/`false` and the thread must exit itself. `fnc_mission_abort` also undoes the entry state (`fnc_mission_abort.sqf:14`). |
| Claim what you spawn | living entities → `fnc_mission_claim`; props → `fnc_duws_keep` (a compKey) | Teardown collects by ownership, not proximity — a patrol wanders out of any radius sweep (`fnc_mission_claim.sqf`). |
| Never claim what the player is handed | leave a rescued squad, a recruited civilian, a captured vehicle unclaimed | A claim is a deletion order (`fnc_mission_claim.sqf:12`). |
| Tear down on both exits | `fnc_mission_finish` with `"SUCCEEDED"` or `"FAILED"` and the compKey | The one chokepoint: deletes claimed tokens and keyed props, pays on a win, frees the slot; a missed teardown leaks the garrison for the rest of the session. `fnc_mission_end` is its internal tail, called nowhere else. |

## Registration: one row plus the thread

Add a row to `src/duws/shared/includes/mission_types.hpp`, index-aligned with the launcher block.
Columns (full contract in the file header): thread name, cooldown-ready name key, strategic-map
description key, map icon, English debug label, launcher `{ [N] call fnc_mission_launch }`, base CP,
AP, REP, deadline `[minHours,maxHours]`, category (`command`/`civilian`), objective archetype, optional
note key, a `spawnRule`, and an `enabled` flag (false keeps the type out of the strategic-map offer
draw; the debug tools still start it). CP/AP/REP and the deadline are read only from here — the thread carries no
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
[§Architecture](side_mission_catalogue.md#architecture-mission-owned-site-selection).

## Player-facing text and reward

Briefing lines, callsigns, hint-vs-card split, and punctuation follow
[`player_text_style_guide.md`](player_text_style_guide.md); keep strings in `stringtable.xml` (English leads,
other locales lag on purpose). Set the base CP/AP to track the *required effort*, not the archetype —
the pricing rationale and the current effort ratings are in
[`side_mission_catalogue.md`](side_mission_catalogue.md#pricing-rework-command-missions).

## Recipe

1. Name the problem the mission poses, and the verb that makes it different from the catalogue. If the
   answer is "the same verb with more enemies", it is a generic reskin, not a new type.
2. Decide the win predicate: one-shot (the thing is dead) or continuous/scripted. Both run the same
   begin → site → build → present → poll → finish sequence; only what step 6 polls differs.
3. Add the `mission_types.hpp` row and register the thread global in `server_fnc_init.sqf`.
4. Write the thread. Spawn, `fnc_mission_claim` everything you own, never claim the player's reward.
5. If it needs particular terrain, add `fnc_<name>_site`; otherwise it inherits the generic finder.
6. Add the stringtable keys; price the base CP/AP to effort.
7. Test: sqf-vm covers parse and pure helpers only — the spawn, behaviour and teardown need an in-game
   run. Note in the thread header when a mission is parse-tested but not yet play-tested.
