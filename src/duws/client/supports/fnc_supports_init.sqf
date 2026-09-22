// Locality: client -- runs on the buying/refunding/losing player's machine. Called by name from
// a registry, so several functions live in this one file.
//
// PERM rows are bought once for the team, saved server-side, take no slot and never refund
// (infrastructure). CONS rows belong to the buyer, take a support_max_slots slot, and refund in
// full -- the slate is meant to be re-cut as the campaign teaches the player what they need.
#include "..\..\shared\includes\action_style.hpp"

// The catalogue: one ordered list, permanent rows first. fnc_duws_help reads it raw for the manual;
// the menu build and buy/refund handler use the filtered fnc_support_defs below.
//
// [key, kind, cost, flag, label, comm item, insurgent-blocked, AP cost]
// Column 8 is the AP half of a dual price (indirect-fire/air-strike rows, and HALO plus the upper
// two radio towers among the permanent unlocks). Absent (reads as 0 via `param [7, 0]`) elsewhere,
// which pays CP only.
//
// A support's manual description is keyed by convention, not carried here: STR_DUWS_T_sdesc_<key>.
fnc_support_catalogue = {
	[
		["armory",    "PERM", 20, "support_armory_available",      "STR_DUWS_T_kw2lnaig",             "",           false],
		["halo",      "PERM", 15, "support_halo_available",        "STR_DUWS_T_xghf3qqd",             "",           true,  30],
		// One vehicle depot buys both repair and recycle (its apply case activates both stations).
		// Flag keeps its pre-merge name (support_veh_repair_available) -- renaming it would read an
		// existing campaign save's depot as un-owned on load.
		["vehicle_depot", "PERM", 20, "support_veh_repair_available", "STR_DUWS_T_vehicle_repair",     "",           false],
		["mobile_HQ", "PERM", 10, "support_mobile_HQ_available",   "STR_DUWS_T_b7gmddq3",             "",           false],
		["fob",       "PERM", 10, "support_FOB_available",         "STR_DUWS_T_fob_request_row",      "fob_support",false],
		["logistics", "PERM", 10, "support_logistics_available",   "STR_DUWS_T_logistics_row",        "",           false],

		// Radio towers: each tier a permanent +1 to BLUFOR rep drift (DUWS_bluforRadioLevel). No comm
		// item -- owned outright once bought, mirroring the enemy's amplifier without a structure.
		["radio1",    "PERM", 15, "support_radio1_available",      "STR_DUWS_T_radio_tower_1",        "",           false],
		["radio2",    "PERM", 40, "support_radio2_available",      "STR_DUWS_T_radio_tower_2",        "",           false, 10],
		["radio3",    "PERM", 60, "support_radio3_available",      "STR_DUWS_T_radio_tower_3",        "",           false, 20],

		// Garage capacity tiers -- cap figures live in DUWS_garage_tiers (fnc_garage_spec.sqf). No comm
		// item: store/retrieve buttons live in the depot dialog, not the 0-8 menu.
		["garage1",   "PERM", 10, "support_garage1_available",     "STR_DUWS_T_garage_exp1_row",      "",           false],
		["garage2",   "PERM", 20, "support_garage2_available",     "STR_DUWS_T_garage_exp2_row",      "",           false,  5],
		["garage3",   "PERM", 40, "support_garage3_available",     "STR_DUWS_T_garage_exp3_row",      "",           false, 15],
		["garage4",   "PERM", 50, "support_garage4_available",     "STR_DUWS_T_garage_exp4_row",      "",           false, 25],

		// Slot only -- the team already paid for Mobile HQ at the permanent row, so this costs 0 CP.
		["mhq_slot",  "CONS",  0, "support_mobile_HQ_slot_available", "STR_DUWS_T_mhq_slot_row",      "mobile_HQ",  false],
		["rally",     "CONS",  0, "support_rally_available",       "STR_DUWS_T_RALLY_POINT",          "rally_point",false],
		["supply",    "CONS",  2, "support_supplydrop_available",  "STR_DUWS_T_5n277nzo",             "ammo",       false],
		["veh_drop",  "CONS",  2, "support_veh_drop_available",    "STR_DUWS_T_oq3q7yrq",             "veh_drop",   false],
		["uav",       "CONS",  3, "support_uav_recon_available",   "STR_DUWS_T_892wo8h0",             "uav_recon",  true],
		["helotaxi",  "CONS",  1, "support_helotaxi_available",    "STR_DUWS_T_witoiij3",             "helo_taxi",  false],
		["helolift",  "CONS",  2, "support_helolift_available",    "STR_DUWS_T_heloliftbuy",          "helo_lift",  false],
		["boattaxi",  "CONS",  1, "support_boattaxi_available",    "STR_DUWS_T_3wiovyga",             "boat_taxi",  false],
		["arty",      "CONS", 15, "support_arty_available",        "STR_DUWS_T_btiiyafy",             "artillery",  true,  25],
		["mortar",    "CONS",  8, "support_mortar_available",      "STR_DUWS_T_xca5aaxu",             "mortar",     false,  8],
		["mortar_smoke","CONS",3, "support_mortar_smoke_available","STR_DUWS_T_mortar_smoke_row",     "mortar_smoke",false],
		["jdam",      "CONS",  5, "support_jdam_available",        "STR_DUWS_T_mbhh2q2e",             "jdam",       true,  10],
		// Same warhead as JDAM (identical scripted damage in fnc_arty) but 2 AP cheaper: the discount is
		// earned by painting and holding the target, where JDAM is fire-and-forget on map coordinates.
		["laser",     "CONS",  5, "support_laser_available",       "STR_DUWS_T_xja6gemx",             "laser",      true,   8],
		["cluster",   "CONS", 18, "support_cluster_available",     "STR_DUWS_T_d5qzh6mj",             "cluster",    true,  30],
		["napalm",    "CONS", 12, "support_napalm_available",      "STR_DUWS_T_owven8ki",             "napalm",     true,  18],
		["hcAttChop", "CONS", 15, "support_hcAttChop_available",   "STR_DUWS_T_t4jo046q",             "hc_ATTchop", true,  15],
		["hcCAS",     "CONS", 30, "support_hcCAS_available",       "STR_DUWS_T_6khosjp7",             "hc_CAS",     true,  25],
		// Priced a shade over the 12-CP High Command rifle squad it mirrors -- same headcount, the
		// premium being the air insertion.
		["paradrop",  "CONS", 15, "support_paradrop_available",    "STR_DUWS_T_9hmlads9",             "paradrop",   true]
	]
};

