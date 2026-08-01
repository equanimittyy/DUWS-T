# Dead code knowingly left in place

A sweep of all `.sqf` under `src/duws/` removed the unreferenced functions, globals, locals and
control flow it found. Three things were left, each for a reason that would otherwise be
rediscovered and re-proposed. Nothing else under `src/duws/` is known-dead.

Two SQF properties decide what a scan of this kind can conclude, and both are recorded in
[`arma_engine_gotchas.md`](arma_engine_gotchas.md): identifiers are case-insensitive, so a
case-sensitive search reports a variable as write-only when the read merely spells it differently;
and a `call`ed block reads the locals of its caller, so a variable unused in its own file can still
be consumed through a `call`.

## The support in-use flags are redundant, not a missing guard

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

## The kndr marker pack is vendored

`client/misc/fnc_kndr_unit_markers.sqf` is a third-party pack that sits in the DUWS tree rather
than under `src/modules/`. Four of its public functions are never called —
`kndr_setMarkerUpdateDelay`, `kndr_getMarkerUpdateDelay`, `kndr_disableShow`, `kndr_setMarkerText`
— and it carries an `if (true) exitWith {}` loop-break idiom. `kndr_assignMarker` and
`kndr_removeMarker` are live, driven by the MHQ deploy, undeploy and release paths.

Trimming a vendored API is a different decision from trimming DUWS code, and none of it costs
runtime, so the file is left whole. It has already diverged from upstream — it calls `fnc_log` —
so the argument for keeping it re-syncable is weaker than it looks; the argument for not editing
someone else's published surface is not.

## The domination briefing bypasses its own translated string

`server/missions/mission_threads/domination/fnc_domination_mission.sqf` hints the hardcoded English
literal `"Armor Hunting"` for its briefing. Every other mission thread shows a localised
`_markerText2` through `[_markerText2,{hint _this}] remoteExec [...]`, and domination's key
`STR_DUWS_T_c13` exists and is translated in `src/stringtable.xml`.

The unused `_markerText2` local that pointed at this went with the rest of the dead code. The
hardcoded line is a live defect rather than dead code, and is recorded here only so the finding
stays attached to the sweep that turned it up. Fixing it is a one-line substitution.
