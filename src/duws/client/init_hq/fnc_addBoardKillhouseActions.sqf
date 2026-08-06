// Locality: client; the addAction/map-click bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};
params ["_board"];
if (isNull _board) exitWith {};

// dedup
if (_board getVariable ["board_killhouse_actions_done", false]) exitWith {};
_board setVariable ["board_killhouse_actions_done", true];

// teleport points A/B are shown permanently, not folded into a submenu
_board addAction [
    ACT_MOVE("STR_DUWS_KILLHOUSE_TELEPORT_A"),
    {
        private _tp = missionNamespace getVariable "killhouse_tpA";
        if (isNil "_tp") exitWith { hint format [localize "STR_DUWS_T_killhouse_tp_notready", "A"]; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    [], 70, true, true, "", "true", ACT_REACH
];
_board addAction [
    ACT_MOVE("STR_DUWS_KILLHOUSE_TELEPORT_B"),
    {
        private _tp = missionNamespace getVariable "killhouse_tpB";
        if (isNil "_tp") exitWith { hint format [localize "STR_DUWS_T_killhouse_tp_notready", "B"]; };
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    },
    [], 70, true, true, "", "true", ACT_REACH
];

// No View Map on the board either. It moved into the REQUESTS menu, beside the mission timers and
// the pools it is read against -- the board is at the HQ, so the two were a pace apart, and reading
// the map is part of deciding what to request rather than an errand of its own.
//
// No base fast travel on the board. It only ever moved the player somewhere within 200 m of an HQ
// they were already standing at, so it bought nothing a walk did not; the FOB Manager owns travel
// between bases.
