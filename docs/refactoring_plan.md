# Refactoring: where the structure fights the maintainer

An audit of `src/duws/` for structural debt — duplication, god files, and the places where
adding one feature costs edits in five. Ordered by return on effort, not by severity.

Scope is the owned tree only. `src/modules/` is vendored and frozen
([`info/architecture.md`](info/architecture.md#vendored-frameworks--modules)); nothing here
touches it.

## What SOLID means in SQF

SQF has no classes, no interfaces, no visibility modifiers and no dependency-injection
container, so four of the five principles need restating before they mean anything here. The
translation used throughout:

| Principle | What it maps to in this codebase |
|---|---|
| Single responsibility | A file does one job. `server_fnc_init.sqf` being both a path registry and the home of 36 function bodies is the violation shape. |
| Open/closed | Adding an instance of an existing concept (a side mission, a support, a faction) edits data, not control flow. A `switch` with one case per instance is the violation shape. |
| Liskov substitution | Where N files implement the same implicit contract — same `params`, same lifecycle obligations — every one of them honours it. A copy that silently dropped a step is the violation shape. |
| Interface segregation | A function's `params` contract is narrow and honest. A file that is a function *and* defines three other globals as a side effect is the violation shape. |
| Dependency inversion | Call sites depend on a name, not a path. The registry already does this well; the exceptions are `call compile` and dynamically-named globals. |

Two engine facts constrain every fix below and are the reason some obvious-looking cleanups are
not recommended:

- **Paths are string literals with no resolver.** Moving a file breaks every reference silently
  ([`info/architecture.md`](info/architecture.md#path-references-are-string-literals)). Any
  change that moves files must be followed by `bash tests/run.sh`, whose `check_paths.py` is
  the only automated guard that exists for this.
- **Code blocks do not capture locals.** A block stored now and run later sees only globals and
  its own `_this`. Several of the global-variable findings below are that constraint being
  worked around, not carelessness — the fix has to preserve the deferral, not just delete the
  global.

## How this was measured

A normalised clone detector over `src/duws/` (comments and whitespace stripped, 8-line seed
windows extended to maximal blocks) run with the 255-file `shared/factions/` data directory
excluded, since near-identical data tables are expected there and would swamp the result.

**2,348 of 25,168 non-data lines are duplicated — 9.3%.** All ten of the largest clone blocks sit
in `server/missions/mission_threads/`, which is why that directory leads the plan: they are the
same 45-line epilogue repeated across nine of the threads.

## Tier 1: quick wins

Small, self-contained, and each one is a strict improvement with no design argument attached.

### The registry has one duplicate entry and one dead one

`fnc_missionLocator` is registered twice from the same path — `server/server_fnc_init.sqf:705`
and `:1200` — and only the second broadcasts it, so the first is doing nothing the second does
not redo.

`fnc_missionPatrolsSmall` (`:726`) is registered and then called from nowhere in `src/`: its only
reference in the tree is the registration itself.

### `call (compile _var)` where `getVariable` is meant

Eight sites read a global by reconstructing its name as a string and invoking the compiler on it:

```sqf
_var = "blufor_RQST_VEHICLE_0" + (str (_index - 1)) + "_X";
_vehicle = call (compile _var);                    // client/dialog/fnc_request_vehicle.sqf:14-18
```

`compile` parses SQF at runtime. Here it parses an identifier — the parse result is a variable
read. `missionNamespace getVariable _var` does the same lookup with no parser involved and, more
usefully, takes a default so a missing entry yields `[]` instead of a script error. The menu
builders at `client/dialog/fnc_HQ_Request_Menu.sqf:26,70` and
`client/dialog/fnc_FOB_Request_Menu.sqf:28,73` run this inside a `while {true}` loop, once per
row, every time the dialog opens.

Sites: `fnc_request_vehicle.sqf:18`, `fnc_request_vehicle_fob.sqf:19`, `fnc_request_unit.sqf:21`,
`fnc_request_unit_fob.sqf:20`, and the four menu-builder lines above.

### Dynamically-named globals for zone and FOB triggers

```sqf
_zonePosName2 = format["trigger2%1%2", round (_zonePos select 0), round (_zonePos select 1)];
call compile format["%1 = _trg2", _zonePosName2];   // server/init_zones/fnc_createzone.sqf:224-225
```

This synthesises a global variable name from a coordinate and assigns to it through the
compiler. `server/supports/fnc_fob_server.sqf:60` does the same for FOB triggers, and
`server/dialog/fnc_FOB_cleanup.sqf:14,17` reads them back the same way. The consequence is that
no grep can find the writer of `trigger2123456` — the identifier does not exist in the source.

A `missionNamespace setVariable [_name, _trg2]` is a one-line change that keeps the same keying
and removes the compiler. The larger fix is a single hashmap keyed by the rounded position, but
the one-line version is worth taking on its own.

## Tier 2: the copy-paste layer

This is where the 18.7% lives, and where duplication has already cost behaviour.

### The building-garrison block: 90-odd lines, nine copies, one drifted

Nine mission threads contain the same routine — find enterable buildings near a point, pick up
to six, spawn four OPFOR per building, and start a per-unit reposition loop:

| File | Span | Lines |
|---|---|---|
| `missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf` | `202-298` | 97 |
| `missions/mission_threads/destroy_radar/fnc_destroy_radar_mission.sqf` | `127-217` | 91 |
| `missions/mission_threads/destroy_tower/fnc_destroy_tower_mission.sqf` | `113-203` | 91 |
| `missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf` | `72-162` | 91 |
| `missions/mission_threads/steal_builder/fnc_steal_builder_mission.sqf` | `94-184` | 91 |
| `missions/mission_threads/steal_supply/fnc_steal_supply_mission.sqf` | `139-229` | 91 |
| `missions/mission_threads/target_armor/fnc_target_armor_mission.sqf` | `64-154` | 91 |
| `missions/mission_threads/target_hvt/fnc_target_hvt_mission.sqf` | `83-173` | 91 |
| `missions/mission_threads/target_sniper/fnc_target_sniper_mission.sqf` | `47-136` | 90 |

Eight are identical modulo the position variable's name. `target_sniper` is not, and the
difference is player-visible: it declares `_buildingGroup` inside the `if` block rather than
before it (`:90`), so the group is unreachable after the block — and the two passes the other
eight run there, `fnc_add_intel_to_group` and `fnc_addRandomLoot`, are simply absent. **A sniper
hunt's building garrison drops no corpse intel**, where every other mission's does. Nothing in
the source says that is deliberate. That is the substitutability failure in concrete form: one
copy of a shared routine quietly lost a step, and there is no single definition to compare it
against.

Two more files solve the same problem a third and fourth way rather than copying it:
`server/init_zones/fnc_createopfortified.sqf:49-55` (eight buildings) and
`missions/mission_threads/clearthearea_cqb/fnc_clearthearea_cqb_mission.sqf:42-80` (four, and
also no intel pass). They share `fnc_usableBuildings` and the `_desiredBldgCount` idea but not
the code, so they are reimplementation rather than duplication — worth folding into the same
helper, but they are not evidence of copy-paste drift and should be converted last.

The extraction has precedent in the same tree: `server/misc/fnc_usableBuildings.sqf` is already a
19-line shared helper that every one of these ten calls. The block wants to become
`fnc_garrisonBuildings` taking `[_pos, _radius, _bucketKey]` and returning the group, with the
intel and loot passes inside it so a caller cannot forget them.

**Decide the drift before extracting, not during.** If the two outliers are correct and the
other eight over-reward, the shared version needs a flag; if they are wrong, extracting fixes
two missions' intel economy as a side effect and that belongs in its own commit with its own
smoke test.

### The mission-thread skeleton

Beyond the garrison block, all 17 threads share a prologue and an epilogue that differ only in
constants. The prologue — target-position search, the `_failSafe > 10` bail-out, marker
creation — is 33 lines repeated across 10 files; the reinforcement-monitor wiring is another 14
across 11. Both are pure boilerplate around values the thread already has.

The prologue is the better first target because it contains a bail-out path that every thread
must get right:

```sqf
if (_failsafe > 10 && _Posfound == false) exitWith {
    Mission_available = true;
    publicVariable "Mission_available";
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};
```

A thread that forgets this leaves `Mission_available` false forever and the side-mission spawner
stops. `fnc_mission_begin` (`server_fnc_init.sqf:651`) already exists and already owns the
*entry* half of that contract — cooldown check, `Mission_available = false`, logging. The
prologue is the missing `fnc_mission_site` companion, and the epilogue
(reward, timer, cleanup, clear `current_mission_target_pos`) is the missing `fnc_mission_end`.

A contract audit across all 17 threads found no thread missing its cleanup — `rescue_squad` and
`sabotage_laptop` carry theirs in a separate `_success` file, correctly `remoteExec`'d to the
server. The contract is currently honoured. Three helpers make it hard to stop honouring.

### Three civilian handlers, 51 shared lines

There are three: `fnc_civ_handler.sqf` (185 lines), `fnc_civ_handler_ravage.sqf` (407) and
`fnc_civ_handler_wbk.sqf` (554). They are no longer one function split in three. The plain path
was rewritten to a single thread that polls every town —
`fnc_civ_init_Tomata.sqf:287` starts it as `[] spawn fnc_civ_handler` with no arguments — while
the two mode handlers kept the original per-town `[_locIndex, _mode]` shape and are still picked
by name at runtime (`:243`). The plain handler now shares **no** block of five or more lines with
either mode handler.

What is left is between the mode handlers alone: 51 lines across seven blocks, the largest nine
(`fnc_civ_handler_ravage.sqf:90` against `fnc_civ_handler_wbk.sqf:79`). That is small enough that
extracting it buys little on its own, and the two are the mission's only consumers.

**The merge this section used to propose is off the table.** Mode code stays out of the plain
civilian path by decision, not by accident: the plain handler is what runs mod-free, and a mode
strategy threaded through it puts RAVAGE and WBK branches on the path every stock game takes. If
the mode handlers converge further, the shape is a helper the two of them call — not one entry
point that all three enter.

## Tier 3: adding one thing costs N edits

### Registering a side mission touches five places

To add mission type 17, a maintainer edits:

1. `client/missions/fnc_stratmap.sqf:112` — append to the `_missionCount` array
2. `client/missions/fnc_stratmap.sqf:47-80` — a `case` in the display-name switch
3. `client/missions/fnc_stratmap.sqf:194+` — a 15-line `case` in the config switch
4. `client/missions/fnc_stratmap.sqf` — two new globals, `mission17_pos` and `mission17_name`
5. `server/server_fnc_init.sqf` — a registry entry

Steps 1-4 are all in one file, which is the saving grace, but the file carries 34 numbered
globals (`mission0_pos` … `mission16_name`) that exist nowhere else in the mission. Each `case`
is the same 15 lines with three substitutions: a function name, a stringtable key, an icon path.

The globals are not carelessness. `array_of_missions` is handed to
`BIS_fnc_strategicMapOpen` (`:521`), whose per-mission code block runs with no arguments — so
the block has to reach its position and name through globals, because SQF blocks do not capture
locals. Any fix must keep that property.

The shape that works: one definition table, one shared slot array, and a block built per index.

```sqf
// server_var_init.sqf or a new shared data file
DUWS_missionDefs = [
    ["fnc_rescue_squad_mission", "STR_DUWS_T_c0", "STR_DUWS_T_kievbwmd", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa"],
    ["fnc_steal_supply_mission", "STR_DUWS_T_c1", "STR_DUWS_T_p7qawzl4", "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa"]
    // ...
];
```

`DUWS_missionSlots` holds `[pos, name]` per type, and the deferred block becomes
`compile format ["[%1] call fnc_launch_side_mission", _type]` — 17 one-token compiles at
menu-build time, replacing 34 globals and three switches. Adding a mission then means one table
row and one registry line.

### The support menu is a 24-case switch over one template

`client/dialog/fnc_request_support.sqf` is 481 lines and 24 cases. Every case is the same
template:

```sqf
case N: {
    if (insurgent_mode_enable) exitWith { hint localize "STR_DUWS_T_inssupport" };   // some cases
    _cost = C;
    if (support_count > 7) exitWith { /* radio cap */ };                             // some cases
    if (support_X_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga" };
    if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv" };
    support_count = support_count + 1;                                               // some cases
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format ["%1", commandpointsblu1]];
    lbSetColor [2103, index_support_X, [0, 1, 0, 1]];
    playSound "...";
    support_X_available = true;
};
```

The "not enough CP" literal `STR_DUWS_T_e95mc4lv` appears 39 times across the tree, 24 of them in
this file. There are 19 `support_*_available` globals. The variation between cases is five
values — cost, unlock flag, dialogue key, listbox index, sound — plus an optional
`insurgent_mode` guard, an optional radio-slot cap, and a per-support unlock action.

A table of the five values plus a per-support unlock block collapses the file to roughly its
declaration table and a 20-line driver. The unlock blocks genuinely differ (arsenal walks
`Array_of_FOBS`, HALO adds three `addAction`s conditioned on `Squad_Leaders`), so they stay as
code — but as one entry per support in the table, not one branch in a switch.

### A faction is 60-odd flat globals plus 50 numbered slots

`shared/factions/` is 27,758 lines — **45% of all DUWS source** — across 255 files, one per
faction per side. Each assigns the same ~60 `blufor_*` / `opfor_*` globals, which is why
`opfor_SOLDIER_X` has 133 assignment sites.

The bulk is not the role globals; it is the request menus. Every blufor file declares
`blufor_RQST_VEHICLE_01_X` through `_50_X` and an equivalent unit block, padded to full length
with `["empty",0,0]`. **2,389 such padding entries exist across the directory** — pure filler
that exists only because the consumer walks a fixed numbered range.

The consumer reconstructs each name as a string with a zero-pad special case:

```sqf
if (_var_count > 9) then {
    _var = "blufor_RQST_VEHICLE_" + str _var_count + "_X";
} else {
    _var = "blufor_RQST_VEHICLE_0" + str _var_count + "_X";
};
```

and the two readers use different thresholds for the same boundary (`> 9` in the menu builder at
`fnc_HQ_Request_Menu.sqf:65`, `> 10` on the offset index in `fnc_request_vehicle.sqf:14`). They
happen to agree because the indices are offset by one. That is a coincidence holding up a menu.

**Do not rewrite 255 faction files by hand for this.** The honest sequencing is: change the
consumer to read one array global (`blufor_RQST_VEHICLES = [[class, label, cost], ...]`) with the
numbered globals as a fallback, then convert faction files by script, then delete the fallback.
The auto-detection path (`shared/factions/MODERN/fn_factionAutoDetect.sqf`, 774 lines) generates
these tables at runtime and must be converted in the same change, because it writes the same
names the files do.

The payoff is not elegance: 2,389 padding lines and a 50-entry ceiling both disappear, and a
faction file becomes readable.

## Tier 4: couplings that need a decision first

These are real, but each needs a call from the maintainer before any code moves. Listed so the
decision can be made deliberately rather than discovered mid-refactor.

### `server_fnc_init.sqf` is two files wearing one name

1,576 lines: 270 registry entries (`fnc_x = compile preprocessFile "..."`) and **45 full function
bodies defined inline**, including `fnc_cp_adjust`, `fnc_ap_adjust`, `fnc_zone_control_set`,
`fnc_mission_begin`, and the whole composition-streaming set (`fnc_duws_keep`, `fnc_duws_stow`,
`fnc_duws_deploy`, `fnc_duws_release`).

The inline bodies are the mission's most load-bearing code — every CP mutation in the campaign
routes through `fnc_cp_adjust` — and they are the hardest to find, because the file reads as a
manifest. The registry self-check at `:1561-1576` is good engineering and should stay wherever
the registry ends up.

The counter-argument for leaving it alone is real: these functions have no natural file yet, the
registry is the only place guaranteed to run before anything calls them, and moving them means
270 path strings get re-verified. The recommendation is the cheap half — move the 45 bodies into
subsystem files (`server/misc/fnc_economy.sqf`, `server/misc/fnc_composition_stream.sqf`) and
register them like everything else, leaving the registry a pure manifest. That is mechanical, and
`check_paths.py` verifies it.

### Globals have no namespace

`src/duws/` calls `publicVariable` at 547 sites on 390 distinct names, over a global namespace
several times that size. There is no convention separating campaign state from scratch variables,
so nothing prevents a name collision between subsystems and nothing makes it visible when one
happens.

This is not fixable as a refactor, and attempting a sweeping rename would be the single
highest-risk change available in this codebase — `publicVariable` names are matched as strings by
`addPublicVariableEventHandler`, and a missed rename fails silently at runtime. What is worth
doing is bounded: **require a `DUWS_` prefix on new globals**, and prefix on touch. The mission
already has good instances of the discipline (`DUWS_enemyGear_scannedUnits`,
`DUWS_missionDefs` as proposed above) alongside bare ones like `support_count` and
`Mission_available`.

### Data compiled as code

Two places carry large data tables inside executable files:

| File | Data lines | Total | Note |
|---|---|---|---|
| `server/misc/fnc_createKillhouse.sqf` | 791 | 1,275 | Two composition arrays, `:15-841` |
| `shared/factions/` | ~27,758 | 27,758 | Covered above |

The killhouse composition is already marked with the `--DUWS-COMPOSITION` fence that
`scripts/duws_eden.ps1` round-trips through Eden
([`info/hq_layout_editing.md`](info/hq_layout_editing.md)), so the tooling to treat it as data
exists. The remaining question is whether it stays inline — `preprocessFile` on a separate data
file costs one more path reference and buys a 484-line file instead of a 1,275-line one.

Related: the composition fence carries **three row schemas (A, B, C)** for one concept, with
eight compositions on A, two on B and five on C. The Eden tool already normalises all three to
`[class, offX, offY, offZ, dir°]`, so the schemas exist only because three authors wrote three
formats. Converting all fifteen to schema A and deleting two adapters from `duws_eden.ps1` is
contained work with a script to verify it — the tool can re-import each composition before and
after and diff the normalised rows.

## What not to do

- **Do not restructure folders.** Every path is a string literal with no resolver, and the win
  here is negligible against the risk.
- **Do not mass-rename globals or `publicVariable` keys.** Silent runtime failure, no compiler,
  and `addPublicVariableEventHandler` matches on strings.
- **Do not touch `src/modules/`.** Vendored and frozen.
- **Do not put mode branches back on the plain civilian path.** `fnc_civ_handler.sqf` is what
  runs mod-free; RAVAGE and WBK behaviour reaches it through nothing but the handler chosen at
  init.
- **Do not treat `bash tests/run.sh` as sufficient.** It checks bracket balance, path resolution
  and retired names. It does not execute the mission
  ([`info/testing.md`](info/testing.md#why-static-analysis-plus-only-a-thin-unit-layer)). Every
  item below needs an in-game run.

## Order of work

Sequenced so that each step is independently verifiable and nothing later depends on a decision
not yet made. Lint is `bash tests/run.sh`; "smoke" means repack and play far enough to exercise
the named system.

- [ ] Registry corrections: delete the duplicate `fnc_missionLocator` at `server_fnc_init.sqf:705` and the unreferenced `fnc_missionPatrolsSmall` at `:726`. Verify: lint passes, and the boot-time registry self-check logs no `compiled EMPTY`.
- [ ] Replace the eight `call (compile _var)` reads with `missionNamespace getVariable`. Verify: HQ and FOB request menus populate identically, and buying a vehicle from each still charges CP.
- [ ] Replace the three `call compile format ["%1 = ...]` trigger assignments with `setVariable`. Verify: enter a zone (notification fires), deploy and remove a FOB (trigger cleanup runs).
- [ ] Decide whether `target_sniper` and `clearthearea_cqb` should drop garrison intel. Record the answer, then extract `fnc_garrisonBuildings` and convert the nine copied call sites. Verify: each of the nine missions spawns building garrisons, and corpse intel matches the decision.
- [ ] Fold the two reimplementations (`fnc_createopfortified.sqf`, `clearthearea_cqb`) onto the same helper, parameterised by building count. Verify: zone fortification garrisons and CQB garrisons spawn at their existing counts of 8 and 4.
- [ ] Add `fnc_mission_site` and `fnc_mission_end` alongside the existing `fnc_mission_begin`; convert the threads one at a time. Verify per thread: the `_failSafe` bail-out still releases `Mission_available`, markers are deleted, and the reward pays once.
- [ ] Collapse `fnc_request_support.sqf` to a declaration table plus a driver. Verify: every one of the 22 supports unlocks once, refuses a second purchase, respects the eight-slot radio cap, and colours its listbox row.
- [ ] Move the 45 inline bodies out of `server_fnc_init.sqf` into subsystem files, leaving a pure manifest. Verify: lint's path check passes, the registry self-check reports the same function count, and CP/AP mutation plus composition stow/deploy still work.
- [ ] Extract the 51 lines the RAVAGE and WBK handlers still share into a helper the two of them call, leaving the plain handler untouched. Verify: both modes spawn, clean up, and respect the spawn mutex; the plain path is unchanged.
- [ ] Side-mission definition table replacing the three switches and 34 numbered globals in `fnc_stratmap.sqf`. Verify: all 17 missions appear on the strategic map, each launches the right thread, and the cooldown hint still names the right mission.
- [ ] Faction request tables: consumer reads an array global with numbered-global fallback, script-convert the 255 files and `fn_factionAutoDetect.sqf`, then delete the fallback. Verify: a vanilla faction, a modded faction and an auto-detected faction all populate both request menus with the same entries as before.
- [ ] Normalise the fifteen compositions to schema A and drop the B/C adapters from `duws_eden.ps1`. Verify: import each composition through the tool before and after, and diff the normalised rows.
