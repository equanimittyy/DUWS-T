// Locality: server -- callers remoteExec to target 2.
//
// Informant hunt. An OPFOR informant hides disguised among a town's civilians; the player locates and
// kills him before he leaves by car for a distant zone. The site-finder (fnc_intel_gathering_site)
// guarantees _MissionPos is a populated Tomata town, so this thread never has to test for one.
//
// Two shapes, chosen by the town's reputation band:
//   friendly/neutral -- the crowd is thickened and every civilian can be asked about the informant
//                       (fnc_intel_ask_addAction, added in the ask-action layer); the player narrows
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

// Escape destination: the nearest named zone at least 1 km off, so the drive is a real leg, the fail
// is reachable, and the zone can be named in the briefing. No zone that far (a tiny map) falls back to
// a point 1.5 km out. TUNABLE.
private _MINDIST = 1000;
private _zx  = [];
private _zoneName = "open country";
private _zxD = 1e9;
{
    _x params ["_zn", "_zp"];
    private _d = _zp distance2D _townPos;
    if (_d >= _MINDIST && _d < _zxD) then { _zxD = _d; _zx = _zp; _zoneName = _zn };
} forEach zone_namePOS_pairs;
if (_zx isEqualTo []) then { _zx = _townPos getPos [1500, random 360] };

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
private _taskID = format ["intel_informant_%1", round time];
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
private _fnc_carPos = {
    // A road point when the town has roads, otherwise a safe patch of ground -- a car in a field is
    // still a car to drive off in.
    if (_roads isEqualTo []) exitWith {
        private _p = [_townPos, 0, _townRadius, 5, 0, 0.3, 0] call BIS_fnc_findSafePos;
        [if (_p isEqualTo [0,0,0]) then { _townPos } else { _p }, random 360]
    };
    private _road = selectRandom _roads;
    [getPosATL _road, getDir _road]
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
    _unit setVariable ["DUWS_intel_dead", true];
    private _p = getPosATL _unit;
    private _tl = missionNamespace getVariable ["civ_locations", []];
    private _tr = missionNamespace getVariable ["civ_radii", []];
    private _ti = -1; private _bd = 1e9;
    { private _dd = (getPos _x) distance2D _p; if (_dd < _bd) then { _bd = _dd; _ti = _forEachIndex } } forEach _tl;
    if (_ti >= 0 && {_bd <= (_tr param [_ti, 200]) + 300}) then {
        [_ti, -1, "informant_killed_near_town"] call fnc_town_rep_adjust;
    };
}];
// A firefight near him is the signal to run, in either branch.
_informant addEventHandler ["FiredNear", { (_this select 0) setVariable ["DUWS_intel_loud", true] }];

// The informant object stays server-side (the reveal reads it there); DUWS_intel_active is the
// broadcast flag the client-side ask action gates on.
missionNamespace setVariable ["DUWS_intel_informant", _informant];
missionNamespace setVariable ["DUWS_intel_townIndex", _townIndex];
// Read server-side by fnc_intel_ask_reveal: town bounds tell "still here" from "has left", and the
// leave direction is what a local reports once he is gone.
missionNamespace setVariable ["DUWS_intel_townPos", _townPos];
missionNamespace setVariable ["DUWS_intel_townRadius", _townRadius];
missionNamespace setVariable ["DUWS_intel_leaveDir", _leaveDir];
DUWS_intel_active = true;
publicVariable "DUWS_intel_active";

// Thicken the crowd only where the player can work it -- a friendly/neutral town he can walk. Each
// added civilian is a real town local (same index, so harming one costs the town), and gets the ask
// action if that layer is loaded. TUNABLE count.
private _crowd = [];
if (!_enemyTown) then {
    for "_i" from 1 to 16 do {
        private _cpos = [_townPos, 0, _townRadius, 2, 0, 0.35, 0] call BIS_fnc_findSafePos;
        if (_cpos isEqualTo [0,0,0]) then { _cpos = _townPos };
        private _c = [_townIndex, _cpos, selectRandom _civBodies, false] call fnc_civ_spawnUnit;
        if (!isNull _c) then {
            _crowd pushBack _c;
            _allUnits pushBack _c;
            // JIP-keyed on the civilian so a client that connects mid-hunt still gets the action.
            [_c] remoteExec ["fnc_intel_ask_addAction", 0, _c];
        };
    };
};
missionNamespace setVariable ["DUWS_intel_crowd", _crowd];

