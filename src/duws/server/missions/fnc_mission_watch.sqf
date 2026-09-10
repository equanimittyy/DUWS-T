// Locality: server. The shared win/deadline tail for the "hold a predicate before the clock runs out"
// side missions (destroy the target, kill the guard force): poll _done against the mission deadline, then
// end through fnc_mission_finish on the matching branch. _done is the per-mission win test, called with
// _handles as its argument. _winExtra is appended to the SUCCEEDED finish args for the rare thread that
// needs the later fnc_mission_finish slots (notify / _extra / _handles), e.g. a composition sweep on win.

params [
    "_handles", "_done",
    "_mission_name", "_taskId", "_targetpos", "_radius", "_markers", "_winLine",
    ["_compKey", ""], ["_winExtra", []], ["_settle", 5]
];

// Let a just-spawned guard force finish arriving before the first win poll, so a mission is not scored
// won in the instant before its defenders exist.
if (_settle > 0) then { sleep _settle };

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, _markers, [], false, _compKey] call fnc_mission_finish;
};

([_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, _markers, _winLine, true, _compKey] + _winExtra) call fnc_mission_finish;
