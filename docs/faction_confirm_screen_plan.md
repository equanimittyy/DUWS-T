# Faction confirmation screen

A setup screen that shows every DUWS role key both sides will field, side by side, and lets the
player swap or clear any of them before the campaign locks in. It sits between the faction/HQ
screen and the environment screen. Background on the schema it displays:
[`info/faction_system.md`](info/faction_system.md).

## Why it needs the flow rearranged

The screen shows resolved classnames, and at the point it opens nothing has resolved them.
`server_init.sqf:47-51` deliberately holds *all* faction resolution behind `createzone_server` —
the post-START commit — so that the environment screen's Back button can re-enter faction and HQ
selection with nothing yet built.

**Decision: the server resolves on request, and the commit applies the player's edits over the
result.** The client asks for resolution when the confirm screen opens; the server runs exactly the
faction init it would have run at commit and publishes the globals; the confirm screen reads them.
The alternative — the client resolving locally for preview — was rejected because `fnc_factionGen`
contains `selectRandom` (`AUTODETECT_blufor.sqf`, the `blufor_RQST_UNITS` block), so a client
preview and a later server build produce *different* factions: the player would confirm a roster the
campaign never fields. Resolving once, server-side, is the only arrangement where what is shown is
what ships.

What stays deferred to the commit: applying the locked overrides, `fnc_faction_pools_publish` over
the edited keys, and squad init (`fnc_BLUFOR_squad_init` composes from the role globals, so it must
run after edits land).

The server serves the request in a **loop** rather than once (`server_init.sqf`), because stepping
back from the environment screen re-enters faction selection and the screen asks again with the new
pick. Request and ready are **counters, not flags**: a flag cleared by the server races a fresh
request raised by the client, and the screen would paint the previous pick's rows. The screen waits
for ready to reach the number it asked with. `duws_faction_preview_ready` doubles as the served
marker, so no third variable is needed — and the wait condition reads globals only, because
`fnc_waitLogged` calls the condition block in its own scope and a captured `private` would be
undefined there.

Resolution publishes every schema key explicitly before answering. AutoDetect broadcasts its own
and a CUSTOM paste ships its assignment list, but a **static faction file only assigns server-side**,
and the OPFOR file is never run on a client at all — without the publish the screen would paint
whatever that machine happened to be holding.

### Re-entry after Back

Resolution is no longer once-only, so every init path has to survive a second run:

- Both faction inits overwrote `BLUFOR_Faction_X` / `OPFOR_Faction_X` from the dropdown's token to
  the faction class. A second run then matched no row and silently kept the *previous* faction's
  file. **`*_FactionFile_X` is now the dropdown's answer** — written by the combo handlers, defaulted
  in `server_var_init.sqf` to the row each combo opens on — and `*_Faction_X` is written only by
  init and means the faction class (`fnc_WARCOM_blu_patrol.sqf` reads it for random vehicle
  patrols). No new global: the two names that existed now carry one meaning each. This is why the
  `CUSTOM`/`AUTODETECT` checks in `server_init.sqf`, `client_init.sqf`,
  `fnc_startup_faction_resolve.sqf` and `fnc_custom_faction_init.sqf` all moved to `*_FactionFile_X`.
  The `== "BLU_F"` default special-case in each init went with it: the token defaults to
  `BLU_F_ARID`, which the registry loop matches on its own.
- The three AutoDetect wrappers guarded the *whole file* on `*_autodetect_faction_init`, which
  pinned the first pick. The guard is now split: the `EntityCreated` retexture handler installs once
  under `*_autodetect_handler_init` and the generation below it re-runs every pass. Guarding
  nothing would have added a second retexture handler per pass; guarding everything ignored the new
  pick. The old flag had no readers once the guard moved, so it is gone.
- `fnc_startup_faction_flow.sqf` clears `selectedFaction_BLU` / `selectedFaction_OPF` network-wide on
  entry, or the server resolves against the previous round's AutoDetect pick before the picker
  republishes this round's.
