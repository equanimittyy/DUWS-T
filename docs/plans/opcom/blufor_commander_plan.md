# BLUFOR commander: the Advanced Overlord

The BLUFOR Commander AI campaign param selects what drives BLUFOR's AI squads. **Simple**, the default, keeps the
Overlord task forces that ship today (`server/warcom/fnc_taskforce_tick.sqf`). **Advanced** runs a second instance of
OPCOM's decision layer ([`opcom_plan.md`](opcom_plan.md)) for BLUFOR: the same tick, perception, appraisal, attack
runner and routes, fed with BLUFOR's side, its ground and what it knows of OPFOR.

The Advanced commander does four things. It stages assaults on OPFOR zones (`attack_assault`, `attack_flank`), it
answers OPFOR contact on BLUFOR ground (`attack_qrf`), it patrols stale ground (`patrol`), and it probes an assault
target (`probe`). It has no economy: its units are the free task forces that Simple spawns, and it spends, banks and
hires nothing. It builds nothing, buys no zone tier and garrisons no zone.

Not in this plan: the commander's recruitment upgrades, and any economy for the commander.

## Status

| Phase | State |
|---|---|
| 0 — Free squad cap: BLUFOR's tier and the zones it holds set how many free task forces stand, up to 6, in both modes | **shipped** |
| 1 — Commander record: OPCOM's per-commander state and its side inputs move into one record per side, OPFOR only | **shipped** |
| 2 — The Advanced commander: the param, BLUFOR's record, perception, task forces as its units, actions, persistence and debug | **shipped** |

Phase 0 lands first. It changes the free spawn that both modes use, so it plays in Simple before Phase 2 builds on
it. Phase 1 changes no behaviour. It comes before Phase 2 because Phase 2 is a second record on the same code, and a
BLUFOR copy of the code would double every later OPCOM change.

## What Advanced reuses

