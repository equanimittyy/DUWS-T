// Locality: server -- callers remoteExec to target 2.
// Kill the HVT (the officer, unit 0 of the spawned group). The APC and camo-net props are set
// dressing kept alive so the abandoned-vehicle collector cannot delete the objective mid-mission;
// they are released with the composition on end. Shared spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];

    private _vehpos = [_targetpos, 10, 30, 10, 0, 0.1, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
    sleep 1;
    [_targetpos, _radius] spawn fnc_missionPatrolswithintel;

    private _apc = opfor_APC1_X createVehicle _vehpos;
    [_apc, "mission_target_hvt"] call fnc_duws_keep;

    private _static1 = "";
    private _static2 = "";
    private _static3 = "";
    switch (VERSION_X) do {
        case "MODERN": {
            _static1 = "VirtualReammoBox_camonet_F";
            _static2 = "CargoNet_01_barrels_F";
            _static3 = "CamoNet_INDP_open_F";
        };
    };
    private _obj1 = createVehicle [_static1, [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
    [_obj1, "mission_target_hvt"] call fnc_duws_keep;
    sleep 1;
    private _obj2 = createVehicle [_static2, [(_targetpos select 0)-2, (_targetpos select 1)-2], [], 0, "CAN_COLLIDE"];
    [_obj2, "mission_target_hvt"] call fnc_duws_keep;
    sleep 1;
    private _obj3 = createVehicle [_static3, _targetpos, [], 0, "CAN_COLLIDE"];
    [_obj3, "mission_target_hvt"] call fnc_duws_keep;
    sleep 1;

    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

    private _group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_OPERATOR_X, opfor_MARK_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    [_group] call fnc_mission_claim;
    private _target = units _group select 0;

    [_target] spawn { params ["_unit"]; sleep 5; _unit addHeadgear "H_Beret_blk" };
    [_target] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };

    private _wp = _group addWaypoint [_vehpos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];

    _wp = _group addWaypoint [_targetpos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];

    // _Building may be an array when no building was found; skip the waypoint then.
    if (_Building isEqualType objNull) then {
        _wp = _group addWaypoint [getpos _Building, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointTimeout [30, 45, 60];
    } else {
        ["WARN", "MISSION", "_Building is not an object, skipping waypoint."] call fnc_log;
    };

    private _wp2 = _group addWaypoint [[(_targetpos select 0)+10, (_targetpos select 1)+10], 0];
    _wp2 setWaypointType "CYCLE";
    _wp2 setWaypointBehaviour "SAFE";
    _wp2 setWaypointTimeout [30, 45, 60];

    [_group, "combat"] call fnc_search_flag_group;
    { [_x] call fnc_addRandomLoot } forEach units _group;

    [_target]
};

private _spec = [
    2, 600, "kill", "STR_DUWS_T_19ajhe1d", "STR_DUWS_T_c2", "rescue",
    _build,
    { params ["_target"]; !alive _target },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hvtletsdothis", 8], ["STR_DUWS_T_Viper", "STR_DUWS_T_hvtseen", 0]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hvtend"],
    "mission_target_hvt"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
