// fnc_addBoardKillhouseActions.sqf
// 客户端执行：为 MapBoard_altis_F 添加 Killhouse 传送动作与基地快速移动
if (!hasInterface) exitWith {};
params ["_board"];
if (isNull _board) exitWith {};

// 防重
if (_board getVariable ["board_killhouse_actions_done", false]) exitWith {};
_board setVariable ["board_killhouse_actions_done", true];

// 传送点 A/B 常驻显示，不再折叠进"开始训练"抽屉
_board addAction [
    "<t color='#00AAFF'>" + localize "STR_DUWS_KILLHOUSE_TELEPORT_A" + "</t>",
    {
        private _tp = missionNamespace getVariable "killhouse_tpA";
        if (isNil "_tp") exitWith { hint "Teleport point A not ready"; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    nil, 6, true, true, "", "true"
];
_board addAction [
    "<t color='#00AAFF'>" + localize "STR_DUWS_KILLHOUSE_TELEPORT_B" + "</t>",
    {
        private _tp = missionNamespace getVariable "killhouse_tpB";
        if (isNil "_tp") exitWith { hint "Teleport point B not ready"; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    nil, 6, true, true, "", "true"
];

// 添加基地快速移动动作（在白板地图上）
if (isNil {_board getVariable "board_fasttravel_actions_done"}) then {
    _board setVariable ["board_fasttravel_actions_done", true];
    _board addAction [
        localize "STR_DUWS_T_FAST_TRAVEL_BASE",
        {
            params ["_target", "_caller", "_actionId"];
            // 避免重复打开地图
            if (!isNil "DUWS_baseTravelMapOpen" && {DUWS_baseTravelMapOpen}) exitWith {
                hint localize "STR_DUWS_T_FAST_TRAVEL_BUSY";
            };
            DUWS_baseTravelMapOpen = true;
            openMap true;
            hint localize "STR_DUWS_T_FAST_TRAVEL_BASE_HINT";
            onMapSingleClick {
                params ["_pos"];
                onMapSingleClick "";
                openMap false;
                DUWS_baseTravelMapOpen = false;
                if (_pos distance PosOfBLUHQ < 200) then {
                    player setPos _pos;
                    hint localize "STR_DUWS_T_FAST_TRAVEL_BASE_ARRIVE";
                } else {
                    hint localize "STR_DUWS_T_FAST_TRAVEL_BASE_FAIL";
                };
                true;
            };
            // 地图被强制关闭时的清理
            [] spawn {
                waitUntil { !visibleMap };
                if (!isNil "DUWS_baseTravelMapOpen" && {DUWS_baseTravelMapOpen}) then {
                    DUWS_baseTravelMapOpen = nil;
                    onMapSingleClick "";
                };
            };
        },
        nil,
        6,
        true,
        true,
        "",
        "_this == player"
    ];
};