// A row that cannot apply is absent rather than greyed, so nothing downstream needs a second
// condition to refuse it. Insurgent-blocked rows are the exception and stay greyed -- a support
// the mode withholds is worth showing as withheld.
fnc_support_defs = {
	([] call fnc_support_catalogue) select {
		private _key = _x select 0;
		private _keep = true;
		// A FOB is not offered until a zone has been taken, the same gate the comm item it grants waits on.
		if (_key == "fob" && {zoneundercontrolblu < 1}) then { _keep = false };
		if (_key == "mhq_slot" && {!(["support_mobile_HQ_available"] call fnc_support_owned)}) then {
			_keep = false;
		};
		if (_key in ["supply", "veh_drop", "helotaxi", "helolift", "boattaxi"] && {!(["support_logistics_available"] call fnc_support_owned)}) then {
			_keep = false;
		};
		if (_key == "rally" && {!((vehicleVarName player) in Squad_Leaders)}) then { _keep = false };
		// Radio tiers unlock in order: each hidden until the one below it is owned, so the player cannot
		// skip to III and the drift amplifier only ever climbs one step at a time.
		if (_key == "radio2" && {!(["support_radio1_available"] call fnc_support_owned)}) then { _keep = false };
		if (_key == "radio3" && {!(["support_radio2_available"] call fnc_support_owned)}) then { _keep = false };
		// Garage expansions unlock in order too, gated behind the depot then each prior level -- same
		// reasoning as the radio tiers.
		if (_key == "garage1" && {!(["support_veh_repair_available"] call fnc_support_owned)}) then { _keep = false };
		if (_key == "garage2" && {!(["support_garage1_available"] call fnc_support_owned)}) then { _keep = false };
		if (_key == "garage3" && {!(["support_garage2_available"] call fnc_support_owned)}) then { _keep = false };
		if (_key == "garage4" && {!(["support_garage3_available"] call fnc_support_owned)}) then { _keep = false };
		_keep
	}
};

