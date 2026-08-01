# Dead code inventory

Scope: all 579 `.sqf` files under `src/duws/`. Vendored code under `src/modules/` is excluded, as
is `src/duws/client/misc/fnc_kndr_unit_markers.sqf` (see [Vendored code](#vendored-code)).

Two SQF properties shape what counts as a finding, and a scan that ignores either produces false
results:

- **Identifiers are case-insensitive.** `_Varname` and `_VarName` are one variable. A
  case-sensitive scan reports `fnc_MHQ_select.sqf:38` as unused when it is not.
- **`call` shares scope with the caller.** A callee reads locals its caller declared, so a variable
  unused in its own file can still be consumed through a `call`. Every candidate below was checked
  against the bodies of the functions its file calls; none is consumed that way.

Nothing is orphaned at file level. The ~250 faction files reached only by a path built at runtime
(`fnc_BLUFOR_faction_init.sqf:23`, `fnc_OPFOR_faction_init.sqf:17`) are live, as is
`killhouse_composition.sqf`, which `fnc_createKillhouse.sqf:10` pulls in with `#include`.

## Functions never called

| Function | Defined at |
|---|---|
| `fnc_disguise_addGear` | `client/client_init.sqf:492`, published at `:495` |
| `fnc_wbk_unitKilled_server` | `server/misc/fnc_wbk_server_init.sqf:82`, published at `server/server_fnc_init.sqf:485` |
| `fnc_IsUAVSpecialist` | `shared/factions/MODERN/fn_factionAutoDetect.sqf:359` |

`fnc_IsUAVSpecialist` belongs to a role-classifier family (`fnc_IsMedic`, `fnc_IsEngineer`,
`fnc_IsEOD`, `fnc_IsOfficer`, …) whose every other member is called. Removing it saves four lines
and breaks the set's symmetry, so it is the one entry here worth leaving deliberately.

## Globals written but never read

Several are also broadcast, so they cost bandwidth as well as reading time.

| Global | Sites |
|---|---|
| `HC_CAS_currentGroup` | `client/supports/fnc_request_hcCAS.sqf:28,73,97` |
| `HC_ATTchop_currentGroup` | `client/supports/fnc_request_hcATTchop.sqf:26,67,91` |
| `Mission_Failed` | `server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf:123,124,164` |
| `blu_officer_object` | `server/init_hq/fnc_BluHQinit.sqf:358` |
| `PAPABEAR` | `server/server_var_init.sqf:275` |
| `LogicGroup` | `server/server_init.sqf:20` |
| `opfor_INFSQUAD_X`, `opfor_INFWEPSQUAD_X` | `server/warcom/fnc_OPFOR_squad_init.sqf:7,8` |
| `blufor_CAN_DIFFUSE1_X`, `blufor_CAN_DIFFUSE2_X`, `IED_DEVICE_X` | `shared/factions/MODERN/CUP_B_USMC_W_blufor.sqf:23,24,25` |

`HC_CAS_currentGroup` and `HC_ATTchop_currentGroup` are the only dead members of their state
groups: the sibling `HC_*_currentVehicle` and `HC_*_active` flags are read by the Killed and
Deleted handlers beside them and must stay.

The three IED entries in `CUP_B_USMC_W_blufor.sqf` name a system that is not in this repo -- their
own trailing comments point at `EPD\Ied_Settings.sqf` -- and no other faction file declares them.

`Mission_Failed` is the whole payload of a `Killed` handler at `fnc_protect_civ.sqf:121-125`;
removing the global removes the handler with it. The monitor thread does not depend on it, testing
`!alive _civ` directly at `:180` and `:190`.

Two more are dead stores whose statements must survive because the right-hand side has an effect:
`PlayerKilledEH` at `client/client_init.sqf:160` (the `addEventHandler` stays) and
`index_escalation_false` at `client/dialog/fnc_enviro_menu.sqf:66` (the `lbAdd` stays).

## Discarded computation

Unlike the rest of this inventory, these cost runtime rather than reading time.

- `server/missions/mission_threads/holdpos/fnc_holdposition_mission.sqf:41-52` runs a
  `lineIntersectsSurfaces` raycast and a branch to derive `_centerSpawnZ`, which nothing reads --
  one discarded raycast per hold-position mission.
- `server/missions/mission_threads/domination/fnc_domination_mission.sqf:42-107` defines
  `_fn_waterproofBluforGroupCenter`, a 65-line water-avoiding BLUFOR infantry spawner that is never
  called. Its three siblings are: `_fn_waterproofBluforVehicleCenter` at `:473`,
  `_fn_waterproofOpforGroupEdge` at `:588`, `_fn_waterproofOpforVehicleEdge` at `:605`. The
  mission therefore fields a BLUFOR APC with no infantry alongside it, which reads more like an
  unfinished spawn than deliberate cruft.
- `server/missions/mission_threads/rescue_squad/fnc_rescue_squad_success.sqf:60-71` walks a
  three-level `alive` chain to pick a surviving soldier into `_solRadio` so that someone can
  deliver a radio line. The line is never sent.
- `client/dialog/fnc_HQ_random_place.sqf:13-16` and `server/missions/fnc_missionLocator.sqf:4-7`
  hold the same four-line block deriving `_half`, `_safehalf`, `_mapradius` and `_mapcenter`.
  Nothing downstream reads any of the four in either file.
- `server/misc/fnc_blackMarketPurchase.sqf:67,75,88,105,115,122` sets `_addedToInventory` across
  five branches and never reads it. Removing it leaves two empty `then {}` blocks, so the
  conditions want inverting rather than the lines simply deleting.

## Dead control flow

- `server/init_zones/prefabs/modern/fnc_modern_simple_zone.sqf:41,69,97` wrap three always-taken
  blocks in `if (true) then`. Each block's `_vehicle_NNN = objNull` initialiser above it exists
  only to cover the branch that cannot be taken.
- `server/init_hq/fnc_fortifyFOB.sqf:58-67` assigns `_turret3 = ""` twice (`:60` and `:65`) and
  initialises `_glPod1`, `_glPod2`, `_hmgPod1`, `_aaPod`, none of which is ever assigned or read
  again -- the `MODERN` case fills only `_turret1` through `_turret5`.

## Write-only locals

78 across 56 files beyond those named above. Roughly half are pure computations whose lines can go
outright; the rest are dead stores on side-effecting calls, where only the `_x =` goes and the
statement stays. Representative cases:

| Kind | Examples |
|---|---|
| Pure computation | `_skillSF` (`client/dialog/fnc_request_unit.sqf:5`), `_flagPos` (`server/init_zones/fnc_captured.sqf:7`), `_dice` and the `_amount_of_prefabs`/`_indexedAmount` chain feeding it (`server/init_zones/fnc_createzone.sqf:138-140`), `_origCenterZ` in all seven `prefabs/modern/*` files, `_cost` and `_index` (`client/supports/fnc_request_hcCAS.sqf:3-4`) |
| Unused `_this select N` | `server/warcom/fnc_WARCOM_init.sqf:10,14,15,16` -- safe to drop because the file's header comment at `:1-4` already documents the full nine-argument signature |
| Dead store, statement stays | `_smoke`/`_chemlight` `createVehicle` calls across the support scripts, `_handle = createDialog` in seven dialog files, `_bomb =` on eight consecutive `createVehicle` calls (`destroy_cache/fnc_destroy_cache_mission.sqf:214-227`) |

## Not dead: the support in-use flags

`CASInUse` (`client/includes/supports_init.hpp:27`, `client/supports/fnc_request_hcCAS.sqf:5,70,94`)
and `AttChopInUse` (`supports_init.hpp:25`, `fnc_request_hcATTchop.sqf:5,64,88`) are written and
never read, and have the shape of a guard against requesting a support twice.

That guard already exists elsewhere and works. `shared/includes/supports_radio_modern.hpp` declares
each entry with `removeAfterExpressionCall = 1` and an expression that calls
`fnc_support_comm_used`, so requesting CAS removes the menu item and drops it from the held record;
only the completion paths hand it back, via `fnc_support_comm_add` at
`fnc_request_hcCAS.sqf:69` and `:93`. The comm menu owns this state.

Adding a read of `CASInUse` would therefore introduce a second, weaker source of truth for
something already handled. These two are redundant duplicates rather than a missing guard.

## Vendored code

`client/misc/fnc_kndr_unit_markers.sqf` is a third-party marker pack (kondor, 2010) that lives in
the DUWS tree rather than under `src/modules/`. Four of its public functions are never called:
`kndr_setMarkerUpdateDelay:129`, `kndr_getMarkerUpdateDelay:137`, `kndr_disableShow:213`,
`kndr_setMarkerText:222`. It also carries an `if (true) exitWith {}` loop-break idiom at `:230`.

`kndr_assignMarker` and `kndr_removeMarker` are live, driven by the MHQ deploy, undeploy and
release paths.

This file is left alone. It has already diverged from upstream -- it calls `fnc_log` -- but
trimming a vendored API is a different decision from trimming DUWS code, and nothing here is
costing runtime.

## Adjacent observation

`server/missions/mission_threads/domination/fnc_domination_mission.sqf:17` assigns
`_markerText2 = localize "STR_DUWS_T_c13"` and never uses it. Ten sibling missions
(`destroy_cache:28`, `destroy_radar:25`, `destroy_tower:31`, `holdpos:34` among them) show their
briefing with `[_markerText2,{hint _this}] remoteExec [...]`. Domination instead hints the
hardcoded English literal `"Armor Hunting"` at `:36`, while `STR_DUWS_T_c13` is fully translated at
`src/stringtable.xml:4090`. The dead local is the remnant of the correct pattern; the live line is
a localisation regression, distinct from the deliberate lag in the non-English tags.

`clearthearea_cqb/fnc_clearthearea_cqb_mission.sqf:15` carries the same dead `_markerText2`, but
that mission does show a briefing from a different key (`STR_DUWS_T_c11` at `:21`), so there it is
a redundant duplicate and not a defect.
