// Locality: server -- called from the zone spawn band, the town garrison and the mission patrol
// builders, all server-side.
// usage: [token, position, radius, strength, posture] call fnc_spawn_team
// radius: 50 for a patrol inside a base, 500 for medium, 1300 for island
//
// Every OPFOR team is raised here. This replaced four files that differed only in their roster and
// in which of two waypoint blocks they ran, which is why a new team used to mean a new file: a team
// is a row on DUWS_teamRosters now, and the orders it stands up under are fnc_apply_posture's.
//
// Returned rather than only spawned, for the callers that `call` it: the zone band flags what it
// raised so the capture test can tell this zone's garrison from passers-by, and the town garrison
// needs the handle to count its strength and to order it out.

// _strength is attrition, and only a caller whose token escapes the composition thin passes it: the
// fortification tokens wear down inside themselves rather than by being dropped, and everything else
// was already thinned as a list before it reached here. Thinning both ways would halve twice.
//
// _posture defaults to the close patrol every team walked when orders were a column on its roster
// row, so the side-mission callers that name only a team still get what they always got. A token may
// carry its own ("garrison:fortified"), which is what DUWS_fnc_zoneSpawnOne passes.
params ["_team", "_center", "_radius", ["_strength", 1], ["_posture", "closepatrol"]];

// grpNull rather than an empty group: DUWS_fnc_raiseGarrison already drops nulls, and a group with
// no men would sit on the zone roster forever holding the capture test open.
private _row = [_team] call DUWS_fnc_teamRow;
if (_row isEqualTo []) exitWith {
    ["WARN", "ZONES", format ["no team named %1; nothing raised", _team]] call fnc_log;
    grpNull
};

// Not named _roster: callers one frame up use that name for the zone's unit roster.
private _men = [_team, enemyunitMultiplier, _strength] call DUWS_fnc_teamRoster;
private _position = [_center, 50, _radius, 5, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
private _group = [_position, EAST, _men, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

{ [_x] call fnc_addRandomLoot } forEach units _group;

[_group, _posture, _center, _radius] call fnc_apply_posture;

_group