// Shared by the buy menu and fnc_duws_help so both read one price from the catalogue rather than
// a baked label. fnc_escalation_cost is identity until escalation starts, so this doubles as the
// base price at mission start and the live price during play.
fnc_support_cost_bracket = {
	params ["_cost", ["_apCost", 0], ["_free", false]];
	private _cp = if (_free) then { 0 } else { [_cost] call fnc_escalation_cost };
	if (_apCost > 0) then { format [" (%1 CP, %2 AP)", _cp, _apCost] }
	else { format [" (%1 CP)", _cp] }
};

// AP tier per support key; unlisted = tier 1 (always available). Mirrors the vehicle tier rungs, so
// radio towers and garage expansions are earned in lockstep with the strikes/vehicles their tier unlocks.
DUWS_support_tiers = [
	["mobile_HQ", 2], ["mhq_slot", 2], ["radio1", 2], ["uav", 2], ["mortar", 2], ["mortar_smoke", 2],
	["jdam", 3], ["laser", 3], ["paradrop", 3], ["helolift", 3], ["halo", 3], ["radio2", 3], ["garage2", 3],
	["arty", 4], ["hcAttChop", 4], ["radio3", 4], ["garage3", 4],
	["hcCAS", 5], ["cluster", 5], ["napalm", 5], ["garage4", 5]
];
fnc_support_tier = {
	params ["_key"];
	private _i = DUWS_support_tiers findIf { (_x select 0) == _key };
	if (_i < 0) then { 1 } else { (DUWS_support_tiers select _i) select 1 }
};

fnc_support_owned = {
	params [["_flagVar", ""]];
	missionNamespace getVariable [_flagVar, false]
};

// Every radio support is a CfgCommunicationMenu class; the fourteen with removeAfterExpressionCall=1
// are deleted by the engine on use and re-added later, so the new id from BIS_fnc_addCommMenuItem
// must be kept or BIS_fnc_removeCommMenuItem (needed for a refund) has nothing to target.
// The record is also the presence test: an entry exists exactly while the item is held, so refund
// eligibility is one lookup and an in-flight support can't be refunded out from under itself.
fnc_support_comm_add = {
	params [["_class", ""]];
	// Broadcast to everyone by the permanent-support handlers, which on a dedicated server means
	// this also lands on a machine with no player to hand the item to.
	if (_class == "" || !hasInterface) exitWith {};
	private _held = missionNamespace getVariable ["DUWS_support_comm", createHashMap];
	// Refused rather than re-added when no longer owned: a refund taken while the item was away on
	// a mission has no id to remove, so this is where that removal lands.
	private _def = ([] call fnc_support_defs) select { (_x select 5) == _class };
	if (count _def > 0 && {!([(_def select 0) select 3] call fnc_support_owned)}) exitWith {};
	// A second add would leave a duplicate row in the 0-8 menu with an id nothing tracks.
	if (_class in _held) exitWith {};
	_held set [_class, [player, _class] call BIS_fnc_addCommMenuItem];
	missionNamespace setVariable ["DUWS_support_comm", _held];
};

// Called only from the comm-menu expression (shared/includes/supports_radio_modern.hpp) -- the one
// place the engine's own item removal is observable.
// Clearing the flag frees the slot and blocks fnc_support_comm_add's re-add until re-bought.
// Ownership-guarded so a stray call can't drive support_count negative; CONS only, so FOB (PERM)
// stays reusable and is never consumed.
fnc_support_consume = {
	params [["_class", ""]];
	private _def = ([] call fnc_support_defs) select { (_x select 5) == _class };
	if (count _def == 0) exitWith {};
	(_def select 0) params ["_key", "_kind", "", "_flagVar"];
	if (_kind == "CONS" && {[_flagVar] call fnc_support_owned}) then {
		missionNamespace setVariable [_flagVar, false];
		support_count = (support_count - 1) max 0;
		private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
		_paid deleteAt _key;
		missionNamespace setVariable ["DUWS_support_paid", _paid];
	};
};

