// Locality: client -- inherited from client/client_init.sqf.
//
// The arsenal and HALO entries stay on the scroll wheel rather than moving into the request menu:
// they are bought supports a player uses on the way out, not something to ask command for.
//
// The handlers below do not paint the supports listbox green when the purchase lands. That row is
// coloured from the availability flags each time the menu is built, and the indices written here
// had drifted onto the wrong rows -- the armory handler was colouring HALO.
#include "..\..\shared\includes\action_style.hpp"

_hq = _this select 0;

if (isMultiplayer) then {
    // ===== 防重：如果已添加过动作，直接退出 =====
    if (_hq getVariable ["HQ_actions_done", false]) exitWith {};
    _hq setVariable ["HQ_actions_done", true];
    // ============================================
    if (support_armory_available) then {
        bluHQ_object addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [_this], 80, true, true, "", "_this == player"];
    };

if (support_halo_available) then {
    bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","alive player"];
        bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","alive player"];
    };  
};

    "support_armory_available" addPublicVariableEventHandler {
        bluHQ_object addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [_this], 80, true, true, "", "_this == player"];
        {
            _x addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [_this], 80, true, true, "", "_this == player"];
        } forEach (Array_of_FOBS);
    };

// 公共变量事件处理器
"support_halo_available" addPublicVariableEventHandler {
    bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","alive player"];
        bluHQ_object addaction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","alive player"];
    };  
    {
        _x addaction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","alive player"];
        if ((vehiclevarname player) in Squad_Leaders) then {
            _x addaction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","alive player"];
            _x addaction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","alive player"];
        };  
    } forEach (Array_of_FOBS);
};
};