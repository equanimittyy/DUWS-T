// Locality: server -- mission threads call it directly, and every thread runs server-side.
//
// Finds the ground a side mission is built on, and undoes fnc_mission_begin's entry state when it
// cannot. Returns [] when the caller must abort -- the caller has to exit itself, because neither
// exitWith nor breakOut inside a called function can terminate its caller's scope.
params ["_missionPos", "_radius", "_missionType"];

private _POSdata = [_missionPos, _radius, false, [], 0] call fnc_missionTargetPos;
_POSdata params ["_randomPos", "_Building", "_Posfound", "_targetpos"];

if (_Posfound) exitWith { [_randomPos, _Building, _targetpos] };

// _Posfound alone, not a failsafe threshold: fnc_missionTargetPos loops until it succeeds or
// gives up at its own cap, so it never returns unfound with attempts left. A caller re-testing that
// cap adds a second number describing one boundary -- neither changeable without reading the other,
// and easily set to 10 or 5 against a callee that stops at 50.
[_missionType] call fnc_mission_abort;
[]