fnc_support_comm_used = {
	params [["_class", ""], ["_defer", false]];
	private _held = missionNamespace getVariable ["DUWS_support_comm", createHashMap];
	_held deleteAt _class;
	missionNamespace setVariable ["DUWS_support_comm", _held];
	// A map-click support passes _defer -- it can still be aborted (map closed, no LZ) after
	// selection, so it consumes itself at its own commit point instead of here.
	if (!_defer) then { [_class] call fnc_support_consume };
};

// A dead support is a wreck/corpse the mission GC reaps on its own; a still-ALIVE one is never a
// corpse, so nothing else collects it -- this despawns it on a controlled clock instead.
// _land brings an aircraft down first, _delay lets it clear; runs in spawn so the caller never blocks.
fnc_support_despawn = {
	params ["_veh", ["_group", grpNull], ["_delay", 0], ["_land", false]];
	if (isNull _veh || {!alive _veh}) exitWith {};
	[_veh, _group, _delay, _land] spawn {
		params ["_veh", "_group", "_delay", "_land"];
		if (_land) then { _veh land "LAND"; _veh engineOn false; };
		if (_delay > 0) then { sleep _delay };
		if (!isNull _veh && {alive _veh}) then {
			{ deleteVehicle _x } forEach units _group;
			deleteVehicle _veh;
		};
	};
};

// Whether a comm-menu item id is a stable handle or an index into a compacting array is
// undocumented, so removing one item might renumber the rest. Rebuild defensively instead: tear
// down the whole slate in descending id order (correct either way) and re-add from the record.
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

// Local half of a purchase: the buyer applies effects and broadcasts the flag (fires other clients'
// publicVariableEventHandlers), then tells the server separately so PERM unlocks reach the save.
// Setting a flag true is idempotent, so this doesn't need the single-writer route pool arithmetic does.
fnc_support_buy = {
	params [["_def", []]];
	if (_def isEqualTo []) exitWith { false };
	_def params ["_key", "_kind", "_cost", "_flagVar", "_labelKey", "_commItem", "_insBlocked"];
	private _apCost = _def param [7, 0];

	// Tier gate mirrors the greyed-row lock in the list -- refused before any charge is taken.
	private _tier = [_key] call fnc_support_tier;
	if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
		hint format [localize "STR_DUWS_T_tier_locked_hint", [_tier] call DUWS_fnc_tierName]; false
	};

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

	// Dual-pool charge is atomic -- both CP and AP debit or neither does, so a refusal never leaves
	// the player charged for half a purchase.
	// Gate descriptor: the server re-derives the tier from _key and refuses the debit if unearned,
	// so the ladder holds even if this client's row-grey was bypassed.
	private _gate = ["support", _key];
	private _bought = if (_apCost > 0) then {
		["CPAP", [_cost, _apCost], _gate] call fnc_pool_spend
	} else {
		["CP", _cost, _gate] call fnc_pool_spend
	};
	if !(_bought) exitWith { hint localize "STR_DUWS_T_e95mc4lv"; false };

	missionNamespace setVariable [_flagVar, true];
	if (_kind == "PERM") then {
		publicVariable _flagVar;
		[_key] remoteExec ["fnc_support_perm_grant", 2];
	} else {
		support_count = support_count + 1;
		// Stores what was actually debited (escalation-scaled), not the base price: refunding from
		// base would under/overpay depending on when escalation moved relative to the purchase.
		// Always a [cp, ap] pair so the refund path is one shape; a CP-only purchase is wrapped with 0 AP.
		private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
		_paid set [_key, if (_apCost > 0) then { duws_last_charge } else { [duws_last_charge, 0] }];
		missionNamespace setVariable ["DUWS_support_paid", _paid];
	};

	[_key] call fnc_support_apply;
	[_commItem] call fnc_support_comm_add;
	ctrlSetText [1000, format ["%1", commandpointsblu1]];
	playSound "boots";
	true
};

