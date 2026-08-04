# Dead code inventory

What is unreferenced under `src/duws/` and still in the tree, and why each of it is still there.
Anything not listed here has either been removed or is live.

Two passes have looked. The first read `.sqf` only and deleted what it found; the second widened to
the config includes, `description.ext` and `stringtable.xml`, and also caught residue inside `.sqf`
that the first could not see as text. The residue is listed below rather than silently re-swept,
because a reader who finds an unused variable naturally asks whether the earlier pass considered and
kept it. It did not: it could not see it.

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

### The support in-use flags are redundant, not a missing guard

`CASInUse` (`client/includes/supports_init.hpp`, `client/supports/fnc_request_hcCAS.sqf`) and
`AttChopInUse` (same pair, with `fnc_request_hcATTchop.sqf`) are written and never read. Their
shape — set true on request, false on both completion paths — reads as a guard against requesting
a support twice, and invites someone to "finish" it by adding the read.

That guard already exists and works. `shared/includes/supports_radio_modern.hpp` declares each
support with `removeAfterExpressionCall = 1` and an expression calling `fnc_support_comm_used`, so
requesting one removes its comm-menu item and drops it from the held record; only the completion
paths hand it back through `fnc_support_comm_add`. The comm menu owns this state, and the record
doubles as the presence test.

Adding a read of `CASInUse` would introduce a second, weaker source of truth for something already
handled — so these are duplicates to delete, not a gap to fill.

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

## Residue a `.sqf`-only text pass could not reach

### Four globals written and never read

| Global | Written at |
|---|---|
| `hq_manually_placed` | `server/server_var_init.sqf:212`, `client/dialog/fnc_HQ_manual_place.sqf:7`, both `publicVariable`d |
| `zones_manually_placed` | `server/server_var_init.sqf:323`, `publicVariable`d |
| `WARCOM_blu_attack_delay` | `server/warcom/fnc_WARCOM_init.sqf:20` |
| `DUWS_number_at` | `client/includes/squad_number_init.hpp:4` |

`WARCOM_blu_attack_delay` is the one worth reading before deleting: its only consumer is a
commented-out `sleep` at `server/warcom/fnc_WARCOM_blu_assault.sqf:138`, so removing the global
also discards the last record of what that delay was for.

### Unused locals

| File | Local |
|---|---|
| `client/misc/fnc_player_markers.sqf:140,155,161,165` | `_injured`, assigned four times, read never |
| `client/misc/fnc_bottom_right_message.sqf:73` | `_showDate` |
| `shared/factions/MODERN/fn_factionAutoDetect.sqf:134` | `_passengers` |
| `shared/factions/MODERN/fn_factionAutoDetect.sqf:586` | `_turretCannon` |
| `server/missions/mission_threads/rescue_squad/fnc_rescue_squad_mission.sqf:26` | `_targetpos` |
| `client/warcom/fnc_WARCOM_mapclick_assault.sqf:6`, `client/supports/fnc_mapclickuav.sqf:6`, `client/supports/fnc_mapclickarty.sqf:50` | `_pos` |

Two need a word. The `_targetPos` read at `fnc_rescue_squad_mission.sqf:79` and `:86` comes from the
`params` of `fnc_rescue_squad_uncaptive` at `:60`, a scope of its own, so the outer write at `:26` is
not what feeds it. The three `_pos` declarations are the engine-handler case in the table above.

### Unreferenced stringtable keys

103 of the 1295 keys in `src/stringtable.xml` are named nowhere in the mission: 43 with descriptive
names, 60 with generated ones. They cluster by feature in a way that reads as reworked rather than
abandoned text — `STR_DUWS_T_LOOT1`, `LOOT_MONEY2` and `LOOT_NOTHING` are dead while `LOOT2` and
`LOOT4` are live, and twelve `*DISGUISE*` keys are dead against roughly seventy that are not.

Two are parked rather than dead: `STR_DUWS_T_RAVAGE_HELP_SUB` and `STR_DUWS_T_WBK_HELP_SUB` belong
to the modes held back until base DUWS is whole, and deleting them would have to be undone. Weigh
the rest against the translation debt: an unused key still costs every language that has to carry
it, and re-adding one later is cheaper than translating one that was never needed.

## The domination briefing bypasses its own translated string

`server/missions/mission_threads/domination/fnc_domination_mission.sqf:35` hints the hardcoded
English literal `"Armor Hunting"` for its briefing. Every other mission thread shows a localised
`_markerText2` through `[_markerText2,{hint _this}] remoteExec [...]`, and domination's key
`STR_DUWS_T_c13` exists and is translated in `src/stringtable.xml`.

The unused `_markerText2` local that pointed at this went with the rest of the dead code, which is
why the defect is recorded here rather than beside the other live ones: without this note, the next
reader sees a hint with no local behind it and nothing saying a translated key was ever intended.
Fixing it is a one-line substitution.
