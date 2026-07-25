// Locality: client -- inherited from init/client_init.sqf.
_hq = _this select 0;

if (isMultiplayer) then {
    // ===== 防重：如果已添加过动作，直接退出 =====
    if (_hq getVariable ["HQ_actions_done", false]) exitWith {};
    _hq setVariable ["HQ_actions_done", true];
    // ============================================
    if (support_armory_available) then {
        bluHQ_object addaction [localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal, [_this], 90, true, true, "", "_this == player"];
    };

if (support_halo_available) then {
    bluHQ_object addaction [localize "STR_DUWS_T_foldimok", fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addaction [localize "STR_DUWS_T_u6btu73i", fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
        bluHQ_object addaction [localize "STR_DUWS_T_halo_ai_only", fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
    };  
};

    "support_armory_available" addPublicVariableEventHandler {
        bluHQ_object addaction [localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal, [_this], 90, true, true, "", "_this == player"];
        {
            _x addaction [localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal, [_this], 90, true, true, "", "_this == player"];
        } forEach (Array_of_FOBS);
        lbSetColor [2103, 5, [0, 1, 0, 1]];
    };

// 公共变量事件处理器
"support_halo_available" addPublicVariableEventHandler {
    bluHQ_object addaction [localize "STR_DUWS_T_foldimok", fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addaction [localize "STR_DUWS_T_u6btu73i", fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
        bluHQ_object addaction [localize "STR_DUWS_T_halo_ai_only", fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
    };  
    {
        _x addaction [localize "STR_DUWS_T_foldimok", fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
        if ((vehiclevarname player) in Squad_Leaders) then {
            _x addaction [localize "STR_DUWS_T_u6btu73i", fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
            _x addaction [localize "STR_DUWS_T_halo_ai_only", fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
        };  
    } forEach (Array_of_FOBS);
    lbSetColor [2103, 14, [0, 1, 0, 1]];
};
};

waitUntil {sleep 600;!alive blu_officer_object};
removeAllActions _hq;