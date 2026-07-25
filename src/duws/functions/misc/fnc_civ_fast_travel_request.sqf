/*
    fnc_civ_fast_travel_request.sqf
    客户端：请求快速传送，服务器验证后打开地图
*/
if (!hasInterface) exitWith {};

params ["_caller"];

// 清除任何残留的点击回调
onMapSingleClick "";

// 防止重复打开地图
if (!isNil "fast_travel_map_open" && {fast_travel_map_open}) exitWith {
    hint localize "STR_DUWS_T_FAST_TRAVEL_BUSY";
};
fast_travel_map_open = true;

// 生成唯一请求ID
private _requestId = floor (random 1000000);
missionNamespace setVariable [format ["fast_travel_req_%1", _requestId], false];
[player, _requestId] remoteExec ["fnc_civ_fast_travel_server", 2];

// 无限等待服务器响应
waitUntil {
    sleep 0.2;
    private _resp = missionNamespace getVariable [format ["fast_travel_req_%1", _requestId], false];
    (_resp isEqualType [])  // 当响应变为数组时退出等待
};

private _result = missionNamespace getVariable [format ["fast_travel_req_%1", _requestId], false];
missionNamespace setVariable [format ["fast_travel_req_%1", _requestId], nil];

if (_result isEqualType []) then {
    _result params ["_success", "_msg"];
    if (!_success) then {
        hint _msg;
        fast_travel_map_open = false;
    } else {
        // 成功：打开地图等待点击
        hint localize "STR_DUWS_T_FAST_TRAVEL_CLICK_MAP";
        openMap true;
        onMapSingleClick {
            params ["_pos", "_alt", "_shift"];
            onMapSingleClick "";
            openMap false;
            // 黑屏效果
            titleCut ["", "BLACK OUT", 0.5];
            [_pos] spawn {
                params ["_pos"];
                sleep 0.5;
                [_pos, player] remoteExec ["fnc_civ_fast_travel_execute", 2];
            };
            fast_travel_map_open = false;
            true;
        };
        // 如果玩家手动关闭地图，取消传送
        waitUntil { !visibleMap };
        if (fast_travel_map_open) then {
            fast_travel_map_open = false;
            onMapSingleClick "";
            [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_FAST_TRAVEL_nvm"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
    };
} else {
    fast_travel_map_open = false;
    onMapSingleClick "";
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_FAST_TRAVEL_nvm"] remoteExec ["BIS_fnc_showSubtitle", _caller];
};