// Foot flight: car gone, so he drops the disguise, pulls a pistol and runs for the zone as an open
// combatant. Faction-agnostic sidearm for now.
if (isNil "DUWS_fnc_intel_footFlee") then {
    DUWS_fnc_intel_footFlee = {
        params ["_inf", "_dest"];
        if (!alive _inf) exitWith {};
        _inf setCaptive false;
        _inf addMagazine "16Rnd_9x21_Mag";
        _inf addWeapon "hgun_Rook40_F";
        private _grp = group _inf;
        while { (count (waypoints _grp)) > 0 } do { deleteWaypoint [_grp, 0] };
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";
        private _wp = _grp addWaypoint [_dest, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
    };
};

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_INTEL_INFORMANT_BRIEF", _townName, _zoneName, _clock, _vehName]] remoteExec ["fnc_duws_dialogue", 0];

// Exfil watcher: hold until the leave clock elapses or a firefight starts, then get him out. Kept off
// the main thread so the win/fail monitor below runs against it in parallel.
[_informant, _informantCar, _decoys, _zx, _leaveAt, _townPos] spawn {
    params ["_inf", "_car", "_decoys", "_zx", "_leaveAt", "_townPos"];

    waitUntil {
        sleep 2;
        (time > _leaveAt) || (_inf getVariable ["DUWS_intel_loud", false]) || !alive _inf
    };
    if (!alive _inf) exitWith {};

    (group _inf) setBehaviour "CARELESS";

    private _boarded = false;
    if (alive _car) then {
        _inf assignAsDriver _car;
        [_inf] orderGetIn true;
        private _giveUp = diag_tickTime + 60;
        waitUntil { sleep 1; (_inf in _car) || !alive _inf || !alive _car || diag_tickTime > _giveUp };
        _boarded = (alive _inf) && (_inf in _car);
    };

    if (!_boarded) exitWith {
        if (alive _inf) then { [_inf, _zx] call DUWS_fnc_intel_footFlee };
    };

    // He is away: the decoys break in random directions away from town (never toward the zone), so
    // four cars leave at once and only eyes-on says which is his.
    {
        if (alive _x && {!isNull (driver _x)}) then {
            private _dg = group (driver _x);
            _dg setBehaviour "CARELESS";
            _dg setSpeedMode "FULL";
            private _dest = _townPos getPos [1500 + random 500, random 360];
            private _wp = _dg addWaypoint [_dest, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
        };
    } forEach _decoys;

    private _grp = group _inf;
    _grp setSpeedMode "FULL";
    private _wp = _grp addWaypoint [_zx, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";

    // Car killed under him mid-drive and he lives: onto foot, armed.
    waitUntil { sleep 2; !alive _car || !alive _inf || (_inf distance2D _zx) < 60 };
    if ((alive _inf) && !alive _car && !(_inf in _car)) then {
        [_inf, _zx] call DUWS_fnc_intel_footFlee;
    };
};

// Win/fail monitor. Killed -> win; reaches the zone -> escaped; deadline -> timeout.
private _deadline = DUWS_curDeadlineAt;
private _outcome = "";
waitUntil {
    sleep 2;
    if ((_informant getVariable ["DUWS_intel_dead", false]) || !alive _informant) exitWith { _outcome = "WIN"; true };
    if (!isNull _informant && {(_informant distance2D _zx) < 60}) exitWith { _outcome = "ESCAPED"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
    false
};

[_markername2] call fnc_missionMarkerClear;
missionNamespace setVariable ["DUWS_intel_informant", objNull];
missionNamespace setVariable ["DUWS_intel_crowd", []];
DUWS_intel_active = false;
publicVariable "DUWS_intel_active";

if (_outcome isEqualTo "WIN") then {
    [_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_allseer", [localize "STR_DUWS_T_INTEL_INFORMANT_KILLED"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
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
