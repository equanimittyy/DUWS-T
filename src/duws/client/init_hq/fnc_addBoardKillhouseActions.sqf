// Locality: client; the addAction/map-click bodies below run on the machine that triggers them, not here.
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
    [], 70, true, true, "", "true"
];
_board addAction [
    ACT_MOVE("STR_DUWS_KILLHOUSE_TELEPORT_B"),
    {
        private _tp = missionNamespace getVariable "killhouse_tpB";
        if (isNil "_tp") exitWith { hint format [localize "STR_DUWS_T_killhouse_tp_notready", "B"]; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    [], 70, true, true, "", "true"
];

_board addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_civ_mapview_action"),
    { call fnc_map_readout_open },
    [], 90, true, true, "", "_this == player"
];

// No base fast travel on the board. It only ever moved the player somewhere within 200 m of an HQ
// they were already standing at, so it bought nothing a walk did not; the FOB Manager owns travel
// between bases.
