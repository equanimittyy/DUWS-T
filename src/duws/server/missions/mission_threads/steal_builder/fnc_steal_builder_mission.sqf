// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

// Ahead of fnc_mission_begin, so the aborted mission claims no reward, deadline or token. begin also
// stamps the rest timer; since it never runs here, stamp it by hand so aborting still spends this
// cycle and the next mission offer waits out the rest instead of the abort being free to spam.
if (!isNil "BLD1" && {alive BLD1}) exitWith {
    [{hint localize "STR_DUWS_T_mfxb090t"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    DUWS_lastMissionStartDate = dateToNumber date;
    publicVariable "DUWS_lastMissionStartDate";
    ["INFO", "MISSION", "steal_builder refused: previous builder still alive"] call fnc_log;
};

if (!([6, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_ALLSEER";
_message = localize "STR_DUWS_T_builderspot";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_message1 = ([localize "STR_DUWS_T_buildertask"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_builderfail"] call fnc_cs);
_message3 = ([localize "STR_DUWS_T_builderwin"] call fnc_cs);


_radius = 600;

private _site = [_MissionPos, _radius, 6] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_czpvn5z1", _mission_name, _randomPos, "getin"] call fnc_missionTaskCreate;

_vehpos = _targetpos;


// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_bld1 = opfor_REPAIR_TRUCK_X createVehicle (_vehPos);
[_bld1, "mission_steal_builder"] call fnc_duws_keep;
_Varname = "BLD1";
_bld1 SetVehicleVarName _VarName;
_bld1 Call Compile Format ["%1=_This ; PublicVariable ""%1""",_VarName];

_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;

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

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 3;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

sleep 5; // let the patrols finish spawning


waitUntil {sleep 2; (!alive BLD1 || (BLD1 distance PosOfBLUHQ)<100 || time > _deadline)};

[_markername2] call fnc_missionMarkerClear;

if (!alive BLD1) exitWith {
    [_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_targetpos,_radius, "mission_steal_builder"] call fnc_mission_end;
};

if (alive BLD1 && (BLD1 distance PosOfBLUHQ) >= 100 && time > _deadline) exitWith {
    [_VARtaskgeneratedName, "", "mission_steal_builder", _targetpos, _radius, false, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_builderdeadline"]] call fnc_mission_deadline_fail;
};

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
[_speaker1, _message3] remoteExec ["fnc_duws_dialogue", 0];

_init_code = {
    waitUntil {!isNil "BLD1"};
    [BLD1, -1, west, "LIGHT"] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
    [BLD1, "mil_triangle", "ColorBlue", "2", "2", "BLD-V"] call kndr_assignMarker;
};
[[[], _init_code], "BIS_fnc_spawn", true, true] spawn BIS_fnc_MP;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;

[_targetpos,_radius, "mission_steal_builder"] call fnc_mission_end;
