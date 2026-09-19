// Locality: server. One tick of a civilian side mission's thread: "" to keep going, else the status to end
// with. Readiness is its own flag, never the state, so a tick cannot overwrite a report or a cancel.
params ["_id"];
private _e = DUWS_civMissions get _id;
private _giver = _e get "giver";
(_e get "giverMarker") setMarkerPos (getPosATL _giver);
private _state = _e get "state";
if (_state == "reported") exitWith { "SUCCEEDED" };
if (_state == "canceled") exitWith { "CANCELED" };
if (!alive _giver || {[_e] call (_e get "lost")}) exitWith { "FAILED" };

private _ready = [_e] call (_e get "won");
if (_ready isNotEqualTo (_e get "ready")) then {
    _e set ["ready", _ready];
    _giver setVariable ["DUWS_civMission_state", ["active", "ready"] select _ready, true];
};

if (!(_e get "announced") && {({ alive _x } count units (_e get "group")) == 0}) then {
    _e set ["announced", true];
    [_e get "taskId", [(getPosATL _giver) select 0, (getPosATL _giver) select 1]] call BIS_fnc_taskSetDestination;
    ["TaskUpdated", ["", _e get "title"]] remoteExec ["BIS_fnc_showNotification", [0, -2] select isDedicated];
};
""
