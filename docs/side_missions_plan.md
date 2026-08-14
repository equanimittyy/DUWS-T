# Side missions: rework plan

Working SSOT for the side-mission rework: the catalogue of what each mission is and how it
actually plays, the reward re-pricing, and the open design ideas. Mission data itself lives in
`src/duws/shared/includes/mission_types.hpp` (one row per type); this doc is the reasoning and the
decisions behind those numbers, not a second copy of them.

The reward *pipeline* (how a base CP/AP payout is multiplied and credited) is not restated here --
see [`docs/info/economy.md`](info/economy.md#faucets) and
[`docs/economy_second_pass.md`](economy_second_pass.md). In short: a thread's base CP/AP
(`mission_types.hpp`) is scaled by `cp_reward_multiplier` (campaign 1-5), a ×1.5 civs-off CP lift,
and the strategic map's depth boost (deep offers pay 1.5×-2×), then credited in
`src/duws/server/missions/fnc_mission_reward.sqf`. This rework only sets the **base** numbers.

## What exists now

- **Two classification axes**, both authored per row and already shipped:
  - `category` -- `command` (HQ-issued) or `civilian` (population-issued). Civilian = the two
    REP-granting missions today (protect_civ, transport_IDAP).
  - `objective` -- the archetype: elimination, assault, sabotage, requisition, rescue, defend,
    escort, recon. Metadata only; no code branches on it yet.
- **Reward is hand-set** CP/AP/REP columns. An earlier experiment to derive CP/AP from
  objective×difficulty was built and then rolled back: for 17 fixed missions a formula fought the
  per-mission tuning (only 3 payout buckets per objective; same type+difficulty paid identically).
  Hand-set values with the tags as metadata is the chosen shape.

## Architecture: mission-owned site selection

Today the picker (`fnc_stratmap`) chooses every offer's position with one generic weighted search
and hands it to the thread, which can only refine locally (`fnc_mission_launch.sqf:22-23` → the
thread's `fnc_mission_site`). A mission cannot demand terrain that fits it: intel needs a
≥20-building town, but the picker never looks for one, so intel is offered on open ground and then
aborts *after* the player picks (`fnc_intel_gathering_mission.sqf:9`).

**Model -- propose and accept.** The picker keeps generating candidate positions with its existing
weighting (easy offers repelled from zones/hardpoints via `_fnUrbanWeight`; hard offers pulled deep
toward them via `_fnHardScore` -- unchanged). Each candidate is offered to the drawn mission's own
site-finder, which **accepts** (returning a precise position) or **rejects**; on rejection the picker
draws another candidate, bounded, until one is accepted or the offer is dropped.

**Contract:**

```
[_candidatePos] call fnc_site_<key>
   -> []                       reject -- this spot does not fit me
   -> [_precisePos, _extra...] accept -- my objective sits at _precisePos
```

Resolved at offer time inside the picker's `while {!_Posfound}` loop, so the map marker and the
depth-boost read the *accepted* precise position -- the pre-pick figures stay honest.

**Dispatch.** A default generic finder accepts the candidate as-is (today's behaviour); a mission
overrides by defining `fnc_site_<name>`, and the picker uses it when present. Finders are compiled
and `publicVariable`'d like `fnc_stratmap`, since the picker runs client-side, and only do terrain
queries (local, no locality issue).

**Bound.** Each offer tries at most K candidates; K rejects drops the offer and logs it (fewer than
the 7 drawn get offered), never an unbounded search.

**Phases:**
1. Dispatch + generic finder + the picker gate, behaviour-preserving (generic accepts every
   candidate, so the current draw is unchanged).
2. Intel: a town finder (accept only where a ≥20-building town sits, return its centre) + the thread
   trusts the finder's position; then the intel internals rework.
3. Other missions gain finders as their reworks require.

## Mission catalogue (how each actually plays)

Effort is a 1-5 read of the *required* fight, from a thread-by-thread analysis. Shared force per
mission: garrison ~24 (`fnc_garrisonBuildings`, 6 buildings × 4) and/or a patrol ring
(`fnc_missionPatrols` = 16 inf, `fnc_missionPatrolswithintel` = 12 inf). Every patrol-ring mission
also gains **1 MBT + 2 armed cars** once OPFOR crosses AP 350/60 -- so ring missions get harder as
the campaign advances while their pay is fixed.

| # | Mission | Obj | Cat | Win condition | Extra force / special | R | Eff | Now CP/AP/REP |
|--:|---------|-----|-----|---------------|-----------------------|--:|:-:|:-:|
| 12 | Hold position | defend | cmd | survive 550s, SAM+radar alive | ~72 attackers in escalating waves | 300 | 5 | 30/36/0 |
| 13 | Domination | assault | cmd | 4 tank crews dead | **4× MBT** + 30 inf, allies die on script | 800 | 5 | 10/30/0 |
| 1 | Steal supply truck | requisition | cmd | truck <100m of HQ | steal **intact** + ~600m drive back | 600 | 4 | 35/24/0 |
| 6 | Steal eng. vehicle | requisition | cmd | repair truck <50m of HQ | steal intact + drive back | 500 | 4 | 15/20/0 |
| 4 | Rescue pilot | rescue | cmd | pilot <50m of HQ | keep fragile AI alive + escort back | 300 | 4 | 25/40/0 |
| 2 | Kill HVT | elimination | cmd | HVT officer dead | mobile HVT + **APC** screen | 600 | 3 | 35/36/0 |
| 5 | Kill snipers | elimination | cmd | both snipers dead | 2 hidden ghillies, no vehicles | 400 | 3 | 30/30/0 |
| 10 | Destroy radar | sabotage | cmd | radar destroyed | 2 HMG + **2 invulnerable AA** | 400 | 3 | 25/24/0 |
| 9 | Destroy cache | sabotage | cmd | **both** caches destroyed | 2 crewed HMG | 400 | 3 | 30/20/0 |
| 11 | Clear area (CQB) | assault | cmd | all 24 house units dead | full clear, no shortcut | 200 | 3 | 15/20/0 |
| 7 | Destroy armour | elimination | cmd | commander officer dead | tank is an **inert prop** | 200 | 2 | 15/20/0 |
| 0 | Rescue squad | rescue | cmd | reach squad (100m) | **no escort back** -- ends on arrival | 300 | 2 | 45/24/0 |
| 3 | Destroy tower | sabotage | cmd | tower destroyed | tower **pre-broken to 0.8** | 400 | 2 | 20/30/0 |
| 8 | Sabotage laptop | sabotage | cmd | one hold-action | compact, light verb | 200 | 1 | 10/36/0 |
| 16 | Intel gathering | recon | cmd | 900s timer, auto-success | **guaranteed payout**, combat optional | 800 | 2* | 5/10/0 |
| 14 | Protect civilian | defend | civ | -- | not yet analysed | -- | -- | 20/10/5 |
| 15 | Transport IDAP | escort | civ | -- | not yet analysed | -- | -- | 20/10/5 |

`*` intel's *required* effort is ~1 (payout is guaranteed on a timer); its ambient force is the
largest on the map but entirely avoidable.

## Pricing rework (command missions)

Principle: base pay tracks required effort, holding the command economy near today's aggregate
(~345 CP / 400 AP). CP leans to command/intel/tactical value, AP to materiel destroyed or manpower
recovered. Proposed column is a starting point, not decided.

| Mission | Eff | Now CP/AP | Proposed | Note |
|---------|:-:|:-:|:-:|------|
| Hold position | 5 | 30/36 | 35/35 | hardest hold |
| Domination | 5 | 10/30 | 30/40 | **worst-paid vs effort** -- the 4-MBT fight |
| Steal supply truck | 4 | 35/24 | 30/26 | intact + long return |
| Steal eng. vehicle | 4 | 15/20 | 28/26 | **half its identical twin today** |
| Rescue pilot | 4 | 25/40 | 26/32 | keep-alive + escort |
| Kill HVT | 3 | 35/36 | 32/26 | APC screen premium |
| Kill snipers | 3 | 30/30 | 26/26 | |
| Destroy radar | 3 | 25/24 | 22/28 | |
| Destroy cache | 3 | 30/20 | 22/28 | two objectives |
| Clear area (CQB) | 3 | 15/20 | 26/24 | **underpaid for a 24-kill clear** |
| Destroy armour | 2 | 15/20 | 16/18 | gimme (inert tank) |
| Rescue squad | 2 | 45/24 | 18/18 | **biggest overpay today** |
| Destroy tower | 2 | 20/30 | 16/18 | gimme (pre-broken) |
| Sabotage laptop | 1 | 10/36 | 18/16 | AP was overpaid for one hold-action |
| Intel gathering | 2* | 5/10 | 12/12 | price as passive income |

## Per-mission rework tracker

Status: `idea` (unconfirmed), `decided` (price/change locked), `done` (in `mission_types.hpp`).
Gameplay-change ideas below come from the play-through analysis; all are unconfirmed suggestions.

| Mission | Price status | Gameplay change idea | Status |
|---------|:-:|----------------------|:-:|
| Hold position | proposed | -- | idea |
| Domination | proposed | -- | idea |
| Steal supply truck | proposed | -- | idea |
| Steal eng. vehicle | proposed | match effort of its twin | idea |
| Rescue pilot | proposed | -- | idea |
| Kill HVT | proposed | -- | idea |
| Kill snipers | proposed | -- | idea |
| Destroy radar | proposed | -- | idea |
| Destroy cache | proposed | -- | idea |
| Clear area (CQB) | proposed | -- | idea |
| Destroy armour | proposed | tank is inert -- make it a live threat, or reframe as "kill the commander" | idea |
| Rescue squad | proposed | add an escort-back leg so effort matches a rescue | idea |
| Destroy tower | proposed | spawn the tower intact so destruction is real work | idea |
| Sabotage laptop | proposed | fine as a quick mission; keep light | idea |
| Intel gathering | proposed | tie payout to an actual search instead of a blind 900s timer | idea |

## Open decisions

- Final per-mission command prices (approve the proposal or override per row).
- Which missions get a gameplay change vs price-only (the ideas above).
- Whether late-campaign armour creep on ring missions needs pay scaling, or the map depth boost
  already compensates.
- Civilian missions (protect_civ, transport_IDAP): analyse and price -- deferred for now.
