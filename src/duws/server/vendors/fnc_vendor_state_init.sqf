// Executed by the registry rather than stored as one function: this file defines several. Broadcasts
// stay in server_fnc_init.sqf beside the load, so the manifest remains the one place to see what
// reaches clients.

// One row per vendor type, keyed by the string the registry stores:
// [name key, marker icon, draft weight, kind, site].
//   weight -- that type's share of a second-pass slot roll in fnc_vendor_init.
//   kind   -- what the shop deals in, which decides its stock, its price band and its delivery.
//   site   -- how its building is picked; "water" needs a shore, and "hq" (the HQ crate) is never drafted.
DUWS_vendorTypes = createHashMapFromArray [
	["arms", ["STR_DUWS_T_VENDOR_ARMS", "loc_Rifle", 1, "gear", "any"]],
	["car",  ["STR_DUWS_T_VENDOR_CAR",  "loc_car",   1, "car",  "fuel"]],
	["boat", ["STR_DUWS_T_VENDOR_BOAT", "loc_boat",  1, "boat", "water"]],
	["hq",   ["STR_DUWS_T_VENDOR_HQ",   "",          0, "gear", "hq"]]
];

// A stock row carries its category as an index into its kind's list (fnc_vendor_stock), which keeps
// the label keys off the wire.
DUWS_vendorCategories = createHashMapFromArray [
	["gear", [
		"STR_DUWS_T_VENDOR_CAT_PRIMARY", "STR_DUWS_T_VENDOR_CAT_HANDGUN", "STR_DUWS_T_VENDOR_CAT_LAUNCHER",
		"STR_DUWS_T_VENDOR_CAT_MAGAZINE", "STR_DUWS_T_VENDOR_CAT_EXPLOSIVE", "STR_DUWS_T_VENDOR_CAT_ATTACHMENT",
		"STR_DUWS_T_VENDOR_CAT_UNIFORM", "STR_DUWS_T_VENDOR_CAT_VEST", "STR_DUWS_T_VENDOR_CAT_HEADGEAR",
		"STR_DUWS_T_VENDOR_CAT_FACEWEAR", "STR_DUWS_T_VENDOR_CAT_BACKPACK", "STR_DUWS_T_VENDOR_CAT_ITEM"
	]],
	["car", [
		"STR_DUWS_T_VENDOR_CAT_CAR", "STR_DUWS_T_VENDOR_CAT_LOGI", "STR_DUWS_T_VENDOR_CAT_ARMOR",
		"STR_DUWS_T_VENDOR_CAT_HELI", "STR_DUWS_T_VENDOR_CAT_DRONE"
	]],
	["boat", ["STR_DUWS_T_VENDOR_CAT_BOAT"]]
];

// Open and closed. Colour alone carries the state: marker alpha is already the reveal channel, set
// from civ_visible in fnc_civ_town_reveal, and dimming a dead vendor as well would make one number
// mean both "undiscovered" and "closed". Open is the town icon's band colour (fnc_civ_townBand), as a
// zone's port takes the zone's, so a shop pin reads as part of its town.
#define VENDOR_COLOUR_DOWN "ColorGrey"

// An unknown type still has to answer: a draft or a marker pass that faulted on one bad row would
// take every other vendor with it.
fnc_vendor_type = {
	params ["_type"];
	DUWS_vendorTypes getOrDefault [_type, ["STR_DUWS_T_VENDOR_UNKNOWN", "c_unknown", 0, "gear", "any"]]
};

fnc_vendor_kind = { params ["_type"]; ([_type] call fnc_vendor_type) select 3 };

fnc_vendor_discount = {
	params ["_rep"];
	if (_rep >= 20) exitWith { 20 };
	if (_rep >= 10) exitWith { 10 };
	0
};

// The stock picker's entries for one type, and the server's whitelist with them: a purchase is refused
// unless the class is on the list it was priced from. A vehicle dealer opens on its own town's traffic.
fnc_vendor_lists = {
	params ["_type"];
	if (_type isEqualTo "hq") exitWith { ["hq"] };
	if (([_type] call fnc_vendor_kind) isEqualTo "gear") exitWith { ["blufor", "opfor", "all"] };
	["civilian", "blufor", "opfor", "all"]
};

// Whether a vehicle dealer of this kind may sell the class. StaticWeapon is a LandVehicle in config and
// ParachuteBase is a Helicopter, and neither a mortar nor a canopy is something a dealer sells as a hull.
fnc_vendor_hullFits = {
	params ["_kind", "_class"];
	private _cv = configFile >> "CfgVehicles";
	private _fits = switch (_kind) do {
		case "car":  {
			(_class isKindOf ["LandVehicle", _cv] && {!(_class isKindOf ["StaticWeapon", _cv])})
			|| {_class isKindOf ["Helicopter", _cv] && {!(_class isKindOf ["ParachuteBase", _cv])}}
		};
		case "boat": { _class isKindOf ["Ship", _cv] };
		default      { false };
	};
	_fits && {!([_cv >> _class] call DUWS_fnc_vehArmed)}
};

// One town's vendor records: [type, position, direction, cooldown seconds] each. That is the whole of
// what a vendor is while nothing is standing -- no unit, group or terrain-object handles, so the
// registry rebuilds from numbers and strings alone (campaign_persistence_plan.md).
fnc_vendor_recs = {
	params ["_townIndex"];
	(missionNamespace getVariable ["DUWS_vendors", []]) param [_townIndex, []]
};

fnc_vendor_markerName = {
	params ["_townIndex", "_slot"];
	format ["civ_vendor_%1_%2", _townIndex, _slot]
};

