// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

// Resolve the town this offer sits on. The finder returned a town centre, so the nearest registered
// town to it is that town; civ_town_rep / civ_radii are server-only and this thread is server-side.
private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locs isEqualTo []) exitWith {
    [15, _requester, "no_towns_registered: civ_locations empty"] call fnc_mission_abort;
};
private _townIndex = -1;
private _bestD = 1e9;
{
    private _d = (getPos _x) distance2D _MissionPos;
    if (_d < _bestD) then { _bestD = _d; _townIndex = _forEachIndex };
} forEach _locs;
if (_townIndex < 0) exitWith {
    [15, _requester, "no_town_match: offer pos matched no registered town"] call fnc_mission_abort;
};
private _townPos    = getPos (_locs select _townIndex);
private _townRadius = _radii param [_townIndex, 200];

// Enemy town: OPFOR-banded, or holding a garrison the reputation band has not caught up to yet.
private _rep       = [_townIndex] call fnc_civ_repAt;
private _enemyTown = (_rep <= -10) || {([_townIndex] call fnc_town_garrison_tierAt) > 0};

if (!([15, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

// Leave clock on the shared mission-timing shape (5-min in-game steps, the same clock the deadline
// uses): enemy towns give 10 minutes, friendly 20. TUNABLE steps.
private _leaveSteps = if (_enemyTown) then { 2 } else { 4 };
private _leaveAt = [_leaveSteps] call fnc_time_deadline;
private _clock = [_leaveAt] call fnc_time_clock;

// Escape destination: nearest OPFOR-held zone at least 1 km off (he runs to enemy ground, never a
// BLUFOR zone). Finder guaranteed one at offer time; if the last was captured since, abort. Name from
// zone_namePOS_pairs, enemy-held from WARCOM_zones_controled_by_OPFOR, matched by position. TUNABLE.
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
    [15, _requester, "escape_zone_missing: no OPFOR-held zone >=1km from town"] call fnc_mission_abort;
};

private _townName = text (_locs select _townIndex);

// 16-point bearing town -> destination, for the civilian "saw him leave" line.
private _compass16 = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
private _leaveDir = _compass16 select (floor (((([_townPos, _zx] call BIS_fnc_dirTo) + 11.25) mod 360) / 22.5));

// Getaway car plus three decoys that scatter when he drives, so the described vehicle never points at
// one car. One decoy is his class, two random: the description narrows to >=2 identical cars, never one.
private _vehPool = missionNamespace getVariable ["civ_veh_array", []];
if (_vehPool isEqualTo []) then { _vehPool = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F"] };
private _informantClass = selectRandom _vehPool;
private _decoyClasses = [_informantClass, selectRandom _vehPool, selectRandom _vehPool] call BIS_fnc_arrayShuffle;
private _vehName = getText (configFile >> "CfgVehicles" >> _informantClass >> "displayName");

private _radius = _townRadius max 200;
// Everything the hunt spawns clusters within this, so the player works one tight knot at the centre,
// not a town-wide sweep, and the informant stays in his crowd. The task ellipse still marks the town.
private _spawnRadius = (_townRadius * 0.5) max 100; // TUNABLE.
// Position-based id (like every mission thread): unique per town and stable, where a round-time id
// collides when two missions are created in the same second.
private _taskID = format ["informant%1%2", round (_townPos select 0), round (_townPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// Parks a car near the town, stripped of the free medkit vanilla civ cars carry. findEmptyPosition fits
// THIS car's footprint against nearby buildings/walls/cars, or a bare road point plus createVehicle's weak
// relocate drops it into a house wall where it detonates on spawn. Nothing fits -> open ground off the road.
private _fnc_spawnCar = {
    params ["_class", "_pos", "_dir"];
    private _fit = _pos findEmptyPosition [0, 25, _class];
    if (_fit isEqualTo []) then {
        _fit = [_pos, 0, 25, (sizeOf _class) max 6, 0, 0.3, 0] call BIS_fnc_findSafePos;
        if (_fit isEqualTo [0,0,0]) then { _fit = _pos };
    };
    private _veh = _class createVehicle _fit;
    clearItemCargoGlobal _veh; clearMagazineCargoGlobal _veh;
    clearWeaponCargoGlobal _veh; clearBackpackCargoGlobal _veh;
    _veh setDir _dir;
    _veh
};

private _roads = nearestTerrainObjects [_townPos, ["MAIN ROAD", "ROAD", "TRACK"], _spawnRadius, false, true];
// A road point is usable only if clear of the walls/rocks/trees lining an Altis town road and of any
// car already placed: the spawn settles onto nearest open ground, so an open start keeps the car on
// the road not shoved off, and the car check keeps the four cars off one another's segment.
private _fnc_carClear = {
    params ["_p"];
    (nearestTerrainObjects [_p, ["WALL", "FENCE", "ROCK", "TREE"], 4]) isEqualTo []
    && { (nearestObjects [_p, ["Car"], 7]) isEqualTo [] }
};
private _fnc_carPos = {
    // Clear road point if the town has one, else safe ground -- a car in a field still drives off.
    private _clear = _roads select { [getPosATL _x] call _fnc_carClear };
    if (_clear isEqualTo []) exitWith {
        private _p = [_townPos, 0, _spawnRadius, 5, 0, 0.3, 0] call BIS_fnc_findSafePos;
        [if (_p isEqualTo [0,0,0]) then { _townPos } else { _p }, random 360]
    };
    private _road = selectRandom _clear;
    // Heading ALONG the road, via bearing to a connected segment: a road piece's own getDir is often
    // 0, which parks the car broadside across the carriageway and blocks it.
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

// The informant: a genuine CIVILIAN-side unit, so third-party AI mods (which manage units by side)
// leave his scripted stroll alone rather than driving a tactical reaction when BLUFOR closes in and
// outs him. Captive/unarmed while blended; only car-gone AND under fire flips him to EAST (footFlee).
private _civBodies = missionNamespace getVariable ["civ_array", []];
private _informantSpawn = [_townPos, 0, _spawnRadius, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
if (_informantSpawn isEqualTo [0,0,0]) then { _informantSpawn = _townPos };
private _iGroup = createGroup [CIVILIAN, true];
private _informant = _iGroup createUnit [selectRandom _civBodies, _informantSpawn, [], 0, "NONE"];
removeAllWeapons _informant;
_informant setCaptive true;
_informant setBehaviour "SAFE";
_informant setUnitPos "UP";
_allUnits pushBack _informant;

// Killed handler here so the rep cost is charged off his death position: a clean kill on the road is
// free, one in the crowd is not. Nearest town within edge + 300 m pays -1. TUNABLE.
_informant addEventHandler ["Killed", {
    params ["_unit", "_killer", "_instigator"];
    _unit setVariable ["DUWS_informant_dead", true];
    // CIVILIAN death triggers the engine's civ-kill rating penalty -- a global rating tank that can turn
    // the player's own AI hostile. Cancel it (the -1 town rep below is the whole intended cost); only on a
    // civilian death, since an EAST flip (car gone) was neutral.
    if (side _unit == CIVILIAN) then {
        private _who = _instigator; if (isNull _who) then { _who = _killer };
        if (!isNull _who) then { _who addRating 500 }; // TUNABLE
    };
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

// He blends fully: a player can call him over and open the same interaction menu every local carries,
// so a lone menu-less civilian is not the tell. Keyed on the unit (like fnc_civ_spawnUnit) so a JIP
// client gets it; he is spawned raw, so this is his only path to the actions.
[_informant] remoteExec ["fnc_civ_clientActions", 0, _informant];

// While waiting he strolls the cluster (fresh safe point, re-tasked on arrival or a cap so a blocked
// path never freezes him), LIMITED so he reads as a local. Ends when the exfil watcher takes over
// (DUWS_informant_leaving), so this doMove never fights the getaway waypoints.
[_informant, _townPos, _spawnRadius] spawn {
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

// Thicken the crowd only on a friendly/neutral town. Each added civilian is a real local (same index,
// so harming one costs the town). Three to a group: 24 solo groups would eat the engine's ~144-per-side
// cap the town crowd and decoy drivers also draw on. Eight trios is ~twice the town's density. TUNABLE.
private _crowd = [];
if (!_enemyTown) then {
    // Re-open every local already in town: a body that survived an earlier hunt still reads
    // DUWS_informant_asked spent. Fresh/streamed-in bodies default unspent, so only these need it.
    { _x setVariable ["DUWS_informant_asked", false, true] } forEach
        (allUnits select { (_x getVariable ["civ_locIndex", -1]) == _townIndex });

    private _crowdGroups = [];
    for "_i" from 1 to 8 do {
        private _anchor = [_townPos, 0, _spawnRadius, 2, 0, 0.35, 0] call BIS_fnc_findSafePos;
        if (_anchor isEqualTo [0,0,0]) then { _anchor = _townPos };
        private _grp = grpNull;
        for "_j" from 0 to 2 do {
            private _cpos = _anchor getPos [_j * 3, random 360];
            private _c = [_townIndex, _cpos, selectRandom _civBodies, false] call fnc_civ_spawnUnit;
            if (!isNull _c) then {
                _crowd pushBack _c;
                _allUnits pushBack _c;
                // Trio's later members join the first's group; the emptied group self-deletes
                // (fnc_civ_spawnUnit sets deleteWhenEmpty).
                if (isNull _grp) then { _grp = group _c } else { [_c] joinSilent _grp };
            };
        };
        if (!isNull _grp) then { _crowdGroups pushBack _grp };
    };
    // The town's own walk-and-pose pass, so the added locals move like the rest of the crowd.
    private _townBuildings = (missionNamespace getVariable [format ["civ_buildings_%1", _townIndex], []]) select { !isNull _x };
    [_crowdGroups, _townBuildings] spawn fnc_civ_wp_Tomata;

    // The ask action reaches every town local -- a poll, not a one-off sweep, since the crowd is not all
    // present at start (the offer is usually taken far off). The askable flag makes each a one-time add;
    // the loop ends with the hunt, and the action self-hides once DUWS_informant_active is false.
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

    // The informant carries the same ask action as every local -- the one man who couldn't be asked
    // would be the tell. Spawned raw, outside the poll's civ_locIndex set, so add it directly, unspent.
    // fnc_informant_ask_request refuses when the asked local IS the informant, so he never outs himself.
    _informant setVariable ["DUWS_informant_asked", false, true];
    [_informant] remoteExec ["fnc_informant_ask_addAction", 0, _informant];
};
missionNamespace setVariable ["DUWS_informant_crowd", _crowd];

// Foot flight when there is no car. Two independent axes: _armed decides breaking cover -- only a gone
// car drops the disguise, pulls a pistol, fights out (a shot alone never unmasks him); _run decides
// pace -- FULL hurrying (under fire or car gone), LIMITED walking out blended. Faction-agnostic sidearm.
if (isNil "DUWS_fnc_informant_footFlee") then {
    DUWS_fnc_informant_footFlee = {
        params ["_inf", "_dest", ["_run", true], ["_armed", false]];
        if (!alive _inf) exitWith {};
        private _grp = group _inf;
        while { (count (waypoints _grp)) > 0 } do { deleteWaypoint [_grp, 0] };
        if (_armed) then {
            // Break cover to an EAST pistol (OPFOR pool). Rebind _grp -- the orders below task his new
            // group, not the emptied civ one. No skill bump (a lone fleer, not a cell); UP is forced below.
            _grp = [[_inf], "EAST", "opfor", ["pistol"], [true, -1]] call fnc_civ_arm;
        } else {
            _grp setBehaviour "CARELESS";
        };
        private _speed = ["LIMITED", "FULL"] select _run;
        _grp setSpeedMode _speed;
        // Upright, never prone: he bolts like a panicking civ (fnc_civ_panic keeps them on their feet),
        // where the EAST combat group would otherwise let danger AI drop him prone to fight from cover.
        _inf setUnitPos "UP";
        private _wp = _grp addWaypoint [_dest, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed _speed;
    };
};

// Exfil watcher: hold until the leave clock elapses or a firefight starts, then get him out. Kept off
// the main thread so the win/fail monitor below runs against it in parallel.
[_informant, _informantCar, _decoys, _zx, _leaveAt, _townPos, _townRadius] spawn {
    params ["_inf", "_car", "_decoys", "_zx", "_leaveAt", "_townPos", "_townRadius"];

    // Why he leaves sets the tempo. A firefight (crowd scattering, read off the civilians' own alarm
    // fnc_civ_panic's DUWS_civ_panicked, propagated town-wide within its 150 m radius) makes him bolt;
    // a reached deadline is a calm exit he walks. The finder guarantees locals around him to read.
    private _loud = false;
    waitUntil {
        sleep 2;
        if (!alive _inf) exitWith { true };
        // Across the town, not one alarm hop: the panic chain thins where the crowd does, so read a
        // town-wide radius off his position rather than trust a panicked civ to stand within 150 m.
        if (((_inf nearEntities ["CAManBase", (_townRadius max 200) + 150]) findIf { _x getVariable ["DUWS_civ_panicked", false] }) >= 0) exitWith { _loud = true; true };
        time > _leaveAt
    };
    if (!alive _inf) exitWith {};

    // Stop the wander loop before leave orders: getaway waypoints must not race the stroll's doMove.
    _inf setVariable ["DUWS_informant_leaving", true];

    // Drop waypoints an interaction left on him: talking runs fnc_civ_resume, which adds a stroll
    // CYCLE, and a CYCLE ahead of the getaway MOVE would loop the car through town instead of out.
    // Back-to-front -- deleteWaypoint shifts later indices.
    private _leftover = waypoints (group _inf);
    reverse _leftover;
    { deleteWaypoint _x } forEach _leftover;

    // FULL when he bolts, LIMITED (walk, or calm roll) on schedule. One pace drives his approach, the
    // getaway and the decoys alike, so all four cars move the same and speed cannot pick him out. TUNABLE.
    private _speed = ["LIMITED", "FULL"] select _loud;
    (group _inf) setBehaviour "CARELESS";
    (group _inf) setSpeedMode _speed;

    private _boarded = false;
    if (alive _car) then {
        _inf assignAsDriver _car;
        // Run him to the car under his own doMove: at FULL a firefight makes him sprint like the
        // panicking crowd (fnc_civ_panic flees the same, CARELESS + FULL), where orderGetIn alone
        // walks a lone unit to the door whatever his speed mode. Board once on it; pace tracks _speed.
        private _giveUp = diag_tickTime + 60;
        waitUntil {
            sleep 1;
            if (alive _inf && {alive _car} && {!(_inf in _car)}) then {
                if (_inf distance _car > 5) then { _inf doMove (getPosATL _car) } else { [_inf] orderGetIn true };
            };
            (_inf in _car) || !alive _inf || !alive _car || diag_tickTime > _giveUp
        };
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

// Marker + task now the hunt stands; the brief below is manual (four-field format, no callsign substitution).
private _markername2 = [_townPos, _radius, _taskID, format [localize "STR_DUWS_T_INTEL_INFORMANT_TASK", _zoneName, _clock, _vehName], _mission_name, "search"] call fnc_mission_present;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_INTEL_INFORMANT_BRIEF", _townName, _zoneName, _clock, _vehName]] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_INTEL_INFORMANT_COPY"] remoteExec ["fnc_duws_dialogue", 0];

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

missionNamespace setVariable ["DUWS_informant_unit", objNull];
missionNamespace setVariable ["DUWS_informant_crowd", []];
DUWS_informant_active = false;
publicVariable "DUWS_informant_active";

if (_outcome isEqualTo "WIN") then {
    [_mission_name, _taskID, "SUCCEEDED", _townPos, _radius, [_markername2], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_INTEL_INFORMANT_KILLED"], true, "", false, false] call fnc_mission_finish;
} else {
    // Both fails read the same way: on a timeout we simply assume he made it to the zone. His own
    // "escaped" hint stands in for the generic timeout notice (notify false).
    private _failText = format [localize "STR_DUWS_T_INTEL_INFORMANT_ESCAPED", _zoneName];
    [_failText, {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_mission_name, _taskID, "FAILED", _townPos, _radius, [_markername2], [], false, "", false, false] call fnc_mission_finish;
};

// Cleanup everything the mission put down (informant, four cars, decoy drivers, added crowd), once
// the players have had a moment with the result.
[_allCars, _allUnits] spawn {
    params ["_cars", "_units"];
    sleep 10;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _cars;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _units;
};
