// Locality: client; the addAction bodies below run on the machine that triggers them, not here (invoked from a dialog action).
// Every case tests its own already-unlocked flag before asking the server to charge:
// the spend is a round trip, so ordering it first would both waste one and report
// "not enough CP" to a player who already owns the support.


#include "..\..\shared\includes\action_style.hpp"

_index2 = lbCurSel 2103;

switch (_index2) do {

	// SUPPLY DROP
    case 0: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_supplydrop_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = ([localize "STR_DUWS_T_supplydropunlock"] call fnc_cs);
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_supplydrop = [player,"ammo"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_supply, [0, 1, 0, 1]];
		playSound "boots";
		support_supplydrop_available = true;
    };

	// ARSENAL
    case 1: {
		_cost = 10;
		if (support_armory_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_arsenalunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		lbSetColor [2103, index_support_armory, [0, 1, 0, 1]];
		support_armory_available = true;
		bluHQ_object addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 0, true, true, "", "_this == player"];
		{
			_x addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 0, true, true, "", "_this == player"];
		} forEach (Array_of_FOBS);

		playSound "loadgun";
		publicVariable "support_armory_available";
		["armory",[localize "STR_DUWS_T_sg49vbhh",localize "STR_DUWS_T_h5t5vtfs"]] call bis_fnc_showNotification;
    };

	// VEHICLE DROP
    case 2: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_veh_drop_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = ([localize "STR_DUWS_T_vehicledropunlock"] call fnc_cs);
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_vehdrop = [player,"veh_drop"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_veh_supply, [0, 1, 0, 1]];
		playSound "boots";
		support_veh_drop_available = true;
    };

	// SIVA DROP
    case 3: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_siva_drop_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_sivaunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_sivadrop = [player,"siva_drop"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_siva_supply, [0, 1, 0, 1]];
		playSound "boots";
		support_siva_drop_available = true;
    };

	// SAWP DROP
    case 4: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_sawp_drop_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_sawpunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_sawpdrop = [player,"sawp_drop"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_sawp, [0, 1, 0, 1]];
		playSound "boots";
		support_sawp_drop_available = true;
    };

// HALO JUMP
case 5: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
    _cost = 15;
    if (support_halo_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
    if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_HALOunlock";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    lbSetColor [2103, 15, [0, 1, 0, 1]];
    support_halo_available = true;

    // 添加三个 HALO 动作：单人、全组、仅 AI
    bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
        bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
    };

    {
        _x addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 0, true, true, "","alive player"];
        if ((vehiclevarname player) in Squad_Leaders) then {
            _x addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 0, true, true, "","alive player"];
            _x addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 0, true, true, "","alive player"];
        };
    } forEach (Array_of_FOBS);

    playSound "loadgun";
    publicVariable "support_halo_available";
    ["halo",[localize "STR_DUWS_T_0m2mxf4u",localize "STR_DUWS_T_adygxrb6"]] call bis_fnc_showNotification;
};

	// UAV RECON
    case 6: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_uav_recon_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_uavunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_uav_recon = [player,"uav_recon"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_uavrecon, [0, 1, 0, 1]];
		playSound "boots";
		support_uav_recon_available = true;
    };

	// HELO TAXI
    case 7: {
		_cost = 5;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_helotaxi_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_helotaxiunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_helo = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_helotaxi, [0, 1, 0, 1]];
		playSound "boots";
		support_helotaxi_available = true;
    };