| OPCOM part | Advanced BLUFOR |
|---|---|
| Tick, belief, influence grid, staleness, traffic | Reused, on BLUFOR's own record |
| Score, shortlist, roll | Reused. `Cost` ranks candidates in AP units, a free unit's stake and its distance; nothing is paid |
| Sourcing | Free units only |
| Attack record and runner: buildup, muster, assault, flank, QRF, release, resolve, break | Reused |
| Patrol, Probe | Reused |
| Routes and λ | Reused, through the live group's waypoints |
| Archetype weights and patience | Reused; the task-force stance selects the record ([§Task forces](#task-forces)) |
| Wallet, prices, hires, Bank, the savings goal, the drip, land-taxi, ferry | Not used: the units come from the free task-force spawn |
| Streaming: virtual units, de-virt, stow | Not used: every BLUFOR commander unit stays live |
| Garrison, zone Reinforce and Fortify, every Build, Minefield, Rapport, arty, supply errands | Not in BLUFOR's action list |
| HQ and FOB discovery, FOB overrun | Not used: OPFOR has neither |

## Phase 0: the free squad cap

The cap on Overlord's free task forces counts BLUFOR's tier and the zones that BLUFOR holds, up to 6. Both modes
spawn through it, because Advanced keeps Simple's free spawn.

```
cap = min(FREE_MAX, tierCap + held zones)
```

- `tierCap` is today's cap by BLUFOR tier: 1, 1, 2, 2 or 3 (`fnc_taskforce_tick.sqf`).
- Each zone in `WARCOM_zones_controled_by_BLUFOR` adds 1, so a lost zone takes its slot back. A squad already alive
  over the cap stays: the cap only stops the next spawn.
- `FREE_MAX` (6) is a `#define` in `fnc_taskforce_tick.sqf`, beside `FIRST_SPAWN` and `RESPAWN`.
- The timer does not change: the first squad 5 minutes in, then 30 minutes apart.
- A handed squad still does not count against the cap.
- Nothing new is saved: the cap reads the tier and the held zones at each tick.

At tier 1 with no zones the cap is 1; at tier 3 with 2 zones it is 4; at tier 5 with 3 zones it is 6.

| Chunk | Builds |
|---|---|
| **0.1** Free squad cap | **Shipped** — the cap above in `fnc_taskforce_tick.sqf`, and the task-force line of `performance.md` |

## Phase 1: the commander record

### The record

`DUWS_opcom_cmds` is a hashmap from a side key to a commander record. The key is the `fnc_ap_adjust` side, `"OPF"`
or `"BLU"`. A record is a field-keyed hashmap that holds:

- the per-commander state: the tasking and attack stores and their sequence counters, the attack and supply
  cooldown ticks, the battery ready ticks, the belief store, the grid's own and enemy layers and their static cache,
  the staleness and traffic layers, the need field and its signatures, the tick cache, the pick debt, the picks per
  tick, the pick-once mode, the AI mode, the archetype and the debug counters;
- the side inputs ([§Side inputs](#side-inputs)).

These stay global: the war clock `DUWS_opcom_tick`, the grid geometry (`DUWS_opcom_grid_w`, the box, the land, water
and landmass layers, the ports), the data tables (`DUWS_opcom_recruitMenu`, `DUWS_opcom_moveType`,
`DUWS_opcom_speed`, `DUWS_opcom_streamK`, `DUWS_opcom_moveWater`, `DUWS_opcom_orders`, `DUWS_opcom_actions`,
`DUWS_opcom_archetypes`), the stores only OPFOR has (HQ and FOB discovery, the contested set, pending builds, mine
variants, ferry hulls) and every `OPCOM_*` constant. A constant that must differ by side becomes a record field
in the chunk that needs it.

- **The tick sets `_cmd`.** The loop runs each commander's stages under `private _cmd = DUWS_opcom_cmds get _side`,
  and every function below it reads its state from `_cmd` through dynamic scope, as the hardpoint banner tick reads
  `_hpDone` (`fnc_init_OPFOR_WARCOM.sqf`). A `spawn` or an event handler takes the record as an argument, because a
  new script inherits no scope.
- **A reader outside the tick names its side.** The site poller, the OP posts (`fnc_hardpoint_stream.sqf`), the
  intel payout, the target recon mission, the zone-garrison entry points (`DUWS_fnc_opcom_zoneReserveSync`,
  `DUWS_fnc_opcom_defenderLost`, `DUWS_fnc_opcom_siteLost`), the save snapshot and the debug pages read
  `DUWS_opcom_cmds get "OPF"`. The restore runs in the OPCOM thread under the tick's `_cmd`.
- **A dirty mark writes into every record.** `DUWS_fnc_opcom_gridDirty` and `DUWS_fnc_opcom_gridDirtyAll` run on
  other threads, so they mark each registered record; a record is registered only once it is built.
- **The loop runs OPFOR's stages, then BLUFOR's**, on the one `OPCOM_TICK_PERIOD` tick and the one idle wait.
- **Rejected: a swap of the old globals for each commander's turn.** The readers outside the tick run in other
  scheduled threads, so they would read whichever side is swapped in. **Rejected: a BLUFOR copy of the code.**

### Side inputs

Each row is a record field. The helpers that read them are in `belief/fnc_opcom_side.sqf`.

| Field | OPFOR | BLUFOR | Read at |
|---|---|---|---|
| `side`, `enemySide` | `east`, `west` | `west`, `east` | the sighting sweep, the patrol and intercept looks, the task step's streaming read |
| `wallet` | true: `WARCOM_opfor_ap`, paid through `["OPF", …] call fnc_ap_adjust` | false: no hire, no charge and no savings goal | `DUWS_fnc_opcom_funds` and `DUWS_fnc_opcom_pay`, from the pick, the sources, the lift, the recruit and every refund |
| `streams` | true | false: a tasking never stows and is never virtual | `fnc_opcom_task_step.sqf` |
| `enemyZones` | `"WARCOM_zones_controled_by_BLUFOR"`, the name, since the list is re-assigned | `"WARCOM_zones_controled_by_OPFOR"` | `DUWS_fnc_opcom_enemyZones` and `DUWS_fnc_opcom_enemyHeld`, from the grid's zone source, the exposure ground, the need field's band, the capture order and the assault targets |
| `covers` | `fnc_aoi_opfor_covers` | `fnc_aoi_blufor_covers` | the QRF sweep |
| `captureRest` | `garrison` at the zone it takes | `guard` where it stands | `DUWS_fnc_opcom_captureEnd` |
| `actions` | every row of `DUWS_opcom_actions` | `attack_assault`, `attack_flank`, `attack_qrf`, `patrol`, `probe` | `fnc_opcom_pick.sqf` |

`DUWS_fnc_opcom_defend` keeps `fnc_zone_bluforHeld`, because the radio tower's siting reads it at startup, before any
record exists.

### Chunks

| Chunk | Builds |
|---|---|
| **1.1** Record | **Shipped** — `DUWS_opcom_cmds` with OPFOR's record, `_cmd` set by the tick, every per-commander store and scalar in the record, and every reader outside the tick on `get "OPF"` |
| **1.2** Side inputs | **Shipped** — every field of [§Side inputs](#side-inputs) on OPFOR's record, and every read in that table routed through it |

## Phase 2: the Advanced commander

### The param

`DUWS_BluforCommander`, titled "BLUFOR Commander AI", is a lobby param: Simple (0, the default) or Advanced (1). It is
read into `DUWS_paramBluforCommander` (`server_var_init.sqf`) and listed in the config diary
(`fnc_duws_config.sqf`). It is a campaign rule, so it is saved in `DUWS_campaignParams`
(`fnc_campaign_store.sqf`), and the load screen's EDIT PARAMS can change it: a new row in `campaign_load_menu.hpp`,
which grows that dialog by 1.5 grid rows.

- Simple builds no BLUFOR record, and `fnc_taskforce_tick` calls Simple's standing orders (`fnc_taskforce_orders`).
- Advanced builds BLUFOR's record at OPCOM init (`fnc_opcom_cmd_new`, from its side inputs in
  `fnc_opcom_perception_run.sqf`) and runs its sensing, belief upkeep, bookkeeping, grid, task step, attack runner,
  need and pick after OPFOR's stages. `fnc_taskforce_tick` keeps its upkeep and calls `fnc_taskforce_commander` in
  place of the orders ([§Task forces](#task-forces)).
- Both commanders start weighted; the Debug menu's mode rows switch the one selected ([§Debug](#debug)).

| A load that switches the mode | Result |
|---|---|
| Simple to Advanced | The saved task forces restore, and the commander takes each one with an empty store |
| Advanced to Simple | The saved task forces restore onto the Simple tick. The BLUFOR store is not restored, so only the standing orders are lost |

### Perception

BLUFOR's belief is about OPFOR, and it holds only what BLUFOR can know.

- **Sensors.** Every live west group is an observer, the players' groups included. Its leader's `nearTargets`
  reports each east group that it fixes, through the shipped sweep (`fnc_opcom_sense.sqf`) with the sides swapped.
  The hardpoint contact reveal, the HQ and FOB discovery and the base-cell blindness stay OPFOR's only. An OPCOM unit
  that is virtual is on no group list, so BLUFOR sees it only once it renders.
- **Own force.** Each BLUFOR zone deposits on BLUFOR's own layer at its garrison force, each commander unit at its
  live `effForce`, and each live player group at its force, with a player worth 1 + `OPCOM_PLAYER_WORTH`.
- **Enemy force from intel.** Each revealed OPFOR zone deposits on the enemy layer at its true garrison force, the
  strength that the map readout's bar shows, and each revealed OPFOR hardpoint at its `DUWS_fnc_hpForce`. A hidden
  zone or hardpoint deposits nothing, so in hardcore mode the commander plans only against what the players found
  ([`intel_system.md`](../../info/gameplay/intel_system.md)). `fnc_zone_reveal` and `fnc_hardpoint_reveal` mark each
  flag they set on the grids (`DUWS_fnc_opcom_gridDirty`).
- **Need.** Each BLUFOR holding spreads its worth × exposure over its 7×7 block, as OPCOM's need does: a BLUFOR
  zone, the HQ (`OPCOM_HQ_WORTH`), each FOB (`OPCOM_FOB_WORTH`) and each BLUFOR-banded town. Exposure is measured to
  the OPFOR ground that BLUFOR knows: each revealed OPFOR zone and each visible OPFOR-banded town. Traffic from
  OPFOR sightings adds as it does for OPCOM. There is no band base and no hardpoint deposit, because BLUFOR builds
  nothing.

### Contact

Every BLUFOR commander unit is a live task force, so the shipped rules cover contact and Phase 2 adds none. An
OPCOM unit renders on a live BLUFOR group within its K (`fnc_opcom_task_step.sqf`), and an OPFOR site wakes for
a live BLUFOR unit inside its ring (`fnc_site_poller`, `server/misc/fnc_site_stream_init.sqf`). A fight away from the players runs
as it runs for Simple's task forces today.

### Task forces

- **Every task force is a commander unit.** `fnc_taskforce_create` registers a squad as today, handed over or
  spawned: its name, its marker and its list row. In Advanced, `fnc_taskforce_commander` gives each live task force a
  live-only tasking on the next tick, whatever path brought it in. The tasking is bound to the squad's group, or, with
  no group (restored), to the task force of its name (`taskforce`). Its `effForce` is read live, and its move type is
  read off the hull the squad rides each tick. It is drawable like any other unit, so the pick can bind it to an
  attack, a QRF, a patrol or a probe.
- **Take back** (`fnc_taskforce_release`) unbinds the tasking at once, so no task step orders the squad after the
  player has it. `fnc_taskforce_commander` then drops every tasking whose task force is gone, and its id from every
  attack role, in the OPCOM thread.
- **The free spawn stays Simple's.** `fnc_taskforce_spawn` raises Overlord's own task forces at the HQ, its section
  drawn by BLUFOR's tier, on the shipped timer and the Phase 0 cap ([§Phase 0](#phase-0-the-free-squad-cap)).
- **The tick splits in two.** `fnc_taskforce_tick` keeps the upkeep (the free timer and spawn, the markers, the lost
  line, the status that the list reads). Simple's orders (the objective, the stance split, the defend posts, the town
  patrols and the HQ hold) are `fnc_taskforce_orders`, which only Simple calls.
- **The Task Force list** (`fnc_taskforce_list.sqf`) reads the commander's orders: hold, stage for an attack,
  capture, respond to contact, patrol and probe.
- **The stance selects the weights.** Attack, Balanced and Defend (`DUWS_taskforce_stance`) select the Aggressive,
  Balanced and Defensive archetype records for BLUFOR's record. The Aggressive and Defensive records stand in
  `fnc_opcom_archetypes.sqf` on Balanced's mixes ([`opcom_plan.md` §Archetype](opcom_plan.md#archetype-phase-7)). A
  record weighs only the actions its commander has.
- **Dialogue.** The deploy and lost lines fire from the task-force code, as today. An attack launch and a QRF launch
  each give one Overlord line, from two new keys. A patrol and a probe are silent. Each new key carries every
  language tag ([`player_text_style_guide.md`](../../info/gameplay/player_text_style_guide.md)).

### Actions

| Action | Targets | Ends on |
|---|---|---|
| `attack_assault`, `attack_flank` | each revealed OPFOR zone on a unit's landmass, under OPCOM's gates: one assault or flank open at a time, `OPCOM_ATTACK_COOLDOWN` and the band. No HQ or FOB target | the zone in `WARCOM_zones_controled_by_BLUFOR`, through the shipped capture rule, then every attacker to `guard` where it stands |
| `attack_qrf` | each cluster of OPFOR sightings that BLUFOR's area covers (`fnc_aoi_blufor_covers`), outside every OPFOR zone's radius (`DUWS_fnc_opcom_qrfBarred`), with no QRF on it and no local defense at the ideal bar | as OPCOM's QRF |
| `patrol` | stale cells on BLUFOR's staleness and need | as shipped |
| `probe` | each assault or flank target above whose block reads stale | as shipped |

- **There is no Bank row.** The pick commits the best candidate it draws, because nothing is saved toward.
- **No hire.** A commander without a wallet is offered no hire source (`DUWS_fnc_opcom_hireSources`).
- **No target lies across water.** Without a ferry, a source on another landmass is no source for the target.
- **A capture is the shipped BLUFOR capture.** A BLUFOR attacker takes a zone as a task force does today, and the
  capture pays what a BLUFOR capture pays today. A live attacker done with its waypoints hunts the zone's nearest
  surviving defender, as Simple's task forces do (`DUWS_fnc_opcom_stepCapture`).
- **The local defense counts the players.** The QRF gate reads BLUFOR's own layer, players included, so a QRF goes
  where the BLUFOR force in contact is short of the ideal bar against the cluster.

### Persistence

The commander's store is campaign state, so a load resumes its standing orders and does not decide them again
([`campaign_persistence_plan.md` §The commander](../campaign_persistence_plan.md#the-commander)).

| Saved, under snapshot key `opcomBlu` | Not saved |
|---|---|
| the taskings with `taskSeq`, the attacks with `attackSeq`, the attack cooldown | belief, the grid layers, the need field and the debug state, which rebuild as OPCOM's do |

- The squads, the free-spawn timer and the stance are saved already (`taskforces`, `taskforceSpawnIn`,
  `taskforceStance`), and so is the tick (`DUWS_opcom_tick`).
- The save is OPCOM's `DUWS_fnc_campaignTaskings`, called with BLUFOR's record. The restore is
  `DUWS_fnc_restoreCmd`, the part of OPFOR's restore that every commander shares, called in the OPCOM thread after
  OPFOR's restore and after `DUWS_fnc_restoreTaskforces`.
- Each tasking keeps its id, so an attack role that names it resumes. The restore then runs
  `fnc_taskforce_commander` once, so each tasking is bound to the task force that restored under its name before the
  first tick.

### Debug

- The Debug menu's OPCOM page gains a Commander row, shown only in Advanced, that switches between OPFOR and BLUFOR
  (`DUWS_opcom_dbgSide`). The mode, Pick once, Difficulty, the grid drift check and the hand-driven orders act on the
  selected commander; recruits, buys, supply, fires and ferries stay OPFOR's.
- The OPCOM AI overlay and the grid overlay draw the selected commander's record.

### Chunks

| Chunk | Builds |
|---|---|
| **2.1** Param and boot | **Shipped** — the lobby param, its config diary row, its `DUWS_campaignParams` entry, the EDIT PARAMS row, BLUFOR's record built and ticked in Advanced, and the task-force tick split |
| **2.2** Perception | **Shipped** — BLUFOR's sensors, its own and enemy grid sources, and its need field |
| **2.3** Task forces | **Shipped** — every task force as a live-only tasking, Take back, the list's order texts and the stance on the archetype records |
| **2.4** Actions | **Shipped** — BLUFOR's action list, `captureRest`, the QRF on BLUFOR ground, patrol and probe on BLUFOR's fields, and the two dialogue keys |
| **2.5** Persistence | **Shipped** — the `opcomBlu` key, its restore, the task-force binding and the switch rules |
| **2.6** Debug | **Shipped** — the Commander row and both overlays |

Phase 2 lands in order. An attack needs belief of OPFOR and units to draw, so 2.2 and 2.3 land before 2.4.

Phase 2 settles in play:

- Whether the Phase 0 cap and the 30-minute spawn field enough units to meet the muster bars, so that an attack
  launches rather than expires.
- Whether a free unit with nothing worth doing should patrol, or hold where it stands, now that no Bank row competes.
- The server cost of two commanders on one tick ([`performance.md`](../../info/architecture/performance.md) records
  the figure).
- Whether a QRF should also answer players in contact outside BLUFOR's area.
- The archetype weights for BLUFOR's stances, beside OPCOM's.
