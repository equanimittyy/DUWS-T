# Arma engine gotchas

Engine behaviours that aren't visible in the SQF itself and cost real debugging time.
Each entry states the rule, why the engine forces it, and how to apply it. Add an entry
when an Arma-specific trap — not a plain SQF bug — burns a debugging session. For where
the mission's subsystems live see [`architecture.md`](architecture.md).

## Non-serializable handles must not live in the mission namespace

**Never store a `DISPLAY`, `CONTROL`, `SCRIPT`, `LOCATION`, or other handle type in a
`missionNamespace` global. Keep UI handles in `uiNamespace`.**

The mission namespace is written into save games, so every global in it must have a
serialized form. Handle types don't, so the engine rejects the write with *"Variable X
does not support serialization and should not be stored in the mission namespace"* —
raised when the global is assigned or at the next save. Booleans, numbers, strings, and
arrays of those serialize fine.

`disableSerialization` does **not** grant an exception. It only tells the engine to skip
serializing a script's **local** (`_underscore`) variables and to not save mid-script; a
value written into a persistent namespace is still checked.

**How to apply:** keep display/control references (open-dialog handles, cached controls)
in `uiNamespace`, which is never saved and is the engine's intended home for UI state.
Read with a default and null-check — `isNull (uiNamespace getVariable ["myDisplay",
displayNull])` — which also detects a dialog closed elsewhere. The faction selector holds
its reused dialog handle this way, in `fnc_factionSelector`
(`src/duws/factions/MODERN/fn_factionAutoDetect.sqf`).

## `exitWith` exits the nearest loop or call scope, not the enclosing if/then

**Inside a loop, `if (cond) exitWith {...}` terminates the whole loop — even when the
`exitWith` is nested several `if/then` blocks deep. `if/then`/`switch` blocks are
transparent to it.**

`exitWith` unwinds to the nearest enclosing scope created by a loop (`while`, `for`,
`forEach`, `count`) or by `call`/`spawn`/`execVM`; the standard `if (done) exitWith {}`
break relies on exactly this. The trap is writing `if (a) then { if (b) exitWith {...} }`
expecting the `exitWith` to abandon only the inner block and let the loop keep iterating —
it does not, it exits the loop. A loop that was meant to retry then silently runs once and
quits.

**How to apply:** to skip-and-retry the current iteration use `continue` (or let control
fall off the end of the loop body); reserve `exitWith` for when you genuinely want the loop
to stop. The zone locator hit this: an origin keep-out used `exitWith` to "re-roll" a
position but instead dropped the zone entirely — see
[`zone_and_town_generation.md`](zone_and_town_generation.md#defects-subsystem-a).

## Structured-text controls need a parsed object, not `ctrlSetText`

**Set a `CT_STRUCTURED_TEXT` (type 13 / `RscStructuredText`) control with
`ctrlSetStructuredText (parseText "<t ...>...</t>")`, never `ctrlSetText`.**

`ctrlSetText` on a structured-text control stores the string verbatim, so `<t>` markup
renders as literal on-screen text — and it fails silently, with no error to point at the
cause (the wasted time goes into suspecting a missing class definition instead). Only
`parseText` turns the markup into the structured-text object the control draws.

**How to apply:** `_ctrl ctrlSetStructuredText (parseText _markup)` to set, `parseText ""`
to clear. The faction selector's "no units" caption uses this, in `fnc_factionSelector`
(`src/duws/factions/MODERN/fn_factionAutoDetect.sqf`).

## Duplicate `<Key ID>` in stringtable.xml resolve to one definition, silently

**`src/stringtable.xml` repeats several `STR_` IDs. The engine loads the table without
error and keeps only one definition per ID; the other copies are dead. Editing a dead
copy changes nothing in-game, and reordering keys can flip which copy wins.**

The table is split into `<Container>` sections purely for navigation — IDs resolve
globally across all containers, so which duplicate the engine keeps is decided by file
order, not by section. Nine IDs are currently duplicated; most pairs are identical (or
differ only in tag order), but `STR_DUWS_T_FAST_TRAVEL_BUSY` has two genuinely different
English strings ("You are already placing a waypoint." vs "The map is already opening,
please wait...") — a latent collision where one string never displays.

**How to apply:** treat any reordering or removal of a duplicate key as behaviour-
affecting; keep the duplicate copies byte-identical, or consolidate to one on purpose and
test in-game. When a string edit appears to do nothing, grep for a second `<Key ID>` with
the same ID before assuming the change didn't take.