// Painted from the stored cooldown and the town's band, never from a unit handle, so the marker stays
// right while the town sleeps and across a rebuild: an uncooled vendor that is simply not simulated
// reads open.
fnc_vendor_markerPaint = {
	if (!isServer) exitWith {};
	params ["_townIndex", "_slot"];
	private _colour = if (((([_townIndex] call fnc_vendor_recs) param [_slot, []]) param [3, 0]) > 0) then {
		VENDOR_COLOUR_DOWN
	} else {
		([[_townIndex] call fnc_civ_repAt] call fnc_civ_townBand) select 1
	};
	([_townIndex, _slot] call fnc_vendor_markerName) setMarkerColor _colour;
};

// The live vendor in one slot, or objNull. Corpses stay on the roster until the town sleeps, the way
// every site roster keeps its dead, so the test has to be on the living.
fnc_vendor_live = {
	params ["_townIndex", "_slot"];
	(([[_townIndex] call fnc_town_site_key, "vendors"] call fnc_site_roster) select {
		alive _x && {(_x getVariable ["DUWS_vendor_slot", -1]) isEqualTo _slot}
	}) param [0, objNull]
};

// A sellable class lives in one of four configs and callers want whichever holds it: the display
// name, the preview and the price band all read off the same entry. CfgVehicles comes last, so a
// class that is both a weapon and a vehicle resolves as the weapon it is sold as.
fnc_vendor_classCfg = {
	params ["_class"];
	if (isClass (configFile >> "CfgMagazines" >> _class)) exitWith { configFile >> "CfgMagazines" >> _class };
	if (isClass (configFile >> "CfgGlasses" >> _class)) exitWith { configFile >> "CfgGlasses" >> _class };
	if (isClass (configFile >> "CfgWeapons" >> _class)) exitWith { configFile >> "CfgWeapons" >> _class };
	if (isClass (configFile >> "CfgVehicles" >> _class)) exitWith { configFile >> "CfgVehicles" >> _class };
	configNull
};

// True when the arsenal actually counts this class, so a bought one adds something to the shelf.
// Outside Limited mode a friendly class is already unlimited there, and stocking it would buy nothing.
// Available on clients: the catalogue greys its arsenal button with this.
fnc_vendor_poolCounts = {
	params ["_class"];
	DUWS_arsenalLimited || {!(_class in (missionNamespace getVariable ["DUWS_friendlyArsenal", []]))}
};

fnc_vendor_packSize = {
	params ["_class"];
	private _mag = configFile >> "CfgMagazines" >> _class;
	if (!isClass _mag) exitWith { 1 };
	private _sim = getText (configFile >> "CfgAmmo" >> getText (_mag >> "ammo") >> "simulation");
	if (_sim in ["shotMissile", "shotRocket"]) exitWith { 2 };
	// shotShell is the 40 mm grenade round.
	if (_sim in [
		"shotGrenade", "shotShell", "shotSmoke", "shotSmokeX", "shotIlluminating",
		"shotMine", "shotBoundingMine", "shotDirectionalBomb", "shotPipeBomb", "shotTimeBomb"
	]) exitWith { 3 };
	// The belt-fed line fnc_IsMG draws.
	if (getNumber (_mag >> "count") >= 100) exitWith { 3 };
	5
};

// Stock is fetched rather than broadcast: the Everything list is a whole-config sweep, far too large
// to push to every client at boot for a shop most of them never open. Shaped on fnc_faction_ask,
// which answers the faction browser the same way.
fnc_vendor_reply = {
	params [["_replyVar", ""], ["_rows", []], ["_discount", 0]];
	// Wrapped, so an empty answer stays distinguishable from no answer yet.
	missionNamespace setVariable [_replyVar, [_rows, _discount]];
};

// Reached by remoteExec, not remoteExecCall, so the build runs on the server's scheduler: the
// Everything sweep walks four configs and filters every class in SQF, which unscheduled would hold a
// frame for as long as it took and stall the whole session. The ask below waits it out.
fnc_vendor_query = {
	if (!isServer) exitWith {};
	params ["_kind", "_list", "_requester", "_replyVar", ["_vendor", objNull]];
	// Sent with every list rather than once per open, so a list switch also picks up a reputation move.
	private _discount = [[_vendor getVariable ["DUWS_vendor_town", -1]] call fnc_civ_repAt] call fnc_vendor_discount;
	[_replyVar, [_kind, _list] call fnc_vendor_stock, _discount] remoteExecCall ["fnc_vendor_reply", _requester];
};

// Blocks on the answer, so every caller has to be scheduled.
fnc_vendor_ask = {
	params ["_kind", "_list", ["_vendor", objNull]];
	DUWS_vendorAskSeq = (missionNamespace getVariable ["DUWS_vendorAskSeq", 0]) + 1;
	private _replyVar = format ["duws_vendor_reply_%1", DUWS_vendorAskSeq];
	[_kind, _list, player, _replyVar, _vendor] remoteExec ["fnc_vendor_query", 2];
	// A server-side throw sends no reply at all; without a deadline the catalogue would wait on it
	// for the rest of the session.
	private _deadline = diag_tickTime + 30;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _res = missionNamespace getVariable [_replyVar, []];
	missionNamespace setVariable [_replyVar, nil];
	if (_res isEqualTo []) then {
		["ERROR", "VENDOR", format ["stock request '%1/%2' went unanswered for 30 s", _kind, _list]] call fnc_log;
	};
	[_res param [0, []], _res param [1, 0]]
};
