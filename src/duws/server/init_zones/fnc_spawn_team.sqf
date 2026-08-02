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

// _strength is attrition, and only a caller whose token escapes the composition thin passes it: the
// fortification tokens wear down inside themselves rather than by being dropped, and everything else
// was already thinned as a list before it reached here. Thinning both ways would halve twice.
params ["_team", "_center", "_radius", ["_strength", 1]];

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
    case "digin": {
        // Scattered on a ring before taskDefend rather than left to walk apart. Zones stream in, so
        // a garrison spawns while BLUFOR are already close enough to watch it happen: on one point
        // it reads as a clump appearing out of nothing and then filing outward, and a defence
        // stacked on the centre is one the player can fight from a single angle. Spread wide, they
        // have to be dug out.
        //
        // findEmptyPosition rather than BIS_fnc_findSafePos: this runs once per unit on the frame
        // budget of a player arriving, and the safe-pos search is the expensive one. The ring does
        // the spreading; the lookup only keeps a body out of a wall, and falls back to the ring
        // point it was given.
        {
            private _ring = _center getPos [40 + random 110, random 360];
            private _spot = _ring findEmptyPosition [0, 15, typeOf _x];
            _x setPos ([_spot, _ring] select (_spot isEqualTo []));
        } forEach units _group;
        // Radius passed rather than defaulted: taskDefend defends 50 m unless told otherwise and
        // treats anyone outside that as out of position, so it would walk the ring back onto the
        // centre and undo the spread above. It has to describe the same ground just placed on.
        [_group, _center, 150] call bis_fnc_taskDefend;
    };
    // "none" and anything unrecognised: the caller places the group and gives it orders itself.
};

_group
