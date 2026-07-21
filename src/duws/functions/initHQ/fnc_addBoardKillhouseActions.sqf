// fnc_addBoardKillhouseActions.sqf
// 客户端执行：为 MapBoard_altis_F 添加 Killhouse 训练动作
if (!hasInterface) exitWith {};
params ["_board"];
if (isNull _board) exitWith {};

// 防重
if (_board getVariable ["board_killhouse_actions_done", false]) exitWith {};
_board setVariable ["board_killhouse_actions_done", true];

// 初始化展开状态
_board setVariable ["killhouse_training_expanded", false];
_board setVariable ["killhouse_child_actions", []];

// ---------- 展开/收起函数 ----------
duws_fnc_toggleKillhouseTraining = {
    params ["_board"];
    private _expanded = _board getVariable ["killhouse_training_expanded", false];
    private _childIDs = _board getVariable ["killhouse_child_actions", []];

    if (_expanded) then {
        // 收起：删除子动作
        { _board removeAction _x; } forEach _childIDs;
        _board setVariable ["killhouse_child_actions", []];
        _board setVariable ["killhouse_training_expanded", false];
        // 重新添加抽屉动作
        private _drawerID = _board addAction [
            "<t color='#00FF00'>" + localize "STR_DUWS_KILLHOUSE_START_TRAINING" + "</t>",
            { params ["_t"]; [_t] call duws_fnc_toggleKillhouseTraining; },
            nil, 6, true, true, "", "true"
        ];
        _board setVariable ["killhouse_drawer_action", _drawerID];
    } else {
        // 展开：移除抽屉动作，添加子动作
        private _drawerID = _board getVariable ["killhouse_drawer_action", -1];
        if (_drawerID != -1) then { _board removeAction _drawerID; };
        private _newIDs = [];
        // 传送点 A
        _newIDs pushBack (_board addAction [
            "<t color='#00AAFF'>" + localize "STR_DUWS_KILLHOUSE_TELEPORT_A" + "</t>",
            {
                private _tp = missionNamespace getVariable "killhouse_tpA";
                if (isNil "_tp") exitWith { hint "Teleport point A not ready"; };
                player setPosWorld _tp;
				hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
            },
            nil, 6, true, true, "", "true"
        ]);
        // 传送点 B
        _newIDs pushBack (_board addAction [
            "<t color='#00AAFF'>" + localize "STR_DUWS_KILLHOUSE_TELEPORT_B" + "</t>",
            {
                private _tp = missionNamespace getVariable "killhouse_tpB";
                if (isNil "_tp") exitWith { hint "Teleport point B not ready"; };
                player setPosWorld _tp;
				hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
            },
            nil, 6, true, true, "", "true"
        ]);
        _board setVariable ["killhouse_child_actions", _newIDs];
        _board setVariable ["killhouse_training_expanded", true];
    };
};

// 初始添加抽屉动作
private _drawerID = _board addAction [
    "<t color='#00FF00'>" + localize "STR_DUWS_KILLHOUSE_START_TRAINING" + "</t>",
    { params ["_t"]; [_t] call duws_fnc_toggleKillhouseTraining; },
    nil, 6, true, true, "", "true"
];
_board setVariable ["killhouse_drawer_action", _drawerID];
publicVariable "duws_fnc_toggleKillhouseTraining";
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