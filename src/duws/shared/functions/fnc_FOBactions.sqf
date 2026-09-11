// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
// The command entries -- squad and FOB managers, the redeploy -- live inside Requests, built by the
// same function the HQ uses. What is left here is what a player reaches for without asking command
// first: a FOB has no medical tent to put it on, and it is the same act of standing at a base and
// stopping for the night.
#include "..\includes\action_style.hpp"

_fob = _this select 0;
if (_fob getVariable ["FOB_actions_done", false]) exitWith {};
_fob setVariable ["FOB_actions_done", true];

// [true]: the same menu as the HQ's, minus the supports half a FOB cannot buy from.
_fob addaction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"), fnc_request_menu, [true], 100, true, true, "", "_this == player", ACT_REACH];

if (support_armory_available) then {
    _fob addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 80, true, true, "", "_this == player", ACT_REACH];
};

if (support_halo_available) then {
    _fob addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","_this == player", ACT_REACH];
    if ((vehiclevarname player) in Squad_Leaders) then {
        _fob addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","_this == player", ACT_REACH];
        _fob addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","_this == player", ACT_REACH];
    };
};

_fob addaction [ACT_AID("STR_DUWS_T_xfgokhbc"),fnc_AI_rearm,[], 60, false, false, "", "_this distance _target < 12"];

// No gate here: the row shows to all so a non-GM learns why; fnc_rest_menu gates host-only.
_fob addAction [ACT_AID("STR_DUWS_T_9eiwr3bt"), {
    params ["_target"];
    [_target] spawn fnc_rest_menu;
}, [], 55, false, false, "", "_this distance _target < 12"];
