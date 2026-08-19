// Locality: server -- callers remoteExec to target 2.
// Elimination: won by killing the tank commander (unit 0). The crippled tank is set dressing --
// spawned pre-damaged and kept alive so the abandoned-vehicle collector cannot remove the objective
// mid-mission. Released with the composition on end. Shared spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _vehpos = [_targetpos, 10, 30, 10, 0, 0.15, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
    [_targetpos, _radius] spawn fnc_missionPatrolswithintel;

    private _vehicle_1 = opfor_MBT_TANK1_X createVehicle _vehpos;
    [_vehicle_1, "mission_target_armor"] call fnc_duws_keep;
    _vehicle_1 setDamage 0.8;

    private _obj1 = createVehicle ["CamoNet_OPFOR_open_F", _targetpos, [], 0, "CAN_COLLIDE"];
    [_obj1, "mission_target_armor"] call fnc_duws_keep;
    private _obj2 = createVehicle ["Land_WoodenTable_large_F", [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
    [_obj2, "mission_target_armor"] call fnc_duws_keep;

    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

    private _group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_CREW_X, opfor_OPERATOR_X, opfor_ENG_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    [_group] call fnc_mission_claim;
    private _target = units _group select 0;

    if !(("OPTRE" in BLUFOR_FactionFile_X)
        or ("HL2ECR" in BLUFOR_FactionFile_X)
        or ("TIOW" in BLUFOR_FactionFile_X)) then {
        removeheadgear _target;
        _target addHeadgear "H_HelmetCrew_I";
    };

    if (hardcore_mode_enable) then {
        [[_target], "objective"] call fnc_search_flag_group;
    };

    private _wp = _group addWaypoint [_vehpos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];

    _wp = _group addWaypoint [_targetpos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];

    private _wp2 = _group addWaypoint [[(_targetpos select 0)+10, (_targetpos select 1)+10], 0];
    _wp2 setWaypointType "CYCLE";
    _wp2 setWaypointBehaviour "SAFE";
    _wp2 setWaypointTimeout [30, 45, 60];

    [_target] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };
    { [_x] call fnc_addRandomLoot } forEach units _group;

    [_target]
};

private _spec = [
    7, 200, "kill", "STR_DUWS_T_y7z1cx6j", "STR_DUWS_T_c7", "targetarmor",
    _build,
    { params ["_target"]; !alive _target },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorend"],
    "mission_target_armor"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
