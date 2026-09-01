// Locality: server; the action and factory bodies below run on the machine that triggers them.
// Protect Informant, defend-and-build: reach the informant, fortify from a limited crate through a
// fixed prep window, then hold OPFOR waves long enough for him to survive. docs/plans/protect_informant_rework.md.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([13, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

#define RADIUS       300    // hold ring: fail radius, spawn radius and debus radius in one number
#define ARRIVE_DIST  30
#define PREP_TIME    600
#define DEFEND_TIME  1200
#define ABANDON_TIME 20

private _deadline = DUWS_curDeadlineAt;

// Re-derive the building the finder snapped onto: nearest house at _MissionPos with a real interior.
private _findBuilding = {
    params ["_p", "_reach"];
    private _list = [nearestTerrainObjects [_p, ["HOUSE", "BUILDING"], _reach, false], [], { _p distance2D _x }, "ASCEND"] call BIS_fnc_sortBy;
    private _b = objNull;
    { if (count (_x buildingPos -1) >= 4) exitWith { _b = _x } } forEach _list;
    _b
};
private _building = [_MissionPos, 30] call _findBuilding;
if (isNull _building) exitWith { [13, _requester, "no_building"] call fnc_mission_abort };
private _targetpos = getPosATL _building;
private _bpos = _building buildingPos -1;

private _tn            = format ["protectciv_%1_%2", round (_MissionPos select 0), round (_MissionPos select 1)];
private _skipVar       = format ["%1_skip", _tn];
private _prepActiveVar = format ["%1_prepActive", _tn];
private _liveVar       = format ["%1_live", _tn];        // spawn -> teardown
private _defendVar     = format ["%1_defend", _tn];      // defend phase only
missionNamespace setVariable [_skipVar, false];
missionNamespace setVariable [_liveVar, true];
missionNamespace setVariable [_defendVar, false];
missionNamespace setVariable [_prepActiveVar, true, true];

