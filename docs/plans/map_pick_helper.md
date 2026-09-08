# Shared map-pick helper

## Why

The "click a point on the open map, hand the position to the server" flow is inlined four
times, each a near-identical copy of the same loop:

- `src/duws/client/dialog/fnc_depot_retrieve_map.sqf` — retrieve a stored vehicle to a chosen
  spot, validated against the HQ ring.
- `src/duws/client/debug/fnc_debug_hardpoint_menu.sqf` — place a dev hardpoint.
- `src/duws/client/debug/fnc_debug_menu.sqf` — the "recon burst" and "garrison ledger" pickers
  (two copies in this one file).

`fnc_debug_menu.sqf` already labels its own copies "same idiom as the hardpoint placer", so the
duplication is known. Every copy repeats: `openMap` → wait for `findDisplay 12` → draw a banner
with `fnc_map_prompt` → arm a self-clearing `onMapSingleClick` → `waitUntil` clicked-or-map-closed
→ clear the handler and banner → act on the position (or bail on cancel). Only the depot copy adds
a validate-and-re-prompt loop.

A depot-only helper would be single-use and not worth extracting; routing the three debug pickers
through it as well gives four real callers, so the helper earns its place.

## The helper

New file `src/duws/client/dialog/fnc_map_pick_pos.sqf`, registered beside `fnc_map_prompt` at
`src/duws/server/server_fnc_init.sqf:489` (compile + `publicVariable`, so it resolves on every
client — the broadcast lint enforces this for any client-called registry entry).

Signature:

```
// Returns the picked position [x,y,z], or [] if the player cancelled by closing the map.
//   _prompt     structured-text banner shown while the map is open.
//   _validate   code taking the clicked _pos as _this, returning bool; false rejects the click and
//               re-prompts. Default {true} accepts any click.
//   _rejectLine text appended to the banner in red on a rejected click (only used when _validate
//               can reject).
params ["_prompt", ["_validate", {true}], ["_rejectLine", ""]];
```

Body (consolidating the existing copies):

- `if (!hasInterface) exitWith {[]};`
- Reset one shared scratch pair of globals — `onMapSingleClick` runs in `missionNamespace` and can
  only write globals, so the click position must land in a global, not a local.
- `openMap [true, false]; waitUntil { !isNull (findDisplay 12) };`
- Draw `_prompt`; arm `onMapSingleClick "<scratch> = _pos; <flag> = true; onMapSingleClick ''; true"`.
- Loop `while {visibleMap && {!_done}}`: on a click, run `<scratch> call _validate`; if it passes,
  keep the position and finish; if it fails, re-draw the banner with `_rejectLine` in red and re-arm
  the handler (it self-clears after each fire).
- Clear the handler and banner. Close the map only on success (a cancel means the player already
  closed it). Return the position, or `[]` on cancel.

### Predicate scoping caveat

SQF blocks are not closures; scope is dynamic (`docs/info/architecture/arma_engine_gotchas.md`,
"SQF blocks are not closures"). A predicate `call`ed from inside the helper *can* see the caller's
private variables only while the whole chain is `call` — a `spawn` anywhere breaks it. To stay
robust, predicates must read **globals only**, not caller locals. The depot predicate already does:
`{(_this distance2D PosOfBLUHQ) <= (missionNamespace getVariable ["DUWS_base_keep_radius", 250])}`.

## Callers after extraction

Depot (`fnc_depot_retrieve_map.sqf`) keeps its selection read and `closeDialog`, then:

```
private _pos = [_prompt, {(_this distance2D PosOfBLUHQ) <= (missionNamespace getVariable ["DUWS_base_keep_radius", 250])}, localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"] call fnc_map_pick_pos;
if (_pos isEqualTo []) exitWith {};
[player, _index, _pos] remoteExec ["fnc_garage_retrieve_map", 2];
```

The three debug pickers pass no validate and no reject line, then flatten and hand off as they do
now:

```
private _pos = ["<their banner>"] call fnc_map_pick_pos;
if (_pos isEqualTo []) exitWith {};
[[_pos select 0, _pos select 1, 0]] remoteExec ["<their server fn>", 2];
hint "<their confirmation>";
```

Their per-picker scratch globals (`DUWS_dbgHPpos`, `DUWS_dbgReconPos`, `DUWS_dbgGarrPos`, and the
matching `*clicked` flags) are removed in favour of the helper's shared pair — only one pick runs at
a time per client, so one pair suffices.

## Deferred: HQ manual placement

`src/duws/client/dialog/fnc_HQ_manual_place.sqf` is left inlined. Its post-click work is not a plain
"return the position": it clears foliage server-side, runs `BIS_fnc_findSafePos`, rejects spots on
or beside a road, and hands off to `fnc_HQ_placement_finish`, all inside the click loop. Folding it
would force optional post-click hooks into the helper and touch the mission boot flow. Revisit only
if a second placement caller needs the same post-processing.

## Verification

- `bash tests/run.sh` — the syntax, paths and broadcast lints must stay green; the broadcast lint
  will fail if the new registry entry is not `publicVariable`'d.
- No unit test: the flow depends on `findDisplay 12` and `onMapSingleClick`, which sqf-vm does not
  provide. Verify in game — one valid pick, one out-of-ring pick (depot only, expect the red
  re-prompt), and one cancel by closing the map — for the depot and each debug picker.

## Risk

Low. The change is a mechanical consolidation of code that already exists and behaves identically;
the only behavioural surface is the shared scratch globals replacing per-caller ones, which is safe
because picks do not overlap.
