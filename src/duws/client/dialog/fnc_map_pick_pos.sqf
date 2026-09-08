// Locality: client. Hold the open map, wait on a click, return the picked position [x,y,z], or [] if
// the player cancelled by closing the map. Must run in a scheduled environment (it waitUntils), so
// callers reach it from inside a spawn.
//   _prompt     structured-text banner shown while the map is open (drawn by fnc_map_prompt).
//   _validate   code taking the clicked position as _this, returning bool; false rejects the click and
//               re-prompts. Default accepts any click.
//   _rejectLine text appended to the banner in red on a rejected click.
//
// _validate must read globals only, never caller locals: SQF blocks are not closures and scope is
// dynamic (docs/info/architecture/arma_engine_gotchas.md, "SQF blocks are not closures"), so a spawn
// anywhere in the call chain would strip the caller's privates from the predicate.
params ["_prompt", ["_validate", {true}], ["_rejectLine", ""]];
if (!hasInterface) exitWith {[]};

// onMapSingleClick runs in missionNamespace and can only write globals, so the clicked position lands
// in a shared scratch pair rather than a local. One pair suffices: a client runs one pick at a time.
DUWS_mapPickClicked = false;
DUWS_mapPickPos = [];

openMap [true, false];
waitUntil { !isNull (findDisplay 12) };
// Banner, not hint: the hint box draws beneath the open map (fnc_map_prompt.sqf).
[_prompt] call fnc_map_prompt;
onMapSingleClick "DUWS_mapPickPos = _pos; DUWS_mapPickClicked = true; onMapSingleClick ''; true";

private _done = false;
while {visibleMap && {!_done}} do {
    waitUntil { DUWS_mapPickClicked || {!visibleMap} };
    if (DUWS_mapPickClicked) then {
        if (DUWS_mapPickPos call _validate) then {
            _done = true;
        } else {
            // The handler self-clears after firing, so a rejected click must re-arm it.
            DUWS_mapPickClicked = false;
            [format ["%1<br/><t color='#ff1111'>%2</t>", _prompt, _rejectLine]] call fnc_map_prompt;
            onMapSingleClick "DUWS_mapPickPos = _pos; DUWS_mapPickClicked = true; onMapSingleClick ''; true";
        };
    };
};

onMapSingleClick "";
[""] call fnc_map_prompt;
if (!_done) exitWith {[]};  // player closed the map to cancel
openMap [false, false];

DUWS_mapPickPos
