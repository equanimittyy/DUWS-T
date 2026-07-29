// Locality: server; the addAction/trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([4, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

// ==================== 定义所有辅助函数（确保在所有机器上执行）====================
private _fncScript = {
    if (isNil "DUWS_fnc_addCarryAction") then {
        // ---------- 自动放下飞行员（无动画，用于进入载具时触发） ----------
        DUWS_fnc_autoDropPilot = {
            params ["_caller", "_pilot"];
            if (isNull _caller || isNull _pilot) exitWith {};

            private _dropAction = _caller getVariable ["dropAction", -1];
            if (_dropAction != -1) then { _caller removeAction _dropAction; };
            private _putAction = _caller getVariable ["putInVehicleAction", -1];
            if (_putAction != -1) then { _caller removeAction _putAction; };
            
            detach _pilot;
            _pilot setPos (_caller getPos [1.5, getDir _caller + 180]);
            [_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
            _pilot enableAI "ALL";
            _pilot disableAI "PATH";
            _pilot setVariable ["isCarried", false, true];
            _pilot setVariable ["carrier", nil, true];
            _caller setVariable ["carriedPilot", nil, true];
            _caller setVariable ["dropAction", nil];
            _caller setVariable ["putInVehicleAction", nil];

            [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
            [_pilot] spawn {
                params ["_pilot"];
                sleep 0.5;
                [_pilot] remoteExec ["DUWS_fnc_addCarryAction", 0];
            };
        };

        // ---------- 放下飞行员（到地上，含动画） ----------
        DUWS_fnc_dropPilot = {
            params ["_caller", "_pilot"];
            private _dropAction = _caller getVariable ["dropAction", -1];
            if (_dropAction != -1) then { _caller removeAction _dropAction; };
            private _putAction = _caller getVariable ["putInVehicleAction", -1];
            if (_putAction != -1) then { _caller removeAction _putAction; };
            _speaker = localize "STR_DUWS_T_actionteam";
            _message = localize "STR_DUWS_T_stayhere";
            [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
            
            [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
            sleep 1.5;
            detach _pilot;
            _pilot setPos (_caller modelToWorld [0, 2, 0]);
            [_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
            _pilot enableAI "ALL";
            _pilot disableAI "PATH";
            _pilot setVariable ["isCarried", false, true];
            _pilot setVariable ["carrier", nil, true];
            [_caller, ""] remoteExec ["switchMove", 0];
            _caller setVariable ["carriedPilot", nil, true];
            _caller setVariable ["dropAction", nil];
            _caller setVariable ["putInVehicleAction", nil];
            
            [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
            [_pilot] spawn {
                params ["_pilot"];
                sleep 0.5;
                [_pilot] remoteExec ["DUWS_fnc_addCarryAction", 0];
            };
        };

        // ---------- 将飞行员放入载具（客户端入口，请求服务器执行） ----------
        DUWS_fnc_putInVehicle = {
            params ["_caller", "_pilot"];
            private _vehicle = cursorTarget;
            if (isNull _vehicle || !(_vehicle isKindOf "AllVehicles") || _vehicle == _caller) then {
                private _nearVehicles = nearestObjects [_caller, ["Car","Tank","Helicopter","Ship"], 5];
                if (count _nearVehicles > 0) then {
                    _vehicle = _nearVehicles select 0;
                } else {
                    hint localize "STR_DUWS_T_no_vehicle_near";
                    breakOut "";
                };
            };

            [_caller, _pilot, _vehicle] remoteExec ["DUWS_fnc_serverPutInVehicle", 2];
        };

        // ---------- 从载具中取出飞行员（客户端入口，请求服务器执行） ----------
        DUWS_fnc_takeOutFromVehicle = {
            params ["_caller", "_pilot"];
            private _vehicle = _pilot getVariable ["inVehicle", objNull];
            if (isNull _vehicle) exitWith {};

            [_caller, _pilot, _vehicle] remoteExec ["DUWS_fnc_serverTakeOutFromVehicle", 2];
        };

        // ---------- 服务器端：实际放入载具 ----------
        DUWS_fnc_serverPutInVehicle = {
            params ["_caller", "_pilot", "_vehicle"];
            if (isNull _vehicle || isNull _pilot || isNull _caller) exitWith {};

            if (_pilot getVariable ["carrier", objNull] != _caller) exitWith {
                [_caller, localize "STR_DUWS_T_cant_put_not_carried"] remoteExec ["hint", _caller];
            };
            if (vehicle _pilot != _pilot) exitWith {
                [_caller, localize "STR_DUWS_T_pilot_already_in_vehicle"] remoteExec ["hint", _caller];
            };

            private _hasSeat = false;
            private _seatType = "";
            if (_vehicle emptyPositions "cargo" > 0) then {
                _hasSeat = true;
                _seatType = "cargo";
                _pilot moveInCargo _vehicle;
            } else {
                if (_vehicle emptyPositions "commander" > 0) then {
                    _hasSeat = true;
                    _seatType = "commander";
                    _pilot moveInCommander _vehicle;
                } else {
                    if (_vehicle emptyPositions "gunner" > 0) then {
                        _hasSeat = true;
                        _seatType = "gunner";
                        _pilot moveInGunner _vehicle;
                    };
                };
            };

            if (!_hasSeat) exitWith {
                [_caller, localize "STR_DUWS_T_no_available_seat"] remoteExec ["hint", _caller];
            };

            sleep 0.5;

            if (vehicle _pilot != _vehicle) then {
                switch (_seatType) do {
                    case "cargo": { _pilot moveInCargo _vehicle; };
                    case "commander": { _pilot moveInCommander _vehicle; };
                    case "gunner": { _pilot moveInGunner _vehicle; };
                };
                sleep 0.5;
            };

            if (vehicle _pilot != _vehicle) exitWith {
                [_caller, localize "STR_DUWS_T_failed_put_vehicle"] remoteExec ["hint", _caller];
            };

            detach _pilot;
            _pilot setVariable ["isCarried", false, true];
            _pilot setVariable ["carrier", nil, true];
            _pilot setVariable ["inVehicle", _vehicle, true];
            _pilot disableAI "ALL";
            _speaker = localize "STR_DUWS_T_actionteam";
            _message = localize "STR_DUWS_T_pilotinveh";
            [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

            [_caller] remoteExec ["DUWS_fnc_clearCarrierActions", _caller];
            [_vehicle] remoteExec ["DUWS_fnc_addVehicleTakeOutAction", 0];
        };

        // ---------- 服务器端：实际从载具取出（优化版：取消下车动画） ----------
        DUWS_fnc_serverTakeOutFromVehicle = {
            params ["_caller", "_pilot", "_vehicle"];
            if (isNull _vehicle || isNull _pilot || isNull _caller) exitWith {};

            if (vehicle _pilot != _vehicle) exitWith {
                [_caller, localize "STR_DUWS_T_pilot_not_in_vehicle"] remoteExec ["hint", _caller];
            };
            if (!isNull (_caller getVariable ["carriedPilot", objNull])) exitWith {
                [_caller, localize "STR_DUWS_T_already_carrying_other"] remoteExec ["hint", _caller];
            };

            _pilot setVariable ["inVehicle", nil, true];

            moveOut _pilot;

            private _timeout = time + 0.5;
            waitUntil { vehicle _pilot == _pilot || time > _timeout };

            if (vehicle _pilot != _pilot) then {
                _pilot setPos (_caller modelToWorld [0, 1.5, 0]);
            };

            [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
            sleep 2;
            if (!alive _pilot) exitWith {
                [_caller, ""] remoteExec ["switchMove", 0];
            };
            [_caller, "AcinPercMstpSrasWrflDnon"] remoteExec ["switchMove", 0];
            _speaker = localize "STR_DUWS_T_actionteam";
            _message = localize "STR_DUWS_T_comeonout";
            [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

            _pilot attachTo [_caller, [0.17,0.1,0.11]];
            [_pilot, -180] remoteExec ["setDir", 0];
            [_pilot, "AinjPfalMstpSnonWnonDf_carried_dead"] remoteExec ["switchMove", 0];
            _pilot disableAI "ALL";

            _pilot setVariable ["isCarried", true, true];
            _pilot setVariable ["carrier", _caller, true];
            _pilot setVariable ["inVehicle", nil, true];
            _caller setVariable ["carriedPilot", _pilot, true];

            [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
            [_caller, _pilot] remoteExec ["DUWS_fnc_addCarrierActions", _caller];

            if (!isNull _vehicle) then {
                [_vehicle] remoteExec ["DUWS_fnc_removeVehicleTakeOutAction", 0];
            };
        };

        // ---------- 为携带者添加放下/放入动作及自动放下监控 ----------
        DUWS_fnc_addCarrierActions = {
            params ["_caller", "_pilot"];
            if (!alive _caller || !alive _pilot) exitWith {};
            
            private _oldDrop = _caller getVariable ["dropAction", -1];
            if (_oldDrop != -1) then { _caller removeAction _oldDrop; };
            private _oldPut = _caller getVariable ["putInVehicleAction", -1];
            if (_oldPut != -1) then { _caller removeAction _oldPut; };
            private _oldHandle = _caller getVariable ["carryAutoDropHandle", scriptNull];
            if (!isNull _oldHandle) then { terminate _oldHandle; };
            
            private _autoDropHandle = [_caller, _pilot] spawn {
                params ["_caller", "_pilot"];
                while {!isNull _caller && alive _caller && !isNull (_caller getVariable ["carriedPilot", objNull])} do {
                    if (vehicle _caller != _caller) then {
                        [_caller, _pilot] call DUWS_fnc_autoDropPilot;
                        hint localize "STR_DUWS_T_auto_drop_hint";
                    };
                    sleep 0.5;
                };
            };
            _caller setVariable ["carryAutoDropHandle", _autoDropHandle];
            
            private _dropAction = _caller addAction [
                localize "STR_DUWS_T_drop_pilot",
                {
                    params ["_target", "_caller", "_actionId"];
                    private _pilot = _target getVariable ["carriedPilot", objNull];
                    if (isNull _pilot) exitWith {};
                    [_caller, _pilot] call DUWS_fnc_dropPilot;
                },
                [],
                40, true, true, "", "player == _target", 5
            ];
            _caller setVariable ["dropAction", _dropAction];
            
            private _putInVehicleAction = _caller addAction [
                localize "STR_DUWS_T_put_in_vehicle",
                {
                    params ["_target", "_caller", "_actionId"];
                    private _pilot = _target getVariable ["carriedPilot", objNull];
                    if (isNull _pilot) exitWith {};
                    [_caller, _pilot] call DUWS_fnc_putInVehicle;
                },
                [],
                40, true, true, "",
                "player == _target && !isNull (_target getVariable ['carriedPilot', objNull]) && {alive (_target getVariable ['carriedPilot', objNull])} && {count (nearestObjects [_target, ['Car','Tank','Helicopter','Ship'], 5]) > 0}",
                5
            ];
            _caller setVariable ["putInVehicleAction", _putInVehicleAction];
        };

        // ---------- 清除携带者身上的所有动作 ----------
        DUWS_fnc_clearCarrierActions = {
            params ["_caller"];
            private _dropAction = _caller getVariable ["dropAction", -1];
            if (_dropAction != -1) then { _caller removeAction _dropAction; };
            private _putAction = _caller getVariable ["putInVehicleAction", -1];
            if (_putAction != -1) then { _caller removeAction _putAction; };
            
            private _autoDropHandle = _caller getVariable ["carryAutoDropHandle", scriptNull];
            if (!isNull _autoDropHandle) then { terminate _autoDropHandle; };
            _caller setVariable ["carryAutoDropHandle", nil];
            
            _caller setVariable ["carriedPilot", nil, true];
            [_caller, ""] remoteExec ["switchMove", 0];
            _caller setVariable ["dropAction", nil];
            _caller setVariable ["putInVehicleAction", nil];
        };

        // ---------- 为飞行员添加背起动作（修改：立即移除动作） ----------
        DUWS_fnc_addCarryAction = {
            params ["_pilot"];
            if (!alive _pilot) exitWith {};
            if (_pilot getVariable ["isCarried", false]) exitWith {};

            [_pilot, {
                params ["_pilot"];
                if (!isNil {_pilot getVariable "carryActionAdded"}) exitWith {};
                _pilot setVariable ["carryActionAdded", true];
                private _actionID = _pilot addAction [
                    localize "STR_DUWS_T_carry_pilot",
                    {
                        params ["_target", "_caller", "_actionId"];
                        if (_target getVariable ["isCarried", false]) exitWith {};
                        if (!alive _target) exitWith {};
                        _speaker = localize "STR_DUWS_T_actionteam";
                        _message = localize "STR_DUWS_T_i_got_u";
                        [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
                        
                        [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
                        
                        // 立即移除飞行员身上的背起动作，防止其他玩家在动画过程中再次点击
                        [_target] remoteExec ["DUWS_fnc_removeCarryAction", 0];
                        
                        sleep 2;
                        if (!alive _target || _target getVariable ["isCarried", false]) exitWith {
                            [_caller, ""] remoteExec ["switchMove", 0];
                        };
                        [_caller, "AcinPercMstpSrasWrflDnon"] remoteExec ["switchMove", 0];
                        
                        _target setVariable ["isCarried", true, true];
                        _target setVariable ["carrier", _caller, true];
                        _target attachTo [_caller, [0.17,0.1,0.11]];
                        [_target, -180] remoteExec ["setDir", 0];
                        [_target, "AinjPfalMstpSnonWnonDf_carried_dead"] remoteExec ["switchMove", 0];
                        _target disableAI "ALL";

                        [_caller, _target] remoteExec ["DUWS_fnc_addCarrierActions", _caller];
                        
                        _caller setVariable ["carriedPilot", _target, true];
                    },
                    [],
                    40, true, true, "",
                    "!isNull _target && {!(_target getVariable ['isCarried', false])} && {alive _target} && {(_this distance _target) < 2.5}",
                    5
                ];
                _pilot setVariable ["carryActionID", _actionID];
            }] remoteExec ["call", 0, true];
        };

        // ---------- 移除飞行员身上的背起动作 ----------
        DUWS_fnc_removeCarryAction = {
            params ["_pilot"];
            if (isNull _pilot) exitWith {};
            private _carryActionID = _pilot getVariable ["carryActionID", -1];
            if (_carryActionID != -1) then {
                _pilot removeAction _carryActionID;
                _pilot setVariable ["carryActionID", nil];
            };
            _pilot setVariable ["carryActionAdded", nil];
        };

        // ---------- 为载具添加"背出飞行员"动作 ----------
        DUWS_fnc_addVehicleTakeOutAction = {
            params ["_vehicle"];
            if (isNull _vehicle) exitWith {};
            if (!isNil {_vehicle getVariable "takeOutActionAdded"}) exitWith {};
            _vehicle setVariable ["takeOutActionAdded", true];
            private _actionID = _vehicle addAction [
                localize "STR_DUWS_T_take_out_pilot",
                {
                    params ["_target", "_caller", "_actionId"];
                    private _pilot = missionNamespace getVariable ["currentMissionPilot", objNull];
                    if (isNull _pilot) exitWith {};
                    if (!alive _pilot) exitWith { hint localize "STR_DUWS_T_pilot_dead"; };
                    if (_pilot getVariable ["inVehicle", objNull] != _target) exitWith {};
                    if (!isNull (_caller getVariable ["carriedPilot", objNull])) exitWith { hint localize "STR_DUWS_T_already_carrying_other"; };
                    [_caller, _pilot] call DUWS_fnc_takeOutFromVehicle;
                },
                [],
                40, true, true, "", "vehicle _this == _this", 5
            ];
            _vehicle setVariable ["takeOutActionID", _actionID];
        };

        // ---------- 移除载具上的"背出飞行员"动作 ----------
        DUWS_fnc_removeVehicleTakeOutAction = {
            params ["_vehicle"];
            if (isNull _vehicle) exitWith {};
            private _takeActionID = _vehicle getVariable ["takeOutActionID", -1];
            if (_takeActionID != -1) then {
                _vehicle removeAction _takeActionID;
                _vehicle setVariable ["takeOutActionID", nil];
            };
            _vehicle setVariable ["takeOutActionAdded", nil];
        };

        // ---------- 清理所有与飞行员相关的动作和动画 ----------
        DUWS_fnc_cleanupPilotActions = {
            params ["_pilot"];
            if (isNull _pilot) exitWith {};
            private _carrier = _pilot getVariable ["carrier", objNull];
            if (!isNull _carrier) then {
                [_carrier] call DUWS_fnc_clearCarrierActions;
            };
            private _vehicle = _pilot getVariable ["inVehicle", objNull];
            if (!isNull _vehicle) then {
                [_vehicle] call DUWS_fnc_removeVehicleTakeOutAction;
            };
            [_pilot] call DUWS_fnc_removeCarryAction;
            _pilot setVariable ["isCarried", false, true];
            _pilot setVariable ["carrier", nil, true];
            _pilot setVariable ["inVehicle", nil, true];
        };
    };
};

call _fncScript;
[_fncScript] remoteExec ["call", 0, true];

// ==================== 任务脚本主体 ====================
_radius = 300;
_cpreward = 25;
_apreward = 45;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_pilot_downed";
_message = localize "STR_DUWS_T_pilotletsdothis";
_message1 = localize "STR_DUWS_T_pilotfound";
_message2 = localize "STR_DUWS_T_pilotend";

_taskTimeout_approach = 600;
_missionStartTime = time;
_hasShown2MinHint = false;

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "pilot";
_markerText2 = localize "STR_DUWS_T_c4";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failsafe > 10 && _Posfound == false) exitWith {
    Mission_available = true; 
    publicVariable "Mission_available"; 
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_vehPos = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

_spawnPos = _targetpos;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 75;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;

sleep 1;
[_spawnPos, _radius] spawn fnc_missionPatrols;
_choppa = "";
switch (VERSION_X) do {
    case "MODERN": {
        _choppa = "Land_Wreck_Heli_Attack_01_F" createVehicle (_vehPos);
        [_choppa, "mission_rescue_pilot"] call fnc_duws_keep;
    };
};
_group = [ [_vehPos select 0, (_vehPos select 1)+2], WEST, [blufor_HELI_PILOT_X] ] call BIS_fnc_spawnGroup;
_pilot = units _group select 0;
_group deleteGroupWhenEmpty true;
_pilot setcaptive true; 
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
removeAllItems _pilot;
_pilot setDamage 0.8;
_pilot disableAI "PATH";

// 添加死亡事件处理器，当飞行员死亡时，立即清除携带者身上的动作
_pilot addEventHandler ["Killed", {
    params ["_unit", "_killer"];
    private _carrier = _unit getVariable ["carrier", objNull];
    if (!isNull _carrier) then {
        [_carrier] remoteExec ["DUWS_fnc_clearCarrierActions", 0];
    };
    [_unit] remoteExec ["DUWS_fnc_removeCarryAction", 0];
}];

missionNamespace setVariable ["currentMissionPilot", _pilot];
publicVariable "currentMissionPilot";

[_pilot] call DUWS_fnc_addCarryAction;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[west, [_VARtaskgeneratedName], 
[localize "STR_DUWS_T_njsu8ofz", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate; 

pilot_west_close = false;
_trg=createTrigger["EmptyDetector",_choppa];
_trg setTriggerArea[50,50,0,false];
_trg setTriggerActivation["WEST","PRESENT",false];
_trg setTriggerStatements["this","pilot_west_close = true;", ""];
_trg setTriggerTimeout [10, 10, 10, true ];  

// ========== 统计初始敌军数量 ==========
sleep 5; // 等待巡逻队生成完毕
private _nearbyEnemies = _targetpos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius * 1.5] select { side _x == EAST };
private _initialEnemyCount = count _nearbyEnemies;
missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
missionNamespace setVariable [_triggeredVar, false, true];
["INFO", "ZONES", format ["%1: Initial enemy count = %2", _mission_name, _initialEnemyCount]] call fnc_log;

// ========== 启动直升机增援监控 ==========
[_targetpos, _radius, _initialCountVar, _triggeredVar, _VARtaskgeneratedName] spawn fnc_opf_heli_reinforce;
// ======================================

waitUntil {
    sleep 1; 
    if ((time - _missionStartTime) >= (_taskTimeout_approach - 120) && !_hasShown2MinHint) then {
        [{hint localize "STR_DUWS_T_fxyys123"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
        _hasShown2MinHint = true;
    };
    pilot_west_close || !(alive _pilot) || (time - _missionStartTime) > _taskTimeout_approach
};

#define CLEANUP_PILOT(pilot) \
    [pilot] call DUWS_fnc_cleanupPilotActions; \
    [pilot] remoteExec ["DUWS_fnc_cleanupPilotActions", 0];
if (!pilot_west_close && (time - _missionStartTime) > _taskTimeout_approach) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    deleteMarker str(_markername2);
    deleteMarker str(_markername);
    _pilot setDamage 1;
    [{hint localize "STR_DUWS_T_fxysw123"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius, "mission_rescue_pilot"] spawn fnc_mission_cleanup;
};

if (!(alive _pilot)) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    deleteMarker str(_markername2);
    deleteMarker str(_markername);
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius, "mission_rescue_pilot"] spawn fnc_mission_cleanup;   
};

_trigger = player1;
if (isMultiplayer) then {
    _nearestUnits = nearestObjects [_pilot,["Man"],150];
    { if (_x in _nearestUnits) then {_trigger = _x}; } forEach call BIS_fnc_ListPlayers;   
};

sleep 5;
_pilot setcaptive false;
_pilot disableAI "PATH";
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

sleep 55;

waitUntil {sleep 1; (_pilot distance PosOfBLUHQ)<50 OR !(alive _pilot)};

if (!(alive _pilot)) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    deleteMarker str(_markername2);
    deleteMarker str(_markername);
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius, "mission_rescue_pilot"] spawn fnc_mission_cleanup;
};

deleteMarker str(_markername2);
deleteMarker str(_markername);

if (!isNull attachedTo _pilot) then {
    detach _pilot;
    CLEANUP_PILOT(_pilot);
};

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
sleep 1;

[_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
deleteVehicle _pilot;
missionNamespace setVariable ["currentMissionPilot", nil];
publicVariable "currentMissionPilot";
sleep 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_pilotend2"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius, "mission_rescue_pilot"] spawn fnc_mission_cleanup;

// Guaranteed, and called rather than spawned into a client function: completing the mission is
// the gate, and the shape this replaces rolled a chance from a server thread through a function
// that began `if (!hasInterface) exitWith {}`, so on a dedicated server the reward evaporated.
// The mission site stands in for the earner's position: a server thread has no one player to ask,
// and this is the ground the rescue was fought over.
if (hardcore_mode_enable) then {[_targetpos] call fnc_intel_payout};