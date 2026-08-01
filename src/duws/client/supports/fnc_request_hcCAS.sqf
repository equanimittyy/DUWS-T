// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:198).
CASInUse = true;

_spawnPos = getmarkerpos str blu_hq_markername;
_grouptype = [blufor_PLANE_CAS_X];

switch (VERSION_X) do {
	case "MODERN": {
		_vec =[random [-1,0,1], random [-1,0,1], 0];
		_dist = 500;
		_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+800];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
sleep 1;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle engineOn true;

// 存储当前CAS战机信息到全局变量（用于事件同步）
HC_CAS_currentVehicle = _vehicle;
HC_CAS_active = true;
HC_CAS_killedPending = false;

switch (VERSION_X) do {
	case "MODERN": {
		_vehicle flyInHeight 150;
	};
};
_speaker = localize "STR_DUWS_T_koipilot";
_message = ([localize "STR_DUWS_T_koiin"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

player hcsetgroup [_group,""];
DUWS_number_CAS = DUWS_number_CAS + 1;
_group setGroupId [format[localize "STR_DUWS_T_8mtxjfj3",DUWS_number_CAS]];
hint localize "STR_DUWS_T_gu6cbc5f";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// 为飞机添加Killed事件处理器（使用spawn以允许sleep，并增加状态控制）
_vehicle addEventHandler ["Killed", {
    _this spawn {
        params ["_killedVehicle"];
        if (!HC_CAS_active) exitWith {};
        if (_killedVehicle != HC_CAS_currentVehicle) exitWith {};

        HC_CAS_killedPending = true;  // 标记Killed正在处理，让Deleted跳过

        // 坠毁广播
        _speaker = localize "STR_DUWS_T_OVERLORD";
        _message = localize "STR_DUWS_T_casdownkoi";
        [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

        sleep 600;

        // 醒来后检查是否已被Deleted提前重置
        if (!HC_CAS_active) exitWith {};

        // 重新添加HC菜单项并清除状态
        ["hc_CAS"] call fnc_support_comm_add;
        CASInUse = false;
        HC_CAS_active = false;
        HC_CAS_currentVehicle = nil;
        HC_CAS_killedPending = false;

        // 广播可用消息
        _speaker = localize "STR_DUWS_T_OVERLORD";
        _message1 = ([localize "STR_DUWS_T_casreservekoi"] call fnc_cs);
        [_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
    };
}];

// 新增Deleted事件处理器，处理飞机被直接删除的情况（机组存活）
_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_deletedVehicle != HC_CAS_currentVehicle) exitWith {};

    // 如果Killed事件已在等待，则让Killed处理，避免重复
    if (HC_CAS_killedPending) exitWith {};

    // 立即重新添加HC菜单项（机组存活时删除）
    ["hc_CAS"] call fnc_support_comm_add;
    CASInUse = false;
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_casreservekoi"] call fnc_cs);  // 复用“可用”提示
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
}];