# Dead code inventory

What is unreferenced under `src/duws/` and still in the tree, and why each of it is still there.
Anything not listed here has either been removed or is live.

Two passes have looked. The first read `.sqf` only and deleted what it found; the second widened to
the config includes, `description.ext` and `stringtable.xml`, and also caught residue inside `.sqf`
that the first could not see as text. That residue is not enumerated here; git history and a re-run
of the wider scan can surface it, because a reader who finds an unused variable naturally asks
whether the earlier pass considered and kept it. It did not: it could not see it.

## What a scan of this kind can conclude

Three SQF properties bound what any text search over this tree can prove, and each has produced a
confident false positive here. All three are recorded in full in
[`arma_engine_gotchas.md`](arma_engine_gotchas.md).

| Property | What it breaks |
|---|---|
| Identifiers are case-insensitive | `fnc_bluHQinit` reads as an orphan next to `fnc_BluHQinit`; `GM_POLAND_WDL` reads as an orphan next to `GM_Poland_WDL.sqf` |
| A `call`ed or `compile`d block reads its caller's locals | `_faction` in `fnc_create_ammo_lists.sqf:159` is consumed by a `configClasses` condition string |
| Handler strings get their locals from the engine | a local `_pos` beside an `onMapSingleClick` install is dead, though the handler names `_pos` |

A fourth has no engine cause and simply needs remembering: globals reached through
`getVariable [format [...]]` are built at runtime. `blufor_RQST_UNITS` is written by 122 faction
files and read only through `fnc_faction_rqst_list.sqf:18`, which composes the name.

## Kept deliberately

### The kndr marker pack is vendored

`client/misc/fnc_kndr_unit_markers.sqf` is a third-party pack that sits in the DUWS tree rather
than under `src/modules/`. Four of its public functions are never called —
`kndr_setMarkerUpdateDelay`, `kndr_getMarkerUpdateDelay`, `kndr_disableShow`, `kndr_setMarkerText`
— and it carries an `if (true) exitWith {}` loop-break idiom. `kndr_assignMarker` and
`kndr_removeMarker` are live, driven by the MHQ deploy, undeploy and release paths.

Trimming a vendored API is a different decision from trimming DUWS code, and none of it costs
runtime, so the file is left whole. It has already diverged from upstream — it calls `fnc_log` —
so the argument for keeping it re-syncable is weaker than it looks; the argument for not editing
someone else's published surface is not.

### The GUI defines are stock Bohemia boilerplate

Eleven `#define`s in `shared/includes/defines.hpp` are never expanded: `CT_LISTNBOX`,
`CT_SHORTCUTBUTTON`, `GUI_GRID_WAbs`, `GUI_GRID_HAbs`, `MB_BUTTON_OK`, `MB_BUTTON_CANCEL`,
`MB_BUTTON_USER`, `ST_HORIZONTAL`, `ST_VERTICAL`, `TR_AUTOCOLLAPSE`, `TR_SHOWROOT`. They are the
standard control-type and style constants every Arma dialog file copies in, and the next dialog
added is as likely to want one as not. Deleting them buys nothing and makes the file diverge from
the shape anyone writing a new dialog will expect.
