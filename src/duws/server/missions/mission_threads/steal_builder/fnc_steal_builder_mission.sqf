// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

// Refuse a second builder while one still lives -- ahead of fnc_mission_run (which calls fnc_mission_begin),
// so the refused mission claims no reward, deadline or token. begin also stamps the rest timer; since it
// never runs here, stamp it by hand so aborting still spends this cycle and the next mission offer waits out
// the rest instead of the abort being free to spam.
if (!isNil "BLD1" && {alive BLD1}) exitWith {
    [{hint localize "STR_DUWS_T_mfxb090t"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    DUWS_lastMissionStartDate = dateToNumber date;
    publicVariable "DUWS_lastMissionStartDate";
    ["INFO", "MISSION", "steal_builder refused: previous builder still alive"] call fnc_log;
};

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];

    // The objective itself: kept for the mission's duration so the abandoned-vehicle clause cannot
    // collect it. A player who disables it and takes half an hour would otherwise find the thing they
    // were sent for gone, with no way left to finish. Published as the global BLD1 -- the R3F factory
    // init on win waits on it, and the next-offer gate above tests it.
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

private _spec = [
    6, 600, "getin", "STR_DUWS_T_czpvn5z1", "rescue",
    _build,
    { alive (_this) && ((_this) distance PosOfBLUHQ) < 100 },
    [["STR_DUWS_T_ALLSEER", "STR_DUWS_T_builderspot", 3], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_buildertask", 0]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderwin"],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderdeadline"],
    "mission_steal_builder",
    false,
    _onWin,
    [[{ !alive (_this) }, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderfail"]]]
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
