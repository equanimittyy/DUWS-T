// Locality: server -- creates civilian vehicles for a town. Called from fnc_civ_handler's fill
// thread, which is server-only.
/*
    Puts civilian cars on a town's roads: a few driving town-to-town, the rest parked. Params:
    [_locIndex, _centerPos, _radius]. Returns nothing.

    Parked cars ride the town's "crowd" roster, so the site poller's empty hook collects them with
    the pedestrians when the town sleeps. A parked car a player gets into leaves that roster and
    costs the town a point of reputation: off the roster the sleep sweep cannot delete a car the
    player drove off, and once abandoned the map cleanup sweep reaps it like any other empty
    vehicle. Driving cars must not ride the roster: they leave for another town, and
    deleting them on their origin town's sleep pops them in front of whoever they drove up to.
    Instead they carry DUWS_binMe -- the map cleanup sweep reaps them only when no player is within
    its keep radius, so one you are following stays and the rest are collected once out of sight.

    Models come from civ_veh_array, auto-detected off the civilian faction the same way combat
    vehicles are (fnc_civ_setup_array). Drivers are full civilians via fnc_civ_spawnUnit, so
    running one down costs reputation exactly as shooting one on foot does; parked cars are empty.
*/
if (!isServer) exitWith {};
params ["_locIndex", "_centerPos", "_radius"];

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

// Cars need a carriageway to sit on and to point along; a town the map drew without roads stays
// pedestrian-only rather than parking vehicles in fields.
private _roads = nearestTerrainObjects [_centerPos, ["MAIN ROAD", "ROAD", "TRACK"], _radius max 150, false, true];
if (_roads isEqualTo []) exitWith {};

private _density = missionNamespace getVariable ["civ_density", 15];
private _nDrive = floor (_density / 5);
private _nPark  = floor (_density / 2);

private _key = [_locIndex] call fnc_town_site_key;
private _roster = [_key, "crowd"] call fnc_site_roster;
private _bodies = missionNamespace getVariable ["civ_array", []];

// Face a car the way its stretch of road runs, taken from the nearest connected node. Falls back
// to the segment's own heading at a dead-end with nothing connected.
private _fnc_roadDir = {
    params ["_road"];
    private _cons = roadsConnectedTo _road;
    if (_cons isEqualTo []) exitWith { getDir _road };
    [getPosATL _road, getPosATL (_cons select 0)] call BIS_fnc_dirTo
};

// "NONE" placement so the car sits where it is put rather than being bounced to the nearest
// clear spot, which on a road is another lane or the verge.
private _fnc_spawnCar = {
    params ["_pos", "_dir"];
    private _veh = createVehicle [selectRandom _pool, _pos, [], 0, "NONE"];
    _veh setDir _dir;
    _veh setPosATL _pos;
    _veh
};

// Parked cars: pulled 3 m off the carriageway centre so a lane stays passable, and skipped where
// one already stands so a short road does not stack them nose to tail. "up to" the target -- a
// town with few road segments parks fewer.
private _parked = 0;
private _tries = 0;
while { _parked < _nPark && _tries < _nPark * 3 } do {
    _tries = _tries + 1;
    private _road = selectRandom _roads;
    private _dir = [_road] call _fnc_roadDir;
    private _pos = (getPosATL _road) getPos [3, _dir + 90];
    if (count (nearestObjects [_pos, ["Car", "Truck"], 4]) > 0) then { continue };
    private _car = [_pos, _dir] call _fnc_spawnCar;
    // Stamped for the EH: its {} does not close over this scope, so town and site key travel on the
    // car. The car is server-local (createVehicle here), so a server-added GetIn fires here when any
    // player takes it. Removed on the first player in, so a passenger after does not charge twice.
    _car setVariable ["DUWS_civCarTown", _locIndex];
    _car setVariable ["DUWS_civCarKey", _key];
    _car addEventHandler ["GetIn", {
        params ["_veh", "", "_unit"];
        if (!isPlayer _unit) exitWith {};
        _veh removeEventHandler ["GetIn", _thisEventHandler];
        [_veh getVariable ["DUWS_civCarKey", ""], _veh, "crowd"] call fnc_site_roster_drop;
        [_veh getVariable ["DUWS_civCarTown", -1], -1, "vehicle_stolen"] call fnc_town_rep_adjust;
    }];
    _roster pushBack _car;
    _parked = _parked + 1;
    // Staggered like the pedestrian fill (this runs in that same scheduled thread): a burst of
    // createVehicle in one frame hitches the server.
    sleep 0.1;
};

// Driving cars: a civilian at the wheel ambling between towns on a cycle. CARELESS so they follow
// the road instead of reacting to the player as a threat; the cap keeps them off the verge.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _ownCentre = _centres param [_locIndex, _centerPos];
for "_i" from 1 to _nDrive do {
    private _road = selectRandom _roads;
    private _dir = [_road] call _fnc_roadDir;
    private _veh = [getPosATL _road, _dir] call _fnc_spawnCar;

    private _driver = [_locIndex, getPosATL _road, selectRandom _bodies, false] call fnc_civ_spawnUnit;
    if (isNull _driver) then { deleteVehicle _veh; continue };
    _driver moveInDriver _veh;

    private _grp = group _driver;
    _grp setBehaviour "CARELESS";
    _grp setSpeedMode "LIMITED";
    _veh limitSpeed 50;

    // Head for another town where the map has one, otherwise loop this town's own roads.
    private _dest = if (count _centres > 1) then { selectRandom (_centres - [_ownCentre]) } else { _ownCentre };
    private _legs = [[_dest, 30], [_ownCentre, 30]];
    {
        _x params ["_wpPos", "_cr"];
        private _wp = _grp addWaypoint [_wpPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "CARELESS";
        _wp setWaypointCompletionRadius _cr;
        _wp setWaypointTimeout [20, 30, 45];
    } forEach _legs;
    private _cyc = _grp addWaypoint [_ownCentre, 0];
    _cyc setWaypointType "CYCLE";
    _cyc setWaypointCompletionRadius 30;

    // Off the roster, onto the cleanup sweep. Flag the driver as well as the car: the sweep clears
    // a vehicle's crew with it, but a driver who bailed on a FiredNear panic is no longer crew.
    _veh setVariable ["DUWS_binMe", true];
    _driver setVariable ["DUWS_binMe", true];
    sleep 0.1;
};
