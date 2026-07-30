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
| Single responsibility | A file does one job. `server_fnc_init.sqf` being both a path registry and the home of 50 function bodies is the violation shape. |
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

A normalised clone detector over `src/duws/` (block and line comments stripped, whitespace
collapsed, blank lines dropped, 8-line seed windows hashed and every line in a repeated window
counted). Two data directories are excluded, since near-identical tables are expected there and
would swamp the result: the 256-file `shared/factions/` tree, and
`server/misc/fnc_factions_check_modern.sqf`, whose BLUFOR and OPFOR roster arrays are identical
by design — its own header says so.

**3,860 of 24,676 non-data lines are duplicated — 15.6%.** `server/missions/mission_threads/`
carries 1,521 of those lines, 39% of all duplication in the tree, which is why that directory
leads the plan.

## Tier 1: the copy-paste layer

This is where the bulk of that 15.6% lives, and where duplication has already cost behaviour.

### The building-garrison block: 90-odd lines, nine copies, one drifted

Nine mission threads contain the same routine — find enterable buildings near a point, pick up
to six, spawn four OPFOR per building, and start a per-unit reposition loop:

| File | Span | Lines |
|---|---|---|
| `missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf` | `199-295` | 97 |
| `missions/mission_threads/destroy_radar/fnc_destroy_radar_mission.sqf` | `120-210` | 91 |
| `missions/mission_threads/destroy_tower/fnc_destroy_tower_mission.sqf` | `106-196` | 91 |
| `missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf` | `67-157` | 91 |
| `missions/mission_threads/steal_builder/fnc_steal_builder_mission.sqf` | `87-177` | 91 |
| `missions/mission_threads/steal_supply/fnc_steal_supply_mission.sqf` | `135-225` | 91 |
| `missions/mission_threads/target_armor/fnc_target_armor_mission.sqf` | `57-147` | 91 |
| `missions/mission_threads/target_hvt/fnc_target_hvt_mission.sqf` | `76-166` | 91 |
| `missions/mission_threads/target_sniper/fnc_target_sniper_mission.sqf` | `40-129` | 90 |

Eight are identical modulo the position variable's name. `target_sniper` is not, and the
difference is player-visible: it declares `_buildingGroup` inside the `if` block rather than
before it (`:82`), so the group is unreachable after the block — and the two passes the other
eight run there, `fnc_add_intel_to_group` and `fnc_addRandomLoot`, are simply absent. **A sniper
hunt's building garrison drops no corpse intel**, where every other mission's does. Nothing in
the source says that is deliberate. That is the substitutability failure in concrete form: one
copy of a shared routine quietly lost a step, and there is no single definition to compare it
against.

**Two more files stay as they are.** `server/init_zones/fnc_createopfortified.sqf` and
`clearthearea_cqb` solve the same problem a third and fourth way, and folding them onto
`fnc_garrisonBuildings` was considered and rejected. Zone fortification differs on four axes at
once — minimum building positions (5 against 2), unit stance (`UP` against `AUTO`), two reposition
sleep ranges, and walking every usable building rather than a random subset — so the fold costs
four parameters that exist for one caller and make the helper worse for the nine it was extracted
for. CQB needs the per-building unit lists its house-cleared announcements are built on, which is
an interface for one consumer. They resemble the block without being copies of it, and there is no
drift to close.

The extraction has precedent in the same tree: `server/misc/fnc_usableBuildings.sqf` is already a
19-line shared helper with fifteen callers across the mission. The block wants to become
`fnc_garrisonBuildings` taking `[_pos, _radius, _bucketKey]` and returning the group, with the
intel and loot passes inside it so a caller cannot forget them. Nine of those fifteen callers are
the copied block, two are the reimplementations above, and the remaining four — `rescue_squad`,
`intel_gathering`, `fnc_civ_handler_wbk` and `fnc_civ_selectTowns` — use `fnc_usableBuildings`
for siting rather than garrisoning and are not part of this conversion.

**The drift is decided: the outliers are wrong.** `target_sniper` and `clearthearea_cqb` should
drop corpse intel like the other seven, so `fnc_garrisonBuildings` runs the intel and loot passes
unconditionally for every side mission and no caller can opt out. That makes two missions start
paying intel they do not pay today — a behaviour change, so it lands in its own commit with its
own smoke test rather than riding along with the extraction.

