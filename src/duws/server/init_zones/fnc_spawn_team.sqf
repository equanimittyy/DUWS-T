// Locality: server -- called from the zone spawn band, the town garrison and the mission patrol
// builders, all server-side.
// usage: [team, position, radius] call fnc_spawn_team
// radius: 50 for a patrol inside a base, 500 for medium, 1300 for island
//
// Every OPFOR team is raised here. This replaced four files that differed only in their roster and
// in which of two waypoint blocks they ran, which is why a new team used to mean a new file: the
// roster and the behaviour are columns on DUWS_teamRosters now, so this reads both.
//
// Returned rather than only spawned, for the callers that `call` it: the zone band flags what it
// raised so the capture test can tell this zone's garrison from passers-by, and the town garrison
// needs the handle to count its strength and to order it out.

params ["_team", "_center", "_radius"];

// grpNull rather than an empty group: DUWS_fnc_raiseGarrison already drops nulls, and a group with
// no men would sit on the zone roster forever holding the capture test open.
private _row = [_team] call DUWS_fnc_teamRow;
if (_row isEqualTo []) exitWith {
    ["WARN", "ZONES", format ["no team named %1; nothing raised", _team]] call fnc_log;
    grpNull
};

// Not named _roster: callers one frame up use that name for the zone's unit roster.
private _men = [_team, enemyunitMultiplier] call DUWS_fnc_teamRoster;
private _position = [_center, 50, _radius, 5, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
private _group = [_position, EAST, _men, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

{ [_x] call fnc_addRandomLoot } forEach units _group;

private _patrolRadius = round (_radius / 1.25);
switch (_row select 1) do {
    case "route": {
        // Engages what it walks into without abandoning the circuit. Set here rather than per
        // waypoint because it is the group's disposition, not one order.
        _group setCombatMode "YELLOW";
        {
            private _wp = if (_x == 3) then {
                // One leg of the circuit ends inside a building rather than on open ground, so a
                // patrol that owns a settlement is actually in it when the player arrives.
                private _here = getPos leader _group;
                private _spot = [(_here select 0) + (random _patrolRadius) - (random _patrolRadius),
                                 (_here select 1) + (random _patrolRadius) - (random _patrolRadius)];
                _group addWaypoint [getPos (nearestBuilding _spot), 0]
            } else {
                private _w = _group addWaypoint [_center, _patrolRadius];
                _w setWaypointCompletionRadius 100;
                _w
            };
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointSpeed "LIMITED";
            // The building leg is a long stay; the open legs are a walk-through.
            _wp setWaypointTimeout ([[60, 120, 180], [300, 450, 600]] select (_x == 3));
        } forEach [1, 2, 3];

        private _cycle = _group addWaypoint [_center, 30];
        _cycle setWaypointType "CYCLE";
        _cycle setWaypointBehaviour "SAFE";
        _cycle setWaypointSpeed "LIMITED";
    };
    case "wander": {
        [_group, _center, _patrolRadius] call bis_fnc_taskPatrol;
    };
    // "none" and anything unrecognised: the caller places the group and gives it orders itself.
};

_group
