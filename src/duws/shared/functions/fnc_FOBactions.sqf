// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
// The command entries a FOB used to carry -- squad and FOB managers, the rest, the cooldown
// readout, the redeploy -- are rows inside Requests now, built by the same function the HQ uses.
// What is left here is what a player reaches for without asking command first.
#include "..\includes\action_style.hpp"

_fob = _this select 0;
_fob_owner = _this select 1;
// 防重
if (_fob getVariable ["FOB_actions_done", false]) exitWith {};
_fob setVariable ["FOB_actions_done", true];

// [true]: the same menu as the HQ's, minus the supports half a FOB cannot buy from.
_fob addaction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"), fnc_request_menu, [true], 100, true, true, "", "_this == player"];

if (support_armory_available) then {
    _fob addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 80, true, true, "", "_this == player"];
};

if (support_halo_available) then {
    _fob addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","_this == player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        _fob addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","_this == player"];
        _fob addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","_this == player"];
    };
};

_fob addaction [ACT_AID("STR_DUWS_T_xfgokhbc"),fnc_AI_rearm,[], 60, false, false, "", "_this distance _target < 12"];
