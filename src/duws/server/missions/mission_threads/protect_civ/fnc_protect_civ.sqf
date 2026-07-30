// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([14, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ----- 任务参数 --------------------------------------------------------------
_searchRadius   = 250;      // 搜索建筑物半径
_spawnDist      = 230;      // 红方生成距离（边缘）
_timeLimit      = 360;      // 限定时间（秒）
_cpReward       = 20;       // 指挥点奖励
_apReward       = 0;        // 行动点奖励
_repReward      = 5;        // 成功时声望增加量

_speaker        = localize "STR_DUWS_T_OVERLORD";
_speakerinfomat = localize "STR_DUWS_T_infomat";
_speakeracteam  = localize "STR_DUWS_T_actionteam";
_message        = localize "STR_DUWS_T_pcletsdothis";
_messagewhoau   = localize "STR_DUWS_T_pcwhoau";
_messageiminfo  = localize "STR_DUWS_T_pciminfo";
_messageoverlord= ([localize "STR_DUWS_T_pcoverlord"] call fnc_cs);
_messageroger   = ([localize "STR_DUWS_T_pcroger"] call fnc_cs);
_message1       = localize "STR_DUWS_T_pcbequick";
_message2       = ([localize "STR_DUWS_T_pcend"] call fnc_cs);
_message3       = ([localize "STR_DUWS_T_pcfail"] call fnc_cs);

// ----- 1. 寻找合适的任务目标位置（含建筑物）--------------------------------

private _site = [_MissionPos, _searchRadius, 14] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// ----- 修改点：确保建筑物至少有4个建筑位置 -----
// A guard, not an else branch. The else this replaces announced the failure and handed the mission
// slot back, then fell through and built the civilian, the markers and the triggers on a null
// building anyway -- a mission the player was told had been cancelled, running while the campaign
// believed no mission was live. exitWith leaves the thread from here because if/then is transparent
// to it and nothing between this line and the thread body is a loop.
if (isNull _Building) exitWith {
    [14, "STR_DUWS_T_mission_no_building"] call fnc_mission_abort;
};

_buildingPositions = [_Building] call BIS_fnc_buildingPositions;
if (count _buildingPositions < 4) then {
    // 需要寻找附近其他建筑物
    private _nearbyBuildings = nearestObjects [_MissionPos, ["House"], _searchRadius];
    private _found = false;
    {
        private _bpos = [_x] call BIS_fnc_buildingPositions;
        if (count _bpos >= 4) then {
            _Building = _x;
            _targetpos = getPosATL _Building;
            _buildingPositions = _bpos;
            _found = true;
            break;
        };
    } forEach _nearbyBuildings;
    if (!_found) exitWith {
        [14, "STR_DUWS_T_mission_no_building_4pos"] call fnc_mission_abort;
    };
};

// ----- 2. 放置平民（蓝方渔民，持续害怕动画）--------------------------------
_civilianClass = "C_Man_Fisherman_01_F";
_civGroup = [[0,0], WEST, [_civilianClass]] call BIS_fnc_spawnGroup;
_civilian = leader _civGroup;
_civilian allowDamage true;
_civilian setCaptive false;
_civilian setDamage 0.8;

// 使用已保存的 _buildingPositions 放置平民（此时确保≥4个位置）
if (count _buildingPositions > 0) then {
    _randIndex = floor random count _buildingPositions;
    _civilian setPosATL (_buildingPositions select _randIndex);
} else {
    // 理论上不会执行到这里，但保留后备
    _civilian setPosATL (getPosATL _Building);
};

// 禁止移动，保持害怕姿态
_civilian disableAI "PATH";
_civilian setBehaviour "CARELESS";
_civilian setCombatMode "BLUE";

// ----- 3. 为线人创建地图标记（类似 CQB 任务的标记模板）----------------------
_civilianMarker = format ["civ_marker_%1", round(time + random 1000)];
createMarker [_civilianMarker, getPosATL _civilian];
_civilianMarker setMarkerShape "ICON";
_civilianMarker setMarkerType "o_unknown";
_civilianMarker setMarkerColor "ColorBlue";
_civilianMarker setMarkerText "Informant";
_civilianMarker setMarkerSize [1, 1];

