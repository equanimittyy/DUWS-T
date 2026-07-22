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
