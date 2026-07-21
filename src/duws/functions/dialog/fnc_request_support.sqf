

_index2 = lbCurSel 2103;

switch (_index2) do {

	// SUPPLY DROP
    case 0: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_supplydrop_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_supplydropunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _supplydrop = [player,"ammo"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_supply, [0, 1, 0, 1]];
                playSound "boots";
                support_supplydrop_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// ARSENAL
    case 1: {
		_cost = 10;
        if (commandpointsblu1 >= _cost) then {
            if (!support_armory_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_arsenalunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                lbSetColor [2103, index_support_armory, [0, 1, 0, 1]];
                support_armory_available = true;
                bluHQ_object addaction [localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal, "", 0, true, true, "", "_this == player"];
                {
                    _x addaction [localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal, "", 0, true, true, "", "_this == player"];
                } forEach (Array_of_FOBS);

                playSound "loadgun";
                publicVariable "support_armory_available";
                ["armory",[localize "STR_DUWS_T_sg49vbhh",localize "STR_DUWS_T_h5t5vtfs"]] call bis_fnc_showNotification;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// VEHICLE DROP
    case 2: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_veh_drop_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_vehicledropunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _vehdrop = [player,"veh_drop"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_veh_supply, [0, 1, 0, 1]];
                playSound "boots";
                support_veh_drop_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };
    
	// SIVA DROP
    case 3: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_siva_drop_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_sivaunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _sivadrop = [player,"siva_drop"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_siva_supply, [0, 1, 0, 1]];
                playSound "boots";
                support_siva_drop_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// SAWP DROP
    case 4: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_sawp_drop_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_sawpunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _sawpdrop = [player,"sawp_drop"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_sawp, [0, 1, 0, 1]];
                playSound "boots";
                support_sawp_drop_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

// HALO JUMP
case 5: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
    _cost = 15;
    if (commandpointsblu1 >= _cost) then {
        if (!support_halo_available) then {
            commandpointsblu1 = commandpointsblu1 - _cost;
            _speaker = localize "STR_DUWS_T_dispatcher";
            _message = localize "STR_DUWS_T_HALOunlock";
            [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
            ctrlSetText [1000, format["%1",commandpointsblu1]];
            lbSetColor [2103, 15, [0, 1, 0, 1]];
            support_halo_available = true;

            // 添加三个 HALO 动作：单人、全组、仅 AI
            bluHQ_object addAction [localize "STR_DUWS_T_foldimok", fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
            if ((vehiclevarname player) in Request_Players) then {
                bluHQ_object addAction [localize "STR_DUWS_T_u6btu73i", fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
                bluHQ_object addAction [localize "STR_DUWS_T_halo_ai_only", fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
            };

            {
                _x addAction [localize "STR_DUWS_T_foldimok", fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
                if ((vehiclevarname player) in Request_Players) then {
                    _x addAction [localize "STR_DUWS_T_u6btu73i", fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
                    _x addAction [localize "STR_DUWS_T_halo_ai_only", fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
                };
            } forEach (Array_of_FOBS);

            playSound "loadgun";
            publicVariable "support_halo_available";
            ["halo",[localize "STR_DUWS_T_0m2mxf4u",localize "STR_DUWS_T_adygxrb6"]] call bis_fnc_showNotification;
        } else {
            hint localize "STR_DUWS_T_8c1i4vga";
        };
    } else {
        hint localize "STR_DUWS_T_e95mc4lv";
    };
};

	// UAV RECON
    case 6: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_uav_recon_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_uavunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _uav_recon = [player,"uav_recon"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_uavrecon, [0, 1, 0, 1]];
                playSound "boots";
                support_uav_recon_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// HELO TAXI
    case 7: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then  {
            if (!support_helotaxi_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_helotaxiunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _helo = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_helotaxi, [0, 1, 0, 1]];
                playSound "boots";
                support_helotaxi_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

// HELO LIFT
case 8: {
    // 如果是客户端（非服务器），拒绝并显示提示
    if (!isServer) exitWith { hint localize "STR_DUWS_T_shiyanxinggongneng"; };
    
    _cost = 10;
    // Check if Radio Support
    if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
    if (commandpointsblu1 >= _cost) then  {
        if (!support_helolift_available) then {
            commandpointsblu1 = commandpointsblu1 - _cost;
            support_count = support_count + 1;
            _speaker = localize "STR_DUWS_T_dispatcher";
            _message = localize "STR_DUWS_T_heloliftunlock";
            [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
            ctrlSetText [1000, format["%1",commandpointsblu1]];
            _helo = [player,"helo_lift"] call BIS_fnc_addCommMenuItem;
            lbSetColor [2103, index_support_helolift, [0, 1, 0, 1]];
            playSound "boots";
            support_helolift_available = true;
        } else {
            hint localize "STR_DUWS_T_8c1i4vga";
        };
    } else {
        hint localize "STR_DUWS_T_e95mc4lv";
    };
};

	// BOAT TAXI
    case 9: {
		_cost = 2;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_boattaxi_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_boattaxiunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                lbSetColor [2103, index_support_boattaxi, [0, 1, 0, 1]];
                support_boattaxi_available = true;
                _boattaxi = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
                playSound "boots";
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// VEHICLE RECYCLE
case 10: {
    _cost = 5;
    if (commandpointsblu1 < _cost) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; };
    if (support_veh_recycle_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga"; };
    commandpointsblu1 = commandpointsblu1 - _cost;
    publicVariable "commandpointsblu1";
    support_veh_recycle_available = true;
    publicVariable "support_veh_recycle_available";
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    lbSetColor [2103, index_support_recycle, [0, 1, 0, 1]];
    playSound "loadgun";
    [] remoteExec ["fnc_activateBaseRecycleStation", 2];
};

	// VEHICLE REPAIR
case 11: {
    _cost = 5;
    if (commandpointsblu1 < _cost) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; };
    if (support_veh_repair_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga"; };
    commandpointsblu1 = commandpointsblu1 - _cost;
    publicVariable "commandpointsblu1";
    support_veh_repair_available = true;
    publicVariable "support_veh_repair_available";
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    lbSetColor [2103, index_support_repair, [0, 1, 0, 1]];
    playSound "loadgun";
    [] remoteExec ["fnc_activateBaseRepairStation", 2];
};

	// ARTILLERY
    case 12: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 20;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_arty_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_artyunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _arty = [player,"artillery"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_arty, [0, 1, 0, 1]];
                playSound "boots";
                support_arty_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// MORTAR
    case 13: {
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_mortar_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_slingshot";
                _message = localize "STR_DUWS_T_mtrunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _mortar = [player,"mortar"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_mortar, [0, 1, 0, 1]];
                playSound "boots";
                support_mortar_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// JDAM STRIKE
    case 14: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_jdam_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_jdamunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _jdam = [player,"jdam"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_jdam, [0, 1, 0, 1]];
                playSound "boots";
                support_jdam_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// LASER GUIDED BOMB
    case 15: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then  {
            if (!support_laser_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_dispatcher";
                _message = localize "STR_DUWS_T_laserguidedunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _laser = [player,"laser"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_laser, [0, 1, 0, 1]];
                playSound "boots";
                support_laser_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// CLUSTER STRIKE
    case 16: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 25;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then  {
            if (!support_cluster_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_clusterunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _cluster = [player,"cluster"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_cluster, [0, 1, 0, 1]];
                playSound "boots";
                support_cluster_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// NAPALM STRIKE
    case 17: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 20;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then  {
            if (!support_napalm_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_napalmunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _cluster = [player,"napalm"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_napalm, [0, 1, 0, 1]];
                playSound "boots";
                support_napalm_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

	// HC ATTACK CHOPPER
    case 18: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 20;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (!support_hcAttChop_available) then {
            if (commandpointsblu1 >= _cost) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_changgongpilot";
                _message = localize "STR_DUWS_T_hcchopperunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _hcAttChop = [player,"hc_ATTchop"] call BIS_fnc_addCommMenuItem;
				hcAttChop = _hcAttChop;
                lbSetColor [2103, index_support_hcAttChop, [0, 1, 0, 1]];
				playSound "boots";
                support_hcAttChop_available = true;
            } else {
				hint localize "STR_DUWS_T_e95mc4lv";
            };
        } else {
            if (AttChopInUse) exitWith {hint localize "STR_DUWS_T_dvbox9ay"};
			commandpointsblu1 = commandpointsblu1 + (floor _cost/2);
			ctrlSetText [1000, format["%1",commandpointsblu1]];
			[player,hcAttChop] call BIS_fnc_removeCommMenuItem;
			lbSetColor [2103, index_support_hcAttChop, [1, 0, 0, 1]];
			playSound "boots";
			support_hcAttChop_available = false;
			hint localize "STR_DUWS_T_wdgpslhe";
        };
    };

	// HC CAS JET
    case 19: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 25;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (!support_hcCAS_available) then {
			if (commandpointsblu1 >= _cost) then {
				commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_koipilot";
                _message = localize "STR_DUWS_T_hcjetunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
				ctrlSetText [1000, format["%1",commandpointsblu1]];
                _hcCAS = [player,"hc_CAS"] call BIS_fnc_addCommMenuItem;
				hcCAS = _hcCAS;
                lbSetColor [2103, index_support_hcCAS, [0, 1, 0, 1]];
				playSound "boots";
                support_hcCAS_available = true;
            } else {
				hint localize "STR_DUWS_T_e95mc4lv";
            };
        } else {
            if (CASInUse) exitWith {hint localize "STR_DUWS_T_dvbox9ay"};
				commandpointsblu1 = commandpointsblu1 + (floor _cost/2);
				ctrlSetText [1000, format["%1",commandpointsblu1]];
				[player,hcCAS] call BIS_fnc_removeCommMenuItem;
				lbSetColor [2103, index_support_hcCAS, [1, 0, 0, 1]];
				playSound "boots";
				support_hcCAS_available = false;
				hint localize "STR_DUWS_T_wdgpslhe";
             };
    };

	// PARADROP
    case 20: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 20;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (commandpointsblu1 >= _cost) then {
            if (!support_paradrop_available) then {
                commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message = localize "STR_DUWS_T_paradropunlock";
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                ctrlSetText [1000, format["%1",commandpointsblu1]];
                _supplydrop = [player,"paradrop"] call BIS_fnc_addCommMenuItem;
                lbSetColor [2103, index_support_paradrop, [0, 1, 0, 1]];
                playSound "boots";
                support_paradrop_available = true;
            } else {
                hint localize "STR_DUWS_T_8c1i4vga";
            };
        } else {
            hint localize "STR_DUWS_T_e95mc4lv";
        };
    };

// Mobile HQ
case 21: {
    _cost = 10;
    // 叛军模式免费
    if (!isNil "insurgent_mode_enable" && insurgent_mode_enable) then {
        _cost = 0;
    };
    // Check if Radio Support
    if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
    if (commandpointsblu1 >= _cost) then {
        if (support_mobile_HQ_available) then {
            commandpointsblu1 = commandpointsblu1 - _cost;
            _speaker = localize "STR_DUWS_T_dispatcher";
            _message = localize "STR_DUWS_T_mhqunlock";
            [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
            ctrlSetText [1000, format["%1",commandpointsblu1]];
            _mhq = [player,"mobile_HQ"] call BIS_fnc_addCommMenuItem;
            lbSetColor [2103, index_mobile_HQ, [0, 1, 0, 1]];
            playSound "boots";
            support_mobile_HQ_available = false;
            publicVariable "support_mobile_HQ_available";
            ["info",[localize "STR_DUWS_T_ooi6w4yh",localize "STR_DUWS_T_cghsxhhu"]] call bis_fnc_showNotification;
        } else {
            hint localize "STR_DUWS_T_8c1i4vga";
        };
    } else {
        hint localize "STR_DUWS_T_e95mc4lv";
    };
};

	// HC CAP JET - fighter
    case 22: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 25;
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
        if (!support_hcCAP_available) then {
			if (commandpointsblu1 >= _cost) then {
				commandpointsblu1 = commandpointsblu1 - _cost;
				support_count = support_count + 1;
				ctrlSetText [1000, format["%1",commandpointsblu1]];
                _hcCAP = [player,"hc_CAP"] call BIS_fnc_addCommMenuItem;
				hcCAS = _hcCAP;
                lbSetColor [2103, 16, [0, 1, 0, 1]];
				playSound "boots";
                support_hcCAP_available = true;
            } else {
				hint localize "STR_DUWS_T_e95mc4lv";
            };
        } else {
            if (CAPInUse) exitWith {hint localize "STR_DUWS_T_dvbox9ay"};
				commandpointsblu1 = commandpointsblu1 + (floor _cost/2);
				ctrlSetText [1000, format["%1",commandpointsblu1]];
				[player,hcCAS] call BIS_fnc_removeCommMenuItem;
				lbSetColor [2103, 16, [1, 0, 0, 1]];
				playSound "boots";
				support_hcCAP_available = false;
				hint localize "STR_DUWS_T_wdgpslhe";
             };
    };

};

//hint format["index: %1",_index2];
publicVariable "commandpointsblu1";