// Keyed rather than tabled: arsenal walks every FOB, HALO adds three conditional actions, and the
// depot stations reach the server -- none would share a column with anything else.
fnc_support_apply = {
	params [["_key", ""]];
	switch (_key) do {
		case "armory": {
			private _arsenal = [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, true, true, "", "_this == player", ACT_REACH];
			bluHQ_object addAction _arsenal;
			{ _x addAction _arsenal } forEach Array_of_FOBS;
		};
		case "halo": {
			private _sites = [bluHQ_object] + Array_of_FOBS;
			{
				_x addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "", "alive player", ACT_REACH];
				if ((vehiclevarname player) in Squad_Leaders) then {
					_x addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "", "alive player", ACT_REACH];
					_x addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "", "alive player", ACT_REACH];
				};
			} forEach _sites;
		};
		case "vehicle_depot": {
			[] remoteExec ["fnc_activateBaseRepairStation", 2];
			[] remoteExec ["fnc_activateBaseRecycleStation", 2];
		};
	};
};

// Refund returns exactly what was charged, keeping the CONS slate re-cuttable. Requiring the item
// be in hand is the single in-use guard -- one away on a mission, in transit, or flying is absent
// from the record and can't be sold out from under itself.
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
	(_paid getOrDefault [_key, [0, 0]]) params [["_backCP", 0], ["_backAP", 0]];
	_paid deleteAt _key;
	missionNamespace setVariable ["DUWS_support_paid", _paid];

	[_commItem] call fnc_support_comm_drop;
	missionNamespace setVariable [_flagVar, false];
	support_count = (support_count - 1) max 0;
	// A dual support returns its AP too, or refunding would quietly tax the scarce pool the purchase
	// was meant to be reversible in.
	if (_backCP > 0) then { [_backCP, "support_refund"] remoteExec ["fnc_cp_adjust", 2] };
	if (_backAP > 0) then { ["BLU", _backAP, "support_refund"] remoteExec ["fnc_ap_adjust", 2] };
	// No purchase sound: that cue belongs to spending, and firing it on refund would read as a second buy.
	// AP figure is appended via the same stringtable suffix the row label uses, so it stays localised
	// rather than English-only, and the CP message keeps its single %1.
	private _msg = format [localize "STR_DUWS_T_SUPPORT_REFUNDED", _backCP];
	if (_backAP > 0) then { _msg = format [localize "STR_DUWS_T_support_ap_suffix", _msg, _backAP] };
	hint _msg;
	true
};

// Death refund is deliberately partial: softens a wipe without letting death liquidate supports
// at a discount a base refund wouldn't give. Permanent unlocks are the team's and untouched.
fnc_support_wipe = {
	private _paid = missionNamespace getVariable ["DUWS_support_paid", createHashMap];
	if (count _paid == 0) exitWith {};
	// Returns support_death_refund of the slate in both currencies -- AP isn't taxed either, the
	// same both-halves shape the manual refund uses. _paid entries are [cp, ap] pairs.
	private _totalCP = 0;
	private _totalAP = 0;
	{ _totalCP = _totalCP + (_y param [0, 0]); _totalAP = _totalAP + (_y param [1, 0]); } forEach _paid;
	private _backCP = round (_totalCP * support_death_refund);
	private _backAP = round (_totalAP * support_death_refund);

	{
		missionNamespace setVariable [(_x select 3), false];
	} forEach (([] call fnc_support_defs) select { (_x select 1) == "CONS" });

	missionNamespace setVariable ["DUWS_support_paid", createHashMap];
	// The body is gone and its comm menu with it, so there is nothing to remove -- only the record
	// of what was in it, which would otherwise refuse every re-add after respawn.
	missionNamespace setVariable ["DUWS_support_comm", createHashMap];
	support_count = 0;

	if (_backCP > 0) then { [_backCP, "support_death_refund"] remoteExec ["fnc_cp_adjust", 2] };
	if (_backAP > 0) then { ["BLU", _backAP, "support_death_refund"] remoteExec ["fnc_ap_adjust", 2] };
	[_backCP, _backAP] spawn {
		params ["_backCP", "_backAP"];
		private _msg = format [localize "STR_DUWS_T_SUPPORT_LOST_MSG", _backCP];
		if (_backAP > 0) then { _msg = format [localize "STR_DUWS_T_support_ap_suffix", _msg, _backAP] };
		["info", [localize "STR_DUWS_T_SUPPORT_LOST_TITLE", _msg]] call bis_fnc_showNotification;
	};
};