- `client_init.sqf` re-runs the BLUFOR faction file locally on join, to get the request-menu
  catalogue the schema does not cover — and that run puts the file's own classnames back over the
  role globals. It now calls `fnc_faction_apply_locked` afterwards, which is why that function is
  broadcast and branches its `publicVariable` on `isServer` rather than exiting early off it.

## One schema, not five

The BLUFOR (34 keys) and OPFOR (38 keys) role lists were written out four times:
`fnc_custom_faction_parse.sqf` (`_requiredKeys`), `AUTODETECT_blufor.sqf` (`b_arraysToRandomize`),
and `o_arraysToRandomize` in **both** `AUTODETECT_opfor.sqf` and `AUTODETECT_RANDOM_opfor.sqf` —
plus, implicitly, every file in `factions/MODERN/`. This screen needed the list a fifth time,
grouped and labelled. All four derive from the schema now; they were diffed against it as sets
before being deleted.

`shared/functions/fnc_faction_schema.sqf` becomes the single source. It returns, per side, an
ordered `[key, group, kind]` list:

| Field | Values | Used for |
|---|---|---|
| `key` | full global name, e.g. `blufor_SOLDIER_AR_X` | the row, the required-key check, the pool publish |
| `group` | `INFANTRY` / `VEHICLES` / `STATIC` / `OPERATORS` | section headers, and section alignment across the two columns |
| `kind` | `man` / `vehicle` / `static` | filters the class dropdown in the key editor |

The four existing lists are derived from it. Adding the schema function without collapsing them
would have left five copies of one fact.

The sides are **not symmetric** — different key counts and different names for the same role
(`blufor_SOLDIER_LAT_X` against `opfor_LAT_SOLDIER_X`; OPFOR carries four truck roles and one turret,
BLUFOR carries four turrets and a boat). Rows therefore cannot pair one-to-one. Sections align
instead: each section is `max(BLUFOR count, OPFOR count)` rows tall and the shorter side pads with
blanks, so `OPERATORS` starts on the same line in both columns.

| Section | BLUFOR | OPFOR | Rows |
|---|---|---|---|
| Infantry | 9 | 14 | 14 |
| Vehicles | 10 | 12 | 12 |
| Static weapons | 4 | 1 | 4 |
| Operators | 11 | 11 | 11 |
| | | | 41 + 4 headers |

`blufor_RQST_UNITS` / `blufor_RQST_VEHICLES` are out of the table: they are variable-length ordered
catalogues with no OPFOR counterpart and no `{key}: {class}` shape, which is the same reason
`fnc_custom_faction_parse` excludes them from its required set. A footer line says the request menu
is generated separately, so their absence does not read as a missing key.

## Screen 1 — confirmation

Same envelope and palette as the screens either side of it (`campaign_menu.hpp`,
`custom_faction.hpp`): a green `{0.2, 0.4, 0.2, 1}` panel under a translucent black
`{0, 0, 0, 0.3}` inner panel, a titled `RscFrame` over both, 40 x 28 GUI_GRID cells at `x = 0.1,
y = 0.02`. Content stops at 25.5 cells and the buttons sit at 26, matching `startup_dialog2`.