[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// Civilian-costumed but in a WEST group, so OPFOR treats him as the target to kill.
private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F", "C_man_p_fugitive_F", "C_man_hunter_1_F", "C_Man_casual_1_F", "C_Man_casual_4_F"];
private _grp = [[0, 0], WEST, [selectRandom _civClasses]] call BIS_fnc_spawnGroup;
private _inf = leader _grp;
_grp deleteGroupWhenEmpty true;
if (count _bpos > 0) then { _inf setPosATL (selectRandom _bpos) } else { _inf setPosATL _targetpos };
_inf allowDamage true;
_inf setCaptive false;
_inf disableAI "PATH";       // holds the building even once he goes AWARE to fire
_inf setBehaviour "CARELESS";
_inf setCombatMode "BLUE";
// Belt-and-suspenders against a future AIS setting change reviving him or stripping the handler below
// (ais_revive_integration.md); the shipped "allplayables" never enrols a spawned unit.
_inf setVariable ["AIS_noReviveInit", true, true];
// Chamber through the weapon: many civilian costumes have no container, so a loose magazine drops
// nowhere (arma_engine_gotchas.md). Spares land only where the costume has pockets.
_inf addWeapon "hgun_P07_F";
_inf addWeaponItem ["hgun_P07_F", "16Rnd_9x21_Mag", true];
_inf addMagazines ["16Rnd_9x21_Mag", 2];
// Half damage, doubling effective health so no fluke ends a 30-minute mission. Scales the per-hit
// increment (not the absolute) so damage still accumulates to death; negative index is whole-body.
_inf addEventHandler ["HandleDamage", {
    params ["_u", "", "_dmg", "", "", "_hi"];
    private _old = if (_hi < 0) then { damage _u } else { _u getHitIndex _hi };
    _old + ((_dmg - _old) * 0.5)
}];
[_grp] call fnc_mission_claim;
DUWS_pc_informant = _inf; publicVariable "DUWS_pc_informant";

// Pick him up by hand during prep (DUWS_fnc_unitCarry, no pathfinding). The carry routine puts the
// matching put-down action on the carrier, not on him -- attached, he sits on the player and can't be
// cursor-targeted. The assault force-drops him, clearing that carrier action, and this pickup one hides
// on the defend flag.
[_inf, [localize "STR_DUWS_T_pc_move_inf",
    { [_this select 0, _this select 1, localize "STR_DUWS_T_pc_hold_inf"] call DUWS_fnc_unitCarryToggle },
    [], 1.5, false, false, "",
    format ["_this distance _target < 6 && isNull (_target getVariable ['DUWS_carriedBy', objNull]) && !(missionNamespace getVariable ['%1_defend', false])", _tn]]
] remoteExec ["addAction", [0, -2] select isDedicated, _inf];

private _cratePos = if (count _bpos > 1) then { _bpos select 1 } else { _targetpos };
private _crate = createVehicle ["Box_NATO_Support_F", _cratePos, [], 0, "CAN_COLLIDE"];
_crate setPosATL _cratePos;
DUWS_pc_crate = _crate; publicVariable "DUWS_pc_crate";
[_crate, "mission_protect_civ"] call fnc_duws_keep;

// Reposition the build point with R3F's own carry routine (the crate is crewless, so R3F accepts it).
[_crate, [localize "STR_DUWS_T_pc_move_crate",
    { [_this select 0] spawn R3F_LOG_FNCT_objet_deplacer },
    [], 1.4, false, false, "", "_this distance _target < 6 && !R3F_LOG_mutex_local_verrou"]
] remoteExec ["addAction", [0, -2] select isDedicated, _crate];

// R3F init is client-side (if(!isDedicated), waits on R3F_LOG_active), so fan it out via BIS_fnc_MP.
// NOT JIP: DUWS_pc_crate is reused by the next instance, so a persisted entry would re-register onto its crate.
[[[], {
    waitUntil { !isNil "DUWS_pc_crate" && { !isNull DUWS_pc_crate } };
    [DUWS_pc_crate, 250, west, ["Fortifications", "Cargo", "Structures_Fences", "Structures_Walls", "Static"]] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
}], "BIS_fnc_spawn", true, false] spawn BIS_fnc_MP;

// Enrol only this crate's built objects under the mission key: R3F flags factory-made objects
// (R3F_LOG_CF_depuis_usine) beside the factory, so a near-crate poll excludes a builder vehicle's props.
[_crate, _liveVar] spawn {
    params ["_crate", "_liveVar"];
    private _seen = [];
    while { (missionNamespace getVariable [_liveVar, false]) && { !isNull _crate } } do {
        uiSleep 2;
        {
            if !(_x in _seen) then { _seen pushBack _x; [_x, "mission_protect_civ"] call fnc_duws_keep };
        } forEach ((_crate nearObjects 60) select { (_x getVariable ["R3F_LOG_CF_depuis_usine", false]) && { _x != _crate } });
    };
};

private _marker = [_MissionPos, RADIUS, _tn, localize "STR_DUWS_T_protectciv", _mission_name, "defend",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pc_directive", 7], ["STR_DUWS_T_actionteam", "STR_DUWS_T_pc_copy", 0]]
] call fnc_mission_present;

// Skip Prep Phase action, 10 s in, reach-gated by the condition, JIP-keyed to the informant.
[_inf, _skipVar, _prepActiveVar] spawn {
    params ["_inf", "_skipVar", "_prepActiveVar"];
    sleep 10;
    private _cond = format ["_this distance _target < 6 && (missionNamespace getVariable ['%1', false])", _prepActiveVar];
    [_inf, [localize "STR_DUWS_T_pc_skip",
        {
            (_this select 3) params ["_sv"];
            // Confirm first: skipping is irreversible (starts the assault). hideOnUse off so a cancel keeps the action.
            if ([localize "STR_DUWS_T_pc_skip_confirm", localize "STR_DUWS_T_pc_skip", true, true] call BIS_fnc_guiMessage) then {
                [_sv] remoteExec ["fnc_protect_civ_skip", 2];
            };
        },
        [_skipVar], 1.5, false, false, "", _cond]
    ] remoteExec ["addAction", [0, -2] select isDedicated, _inf];
};

// Prep starts only when a player reaches the informant; the deadline is the never-engaged backstop,
// disarmed once prep triggers.
private _fnArrived = { (call BIS_fnc_listPlayers) findIf { _x distance _inf < ARRIVE_DIST } >= 0 };
waitUntil {
    sleep 1;
    (call _fnArrived) || { missionNamespace getVariable [_skipVar, false] } || { time > _deadline }
};

if (time > _deadline && !(call _fnArrived) && !(missionNamespace getVariable [_skipVar, false])) exitWith {
    // Never engaged -> shared timeout notice, no death asserted.
    missionNamespace setVariable [_liveVar, false];
    missionNamespace setVariable [_prepActiveVar, false, true];
    DUWS_pc_informant = objNull; publicVariable "DUWS_pc_informant";
    DUWS_pc_crate = objNull; publicVariable "DUWS_pc_crate";
    [_mission_name, _tn, "FAILED", _targetpos, RADIUS, [_marker], [], false, "mission_protect_civ", false, true] call fnc_mission_finish;
};

private _skipped = missionNamespace getVariable [_skipVar, false];
[localize "STR_DUWS_T_pc_prep_hint"] remoteExec ["hint", [0, -2] select isDedicated];
[localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_pc_arrive"] remoteExec ["fnc_duws_dialogue", 0];

if (!_skipped) then {
    private _prepEnd = time + PREP_TIME;
    while { time < _prepEnd && !(missionNamespace getVariable [_skipVar, false]) } do {
        [format [localize "STR_DUWS_T_pc_prep_count", ceil ((_prepEnd - time) / 60)]] remoteExec ["hint", [0, -2] select isDedicated];
        private _next = time + 60;
        waitUntil { sleep 1; time >= _next || time >= _prepEnd || (missionNamespace getVariable [_skipVar, false]) };
    };
};

missionNamespace setVariable [_prepActiveVar, false, true];   // hide the skip action

missionNamespace setVariable [_defendVar, true];
[_inf] call DUWS_fnc_unitDrop;   // set him down where he stands if a player was carrying him
_inf disableAI "PATH";
_inf setBehaviour "AWARE";
_inf setCombatMode "YELLOW";

// Budget derived once and held: 7 plus the BLUFOR headcount, counting all on the side (not the living)
// so casualties never thin the waves.
private _budget = 7 + ({ side group _x == west } count (call BIS_fnc_listPlayers));
private _vehSubCap = 2 + floor random 3;   // rand(2,4) live combat vehicles, rolled once

[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_pc_assault"] remoteExec ["fnc_duws_dialogue", 0];
sleep 2;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_pc_hold"] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_pc_hold_hint"] remoteExec ["hint", [0, -2] select isDedicated];

// Lean truck dispatch: the garrison reserve's debus geometry without its held-state/pool machinery.
// Drive short of the ring, eject the squads to hunt, send the empty taxi to the sweep.
private _leanDispatch = {
    params ["_center", "_radius", "_spawnPos", "_truck", "_drv", "_grps"];
    private _debusRaw = _center getPos [_radius + DUWS_reserveDebusOffset, _center getDir _spawnPos];
    private _debusPos = [_debusRaw, 0, 80, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
    if (_debusPos isEqualTo []) then { _debusPos = _debusRaw };
    _drv setBehaviour "CARELESS";
    _drv setSpeedMode "FULL";
    (_drv addWaypoint [_debusPos, 0]) setWaypointType "MOVE";
    private _rideStart = diag_tickTime;
    waitUntil {
        uiSleep 1;
        !alive _truck || { !alive (driver _truck) } || { !canMove _truck }
        || { damage _truck > 0.8 } || { (_truck distance2D _debusPos) < 40 }
        || { diag_tickTime - _rideStart > 180 }
    };
    for "_i" from ((count (waypoints _drv)) - 1) to 0 step -1 do { deleteWaypoint [_drv, _i] };
    {
        private _g = _x;
        { if (alive _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
        if (({ alive _x } count units _g) > 0) then { [_g, "hunt", _center, _radius] call fnc_apply_posture };
    } forEach _grps;
    if (alive _truck && { alive (driver _truck) }) then {
        (_drv addWaypoint [_center getPos [_radius + 400, _center getDir _spawnPos], 0]) setWaypointType "MOVE";
    };
    _truck setVariable ["DUWS_binMe", true];
    _truck setVariable ["DUWS_binAt", time + 30];
    { _x setVariable ["DUWS_binMe", true]; _x setVariable ["DUWS_binAt", time + 30] } forEach units _drv;
};

// Token compiled into the claim, not read live: _claim is handed to the wave thread (which does not
// inherit caller privates) and fires on late waves -- a group raised then must claim this mission, not
// the next if it has begun. See fnc_missionPatrols.
private _token = missionNamespace getVariable ["DUWS_mission_token", 0];
private _claim = compile format ["[_this, %1] call fnc_mission_claim", _token];

// Deliver infantry tokens by truck (walk them in if the side fields none); returns the squad groups.
private _deliverSquads = {
    params ["_center", "_radius", "_spawnPos", "_tokens", "_claim"];
    private _out = [];
    private _made = [_spawnPos, _center] call DUWS_fnc_garrisonReserveTruckSpawn;
    if (_made isEqualTo []) exitWith {
        { private _g = [_x, _center, _radius, "hunt", _spawnPos, "opfor"] call fnc_spawn_team;
          if (!isNull _g) then { [_g] call _claim; _out pushBack _g } } forEach _tokens;
        _out
    };
    _made params ["_truck", "_drv", "_cap"];
    private _aboard = [];
    private _used = 0;
    {
        private _men = [_x] call DUWS_fnc_tokenMenCount;
        if (_used + _men <= _cap) then {
            private _g = [_x, _center, _radius, "none", _spawnPos, "opfor"] call fnc_spawn_team;
            if (!isNull _g) then {
                { _x moveInCargo _truck } forEach units _g;
                [_g] call _claim;
                _aboard pushBack _g; _out pushBack _g; _used = _used + _men;
            };
        } else {
            private _g = [_x, _center, _radius, "hunt", _spawnPos, "opfor"] call fnc_spawn_team;
            if (!isNull _g) then { [_g] call _claim; _out pushBack _g };
        };
    } forEach _tokens;
    if (_aboard isEqualTo []) then {
        { deleteVehicle _x } forEach units _drv; deleteVehicle _truck;
    } else {
        [_drv] call _claim;
        [_center, _radius, _spawnPos, _truck, _drv, _aboard] spawn _leanDispatch;
    };
    _out
};

// Shared with the win-time retreat: the wave loop mutates these in place (arrays pass by reference).
private _waveGroups = [];
private _vehGroups = [];

// Wave controller: fill toward the budget on a deep dip (< 60 %) or the 5-minute heartbeat. Vehicles
// drive in from the far side; infantry ride the truck to the debus.
[_targetpos, _budget, _vehSubCap, _defendVar, _claim, _deliverSquads, _leanDispatch, _waveGroups, _vehGroups] spawn {
    params ["_center", "_budget", "_vehSubCap", "_defendVar", "_claim", "_deliverSquads", "_leanDispatch", "_waveGroups", "_vehGroups"];
    private _fnLive = { { ({ alive _x } count units _x) > 0 } count _this };
    private _lastWave = -1e9;
    while { missionNamespace getVariable [_defendVar, false] } do {
        private _live = _waveGroups call _fnLive;
        if (_live < 0.6 * _budget || { time - _lastWave >= 300 }) then {
            _lastWave = time;
            private _spawnPos = [_center, RADIUS] call DUWS_fnc_garrisonReservePos;
            private _vehLive = _vehGroups call _fnLive;
            private _pending = [];
            for "_slot" from 1 to (_budget - _live) do {
                private _fieldableVeh = ["car", "apc", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
                if ((_vehLive < _vehSubCap) && { _fieldableVeh isNotEqualTo [] } && { random 1 < 0.4 }) then {
                    private _cls = [selectRandom _fieldableVeh] call DUWS_fnc_tokenClass;
                    if (_cls != "") then {
                        private _g = [_cls, _center, RADIUS, "hunt", _spawnPos, "opfor"] call fnc_spawn_vehicle;
                        if (!isNull _g) then { [_g] call _claim; _waveGroups pushBack _g; _vehGroups pushBack _g; _vehLive = _vehLive + 1 };
                    };
                } else {
                    _pending pushBack (selectRandom ["team", "wp_team", "squad", "recon"]);
                };
            };
            if (_pending isNotEqualTo []) then {
                { _waveGroups pushBack _x } forEach ([_center, RADIUS, _spawnPos, _pending, _claim] call _deliverSquads);
            };
        };
        sleep 5;
    };
};

// Abandon: no BLUFOR in the ring for 20 continuous seconds kills the informant (same killed loss);
// warning hint loops while breached, cancelled the instant any BLUFOR re-enters.
[_inf, _targetpos, _defendVar] spawn {
    params ["_inf", "_center", "_defendVar"];
    private _breach = -1;
    while { (missionNamespace getVariable [_defendVar, false]) && { alive _inf } } do {
        uiSleep 2;
        if ([_center, RADIUS, 1] call fnc_duws_bluforNear) then {
            _breach = -1;
        } else {
            if (_breach < 0) then { _breach = time };
            private _left = ABANDON_TIME - (time - _breach);
            if (_left <= 0) exitWith { _inf setDamage 1 };
            [format [localize "STR_DUWS_T_pc_abandon", ceil _left]] remoteExec ["hint", [0, -2] select isDedicated];
        };
    };
};

private _defendEnd = time + DEFEND_TIME;
waitUntil { sleep 2; !alive _inf || { time >= _defendEnd } };

missionNamespace setVariable [_defendVar, false];
missionNamespace setVariable [_liveVar, false];
if (!isNull DUWS_pc_crate) then { DUWS_pc_crate setVariable ["R3F_LOG_CF_credits", 0, true] };   // halt building
DUWS_pc_informant = objNull; publicVariable "DUWS_pc_informant";
DUWS_pc_crate = objNull; publicVariable "DUWS_pc_crate";

if (!alive _inf) exitWith {
    [_mission_name, _tn, "FAILED", _targetpos, RADIUS, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pc_killed"], false, "mission_protect_civ", false, false] call fnc_mission_finish;
};

// Win. Surviving combat vehicles disengage to the nearest OPFOR-held zone (infantry keep hunting);
// REP to the nearest town, paid apart from finish's CP/AP.
{
    if (({ alive _x } count units _x) > 0) then {
        private _lead = leader _x;
        private _held = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
        private _dest = if (_held isNotEqualTo []) then {
            ([_held, [], { _lead distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0
        } else {
            _targetpos getPos [RADIUS + 800, _targetpos getDir (getPosATL _lead)]
        };
        for "_i" from ((count (waypoints _x)) - 1) to 0 step -1 do { deleteWaypoint [_x, _i] };
        _x setBehaviour "CARELESS";
        _x setSpeedMode "FULL";
        (_x addWaypoint [_dest, 0]) setWaypointType "MOVE";
    };
} forEach _vehGroups;

if (CIV_PRESENCE != "NONE") then {
    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _idx = -1; private _best = 1e9;
    { private _d = (getPos _x) distance2D _targetpos; if (_d < _best) then { _best = _d; _idx = _forEachIndex } } forEach _locs;
    if (_idx >= 0) then { [_idx, DUWS_curReward select 2, "protect_civ_success"] call fnc_town_rep_adjust };
};

[_mission_name, _tn, "SUCCEEDED", _targetpos, RADIUS, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pc_win"], true, "mission_protect_civ", false, false] call fnc_mission_finish;