// HELO LIFT
case 8: {
    _cost = 10;
    // Check if Radio Support
    if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
    if (support_helolift_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
    if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
    support_count = support_count + 1;
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_heloliftunlock";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    _helo = [player,"helo_lift"] call BIS_fnc_addCommMenuItem;
    lbSetColor [2103, index_support_helolift, [0, 1, 0, 1]];
    playSound "boots";
    support_helolift_available = true;
};

	// BOAT TAXI
    case 9: {
		_cost = 2;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_boattaxi_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_boattaxiunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		lbSetColor [2103, index_support_boattaxi, [0, 1, 0, 1]];
		support_boattaxi_available = true;
		_boattaxi = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
		playSound "boots";
    };

	// VEHICLE RECYCLE
case 10: {
    _cost = 5;
    if (support_veh_recycle_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga"; };
    if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; };
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
    if (support_veh_repair_available) exitWith { hint localize "STR_DUWS_T_8c1i4vga"; };
    if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; };
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
		if (support_arty_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_artyunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_arty = [player,"artillery"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_arty, [0, 1, 0, 1]];
		playSound "boots";
		support_arty_available = true;
    };

	// MORTAR
    case 13: {
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_mortar_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_slingshot";
		_message = localize "STR_DUWS_T_mtrunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_mortar = [player,"mortar"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_mortar, [0, 1, 0, 1]];
		playSound "boots";
		support_mortar_available = true;
    };

	// JDAM STRIKE
    case 14: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_jdam_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = ([localize "STR_DUWS_T_jdamunlock"] call fnc_cs);
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_jdam = [player,"jdam"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_jdam, [0, 1, 0, 1]];
		playSound "boots";
		support_jdam_available = true;
    };

	// LASER GUIDED BOMB
    case 15: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 10;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_laser_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_laserguidedunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_laser = [player,"laser"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_laser, [0, 1, 0, 1]];
		playSound "boots";
		support_laser_available = true;
    };

	// CLUSTER STRIKE
    case 16: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 25;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_cluster_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = ([localize "STR_DUWS_T_clusterunlock"] call fnc_cs);
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_cluster = [player,"cluster"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_cluster, [0, 1, 0, 1]];
		playSound "boots";
		support_cluster_available = true;
    };

	// NAPALM STRIKE
    case 17: {
        if (insurgent_mode_enable) exitWith {
        hint localize "STR_DUWS_T_inssupport";
        };
		_cost = 20;
		// Check if Radio Support
		if (support_count > 7) exitWith {["info",[localize "STR_DUWS_T_45a8q6tj",localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;};
		if (support_napalm_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = ([localize "STR_DUWS_T_napalmunlock"] call fnc_cs);
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_cluster = [player,"napalm"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_napalm, [0, 1, 0, 1]];
		playSound "boots";
		support_napalm_available = true;
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
			if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
			support_count = support_count + 1;
            _speaker = localize "STR_DUWS_T_changgongpilot";
            _message = localize "STR_DUWS_T_hcchopperunlock";
            [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
            ctrlSetText [1000, format["%1",commandpointsblu1]];
            _hcAttChop = [player,"hc_ATTchop"] call BIS_fnc_addCommMenuItem;
			hcAttChop = _hcAttChop;
            lbSetColor [2103, index_support_hcAttChop, [0, 1, 0, 1]];
			playSound "boots";
            support_hcAttChop_available = true;
        } else {
            if (AttChopInUse) exitWith {hint localize "STR_DUWS_T_dvbox9ay"};
			[floor (_cost / 2), "hc_attack_heli_refund"] remoteExec ["fnc_cp_adjust", 2];
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
			if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
			support_count = support_count + 1;
            _speaker = localize "STR_DUWS_T_koipilot";
            _message = ([localize "STR_DUWS_T_hcjetunlock"] call fnc_cs);
            [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
			ctrlSetText [1000, format["%1",commandpointsblu1]];
            _hcCAS = [player,"hc_CAS"] call BIS_fnc_addCommMenuItem;
			hcCAS = _hcCAS;
            lbSetColor [2103, index_support_hcCAS, [0, 1, 0, 1]];
			playSound "boots";
            support_hcCAS_available = true;
        } else {
            if (CASInUse) exitWith {hint localize "STR_DUWS_T_dvbox9ay"};
				[floor (_cost / 2), "hc_cas_refund"] remoteExec ["fnc_cp_adjust", 2];
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
		if (support_paradrop_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
		if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
		support_count = support_count + 1;
		_speaker = localize "STR_DUWS_T_OVERLORD";
		_message = localize "STR_DUWS_T_paradropunlock";
		[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
		ctrlSetText [1000, format["%1",commandpointsblu1]];
		_supplydrop = [player,"paradrop"] call BIS_fnc_addCommMenuItem;
		lbSetColor [2103, index_support_paradrop, [0, 1, 0, 1]];
		playSound "boots";
		support_paradrop_available = true;
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
    // The flag reads "still unclaimed" here, unlike every other support flag in this file.
    if (!support_mobile_HQ_available) exitWith {hint localize "STR_DUWS_T_8c1i4vga";};
    if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_mhqunlock";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    _mhq = [player,"mobile_HQ"] call BIS_fnc_addCommMenuItem;
    lbSetColor [2103, index_mobile_HQ, [0, 1, 0, 1]];
    playSound "boots";
    support_mobile_HQ_available = false;
    publicVariable "support_mobile_HQ_available";
    ["info",[localize "STR_DUWS_T_ooi6w4yh",localize "STR_DUWS_T_cghsxhhu"]] call bis_fnc_showNotification;
};

};

//hint format["index: %1",_index2];