```
+--------------------------------------------------------------------------------------+
| CONFIRM YOUR FACTIONS                                                                |
|                                                                                      |
|   Review the classname each side will field for every role. SELECT swaps a role,     |
|   CLEAR empties it. These are the final faction settings for this campaign.          |
|                                                                                      |
|              BLUFOR (blue)                        OPFOR (red)                        |
|  +--------------------------------------+--------------------------------------+ ^  |
|  | INFANTRY                             | INFANTRY                             | #  |
|  | SOLDIER: B_Soldier_F  [SELECT][CLEAR]| SOLDIER: O_Soldier_F  [SELECT][CLEAR]| #  |
|  | SOLDIER_LAT: B_Soldi. [SELECT][CLEAR]| AA_SOLDIER: O_Soldi.  [SELECT][CLEAR]| |  |
|  | ...                                  | ...                                  | |  |
|  |                                      | OPERATOR: O_Soldier.  [SELECT][CLEAR]| |  |
|  |                                      |     (BLUFOR side padded blank)       | |  |
|  | VEHICLES                             | VEHICLES                             | |  |
|  | BOAT_ARMED: B_Boat_A. [SELECT][CLEAR]| ARMED_CAR1: O_MRAP_0. [SELECT][CLEAR]| |  |
|  | ...                                  | ...                                  | |  |
|  | STATIC                               | STATIC                               | |  |
|  | TURRET_AA: B_static_. [SELECT][CLEAR]| TURRET_HMG: O_HMG_01. [SELECT][CLEAR]| |  |
|  | TURRET_AT: -- MISSING --  [SELECT]   |     (OPFOR side padded blank)        | |  |
|  | ...                                  |                                      | |  |
|  | OPERATORS                            | OPERATORS                            | |  |
|  | SPECOPS: B_recon_F    [SELECT][CLEAR]| SPECOPS: O_recon_F    [SELECT][CLEAR]| v  |
|  +--------------------------------------+--------------------------------------+    |
|   Request-menu units and vehicles are generated separately and are not listed here.  |
|                                                                                      |
|        [ BACK ]                                              [ CONTINUE ]            |
+--------------------------------------------------------------------------------------+
```

**One scroll container, not two.** Both columns live inside a single `RscControlsGroup`; its one
scrollbar moves both halves together, which is what "scroll both sides at the same time" needs, and
it needs no scroll-position syncing between two controls. `defines.hpp` has the `CT_CONTROLS_GROUP`
constant but no `RscControlsGroup` class — one has to be added, with a `VScrollbar`/`HScrollbar`
pair, alongside the existing base classes.

The `BLUFOR` / `OPFOR` captions sit *above* the group so they stay put while rows scroll. They take
the colours the faction dropdowns already use for the two sides (`fnc_HQ_faction_dialog.sqf:54,94`):
blue `[0.2, 0.5, 1, 1]`, red `[1, 0.2, 0.2, 1]`.

### Row geometry

Cells are GUI_GRID units inside the group. Group inner width 37.6 after the scrollbar; each side
gets 18.6 with a 0.4 gutter.

| Control | x (block-relative) | w | Notes |
|---|---|---|---|
| `KEY: class` label | 0 | 12.6 | `RscText`, one string, tooltip carries the untruncated form |
| `[SELECT]` | 12.8 | 3.2 | `RscButton` |
| `[CLEAR]` | 16.2 | 2.0 | `RscButton`, disabled when the key is already empty |

BLUFOR block at x 0.2, OPFOR block at x 18.9. Row pitch 1.0 cell; the group viewport is 19.4 cells
against 45 cells of content, so a little under half the table is visible at once.

`fnc_faction_confirm_rows.sqf` re-declares `GUI_GRID_W`/`GUI_GRID_H` at the top. `defines.hpp` is a
config, not SQF, so it cannot be included there — and the rows have to land on the same grid as the
dialog around them.

**Long classnames truncate, and that is accepted.** 12.8 cells is ~0.32 screen width, about 27
characters at `sizeEx` 0.025; `APC_PATROL1: B_APC_Wheeled_01_cannon_F` is 38. The prefix
(`blufor_`/`opfor_`) and the `_X` suffix are stripped from the label — the column heading already
says which side, and the suffix carries nothing — so most rows fit. The rest cut off, with the row
tooltip carrying the untruncated classname and its `displayName`. Shrinking the font to fit the
worst case would cost every row's legibility for the sake of a handful, and the panel is already
full screen width.

An empty key renders `KEY: -- MISSING --` in red and greys its `[CLEAR]`.

Roughly 265 controls get created (41 rows x 2 sides x 3, plus headers and chrome). The display is
built once and kept in `uiNamespace`, the way `fnc_factionSelector` keeps `DUWS_factionSelectDisplay`,
so a Back/forward round trip repaints values rather than rebuilding.

## Screen 2 — key editor

Reached from any `[SELECT]`. Takes the shape of the AutoDetect picker
(`fn_factionAutoDetect.sqf:696-754`): green backdrop, translucent inner panel, `editorPreview`
picture, red action button.

