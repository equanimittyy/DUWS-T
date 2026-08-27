// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).

params ["_MissionPos", "_mission_name"];
if (!([1, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 600;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_Signal2";
_message = localize "STR_DUWS_T_supplytruckletsdothis";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_message1 = ([localize "STR_DUWS_T_supplytruckoverlord"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_supplytruckfail"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c1";

private _site = [_MissionPos, _radius, 1] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_p7qawzl4", _mission_name, _randomPos, "getin"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

_vehPos = _targetpos;


// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_truck1 = opfor_TRANS_TRUCK_X createVehicle _vehPos;
[_truck1, "mission_steal_supply"] call fnc_duws_keep;
clearMagazineCargoGlobal _truck1;
clearWeaponCargoGlobal _truck1;
clearItemCargoGlobal _truck1;
clearBackpackCargoGlobal _truck1;

private _truckGetInEH = _truck1 addEventHandler ["GetIn", {
    params ["_vehicle", "_role", "_unit", "_turret"];
    if (isPlayer _unit) then {
        [{hint localize "STR_DUWS_T_fxkczy00"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    };
}];

_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "O_supplyCrate_F" createVehicle _vehPos;
        _box2 = "O_supplyCrate_F" createVehicle _vehPos;
        { [_x, "mission_steal_supply"] call fnc_duws_keep; } forEach [_box1, _box2];
        _box1 attachTo [_truck1, [0, -0.5, 0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1, [0, -2.2, 0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

clearMagazineCargoGlobal _box1;
clearWeaponCargoGlobal _box1;
clearItemCargoGlobal _box1;
clearBackpackCargoGlobal _box1;
clearMagazineCargoGlobal _box2;
clearWeaponCargoGlobal _box2;
clearItemCargoGlobal _box2;
clearBackpackCargoGlobal _box2;

_obj1 = createVehicle [_static1, [(_vehPos select 0)-12, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_steal_supply"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_steal_supply"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehPos select 0)-8, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_steal_supply"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_steal_supply"] call fnc_duws_keep;
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
sleep 8;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

sleep 5; // let the patrols finish spawning


waitUntil {
    sleep 1;
    (!alive _truck1) ||
    (_truck1 distance PosOfBLUHQ < 100) ||
    (time > _deadline)
};

[_markername2] call fnc_missionMarkerClear;

if (!alive _truck1 || time > _deadline) exitWith {
    _truck1 removeEventHandler ["GetIn", _truckGetInEH];
    _truck1 setDamage 1;
    [{hint localize "STR_DUWS_T_jsg7ys0w"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    [_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_targetpos, _radius, "mission_steal_supply"] call fnc_mission_end;
};

_truck1 removeEventHandler ["GetIn", _truckGetInEH];
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[{hint localize "STR_DUWS_T_po7fmmoa"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
[{hint localize "STR_DUWS_T_3jmpthvi"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

["opfor", [3, 2, 2, 2, 2]] call fnc_arsenal_reward;
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos, _radius, "mission_steal_supply"] call fnc_mission_end;
