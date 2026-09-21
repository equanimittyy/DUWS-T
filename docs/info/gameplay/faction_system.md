# DUWS_T faction system

How DUWS_T decides which units and vehicles each side fields. All faction code lives under
`src/duws/shared/factions/` (data) and the `server/` / `client/` trees (logic); paths below are relative
to `src/`. For the wider mission structure see [`architecture.md`](../architecture.md).

## The core abstraction: a faction variable schema

Everything hangs off a fixed set of global variables that map an **abstract DUWS role** to a **concrete
classname** from whatever mod is in use. A "faction" is any code that assigns this schema; every consumer
(patrols, guards, supports, request menus) reads the globals, never a mod classname directly.
`shared/faction_lib/fnc_faction_schema.sqf` is the one place the set is written down.

Both sides spell a role the same way and hold it in the same position, so the names below take either a
`blufor_` or an `opfor_` prefix. That is what lets a team roster name a role bare and have the side supply
the man ([§squads](#squads-and-civilians)), and what lets the confirmation screen put a role on one line
across two columns.

| Group | Variables | Consumed by |
|---|---|---|
| Infantry roles | `SOLDIER_X`, `AA_SOLDIER_X`, `AR_SOLDIER_X`, `AT_SOLDIER_X`, `GL_SOLDIER_X`, `LAT_SOLDIER_X`, `SL_SOLDIER_X`, `TL_SOLDIER_X`, `MARK_SOLDIER_X`, `SNIPER_SOLDIER_X`, `OFFICER_X` | Team rosters, HQ/FOB guards, patrols, paradrop |
| Vehicles | `ARMED_CAR1_X`, `APC1_X`, `APC2_X`, `MBT_TANK1_X`, `TRANS_HELI_X`, `ATTACK_HELI_X`, `MISC_AIR_X` | Zone compositions, random patrols, support requests |
| Static weapons | `TURRET_AA/AT/HMG/GMG/MORTAR` | HQ/FOB fortification, every zone prefab's guns, three side missions |
| Operators | `SPECOPS_X` + 10 role variants | Operative recruit menu |
| Special, BLUFOR only | `HELI_PILOT_X`, `BOAT_ARMED_X`, `BOAT_CREW_X`, `HELI_TRANS_ARM_X` | Rescue-pilot mission, boat and helo taxi |
| Special, OPFOR only | `ENG_SOLDIER_X`, `CREW_X`, `OPERATOR_X`, `AA_APC_X`, `TRANS_/COVERED_/AMMO_/REPAIR_TRUCK_X` | Side-mission targets and guards, R3F logistics |
| Request slots | `_RQST_UNIT_01..14_X` (14 fixed, `["empty",0,0]`-padded), `_RQST_VEHICLE_01..50_X` | HQ/FOB request menus |

Each value is a classname string, or an array of candidates (periodically re-rolled — see
[§autodetect](#the-procedural-generator-autodetect)). Every variable is `publicVariable`d so dedicated
servers and JIP clients see the same faction.

**A role a side's faction files never named is borrowed, not left empty.**
`shared/faction_lib/fnc_faction_backfill.sqf` holds a short ladder — `AA_SOLDIER_X` from `SPECOPS_AA_X`,
then `LAT_SOLDIER_X`, then the rifleman — and `server_init.sqf` runs it once both sides have resolved and
before the confirmation screen paints, so the player edits the borrowed class rather than a blank row. No
BLUFOR faction file defines an anti-air, anti-tank or sniper role; a shared roster naming one would
otherwise raise a man short on every one of them. Every rung names a role the faction file itself defines,
never another row's target, which is what makes the pass order-independent.

Faction init clears its side's schema keys before running the faction file. A faction file only assigns
what it defines, so stepping back through the setup screens and picking a second faction would otherwise
leave the first one's class standing in every key the second omits.

## Three ways a faction is defined

The schema can be populated three ways, all selected at campaign start:

| Path | Code | How it fills the schema |
|---|---|---|
| **Static template** | `factions/MODERN/<file>_{blufor,opfor}.sqf` (254 files) | Hand-authored direct assignments, one file per supported mod faction |
| **Procedural (autodetect)** | `shared/factions/MODERN/fn_factionAutoDetect.sqf` + `AUTODETECT_*` | Classifies any installed faction's `CfgVehicles` at runtime |
| **Custom (user text)** | `client/dialog/fnc_custom_faction_capture.sqf`, `server/dialog/fnc_custom_faction_init.sqf` | Parses and compiles a faction definition the player pastes in |

## Selection and availability

Which factions the player can pick is discovered at start, not hard-wired.
`shared/faction_lib/fnc_factions_check_modern.sqf` (`fnc_factions_check`) holds two master lists —
`_faction_files_BLUFOR` and `_faction_files_OPFOR` (~130 entries each). Each entry is:

```text
[ probe rifleman classname, faction class, menu label, faction file ]
```

For every entry it tests `isClass (configFile >> "CfgVehicles" >> <probe>)`. The probe is a signature unit
that only exists if the mod is loaded, so **mod presence is detected by class probing** — an uninstalled
mod's factions simply never appear. Surviving entries go into the global arrays
`Factions_Available_BLUFOR_X` / `Factions_Available_OPFOR_X` (NATO Arid and CSAT Arid are always-present
defaults). The same file probes signature civilian classes to set `civ_mod`. The `AUTODETECT`,
`AUTODETECT_RANDOM` and `CUSTOM` pseudo-factions are appended as always-available options.

`client/dialog/fnc_HQ_faction_dialog.sqf` renders two dropdowns from those arrays (blue BLUFOR, red OPFOR)
and, on selection, sets `BLUFOR_FactionFile_X` / `OPFOR_FactionFile_X` to the chosen faction-file token,
then hands off to HQ placement.

### The server answers the setup screens

The setup screens run on the game master's client, but the server builds the factions from its own mods.
Arma does not make a client's mods match the server's, so a list or a check made against the client's
config can offer a class the server cannot spawn, or reject one it can. Every answer that decides what a
faction may hold therefore comes from the server:

| Setup data | Server source |
|---|---|
| Preset dropdowns | `Factions_Available_BLUFOR_X` / `Factions_Available_OPFOR_X` |
| AutoDetect picker and key-editor faction lists | `DUWS_detectedFactions` / `DUWS_detectedZombieFactions`, built by `fnc_factions_check` |
| Key-editor class rows | `fnc_faction_query`, op `classes` |
| The base of a list whose main the player changed | `fnc_faction_query`, op `base` |
| The custom-paste check | `fnc_faction_query`, op `validate` |

The lists are fixed for the session, so the server broadcasts them once at init. The other rows depend
on what the player clicks, so the client asks with `fnc_faction_ask`
(`shared/faction_lib/fnc_faction_query.sqf`), which blocks until the server replies. Every caller must
therefore be scheduled. The server runs the query with `remoteExecCall`, because a class list for ALL
walks the whole of `CfgVehicles` and would crawl at the scheduler's frame budget.

Previews still read the client's config: an editor picture needs the mod's files on that machine to show
at all. No faction file runs on a client, and clients take the resolved faction from the server's
broadcasts ([§The confirmation screen](#the-confirmation-screen)).

**Two globals, two meanings.** `*_FactionFile_X` is the player's answer — a faction-file token, or
`CUSTOM`/`AUTODETECT`. `*_Faction_X` is the faction *class*, written only by faction init; its functional
reader was the BLUFOR vehicle patrols, retired with the WARCOM cleanup, so today it survives as the
resolved-class record (read only in placement logging, `client/dialog/fnc_HQ_manual_place.sqf:2-3`). Init
used to overwrite the answer with the class, which was harmless only while it ran once; resolution now runs
once per pass through the setup screens, and a second pass reading the overwritten value matched no registry
row and silently kept the previous faction's file.

`server/init_hq/fnc_BLUFOR_faction_init.sqf` and `server/warcom/fnc_OPFOR_faction_init.sqf` resolve the
choice to a file, build the path `duws\factions\MODERN\<file>_<side>.sqf`, then
`compile preprocessFileLineNumbers` and call it — populating the schema. (This dynamic path build is why
the faction folder can't be renamed without care.) `AUTODETECT*`/`CUSTOM` route to the generator or the
paste parser instead of a static file.

## The confirmation screen

After both sides are chosen, `client/dialog/fnc_faction_confirm.sqf` shows every role key both sides will
field, side by side, and lets the player swap, edit or clear any of them. It is the reason faction resolution no
longer waits for the post-START commit: the screen has to show resolved classnames, so it asks the server
to resolve and the commit applies the player's table over the result.

**Request and ready are counters, not flags.** The screen increments `duws_faction_preview_request` on
open; `server_init.sqf` serves in a loop and sets `duws_faction_preview_ready` to the number it served,
which is what the screen waits on. A loop because the environment screen's Back button re-enters faction
selection and the screen asks again with the new pick; counters because a flag cleared by the server races
a fresh request, and the screen would paint the previous pick's rows. Two obligations land outside the
screen: every path the loop calls — both faction inits, all three AutoDetect wrappers, the paste parser —
has to survive a second call, and the loop `publicVariable`s every schema key before answering, because no
faction file runs on a client and a static one assigns server-side only. The loop also publishes the
request-menu catalogue, which the schema does not cover: `blufor_RQST_UNITS` / `blufor_RQST_VEHICLES`, or
the numbered slots that `fnc_faction_rqst_list` falls back to.

On Continue the screen publishes `duws_faction_locked` — the whole table, not just the edits, so applying
it is an overwrite rather than a reconciliation. `server/warcom/fnc_faction_apply_locked.sqf` does that on
the server at the commit and broadcasts every key, so every client reads the confirmed table, a joining
client included. The table already holds every row's whole pool, because the screen builds its rows from
`DUWS_factionPreviewPools`. The commit therefore runs `fnc_faction_augment` only when no table was locked
(the debug quickstart). A second pass would rebuild each pool from its representative and undo the list
edits.

**A vehicle role is an edited list.** EDIT on a vehicle row opens `startup_faction_key_list`
(`client/dialog/fnc_faction_key_list.sqf`): the role's list beside the class browser, with Add, Remove,
Make main and Reset. Infantry and static rows keep the single pick behind SELECT, because
`fnc_faction_poolable_keys` holds those roles to one class. The browser offers only `scope` 2 classes, the
gate that `fnc_faction_keep` applies at the commit.

**The edits are kept as intent, not as a list.** A role's edits are one record, `[main, added, dropped]`
(`shared/faction_lib/fnc_faction_lists.sqf`). The base is the pool the server built before the screen. When
the player makes a class main, the base becomes that class's bucket (`fnc_faction_pool_for_class`). The
list is the main first, then the base minus the drops, then the adds. The first entry is the
representative, so the single-class readers get the main. The main cannot be removed, because a removal
would silently re-parent the role to the next entry. Each locked vehicle row carries its record, and the
server rebuilds the row from the record with `fnc_faction_edits_apply` instead of trusting the client's
list. That function gates the list through `fnc_faction_keep` and keeps the records in
`DUWS_factionListEdits`, so a later detection can apply them again.

A record applied over a later detection can name a class that the session lacks, for example after the
player removes a mod. `fnc_faction_edits_apply` handles each case:

| Missing | Result |
|---|---|
| `main` | The base falls back to the pool that resolution built, as if `main` were `""` |
| A class in `added` | `fnc_faction_keep` removes it |
| Every class in the resolved list | The key keeps the pool that resolution built, and a WARN names the key |

`shared/faction_lib/fnc_faction_schema.sqf` is the single source for which keys exist. It returns
`[key, group, kind, required]` per side and feeds the screen's rows, `fnc_custom_faction_parse`'s
required-key validation, and both AutoDetect wrappers' pool-publish lists — which each held their own copy
of the list before.

`required` is false for the five static keys and `opfor_ARTY_X`, all added after the 254 shipped faction files were written. None
of those files defines them, so requiring one would fail every custom paste a player already has, including
one copied out of `factions/MODERN/`. The parse clears the whole schema and validates only the required
subset: narrowing the clear as well would let an optional key survive a re-paste, and stepping back into
the faction screen re-pastes as a normal navigation path.

### Static weapons resolve at placement

`shared/functions/fnc_static_roles.sqf` holds the placeholder table, the resolver and the placer. A
composition names a vanilla static because that is what its author dragged into Eden; `DUWS_staticRoles`
maps that class to a role, and `fnc_static_resolve` turns it into `<side>_TURRET_<ROLE>` drawn per object
out of the pool. A row that names its own key — the HQ and FOB fences — skips the table.

Artillery is the one role in that table whose piece is a vehicle. It resolves to `<side>_ARTY_X` instead
of a turret key and skips both guards below — the MG substitute would stand a machine gun where a battery
belongs, and the `StaticWeapon` test refuses every self-propelled gun there is. A side that fields none
keeps the composition's own placeholder, since a tank standing in for a gun is a battery that cannot
answer a fire mission. `fnc_hardpoint_build` draws once for each placeholder class in a composition, so all
guns in one battery are the same type. The next battery draws again, so a pool with several guns still
varies from one battery to the next.

Four things it refuses to do silently. A class the table does not carry stands as itself, which is what
keeps a prefab working while the table is incomplete and is the answer for every prop the placer is handed.
A role the faction never fields falls to that faction's MG nest, the habit 25 of the shipped BLUFOR files
already wrote by hand; `server_init.sqf` warns once per campaign when a side has no static MG for that to
reach. An answer that is not `isKindOf "StaticWeapon"` is refused and the placeholder kept, because the zone
manning hook, its crew-out counterpart and the empty-vehicle cleanup's exemption all key off that test — a
mod "static" configured as a car would be placed, never crewed, and swept away as abandoned. And the class
is drawn through `fnc_faction_pick` rather than read off the global, so two MG nests in one zone can be
different guns.

`fnc_static_place` is the only sanctioned way to put one down. It freezes with `enableSimulationGlobal
false` at creation — which is what holds a row where its Z put it, since an unsimulated object does not fall
— and each caller's crew step thaws once a gunner is in.

## The static template library

`factions/MODERN/` holds 254 hand-authored files (122 `*_blufor.sqf`, 132 `*_opfor.sqf`), one per supported
mod faction — RHS, CUP, 3CB, CFP, VME PLA, GM, TIOW, and many more. Each is a flat script of direct
assignments, e.g. from `3CB_US80_WDL_blufor.sqf`:

```sqf
blufor_SOLDIER_X   = "UK3CB_CW_US_B_LATE_RIF_1";   // patrol, fortify, paradrop
blufor_TURRET_HMG  = "UK3CB_CW_US_B_LATE_M2_TriPod";
```

Trailing comments name the consuming function for each variable — the de-facto schema spec.

## The procedural generator (autodetect)

`fn_factionAutoDetect.sqf` synthesizes the same schema for **any** faction with no hand-authored file:

- **`fnc_parseFaction`** enumerates the faction's `CfgVehicles` and buckets it. Infantry is classified by
  role via `fnc_unitParseRoles`, which inspects each unit's loadout, weapon UI-icon path (`icon_mg_ca.paa`,
  `icon_at_ca.paa`, …), config flags (`attendant`, `engineer`, `uavHacker`) and displayName keywords into
  grunt / medic / SL / TL / AR / MG / GL / AA / LAT / HAT / officer / marksman / sniper / eng / EOD / pilot /
  crew / diver / UAV, plus suppressed-weapon "spec-ops" variants. Vehicles are bucketed by editor subcategory
  and `isKindOf` filters (`fnc_filterBySeats`, `fnc_filterByWeapons`, `fnc_filterByPylons`,
  `fnc_filterByUtility`) into turrets, APCs, tanks, artillery, cars, helis, planes, boats, drones.
  Vehicle buckets that feed different roles must not overlap. A pool is rebuilt from the tightest bucket
  that holds the role's representative (`fnc_faction_pool_for_class`), so a class in two buckets can give
  one role the other role's pool. For this reason, the armed-heli bucket holds only gunships (pylons, or a
  cannon, rocket or missile weapon), the transport-heli bucket excludes those gunships, and the truck
  bucket holds only unarmed vehicles.
- **`fnc_factionGen`** assigns the `blufor_*`/`opfor_*` globals from the parsed buckets, using
  `fnc_selectNonEmpty` fallback chains that end in vanilla assets, and builds the request-menu vehicle list
  priced by `fnc_evalVehicleCost` (estimates a CP cost from vehicle type, weapons, armor, sensors and threat
  rating).
- **`fnc_factionSelector`** is a listbox of the factions the server detected (`DUWS_detectedFactions`,
  built at init by `fnc_getAllFactionsClean` over `BIS_fnc_getFactions`). It runs on the game master's
  client and is the only AutoDetect helper broadcast to clients.
- The `AUTODETECT_{blufor,opfor}.sqf` wrappers add an `EntityCreated` handler (`fnc_vehiclePostInit`) that
  retextures and re-crews vehicles spawned for a mismatched faction, then hand every array-valued role to
  `fnc_faction_pools_publish`. `AUTODETECT_RANDOM_opfor.sqf` is the same pipeline but auto-picks a random
  faction instead of prompting.

  **Detection derives once; the pick happens per spawn.** A role global holds one classname because every
  spawner hands it straight to `BIS_fnc_spawnGroup` or `createVehicle`, so the several candidates detection
  finds are kept beside it in `DUWS_factionPool_<role>` and drawn from by `fnc_faction_pick` at the moment
  a unit is placed. A thread per role re-rolling the global every 300 s did this before, which gave variety
  across *time* rather than across the map — every zone raised in the same five-minute window fielded the
  identical APC — while drifting the faction identity detection exists to establish, and costing seventy
  permanent scripts and seventy broadcasts every five minutes for a value only read at spawn.

## Custom factions

The `CUSTOM` option lets a player define a faction by pasting text. `fnc_custom_faction_capture.sqf` reads
two dialog text boxes (controls 2100/2101, defined in `shared/includes/custom_faction.hpp`) into
`BLUfactionDataTemp` / `OPFfactionDataTemp`. `fnc_custom_faction_init.sqf` then splits the pasted text on
newlines, keeps lines containing `blufor_` / `opfor_`, strips path-like lines, and `call compile`s each
`variable = "classname";` pair — so the paste is executed as SQF. The paste dialog does not close until
the server's check passes (`fnc_faction_query`, op `validate`): every required key must name a class that
the server has. This is a runtime eval of user input; it is server-side and gated behind the
custom-faction dialog.

## Squads and civilians

`shared/functions/fnc_spawn_vocab.sqf` holds `DUWS_teamRosters`, one table of teams both armies raise
out of: a row names roles bare and `DUWS_fnc_teamRoster` prepends the side. `recon` is the same four
roles whoever stands it up. Its own file rather than a block beside the zone spawn band, because the
BLUFOR squad catalogue is priced at `server_init` before that band is spawned.

A row is a role list and at most one leader, and nothing about how many of the team a site fields —
that is the composition's to say. The enemy multiplier used to reach inside a row instead, repeating
a "core" column while a "tail" column was added once so a x3 setting fielded one marksman rather than
three; it scales whole cards now (`DUWS_fnc_scaleComposition`), so a x3 zone fields three patrols
rather than one patrol of six men, and the row lost two columns and a rule with it.

`server/init_hq/fnc_BLUFOR_squad_init.sqf` prices the purchasable sections against that table — recon
team, infantry squad, motorized / mechanized / armor sections — each tagged with a CP price (e.g.
`blufor_INF_SQUAD_X = [_squad, 12]`). Squad init runs once at boot — it was re-run every five minutes
to track re-rolled classnames, and with the roles stable that rebuild produced identical data, while a
catalogue whose prices reshuffle under the player is worse than a fixed one.

Civilians are templated separately. `shared/factions/CIV_FACTIONS.sqf` sets `civ_array` from the
`CIV_PRESENCE` parameter, choosing a classname list per source: vanilla (regional variants), CUP, CFP,
PrOpfor/LOP, Unsung, IFA3, and a Ravage-zombie set (which falls back to vanilla civs if Ravage is absent).
`civ_array` feeds the civilian/informant system in `server/misc/`.

## Bandits

Bandits are a third hostile force on INDEPENDENT, which `server/server_init.sqf:22-27` sets hostile to
both armies. They are not a selectable faction and have no variable schema. `fnc_bandit_spawn`
(`server/bandits/`) raises base-game FIA bodies (`I_G_Soldier_F`), re-dresses them and arms them.

Clothing comes from `DUWS_banditLooks`, which `fnc_bandit_looks` builds once at server init from the
unit config of three native bandit sources. Each slot (uniform, headgear) draws a source at random and
then an item from it, so one bandit can mix sources. Facewear is the FIA body's own.

| Source | Factions | Withheld by the `Bandits` parameter |
|---|---|---|
| FIA | `BLU_G_F`, `OPF_G_F`, `IND_G_F` | Never |
| Syndikat | `IND_C_F` | No DLC, No Apex DLC |
| Looters | `IND_L_F` | No DLC, No Contact DLC |

The parameter gates clothing only. A source that yields no uniforms logs a `BANDIT` warning and is
dropped.

Kit, vests included, comes from `fnc_civ_arm` with the pool `["opfor", "blufor"]`. The five roles
(rifleman, autogunner, grenadier, AT, medic) map to its token specs in `fnc_bandit_spawn.sqf`. The
pool samples only three unit loadouts per side, so a role whose weapon category it lacks (a machine gun,
an SMG) carries an assault rifle instead. Every bandit also carries two `HandGrenade` and two
`FirstAidKit`. Bandits spawn at `opfor_ai_skill` and carry no random loot. Civilian side missions raise them
([`side_mission_catalogue.md`](side_mission_catalogue.md#civilian-side-missions)).

WBK zombies also spawn on INDEPENDENT (`server/civilian/fnc_civ_handler_wbk.sqf:254`), so bandits and
zombies never fight each other. A zone's enemy trigger counts EAST only
(`server/init_zones/fnc_createzone.sqf:155`), so bandits neither hold a zone nor block its capture.

## Adding a faction

1. Create `factions/MODERN/<FILE>_blufor.sqf` and `<FILE>_opfor.sqf` assigning the full schema (copy an
   existing file of a similar mod as the starting point).
2. Add a registry line to `_faction_files_BLUFOR` / `_faction_files_OPFOR` in
   `fnc_factions_check_modern.sqf`: `[<probe rifleman>, <faction class>, "<menu label>", "<FILE>"]`. The
   probe must be a class that exists only when the mod is loaded.
3. Repack and test: the new faction appears in the start dropdown only if its probe class resolves.

## Constraints worth knowing

- `VERSION_X` (value `"MODERN"`) is both the era switch used across the dialogs/squad logic and the
  `factions/` subfolder segment in the load path; its value is game state and the folder is named to match
  it (see [`architecture.md`](../architecture.md)).
- Faction variables are plain globals populated server-side and `publicVariable`d; a consumer that runs
  before faction init sees nil.
- The static library and the registry in `fnc_factions_check_modern.sqf` must stay in lockstep — a template
  file with no registry entry is unreachable, and a registry entry with no file fails the dynamic load at
  selection time.