```
+--------------------------------------------------------+
| SET ROLE -- BLUFOR / SOLDIER_AR                        |
|                                                        |
|   Faction  [ NATO - Arma 3                        |v]  |
|   Class    [ B_soldier_AR_F                       |v]  |
|                                                        |
|   +------------------------------------------------+   |
|   |                                                |   |
|   |            (editorPreview image, or            |   |
|   |             NO PREVIEW caption in red)         |   |
|   |                                                |   |
|   +------------------------------------------------+   |
|                                                        |
|   Autorifleman  --  B_soldier_AR_F                     |
|   Variety pool: 6 classes from this faction's AR role  |
|                                                        |
|        [ CANCEL ]                    [ CONFIRM ]       |
+--------------------------------------------------------+
```

The faction combo is filled from `fnc_getAllFactionsClean`, run for both the ordinary and the zombie
list and concatenated — that function's `_wantZombies` flag returns one set or the other, and here
nothing should be unreachable. The class combo lists that faction's `CfgVehicles` entries filtered
to the row's `kind`, so an infantry role does not offer tanks. The preview and the `NO PREVIEW`
fallback reuse the picker's `LBSelChanged` behaviour, including its habit of picking only among
classes that actually have a preview image.

### Confirming keeps the variety

A role global may hold a single classname (static faction files) or an **array** — a pool that
`fnc_faction_pick` draws from at each spawn, which is how AutoDetect gives a faction more than one
APC. Collapsing that to the one class the player clicked would throw away the variety AutoDetect
exists to produce.

So CONFIRM does not write a bare classname. It runs `fnc_parseFaction` on the chosen faction
(cached in `uiNamespace` per faction — the parse walks the whole faction's `CfgVehicles` and is far
too expensive to repeat per click), finds which role bucket the picked class falls in, and writes
that bucket with the picked class moved to the front. `fnc_faction_pools_publish` then takes the
first entry as the representative, so the player's explicit pick is what the row shows and what
every single-value reader gets, while the rest of the bucket stays available to `fnc_faction_pick`.
A class in no bucket writes a one-entry pool, which is the honest result.

The row shows the representative with the pool size appended: `SOLDIER_AR: B_soldier_AR_F (+5)`.

## Screens 3 and 4 — the two prompts

Both are **overlay controls on the confirmation dialog**, not dialogs of their own. Stacking a
second dialog over the screen would leave the row buttons behind the prompt still live to the mouse;
raising a prompt instead greys the group and the two footer buttons and drops a sheet over the
table, so the only live controls are the prompt's own. They are declared last in `class controls`,
because declaration order is draw order, and start hidden.

### Clear warning

```
+----------------------------------------------------+
| CLEAR ROLE                                         |
|                                                    |
|   Are you sure you want to clear the key?          |
|   A missing key may cause issues.                  |
|                                                    |
|        [ CANCEL ]                  [ CLEAR ]       |
+----------------------------------------------------+
```

### Continue confirmation

It appears on every Continue; the warning appears only when at least one key on either side is
empty. Both lines live in one structured-text control, because a second control would leave a gap
on the screens that omit the warning.

```
+----------------------------------------------------+
| LOCK IN FACTIONS                                   |
|                                                    |
|   Continue? This action will lock in your          |
|   factions.                                        |
|                                                    |
|   Warning: You are missing keys. A missing key     |
|   may cause issues.                       (red)    |
|                                                    |
|        [ CANCEL ]                [ CONTINUE ]      |
+----------------------------------------------------+
```

Missing keys do not block Continue. The mission already tolerates them at the edges — every spawner
reads a global that may be nil, and `fnc_custom_faction_parse` reports rather than refuses — so the
warning is the whole of the enforcement.

## Data flow

| Global | Written by | Read by |
|---|---|---|
| `duws_faction_preview_request` | confirm screen, on open (incremented) | server, to resolve for this round |
| `duws_faction_preview_ready` | server, after resolving | confirm screen; doubles as the server's served marker |
| `duws_faction_locked` | confirm screen, on Continue | server at commit, and each client after its own faction-file re-run |
| `BLUFOR_FactionFile_X` / `OPFOR_FactionFile_X` | faction dropdown | faction init, and every `CUSTOM`/`AUTODETECT` check |

