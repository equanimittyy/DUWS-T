# Composition tooling

The mission has two kinds of composition, and each is edited where it can be seen.

| Kind | Where it lives | How it is edited |
|---|---|---|
| **Static** — object layouts (HQ, FOB, zone prefabs, hardpoints, mission sites, killhouse) | `src/duws/compositions/<name>/composition.sqe`, read at runtime by `fnc_composition_rows` | in Eden, saved as a custom composition |
| **Unit** — spawn tables (tier compositions, team rosters, the purchasable squads, the static-weapon role map) | `--DUWS-UNITCOMP--` fences in the source | in the composition TUI, which writes rows back to the source |

Static compositions are *layout*, so the file is the one the 3D editor saves. Unit compositions are
*data*, and there is nothing to look at in Eden.

The TUI is `scripts/duws_eden.ps1`, launched by double-clicking `duws_eden.cmd` at the repo root or by:

```text
powershell -ExecutionPolicy Bypass -File scripts\duws_eden.ps1
```

## Static compositions: edited in Eden

Each composition is one folder, `src/duws/compositions/<name>/`, which holds the `composition.sqe` and
`header.sqe` that Eden writes. `src/duws/shared/includes/compositions.hpp` gives each one a class under
`CfgCompositions`, and `description.ext` includes that file, so the engine parses every composition
once at mission load. `<name>` is the Eden composition name, the folder name and the class name.
Keep it `lower_snake_case` with no spaces: Eden URL-encodes the name into the folder name, so a space
becomes `%20` and the three names stop matching.

