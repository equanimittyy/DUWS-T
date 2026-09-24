# Eden composition files: implementation plan

Store each static layout as the `composition.sqe` file that the Eden editor saves, and read it at
runtime through `missionConfigFile`. Today each layout is an SQF array between
`--DUWS-COMPOSITION` fences, and every edit goes through the `duws_eden.ps1` round trip: import
into the Eden console, rearrange, export, paste back, and reconcile by row index
([`composition_tooling.md`](../info/architecture/composition_tooling.md#static-compositions-the-eden-round-trip)).
After this change, an edit is "Save composition" in Eden, and the change lands in `src/`.

The row stays the runtime contract. A new reader turns a composition into the same
`[class, X, Y, Z, dir°, isWeapon]` rows that the fences hold now. `fnc_composition_place`,
`fnc_static_place`, the stream store and OPCOM's hardpoint read do not change.

The unit-composition half of the tool (`--DUWS-UNITCOMP`) is out of scope. Those tables are data,
and there is nothing to see in Eden.

## What the engine gives

A `composition.sqe` file uses config syntax, the same as `mission.sqm`. A mission can read it in
two ways:

| Route | How | Decision |
|---|---|---|
| `#include` in `description.ext` | `class CfgCompositions { class duws_hp_mg { #include "..." }; };`, read through `missionConfigFile` | Chosen. The engine parses it once at mission load, and `check_paths.py` already resolves every `#include`, so a missing file fails the lint. Larrow's `LARs_fnc_spawnComp` uses this route. |
| `loadConfig "path\composition.sqe"` | Returns a `Config`, or `configNull` when the file is missing | Rejected. The BI wiki says that a load is slow and must be cached, and the cache holds a handle. It is not verified that a `Config` can live in `missionNamespace` ([§Non-serializable handles](../info/architecture/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)). |

The file layout, read from the LARs source and from a public composition file:

| Field | Meaning |
|---|---|
| `center[]` | The world position where Eden saved the composition, in the order `[x, z, y]`. |
| `class items >> class ItemN` | One entity. `dataType` is `Object`, `Group`, `Layer`, `Logic`, `Marker`, `Trigger` or `Waypoint`. |
| `Layer` or `Group` `>> class Entities` | The children of a layer or a group, in the same `ItemN` form. |
| `PositionInfo >> position[]` | The offset from `center[]`, in the order `[x, z, y]`: height is the middle value. |
| `PositionInfo >> angles[]` | `[pitch, yaw, roll]` in radians. LARs applies `deg yaw` through `setDir`, so yaw has the same sense as `getDir`. |
| `Attributes >> name` | The variable name set in Eden. The reader finds the frame markers by it. |
| `type` | The class name. |

`header.sqe` holds the display name, the author and the Eden category. The mission does not read
it, but Eden needs it to list the composition, so it stays next to `composition.sqe`.

Eden also saves `CustomAttributes` for the mods that are loaded at save time (the public sample
carries an ACE medical-facility flag). The reader reads only `type`, `PositionInfo` and
`Attributes >> name`, so these attributes are inert and add no mod dependency. Save with no mods
loaded anyway, so that the diff does not carry them.

## Design

### Files

Each composition is one folder, `src/duws/compositions/<name>/`, that holds `composition.sqe` and
`header.sqe`. `<name>` is `lower_snake_case` with no spaces, and it is also the Eden composition
name and the config class name. Eden names the folder after the composition and URL-encodes the
name (a public composition repository has a folder named `Artillery%20Position`), so a name with no spaces keeps all three the
same.

`src/duws/shared/includes/compositions.hpp` holds one `class CfgCompositions` with one class per
composition. `description.ext` includes it next to the other `duws\shared\includes` files. The
`.sqe` files pack with no build change: `repack.cmd` stages all of `src/` with no extension filter,
and `pbo.json` only selects which files to compress.

### The frame

Each composition carries the two markers that the export uses now: `DUWS_ORIGIN`, a `FlagPole_F`
at the origin, and `DUWS_FRONT`, which marks the facing. They are saved inside the composition, so
the frame moves with the layout into and out of Eden. `center[]` only records where the save
happened, and a layout that was dragged or turned before the save still measures correctly from its
markers. This is the property that makes the current export rotation-proof.

### The reader

`[_name, _layer] call fnc_composition_rows` lives in
`src/duws/server/placement/fnc_composition_rows.sqf` and is compiled next to
`fnc_composition_place` (`server_fnc_init.sqf:67`). It returns `[class, X, Y, Z, dir°, isWeapon]`
rows:

1. It walks `missionConfigFile >> "CfgCompositions" >> _name >> "items"`, descends into `Layer`
   entities, and keeps only `dataType="Object"`. This drops the crew that Eden saves with a static
   weapon (a `Group`) and any module (a `Logic`, which `createVehicle` refuses:
   [§Module rows](../info/architecture/arma_engine_gotchas.md#an-eden-export-writes-module-rows-a-composition-placer-cannot-build)).
2. When `_layer` is not empty, it keeps only the objects under the top-level layer with that name.
   A site whose parts have different lifetimes (props built once, guns rebuilt) stays one
   composition in Eden.
3. It finds `DUWS_ORIGIN` and `DUWS_FRONT` by name in the whole composition, drops both, and
   measures every row from the origin in the frame that the front marker points down. The math is
   the export's (`scripts/duws_eden.ps1:315-373`).
4. It derives `isWeapon` from the class against `DUWS_staticRoles`. The TUI already uses this rule
   for a row that has no flag to inherit, and the rule agrees with every flag in the shipped
   fences. `DUWS_staticRoles` loads at `server_fnc_init.sqf:214`, before the first caller at `:226`.
5. When the class or a marker is missing, it logs an `ERROR` through `fnc_log` and returns `[]`.
   Without the log, a composition that places nothing is silent.

Every row has six columns. The FOB and killhouse consumers read five with `params`, so the sixth
column has no effect there.

The reader does not cache. The hardpoint tables call it once at load, and a prefab or a mission
calls it once for each build, where one config walk costs little next to the `createVehicle` calls
that follow.

No consumer reads rows by index, so the order of the items in the file does not matter.
`fnc_destroy_cache_mission.sqf` needs exactly two weapon rows, but `fnc_place_bunker_guns` treats
the two guns the same. The patrol camp finds its campfire and its table by class
(`fnc_destroy_patrol_camp_mission.sqf:71,81`), and the HQ and the killhouse find their anchors by
class.

### Z

Every consumer keeps its current Z rule. Prop Z is discarded, a weapon row's Z is its height over
the ground at the origin, and the killhouse reads Z as an offset from `_centerSpawnZ`. So the
reader must give the Z that the export gives now: the object's `getPosWorld` height over the base
of `DUWS_ORIGIN`, which is the marker's centre minus `3.9775` (`$markerZ`,
`duws_eden.ps1:61-66`).

The public sample suggests that the `position[]` height is the `getPosWorld` centre over the
`center[]` height: a razorwire coil about 1.5 m tall reads 0.755. If that is true, row Z is the
item height minus the origin marker's height, plus 3.9775. Phase 1 verifies this by parity.

## Authoring loop

1. Link once. A `duws_eden.ps1` command creates a directory junction for each
   `src/duws/compositions/<name>` in the profile's `Compositions` folder. Eden then lists the
   mission's compositions with the custom compositions and saves directly into `src/`.
2. Place the composition in Eden on flat ground and edit it.
3. Select everything, including both markers, and use "Save composition" with the same name.
4. Review the diff and repack.

Each existing fence migrates through the current tool one last time. Import the fence, which
raises both markers. Move any subset into its named layer. Then save the selection as a
composition.

## Changes for each fence

| Fence | Composition | Change |
|---|---|---|
| 9 hardpoints, `init_zones/hardpoint_compositions.sqf` | `duws_hp_<type>` | Each `DUWS_hardpointComp_<TYPE>` global is assigned from the reader. `fnc_hardpoint_comp` (`placement/fnc_composition_sets.sqf:33-43`) and `fnc_opcom_force.sqf:110` read the globals and do not change. |
| 7 zone prefabs, `init_zones/prefabs/modern/` | `duws_zone_<name>` | The literal becomes a reader call. |
| Destroy Cache, Destroy Radar, Patrol Camp | `duws_mission_<name>` | The literal becomes a reader call. |
| FOB Perimeter and FOB Turrets | `duws_fob`, layers `perimeter` and `turrets` | `_fnc_place` (`fnc_fortifyFOB.sqf:105-117`) writes the row's Z through `setPos`. Every row holds 0 now, but the reader gives a prop its centre height, so `_fnc_place` writes 0, as every other prop placer does. |
| Killhouse Objects and Killhouse Targets | `duws_killhouse`, layers `objects` and `targets` | `killhouse_composition.sqf` is deleted. `_centerSpawnZ` (declared at its `:9`) moves into `fnc_createKillhouse.sqf`, and both arrays come from the reader. |
| HQ Main Base | `duws_hq` | `DUWS_ORIGIN` stands on the HQ building's row, so the rows become offsets from the building and each object goes to `PosOfBLUHQ + row`. `_hqInCompX/Y` and `_compCenterX/Y` (`fnc_BluHQinit.sqf:14-20`) are deleted. |
| HQ Turrets | Stays in SQF | Four of its eight columns are not layout: the unused Z, `role`, `anchorClass` and `hOffset`. The two rows move into the HQ building's frame once (minus `_hqInComp`), and the fence markers are deleted. |
| Simple Zone | Stays in SQF | One camouflage net at the origin is not a layout. The fence markers are deleted. |

## Lint

`check_paths.py` already fails on an `#include` of a missing `.sqe`. A new check,
`tests/lint/check_eden_compositions.py`, run from `tests/run.sh`, catches the failures that are
silent until a site is built:

- A name passed to `fnc_composition_rows` that has no class in `compositions.hpp`.
- A `composition.sqe` without exactly one `DUWS_ORIGIN` and one `DUWS_FRONT`.
- A layer name passed in SQF that the composition does not hold.

## Phases

### 1. Reader and pilot

Build `fnc_composition_rows`, `compositions.hpp` and its include, the link command and the lint.
Migrate the MG Nest (`DUWS_hardpointComp_MG`): it has three rows and one gun, so a Z error shows
on one row.

Verify by parity. With the `.sqe` included and the literal still in place, compare the reader's
rows with the literal class by class in the debug console: X, Y and the weapon row's Z within
1 cm, and the heading within 0.1°. Then delete the literal.

The pilot also answers the questions that the documentation cannot:

| Question | What the answer changes |
|---|---|
| Is the `position[]` height the `getPosWorld` centre over the `center[]` height? | The Z formula in the reader. |
| Does Eden save through a directory junction, and does "Save composition" with an existing name overwrite in place? | If not, the link command becomes a copy command in each direction. |
| Does a re-save with nothing moved keep the item order and the `id` values? | If not, each save rewrites the whole file, and the review relies on the parity check instead of the diff. |
| Which folder does Eden save to: `Documents\Arma 3\Compositions` or `Documents\Arma 3 - Other Profiles\<profile>\Compositions`? | Where the link command writes. |

Each answer that is an engine trap goes into
[`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) in the same change.

### 2. The shared-placer compositions

The other 8 hardpoints, the 7 zone prefabs and the 3 mission fences. All of them go through
`fnc_composition_place` and `fnc_static_place`, so each is the pilot's swap with the pilot's
parity check.

### 3. FOB

One composition with two layers, and the `_fnc_place` Z change.

### 4. Killhouse

One composition with two layers. It is the largest layout, with about 700 object rows, and the only
one whose prop Z is kept, so it is the parity check at altitude. It is also the largest include:
compare the mission load time before and after.

### 5. HQ

The frame change and the turret conversion. `fnc_redeployHQUnits.sqf` reads the `HQ_redeploy_*`
variables that `fnc_BluHQinit.sqf` sets at build, so the redeploy needs no edit.

### 6. Retire the static half of the tool

Delete the static menu of `duws_eden.ps1` (import, export, update, new composition, `$markerZ` and
the fence scan), except the link command. Rewrite the static-composition sections of
`composition_tooling.md` around the authoring loop above. Update the fence wording in
`hardpoints.md:77` and in the source comments that describe the round trip, for example
`fnc_BluHQinit.sqf:176-195`. This phase is last because every migration uses the import.

## Files touched

| File | Change |
|---|---|
| `src/duws/server/placement/fnc_composition_rows.sqf` | New. The reader. |
| `src/duws/server/server_fnc_init.sqf` | Compile the reader next to `fnc_composition_place` (`:67`). |
| `src/duws/shared/includes/compositions.hpp` | New. `class CfgCompositions`. |
| `src/description.ext` | Include `compositions.hpp`. |
| `src/duws/compositions/<name>/` | New. 22 folders, one for each composition. |
| The 16 files that hold fences | The literal becomes a reader call, or the fence markers are deleted (HQ Turrets, Simple Zone). |
| `src/duws/server/killhouse/killhouse_composition.sqf` | Deleted. |
| `src/duws/server/killhouse/fnc_createKillhouse.sqf` | Declares `_centerSpawnZ` and reads both layers. |
| `scripts/duws_eden.ps1` | The link command. The static half is deleted in phase 6. |
| `tests/lint/check_eden_compositions.py`, `tests/run.sh` | The new check. |
| `docs/info/architecture/composition_tooling.md` | The static half is rewritten. |
| `docs/info/gameplay/hardpoints.md` | The authoring description. |
| `docs/info/architecture/arma_engine_gotchas.md` | The traps that the pilot verifies. |

## Decided trade-offs

**`#include` over `loadConfig`.** Every machine parses the compositions, but only the server places
them. That costs one config parse at mission load. The alternative is a cached handle whose storage
rules are not verified.

**A reader of our own, not `LARs_fnc_spawnComp`.** LARs creates the objects itself, so it would go
around `fnc_duws_keep`, the stream store and the faction resolution in `fnc_static_place`. It is
also about 1,450 lines, and the SimTools copy has no license file. The reader needs only objects,
names and one frame.

**The row stays the contract.** The reader gives what the fences hold now. The placers, OPCOM and
the stream store stay out of this change, and each migration is verified by comparing two arrays.

**Layers, not a second composition, for a split site.** Two compositions for one site have two
origins to line up by hand in Eden. One composition with two layers shows the whole site and keeps
one frame.

**HQ Turrets and Simple Zone stay in SQF.** Half of each HQ turret row is placement data that Eden
cannot hold, and a single net at the origin has no layout to edit.

**Diffs get longer.** One object in `composition.sqe` takes 15 lines or more, where a fence takes one
row, so a moved object shows as a changed `position[]` inside a class block. For a layout change,
the parity check and a look at the site in play are the review.
