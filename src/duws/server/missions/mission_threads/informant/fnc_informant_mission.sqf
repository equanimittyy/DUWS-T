// Locality: server -- callers remoteExec to target 2.
//
// Informant hunt. An OPFOR informant hides disguised among a town's civilians; the player locates and
// kills him before he leaves by car for a distant zone. The site-finder (fnc_informant_site)
// guarantees _MissionPos is a populated Tomata town, so this thread never has to test for one.
//
// Two shapes, chosen by the town's reputation band:
//   friendly/neutral -- the crowd is thickened and every civilian can be asked about the informant
//                       (fnc_informant_ask_addAction, added in the ask-action layer); the player narrows
//                       him down by talking, and has time.
//   enemy            -- no asking; the informant leaves much sooner, so the player camps the
//                       described vehicle and intercepts.
// Both leave early the moment a firefight starts near the informant.
params ["_MissionPos", "_mission_name"];

// Resolve the town this offer sits on. The finder returned a town centre, so the nearest registered
// town to it is that town; civ_town_rep / civ_radii are server-only and this thread is server-side.
private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locs isEqualTo []) exitWith {
    [16, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};
private _townIndex = -1;
private _bestD = 1e9;
{
    private _d = (getPos _x) distance2D _MissionPos;
    if (_d < _bestD) then { _bestD = _d; _townIndex = _forEachIndex };
} forEach _locs;
if (_townIndex < 0) exitWith {
    [16, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};
private _townPos    = getPos (_locs select _townIndex);
private _townRadius = _radii param [_townIndex, 200];

// Enemy town: OPFOR-banded, or holding a garrison the reputation band has not caught up to yet.
private _rep       = [_townIndex] call fnc_civ_repAt;
private _enemyTown = (_rep <= -10) || {([_townIndex] call fnc_town_garrison_tierAt) > 0};

if (!([16, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;

// Leave built on the shared mission-timing shape (10-minute steps of in-game time, the same shape and
// clock the deadline uses): enemy towns give one step, friendly two. TUNABLE steps.
private _leaveSteps = if (_enemyTown) then { 1 } else { 2 };
private _leaveAt = [_leaveSteps] call fnc_time_deadline;
private _clock = [_leaveAt] call fnc_time_clock;

// Escape destination: the nearest OPFOR-held zone at least 1 km off. The informant runs to enemy
// ground, never to a BLUFOR zone or the player's own, so there is no fallback -- the finder guaranteed
// one existed at offer time, and if the last was captured between the offer and now the mission cannot
// run and aborts. zone_namePOS_pairs carries the name; WARCOM_zones_controled_by_OPFOR carries which
// zones are enemy-held, matched by position. TUNABLE distance.
private _MINDIST = 1000;
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _zx  = [];
private _zoneName = "";
private _zxD = 1e9;
{
    _x params ["_zn", "_zp"];
    private _d = _zp distance2D _townPos;
    if (_d >= _MINDIST && _d < _zxD && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        _zxD = _d; _zx = _zp; _zoneName = _zn;
    };
} forEach zone_namePOS_pairs;
if (_zx isEqualTo []) exitWith {
    [16, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

private _townName = text (_locs select _townIndex);

// The compass direction he heads when he leaves, for the civilian "saw him leave" line: the 16-point
// bearing from the town to his destination.
private _compass16 = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
private _leaveDir = _compass16 select (floor (((([_townPos, _zx] call BIS_fnc_dirTo) + 11.25) mod 360) / 22.5));

// The getaway car, and three decoys that scatter when he drives so the described vehicle never points
// at one car. One decoy is guaranteed his class, the other two random, so the description narrows the
// field to at least two identical cars without ever pinning the informant.
private _vehPool = missionNamespace getVariable ["civ_veh_array", []];
if (_vehPool isEqualTo []) then { _vehPool = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F"] };
private _informantClass = selectRandom _vehPool;
private _decoyClasses = [_informantClass, selectRandom _vehPool, selectRandom _vehPool] call BIS_fnc_arrayShuffle;
private _vehName = getText (configFile >> "CfgVehicles" >> _informantClass >> "displayName");

// Objective marker + task on the town. Marked before the crowd is built, since the ellipse is all the
// player has to go on while the spawn runs.
private _radius = _townRadius max 200;
private _markername2 = [_townPos, _radius] call fnc_missionMarkerData;
// Position-based, matching every other mission thread: unique per town and stable, where a
// round-time id collides when two missions are created in the same second.
private _taskID = format ["informant%1%2", round (_townPos select 0), round (_townPos select 1)];
[_taskID, format [localize "STR_DUWS_T_INTEL_INFORMANT_TASK", _zoneName, _clock, _vehName], _mission_name, _townPos, "search"] call fnc_missionTaskCreate;

// Parks a car of a given class on a road point near the town, stripped of the free medkit vanilla
// civilian cars carry, sitting where put rather than bounced to a clear spot.
private _fnc_spawnCar = {
    params ["_class", "_pos", "_dir"];
    private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
    clearItemCargoGlobal _veh; clearMagazineCargoGlobal _veh;
    clearWeaponCargoGlobal _veh; clearBackpackCargoGlobal _veh;
    _veh setDir _dir;
    _veh setPosATL _pos;
    _veh
};

private _roads = nearestTerrainObjects [_townPos, ["MAIN ROAD", "ROAD", "TRACK"], _radius max 200, false, true];
// A road point is usable only if it is clear of the walls, rocks and trees that line an Altis town
// road and of any car already placed: a car dropped onto an occupied point with "NONE" clips the
// object and detonates on spawn, and the car check keeps the four cars off one another's segment.
private _fnc_carClear = {
    params ["_p"];
    (nearestTerrainObjects [_p, ["WALL", "FENCE", "ROCK", "TREE"], 4]) isEqualTo []
    && { (nearestObjects [_p, ["Car"], 7]) isEqualTo [] }
};
private _fnc_carPos = {
    // A clear road point when the town has one, otherwise a safe patch of ground -- a car in a field
    // is still a car to drive off in.
    private _clear = _roads select { [getPosATL _x] call _fnc_carClear };
    if (_clear isEqualTo []) exitWith {
        private _p = [_townPos, 0, _townRadius, 5, 0, 0.3, 0] call BIS_fnc_findSafePos;
        [if (_p isEqualTo [0,0,0]) then { _townPos } else { _p }, random 360]
    };
    private _road = selectRandom _clear;
    // Heading ALONG the road, from the bearing to a connected segment: a road piece's own getDir is
    // frequently 0, which parks the car broadside across the carriageway and blocks it.
    private _cons = roadsConnectedTo _road;
    private _dir = if (_cons isEqualTo []) then { getDir _road } else { _road getDir (_cons select 0) };
    [getPosATL _road, _dir]
};

private _allCars = [];
private _allUnits = [];

// The informant's car first, empty: he is on foot in the crowd and only walks to it when he leaves.
([] call _fnc_carPos) params ["_icp", "_icd"];
private _informantCar = [_informantClass, _icp, _icd] call _fnc_spawnCar;
_allCars pushBack _informantCar;

// Decoy cars, each with a civilian already at the wheel so they can pull away the instant he does.
private _decoys = [];
{
    (call _fnc_carPos) params ["_dp", "_dd"];
    private _dCar = [_x, _dp, _dd] call _fnc_spawnCar;
    private _driver = [_townIndex, _dp, selectRandom (missionNamespace getVariable ["civ_array", []]), false] call fnc_civ_spawnUnit;
    if (!isNull _driver) then {
        _driver moveInDriver _dCar;
        (group _driver) setBehaviour "CARELESS";
        _decoys pushBack _dCar;
        _allCars pushBack _dCar;
        _allUnits pushBack _driver;
    } else {
        deleteVehicle _dCar;
    };
} forEach _decoyClasses;

// The informant: a civilian-model unit in an EAST group, so he reads as a local but counts as OPFOR
// for the kill. Captive and unarmed while he blends; he only arms if forced onto foot (below).
private _civBodies = missionNamespace getVariable ["civ_array", []];
private _informantSpawn = [_townPos, 0, _townRadius, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
if (_informantSpawn isEqualTo [0,0,0]) then { _informantSpawn = _townPos };
private _iGroup = createGroup [EAST, true];
private _informant = _iGroup createUnit [selectRandom _civBodies, _informantSpawn, [], 0, "NONE"];
removeAllWeapons _informant;
_informant setCaptive true;
_informant setBehaviour "SAFE";
_informant setUnitPos "UP";
_allUnits pushBack _informant;

// Killed here so the near-town reputation cost is charged off his death position: a clean kill out on
// the road is free, one in the crowd is not. Nearest town within its edge + 300 m pays -1. TUNABLE.
_informant addEventHandler ["Killed", {
    params ["_unit"];
    _unit setVariable ["DUWS_informant_dead", true];
    private _p = getPosATL _unit;
    private _tl = missionNamespace getVariable ["civ_locations", []];
    private _tr = missionNamespace getVariable ["civ_radii", []];
    private _ti = -1; private _bd = 1e9;
    { private _dd = (getPos _x) distance2D _p; if (_dd < _bd) then { _bd = _dd; _ti = _forEachIndex } } forEach _tl;
    if (_ti >= 0 && {_bd <= (_tr param [_ti, 200]) + 300}) then {
        [_ti, -1, "informant_killed_near_town"] call fnc_town_rep_adjust;
    };
}];

// The informant object stays server-side (the reveal reads it there); DUWS_informant_active is the
// broadcast flag the client-side ask action gates on.
missionNamespace setVariable ["DUWS_informant_unit", _informant];
missionNamespace setVariable ["DUWS_informant_townIndex", _townIndex];
// Read server-side by fnc_informant_ask_reveal: town bounds tell "still here" from "has left", and the
// leave direction is what a local reports once he is gone.
missionNamespace setVariable ["DUWS_informant_townPos", _townPos];
missionNamespace setVariable ["DUWS_informant_townRadius", _townRadius];
missionNamespace setVariable ["DUWS_informant_leaveDir", _leaveDir];
DUWS_informant_active = true;
publicVariable "DUWS_informant_active";

// While he waits he strolls the whole town rather than standing a fixed pin in the crowd: a fresh safe
// point anywhere in the town radius, re-tasked on arrival or after a cap so a blocked path never freezes
// him mid-town. LIMITED so he reads as a local out for a walk. Ends the instant the exfil watcher takes
// over (DUWS_informant_leaving), so this doMove never fights the getaway's waypoints. TUNABLE cap.
[_informant, _townPos, _townRadius] spawn {
    params ["_inf", "_tp", "_tr"];
    (group _inf) setSpeedMode "LIMITED";
    while { alive _inf && !(_inf getVariable ["DUWS_informant_leaving", false]) } do {
        private _dest = [_tp, 0, _tr, 3, 0, 0.35, 0] call BIS_fnc_findSafePos;
        if (_dest isEqualTo [0,0,0]) then { _dest = _tp };
        _inf doMove _dest;
        private _until = diag_tickTime + 90;
        waitUntil {
            sleep 3;
            !alive _inf || (_inf getVariable ["DUWS_informant_leaving", false])
              || (_inf distance2D _dest < 8) || diag_tickTime > _until
        };
    };
};

// Thicken the crowd only where the player can work it -- a friendly/neutral town he can walk. Each
// added civilian is a real town local (same index, so harming one costs the town), gets the ask
// action if that layer is loaded, and wanders on the town's own movement pass rather than standing
// frozen. Spawned two to a group beside each other: a civilian gets its own group, and 16 solo groups
// eat the engine's ~144-per-side cap the town crowd and the decoy drivers also draw on. TUNABLE
// count (pairs x 2).
private _crowd = [];
if (!_enemyTown) then {
    // Re-open every local already in town: a hunt reuses bodies that survived an earlier one on the
    // same town, where DUWS_informant_asked would otherwise still read spent from last time. Fresh
    // and streamed-in bodies default to unspent, so only the ones already here need clearing.
    { _x setVariable ["DUWS_informant_asked", false, true] } forEach
        (allUnits select { (_x getVariable ["civ_locIndex", -1]) == _townIndex });

    private _crowdGroups = [];
    for "_i" from 1 to 8 do {
        private _anchor = [_townPos, 0, _townRadius, 2, 0, 0.35, 0] call BIS_fnc_findSafePos;
        if (_anchor isEqualTo [0,0,0]) then { _anchor = _townPos };
        private _grp = grpNull;
        for "_j" from 0 to 1 do {
            private _cpos = _anchor getPos [_j * 3, random 360];
            private _c = [_townIndex, _cpos, selectRandom _civBodies, false] call fnc_civ_spawnUnit;
            if (!isNull _c) then {
                _crowd pushBack _c;
                _allUnits pushBack _c;
                // Second of the pair joins the first's group; the emptied group deletes itself
                // (fnc_civ_spawnUnit makes them deleteWhenEmpty).
                if (isNull _grp) then { _grp = group _c } else { [_c] joinSilent _grp };
            };
        };
        if (!isNull _grp) then { _crowdGroups pushBack _grp };
    };
    // The town's own walk-and-pose pass, so the added locals move like the rest of the crowd.
    private _townBuildings = (missionNamespace getVariable [format ["civ_buildings_%1", _townIndex], []]) select { !isNull _x };
    [_crowdGroups, _townBuildings] spawn fnc_civ_wp_Tomata;

    // The ask action reaches every town local for the hunt's duration -- the thickening crowd above,
    // the baseline locals, and any that stream in as the player nears the town or after it sleeps and
    // refills. A poll rather than a one-off sweep because the crowd is not all present when the hunt
    // starts: the offer is usually taken from the map, far from the town. The askable flag makes each
    // body a one-time add; the loop ends with the hunt, and the action hides itself once
    // DUWS_informant_active goes false. JIP-keyed on the civilian so a mid-hunt joiner still gets it.
    [_townIndex] spawn {
        params ["_ti"];
        while { missionNamespace getVariable ["DUWS_informant_active", false] } do {
            {
                if !(_x getVariable ["DUWS_informant_askable", false]) then {
                    _x setVariable ["DUWS_informant_askable", true];
                    [_x] remoteExec ["fnc_informant_ask_addAction", 0, _x];
                };
            } forEach (allUnits select { (_x getVariable ["civ_locIndex", -1]) == _ti });
            sleep 5;
        };
    };
};
missionNamespace setVariable ["DUWS_informant_crowd", _crowd];

// Foot flight when there is no car to take. Two independent axes: _armed decides whether he breaks
// cover -- only with his car gone does he drop the disguise, pull a pistol and fight out; a shot
// alone never unmasks him. _run decides pace -- FULL when hurrying (under fire, or car gone),
// LIMITED when he walks out still blended. Faction-agnostic sidearm.
if (isNil "DUWS_fnc_informant_footFlee") then {
    DUWS_fnc_informant_footFlee = {
        params ["_inf", "_dest", ["_run", true], ["_armed", false]];
        if (!alive _inf) exitWith {};
        private _grp = group _inf;
        while { (count (waypoints _grp)) > 0 } do { deleteWaypoint [_grp, 0] };
        if (_armed) then {
            _inf setCaptive false;
            _inf addMagazine "16Rnd_9x21_Mag";
            _inf addWeapon "hgun_Rook40_F";
            _grp setBehaviour "COMBAT";
            _grp setCombatMode "RED";
        } else {
            _grp setBehaviour "CARELESS";
        };
        private _speed = ["LIMITED", "FULL"] select _run;
        _grp setSpeedMode _speed;
        private _wp = _grp addWaypoint [_dest, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed _speed;
    };
};

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_INTEL_INFORMANT_BRIEF", _townName, _zoneName, _clock, _vehName]] remoteExec ["fnc_duws_dialogue", 0];

// Exfil watcher: hold until the leave clock elapses or a firefight starts, then get him out. Kept off
// the main thread so the win/fail monitor below runs against it in parallel.
[_informant, _informantCar, _decoys, _zx, _leaveAt, _townPos] spawn {
    params ["_inf", "_car", "_decoys", "_zx", "_leaveAt", "_townPos"];

    // Why he leaves sets the tempo. A firefight -- the crowd scattering, read off the same alarm the
    // civilians raise (fnc_civ_panic's DUWS_civ_panicked, propagated across the town within its 150 m
    // radius) -- makes him bolt; a reached deadline is a calm scheduled exit he walks. The finder
    // guarantees a populated town, so there are always locals around him to read.
    private _loud = false;
    waitUntil {
        sleep 2;
        if (!alive _inf) exitWith { true };
        if (((_inf nearEntities ["CAManBase", 150]) findIf { _x getVariable ["DUWS_civ_panicked", false] }) >= 0) exitWith { _loud = true; true };
        time > _leaveAt
    };
    if (!alive _inf) exitWith {};

    // Stops the wander loop before the leave orders go in: his getaway waypoints must not race the
    // stroll's doMove for the same group.
    _inf setVariable ["DUWS_informant_leaving", true];

    // FULL when he bolts, LIMITED (a walk on foot, a calm roll in the car) when he leaves on schedule.
    // The one pace drives his approach to the car, the getaway, and the decoys alike, so a calm exit
    // and a panicked one each leave four cars moving the same and speed cannot pick him out. TUNABLE.
    private _speed = ["LIMITED", "FULL"] select _loud;
    (group _inf) setBehaviour "CARELESS";
    (group _inf) setSpeedMode _speed;

    private _boarded = false;
    if (alive _car) then {
        _inf assignAsDriver _car;
        [_inf] orderGetIn true;
        private _giveUp = diag_tickTime + 60;
        waitUntil { sleep 1; (_inf in _car) || !alive _inf || !alive _car || diag_tickTime > _giveUp };
        _boarded = (alive _inf) && (_inf in _car);
    };

    if (!_boarded) exitWith {
        if (alive _inf) then {
            // Only a car that is gone (destroyed, or never spawned) unmasks him; a boarding that just
            // timed out with the car intact keeps him disguised. He hurries under fire or with no ride.
            private _carGone = !alive _car;
            [_inf, _zx, _loud || _carGone, _carGone] call DUWS_fnc_informant_footFlee;
        };
    };

    // He is away: the decoys break in random directions away from town (never toward the zone), so
    // four cars leave at once -- at his pace, so eyes-on, not speed, is the only tell.
    {
        if (alive _x && {!isNull (driver _x)}) then {
            private _dg = group (driver _x);
            _dg setBehaviour "CARELESS";
            _dg setSpeedMode _speed;
            private _dest = _townPos getPos [1500 + random 500, random 360];
            private _wp = _dg addWaypoint [_dest, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed _speed;
        };
    } forEach _decoys;

    private _grp = group _inf;
    _grp setSpeedMode _speed;
    private _wp = _grp addWaypoint [_zx, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed _speed;
    _wp setWaypointBehaviour "CARELESS";

    // Car killed under him mid-drive and he lives: onto foot, armed and running -- his ride is gone.
    waitUntil { sleep 2; !alive _car || !alive _inf || (_inf distance2D _zx) < 60 };
    if ((alive _inf) && !alive _car && !(_inf in _car)) then {
        [_inf, _zx, true, true] call DUWS_fnc_informant_footFlee;
    };
};

// Win/fail monitor. Killed -> win; reaches the zone -> escaped; deadline -> timeout.
private _deadline = DUWS_curDeadlineAt;
private _outcome = "";
waitUntil {
    sleep 2;
    if ((_informant getVariable ["DUWS_informant_dead", false]) || !alive _informant) exitWith { _outcome = "WIN"; true };
    if (!isNull _informant && {(_informant distance2D _zx) < 60}) exitWith { _outcome = "ESCAPED"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
    false
};

[_markername2] call fnc_missionMarkerClear;
missionNamespace setVariable ["DUWS_informant_unit", objNull];
missionNamespace setVariable ["DUWS_informant_crowd", []];
DUWS_informant_active = false;
publicVariable "DUWS_informant_active";

if (_outcome isEqualTo "WIN") then {
    [_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_INTEL_INFORMANT_KILLED"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_townPos, _radius, ""] call fnc_mission_end;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    [_taskID, "FAILED"] call fnc_missionTaskEnd;
    // Both fails read the same way: on a timeout we simply assume he made it to the zone.
    private _failText = format [localize "STR_DUWS_T_INTEL_INFORMANT_ESCAPED", _zoneName];
    [_failText, {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_townPos, _radius, ""] call fnc_mission_end;
};

// Same cleanup for everything the mission put down -- informant, all four cars, decoy drivers and the
// added crowd -- once the players have had a moment with the result.
[_allCars, _allUnits] spawn {
    params ["_cars", "_units"];
    sleep 10;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _cars;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _units;
};
