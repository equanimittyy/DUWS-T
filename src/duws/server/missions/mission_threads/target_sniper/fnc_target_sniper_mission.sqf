// Locality: server -- callers remoteExec to target 2.
// Kill both snipers (units 1 and 2 of the spawned group; unit 0 is their spotter/leader). No
// vehicle or kept props, so no composition key. Shared spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

    [_targetpos, 15] spawn { [(["patrol"] + _this) call fnc_spawn_team] call fnc_mission_claim };
    sleep 1;
    [_randomPos, _radius] spawn { [(["patrol"] + _this) call fnc_spawn_team] call fnc_mission_claim };
    sleep 1;
    [_randomPos, _radius] spawn { [(["team"] + _this) call fnc_spawn_team] call fnc_mission_claim };
    sleep 1;
    [_randomPos, _radius] spawn { [(["team"] + _this) call fnc_spawn_team] call fnc_mission_claim };

    private _group = [_targetpos, east, [opfor_SL_SOLDIER_X, opfor_SNIPER_SOLDIER_X, opfor_SNIPER_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    [_group] call fnc_mission_claim;
    private _target1 = units _group select 1;
    private _target2 = units _group select 2;

    [_target1] spawn { params ["_unit"]; sleep 5; _unit forceAddUniform "U_B_FullGhillie_sard" };
    [_target2] spawn { params ["_unit"]; sleep 5; _unit forceAddUniform "U_B_FullGhillie_sard" };
    [_target1] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };
    [_target2] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };

    if (hardcore_mode_enable) then {
        [[units _group select 0], "objective"] call fnc_search_flag_group;
    };

    if (VERSION_X == "MODERN") then {
        if !(("OPTRE" in BLUFOR_FactionFile_X)
            or ("HL2ECR" in BLUFOR_FactionFile_X)
            or ("TIOW" in BLUFOR_FactionFile_X)) then {
            removeheadgear _target1;
            removeheadgear _target2;
            _target1 addHeadgear "H_Shemag_khk";
            _target2 addHeadgear "H_Shemag_khk";
        };
    };

    [_group, _targetpos, _radius] call bis_fnc_taskPatrol;
    { [_x] call fnc_addRandomLoot } forEach units _group;

    [_target1, _target2]
};

private _spec = [
    5, 400, "kill", "STR_DUWS_T_16dh939j", "STR_DUWS_T_c5", "sniperhunt",
    _build,
    { params ["_target1", "_target2"]; !alive _target1 && !alive _target2 },
    [["STR_DUWS_T_Viper", "STR_DUWS_T_sniperletsdothis", 8]],
    ["STR_DUWS_T_Viper", "STR_DUWS_T_sniperend"]
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
