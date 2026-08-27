// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([14, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 600;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speakerIDAP = localize "STR_DUWS_T_IDAP";
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam  = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_idapletsdothis";
_message1 = ([localize "STR_DUWS_T_idapcopy"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_idapacteamgo"] call fnc_cs);
_message3 = localize "STR_DUWS_T_idapend";
_markerText2 = localize "STR_DUWS_T_c14";

private _site = [_MissionPos, _radius, 14] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_transIDAP", _mission_name, _randomPos, "truck"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_vehPos = _targetpos;


_truck1 = "C_Truck_02_transport_F" createVehicle (_vehpos);
[_truck1, "mission_transport_idap"] call fnc_duws_keep;

_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        _box2 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        { [_x, "mission_transport_idap"] call fnc_duws_keep; } forEach [_box1, _box2];
        _box1 attachTo [_truck1,[0,-0.5,0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1,[0,-2.2,0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;

// Vehicle guards
_group = ["team", _vehPos, _radius, "none", _vehPos] call fnc_spawn_team;
[_group] call fnc_mission_claim;

// CREATE PATROLS
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private _targetDeliveryPos = [];
private _deliveryMarkerName = format ["delivery_%1", floor random 10000];
private _minDist = 1000;
private _maxDist = 2000;
private _attempts = 0;
while {_attempts < 100 && _targetDeliveryPos isEqualTo []} do {
    _targetDeliveryPos = [_MissionPos, _minDist, _maxDist, 1, 0, 20, 0] call BIS_fnc_findSafePos;
    _attempts = _attempts + 1;
};
if (_targetDeliveryPos isEqualTo []) then {
    private _dir = random 360;
    private _dist = _minDist + random (_maxDist - _minDist);
    _targetDeliveryPos = [_MissionPos, _dist, _dir] call BIS_fnc_relPos;
};

_deliveryMarkerName = format ["civ_marker_%1", round(time + random 1000)];
createMarker [_deliveryMarkerName, _targetDeliveryPos];
_deliveryMarkerName setMarkerShape "ICON";
_deliveryMarkerName setMarkerType "o_unknown";
_deliveryMarkerName setMarkerColor "ColorGreen";
_deliveryMarkerName setMarkerText "IDAP";
_deliveryMarkerName setMarkerSize [1, 1];

_cleanupDelivery = {
    if (!isNil "_deliverySmokeScript") then { terminate _deliverySmokeScript; };
    if (!isNil "_smokeObjects") then { { deleteVehicle _x } forEach _smokeObjects; };
    if (!isNil "_groupDelivery") then { { deleteVehicle _x } forEach units _groupDelivery; deleteGroup _groupDelivery; };
};

_unitClasses = [
    "C_IDAP_Man_Aidworker_01_F",
    "C_IDAP_Man_Aidworker_02_F",
    "C_IDAP_Man_Aidworker_03_F",
    "C_IDAP_Man_Aidworker_04_F",
    "C_IDAP_Man_Aidworker_05_F",
    "C_IDAP_Man_Aidworker_06_F"
];
_groupUnits = [];
for "_i" from 1 to 5 do {
    _groupUnits pushBack (selectRandom _unitClasses);
};
_groupDelivery = [_targetDeliveryPos, civilian, _groupUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;

{
    private _offsetDist = 5 + random 3;
    private _offsetDir = random 360;
    private _newPos = _targetDeliveryPos getPos [_offsetDist, _offsetDir];
    _x setPos _newPos;
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    [_x] spawn {
        params ["_unit"];
        while {alive _unit} do {
            _unit switchmove "Acts_JetsShooterNavigate_loop_m";
            sleep 5;
        };
    };
} forEach units _groupDelivery;

_smokeObjects = [];
_deliverySmokeScript = [_targetDeliveryPos, _smokeObjects] spawn {
    params ["_pos", "_smokeObjects"];
    while {true} do {
        if (count _smokeObjects > 0) then {
            deleteVehicle (_smokeObjects select 0);
            _smokeObjects deleteAt 0;
        };
        _smoke = "SmokeShellGreen" createVehicle _pos;
        _smoke setPos _pos;
        _smokeObjects pushBack _smoke;
        sleep 30;
    };
};

[_speakerIDAP, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;

// TASK AND NOTIFICATION

sleep 5; // let the patrols finish spawning


waitUntil {
    sleep 2;
    (getdammage _truck1>0.95) || (_truck1 distance _targetDeliveryPos) < 50 || time > _deadline
};

[_markername2] call fnc_missionMarkerClear;

if (getdammage _truck1>0.95) exitWith {
    deleteMarker _deliveryMarkerName;
    call _cleanupDelivery;
    _truck1 setDamage 1;
    [{hint localize "STR_DUWS_T_jsg7ys0w"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    // Reputation is a civilian-system currency: skip its change when civilians are off. The
    // town is resolved from the delivery point, falling back to the global outside every radius.
    if (CIV_PRESENCE != "NONE") then {
        [[_targetpos] call fnc_civ_townAt, -5, "idap_failed"] call fnc_town_rep_adjust;
    };
    [_targetpos,_radius, "mission_transport_idap"] call fnc_mission_end;
};

if (time > _deadline && getdammage _truck1 <= 0.95 && (_truck1 distance _targetDeliveryPos) >= 50) exitWith {
    deleteMarker _deliveryMarkerName;
    call _cleanupDelivery;
    // TODO: give this mission a bespoke Overlord timeout-fail line instead of the generic notice.
    call fnc_mission_timeout_notice;
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    if (CIV_PRESENCE != "NONE") then {
        [[_targetpos] call fnc_civ_townAt, -5, "idap_deadline"] call fnc_town_rep_adjust;
    };
    [_targetpos,_radius, "mission_transport_idap"] call fnc_mission_end;
};

deleteMarker _deliveryMarkerName;
[_speakerIDAP, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
if (CIV_PRESENCE != "NONE") then {
    [[_targetpos] call fnc_civ_townAt, 5, "idap_success"] call fnc_town_rep_adjust;
};
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
sleep 8;
deleteVehicle _truck1;
call _cleanupDelivery;


[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius, "mission_transport_idap", true] call fnc_mission_end;
