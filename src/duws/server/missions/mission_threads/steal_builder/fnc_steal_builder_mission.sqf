// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

// Refuse a second builder while one still lives -- ahead of fnc_mission_begin, so the refused mission
// claims no reward, deadline or token. begin never runs here, so stamp the rest timer by hand, or the
// abort would be free to spam the next offer.
if (!isNil "BLD1" && {alive BLD1}) exitWith {
    [{hint localize "STR_DUWS_T_mfxb090t"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    DUWS_lastMissionStartDate = dateToNumber date;
    publicVariable "DUWS_lastMissionStartDate";
    ["INFO", "MISSION", "steal_builder refused: previous builder still alive"] call fnc_log;
};

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];

    // Kept for the mission's duration so the abandoned-vehicle sweep cannot collect the prize while a
    // player takes their time. Published as the global BLD1 -- the R3F factory init on win waits on it,
    // and the next-offer gate above tests it.
    private _bld1 = opfor_REPAIR_TRUCK_X createVehicle _targetpos;
    [_bld1, "mission_steal_builder"] call fnc_duws_keep;
    BLD1 = _bld1;
    _bld1 setVehicleVarName "BLD1";
    publicVariable "BLD1";

    [_targetpos, "mission_steal_builder"] call fnc_mission_dressing;

    // Guard force: idle team on the prize, a close and two wide foot patrols, plus vehicle patrols that
    // scale with the enemy's earned AP -- DUWS_fnc_tokenClass returns "" for a token gated out at the
    // current tier, so a car joins from motorised (60 AP) and a second car-or-ifv from mechanised (150 AP).
    private _claim = { [_this] call fnc_mission_claim };
    (["team", _targetpos, _radius, "none", _targetpos] call fnc_spawn_team) call _claim;   // idle, on the objective
    (["team", _targetpos, _radius, "closepatrol"] call fnc_spawn_team) call _claim;
    for "_i" from 1 to 2 do { (["patrol", _targetpos, _radius, "widepatrol"] call fnc_spawn_team) call _claim; };
    private _car = ["car"] call DUWS_fnc_tokenClass;
    if (_car != "") then { ([_car, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
    if ((["ifv"] call DUWS_fnc_tokenClass) != "") then {
        private _cls = [selectRandom ["car", "ifv"]] call DUWS_fnc_tokenClass;
        if (_cls != "") then { ([_cls, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
    };

    _bld1
};

// On win: convert the recovered vehicle into an R3F mobile factory and pin its persistent BLD-V marker.
// Run via BIS_fnc_MP so the factory registers on every machine, not just the server.
private _onWin = {
    private _init_code = {
        waitUntil {!isNil "BLD1"};
        [BLD1, -1, west, "LIGHT"] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
        [BLD1, "mil_triangle", "ColorBlue", "2", "2", "BLD-V"] call kndr_assignMarker;
    };
    [[[], _init_code], "BIS_fnc_spawn", true, true] spawn BIS_fnc_MP;
};

// Win: the recovered builder vehicle reaches BLUFOR HQ intact. Early-lose: it is destroyed (the _done
// test requires it alive, so win and loss stay mutually exclusive).
private _done = { alive (_this) && ((_this) distance PosOfBLUHQ) < 100 };
private _lost = [[{ !alive (_this) }, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderfail"]]];

if (!([6, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 600;
private _site = [_MissionPos, _radius, 6, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["rescue%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_czpvn5z1", _mission_name, "getin",
    [["STR_DUWS_T_ALLSEER", "STR_DUWS_T_builderspot", 3], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_buildertask", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_buildercopy", 0]]
] call fnc_mission_present;

sleep 5; // let the guard force finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || (_lost findIf { _handles call (_x select 0) } >= 0) || time > _deadline };

// Loss ranked ahead of the timeout so a builder destroyed as the clock runs out reads as destroyed.
private _lostIdx = _lost findIf { _handles call (_x select 0) };
if (!(_handles call _done) && _lostIdx >= 0) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], (_lost select _lostIdx) select 1, false, "mission_steal_builder", false, false] call fnc_mission_finish;
};

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_steal_builder"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderwin"], true, "mission_steal_builder", false, false, _onWin, _handles] call fnc_mission_finish;
