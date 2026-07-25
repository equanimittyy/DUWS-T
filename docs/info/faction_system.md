# DUWS_T faction system

How DUWS_T decides which units and vehicles each side fields. See
[`architecture.md`](architecture.md) for the wider mission structure. All faction code
lives under `src/duws/shared/factions/` (data) and the `server/` / `client/` trees (logic); paths below
are relative to `src/`.

## The core abstraction: a faction variable schema

Everything hangs off a fixed set of global variables that map an **abstract DUWS role**
to a **concrete classname** from whatever mod is in use. A "faction" is any code that
assigns this schema; every consumer (patrols, guards, supports, request menus) reads the
globals, never a mod classname directly. The BLUFOR set (OPFOR mirrors it with `opfor_`):

| Group | Variables | Consumed by |
|---|---|---|
| Infantry roles | `blufor_SOLDIER_X`, `_SOLDIER_LAT_X`, `_SOLDIER_GL_X`, `_SOLDIER_TL_X`, `_SOLDIER_SL_X`, `_SOLDIER_AR_X`, `_MARKSMAN_X`, `_OFFICER_X`, `_HELI_PILOT_X` | HQ/FOB guards, patrols, paradrop, rescue-pilot mission |
| Vehicles | `_CAR_PATROL1_X`, `_APC_PATROL1/2_X`, `_TANK_PATROL1_X`, `_HELI_TRANS_ARM/UNARM_X`, `_HELI_ATTACK_X`, `_PLANE_CAS_X`, `_BOAT_ARMED_X` | Random patrols, support requests, taxi |
| Static weapons | `_TURRET_AA/AT/HMG/GMG` | HQ/FOB fortification |
| Operators | `_SPECOPS_X` + 10 role variants | Operative recruit menu |
| Request slots | `_RQST_UNIT_01..14_X` (14 fixed, `["empty",0,0]`-padded), `_RQST_VEHICLE_01..50_X` | HQ/FOB request menus |