`duws_faction_locked` is `[[side, [[key, value], ...]], ...]` and carries the whole table, not just
the edits — the server then has one code path (apply the map) rather than a diff to reconcile.

Locality: the confirm screen inherits `fnc_startup_faction_flow`'s, which `client_init.sqf:82` gates
on `game_master`. One machine builds it; on a dedicated server that is the admin, the same machine
`fnc_factionSelector` is already routed to.

## Files

| File | Change |
|---|---|
| `shared/functions/fnc_faction_schema.sqf` | new; the key/group/kind table for both sides |
| `shared/includes/faction_confirm.hpp` | new; the confirmation screen (prompts included) and the key editor |
| `shared/includes/defines.hpp` | `RscControlsGroup` and its scrollbar classes |
| `client/dialog/fnc_faction_confirm.sqf` | new; requests resolution, snapshots the table, drives the screen |
| `client/dialog/fnc_faction_confirm_rows.sqf` | new; section-aligned rows into the scroll group |
| `client/dialog/fnc_faction_row_paint.sqf` | new; one row's text, colour, tooltip and CLEAR state |
| `client/dialog/fnc_faction_prompts.sqf` | new; both prompts plus the clear and Continue handlers |
| `client/dialog/fnc_faction_key_edit.sqf` | new; the key editor screen |
| `client/dialog/fnc_faction_key_apply.sqf` | new; the bucket lookup that rebuilds the pool on confirm |
| `server/warcom/fnc_faction_apply_locked.sqf` | new; applies the locked table, server and client |
| `client/dialog/fnc_startup_faction_flow.sqf` | calls the screen; clears `selectedFaction_*` on re-entry |
| `client/dialog/fnc_HQ_faction_dialog.sqf` | the combos write `*_FactionFile_X` |
| `client/dialog/fnc_startup_faction_resolve.sqf` | switches on `*_FactionFile_X` |
| `client/client_init.sqf` | re-applies the locked table after the JIP faction-file run |
| `client/dialog/fnc_callsign_confirm.sqf` | setup snapshot logs both faction globals |
| `server/server_init.sqf` | resolve loop split from the commit gate; squad init after the apply |
| `server/server_var_init.sqf` | handshake counters, locked table, `*_FactionFile_X` defaults |
| `server/server_fnc_init.sqf` | compiles and broadcasts the new functions |
| `server/init_hq/fnc_BLUFOR_faction_init.sqf`, `server/warcom/fnc_OPFOR_faction_init.sqf` | read the token, survive re-entry |
| `server/dialog/fnc_custom_faction_init.sqf` | `CUSTOM` check reads the token |
| `shared/factions/MODERN/AUTODETECT_{blufor,opfor,RANDOM_opfor}.sqf` | schema-derived lists; handler guard split from the generation |
| `shared/functions/fnc_custom_faction_parse.sqf` | `_requiredKeys` from the schema |
| `description.ext` | includes `faction_confirm.hpp` |
| `stringtable.xml` | new English keys (DE/ES/ZH lag by convention) |

## Constraints worth knowing

- Faction resolution now runs once per pass through the setup screens, and again as an apply at the
  commit. Anything added to those paths has to stay idempotent.
- The confirm screen must not open before `Factions_Available_*_X` exist; those come from
  `fnc_factions_check_modern.sqf` on the server, and the screen is downstream of a dialog that
  already reads them, so the ordering holds as long as the screen stays inside
  `fnc_startup_faction_flow`.
- The zombie game mode forces OPFOR to an AutoDetect row (`fnc_HQ_faction_dialog.sqf`). Its keys
  resolve and display like any other, but a player who edits them can put a non-zombie unit into a
  zombie campaign; that is theirs to do, and no different from the paste path.
- Roughly 265 controls are created for the table. It is built once per visit to the screen; if that
  cost ever shows, the fallback is to create only the visible rows and repaint on scroll.