**"Consistent" means all eleven sites, including the zone garrison.** `fnc_add_intel_to_group` is
called from side missions only today, and `fnc_createopfortified` has never added intel to a
zone's garrison. That gap closes rather than being preserved behind a parameter: the helper runs
the intel and loot passes for every caller, and `fnc_garrisonBuildings` takes no intel flag at all.

A zone rebuilds its garrison whenever players return to it, so this is a supply the player can
work repeatedly. That is intended — the cost of each cycle is defeating the garrison again, and
the intel pool is finite, so grinding buys a faster route through the hidden-map phase and nothing
after it. The reasoning is in [`search_system_plan.md`](search_system_plan.md#streamed-entities-are-flagged-too-and-the-farm-is-the-price).

The per-corpse hold action this attaches is a standing cost rather than a leak: its JIP entry is
keyed to the body and dropped when `fnc_repetitive_cleanup` deletes it
([`info/intel_system.md`](info/intel_system.md#the-body-search-looks-outward-so-it-scales-with-players-not-corpses)).
Extending it to a respawning population raises the steady-state count, which is one more reason
the Search rework should move this onto the outward-looking shape.

The reward keeps the Search the Body shape it already has — the `BIS_fnc_holdActionAdd` that
`fnc_add_intel_on_death` wires onto each corpse — at a 60% find rate, searchable once by anyone.
Two of those three hold today; the third does not, and a fourth thing has to change for the rate
to be true:

- **60% is already the aggregate.** `fnc_corpse_search_action.sqf` rolls `random 1`: under 0.4
  reveals the target, 0.4–0.6 pays 1 CP and 1 AP, above 0.6 pays nothing. No odds change.
- **Once-by-anyone is not what happens.** The action is `remoteExec`'d to every client, its
  remove-on-completion is per-machine, and the `corpse_search_action_added` guard at `:12-13` is
  set without the broadcast flag — so it is per-machine too. In co-op each player searches the
  same body for their own payout. Closing it needs a server-side claim on the corpse, checked in
  the action's condition; the mission already has `fnc_support_try_claim` as precedent.
- **The 40% reveal branch is inert for both new missions.** It is guarded by
  `count _targetPos == 3`, and `current_mission_target_pos` is set by eight threads —
  `target_sniper` and `clearthearea_cqb` are not among them. Left alone, their garrisons would
  pay at 20%, not 60%, and 40% of searches would return no dialogue, no notification and no
  reward at all. Both threads must set the global for the stated rate to be the real one.
- **The per-player search timer stays out of it.** `playerIntelSearchTick` and `econ_tick` gate
  `fnc_intel_search`, the area search, and never touched the corpse path. Nothing to do.

### Clone hotspots outside the mission threads

Three more files carry over 100 duplicated lines each and are not covered by anything above.
None is large enough to lead the plan; all three are cheap once the mission-thread work has
established the pattern.

| File | Lines | Duplicated | Shape |
|---|---|---|---|
| `server/init_hq/fnc_BluHQinit.sqf` | 762 | 110 | HQ unit placement, reimplemented by the file below |
| `server/misc/fnc_redeployHQUnits.sqf` | 261 | 110 | the same placement again, for the redeploy path |
| `server/dialog/fnc_weather.sqf` | 226 | 116 | one `switch (weather_type)` case per climate, each repeating the same fog and overcast loop around different constants |
| `server/init_zones/fnc_zone_spawn_sizes.sqf` | 207 | 100 | six `fnc_<N>_zone` functions that are a spawn table written as code |

The HQ pair is the same reimplementation shape as `fnc_createopfortified` and folds into a shared
placement helper. `fnc_weather.sqf` and `fnc_zone_spawn_sizes.sqf` are both the open/closed
violation in miniature — adding a climate or a zone size edits control flow — and both collapse
to a table with a short driver, exactly as the support menu does below.

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

## Tier 2: adding one thing costs N edits

### Registering a side mission touches seven places

To add mission type 17, a maintainer edits:

1. `client/missions/fnc_stratmap.sqf:112` — append to the `_missionCount` array
2. `client/missions/fnc_stratmap.sqf:47-80` — a `case` in the cooldown-ready notification monitor
3. `client/missions/fnc_stratmap.sqf:202+` — a 15-line `case` in the config switch
4. `client/missions/fnc_stratmap.sqf` — two new globals, `mission17_pos` and `mission17_name`
5. `server/server_fnc_init.sqf` — a registry entry
6. `server/misc/fnc_debug_force_mission.sqf:12-18` — the `_threads` name array
7. `client/dialog/fnc_debug_mission_menu.sqf:16-21` — the `_types` label array

Four of those are four separate type-indexed tables — the config switch, the notification switch,
`_threads` and `_types` — that must stay in lockstep by hand and agree only because someone
checked. Steps 1-4 being in one file is the saving grace, but that file carries 34 numbered
globals (`mission0_pos` … `mission16_name`) that exist nowhere else in the mission. Each `case`
is the same 15 lines with three substitutions: a function name, a stringtable key, an icon path.

Two smaller things live in the same file and are worth taking with it. The three
`switch (VERSION_X)` blocks inside the notification switch (`:52`, `:62`, `:69`) return the same
string from their case and their default, so they branch on nothing. And the comment at `:111`
still reads `CURRENTLY 15 MISSIONS AVAILABLE` above a 17-entry array.

The globals are not carelessness. `array_of_missions` is handed to
`BIS_fnc_strategicMapOpen`, whose per-mission code block runs with no arguments — so the block
has to reach its position and name through globals, because SQF blocks do not capture locals.
Any fix must keep that property, and must keep the shuffle-and-draw at `:113-117`, which offers
seven of the seventeen types per opening rather than all of them.

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
`compile format ["[%1] call fnc_launch_side_mission", _type]` — seven one-token compiles per
opening, replacing 34 globals and four hand-synchronised tables. Adding a mission then means one
table row and one registry line.

### The support menu is a 22-case switch over one template

`client/dialog/fnc_request_support.sqf` is 485 lines and 22 cases. Every case is the same
template:

```sqf
case N: {
    if (insurgent_mode_enable) exitWith { hint localize "STR_DUWS_T_inssupport" };   // 13 cases
    _cost = C;
    if (support_count > 7) exitWith { /* radio cap */ };                             // 17 cases
    if (support_X_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga" };
    if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv" };
    support_count = support_count + 1;                                               // 17 cases
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format ["%1", commandpointsblu1]];
    lbSetColor [2103, index_support_X, [0, 1, 0, 1]];
    playSound "...";
    support_X_available = true;
};
```

The "not enough CP" literal `STR_DUWS_T_e95mc4lv` appears 39 times across the tree, 22 of them in
this file. There are 23 `support_*_available` globals. The variation between cases is five
values — cost, unlock flag, dialogue key, listbox index, sound — plus an optional
`insurgent_mode` guard, an optional radio-slot cap, and a per-support unlock action.

A table of the five values plus a per-support unlock block collapses the file to roughly its
declaration table and a 20-line driver. The unlock blocks genuinely differ (arsenal walks
`Array_of_FOBS`, HALO adds three `addAction`s conditioned on `Squad_Leaders`), so they stay as
code — but as one entry per support in the table, not one branch in a switch.

**Sequence this before the two-currency split, not after.**
[`ap_economy_plan.md`](ap_economy_plan.md) and [`cp_economy_plan.md`](cp_economy_plan.md) put
advanced supports behind a CP *and* AP price. Against the switch that is a second price and a
second spend call edited into every advanced case by hand; against the table it is one more
column and one more line in the driver.

### A faction is 60-odd flat globals plus 50 numbered slots

`shared/factions/` is 27,758 lines — **44% of all DUWS source** — across 256 files, one per
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
`fnc_HQ_Request_Menu.sqf:64`, `> 10` on the offset index in `fnc_request_vehicle.sqf:13`). They
happen to agree because the indices are offset by one. That is a coincidence holding up a menu.

**Do not rewrite 255 faction files by hand for this.** The honest sequencing is: change the
consumer to read one array global (`blufor_RQST_VEHICLES = [[class, label, cost], ...]`) with the
numbered globals as a fallback, then convert faction files by script, then delete the fallback.
The auto-detection path (`shared/factions/MODERN/fn_factionAutoDetect.sqf`, 774 lines) generates
these tables at runtime and must be converted in the same change, because it writes the same
names the files do.

The payoff is not elegance: 2,389 padding lines and a 50-entry ceiling both disappear, and a
faction file becomes readable.

## Tier 3: couplings that need a decision first

These are real, but each needs a call from the maintainer before any code moves. Listed so the
decision can be made deliberately rather than discovered mid-refactor.

### `server_fnc_init.sqf` is two files wearing one name

1,675 lines: 285 registry entries (`fnc_x = compile preprocessFile "..."`) and **50 full function
bodies defined inline**, including `fnc_cp_adjust`, `fnc_ap_adjust`, `fnc_zone_control_set`,
`fnc_mission_begin`, and the whole composition-streaming set (`fnc_duws_keep`, `fnc_duws_stow`,
`fnc_duws_deploy`, `fnc_duws_release`).

The inline bodies are the mission's most load-bearing code — every CP mutation in the campaign
routes through `fnc_cp_adjust` — and they are the hardest to find, because the file reads as a
manifest. The registry self-check at `:1660-1675` is good engineering and should stay wherever
the registry ends up.

The counter-argument for leaving it alone is real: these functions have no natural file yet, the
registry is the only place guaranteed to run before anything calls them, and moving them means
285 path strings get re-verified. The recommendation is the cheap half — move the 50 bodies into
subsystem files (`server/misc/fnc_economy.sqf`, `server/misc/fnc_composition_stream.sqf`) and
register them like everything else, leaving the registry a pure manifest. That is mechanical, and
`check_paths.py` verifies it.

The file is also the one that grows: it has taken five new inline bodies and fifteen new registry
entries since this audit was first written, and each new helper goes in as an inline body because
that is what the file's neighbours are. Every delay makes the same move larger.

### Globals have no namespace

`src/duws/` calls `publicVariable` at 538 sites on 394 distinct names, over a global namespace
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
| `server/misc/fnc_createKillhouse.sqf` | 821 | 1,334 | Two composition arrays, `:18-727` and `:730-842` |
| `shared/factions/` | 27,758 | 27,758 | Covered above |

The killhouse compositions are already marked with the `--DUWS-COMPOSITION` fence that
`scripts/duws_eden.ps1` round-trips through Eden
([`info/hq_layout_editing.md`](info/hq_layout_editing.md)), so the tooling to treat them as data
exists. The remaining question is whether they stay inline — `preprocessFile` on a separate data
file costs one more path reference and buys a 513-line file instead of a 1,334-line one.

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
- **Do not extract `fnc_factions_check_modern.sqf`'s roster arrays.** The clone detector flags
  194 duplicated lines there; they are the BLUFOR and OPFOR tables, which the file's own header
  requires to stay identical in shape.
- **Do not treat `bash tests/run.sh` as sufficient.** It checks bracket balance, path resolution
  and retired names. It does not execute the mission
  ([`info/testing.md`](info/testing.md#why-static-analysis-plus-only-a-thin-unit-layer)). Every
  item below needs an in-game run.

## Order of work

Sequenced so that each step is independently verifiable and nothing later depends on a decision
not yet made. Lint is `bash tests/run.sh`; "smoke" means repack and play far enough to exercise
the named system.

- [ ] Extract `fnc_garrisonBuildings` and convert the nine copied call sites, intel and loot passes inside it. Verify: each of the nine missions spawns building garrisons, and all nine now drop corpse intel — including `target_sniper`, which does not today.
- [ ] Collapse `fnc_request_support.sqf` to a declaration table plus a driver, **before** the two-currency work adds an AP price to every advanced case. Verify: every one of the 22 supports unlocks once, refuses a second purchase, respects the eight-slot radio cap, and colours its listbox row.
- [ ] Move the 49 inline bodies out of `server_fnc_init.sqf` into subsystem files, leaving a pure manifest. Verify: lint's path check passes, the registry self-check reports the same function count, and CP/AP mutation plus composition stow/deploy still work.
- [ ] Fold `fnc_redeployHQUnits.sqf` onto `fnc_BluHQinit.sqf`'s placement routine, and collapse `fnc_weather.sqf` and `fnc_zone_spawn_sizes.sqf` to table-plus-driver. Verify: HQ units place identically on init and on redeploy; each weather type still transitions; each zone size spawns its existing group count.
- [ ] Extract the 51 lines the RAVAGE and WBK handlers still share into a helper the two of them call, leaving the plain handler untouched. Verify: both modes spawn, clean up, and respect the spawn mutex; the plain path is unchanged.
- [ ] Side-mission definition table replacing the four type-indexed tables and 34 numbered globals in `fnc_stratmap.sqf`, feeding the debug menu from the same table. Verify: seven missions are drawn per map opening, each launches the right thread, the cooldown-ready notification names the right mission, and every debug-menu row forces the type its label claims.
- [ ] Faction request tables: consumer reads an array global with numbered-global fallback, script-convert the 255 files and `fn_factionAutoDetect.sqf`, then delete the fallback. Verify: a vanilla faction, a modded faction and an auto-detected faction all populate both request menus with the same entries as before.
- [ ] Normalise the fifteen compositions to schema A and drop the B/C adapters from `duws_eden.ps1`. Verify: import each composition through the tool before and after, and diff the normalised rows.
