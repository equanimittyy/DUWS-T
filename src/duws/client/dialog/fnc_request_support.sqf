// Locality: client; the addAction bodies below run on the machine that triggers them, not here (invoked from a dialog action).
// Every purchase tests its own already-unlocked flag before asking the server to charge:
// the spend is a round trip, so ordering it first would both waste one and report
// "not enough CP" to a player who already owns the support.

#include "..\..\shared\includes\action_style.hpp"

_index2 = lbCurSel 2103;

// Fifteen supports differ only in these eight values. They are alike in three more that used to be
// written out per case and are now the driver's: all of them consume one of the eight radio slots,
// all play the same sound, and all hand the player a comm-menu item. The seven below the driver do
// not fit that shape -- an arsenal walks every FOB, HALO adds three conditional actions, the two
// depot stations reach the server, the two High Command aircraft can be sold back, and the Mobile
// HQ reads its flag inverted -- so they stay as code rather than becoming table columns no other
// row would use.
//
// [cost, unlock flag, listbox row, speaker, message, wrap in fnc_cs, comm item, blocked in insurgent mode]
private _supportDefs = createHashMapFromArray [
    [0, [5, "support_supplydrop_available", "index_support_supply",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_supplydropunlock", true, "ammo", false]],
    [2, [5, "support_veh_drop_available", "index_support_veh_supply",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_vehicledropunlock", true, "veh_drop", false]],
    [3, [10, "support_siva_drop_available", "index_support_siva_supply",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_sivaunlock", false, "siva_drop", true]],
    [4, [10, "support_sawp_drop_available", "index_support_sawp",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_sawpunlock", false, "sawp_drop", true]],
    [6, [10, "support_uav_recon_available", "index_support_uavrecon",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_uavunlock", false, "uav_recon", true]],
    [7, [5, "support_helotaxi_available", "index_support_helotaxi",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_helotaxiunlock", false, "helo_taxi", false]],
    [8, [10, "support_helolift_available", "index_support_helolift",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_heloliftunlock", false, "helo_lift", false]],
    [9, [2, "support_boattaxi_available", "index_support_boattaxi",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_boattaxiunlock", false, "boat_taxi", false]],
    [12, [20, "support_arty_available", "index_support_arty",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_artyunlock", false, "artillery", true]],
    [13, [10, "support_mortar_available", "index_support_mortar",
        "STR_DUWS_T_slingshot", "STR_DUWS_T_mtrunlock", false, "mortar", false]],
    [14, [10, "support_jdam_available", "index_support_jdam",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_jdamunlock", true, "jdam", true]],
    [15, [10, "support_laser_available", "index_support_laser",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_laserguidedunlock", false, "laser", true]],
    [16, [25, "support_cluster_available", "index_support_cluster",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_clusterunlock", true, "cluster", true]],
    [17, [20, "support_napalm_available", "index_support_napalm",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_napalmunlock", true, "napalm", true]],
    [20, [20, "support_paradrop_available", "index_support_paradrop",
        "STR_DUWS_T_OVERLORD", "STR_DUWS_T_paradropunlock", false, "paradrop", true]]
];

private _def = _supportDefs getOrDefault [_index2, []];
if !(_def isEqualTo []) exitWith {
    _def params ["_cost", "_flagVar", "_lbVar", "_speakerKey", "_msgKey", "_useCs", "_commItem", "_insBlocked"];

    if (_insBlocked && {!isNil "insurgent_mode_enable" && {insurgent_mode_enable}}) exitWith {
        hint localize "STR_DUWS_T_inssupport";
    };
    if (support_count > 7) exitWith {
        ["info", [localize "STR_DUWS_T_45a8q6tj", localize "STR_DUWS_T_iadwwap5"]] call bis_fnc_showNotification;
    };
    if (missionNamespace getVariable [_flagVar, false]) exitWith { hint localize "STR_DUWS_T_8c1i4vga" };
    if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv" };

    support_count = support_count + 1;
    private _message = localize _msgKey;
    if (_useCs) then { _message = [_message] call fnc_cs };
    [localize _speakerKey, _message] remoteExec ["fnc_duws_dialogue", 0];
    ctrlSetText [1000, format ["%1", commandpointsblu1]];
    [player, _commItem] call BIS_fnc_addCommMenuItem;
    // Defaulted: a row absent under this VERSION_X leaves its index global undefined, and the
    // literal that used to sit here would have coloured whatever row happened to occupy that slot.
    lbSetColor [2103, missionNamespace getVariable [_lbVar, -1], [0, 1, 0, 1]];
    playSound "boots";
    missionNamespace setVariable [_flagVar, true];
};

switch (_index2) do {

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
		bluHQ_object addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 80, true, true, "", "_this == player"];
		{
			_x addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 80, true, true, "", "_this == player"];
		} forEach (Array_of_FOBS);

		playSound "loadgun";
		publicVariable "support_armory_available";
		["armory",[localize "STR_DUWS_T_sg49vbhh",localize "STR_DUWS_T_h5t5vtfs"]] call bis_fnc_showNotification;
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
    lbSetColor [2103, index_support_halo, [0, 1, 0, 1]];
    support_halo_available = true;

    // 添加三个 HALO 动作：单人、全组、仅 AI
    bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","alive player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","alive player"];
        bluHQ_object addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","alive player"];
    };

    {
        _x addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","alive player"];
        if ((vehiclevarname player) in Squad_Leaders) then {
            _x addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","alive player"];
            _x addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","alive player"];
        };
    } forEach (Array_of_FOBS);

    playSound "loadgun";
    publicVariable "support_halo_available";
    ["halo",[localize "STR_DUWS_T_0m2mxf4u",localize "STR_DUWS_T_adygxrb6"]] call bis_fnc_showNotification;
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

// MOBILE HQ
case 21: {
    _cost = 10;
    // 叛军模式免费
    if (!isNil "insurgent_mode_enable" && insurgent_mode_enable) then {
        _cost = 0;
    };
    // Outside the eight-slot cap, like the armory and the depot stations: this buys a one-shot
    // designation token for a team-wide vehicle, not a permanent per-player capability, and it
    // is re-bought every time the MHQ is destroyed. Charging a permanent slot for a recurring
    // purchase would spend several players' slots on one vehicle over a campaign.
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
