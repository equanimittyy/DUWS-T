// Locality: server -- waypoints are ignored unless the group is local.
/*
    Gives a freshly spawned crowd something to do: every civilian walks the roadside near where it
    spawned, out along one side of the street and back along the other. With no road in reach, a
    civilian walks a short circuit on open ground instead. Params: [_groups, _buildings].
*/
if (!isServer) exitWith {};

// How far a walker's circuit reaches from where it spawned. Wide enough that two neighbours do
// not trace the same path, short enough to keep the crowd in the cluster the spawn packed it
// into -- waypoints drawn across the whole town are what had civilians jogging between postcodes.
#define ROAM_RADIUS 60
#define ROAD_REACH 100
#define ROUTE_LENGTH 150

params ["_groups", "_buildings"];

_buildings = _buildings select {!isNull _x && {_x isKindOf "Building"}};

// Water is rejected because a coastal town would otherwise walk someone into the sea.
private _fnc_strollPos = {
    params ["_origin"];
    private _pos = _origin;
    for "_i" from 1 to 6 do {
        private _try = _origin getPos [10 + random (ROAM_RADIUS - 10), random 360];
        if (!surfaceIsWater _try) exitWith { _pos = _try };
    };
    _pos
};

// One waypoint per segment: the foot pathfinder takes the shortest line, so sparse ones cut through
// yards. The side is relative to travel, so the reversed leg walks the far side of the street.
private _fnc_verge = {
    params ["_leg", "_side"];
    private _points = [];
    {
        private _dir = if (_forEachIndex < count _leg - 1) then {
            _x getDir (_leg select (_forEachIndex + 1))
        } else {
            (_leg select (_forEachIndex - 1)) getDir _x
        };
        private _c = getPosATL _x;
        private _w = _c getPos [((getRoadInfo _x) select 1) / 2, _dir + _side];
        // Knee height clears a kerb but not a garden wall.
        private _hit = lineIntersectsSurfaces [AGLToASL [_c select 0, _c select 1, 0.5], AGLToASL [_w select 0, _w select 1, 0.5], objNull, objNull, true, 1, "GEOM"];
        if !(_hit isEqualTo []) then {
            _w = _c getPos [((_c distance2D ((_hit select 0) select 0)) - 1) max 0, _dir + _side];
        };
        if (!surfaceIsWater _w) then { _points pushBack _w };
    } forEach _leg;
    _points
};

// Bridges are left out: a verge point beside the deck is over the valley below it.
private _fnc_roadRoute = {
    params ["_unit"];
    private _here = [getPos _unit, ROAD_REACH] call BIS_fnc_nearestRoad;
    if (isNull _here || {(getRoadInfo _here) select 8}) exitWith { [] };
    private _route = [_here];
    private _walked = 0;
    private _goal = ROUTE_LENGTH / 2 + random ROUTE_LENGTH;
    while { _walked < _goal } do {
        private _next = (roadsConnectedTo _here) select { !(_x in _route) && {!((getRoadInfo _x) select 8)} };
        if (_next isEqualTo []) exitWith {};
        private _step = selectRandom _next;
        _walked = _walked + (_here distance2D _step);
        _route pushBack _step;
        _here = _step;
    };
    if (count _route < 2) exitWith { [] };
    private _side = selectRandom [90, -90];
    private _back = +_route;
    reverse _back;
    ([_route, _side] call _fnc_verge) + ([_back, _side] call _fnc_verge)
};

// Zombies keep the building-to-building hunt; a living town strolls instead, because a walking pace
// is what a living town looks like and does not read as undead.
private _fnc_hunt = {
    params ["_group", "_buildings"];
    if !(_buildings isEqualTo []) then {
        for "_i" from 1 to 2 do {
            private _building = selectRandom _buildings;
            private _positions = [_building] call BIS_fnc_buildingPositions;
            if (count _positions == 0) then { continue };
            private _wp = _group addWaypoint [_building buildingPos (floor random count _positions), 2];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "NORMAL";
            _wp setWaypointBehaviour "STEALTH";
            _wp setWaypointCombatMode "GREEN";
            _wp setWaypointTimeout [60, 90, 120];
            _wp setWaypointCompletionRadius 15;
        };
    };
    private _cycle = _group addWaypoint [getPos leader _group, 2];
    _cycle setWaypointType "CYCLE";
    _cycle setWaypointSpeed "NORMAL";
    _cycle setWaypointBehaviour "STEALTH";
    _cycle setWaypointCombatMode "GREEN";
    _cycle setWaypointCompletionRadius 15;
};

{
    private _group = _x;
    private _unit = leader _group;
    if (isNull _unit) then { continue };

    if (_unit getVariable ["civ_isZombie", false]) then {
        [_group, _buildings] call _fnc_hunt;
        continue;
    };

    // SAFE and LIMITED are what keep a stroll a stroll. SAFE keeps them upright instead of moving
    // tactically, LIMITED is the walk; STEALTH with NORMAL is a crouching sprint, which reads as a
    // panicked crowd before anyone has fired.
    _group setBehaviour "SAFE";
    _group setSpeedMode "LIMITED";

    private _points = [_unit] call _fnc_roadRoute;
    if (_points isEqualTo []) then {
        private _origin = getPos _unit;
        for "_i" from 1 to (2 + floor random 2) do { _points pushBack ([_origin] call _fnc_strollPos) };
    };

    private _first = [];
    {
        private _wp = _group addWaypoint [_x, 0];
        if (_first isEqualTo []) then { _first = _wp };
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "GREEN";
        _wp setWaypointCompletionRadius 3;
    } forEach _points;

    private _cycle = _group addWaypoint [_points select 0, 0];
    _cycle setWaypointType "CYCLE";
    _cycle setWaypointSpeed "LIMITED";
    _cycle setWaypointBehaviour "SAFE";
    _cycle setWaypointCombatMode "GREEN";
    _cycle setWaypointCompletionRadius 3;

    // The call-over and the panic delete the old circuit, which leaves the group's waypoint index
    // where it was, so a shorter new circuit starts past its own end and the civilian stands.
    _group setCurrentWaypoint _first;

    // The call-over ends on a doStop so the civilian stands still to be spoken to, and a stopped
    // unit ignores its group's waypoints until it is given a move of its own -- new orders do not
    // release it. Every civilian is its own group leader, so the stop held the whole circuit and
    // anyone the player talked to stood where the conversation ended. Harmless on the fill path,
    // where the first leg is where they were headed anyway.
    _unit doMove (waypointPosition _first);
} forEach _groups;