Each value is a classname string, or an array of candidates (periodically re-rolled — see
[§autodetect](#the-procedural-generator-autodetect)). Every variable is `publicVariable`d
so dedicated servers and JIP clients see the same faction.

## Three ways a faction is defined

The schema can be populated three ways, all selected at campaign start:

| Path | Code | How it fills the schema |
|---|---|---|
| **Static template** | `factions/MODERN/<file>_{blufor,opfor}.sqf` (254 files) | Hand-authored direct assignments, one file per supported mod faction |
| **Procedural (autodetect)** | `shared/factions/MODERN/fn_factionAutoDetect.sqf` + `AUTODETECT_*` | Classifies any installed faction's `CfgVehicles` at runtime |
| **Custom (user text)** | `client/dialog/fnc_custom_faction_capture.sqf`, `server/dialog/fnc_custom_faction_init.sqf` | Parses and compiles a faction definition the player pastes in |

## Selection and availability

Which factions the player can pick is discovered at start, not hard-wired.

`server/misc/fnc_factions_check_modern.sqf` (`fnc_factions_check`) holds two master
lists — `_faction_files_BLUFOR` and `_faction_files_OPFOR` (~130 entries each). Each entry is:

```text
[ probe rifleman classname, faction class, menu label, faction file ]
```

For every entry it tests `isClass (configFile >> "CfgVehicles" >> <probe>)`. The probe is a
signature unit that only exists if the mod is loaded, so **mod presence is detected by
class probing** — an uninstalled mod's factions simply never appear. Surviving entries go
into the global arrays `Factions_Available_BLUFOR_X` / `Factions_Available_OPFOR_X` (NATO
Arid and CSAT Arid are always-present defaults). The same file probes signature civilian
classes to set `civ_mod`. The `AUTODETECT`, `AUTODETECT_RANDOM`, and `CUSTOM` pseudo-factions
are appended to the lists as always-available options.

`client/dialog/fnc_HQ_faction_dialog.sqf` renders two dropdowns from those arrays (blue
BLUFOR, red OPFOR) and, on selection, sets `BLUFOR_Faction_X` / `OPFOR_Faction_X` to the
chosen faction-file token, then hands off to HQ placement.

`server/init_hq/fnc_BLUFOR_faction_init.sqf` and
`server/warcom/fnc_OPFOR_faction_init.sqf` resolve the choice to a file, build the path
`duws\factions\MODERN\<file>_<side>.sqf`, then `compile preprocessFileLineNumbers` and call
it — populating the schema. (This dynamic path build is why the faction folder can't be
renamed without care.) `AUTODETECT*`/`CUSTOM` route to the generator or the paste parser
instead of a static file.

## The static template library

`factions/MODERN/` holds 254 hand-authored files (122 `*_blufor.sqf`, 132 `*_opfor.sqf`),
one per supported mod faction — RHS, CUP, 3CB, CFP, VME PLA, GM, TIOW, and many more. Each
is a flat script of direct assignments, e.g. from `3CB_US80_WDL_blufor.sqf`:

```sqf
blufor_SOLDIER_X   = "UK3CB_CW_US_B_LATE_RIF_1";   // patrol, fortify, paradrop
blufor_TURRET_HMG  = "UK3CB_CW_US_B_LATE_M2_TriPod";
```

Trailing comments name the consuming function for each variable — the de-facto schema spec.

## The procedural generator (autodetect)

`fn_factionAutoDetect.sqf` synthesizes the same schema for **any** faction with no
hand-authored file:

- **`fnc_parseFaction`** enumerates the faction's `CfgVehicles` and buckets it. Infantry is
  classified by role via `fnc_unitParseRoles`, which inspects each unit's loadout, weapon
  UI-icon path (`icon_mg_ca.paa`, `icon_at_ca.paa`, …), config flags (`attendant`,
  `engineer`, `uavHacker`), and displayName keywords into grunt / medic / SL / TL / AR / MG /
  GL / AA / LAT / HAT / officer / marksman / sniper / eng / EOD / pilot / crew / diver / UAV,
  plus suppressed-weapon "spec-ops" variants. Vehicles are bucketed by editor subcategory and
  `isKindOf` filters (`fnc_filterBySeats`, `fnc_filterByWeapons`, `fnc_filterByPylons`,
  `fnc_filterByUtility`) into turrets, APCs, tanks, artillery, cars, helis, planes, boats, drones.
- **`fnc_factionGen`** assigns the `blufor_*`/`opfor_*` globals from the parsed buckets, using
  `fnc_selectNonEmpty` fallback chains that end in vanilla assets, and builds the request-menu
  vehicle list priced by `fnc_evalVehicleCost` (estimates a CP cost from vehicle type, weapons,
  armor, sensors, and threat rating).
- **`fnc_factionSelector`** is a listbox of all present factions (`fnc_getAllFactionsClean` over
  `BIS_fnc_getFactions`); on dedicated it is `remoteExec`d to the admin.
- The `AUTODETECT_{blufor,opfor}.sqf` wrappers add an `EntityCreated` handler
  (`fnc_vehiclePostInit`) that retextures and re-crews vehicles spawned for a mismatched
  faction, then periodically (every 300 s) re-roll array-valued role variables and re-run
  squad init. `AUTODETECT_RANDOM_opfor.sqf` is the same pipeline but auto-picks a random
  faction instead of prompting.

## Custom factions

The `CUSTOM` option lets a player define a faction by pasting text. `fnc_custom_faction_capture.sqf`
reads two dialog text boxes (controls 2100/2101, defined in `shared/includes/custom_faction.hpp`) into
`BLUfactionDataTemp` / `OPFfactionDataTemp`. `fnc_custom_faction_init.sqf` then splits the pasted
text on newlines, keeps lines containing `blufor_` / `opfor_`, strips path-like lines, and
`call compile`s each `variable = "classname";` pair — so the paste is executed as SQF. It
validates that the resulting `*_SOLDIER_X` rifleman is a real class and loops an error message
if not. This is a runtime eval of user input; it is server-side and gated behind the custom-faction
dialog.

## Squads

`server/init_hq/fnc_BLUFOR_squad_init.sqf` and `server/warcom/fnc_OPFOR_squad_init.sqf`
compose higher-order groups from the role variables — recon team, infantry squad, motorized /
mechanized / armor sections — each tagged with a CP price (e.g. `blufor_INF_SQUAD_X =
[_squad, "Infantry Squad (12CP)", 12]`). Autodetect re-runs squad init every five minutes so
squads track the re-rolled unit types.

## Civilians

Civilians are templated separately. `shared/factions/CIV_FACTIONS.sqf` sets `civ_array` from the
`CIV_PRESENCE` parameter, choosing a classname list per source: vanilla (regional variants),
CUP, CFP, PrOpfor/LOP, Unsung, IFA3, and a Ravage-zombie set (which falls back to vanilla civs
if Ravage is absent). `civ_array` feeds the civilian/informant system in `server/misc/`.

## Adding a faction

1. Create `factions/MODERN/<FILE>_blufor.sqf` and `<FILE>_opfor.sqf` assigning the full schema
   (copy an existing file of a similar mod as the starting point).
2. Add a registry line to `_faction_files_BLUFOR` / `_faction_files_OPFOR` in
   `fnc_factions_check_modern.sqf`: `[<probe rifleman>, <faction class>, "<menu label>", "<FILE>"]`.
   The probe must be a class that exists only when the mod is loaded.
3. Repack and test: the new faction appears in the start dropdown only if its probe class resolves.

## Constraints worth knowing

- `VERSION_X` (value `"MODERN"`) is both the era switch used across the dialogs/squad logic and
  the `factions/` subfolder segment in the load path; its value is game state and the folder is
  named to match it (see [`architecture.md`](architecture.md)).
- Faction variables are plain globals populated server-side and `publicVariable`d; a consumer
  that runs before faction init sees nil.
- The static library and the registry in `fnc_factions_check_modern.sqf` must stay in lockstep —
  a template file with no registry entry is unreachable, and a registry entry with no file fails
  the dynamic load at selection time.
