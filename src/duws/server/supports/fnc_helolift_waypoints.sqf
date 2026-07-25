// Locality: server only (remoteExec target 2). Callers: client/supports/fnc_helolift.sqf.
// Every flight-control command here -- addWaypoint, deleteWaypoint, flyInHeight -- is only
// honoured on the machine the group is local to, which fnc_helolift_spawnHeli makes the
// server. The client drives the lift but must route all of them through here.
// Waypoint completion is reported back by setting a broadcast variable the caller waits on;
// remoteExec returns nothing, so there is no other way to tell it the leg finished.
params ["_caller", "_mode", "_params"];
if (!isServer) exitWith {};

private _playerUID = getPlayerUID _caller;
private _varPrefix = format ["LiftTask_%1", _playerUID];
private _helo = missionNamespace getVariable [_varPrefix + "_helo", objNull];
if (isNull _helo) exitWith {};

if (_mode == "height") exitWith {
    _params params ["_height"];
    _helo flyInHeight _height;
};

private _heloGroup = group (currentPilot _helo);
if (isNull _heloGroup) exitWith {};

private _clear = { while {count (waypoints _heloGroup) > 0} do { deleteWaypoint ((waypoints _heloGroup) select 0) }; };

switch (_mode) do {
    case "clear": { call _clear };
    case "setInitial": {
        _params params ["_targetVehicle"];
        call _clear;
        private _targetPos = getPos _targetVehicle;
        // Stand off 70 m on the helo's own side of the target so the approach is a straight
        // run-in rather than a hover-turn directly over the vehicle it is about to sling.
        private _wp = _heloGroup addWaypoint [_targetPos getPos [-70, _targetPos getDir _helo], 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 5;
        _wp setWaypointBehaviour "CARELESS";
        _wp setWaypointStatements ["true",
            format ["missionNamespace setVariable ['LiftTask_%1_moveCompleted', true, true];", _playerUID]];
    };
    case "setRoute": {
        _params params ["_waypoints"];
        call _clear;
        private _finalClickPos = _waypoints select 2;
        _waypoints set [2, _finalClickPos getPos [-70, _finalClickPos getDir (getPos _helo)]];
        {
            private _wp = _heloGroup addWaypoint [_x, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointCompletionRadius 5;
            _wp setWaypointBehaviour "CARELESS";
            if (_forEachIndex == (count _waypoints - 1)) then {
                _wp setWaypointStatements ["true",
                    format ["missionNamespace setVariable ['LiftTask_%1_finalReached', true, true];", _playerUID]];
            };
        } forEach _waypoints;
    };
    case "depart": {
        call _clear;
        private _worldCenter = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
        _worldCenter set [2, 200];
        _heloGroup addWaypoint [_worldCenter, 0];
        [_helo, _heloGroup, _varPrefix] spawn {
            params ["_helo", "_heloGroup", "_varPrefix"];
            sleep 210;
            if (!isNull _helo) then {
                { ropeDestroy _x } forEach (_helo getVariable ["attachedRopes", []]);
                if (!isNull _heloGroup) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _heloGroup;
                };
                deleteVehicle _helo;
            };
            { missionNamespace setVariable [_varPrefix + _x, nil, true]; }
                forEach ["_helo", "_heloGroup", "_heloReady", "_ropesTight", "_moveCompleted", "_finalReached"];
        };
    };
};
