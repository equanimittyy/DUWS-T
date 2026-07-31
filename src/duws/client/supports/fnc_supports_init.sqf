// Locality: client -- every function here runs on the machine of the player buying, refunding or
// losing a support. Executed by the registry rather than stored as one function: this file
// defines several.
//
// Two mechanisms over one catalogue. A PERM row is bought once for the whole team, recorded on
// the server so a campaign save can restore it, occupies no slot and never refunds: it is
// infrastructure, and dismantling infrastructure for cash is a different mechanic with its own
// rules. A CONS row belongs to the buyer alone, takes one of support_max_slots, and refunds every
// point it charged -- the slate is meant to be re-cut as the campaign teaches the player what
// they actually needed.
#include "..\..\shared\includes\action_style.hpp"

// The catalogue: one ordered list, permanent rows first, read by both the menu build
// (client/dialog/fnc_request_menu.sqf) and the buy/refund handler. Row order used to be literal
// indices agreed between those two files, so adding a row anywhere but the end silently
// repointed every row below it at another support's price, flag and unlock line.
//
// [key, kind, cost, flag, label, comm item, speaker, unlock line, wrap in fnc_cs, insurgent-blocked, MODERN-only]
//
// An empty unlock line means the row announces itself by notification alone, which is what the
// two depot stations have always done.
fnc_support_defs = {
	private _defs = [
		["armory",    "PERM", 10, "support_armory_available",      "STR_DUWS_T_kw2lnaig",             "",           "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_arsenalunlock",     false, false, false],
		["halo",      "PERM", 15, "support_halo_available",        "STR_DUWS_T_xghf3qqd",             "",           "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_HALOunlock",        false, true,  false],
		["repair",    "PERM",  5, "support_veh_repair_available",  "STR_DUWS_T_vehicle_repair",       "",           "",                          "",                             false, false, false],
		["recycle",   "PERM",  5, "support_veh_recycle_available", "STR_DUWS_T_zaijvhuishouzhan1",    "",           "",                          "",                             false, false, false],
		["mobile_HQ", "PERM", 10, "support_mobile_HQ_available",   "STR_DUWS_T_b7gmddq3",             "mobile_HQ",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_mhqunlock",         false, false, false],
		["fob",       "PERM", 10, "support_FOB_available",         "STR_DUWS_T_fob_request_row",      "fob_support","STR_DUWS_T_OVERLORD",       "STR_DUWS_T_fobunlock",         false, false, false],

		["supply",    "CONS",  5, "support_supplydrop_available",  "STR_DUWS_T_5n277nzo",             "ammo",       "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_supplydropunlock",  true,  false, false],
		["veh_drop",  "CONS",  5, "support_veh_drop_available",    "STR_DUWS_T_oq3q7yrq",             "veh_drop",   "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_vehicledropunlock", true,  false, true],
		["siva",      "CONS", 10, "support_siva_drop_available",   "STR_DUWS_T_jjzzkt01",             "siva_drop",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_sivaunlock",        false, true,  true],
		["sawp",      "CONS", 10, "support_sawp_drop_available",   "STR_DUWS_T_sawp1234",             "sawp_drop",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_sawpunlock",        false, true,  false],
		["uav",       "CONS", 10, "support_uav_recon_available",   "STR_DUWS_T_892wo8h0",             "uav_recon",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_uavunlock",         false, true,  true],
		["helotaxi",  "CONS",  5, "support_helotaxi_available",    "STR_DUWS_T_witoiij3",             "helo_taxi",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_helotaxiunlock",    false, false, true],
		["helolift",  "CONS", 10, "support_helolift_available",    "STR_DUWS_T_heloliftbuy",          "helo_lift",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_heloliftunlock",    false, false, true],
		["boattaxi",  "CONS",  2, "support_boattaxi_available",    "STR_DUWS_T_3wiovyga",             "boat_taxi",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_boattaxiunlock",    false, false, false],
		["arty",      "CONS", 20, "support_arty_available",        "STR_DUWS_T_btiiyafy",             "artillery",  "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_artyunlock",        false, true,  false],
		["mortar",    "CONS", 10, "support_mortar_available",      "STR_DUWS_T_xca5aaxu",             "mortar",     "STR_DUWS_T_slingshot",      "STR_DUWS_T_mtrunlock",         false, false, false],
		["jdam",      "CONS", 10, "support_jdam_available",        "STR_DUWS_T_mbhh2q2e",             "jdam",       "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_jdamunlock",        true,  true,  true],
		["laser",     "CONS", 10, "support_laser_available",       "STR_DUWS_T_xja6gemx",             "laser",      "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_laserguidedunlock", false, true,  true],
		["cluster",   "CONS", 25, "support_cluster_available",     "STR_DUWS_T_d5qzh6mj",             "cluster",    "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_clusterunlock",     true,  true,  true],
		["napalm",    "CONS", 20, "support_napalm_available",      "STR_DUWS_T_owven8ki",             "napalm",     "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_napalmunlock",      true,  true,  false],
		["hcAttChop", "CONS", 20, "support_hcAttChop_available",   "STR_DUWS_T_t4jo046q",             "hc_ATTchop", "STR_DUWS_T_changgongpilot", "STR_DUWS_T_hcchopperunlock",   false, true,  true],
		["hcCAS",     "CONS", 25, "support_hcCAS_available",       "STR_DUWS_T_6khosjp7",             "hc_CAS",     "STR_DUWS_T_koipilot",       "STR_DUWS_T_hcjetunlock",       true,  true,  true],
		["paradrop",  "CONS", 20, "support_paradrop_available",    "STR_DUWS_T_9hmlads9",             "paradrop",   "STR_DUWS_T_OVERLORD",       "STR_DUWS_T_paradropunlock",    false, true,  false]
	];

	// A row that cannot apply is absent rather than greyed, so nothing downstream needs a second
	// condition to refuse it. Insurgent-blocked rows are the exception and stay: they are greyed,
	// because a support the mode withholds is worth showing as withheld.
	_defs select {
		private _key = _x select 0;
		private _keep = true;
		if ((_x select 10) && {VERSION_X != "MODERN"}) then { _keep = false };
		// A FOB is not offered until a zone has been taken, which is what the comm item it grants
		// used to wait on.
		if (_key == "fob" && {zoneundercontrolblu < 1}) then { _keep = false };
		_keep
	}
};

fnc_support_owned = {
	params [["_flagVar", ""]];
	missionNamespace getVariable [_flagVar, false]
};

// Comm-menu bookkeeping. Every radio support is a CfgCommunicationMenu class, and the fourteen
// with removeAfterExpressionCall = 1 are deleted by the engine the moment they are used, then
// re-added by their own script when the mission ends or the cooldown expires. BIS_fnc_removeCommMenuItem
// wants the id BIS_fnc_addCommMenuItem returned, and those re-adds used to throw the new id away,
// so nothing but the two High Command aircraft could remove an item at all. A refund has to.
//
// The record below is the presence test as well as the id store: an entry exists exactly while
// the player is holding that item. That is what makes "refund what you are still carrying" a
// single check rather than a per-support in-use guard, and it is why a support in flight cannot
// be refunded out from under itself.
fnc_support_comm_add = {
	params [["_class", ""]];
	// Broadcast to everyone by the permanent-support handlers, which on a dedicated server means
	// this also lands on a machine with no player to hand the item to.
	if (_class == "" || !hasInterface) exitWith {};
	private _held = missionNamespace getVariable ["DUWS_support_comm", createHashMap];
	// Refused rather than re-added when the support is no longer owned: a refund taken while the
	// item was away on a mission has no id to remove, so this is where that removal lands.
	private _def = ([] call fnc_support_defs) select { (_x select 5) == _class };
	if (count _def > 0 && {!([(_def select 0) select 3] call fnc_support_owned)}) exitWith {};
	// A second add would leave a duplicate row in the 0-8 menu with an id nothing tracks.
	if (_class in _held) exitWith {};
	_held set [_class, [player, _class] call BIS_fnc_addCommMenuItem];
	missionNamespace setVariable ["DUWS_support_comm", _held];
};

// Called from the comm-menu expression itself (shared/includes/supports_radio_modern.hpp), which
// is the only place the engine's own removal is observable.
fnc_support_comm_used = {
	params [["_class", ""]];
	private _held = missionNamespace getVariable ["DUWS_support_comm", createHashMap];
	_held deleteAt _class;
	missionNamespace setVariable ["DUWS_support_comm", _held];
};

// Removing one item may or may not renumber the others: whether an item id is a stable handle or
// an index into a compacting array is undocumented, and the answer decides whether every other
// recorded id is still valid afterwards. Rather than depend on it, the whole slate is torn down
// in descending id order -- correct under either reading -- and rebuilt from the record, which
// yields ids that are certainly current. Only items the player is holding come back, so a support
// away on a mission is not handed back early.
fnc_support_comm_drop = {
	params [["_class", ""]];
	private _held = missionNamespace getVariable ["DUWS_support_comm", createHashMap];
	if !(_class in _held) exitWith {};
	private _keep = (keys _held) - [_class];
	private _ids = (keys _held) apply { _held get _x };
	_ids sort false;
	{ [player, _x] call BIS_fnc_removeCommMenuItem } forEach _ids;
	missionNamespace setVariable ["DUWS_support_comm", createHashMap];
	{ [_x] call fnc_support_comm_add } forEach _keep;
};

// The local half of a purchase. The buyer applies its own effects and broadcasts the flag, which
// is what fires the other clients' publicVariableEventHandlers; the server is told separately so
// the team's permanent unlocks reach a campaign save. Setting a flag true is idempotent, so this
// is not the lost-update shape pool arithmetic has to route through one writer.
fnc_support_buy = {
	params [["_def", []]];
	if (_def isEqualTo []) exitWith { false };
	_def params ["_key", "_kind", "_cost", "_flagVar", "_labelKey", "_commItem", "_speakerKey", "_msgKey", "_useCs", "_insBlocked"];

	private _insurgent = !isNil "insurgent_mode_enable" && {insurgent_mode_enable};
	if (_insBlocked && _insurgent) exitWith { hint localize "STR_DUWS_T_inssupport"; false };
	if ([_flagVar] call fnc_support_owned) exitWith { hint localize "STR_DUWS_T_8c1i4vga"; false };
	if (_kind == "CONS" && {support_count >= support_max_slots}) exitWith {
		["info", [localize "STR_DUWS_T_45a8q6tj",
			format [localize "STR_DUWS_T_SUPPORT_SLOTS_FULL", support_max_slots]]] call bis_fnc_showNotification;
		false
	};
	// The mode gives the Mobile HQ away; its label says so.
	if (_key == "mobile_HQ" && _insurgent) then { _cost = 0 };

	if !(["CP", _cost] call fnc_pool_spend) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; false };

	missionNamespace setVariable [_flagVar, true];
	if (_kind == "PERM") then {
		publicVariable _flagVar;
		[_key] remoteExec ["fnc_support_perm_grant", 2];
	} else {
		support_count = support_count + 1;
		// What the server actually debited, not the base price. fnc_pool_try_spend scales every
		// cost by escalation_multiplier on entry, so a refund computed from the base under-pays a
		// player who bought late and one computed at the current multiplier mints the difference
		// for a player who bought early.
		private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
		_paid set [_key, duws_last_charge];
		missionNamespace setVariable ["DUWS_support_paid", _paid];
	};

	[_key] call fnc_support_apply;
	[_commItem] call fnc_support_comm_add;
	if (_msgKey != "") then {
		private _message = localize _msgKey;
		if (_useCs) then { _message = [_message] call fnc_cs };
		[localize _speakerKey, _message] remoteExec ["fnc_duws_dialogue", 0];
	};
	ctrlSetText [1000, format ["%1", commandpointsblu1]];
	playSound "boots";
	true
};

// The four rows whose effect is not a comm-menu item. Keyed rather than tabled: an arsenal walks
// every FOB, HALO adds three conditional actions, and the two depot stations reach the server, so
// none of them would share a column with anything else.
fnc_support_apply = {
	params [["_key", ""]];
	switch (_key) do {
		case "armory": {
			private _arsenal = [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, true, true, "", "_this == player"];
			bluHQ_object addAction _arsenal;
			{ _x addAction _arsenal } forEach Array_of_FOBS;
			["armory", [localize "STR_DUWS_T_sg49vbhh", localize "STR_DUWS_T_h5t5vtfs"]] call bis_fnc_showNotification;
		};
		case "halo": {
			private _sites = [bluHQ_object] + Array_of_FOBS;
			{
				_x addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "", "alive player"];
				if ((vehiclevarname player) in Squad_Leaders) then {
					_x addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "", "alive player"];
					_x addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "", "alive player"];
				};
			} forEach _sites;
			["halo", [localize "STR_DUWS_T_0m2mxf4u", localize "STR_DUWS_T_adygxrb6"]] call bis_fnc_showNotification;
		};
		case "repair":  { [] remoteExec ["fnc_activateBaseRepairStation", 2] };
		case "recycle": { [] remoteExec ["fnc_activateBaseRecycleStation", 2] };
		case "mobile_HQ": {
			["info", [localize "STR_DUWS_T_ooi6w4yh", localize "STR_DUWS_T_cghsxhhu"]] call bis_fnc_showNotification;
		};
	};
};

// A consumable comes back at what it charged, which is the whole point of the slate being
// re-cuttable: the player commits at hour one to a shape they cannot evaluate until hour six.
// Refusing a support that is not in hand is the single in-use guard -- an item away on a fire
// mission, a taxi in transit or a High Command aircraft in the air is absent from the record, so
// none of them can be sold out from under the mission they are flying.
fnc_support_refund = {
	params [["_def", []]];
	if (_def isEqualTo []) exitWith { false };
	_def params ["_key", "_kind", "_cost", "_flagVar", "_labelKey", "_commItem"];

	if (_kind != "CONS") exitWith { hint localize "STR_DUWS_T_SUPPORT_NO_REFUND"; false };
	if !([_flagVar] call fnc_support_owned) exitWith { false };
	if !(_commItem in (missionNamespace getVariable ["DUWS_support_comm", createHashMap])) exitWith {
		hint localize "STR_DUWS_T_dvbox9ay";
		false
	};

	private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
	private _back = _paid getOrDefault [_key, 0];
	_paid deleteAt _key;
	missionNamespace setVariable ["DUWS_support_paid", _paid];

	[_commItem] call fnc_support_comm_drop;
	missionNamespace setVariable [_flagVar, false];
	support_count = (support_count - 1) max 0;
	if (_back > 0) then { [_back, "support_refund"] remoteExec ["fnc_cp_adjust", 2] };
	playSound "boots";
	hint format [localize "STR_DUWS_T_SUPPORT_REFUNDED", _back];
	true
};

// Death costs the player their slate. The share that comes back is deliberately small: it softens
// a wipe without making death a way to liquidate supports that a refund at the base would price
// at full. Permanent unlocks are the team's and are untouched.
fnc_support_wipe = {
	private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
	if (count _paid == 0) exitWith {};
	private _total = 0;
	{ _total = _total + _y } forEach _paid;
	private _back = round (_total * support_death_refund);

	{
		missionNamespace setVariable [(_x select 3), false];
	} forEach (([] call fnc_support_defs) select { (_x select 1) == "CONS" });

	missionNamespace setVariable ["DUWS_support_paid", createHashMap];
	// The body is gone and its comm menu with it, so there is nothing to remove -- only the record
	// of what was in it, which would otherwise refuse every re-add after respawn.
	missionNamespace setVariable ["DUWS_support_comm", createHashMap];
	support_count = 0;

	if (_back > 0) then { [_back, "support_death_refund"] remoteExec ["fnc_cp_adjust", 2] };
	[_back] spawn {
		params ["_back"];
		["info", [localize "STR_DUWS_T_SUPPORT_LOST_TITLE",
			format [localize "STR_DUWS_T_SUPPORT_LOST_MSG", _back]]] call bis_fnc_showNotification;
	};
};