// 任务提示（只保留文字提示，不再重复广播标记）
// TODO: revisit the channel -- every mission thread announces through a hint box, so moving off
// it is one pass across all of them rather than a change here.
[localize "STR_DUWS_T_c14", {hint _this}] remoteExec ["BIS_fnc_Spawn", 0];

// 持续播放惊恐动画
[_civilian] spawn {
    params ["_unit"];
    sleep 1;
    // Broadcast: playMoveNow is local, so run from the server the informant only panicked on a
    // hosting player's screen and stood there calmly for every client. fnc_civ_arrest already
    // reaches for the same command this way. Unkeyed on purpose -- it reissues every 5 s, so a
    // joiner picks the animation up on the next pass without a queue entry per repeat.
    while {alive _unit} do {
        [_unit, "ApanPpneMstpSnonWnonDnon_G02"] remoteExec ["playMoveNow", 0];
        sleep 5;
    };
};

// 平民死亡事件：触发任务失败（由监控线程处理）
_civilian addEventHandler ["Killed", {
    params ["_unit", "_killer", "_instigator"];
    Mission_Failed = true;
    publicVariable "Mission_Failed";
}];

_civGroup deleteGroupWhenEmpty true;

// ----- 任务前对话（广播）----------------------------------------------------
[_speakerinfomat, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker, _messagewhoau] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakerinfomat, _messageiminfo] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker, _messageoverlord] remoteExec ["fnc_duws_dialogue", 0];
sleep 3;

// ----- 4. 创建任务条目（使用线人标记作为任务位置标记）----------------------
_VARtaskgeneratedName = format ["protectciv_%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_protectciv", _mission_name, getPosATL _civilian, "defend"] call fnc_missionTaskCreate;
sleep 5;
[_speakeracteam, _messageroger] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakerinfomat, _message1] remoteExec ["fnc_duws_dialogue", 0];

// ========== 新增：创建触发器，等待任意玩家进入任务区域 ==========
_startTrigger = createTrigger ["EmptyDetector", _targetpos];
_startTrigger setTriggerArea [_searchRadius, _searchRadius, 0, false];
_startTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", false];
_startTrigger setTriggerStatements ["this", "", ""]; // 空语句，在线程中等待

missionNamespace setVariable [format ["%1_started", _VARtaskgeneratedName], false];
publicVariable format ["%1_started", _VARtaskgeneratedName];