`[_name, _layer] call fnc_composition_rows` (`server/placement/fnc_composition_rows.sqf`) turns a
composition into rows `[class, X, Y, Z, dir°, isWeapon]`, the shape every placer already takes.
`isWeapon` is derived from the class against `DUWS_staticRoles`, which is the mission's own answer to
which classes are guns. The reader keeps only objects: Eden saves the crew of a static weapon as a
`Group` and a module as a `Logic`, and both are dropped
([§Module rows](arma_engine_gotchas.md#an-eden-module-in-a-composition-is-a-logic-a-placer-cannot-build)).

A name with no class, a layer the composition does not hold, and a composition without both markers
all place nothing. The reader logs an `ERROR` for the first and the last, but only when that site is
built, so `tests/lint/check_eden_compositions.py` checks all three before the mission ships.

### Editing one

1. Link once: `1` on the TUI's top menu lists the Arma profiles under Documents. Pick the one Eden
   runs under, and the tool creates a directory junction for each composition in that profile's
   `Compositions` folder. Eden then lists the mission's compositions with its custom compositions, and
   a save writes into `src/`. A name already taken in the profile is skipped, not replaced.
2. In Eden, place the composition on flat ground and edit it.
3. Select everything, including both markers, and use "Save composition" with the same name.
4. Review the diff and repack.

A new composition starts as a copy of an existing one, so that it carries both markers: place one,
replace its objects, save it under a new name, and move the new folder from the profile into
`src/duws/compositions/`. Then add its class to `compositions.hpp`, call the reader where it is built,
and link again.

### The two markers

Every composition holds two `FlagPole_F` objects that are not part of the layout: **`DUWS_ORIGIN`**
at the origin, and **`DUWS_FRONT`** clear of the layout along **+Y**. The reader finds both by
variable name, drops them from the rows, and measures every row from the origin in the frame that the
front marker points down. `center[]` in the file only records where Eden saved, so a layout that was
dragged or turned before the save reads back the same rows.

Keep both markers selected with everything else when you save. To *re-face* a composition, turn the
layout relative to `DUWS_FRONT`, or point `DUWS_FRONT` the new way: the rows then come back rotated,
which is what was asked for. A composition may hold a flagpole of its own, because a marker is known
by its name, not by its class.

### Layers

A composition read in halves splits them into top-level Eden layers, and the SQF asks for a layer by
name. The FOB (`perimeter`, `turrets`) splits because the halves have different lifetimes: the
perimeter stands for good, while a refortify replaces every turret. The killhouse (`objects`,
`targets`) splits because the targets are stored for the run functions, not built. An object outside
the named layers is never read by a consumer that asks for a layer.

### Heights

Eden saves each position as `[x, height, y]`, and the height is the model centre over the ground under
that object, not over `center[]`. Two sources agree on it: a `Land_HBarrier_1_F` reads 0.702 in
Eden-saved files and in the rows the mission once measured with `getPosWorld`, and an object on a
table carries its full height in `position[]` with the table's height repeated in `atlOffset`, which
the reader ignores. The reader passes the height through, measured from the base of `DUWS_ORIGIN`
(the pole's centre sits 3.9775 m above its base), so a layout built off the ground keeps its own datum.

Each consumer decides what the height means:

| Consumer | Row Z |
|---|---|
| Props through `fnc_composition_place`, and the HQ's props | Discarded: each prop is snapped to the terrain. |
| Weapon rows through `fnc_static_place` in `"world"` mode | The gun's centre over the ground under it, so a gun on a roof holds its height. |
| FOB perimeter (`fnc_fortifyFOB.sqf:42`) | The prop's centre over the ground under it. |
| FOB turrets (`fnc_fortifyFOB.sqf:68`) | Ignored: the ring's guns stand on the ground. |
| Killhouse | An offset from the floor at `_centerSpawnZ` (1000 m). |

Place a composition on flat ground in Eden, so that what the 3D view shows is what the mission builds.

### Static weapons

**A static weapon's class is a role token at runtime, not the gun that gets placed.**
`fnc_static_resolve` (`shared/functions/fnc_static_roles.sqf`) reads the class off the row, looks it
up in `DUWS_staticRoles`, and stands whatever the placing side's faction fields for that role — so
swapping a Mk6 mortar for an HMG in Eden changes the role every faction fills there, not just the
silhouette in the 3D view. Rearranging and rotating are free; retyping a class is a design change.
The class still decides what Eden draws, which is the point of keeping a vanilla one: the layout is
arranged against the right silhouettes whether or not a mod is loaded. A class the table does not
carry is placed as itself, so an unmapped gun is quietly no longer faction-aware, and it is not a
weapon row.

**Place the high-mount HMG and GMG, never the crouch-height one.** `DUWS_staticRoles` maps both
mounts of a family to one role, so which one stands is the faction's choice and not the author's —
but the row's Z was measured against the silhouette in the 3D view, and a gun a metre shorter than
the one it was arranged around sits a metre wrong. A second role per mount would not fix that: 252
of the 255 faction files name `TURRET_HMG` by hand and none would name the new key, so each would
fall back to the gun it already has. The heights those files actually name spread wider than one
mount does anyway, from a low `CUP_O_DSHKM_SLA` tripod to `rhs_KORD_high_MSV`.

**Crew placed in Eden is ignored.** Each prefab crews its own guns at build time
(`DUWS_fnc_crewCompositionStatics`, called at `fnc_modern_FieldHospital.sqf:40`), then the zone
re-seats them every streaming cycle.

## Editing the HQ layout

The player's Main Base (`src/duws/server/init_hq/fnc_BluHQinit.sqf`, compiled at
`server_fnc_init.sqf:486`, spawned at `server_init.sqf:192`) anchors on `PosOfBLUHQ`, the spot chosen
at placement (`fnc_HQ_random_place.sqf:38` or `fnc_HQ_manual_place.sqf:42`). The `duws_hq`
composition's `DUWS_ORIGIN` stands on the HQ building (`Land_Cargo_HQ_V1_F`), so every row is an
offset from the building and each prop goes to `PosOfBLUHQ + row`.

**Props from the composition, guns from code.** `_allObjectsData` (`:25`) holds every static prop —
walls, towers, tents, crates — and its loop (`:81-119`) snaps each one to the terrain. `_weaponData`
(`:37`) holds the two static guns in the same frame. They stay in SQF because half of each row is
placement data Eden cannot hold, and because the guns are replaced on every redeploy while the props
are built once. The loop skips a weapon row (`:83`), so a gun saved into `duws_hq` is never built;
the HQ's guns belong in `_weaponData`.

**A gun's height comes from its anchor, not its row.** Z is unused in `_weaponData`. The trailing
`anchorClass`/`hOffset` columns are resolved against `nearestObject` of that class at placement
(`fnc_placeHQUnits.sqf:64-68`), because a building's own `modelToWorld` Z is unusable. Move the gun's
row and only its X/Y/heading change; move its anchor structure and the height follows.

**What neither governs.** The garrison — tower guards, the door pairs, the sentry, the patrol, the
officer — is placed by `fnc_placeHQUnits.sqf`, called once at build (`:175`) and again on redeploy
(`fnc_redeployHQUnits.sqf:56`), from `modelToWorld` offsets measured against a spawned structure.
Move a guard by moving its anchor structure in the composition (dependents follow) or by editing the
offset in `fnc_placeHQUnits.sqf`. The redeploy path reads the `HQ_redeploy_*` variables that
`fnc_BluHQinit.sqf` sets at build time, not a second copy of the layout.

## Unit compositions: edited in place

Two ideas, and keeping them apart is what makes the menus make sense:

- A **composition** is a list of tokens, sometimes with a price. A zone tier, a town tier, a
  purchasable squad. Contract for what the tier tables mean:
  [`zones_and_civilians.md`](../gameplay/zones_and_civilians.md#zone-tiers). A garrison composition writes each
  entry as `posture:token` — one A3 group, its orders and its roster. Typed as one string rather
  than a pair because the row editor below splits on commas and would cut a nested list in half.
- A **token** is what one name stands for, and the Tokens menu holds every table of them: a team of
  men (`sniper_element` is two snipers until you say otherwise), one vehicle, and the class-to-role map
  behind a static weapon.

Compositions name tokens; a token is edited in one place and referred to from many. **The unit of
work is a row, not the table it lives in** — which file a composition sits in is not something the
person editing it should have to know — so the menu lists every zone tier, town tier and squad
together and opening one shows its configuration. A field naming a token shows what that token
raises beside it, so a reference is never a dead end.

```sqf
// --DUWS-UNITCOMP BEGIN name="OPFOR zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["patrol", "team", "car"],
    ...
];
// --DUWS-UNITCOMP END--
```

| Attr | Meaning |
|---|---|
| `name="..."` | label in the menu, and the key a write matches on |
| `kind=` | `composition` or `team` (the Tokens menu) — which menu its rows appear under. Anything unlabelled falls to `team`, so a table nobody classified is still reachable |
| `row="..."` | what one row means, since a row is a tier in one table and a vehicle in another |
| `rowname="Tier %1"` | how a row is named in the menu, `%1` being its index in roman. Without it the first column names the row, which is what a team and a squad already do |
| `fields="a, b, c"` | the row's columns, for a table whose rows are fixed-shape rather than a free-length list. Its presence is what switches the editor into field mode |
| `prefix=opfor_` | the faction prefix this table's role names carry: stripped for display, re-applied on write. A comma-separated pair (`prefix=blufor_,opfor_`) marks a table both armies raise out of — its names are stored bare, the side is prepended at spawn time, and the coverage check below runs against both armies with the worse answer reported |

A row without `fields=` is a plain list — add an entry, drop one, or retype the row. Entries are
typed unquoted (`patrol, team, car`) and the tool quotes anything that is not a bare number, so a
numeric column stays numeric and a token row stays strings.

### Field mode

A row of a `fields=` table is a thing with named parts — a team, a purchasable squad — so it is
picked apart by column instead of by entry index. Pick a row, pick a field, and the current value is
**already in the line** for editing rather than retyped from scratch; Escape backs out.

Each field keeps the kind it already had, inferred from the value rather than declared: a list stays
a list, a quoted name stays quoted, and a number field refuses anything else instead of writing a
table that will not compile.

One vocabulary is checked before a row is changed, and it catches a write that compiles and then
says nothing at runtime:

- **Role names**, against the slots the faction files under `shared/factions/` actually define. The
  count is the point rather than a yes/no: every faction file fills the same slots, so a name none
  of them defines would spawn nothing, and one only some of them define is a roster that quietly
  thins on the rest — which is the failure the faction auto-detection exists to prevent. A role
  `DUWS_roleFallbacks` names counts as covered: `fnc_faction_backfill` borrows it at load, and
  flagging it would put a hard warning on the mission's own answer to the gap.

The same resolution is gated headlessly for hand edits, which get none of the above: `tests/lint/check_compositions.py` (in `tests/run.sh`, python only) fails if a role token is absent from `fnc_faction_schema` or a `posture:token` cell names no team or vehicle. It uses the schema as the covered-set, since a required=false key is exactly a `DUWS_roleFallbacks` target.

A row holding a nested list belongs in a `fields=` table. The flat editor splits typed input on
commas, which would cut a nested list in half.

### Adding a token

The Tokens menu can append a row. A **team** or a **vehicle** added there is spawnable as it stands —
nothing in the mission has to learn the new name:

- A team row is a roster and nothing else. What the group *does* is the posture a composition names
  beside it, applied by `fnc_apply_posture`, so the same five men are a patrol on one row and a
  building garrison on the next. Before this the orders were a column here, and fielding those men
  under different orders took a second row with an identical roster.
- The spawn path asks the tables what a token is rather than switching on known names, so a token
  no table claims is a classname a faction file named directly and stands as itself.

The values already in a column are offered while typing, so what is on offer is what the tables
actually hold rather than a list in a doc that rots. A duplicate name is refused: the first column is
what compositions refer to, so a second row of the same name could never be reached.

Adding a **BLUFOR** team is the same — a squad references it by name and `fnc_BLUFOR_squad_init`
resolves it.

**Add** is on every menu, not only Tokens: a zone tier, a town tier and a purchasable squad are rows
like any other. A row of a table that declares no `fields=` is typed as one comma-separated list;
one of a fixed-column table is walked field by field, each blanked from the row above so it keeps
its kind. The one row that buys nothing on its own is a *squad*: the request dialog switches on a
hardcoded listbox index (`client/dialog/fnc_request_squad.sqf:16`), so a sixth squad needs a case
written there before anything can purchase what the table now offers.

### Adding a table

**New table** writes an empty fenced table and prompts for the attributes above, because every one of
them fails quietly when it is wrong: an unknown `kind=` files the rows under Tokens, a missing `row=`
leaves them described as "row", and a `fields=` that does not match what the rows hold switches the
editor into field mode against columns that are not there.

Two are refused outright rather than left to be edited later, because neither is recoverable from
inside the tool: a **name** another fence already carries, since a write matches a fence by name and
would rewrite both bodies; and a **variable** already assigned somewhere under `src/`, since whichever
file the mission compiles last wins and the table being edited need not be the one that is live.

A new table arrives empty, and the first row typed into it goes through the flat prompt whatever its
`fields=` says — the field walk reads each column's kind off the row above, and a table created a
moment ago has no row to read.

**A new row is live; a new table is not.** The spawn path asks the tables what a token is rather than
switching on known names, so a team or vehicle added to an existing table spawns without any code
changing. A new table is inert until something reads its global.

**Only the fenced body is rewritten.** The reasoning above each table is outside the fence and
survives editing, which is why the fences sit tight around the literal rather than around the whole
block.

Three things the writer refuses rather than guesses at:

- **A body that does not read back as the rows it came from.** The regenerated text is re-split and
  compared row for row before anything touches disk. These files are compiled by the mission, so a
  malformed table is a campaign that does not boot.
- **A file that is not valid UTF-8.** Thirty-five `.sqf` files under `src/modules` carry legacy
  single-byte encodings; reading one is harmless because the fence marker is ASCII, but writing it
  back would replace every non-ASCII byte in the file. No fence lives in one today.
- **A fence name that does not match.** Fences are rewritten by name, not by position, so every other
  table in the same file is returned untouched.

Past those, **git is the undo** — the tool writes into tracked source and you review the diff like
any other change.

### Adding a table to the tool

Wrap the literal in a fence and it appears in the menu; there is no code change. The parser expects
`<var> = [ <row>, … ];` and splits rows by bracket depth, so a row holding a nested array — a team's
role lists — survives intact. Set `kind=` so its rows land in the right menu, add `fields=` when
every row has the same columns, and `prefix=` when its names are faction slots.
