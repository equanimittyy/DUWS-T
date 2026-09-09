# Rescue Hostage side mission

A covert-rescue side mission: OPFOR holds a lone captive in a building cluster in no-man's-land,
guarded by one garrison squad and roving foot patrols. The player infiltrates, frees the hostage and
exfils him to HQ — but if the guards detect the assault, they execute the hostage on a one-minute
clock. The verb is *stay unseen long enough to neutralise the guards*, which no current mission poses.

This is the *how* for one type; the shared authoring contract it must satisfy is
[`side_mission_authoring.md`](../info/gameplay/side_mission_authoring.md), the per-mission catalogue is
[`side_mission_catalogue.md`](../info/gameplay/side_mission_catalogue.md), and the detection design
rests on the `knowsAbout` trap documented in
[`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag).

## Why it is a distinct problem, not a reskin

The design bar is a new *verb*, not a bigger garrison. Every other rescue (`rescue_pilot`,
`rescue_squad`) is a fight-in-then-carry-out with no penalty for being loud — the captive is safe until
you reach him. Here the captive's survival is coupled to your stealth: the guards can kill the objective
before you close, so the player must weigh a quiet approach that removes the executioners against a fast
loud one that starts the death clock. The execution timer, and the detection model that arms it, are the
bespoke scripting; the garrison and patrols are ordinary spawns.

## Siting (offer-time finder)

Placement is gated at *click* time by a `fnc_rescue_hostage_site` finder (propose/accept), because the
constraints can be tested with terrain queries and broadcast state — the two limits every finder runs
under (`fnc_mission_findSite.sqf`, client-side in the picker). `surveyKind` is `"map"` (like Sabotage
Laptop): the hostage belongs in contested countryside or a quiet settlement, not tethered to a zone.

The finder accepts a candidate only when **all** hold:

| Constraint | Test | Source |
|---|---|---|
| A real building cluster to hide in | ≥3 enterable buildings within the search radius | inline `nearestTerrainObjects [_pos, ["House"], R, true]` + `buildingPos 3`, the exact test `fnc_sabotage_laptop_site.sqf:18-20` uses so it runs client-side |
| Clear of the capturable-zone fight | ≥300 m from every zone edge | `zone_meta_array` (broadcast; already read this way in `fnc_mission_findSite.sqf:90`) |
| Not inside a side-held town | reject if the nearest town is BLUFOR- or OPFOR-leaning; a neutral town or open ground is fine | `duws_town_circles` for town centres/radii (broadcast, `fnc_civ_init_Tomata.sqf:170`) plus the town-ownership signal — **see Open decisions** |

The finder returns the accepted cluster centre; the thread re-derives the exact hostage building from
there. Only `select 0` reaches the thread (the picker flattens to 2-D), so hand back one position, not a
bundle.

## The build

Reuse the Rescue Pilot captive rig almost verbatim — it already solves the fragile-captive problem — and
the Sabotage Laptop garrison-into-a-named-building placement.

- **Hostage.** Adopt the Escort Informant rig, not the pilot's carry — the hostage can walk. Spawn one
  unarmed man in a random interior slot of the chosen building: `setCaptive true` (a held prisoner the
  guards do not pre-emptively shoot), `disableAI "MOVE"` — *not* `"PATH"` — so he holds in the building
  until freed but can still path once released (`fnc_escort_informant_mission.sqf:41`), and
  `AIS_noReviveInit` so death is death, not an unconscious state the win poll never sees end (`:43`). Add
  the halving `HandleDamage` clamp from `fnc_rescue_pilot_mission.sqf:74-81` on top, so a stray round in
  the firefight cannot instakill him. A surrender/sit animation is optional flavour. **Do not
  `fnc_mission_claim` him** — he is the player's reward; a claim is a deletion order
  (`side_mission_authoring.md` "Never claim what the player is handed").
- **Garrison.** One `garrison:team` raised through `DUWS_fnc_zoneSpawnOne` and `fnc_spreadIntoBuildings`
  into the hostage building by hand — the same placement Sabotage Laptop uses
  (`fnc_sabotage_laptop_mission.sqf:117-127`) rather than the `garrison` posture, which would hunt the
  nearest ≥5-slot structure and could seat the guards in a neighbour. Stamp `DUWS_garrisonedBy` so an
  overlapping town garrison cannot double-occupy the house. These guards are the executioners and the
  primary obstacle; `fnc_mission_claim` them.
- **Foot patrols.** A small ring of `widepatrol`/`closepatrol` foot tokens around the cluster — the
  patrol-ring pattern from `fnc_rescue_pilot_mission.sqf:102-116`, foot-only (no vehicles) to keep the
  encounter a light-infantry stealth problem. Claim them.
- **Marker + brief.** One objective marker on the cluster via `fnc_mission_present`; a precise hostage
  float appears only once a rescuer reaches him, as the pilot icon does
  (`fnc_rescue_pilot_mission.sqf:170-185`), so the marker never pinpoints the exact building for free.

## Detection → execution (the bespoke core)

**Detection is scoped to this mission's own OPFOR units, never side-wide.** `east knowsAbout player`
reads the same flat-high value whether a guard is watching the player or a zone garrison two kilometres
away merely remembers him, and it lingers side-wide until every unit that knew him dies
([gotcha](../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)).
A side-wide gate would execute the hostage because of a firefight the player is having elsewhere. So the
watcher aggregates over the **bounded observer set** — exactly the garrison + patrol groups this thread
spawned — which is the same discipline `fnc_opcom_sense.sqf` follows.

The server-side watcher polls, every ~2 s, every living mission-owned OPFOR unit against every
living West player:

- **Trip on** `_guard knowsAbout _player > ~1.25` for any (guard, player) pair, **or** any mission group
  flipping to `behaviour "COMBAT"`. The behaviour flip catches "a shot was heard / a body was seen" that
  `knowsAbout` is slow to express; the `knowsAbout` gate catches "spotted on approach". Threshold is a
  tunable — high enough that a flicker at extreme range does not count, low enough that a clear sighting
  does. The engine's own front-cone/peripheral/skill/light modelling feeds `knowsAbout`, so sneaking
  behind a guard in the dark genuinely stays quiet with no extra code.
- **One-way.** Once tripped, the alarm does not un-trip if the player breaks contact — the guards have
  raised it and are moving the hostage to be shot. (A softer MGS-style "re-hide to cancel" is possible;
  the one-way rule matches the brief and is simpler — noted under Open decisions.)

### One event, two causes: dropping `setCaptive`

The hostage starts `setCaptive true`. Exactly one event ever flips it to `false`, and it fires on
**whichever of these comes first**:

- **The garrison dies** — the squad guarding him (the building `garrison:team`, not the ring patrols) is
  wiped. `setCaptive false`, and this is also the sole gate that makes him **recruitable** (below). No
  guard is left to shoot him, so he is simply freed. This same moment **converges the surviving ring
  patrols onto the hostage building**, the Rescue Pilot retask (`fnc_rescue_pilot_mission.sqf:193-206`):
  clear each patrol's waypoints, set `AWARE`/`RED`/`FULL`, and add an `SAD` waypoint on the building with
  a `CYCLE` after it, so they sweep in and the exfil becomes a fighting withdrawal rather than an
  uncontested stroll to HQ.
- **The execution clock expires** — detection tripped the 60 s clock and it ran out with a guard still
  alive. `setCaptive false` *drops his protection among live, co-located guards*, who immediately engage
  and cut him down. This is the fiction the brief asks for — "he just turns off captivity" — as the literal
  mechanism, not a scripted `setDamage`.

Because the garrison-death drop cancels the clock, the two causes are mutually exclusive: if the guards
die first he is freed, if the timer wins he is executed. Reliability backstop only: if the co-located
guards have not killed him within a few seconds of an execution drop, force `hostage setDamage 1` (scripted
damage bypasses the `HandleDamage` clamp, per `fnc_rescue_pilot_mission.sqf:74-81`) so a stuck-AI edge
case cannot leave a "freed" hostage the guards never finished.

On detection trip: start the **60 s clock** and warn the player (hint/card). Killing the garrison at any
point — before detection so the clock never starts, or mid-count — frees him; that immediacy is what makes
the stealth-clear path feel responsive.

## Win, fail, exfil

Off the spine (like `rescue_pilot`/`sabotage_laptop`): the win comes through a scripted sequence watched
against the deadline, not a one-shot predicate.

1. **Free** — killing the building garrison drops `setCaptive false` and unlocks recruitment. Only then
   does the leader-gated join action appear, the Escort Informant pattern
   (`fnc_escort_informant_mission.sqf:68-84`): a group leader within ~6 m recruits him, he `enableAI
   "MOVE"`s and walks under his own AI as a group member. Gate the action's show-condition on
   garrison-eliminated so it cannot be used through a wall while the guards are still up. A non-leader
   still sees the action and is told why it did nothing, rather than it silently vanishing. Reuse escort's
   join/leave handler, or a hostage-specific `fnc_rescue_hostage_group` if that one carries informant-only
   side effects.
2. **Exfil** — bring him alive to within 20 m of `PosOfBLUHQ`, the pilot's win range
   (`fnc_rescue_pilot_mission.sqf:224`). He is `setCaptive false` on the walk out — a freed man, a valid
   OPFOR target like the escorted informant — so surviving ring patrols on the route are a real threat and
   the `HandleDamage` clamp keeps a single stray round from being an instant loss.

**Win:** hostage alive at HQ. Eliminating the garrison is instrumental (it disarms the execution clock),
not a separately polled gate — one win condition, fewer moving parts. **Fail:** hostage executed on the
clock, hostage killed in the crossfire, or the deadline expires — each routed through `fnc_mission_finish`
with `"FAILED"` and its own outcome line. Every exit, win or fail, goes through `fnc_mission_finish` so
the garrison, patrols and markers tear down and the slot frees.

## The spine it runs

The standard sequence (`side_mission_authoring.md` "The shape every thread runs"), with two background
watchers hung off it:

1. `[24, _MissionPos, _mission_name, _requester] call fnc_mission_begin` — gate + reward/deadline.
2. `fnc_mission_site` for the exact building inside the vetted cluster; abort if the cluster evaporated.
3. `fnc_mission_notice` build announce.
4. Spawn hostage (unclaimed), garrison + patrols (claimed).
5. `fnc_mission_present` — marker, task, brief.
6. Poll the reach→exfil sequence to `DUWS_curDeadlineAt`; the **detection watcher** and **execution clock**
   run as spawned tails feeding the fail path.
7. `fnc_mission_finish` on every exit.

## Files to touch

| File | Change |
|---|---|
| `mission_threads/rescue_hostage/fnc_rescue_hostage_mission.sqf` | New thread. |
| `mission_threads/rescue_hostage/fnc_rescue_hostage_site.sqf` | New offer-time finder (cluster + zone-distance + town-ownership). |
| `shared/includes/mission_types.hpp` | New row at index 24, launcher `{ [24] call fnc_mission_launch }`. |
| `server/server_fnc_init.sqf` | Register `fnc_rescue_hostage_mission` and `publicVariable` the site finder. |
| `stringtable.xml` | Ready line, description, brief, warning-on-detection, executed/killed/timeout fail lines (English leads). |

No carry action is needed — the hostage walks — so nothing extra is broadcast; the join/leave actions are
plain `addAction`s on the hostage, as Escort Informant does.

## Reward

Base pay tracks required effort, not the archetype. This is a multi-guard clear *plus* an escort *plus* a
stealth fail-timer — heavier than Rescue Pilot (25/25) and about level with Sabotage Laptop's reworked
garrison clear (30/20). Propose **30 CP / 25 AP**, `objective "rescue"`, `category "command"`,
`surveyKind "map"`, destination fields default (no convoy). Deadline `[0.6667, 1.5]` h. Confirm against
the catalogue's effort ladder before landing.

## Open decisions

- **Town-ownership signal for the finder.** *Resolved.* Only the OPFOR band was broadcast
  (`DUWS_enemy_town_pos`); BLUFOR lean lived in the server-only `civ_town_rep`. `fnc_enemy_towns_refresh`
  (`fnc_economy_init.sqf`) now also publishes `DUWS_blufor_town_pos` (rep ≥ +10 town centres) on the same
  band-crossing rebuild, so the finder rejects a candidate sitting inside either faction's town via those two
  lists matched against `duws_town_circles` for the radii. `civ_town_rep` itself stays server-local.
- **One-way alarm vs re-hide-to-cancel.** **Recommend one-way** per the brief; revisit only if playtest
  finds the death clock too punishing, in which case allow the clock to pause while no mission guard has
  fresh `nearTargets` knowledge of any player.
