_cost = 0;
_index = lbCurSel 2103;
AttChopInUse = true;

_grouptype = [];
_spawnPos = getmarkerpos str blu_hq_markername;

switch (VERSION_X) do {
	case "MODERN": {
		_spawnPos = [(_spawnPos select 0)+250, _spawnPos select 1, (_spawnPos select 2)+200];
		_grouptype = [blufor_HELI_ATTACK_X];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// 获取直升机/飞机的引用
_leader = leader _group;
_vehicle = vehicle _leader;

// 存储当前攻击直升机信息到全局变量（用于事件同步）
HC_ATTchop_currentVehicle = _vehicle;
HC_ATTchop_currentGroup = _group;
HC_ATTchop_active = true;
HC_ATTchop_killedPending = false;

player hcsetgroup [_group,""];
DUWS_number_attackchopa = DUWS_number_attackchopa + 1;

switch (VERSION_X) do {
	case "MODERN": {
		_group setGroupId [format[localize "STR_DUWS_T_8mtxjfj3",DUWS_number_attackchopa]];
	};
};
_speaker = localize "STR_DUWS_T_changgongpilot";
_message = ([localize "STR_DUWS_T_longbowin"] call fnc_cs);
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
hint localize "STR_DUWS_T_rjuehu36";

// 为直升机/飞机添加Killed事件处理器（保留原有时序，但增加冲突控制）
_vehicle addEventHandler ["Killed", {
    _this spawn {
        params ["_killedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_killedVehicle != HC_ATTchop_currentVehicle) exitWith {};

    HC_ATTchop_killedPending = true;  // 标记Killed正在处理，让Deleted跳过

    // 原有坠毁广播
    _speaker = localize "STR_DUWS_T_dispatcher";
    _message = localize "STR_DUWS_T_casdownlb";
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

    sleep 580;

    // 醒来后检查是否已被Deleted提前重置
    if (!HC_ATTchop_active) exitWith {};

    // 重新添加HC菜单项并清除状态
    _hcAttChop = [player,"hc_ATTchop"] call BIS_fnc_addCommMenuItem;
    hcAttChop = _hcAttChop;
    AttChopInUse = false;
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    HC_ATTchop_currentGroup = nil;
    HC_ATTchop_killedPending = false;

    // 广播可用消息
    _speaker = localize "STR_DUWS_T_dispatcher";
    _message1 = ([localize "STR_DUWS_T_casreservelb"] call fnc_cs);
    [_speaker, _message1] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
    };
}];

// 新增Deleted事件处理器，处理直升机被直接删除的情况（机组存活）
_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_deletedVehicle != HC_ATTchop_currentVehicle) exitWith {};

    // 如果Killed事件已在等待，则让Killed处理，避免重复
    if (HC_ATTchop_killedPending) exitWith {};

    // 立即重新添加HC菜单项（机组存活时删除）
    _hcAttChop = [player,"hc_ATTchop"] call BIS_fnc_addCommMenuItem;
    hcAttChop = _hcAttChop;
    AttChopInUse = false;
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    HC_ATTchop_currentGroup = nil;
    _speaker = localize "STR_DUWS_T_dispatcher";
    _message = ([localize "STR_DUWS_T_casreservelb"] call fnc_cs);  // 复用“可用”提示
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
}];