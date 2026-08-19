// Locality: server -- callers remoteExec to target 2.
//
// Convoy hunt. A high-value target flees to an OPFOR-held zone in one of three armed road convoys,
// each on its own approach. Exactly one convoy carries the HVT in a single unarmed car -- the odd hull
// among the armed escorts, its type named to the player -- so the mission is to spot the right column
// and stop it before it arrives. Win: the HVT dies. Fail: his car reaches the zone, or the deadline
// passes.
//
// Off the fnc_mission_run spine on purpose: the win is a race, not a one-shot predicate polled at a
// fixed spot (see fnc_mission_run's header), so this owns its own site pick, spawn and monitor the
// way the informant hunt and the IDAP escort do.
params ["_MissionPos", "_mission_name"];
if (!([2, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// Destination: the OPFOR-held zone nearest the sited position -- the safe haven the convoys run for.
// Matched by position against WARCOM_zones_controled_by_OPFOR the way the informant hunt picks its
// escape zone. None held (the last fell between offer and start) -> abort, releasing gate and slot.
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _destPos = [];
private _destName = "";
private _destD = 1e9;
{
    _x params ["_zn", "_zp"];
    if ((_enemyZones findIf { _x distance2D _zp < 50 }) >= 0 && {(_zp distance2D _MissionPos) < _destD}) then {
        _destD = _zp distance2D _MissionPos; _destPos = _zp; _destName = _zn;
    };
} forEach zone_namePOS_pairs;
if (_destPos isEqualTo []) exitWith {
    [2, "STR_DUWS_T_crtzxs0j", "dest_zone_missing: no OPFOR-held zone to run the convoy to"] call fnc_mission_abort;
};

// The convoys start ringed around the zone on three bearings ~120 deg apart, so the approaches
// diverge and the player cannot cover them all. TUNABLE: ring gives roughly the intercept window
// (bigger = more travel time), grace holds the columns at their start so a player inserting from
// across the map has time to reach one before it rolls, arrive is the zone-edge fail band.
private _ring    = 4500;
private _graceSec = 120;
private _arrive   = 80;

// Escort classes roll per vehicle across armed car, IFV and armour, gated by OPFOR's earned Army
// Power through DUWS_fnc_tokenClass -- a low-AP campaign fields cars, a high one can field tanks. The
// armed car is the floor when the side has earned nothing yet, so a convoy is never unescorted.
private _escTokens = ["car", "ifv", "tank"] select { ([_x, "OPF"] call DUWS_fnc_tokenClass) != "" };
private _rollEsc = {
    if (_escTokens isEqualTo []) exitWith { opfor_ARMED_CAR1_X };
    private _c = [selectRandom _escTokens, "OPF"] call DUWS_fnc_tokenClass;
    if (_c == "") then { opfor_ARMED_CAR1_X } else { _c }
};

// The HVT rides an unarmed car of OPFOR's own faction -- no turret weapon, a handful of seats -- so it
// reads as one of theirs, not a civilian giveaway, yet is the odd unarmed hull among armed escorts and
// the thing the player is told to look for. The faction vocab names no such role, so its CfgVehicles is
// scanned once for a Car-kind class the armed test (the reserve trucks' own) clears; cached per faction,
// since the scan is broad and the faction is fixed for the session. A faction with no unarmed car falls
// back to an armed car, and the transport truck only if it names neither.
private _fac = getText (configFile >> "CfgVehicles" >> opfor_SOLDIER_X >> "faction");
private _cacheKey = format ["DUWS_hvtCarPool_%1", _fac];
private _carPool = missionNamespace getVariable [_cacheKey, []];
if (_carPool isEqualTo []) then {
    // Scope and faction filtered engine-side, so only this faction's public vehicles reach the SQF
    // loop -- a few dozen, not the whole CfgVehicles -- where the Car kind and the armed test decide.
    private _cond = format ["getNumber (_x >> 'scope') == 2 && {getText (_x >> 'faction') == '%1'}", _fac];
    private _cars = [];
    {
        private _c = configName _x;
        if (_c isKindOf "Car" && {!([_c] call DUWS_fnc_classIsArmed)}) then {
            _cars pushBack [_c, 1 + getNumber (_x >> "transportSoldier")];
        };
    } forEach (_cond configClasses (configFile >> "CfgVehicles"));
    // Prefer the four-to-five-seat cars, then any unarmed faction car. Failing that -- a faction with no
    // unarmed car at all -- an armed car, and the transport truck only if even that is unnamed.
    _carPool = (_cars select { (_x select 1) >= 4 && (_x select 1) <= 6 }) apply { _x select 0 };
    if (_carPool isEqualTo []) then { _carPool = _cars apply { _x select 0 } };
    if (_carPool isEqualTo []) then {
        private _fallback = opfor_ARMED_CAR1_X;
        if (_fallback == "") then { _fallback = opfor_TRANS_TRUCK_X };
        _carPool = [_fallback];
    };
    missionNamespace setVariable [_cacheKey, _carPool];
    ["INFO", "MISSION", format ["hvt convoy: %1 unarmed cars for faction %2", count _carPool, _fac]] call fnc_log;
};
private _hvtCarClass = selectRandom _carPool;
private _vehName = getText (configFile >> "CfgVehicles" >> _hvtCarClass >> "displayName");

// One line of vehicles as a road column, crews merged into a single group so they move together.
// Returns [group, [vehicles]]. Loot on the crew so a searched body reads as this faction like any
// patrol.
private _spawnLine = {
    params ["_classes", "_start", "_heading", "_behaviour", "_speed"];
    private _grp = createGroup EAST;
    private _vehs = [];
    {
        private _p = _start getPos [_forEachIndex * 18, _heading + 180];
        private _r = [_p, _heading, _x, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _heading;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    } forEach _classes;
    _grp setBehaviour _behaviour;
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode _speed;
    _grp setFormation "COLUMN";
    _grp deleteGroupWhenEmpty true;
    { [_x] call fnc_addRandomLoot } forEach units _grp;
    [_grp, _vehs]
};

private _hvtIdx = floor random 3;
private _base = random 360;
private _groups = [];         // every convoy group, for the delayed roll-out and the claim
private _convoyStarts = [];   // one per convoy, for exactly three start markers (no tell)
private _hvt = objNull;

for "_i" from 0 to 2 do {
    private _bearing = _base + (_i * 120) + (random 40 - 20);
    private _raw = _destPos getPos [_ring, _bearing];
    // On a road: a convoy that spawns off the network fights the pathfinder the whole way. nearRoads
    // returns nearest-first; a safe patch is the fallback where the ring point is roadless.
    private _roads = _raw nearRoads 600;
    private _start = if (count _roads > 0) then { getPosATL (_roads select 0) }
        else { [_raw, 0, 150, 10, 0, 0.5, 0] call BIS_fnc_findSafePos };
    private _heading = [_start, _destPos] call BIS_fnc_dirTo;
    _convoyStarts pushBack _start;

    if (_i == _hvtIdx) then {
        // Two armed escorts fore and aft, defending (AWARE, return fire); the HVT's car is its own
        // CARELESS group between them so it commits to the run and drives through a firefight rather
        // than halting with the escorts -- the player has to stop the car, not just spook the column.
        private _escGrp = createGroup EAST;
        {
            private _p = _start getPos [_x, _heading + 180];
            private _r = [_p, _heading, call _rollEsc, EAST] call BIS_fnc_spawnVehicle;
            (_r select 0) setDir _heading;
            (_r select 2) deleteGroupWhenEmpty true;
            (_r select 1) joinSilent _escGrp;
        } forEach [0, 36];
        _escGrp setBehaviour "AWARE";
        _escGrp setCombatMode "YELLOW";
        _escGrp setSpeedMode "LIMITED";
        _escGrp setFormation "COLUMN";
        _escGrp deleteGroupWhenEmpty true;
        { [_x] call fnc_addRandomLoot } forEach units _escGrp;

        private _cp = _start getPos [18, _heading + 180];
        private _car = createVehicle [_hvtCarClass, _cp, [], 0, "NONE"];
        _car setDir _heading;
        private _hvtGrp = createGroup EAST;
        private _driver = _hvtGrp createUnit [opfor_SOLDIER_X, _cp, [], 0, "NONE"];
        _driver moveInDriver _car;
        _hvt = _hvtGrp createUnit [opfor_OFFICER_X, _cp, [], 0, "NONE"];
        _hvt moveInCargo _car;
        _hvt addHeadgear "H_Beret_blk";
        _hvt addMagazineGlobal "FileTopSecret";
        _hvtGrp setBehaviour "CARELESS";
        _hvtGrp setSpeedMode "LIMITED";
        _hvtGrp deleteGroupWhenEmpty true;
        _groups append [_escGrp, _hvtGrp];
    } else {
        ([[call _rollEsc, call _rollEsc, call _rollEsc], _start, _heading, "AWARE", "LIMITED"] call _spawnLine) params ["_grp"];
        _groups pushBack _grp;
    };
};

if (isNull _hvt) exitWith {
    // The officer class never crewed -- an exotic faction naming no officer role. Bail rather than
    // leave a mission that can never be won.
    { private _g = _x; { deleteVehicle (vehicle _x); deleteVehicle _x } forEach units _g; deleteGroup _g } forEach _groups;
    [2, "STR_DUWS_T_crtzxs0j", "hvt_spawn_failed: no officer class"] call fnc_mission_abort;
};

{ [_x] call fnc_mission_claim } forEach _groups;

// Interdiction ellipse on the zone, plus a fix on each convoy's start so the player has three columns
// to run down. The starts are one-shot: nothing tracks the convoys live, or there would be no hunt.
private _radius = 1500;
private _marker = [_destPos, _radius] call fnc_missionMarkerData;
private _startMarkers = [];
{
    private _mn = format ["hvtconvoy_%1_%2", round (_x select 0), round (_x select 1)];
    createMarker [_mn, _x];
    _mn setMarkerShape "ICON";
    _mn setMarkerType "o_motor_inf";
    _mn setMarkerColor "ColorEAST";
    _mn setMarkerText "Convoy";
    _startMarkers pushBack _mn;
} forEach _convoyStarts;

private _taskId = format ["hvtconvoy%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, format [localize "STR_DUWS_T_HVT_CONVOY_TASK", _destName, _vehName], _mission_name, _destPos, "kill"] call fnc_missionTaskCreate;
[localize "STR_DUWS_T_c2", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_hvtletsdothis", _destName, _vehName]] remoteExec ["fnc_duws_dialogue", 0];

// Grace: the columns hold at their start points, so a player inserting from range has a window before
// the race begins. Then every group is ordered to the zone at once.
sleep _graceSec;
{
    private _wp = _x addWaypoint [_destPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 40;
} forEach _groups;

private _outcome = "";
waitUntil {
    sleep 2;
    if (!alive _hvt) exitWith { _outcome = "WIN"; true };
    if (_hvt distance2D _destPos < _arrive) exitWith { _outcome = "ESCAPED"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
    false
};

[_marker] call fnc_missionMarkerClear;
{ deleteMarker _x } forEach _startMarkers;

if (_outcome == "WIN") then {
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_hvtend"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;
    sleep 1;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    if (_outcome == "ESCAPED") then {
        [[_destName], { params ["_z"]; hint format [localize "STR_DUWS_T_HVT_CONVOY_ESCAPED", _z] }] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    } else {
        // TODO: give this mission a bespoke Overlord timeout-fail line instead of the generic notice.
        call fnc_mission_timeout_notice;
    };
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
};

[_destPos, _radius] call fnc_mission_end;
