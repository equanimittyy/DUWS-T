// Locality: client; the addAction/map-click bodies below run on the machine that triggers them, not here.
// fnc_addBoardKillhouseActions.sqf
// 客户端执行：为 MapBoard_altis_F 添加 Killhouse 传送动作与基地快速移动
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};
params ["_board"];
if (isNull _board) exitWith {};

// 防重
if (_board getVariable ["board_killhouse_actions_done", false]) exitWith {};
_board setVariable ["board_killhouse_actions_done", true];

// 传送点 A/B 常驻显示，不再折叠进"开始训练"抽屉
_board addAction [
    ACT_MOVE("STR_DUWS_KILLHOUSE_TELEPORT_A"),
    {
        private _tp = missionNamespace getVariable "killhouse_tpA";
        if (isNil "_tp") exitWith { hint format [localize "STR_DUWS_T_killhouse_tp_notready", "A"]; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    [], 65, true, true, "", "true"
];
_board addAction [
    ACT_MOVE("STR_DUWS_KILLHOUSE_TELEPORT_B"),
    {
        private _tp = missionNamespace getVariable "killhouse_tpB";
        if (isNil "_tp") exitWith { hint format [localize "STR_DUWS_T_killhouse_tp_notready", "B"]; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    [], 65, true, true, "", "true"
];

_board addAction [
    ACT_UTIL("STR_DUWS_T_civ_mapview_action"),
    { call fnc_civ_mapView },
    [], 5, true, true, "", "_this == player"
];

// 添加基地快速移动动作（在白板地图上）
if (isNil {_board getVariable "board_fasttravel_actions_done"}) then {
    _board setVariable ["board_fasttravel_actions_done", true];
    _board addAction [
        ACT_MOVE("STR_DUWS_T_FAST_TRAVEL_BASE"),
        {
            params ["_target", "_caller", "_actionId"];
            // 避免重复打开地图
            if (!isNil "DUWS_baseTravelMapOpen" && {DUWS_baseTravelMapOpen}) exitWith {
                hint localize "STR_DUWS_T_FAST_TRAVEL_BUSY";
            };
            private _got = ["FASTTRAVEL", {
                params ["_pos"];
                // Releasing clears the banner too, and it has to happen while the map is still
                // up: the banner is a control on that display.
                ["FASTTRAVEL"] call fnc_mapclick_release;
                openMap false;
                DUWS_baseTravelMapOpen = false;
                if (_pos distance PosOfBLUHQ < 200) then {
                    player setPos _pos;
                    hint localize "STR_DUWS_T_FAST_TRAVEL_BASE_ARRIVE";
                } else {
                    hint localize "STR_DUWS_T_FAST_TRAVEL_BASE_FAIL";
                };
                true;
            }] call fnc_mapclick_claim;
            if (!_got) exitWith {};

            DUWS_baseTravelMapOpen = true;
            openMap true;
            // Not a hint: the hint box renders beneath the map display, so the instruction to
            // click near the base played its sound and showed nothing, leaving the player in a
            // click-to-travel mode with no sign it had started.
            [localize "STR_DUWS_T_FAST_TRAVEL_BASE_HINT"] call fnc_map_prompt;

            // 地图被强制关闭时的清理
            [] spawn {
                waitUntil { !visibleMap };
                if (!isNil "DUWS_baseTravelMapOpen" && {DUWS_baseTravelMapOpen}) then {
                    DUWS_baseTravelMapOpen = nil;
                    ["FASTTRAVEL"] call fnc_mapclick_release;
                };
            };
        },
        [],
        6,
        true,
        true,
        "",
        "_this == player"
    ];
};