// 等待线程
[_startTrigger, _VARtaskgeneratedName] spawn {
    params ["_trg", "_taskName"];
    waitUntil { sleep 1; triggerActivated _trg };
    missionNamespace setVariable [format ["%1_startTime", _taskName], time];
    missionNamespace setVariable [format ["%1_started", _taskName], true];
    [localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_pcyh"] remoteExec ["fnc_duws_dialogue", 0];
    deleteVehicle _trg;
};

// ----- 7. 任务状态监控线程（统一处理成功/失败/取消 + 删除线人标记）-------
Mission_Failed = false;

// 启动监控线程，同时传递必要参数
[_civilian, _VARtaskgeneratedName, _civilianMarker, _timeLimit, _cpReward, _apReward, _repReward, _targetpos, _searchRadius] spawn {
    params ["_civ", "_taskID", "_civMarker", "_timeLimit", "_cp", "_ap", "_rep", "_targetPos", "_radius"];

    // 等待玩家进入任务区域
    waitUntil { sleep 1; missionNamespace getVariable [format ["%1_started", _taskID], false] };
    private _missionStartTime = missionNamespace getVariable [format ["%1_startTime", _taskID], time];

    // 任务活动标志，用于控制生成线程
    Mission_Active = true;
    publicVariable "Mission_Active";

    waitUntil {
        sleep 2;
        if (!alive _civ) exitWith { true };
        if (time - _missionStartTime >= _timeLimit) exitWith { true };
        false
    };

    // 任务结束，立即停止生成线程
    Mission_Active = false;
    publicVariable "Mission_Active";

    // ----- 任务结局判定 -----
    if (!alive _civ) then {
        // 平民死亡 → 失败
        [_taskID, "FAILED"] call fnc_missionTaskEnd;
        // Reputation is a civilian-system currency: skip its change when off. Charged against
        // the town the escorted civilian belonged to, falling back to the global outside one.
        if (CIV_PRESENCE != "NONE") then {
            [_civ getVariable ["civ_locIndex", -1], -1, "protect_civ_casualty"] call fnc_town_rep_adjust;
        };
        ["info", [localize "STR_DUWS_T_cycuqbvj", localize "STR_DUWS_T_ayhemuj4"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
        [_speaker, _message3] remoteExec ["fnc_duws_dialogue", 0];
    } else {
            // 时间到且平民存活 → 成功
            _speakeracteam  = localize "STR_DUWS_T_actionteam";
            _message2       = ([localize "STR_DUWS_T_pcend"] call fnc_cs);
            [_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
            sleep 8;
            [_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;

            [_cp, _ap, "Protect Civilian"] call fnc_mission_reward;
            if (CIV_PRESENCE != "NONE") then {
                [_civ getVariable ["civ_locIndex", -1], _rep, "protect_civ_success"] call fnc_town_rep_adjust;
                ["repup", [localize "STR_DUWS_T_rqwho9bq", localize "STR_DUWS_T_civ_rep_up"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
            };
    };

    // ----- 任务结束，统一清理 -----

    // ✅ 删除线人标记（无论成功/失败/取消，都会执行）
    if (!isNil "_civMarker" && {_civMarker != ""}) then {
        deleteMarker _civMarker;
    };

    // 调用通用清理函数（清除敌方单位、残骸等）
    [_targetPos, _radius, "", true] spawn fnc_mission_cleanup;
    // Spawn the "next mission" wait
    [] spawn fnc_missionTimer;
};

// ----- 8. 生成红方部队线程（最多四波，受 Mission_Active 控制）-----------
[_targetpos, _spawnDist, _civilian, _VARtaskgeneratedName] spawn {
    params ["_pos", "_dist", "_civ", "_taskName"];

    // 等待玩家进入任务区域
    waitUntil { sleep 1; missionNamespace getVariable [format ["%1_started", _taskName], false] };

    // 在此内部定义生成函数，确保作用域正确
    private _spawnOpforWave = {
        params ["_center", "_dist", "_targetObject"];
        private _spawnPos = [];
        private _attempts = 0;
        private _validPos = false;

        while {_attempts < 15 && !_validPos} do {
            _angle = random 360;
            _spawnPos = _center getPos [_dist, _angle];
            if (!surfaceIsWater _spawnPos) then { _validPos = true; };
            _attempts = _attempts + 1;
            sleep 0.5;
        };
        if (!_validPos) then {
            _spawnPos = _center getPos [_dist, random 360];
        };
        _spawnPos set [2, 0];

        _group = [_spawnPos, EAST, [
            opfor_SOLDIER_X, opfor_SOLDIER_X,
            opfor_AR_SOLDIER_X, opfor_AR_SOLDIER_X,
            opfor_LAT_SOLDIER_X,
            opfor_GL_SOLDIER_X,
            opfor_AR_SOLDIER_X, opfor_SOLDIER_X
        ]] call BIS_fnc_spawnGroup;
        {
        [_x] call fnc_addRandomLoot;
        } forEach units _group;
        {
            _x allowFleeing 0;
            _x disableAI "AUTOCOMBAT";
            _x setBehaviour "AWARE";
            _x setCombatMode "RED";
        } forEach units _group;

        _group deleteGroupWhenEmpty true;

        _wp = _group addWaypoint [getPosATL _targetObject, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointSpeed "NORMAL";

        _wp2 = _group addWaypoint [getPosATL _targetObject, 10];
        _wp2 setWaypointType "SAD";
        _wp2 setWaypointSpeed "NORMAL";
    };

    private _waveCount = 0;
    private _maxWaves = 4;          // 原脚本共生成四波
    private _initialDelay = 20;      // 第一波前的延迟

    // 等待初始延迟，期间可被 Mission_Active 中断
    private _endTime = time + _initialDelay;
    waitUntil { sleep 1; time >= _endTime || !Mission_Active };
    if (!Mission_Active) exitWith {};
    sleep 20;
    // 生成第一波
    [_pos, _dist, _civ] call _spawnOpforWave;
    _waveCount = 1;

    // 后续波次
    while {_waveCount < _maxWaves && Mission_Active} do {
        _endTime = time + 40;
        waitUntil { sleep 1; time >= _endTime || !Mission_Active };
        if (!Mission_Active) exitWith {};

        [_pos, _dist, _civ] call _spawnOpforWave;
        _waveCount = _waveCount + 1;
    };
};