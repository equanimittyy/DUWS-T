// Locality: server -- see callers.

// SERVER FUNCTIONS

// Server-authoritative command-point mutation. Every CP change routes here via
// remoteExec [..., 2] with a signed delta; nothing else may assign
// commandpointsblu1 or publicVariable it. The engine runs each delta as one
// uninterruptible statement on the single server copy, so concurrent changes
// from different machines serialize instead of clobbering each other with stale
// absolute values (a client's read-modify-write of its local copy otherwise
// duplicated or lost CP for the whole session in co-op).
fnc_cp_adjust = {
	if (!isServer) exitWith {};
	// _reason is a short label naming what caused the change. It exists only for the log:
	// a bare "CP -5" cannot be told apart from a death penalty, a purchase or a lost zone
	// after the fact. Optional so a missed call site still works.
	params [["_delta", 0], ["_reason", ""]];
	// Integer invariant: the HUD prints the pool raw, so a fraction reaching it renders
	// as "32.05". Round the total rather than the delta -- that also normalises a pool
	// already holding one. Sub-point payouts must accumulate whole points at the caller;
	// rounding here would swallow them silently, so a fractional delta is logged.
	if (_delta != round _delta) then {
		["WARN", "ECON", format ["fractional CP delta %1 rounded into the pool (%2)", _delta, _reason]] call fnc_log;
	};
	// Floored at 0: the pool is a count, and the death penalty plus the co-op
	// double-spend window could otherwise leave it reading negative.
	commandpointsblu1 = round ((commandpointsblu1 + _delta) max 0);
	publicVariable "commandpointsblu1";
	["INFO", "ECON", format ["CP %1 -> %2 (%3)", _delta, commandpointsblu1, _reason]] call fnc_log;
	// PV handler updates ctrl 1000 on remote clients; do it here for the host,
	// whose own publicVariableEventHandler does not fire for its own broadcast.
	if (hasInterface) then { ctrlSetText [1000, format ["%1", commandpointsblu1]]; };
};

// Server-authoritative Army Power mutation -- same delta contract as fnc_cp_adjust:
// callers remoteExec a signed delta, nothing else assigns the pools. An unrecognised
// side drops the delta and logs rather than crediting the wrong pool; no HUD counter
// to refresh. Floored at 0 like CP: losing a zone subtracts the zone's full worth, so
// an unclamped pool could sit deeply negative, and every WARCOM wave threshold reads
// "above N" anyway, so 0 and -45 already behave identically.
fnc_ap_adjust = {
	if (!isServer) exitWith {};
	params [["_side", ""], ["_delta", 0], ["_reason", ""]];
	switch (_side) do {
		case "OPF": {
			WARCOM_opfor_ap = (WARCOM_opfor_ap + _delta) max 0; publicVariable "WARCOM_opfor_ap";
			["INFO", "ECON", format ["OPF AP %1 -> %2 (%3)", _delta, WARCOM_opfor_ap, _reason]] call fnc_log;
		};
		case "BLU": {
			WARCOM_blufor_ap = (WARCOM_blufor_ap + _delta) max 0; publicVariable "WARCOM_blufor_ap";
			["INFO", "ECON", format ["BLU AP %1 -> %2 (%3)", _delta, WARCOM_blufor_ap, _reason]] call fnc_log;
		};
		default { ["ERROR", "ECON", format ["fnc_ap_adjust: unrecognised side '%1', dropped delta %2", _side, _delta]] call fnc_log; };
	};
};

// Server-authoritative reorder of the OPFOR assault queue. The map-click picker runs
// on the clicking player's machine, so mutating this shared list there and
// broadcasting the absolute array would drop a concurrent capture's edit to it.
// Matches by position value: the caller passes an entry it read from this same list,
// so a stale pick simply finds nothing rather than resurrecting a captured zone.
fnc_warcom_set_primary_zone = {
	if (!isServer) exitWith {};
	params [["_zonePos", []]];
	private _i = WARCOM_zones_controled_by_OPFOR findIf {_x isEqualTo _zonePos};
	if (_i < 0) exitWith {};
	WARCOM_zones_controled_by_OPFOR deleteAt _i;
	WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
	WARCOM_zones_controled_by_OPFOR insert [0, [_zonePos]];
	publicVariable "WARCOM_zones_controled_by_OPFOR";
};

// Server-authoritative zone-control transition. A capture or loss moves four networked
// globals at once -- both side lists and both counters -- and each used to be its own
// read-modify-write plus broadcast, so the four could be left inconsistent with each
// other as well as individually lost. Applying them together makes a transition atomic.
// Position matching is on the x/y components rather than isEqualTo: a stored zone
// position and the trigger position that reports it can differ in z.
// No floor on the counters on purpose -- they are accounting, and a negative would mean
// a zone was processed twice, which should stay visible rather than be clamped away.
fnc_zone_control_set = {
	if (!isServer) exitWith {};
	params [["_side", ""], ["_zonePos", []]];
	if (_zonePos isEqualTo []) exitWith {};
	private _fnc_dropFrom = {
		params ["_list", "_pos"];
		private _i = _list findIf {
			((_x select 0) == (_pos select 0)) && ((_x select 1) == (_pos select 1))
		};
		if (_i >= 0) then { _list deleteAt _i };
	};
	switch (_side) do {
		case "BLU": {
			WARCOM_zones_controled_by_BLUFOR pushBack _zonePos;
			[WARCOM_zones_controled_by_OPFOR, _zonePos] call _fnc_dropFrom;
			amount_zones_captured = amount_zones_captured + 1;
			zoneundercontrolblu = zoneundercontrolblu + 1;
			// Position is the only stable zone id here: the capture path never receives the
			// generation index, and the prefab name it does carry is not unique.
			["INFO", "ZONES", format ["captured by BLUFOR at %1, now holding %2",
				_zonePos, zoneundercontrolblu]] call fnc_log;
		};
		case "OPF": {
			[WARCOM_zones_controled_by_BLUFOR, _zonePos] call _fnc_dropFrom;
			// Sort by distance to HQ, then force the just-lost zone to the front: WARCOM
			// reads index 0 as the primary assault target.
			WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
			WARCOM_zones_controled_by_OPFOR insert [0, [_zonePos]];
			amount_zones_captured = amount_zones_captured - 1;
			zoneundercontrolblu = zoneundercontrolblu - 1;
			["INFO", "ZONES", format ["lost to OPFOR at %1, now holding %2, primary assault target",
				_zonePos, zoneundercontrolblu]] call fnc_log;
		};
		default { ["ERROR", "ZONES", format ["fnc_zone_control_set: unrecognised side '%1'", _side]] call fnc_log; };
	};
	publicVariable "WARCOM_zones_controled_by_BLUFOR";
	publicVariable "WARCOM_zones_controled_by_OPFOR";
	publicVariable "amount_zones_captured";
	publicVariable "zoneundercontrolblu";
};

// Drops one FOB from the three index-parallel FOB registries at once. Removal used to run as
// two independent forEach passes matching on different keys -- the building by a stringified
// position, the name by string equality -- each deleting from the array it was iterating.
// Deleting during forEach skips the next element, and two key types can disagree about which
// FOB they matched, so the registries could end up describing different FOBs at the same index.
// Nearest-within-tolerance rather than equality: the removal dialog reports a position it read
// back off the building, the destruction watcher reports one captured at build time, and those
// agree to within float noise rather than exactly. 5 m cannot reach a second FOB -- the building
// alone is wider than that.
fnc_fob_deregister = {
	if (!isServer) exitWith {};
	params [["_fobPos", []]];
	if (_fobPos isEqualTo []) exitWith {};
	private _i = Array_of_FOBpos findIf { (_x distance2D _fobPos) < 5 };
	if (_i < 0) exitWith {
		["WARN", "SUPPORT", format ["fnc_fob_deregister: no FOB registered at %1", _fobPos]] call fnc_log;
	};
	Array_of_FOBS deleteAt _i;
	Array_of_FOBname deleteAt _i;
	Array_of_FOBpos deleteAt _i;
	publicVariable "Array_of_FOBS";
	publicVariable "Array_of_FOBname";
	publicVariable "Array_of_FOBpos";
};

// Position to town index, -1 when the point sits outside every civilian radius. Open country,
// a civilians-off campaign and RAVAGE/WBK all land on -1, and every caller degrades on that
// rather than treating it as an error: a reputation charge is dropped, a reputation read comes
// back neutral.
fnc_civ_townAt = {
	if (!isServer) exitWith { -1 };
	params [["_pos", [0,0,0]]];
	private _locs = missionNamespace getVariable ["civ_locations", []];
	private _radii = missionNamespace getVariable ["civ_radii", []];
	private _found = -1;
	{
		if ((_pos distance2D (getPos _x)) < (_radii param [_forEachIndex, 0])) exitWith {
			_found = _forEachIndex;
		};
	} forEach _locs;
	_found
};

// One player, or _minAI friendly AI, within _radius of _pos. Shared by zone streaming and the
// town garrison so the two decide "BLUFOR have arrived" the same way.
// nearEntities rather than a filter over allUnits: the engine's spatial index answers this
// directly, so the cost tracks nearby units instead of every unit in the mission. Vehicles are
// queried alongside men and their crew resolved, because a CAManBase-only query does not report
// units riding in something.
// The AI threshold is a parameter because raising a position and holding one differ: two AI to
// bring it up, one to keep it there. That hysteresis stops a zone flickering off around the
// edges of the force that just took it.
fnc_duws_bluforNear = {
	if (!isServer) exitWith { false };
	params ["_pos", "_radius", ["_minAI", 2]];
	private _men = [];
	{
		if (_x isKindOf "CAManBase") then {
			if (side _x == WEST) then { _men pushBackUnique _x };
		} else {
			{ if (side _x == WEST) then { _men pushBackUnique _x } } forEach crew _x;
		};
	} forEach (_pos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius]);
	if (count _men >= _minAI) exitWith { true };
	((call BIS_fnc_ListPlayers) findIf { (_pos distance _x) < _radius }) >= 0
};

// A player within _radius of a position. Shared by the civilian-death charge and the building
// destruction charge rather than each carrying its own sweep, so the two cannot drift: presence
// is the proxy for the player having been involved and both must mean the same thing by it.
fnc_civ_playerNear = {
	if (!isServer) exitWith { false };
	params ["_pos", ["_radius", 200]];
	((call BIS_fnc_ListPlayers) findIf { (_x distance _pos) < _radius }) >= 0
};

// The reputation a town-local consumer acts on: that town's if it has one, neutral otherwise.
// Every civilian gate degrades this way rather than refusing to act, because civilians can be
// switched off and RAVAGE/WBK register no town reputation at all.
// Neutral, not a stored figure: reputation is territory, and there is nothing to be liked or
// hated by on ground no town owns. A caller that has to tell "neutral" from "not modelled"
// reads civ_town_rep directly, the way fnc_civ_townQuery does.
fnc_civ_repAt = {
	if (!isServer) exitWith { 0 };
	params [["_townIndex", -1]];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex >= 0 && _townIndex < count _reps) then {
		_reps select _townIndex
	} else {
		0
	}
};

// How a town reacts to a request: [accept, bribe, refuse], summing to 1. Split out of the roll
// that consumes it so the curve is unit-testable -- the rest of the request path needs the
// engine, this needs nothing.
//
// Piecewise linear with a kink at zero, because accept climbs faster above neutral than below
// it. Bribe is the remainder, a symmetric tent peaking at neutral: a town that neither likes
// nor hates the player is where money talks loudest, and at both extremes standing decides
// instead of coins. Neither end is a wall -- a town at -20 still takes a bribe one time in ten,
// so ground the player has ruined is expensive rather than closed.
fnc_civ_reaction_weights = {
	params [["_rep", 0]];
	private _t = ((_rep / 20) max -1) min 1;
	private _fnc_accept = {
		if (_this <= 0) then { (1 + _this) / 3 } else { (1/3) + _this * (0.9 - 1/3) }
	};
	private _accept = _t call _fnc_accept;
	// Refuse is accept's exact mirror, so the curve cannot drift out of symmetry by being
	// written twice.
	private _refuse = (-_t) call _fnc_accept;
	[_accept, 1 - _accept - _refuse, _refuse]
};

// What a menu row costs if the reaction roll comes back bribe. One table rather than a switch in
// each consumer: the request roll, the serve and the bribe answer all have to agree on the price,
// and three copies would drift. The prices are anchored on the black market the player already
// reads (goggles 1, pistol and optic 5) and are placeholders for balancing, not measured figures.
//
// An unrecognised row returns a negative price. Callers must treat that as a reject: rows only
// ever come off the wire, so this is the fail-closed edge for a client sending one the menu
// never offered.
fnc_civ_rowPrice = {
	params [["_row", ""]];
	switch (toUpper _row) do {
		case "INTEL": { 3 };
		case "RECRUIT": { 2 };
		case "AID": { 2 };
		case "TOOLKIT": { 2 };
		default { -1 };
	};
};

// A town's band colours as [ellipse, icon], keyed on reputation. One table rather than a
// literal at each paint site: the two markers must never disagree about which side a town is
// on, and marker creation needs the neutral pair before any reputation array exists.
// Blue/red rather than green, because the engine reads green as Independent, which this
// mission sets hostile to west. The icon is the deeper of each pair -- the ellipse is washed
// out on purpose so it does not compete with a zone marker at map zoom-out, and an icon drawn
// at full alpha in that same wash is unreadable against Altis terrain.
fnc_civ_townBand = {
	params [["_rep", 0]];
	if (_rep >= 10) exitWith { ["#(0.45,0.62,1.0,1)", "#(0.15,0.38,0.95,1)"] };
	if (_rep <= -10) exitWith { ["#(1.0,0.45,0.45,1)", "#(0.85,0.1,0.1,1)"] };
	["#(0.6,0.35,0.7,1)", "#(0.42,0.15,0.58,1)"]
};

// What a town pays an economy tick, as [amount, side]. A town inside the neutral band pays
// nobody, so its worth is not its income. Derived here rather than at each consumer because
// the map readout and the tick that actually pays must not be able to disagree: a readout
// promising AP the tick never credits is worse than no readout.
fnc_civ_townIncome = {
	params [["_rep", 0], ["_ap", 0]];
	if (_rep >= 10) exitWith { [_ap, "BLU"] };
	if (_rep <= -10) exitWith { [_ap, "OPF"] };
	[0, ""]
};

// Repaints one town's ellipse and icon from civ_town_rep. The band is the only writer of both
// colours -- depopulation used to paint the ellipse black and that path is gone -- so nothing
// races this. setMarkerColor takes an inline #(r,g,b,a) string as well as a CfgMarkerColors
// class name; alpha is set explicitly because a marker created without it sits at 1.
// With no civ_town_rep (RAVAGE, WBK) both markers keep the neutral pair creation gave them,
// since no band will ever repaint them.
fnc_civ_townRender = {
	if (!isServer) exitWith {};
	params ["_townIndex"];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex < 0 || _townIndex >= count _reps) exitWith {};

	([_reps select _townIndex] call fnc_civ_townBand) params ["_areaColour", "_iconColour"];
	private _area = format ["civ_area_%1", _townIndex];
	_area setMarkerColor _areaColour;
	(format ["civ_icon_%1", _townIndex]) setMarkerColor _iconColour;
	// Alpha comes from the reveal flag, not from the band: a hardcore town the player has not
	// found yet is repainted every time its reputation moves, and a flat 0.3 here would put it
	// on the map the first time a civilian was harmed in it.
	private _shown = (missionNamespace getVariable ["civ_visible", []]) param [_townIndex, true];
	_area setMarkerAlpha ([0, 0.3] select _shown);
};

// Per-town reputation, and the only reputation there is: server-only, signed delta, the writer
// owns the rounding, callers never assign. Deltas are fractional (+0.5, -0.3), so two callers
// rounding differently would compound drift into what a town will sell.
// A town index of -1 is dropped rather than charged somewhere else. Every caller resolves its
// index through fnc_civ_townAt, which answers -1 for open country, a civilians-off campaign and
// RAVAGE/WBK alike -- and reputation is territory, so harm done where no town can see it costs
// nothing. Not broadcast: no client reads civ_town_rep, and the markers below are painted with
// global-effect commands.
fnc_town_rep_adjust = {
	if (!isServer) exitWith {};
	params [["_townIndex", -1], ["_delta", 0], ["_reason", ""]];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex < 0 || _townIndex >= count _reps) exitWith {};
	private _old = _reps select _townIndex;
	private _new = ((_old + _delta) max -20) min 20;
	_new = (round (_new * 100)) / 100;
	if (abs _new < 0.01) then { _new = 0 };
	_reps set [_townIndex, _new];
	[_townIndex] call fnc_civ_townRender;
	["INFO", "CIV", format ["TOWNREP %1: %2 -> %3 (%4)", _townIndex, _old, _new, _reason]] call fnc_log;
};

// A cost with escalation applied, rounded up so a scaled price is never cheaper than the base
// one. Defined here rather than in fnc_escalation so the purchase path does not depend on
// whether escalation ever started -- with no multiplier published this is the identity.
// Available on clients too: the request menus display what a purchase will actually cost.
fnc_escalation_cost = {
	params [["_cost", 0]];
	ceil (_cost * (missionNamespace getVariable ["escalation_multiplier", 1]))
};
publicVariable "fnc_escalation_cost";

// Coins in hand. Money_roll is added as a magazine, but the ground pickup and the arsenal can
// land one in either the magazine or the item slots, so both are counted: itemsWithMagazines is
// the union and cannot report fewer coins than the player is holding. Counting magazines alone
// -- which two of the four purchase paths used to do -- can only ever undercount, and an
// undercount tells a player who can afford something that they cannot.
// Available on clients too: the civilian menu shows the player what they are carrying.
fnc_coins_count = {
	params ["_unit"];
	if (isNull _unit) exitWith { 0 };
	{ _x == "Money_roll" } count (itemsWithMagazines _unit)
};
publicVariable "fnc_coins_count";

// Spends coins and reports whether it could. Server-only, and the caller says nothing about the
// price until this returns: a client's count is a snapshot, and in co-op two players can spend
// the same coins, so this read and the removal are adjacent statements on the one machine that
// owns the inventory -- the same reason fnc_pool_try_spend exists for CP.
//
// Both removal commands are needed because both slots are counted, and each ignores the other's.
// Callers own the refusal message: the four purchase paths word it differently and one of them
// closes a civilian on top.
fnc_coins_spend = {
	if (!isServer) exitWith { false };
	params ["_unit", ["_amount", 0]];
	if (([_unit] call fnc_coins_count) < _amount) exitWith { false };
	private _left = _amount;
	{
		if (_x == "Money_roll" && _left > 0) then {
			_unit removeItem "Money_roll";
			_left = _left - 1;
		};
	} forEach (items _unit);
	{
		if (_x == "Money_roll" && _left > 0) then {
			_unit removeMagazineGlobal "Money_roll";
			_left = _left - 1;
		};
	} forEach (magazines _unit);
	// Fail loud rather than half-charge: a caller that gets false must not deliver the goods.
	_left <= 0
};
publicVariable "fnc_coins_spend";

// Server-authoritative purchase. The writers above own the arithmetic but not the
// decision: a client testing its own copy of a pool is a network round trip out of date,
// so two clients each seeing 10 CP both pass a 10 CP gate and the floor absorbs the
// second debit, making it free. Here the test and the debit are adjacent statements
// against the one server copy, so no other machine's request lands between them.
// remoteExec returns nothing, so the verdict goes back as a named reply the caller waits
// on -- fnc_pool_spend is the other half of the handshake.
// The debit is `call`, not remoteExec to self: that would queue a scheduled job for a
// later frame and reopen the gap this function exists to close.
fnc_pool_try_spend = {
	if (!isServer) exitWith {};
	params [["_pool", ""], ["_cost", 0], ["_requester", objNull], ["_replyVar", ""]];
	private _ok = false;
	// Attribution comes from _requester rather than a threaded-through label: the 40 client
	// purchase sites all reach here via fnc_pool_spend, which knows the cost but not what
	// the player was buying.
	private _who = format ["purchase by %1", name _requester];
	// One application point for the escalation multiplier: every fnc_pool_spend site reaches
	// here, so scaling on entry covers all of them. The four server-side paths that call
	// fnc_cp_adjust directly bypass this handshake and apply it themselves.
	_cost = [_cost] call fnc_escalation_cost;
	switch (_pool) do {
		case "CP": { if (commandpointsblu1 >= _cost) then { [-_cost, _who] call fnc_cp_adjust; _ok = true; }; };
		case "AP": { if (WARCOM_blufor_ap >= _cost) then { ["BLU", -_cost, _who] call fnc_ap_adjust; _ok = true; }; };
		default { ["ERROR", "ECON", format ["fnc_pool_try_spend: unrecognised pool '%1', refused %2", _pool, _cost]] call fnc_log; };
	};
	[_replyVar, _ok] remoteExec ["fnc_pool_reply", _requester];
};

// Client half of the purchase handshake: blocks until the server rules on the request,
// so callers must already be scheduled -- every purchase entry point is spawned. Refuses
// on timeout rather than falling through: silence must not let a purchase happen.
// A zero cost short-circuits, because several comm-menu supports are charged at unlock
// time and pass 0 here.
fnc_pool_spend = {
	params [["_pool", "CP"], ["_cost", 0]];
	if (_cost <= 0) exitWith { true };
	duws_spend_seq = (missionNamespace getVariable ["duws_spend_seq", 0]) + 1;
	private _replyVar = format ["duws_spend_reply_%1", duws_spend_seq];
	[_pool, _cost, player, _replyVar] remoteExec ["fnc_pool_try_spend", 2];
	private _deadline = diag_tickTime + 5;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _replied = !isNil _replyVar;
	private _ok = missionNamespace getVariable [_replyVar, false];
	missionNamespace setVariable [_replyVar, nil];
	// A timeout and a refusal look identical to the caller, so log the difference: without
	// it a dropped reply reads in-game as "not enough CP" with a full pool.
	if (!_replied) then { ["WARN", "ECON", format ["fnc_pool_spend: no reply for %1 %2, refused", _cost, _pool]] call fnc_log; };
	_ok
};
publicVariable "fnc_pool_spend";

fnc_pool_reply = {
	params [["_replyVar", ""], ["_ok", false]];
	missionNamespace setVariable [_replyVar, _ok];
};
publicVariable "fnc_pool_reply";

// Server-authoritative fire-mission slot, one per support type. Unlocks and cooldowns are both
// per player, so nothing stopped two squad leads walking mortars onto the map at the same moment
// and talking over each other on the net for the whole salvo.
//
// The slot carries an expiry as well as an explicit release. A caller that disconnects, dies or
// errors out between claiming and releasing would otherwise hold its support type for the rest
// of the campaign, and a fire mission that never comes back is a worse bug than two at once.
fnc_support_try_claim = {
	if (!isServer) exitWith {};
	params [["_type", ""], ["_hold", 300], ["_requester", objNull], ["_replyVar", ""]];
	private _key = format ["duws_support_busy_%1", _type];
	private _ok = time > (missionNamespace getVariable [_key, 0]);
	if (_ok) then { missionNamespace setVariable [_key, time + _hold]; };
	[_replyVar, _ok] remoteExec ["fnc_support_reply", _requester];
};

fnc_support_release = {
	if (!isServer) exitWith {};
	params [["_type", ""]];
	missionNamespace setVariable [format ["duws_support_busy_%1", _type], 0];
};

fnc_support_reply = {
	params [["_replyVar", ""], ["_ok", false]];
	missionNamespace setVariable [_replyVar, _ok];
};
publicVariable "fnc_support_reply";

// Client half of the slot handshake, same shape as fnc_pool_spend: blocks on the server's
// ruling, so callers must already be scheduled. Refuses on timeout rather than falling through --
// two simultaneous fire missions is the thing this exists to prevent, so a dropped reply must
// not read as a free slot.
fnc_support_claim = {
	params [["_type", ""], ["_hold", 300]];
	duws_support_seq = (missionNamespace getVariable ["duws_support_seq", 0]) + 1;
	private _replyVar = format ["duws_support_reply_%1", duws_support_seq];
	[_type, _hold, player, _replyVar] remoteExec ["fnc_support_try_claim", 2];
	private _deadline = diag_tickTime + 5;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _replied = !isNil _replyVar;
	private _ok = missionNamespace getVariable [_replyVar, false];
	missionNamespace setVariable [_replyVar, nil];
	if (!_replied) then { ["WARN", "SUPPORT", format ["fnc_support_claim: no reply for %1, refused", _type]] call fnc_log; };
	_ok
};
publicVariable "fnc_support_claim";

// Player-callsign substitution for radio/subtitle dialogue. The stringtable bakes
// the default callsign "Alpha 1-1" into the English lines; this swaps it for the
// host-chosen duws_callsign at display time, so wrapping every localize is safe:
// it is a no-op when the callsign is unset, still the default, or the line has no
// callsign token. Only the literal "Alpha 1-1" is touched -- other callsigns
// (Overlord, Allseer, Dispatch) and non-English translations are left as-is, which
// is why localised callsigns intentionally lag the English one.
fnc_cs = {
	params [["_s", ""]];
	if (isNil "duws_callsign") exitWith {_s};
	if (duws_callsign isEqualTo "Alpha 1-1") exitWith {_s};
	private _find = "Alpha 1-1";
	private _flen = count _find;
	private _n = count _s;
	private _out = "";
	private _i = 0;
	while {_i < _n} do {
		if ((_s select [_i, _flen]) isEqualTo _find) then {
			_out = _out + duws_callsign;
			_i = _i + _flen;
		} else {
			_out = _out + (_s select [_i, 1]);
			_i = _i + 1;
		};
	};
	_out
};
publicVariable "fnc_cs";

// Speaker -> surface, for fnc_duws_dialogue. NET is the explicit list and VOICE the
// default, so a callsign added later without a table entry lands on the loud surface where
// it is visible in the first minute of play, rather than disappearing into a chat box
// nobody is watching.
// Kept pure and out of the router because the router touches localize, chat and UI, none
// of which exist in the headless test VM -- this is the one part the lint cannot check.
fnc_duws_dialogue_channel = {
    params [["_speaker", ""], ["_netSpeakers", []]];
    // fnc_fob_server builds its speaker with format and interpolates a position array.
    // That is pre-existing; it must not reach `in` against a table of strings.
    if !(_speaker isEqualType "") exitWith {"VOICE"};
    if (_speaker in _netSpeakers) exitWith {"NET"};
    "VOICE"
};
publicVariable "fnc_duws_dialogue_channel";

// Hand an object to the map cleanup, to be deleted _ttd seconds from now once no player is
// near it. Opt-in by whoever created the object, because class cannot tell these apart: a
// supply drop and the HQ arsenal crate are both B_supplyCrate_F, and three side missions use
// crate classes for their objectives. Only the code that made the thing knows it is litter.
// Callable from anywhere -- a client call forwards itself to the server, which owns the sweep.
fnc_duws_disposeAfter = {
    params ["_obj", ["_ttd", 1800]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_disposeAfter", 2] };
    // Living entities are out of scope here -- they have their own spawn and despawn logic.
    // Refused rather than trusted to callers: the sweep spares anything with living crew, and
    // crew of a man on foot is the man, so one reaching the disposal list would never leave it.
    if (_obj isKindOf "CAManBase") exitWith {};
    DUWS_disposables pushBack [_obj, _ttd];
};
publicVariable "fnc_duws_disposeAfter";

// Mark an object as part of a standing composition -- the BLUFOR HQ, a FOB, a zone prefab, a
// hardpoint. Tagged persistent so no cleanup sweep touches it, and filed under _key so the
// whole composition can be released together.
// Membership is tracked rather than inferred, because inference cannot work: when a hardpoint
// is wrecked its sandbags and camo net are undamaged props, and no test applied to those
// objects -- dead, immobile, litter class -- would ever collect them. Only the key knows they
// belonged to something that is now gone.
// One object, one key. Nothing enforces it, but release drops the persistent flag
// unconditionally, so filing something under two keys means retiring either of them strips the
// protection while the other still lists it as a member.
// _pinned marks a member whose effect depends on its existing rather than on being looked at --
// an artillery piece, a mortar, an AA gun. Streaming those removes a capability instead of
// deferring a cost: an aircraft crosses the gate's radius in a few seconds, so a stowed AA gun
// would never engage anything. Declared by the caller rather than tested by class at stow time,
// because only the code that placed the object knows why it is there, and a class test would have
// to be kept in step with every faction mod's turret names. Local: only the server stows.
fnc_duws_keep = {
    params ["_obj", ["_key", "world"], ["_pinned", false]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_keep", 2] };
    // Props and vehicles only. A unit's presence on the map is decided by its own spawn and
    // despawn logic, and a composition that owned one could not release it without fighting
    // that logic for control of the same entity.
    if (_obj isKindOf "CAManBase") exitWith {};
    _obj setVariable ["persistent", true, true];
    if (_pinned) then { _obj setVariable ["DUWS_noStow", true] };
    // Filing anything under a retired key revives it, so a hardpoint rebuilt at the same rounded
    // coordinates as a cleared one does not inherit its predecessor's retirement.
    private _wasRetired = DUWS_retired find _key;
    if (_wasRetired >= 0) then { DUWS_retired deleteAt _wasRetired };
    // Nulls pruned on the way in: a FOB rebuild deletes its old ring outright rather than
    // releasing it, so without this the key accumulates dead references for the whole campaign.
    private _members = (DUWS_compositions getOrDefault [_key, []]) select {!isNull _x};
    _members pushBackUnique _obj;
    DUWS_compositions set [_key, _members];
};
publicVariable "fnc_duws_keep";

// The composition is gone: drop the protection from every part and hand the lot to the sweep.
// Deletion still respects the keep-radius, so a hardpoint wrecked under the player's nose
// clears once they leave rather than in front of them.
fnc_duws_release = {
    params ["_key", ["_ttd", 300]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_release", 2] };
    {
        _x setVariable ["persistent", false, true];
        [_x, _ttd] call fnc_duws_disposeAfter;
    } forEach (DUWS_compositions getOrDefault [_key, []]);
    DUWS_compositions deleteAt _key;
    // Stowed members do not exist, so there is nothing to hand the sweep -- but the records have to
    // go, or a retired composition redeploys intact the next time someone walks up to it.
    DUWS_stowed deleteAt _key;
    // Terminal, and readable as such. A gate cycling this composition needs to know it is finished
    // rather than infer it from the key being absent, which is equally true before build-out ran.
    DUWS_retired pushBackUnique _key;
};
publicVariable "fnc_duws_release";

// Take a composition off the map, holding the data needed to put it back. Distinct from
// fnc_duws_release: release retires a composition for good and drops its key, where stow keeps the
// key so the same one can return.
// Deletion is immediate rather than handed to the sweep, because removing the entity is the whole
// point -- a stowed member has to leave allMissionObjects, the curator's editable set and the
// spatial index at once, and the sweep's keep-radius would hold it instead.
// Refuses while a streamable member is crewed. fnc_spawnWait leaves gunners sitting in static
// weapons alive (its despawn pass tests vehicle _x == _x), so stowing regardless would delete a
// manned gun and strand the AI where its turret was. Retrying on the next cycle is the safe
// failure. Pinned members are excluded from that test on purpose: they keep their crew by design,
// so counting them would block their composition from ever stowing.
fnc_duws_stow = {
    params ["_key"];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_stow", 2] };
    if !(_key in DUWS_compositions) exitWith { false };
    private _members = (DUWS_compositions getOrDefault [_key, []]) select {!isNull _x};
    private _pinned = _members select {_x getVariable ["DUWS_noStow", false]};
    private _streamable = _members - _pinned;
    if ((_streamable findIf {({alive _x} count crew _x) > 0}) >= 0) exitWith { false };
    private _records = [];
    {
        // Dead members go unrecorded, so what a player destroyed stays destroyed. A ruined
        // building is a separate object the BuildingChanged handler has already claimed.
        if (alive _x) then {
            // Cargo travels with the crate. Contents are rolled by fnc_fill_ammobox and drawn down
            // by players, so replaying the classname alone hands back a crate someone emptied.
            private _cargo = [];
            if (_x isKindOf "ReammoBox_F") then {
                _cargo = [getWeaponCargo _x, getMagazineCargo _x,
                    getItemCargo _x, getBackpackCargo _x];
            };
            // Simulation and damage state are recorded because the prefabs set them per object --
            // props ship with simulation off and several are invulnerable. A deploy that guessed
            // would quietly re-simulate every prop on the map.
            _records pushBack [typeOf _x, getPosWorld _x, [vectorDir _x, vectorUp _x],
                simulationEnabled _x, isDamageAllowed _x, _cargo];
        };
        deleteVehicle _x;
    } forEach _streamable;
    // Pinned members never left, so the key keeps its place in DUWS_compositions holding just
    // them. Dropped entirely when nothing was pinned, so the common case stays a single entry.
    if (count _pinned == 0) then {
        DUWS_compositions deleteAt _key;
    } else {
        DUWS_compositions set [_key, _pinned];
    };
    DUWS_stowed set [_key, _records];
    true
};
publicVariable "fnc_duws_stow";

// Rebuild a stowed composition. Members come back as new objects, so nothing holding a reference
// to the old ones survives a stow -- the key is the only identity a composition has across one,
// which is why membership is re-filed through fnc_duws_keep rather than restored.
fnc_duws_deploy = {
    params ["_key"];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_deploy", 2] };
    {
        _x params ["_class", "_pos", "_vectorDirUp", "_sim", "_damageAllowed", "_cargo"];
        private _obj = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
        // Before it is placed, not after: this loop is scheduled code, so the engine can suspend it
        // between any two statements, and a prop that is still simulated over a frame boundary
        // settles or slides off the position just written to it.
        _obj enableSimulationGlobal _sim;
        // Placed again after creation: createVehicle reads its position as AGL, and the record
        // holds world coordinates. Without this a prop on a slope returns metres into the hill.
        _obj setPosWorld _pos;
        _obj setVectorDirAndUp _vectorDirUp;
        // Rotating displaces the object, so the position has to be written a second time after it.
        // The prefabs that place these props do the same around their setDir for the same reason.
        _obj setPosWorld _pos;
        _obj allowDamage _damageAllowed;
        if (count _cargo > 0) then {
            clearWeaponCargoGlobal _obj;
            clearMagazineCargoGlobal _obj;
            clearItemCargoGlobal _obj;
            clearBackpackCargoGlobal _obj;
            (_cargo select 0) params ["_wTypes", "_wCounts"];
            (_cargo select 1) params ["_mTypes", "_mCounts"];
            (_cargo select 2) params ["_iTypes", "_iCounts"];
            (_cargo select 3) params ["_bTypes", "_bCounts"];
            { _obj addWeaponCargoGlobal [_x, _wCounts select _forEachIndex] } forEach _wTypes;
            { _obj addMagazineCargoGlobal [_x, _mCounts select _forEachIndex] } forEach _mTypes;
            { _obj addItemCargoGlobal [_x, _iCounts select _forEachIndex] } forEach _iTypes;
            { _obj addBackpackCargoGlobal [_x, _bCounts select _forEachIndex] } forEach _bTypes;
        };
        [_obj, _key] call fnc_duws_keep;
    } forEach (DUWS_stowed getOrDefault [_key, []]);
    DUWS_stowed deleteAt _key;
};
publicVariable "fnc_duws_deploy";

// Debug-menu entry point for the map cleanup: sweep now, with every lifetime treated as elapsed,
// so a tester does not wait 30 min to see collection happen. The sweep's interval wait breaks on
// this flag, so it lands within half a second. Bounded by what it cannot skip -- KEEP_RADIUS and
// the persistent flag -- so the worst a client reaching it can do is bin distant litter early.
// Not published, because nothing calls it locally: the menu remoteExecs it to the server, the
// only machine holding the deadlines.
fnc_duws_forceCleanup = {
    DUWS_cleanup_force = true;
    ["INFO", "CLEANUP", "Forced sweep requested from the debug menu."] call fnc_log;
};

// Debug-menu entry point for composition streaming: stow the nearest zone, or deploy it if it is
// already stowed. Takes the caller's position because the server has no player of its own to
// measure from. Not published, for the same reason fnc_duws_forceCleanup is not.
fnc_duws_toggleNearestZone = {
    params ["_pos"];
    if (count zone_meta_array == 0) exitWith {};
    private _best = [];
    {
        private _zonePos = _x select 1;
        if (_best isEqualTo [] || {_pos distance _zonePos < _pos distance _best}) then {
            _best = _zonePos;
        };
    } forEach zone_meta_array;
    private _key = format ["zone_%1_%2", round (_best select 0), round (_best select 1)];
    if (_key in DUWS_stowed) then {
        [_key] call fnc_duws_deploy;
        ["INFO", "STREAM", format ["deployed %1", _key]] call fnc_log;
    } else {
        private _stowed = [_key] call fnc_duws_stow;
        ["INFO", "STREAM", format ["stow %1: %2", _key,
            ["refused", "done"] select _stowed]] call fnc_log;
    };
};

// STARTUP FUNCTIONS
fnc_BluHQinit = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BluHQinit.sqf";
fnc_factions_check = compile preprocessFileLineNumbers "duws\server\misc\fnc_factions_check_modern.sqf";
fnc_intro_heli = compile preprocessFileLineNumbers "duws\server\misc\fnc_intro_heli.sqf";
publicVariable "fnc_intro_heli";
// SERVER INIT FUNCTIONS
fnc_init_OPFOR_WARCOM = compile preprocessFileLineNumbers "duws\server\warcom\fnc_init_OPFOR_WARCOM.sqf";
fnc_OPFOR_faction_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_OPFOR_faction_init.sqf";
fnc_OPFOR_squad_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_OPFOR_squad_init.sqf";
fnc_repetitive_cleanup = compile preprocessFileLineNumbers "duws\server\misc\fnc_repetitive_cleanup.sqf";
fnc_capture_zones_task = compile preprocessFileLineNumbers "duws\server\misc\fnc_capture_zones_task.sqf";
fnc_AI_Master_Control = compile preprocessFileLineNumbers "duws\server\misc\fnc_AI_Master_Control.sqf";
fnc_weather = compile preprocessFileLineNumbers "duws\server\dialog\fnc_weather.sqf";
fnc_zeus_objects_init = compile preprocessFileLineNumbers "duws\server\misc\fnc_zeus_objects_init.sqf";
fnc_usableBuildings = compile preprocessFileLineNumbers "duws\server\misc\fnc_usableBuildings.sqf";
fnc_fob_destroyed = compile preprocessFileLineNumbers "duws\server\misc\fnc_fob_destroyed.sqf";
// Not broadcast: it creates a global marker, so exactly one machine may run it.
fnc_baseRangeMarker = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseRangeMarker.sqf";
// Not broadcast: it decides which players a base appearing is visible to, which only the server can.
fnc_baseFade = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseFade.sqf";
fnc_create_ammo_lists = compile preprocessFileLineNumbers "duws\server\misc\fnc_create_ammo_lists.sqf";
fnc_basic_ammo_lists = compile preprocessFileLineNumbers "duws\server\misc\fnc_basic_ammo_lists.sqf";
fnc_escalation = compile preprocessFileLineNumbers "duws\server\misc\fnc_escalation.sqf";
fnc_civ_garrison = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_garrison.sqf";
fnc_ai_rearm = compile preprocessFileLineNumbers "duws\client\misc\fnc_ai_rearm.sqf";publicVariable "fnc_ai_rearm";
fnc_addRandomLoot = compile preprocessFileLineNumbers "duws\server\misc\fnc_addRandomLoot.sqf";
publicVariable "fnc_addRandomLoot";
fnc_hirePartisans_spawnDeployed = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans_spawnDeployed.sqf";
publicVariable "fnc_hirePartisans_spawnDeployed";
fnc_addBoardKillhouseActions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_addBoardKillhouseActions.sqf";
publicVariable "fnc_addBoardKillhouseActions";
fnc_killhouse_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_killhouse_markers.sqf";
publicVariable "fnc_killhouse_markers";
// SIDE MISSION FUNCTIONS
fnc_mission_reward = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_reward.sqf";
fnc_missionTimer = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTimer.sqf";
fnc_missionTargetPos = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTargetPos.sqf";
fnc_missionMarkerData = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionMarkerData.sqf";
fnc_missionTaskCreate = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskCreate.sqf";
fnc_missionTaskEnd = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskEnd.sqf";
fnc_missionPatrols = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionPatrols.sqf";
fnc_missionPatrolswithintel = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionPatrolswithintel.sqf";
fnc_mission_cleanup = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_cleanup.sqf";
// 动态氛围任务系统
fnc_findSafeMissionPos = compile preprocessFileLineNumbers "duws\server\misc\fnc_findSafeMissionPos.sqf";
publicVariable "fnc_findSafeMissionPos";
fnc_dynamicAtmosphere_init = compile preprocessFileLineNumbers "duws\server\missions\dyna\fnc_dynamicAtmosphere_init.sqf";
publicVariable "fnc_dynamicAtmosphere_init";

// Opens every side-mission thread: cooldown gate, cooldown stamp, and the mission lock.
// Returns false when the caller must abort -- the caller has to exit itself, because
// neither exitWith nor breakOut inside a called function can terminate its caller's scope.
// The 17 copies this replaces tried to, via `breakOut "main"` into a scope no thread
// declares, so a mission on cooldown unwound through an undefined scope name.
fnc_mission_begin = {
	// _requester is remoteExecutedOwner read in the calling thread -- it must be sampled
	// there, in the scope remoteExec actually entered. 0 means the thread was called
	// locally, in which case a plain hint is the only machine there is to reach.
	params ["_missionType", "_MissionPos", "_mission_name", ["_requester", 0], ["_cooldown", 3600]];
	private _var = format ["mission_cooldown_%1", _missionType];
	private _until = missionNamespace getVariable [_var, 0];
	if (_until > diag_tickTime) exitWith {
		private _remaining = _until - diag_tickTime;
		// Floor the seconds too: diag_tickTime is fractional, so an unfloored remainder reaches
		// format at full precision and the hint reads "59 min 0.000381 sec".
		private _parts = [floor (_remaining / 60), floor (_remaining % 60)];
		// Localised on the receiving machine: the server's language is not the player's.
		if (_requester > 0) then {
			[_parts, {
				hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _this select 0, _this select 1];
			}] remoteExec ["spawn", _requester];
		} else {
			hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _parts select 0, _parts select 1];
		};
		["DEBUG", "MISSION", format ["type=%1 refused, %2s of cooldown left",
			_missionType, round _remaining]] call fnc_log;
		false
	};
	missionNamespace setVariable [_var, diag_tickTime + _cooldown, true];
	// Holds off the next mission until this thread finishes; each thread clears it on exit.
	Mission_available = false;
	publicVariable "Mission_available";
	["INFO", "MISSION", format ["start type=%1 name=%2 pos=%3",
		_missionType, _mission_name, _MissionPos]] call fnc_log;
	// Every mission generates an operation name and, until now, only ever showed it in the task
	// list. Announced here rather than in the seventeen threads: this is the one line all of
	// them pass through, so a card added anywhere else would cover some missions and not others.
	// Typed rather than titleText'd, to match the card the campaign opens with. Spawned on each
	// client rather than remoteExec'd straight to BIS_fnc_typeText: it sleeps between characters,
	// which throws in the unscheduled environment remoteExec would call it in.
	[_mission_name, {
		[[[toUpper _this, "<t align='center' shadow='1' size='1'>%1</t>"]]] spawn BIS_fnc_typeText;
	}] remoteExec ["spawn", [0,-2] select isDedicated];
	true
};

// SIDE MISSION THREADS
fnc_rescue_squad_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_mission.sqf";
fnc_rescue_squad_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_success.sqf";
fnc_steal_supply_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_supply\fnc_steal_supply_mission.sqf";
fnc_transport_IDAP_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\transport_idap\fnc_transport_IDAP_mission.sqf";
fnc_target_hvt_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_hvt\fnc_target_hvt_mission.sqf";
fnc_destroy_tower_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_tower\fnc_destroy_tower_mission.sqf";
fnc_rescue_pilot_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_pilot\fnc_rescue_pilot_mission.sqf";
fnc_target_sniper_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_sniper\fnc_target_sniper_mission.sqf";
fnc_domination_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\domination\fnc_domination_mission.sqf";
fnc_clearthearea_cqb_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\clearthearea_cqb\fnc_clearthearea_cqb_mission.sqf";
fnc_holdposition_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\holdpos\fnc_holdposition_mission.sqf";
fnc_protect_civ_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ.sqf";
fnc_steal_builder_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_builder\fnc_steal_builder_mission.sqf";
fnc_target_armor_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_armor\fnc_target_armor_mission.sqf";
fnc_sabotage_laptop_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_mission.sqf";
fnc_sabotage_laptop_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_success.sqf";
fnc_destroy_cache_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_cache\fnc_destroy_cache_mission.sqf";
fnc_destroy_radar_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_radar\fnc_destroy_radar_mission.sqf";
fnc_dyna_mission_mortarspotter = compile preprocessFileLineNumbers "duws\server\missions\dyna\fnc_dyna_mission_mortarspotter.sqf";
publicVariable "fnc_dyna_mission_mortarspotter";
fnc_dyna_mission_supply_recovery = compile preprocessFileLineNumbers "duws\server\missions\dyna\fnc_dyna_mission_supply_recovery.sqf";
publicVariable "fnc_dyna_mission_supply_recovery";
fnc_add_intel_on_death = compile preprocessFileLineNumbers "duws\server\misc\fnc_add_intel_on_death.sqf";
publicVariable "fnc_add_intel_on_death";
fnc_corpse_search_action = compile preprocessFileLineNumbers "duws\client\misc\fnc_corpse_search_action.sqf";
publicVariable "fnc_corpse_search_action";
fnc_add_intel_to_group = compile preprocessFileLineNumbers "duws\server\misc\fnc_add_intel_to_group.sqf";
publicVariable "fnc_add_intel_to_group";
fnc_intel_gathering_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\intel_gathering\fnc_intel_gathering_mission.sqf";
publicVariable "fnc_intel_gathering_mission";
// CIVILIAN FUNCTIONS
fnc_civ_init_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_init_Tomata.sqf";
fnc_civ_setup_array = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_setup_array.sqf";
fnc_civ_selectTowns = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_selectTowns.sqf";
// Broadcast for the same reason the RAVAGE and WBK handlers are: the town presence trigger names
// it, and that trigger is global, so every machine evaluates it and every machine runs the body.
fnc_civ_town_reveal = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_town_reveal.sqf";
publicVariable "fnc_civ_town_reveal";
// The board's map readout. The query is broadcast because a client is what calls it, and the
// two display halves because the server is what calls them back.
fnc_civ_townQuery = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_townQuery.sqf";
publicVariable "fnc_civ_townQuery";
fnc_civ_townInfo = compile preprocessFileLineNumbers "duws\client\misc\fnc_civ_townInfo.sqf";
publicVariable "fnc_civ_townInfo";
fnc_civ_mapView = compile preprocessFileLineNumbers "duws\client\misc\fnc_civ_mapView.sqf";
publicVariable "fnc_civ_mapView";
fnc_civ_wp_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_wp_Tomata.sqf";
// Server-only, and deliberately not broadcast: the FiredNear handler that calls it is added on
// this machine alone, and a client that could run it could scatter a town at will.
fnc_civ_panic = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_panic.sqf";
fnc_civ_rep_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_rep_Tomata.sqf";
fnc_recruit_civilian = compile preprocessFileLineNumbers "duws\shared\functions\fnc_recruit_civilian.sqf";
publicVariable "fnc_recruit_civilian";
fnc_recruit_civilian_server = compile preprocessFileLineNumbers "duws\server\misc\fnc_recruit_civilian_server.sqf";
publicVariable "fnc_recruit_civilian_server";
fnc_addRecruitAction = compile preprocessFileLineNumbers "duws\shared\functions\fnc_addRecruitAction.sqf";
publicVariable "fnc_addRecruitAction";
fnc_night_horde_event = compile preprocessFileLineNumbers "duws\server\misc\fnc_night_horde_event.sqf";
publicVariable "fnc_night_horde_event";
fnc_civ_healed = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_healed.sqf";
fnc_civ_stopCommand = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_stopCommand.sqf";
publicVariable "fnc_civ_stopCommand";
fnc_civ_search_action = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_search_action.sqf";
publicVariable "fnc_civ_search_action";
fnc_civ_release_action = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_release_action.sqf";
publicVariable "fnc_civ_release_action";
fnc_civ_release = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_release.sqf";
publicVariable "fnc_civ_release";
// Not broadcast, unlike the two below it: the plain civilian path is a server-side thread started
// at town registration, so no trigger anywhere names it.
fnc_civ_handler = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler.sqf";
fnc_civ_handler_ravage = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler_ravage.sqf";
publicVariable "fnc_civ_handler_ravage";
fnc_civ_handler_wbk = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler_wbk.sqf";
publicVariable "fnc_civ_handler_wbk";
// Server-only: every caller is a handler thread or its trigger, and the trigger already resolves
// on the machine that runs the spawn. The recycle pass is RAVAGE and WBK's alone; the ceiling is
// shared with the plain path.
fnc_civ_liveTarget = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_liveTarget.sqf";
fnc_civ_spawnUnit = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_spawnUnit.sqf";
fnc_civ_recycle = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_recycle.sqf";
// Broadcast: the spawn paths remoteExec it to every client to hang the civilian's actions.
fnc_civ_clientActions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_clientActions.sqf";
publicVariable "fnc_civ_clientActions";
// Civilian menu. Only fnc_civ_request and fnc_civ_bribe_answer are reached from a client, but
// the rest are broadcast too so a headless client running civilian logic resolves them.
fnc_civ_request = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_request.sqf";
publicVariable "fnc_civ_request";
fnc_civ_serve = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_serve.sqf";
publicVariable "fnc_civ_serve";
fnc_civ_close = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_close.sqf";
publicVariable "fnc_civ_close";
fnc_civ_bribe_answer = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_bribe_answer.sqf";
publicVariable "fnc_civ_bribe_answer";
fnc_civ_arrest = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_arrest.sqf";
publicVariable "fnc_civ_arrest";
fnc_civ_menuAction = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_menuAction.sqf";
publicVariable "fnc_civ_menuAction";
fnc_civ_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_menu.sqf";
publicVariable "fnc_civ_menu";
fnc_civ_bribe_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_bribe_prompt.sqf";
publicVariable "fnc_civ_bribe_prompt";
fnc_disguiseAsCivilian = compile preprocessFileLineNumbers "duws\server\misc\fnc_disguiseAsCivilian.sqf";
publicVariable "fnc_disguiseAsCivilian";
fnc_scanCivilianGear = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanCivilianGear.sqf";
publicVariable "fnc_scanCivilianGear";
fnc_civ_moveToPlayerServer = {
    params ["_unit", "_caller"];
    if (!isServer) exitWith {};
    if (isNull _unit || isNull _caller) exitWith {};

    // Broadcast: the interaction menu's condition is evaluated on every machine that carries the
    // action, and the call-over is what unlocks it. Set here rather than in the client-side action
    // body so a client cannot open the menu on a local it never actually stopped.
    _unit setVariable ["DUWS_civ_stopped", true, true];

    // An idler is held in an ambient pose that owns their AI, so the doMove below is silently
    // ignored until the pose is released -- the civilian stands and smokes through being called.
    if (_unit getVariable ["civ_posed", false]) then {
        [_unit] call BIS_fnc_ambientAnim__terminate;
        _unit setVariable ["civ_posed", false];
    };

    // Back to front: deleteWaypoint shifts every later index down, so a forward pass over the
    // list deletes every other waypoint and leaves the rest to pull the civilian away mid-walk.
    // `reverse` cannot be inlined into the forEach -- it reverses in place and returns Nothing.
    private _wps = waypoints (group _unit);
    reverse _wps;
    { deleteWaypoint _x } forEach _wps;
    _unit doMove (getPos _caller);
    _unit setBehaviour "AWARE";
    _unit setSpeedMode "NORMAL";
    sleep 5;
    doStop _unit;
};
publicVariable "fnc_civ_moveToPlayerServer";

// The counterpart to the call-over: putting a civilian back to what they were doing before the
// player interrupted them. Every ending uses it -- a refusal, a granted request, a declined
// surrender, and the panic calm-down -- so none of them can drift apart.
//
// Their actual orders cannot be preserved, because the call-over deletes the waypoints and breaks
// the pose to bring them over. What is preserved is the role: fnc_civ_wp_Tomata remembers whether
// a civilian was a stander or a walker and re-issues the same one, so a local who was leaning on
// a wall goes back to leaning on it rather than walking away.
//
// The pause before it is the point. Without it the reply and the turn land in the same frame, so
// the player reads what was said to them after the speaker has already moved. Spawned rather than
// slept in place because the callers are reached by remoteExec from a client's menu action, which
// is not a context sleep can be relied on in.
fnc_civ_resume = {
	if (!isServer) exitWith {};
	params ["_civilian"];
	if (isNull _civilian) exitWith {};
	_civilian spawn {
		sleep (1 + random 1);
		if (!alive _this) exitWith {};
		// A shot fired mid-conversation panics the civilian while the dialog is still open, so the
		// row the player then picks lands here on someone already running. Re-issuing would draw a
		// circuit around a fleeing unit and leave its CYCLE in front of the one the calm-down adds
		// a minute later, which the group never walks past. The panic owns the resume in that case.
		if (_this getVariable ["DUWS_civ_panicked", false]) exitWith {};
		private _idx = _this getVariable ["civ_locIndex", -1];
		private _buildings = if (_idx < 0) then { [] } else {
			(missionNamespace getVariable [format ["civ_buildings_%1", _idx], []]) select { !isNull _x }
		};
		[[group _this], _buildings] spawn fnc_civ_wp_Tomata;
	};
};

fnc_recruitSuccessServer = {
    params ["_target", "_caller", "_civNetId"];
    if (!isServer) exitWith {};
    
    // 如果_target为空，用网络ID重建
    if (isNull _target) then {
        _target = objectFromNetId _civNetId;
    };
    if (isNull _caller) exitWith {};
    if (isNull _target || !alive _target) exitWith {
        ["ERROR", "CIV", "Server: target is null or dead"] call fnc_log;
    };
    
    // Payment is the caller's business, not this function's. Recruiting through the civilian
    // menu is free when the town simply agrees and costs a bribe only when it asks for one, so a
    // fixed charge here would bill an accepted request and double-bill a bribed one.

    // 原有代码：设置俘虏状态，广播等
    _target setCaptive false;
    private _netId = netId _target;
    [_netId, false] remoteExec ["fnc_globalSetCaptive", 0];
    
    // 清除死亡事件和路点
    _target removeAllEventHandlers "Killed";
    private _oldGroup = group _target;
    while {count (waypoints _oldGroup) > 0} do {
        deleteWaypoint ((waypoints _oldGroup) select 0);
    };
    // 加入玩家组
    [_target] joinSilent (group _caller);
    _target allowDamage true;
    // 多次加入确保（原代码有重复，保留）
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    
    // 设置战斗行为
    _target enableAI "PATH";
    _target setBehaviour "AWARE";
    _target setCombatMode "RED";
    _target enableAI "AUTOTARGET";
    _target enableAI "TARGET";
    _target setUnitPos "AUTO";
    [_target] joinSilent (group _caller);
    
    // 武装
    private _weaponPool = [
        ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
        ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
        ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
        ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
        ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
        ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
        ["hgun_P07_F", "16Rnd_9x21_Mag"],
        ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
    ];
    private _weaponEntry = selectRandom _weaponPool;
    private _weapon = _weaponEntry select 0;
    private _magazine = _weaponEntry select 1;
    [_target] joinSilent (group _caller);
    
    removeAllWeapons _target;
    for "_i" from 1 to 3 do {
        _target addMagazineGlobal _magazine;
    };
    _target addWeapon _weapon;
    [_target] joinSilent (group _caller);
    
    // 提示执行者
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_SUCCESS"] remoteExec ["fnc_duws_dialogue", _caller];
    [_target] joinSilent (group _caller);
};
publicVariable "fnc_recruitSuccessServer";

// WARCOM FUNCTIONS
fnc_WARCOM_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_init.sqf";
fnc_WARCOM_wp_blu_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_blu_assault.sqf";
fnc_WARCOM_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_blu_patrol.sqf";
fnc_WARCOM_wp_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_blu_patrol.sqf";
fnc_WARCOM_opf_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_opf_patrol.sqf";
fnc_WARCOM_wp_opf_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_opf_patrol.sqf";
fnc_WARCOM_opf_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_opf_assault.sqf";
fnc_WARCOM_wp_opf_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_opf_assault.sqf";
fnc_WARCOM_opf_air = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_opf_air.sqf";
fnc_random_veh_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_random_veh_blu_patrol.sqf";
fnc_random_veh_opf_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_random_veh_opf_patrol.sqf";
fnc_WARCOM_gps_marker = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_gps_marker.sqf";

// ZONE FUNCTIONS
fnc_zonesundercontrol = compile preprocessFileLineNumbers "duws\server\misc\fnc_zonesundercontrol.sqf";
fnc_locatorZones_random = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_random.sqf";
fnc_captured = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_captured.sqf";
fnc_blufor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_blufor_cap.sqf";
fnc_opfor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_opfor_cap.sqf";
fnc_enterlocation = compile preprocessFileLineNumbers "duws\server\misc\fnc_enterlocation.sqf";
fnc_spawnWait = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_spawnWait.sqf";
fnc_createopfortified = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createopfortified.sqf";
fnc_createoppatrol_sniper = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createoppatrol_sniper.sqf";
fnc_createoppatrol2 = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createoppatrol2.sqf";
fnc_createopteam = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createopteam.sqf";
fnc_createopteam2 = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createopteam2.sqf";
fnc_createopwpteam = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createopwpteam.sqf";
fnc_random_veh = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_random_veh.sqf";
fnc_zone_reveal = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_reveal.sqf";
fnc_hardcore_visible_recalc = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardcore_visible_recalc.sqf";
fnc_zone_spawn_sizes = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_spawn_sizes.sqf";

//////////////////
// ZONE PREFABS
//////////////////

switch (VERSION_X) do {
	case "MODERN": {
		fnc_modern_CommStation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_CommStation.sqf";
		fnc_modern_outpost1 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_outpost1.sqf";
		fnc_modern_Outpost2 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_Outpost2.sqf";
		fnc_modern_reconOutpost = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_reconOutpost.sqf";
		fnc_modern_simple_zone = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_simple_zone.sqf";
		fnc_modern_StorageBunker = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_StorageBunker.sqf";
		fnc_modern_vehfittingstation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_vehfittingstation.sqf";
        fnc_modern_FieldHospital = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_FieldHospital.sqf";
	};
};



// --- Map-click slot ------------------------------------------------------------------
// The engine keeps exactly one onMapSingleClick handler per machine and offers no way to read
// back what is installed, so two features that each install one silently disarm each other and
// the loser waits on a click that never arrives. Everything mid-mission that wants a map click
// goes through these three instead of touching the command.
//
// Held in uiNamespace rather than missionNamespace because a claim must not be serialized into
// a savegame: restored from one, the slot would come back owned by a mode that no longer
// exists and every map click for the rest of the session would be dead.
//
// Mission generation (HQ placement, manual zone placement) still calls the command directly.
// Those run to completion before the player has a comm menu or a board to click, so they
// cannot collide with anything, and routing them through a function the server publishes would
// make map placement depend on the broadcast having landed.

// A listener with no mode behind it, live whenever no mode holds the slot. The player-marker
// system needs the clicked position permanently, and before this it lost the slot to the first
// support call of the mission and never got it back.
fnc_mapclick_background = {
	params [["_handler", ""]];
	uiNamespace setVariable ["DUWS_mapclick_bg", _handler];
	if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isEqualTo "") then {
		onMapSingleClick _handler;
	};
};
publicVariable "fnc_mapclick_background";

// Takes the slot for a named mode, refusing if a different one already holds it -- which is the
// point: a collision becomes a message the player reads instead of a feature that dies quietly.
// Re-claiming as the current holder succeeds, because multi-stage modes (the helicopter taxi
// takes three points) swap handlers between stages.
// An optional third element is passed to the binary form of the command, which sets _this in
// the handler. Not defaulted to []: the unary form leaves the click itself in _this, and every
// site that reads its position out of `params ["_pos"]` would break if that were blanked.
fnc_mapclick_claim = {
	params [["_owner", ""], ["_handler", ""]];
	private _held = uiNamespace getVariable ["DUWS_mapclick_owner", ""];
	if (_held isNotEqualTo "" && {_held isNotEqualTo _owner}) exitWith {
		// The comm menu opens over the map, so a support called while another mode holds the
		// slot has to be refused on whichever surface is in front of the player: the hint box
		// renders behind the map.
		// if/then rather than a nested exitWith, which would exit this block and make the
		// refusal's return value depend on which branch ran.
		private _msg = localize "STR_DUWS_T_mapclick_busy";
		if (visibleMap) then {
			// Appended to the holder's banner rather than replacing it. The holder's instruction
			// is still live and the player still has to act on it, so overwriting it would trade
			// a silent theft for a lost prompt. Restored once the notice has been read.
			private _prev = missionNamespace getVariable ["DUWS_map_prompt_shown", ""];
			private _combined = _msg;
			if (_prev isNotEqualTo "") then {
				_combined = format ["%1<br/><t color='#ff6666'>%2</t>", _prev, _msg];
			};
			[_combined] call fnc_map_prompt;
			[_prev, _held, _combined] spawn {
				params ["_prev", "_holder", "_combined"];
				sleep 4;
				// Both guards matter: the holder may have finished (restoring would resurrect a
				// dead instruction) or redrawn its banner (restoring would undo the newer text).
				if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isEqualTo _holder
					&& {(missionNamespace getVariable ["DUWS_map_prompt_shown", ""]) isEqualTo _combined}) then {
					[_prev] call fnc_map_prompt;
				};
			};
		} else {
			hint _msg;
		};
		false
	};
	uiNamespace setVariable ["DUWS_mapclick_owner", _owner];
	if (count _this > 2) then { (_this select 2) onMapSingleClick _handler } else { onMapSingleClick _handler };
	true
};
publicVariable "fnc_mapclick_claim";

// Hands the slot back to the background listener. A release from anyone but the holder is a
// no-op: several modes clear themselves from inside their own handler and again on the way out,
// and that second clear must not disarm whoever claimed in between.
fnc_mapclick_release = {
	params [["_owner", ""]];
	if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isNotEqualTo _owner) exitWith { false };
	uiNamespace setVariable ["DUWS_mapclick_owner", ""];
	onMapSingleClick (uiNamespace getVariable ["DUWS_mapclick_bg", ""]);
	// The banner shares the slot's lifetime: a mode that no longer owns the click must not be
	// left telling the player to click. Multi-stage modes redraw after each re-claim. No-op once
	// the map has closed, since the control lives on that display.
	[""] call fnc_map_prompt;
	true
};
publicVariable "fnc_mapclick_release";

//////////////////////////////
// GLOBAL FUNCTIONS
//////////////////////////////
fnc_ambient_musicloop = compile preprocessFileLineNumbers "duws\client\sounds\fnc_ambient_musicloop.sqf";publicVariable "fnc_ambient_musicloop";
fnc_duws_Arsenal = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_Arsenal.sqf";publicVariable "fnc_duws_Arsenal";
fnc_ghst_halo = compile preprocessFileLineNumbers "duws\client\misc\fnc_ghst_halo.sqf";publicVariable "fnc_ghst_halo";
fnc_WARCOM_blu_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_blu_assault.sqf";publicVariable "fnc_WARCOM_blu_assault";
fnc_random_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_random_name.sqf";publicVariable "fnc_random_name";
fnc_BLUFOR_squad_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_squad_init.sqf";publicVariable "fnc_BLUFOR_squad_init";
fnc_BLUFOR_faction_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_faction_init.sqf";publicVariable "fnc_BLUFOR_faction_init";
fnc_fortifyFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_fortifyFOB.sqf";publicVariable "fnc_fortifyFOB";
fnc_guardsFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_guardsFOB.sqf";publicVariable "fnc_guardsFOB";
// Broadcast: it is the FOB redeploy action's function value, so every client needs it.
fnc_redeployFOB = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_redeployFOB.sqf";publicVariable "fnc_redeployFOB";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_redeployFOBUnits = compile preprocessFileLineNumbers "duws\server\misc\fnc_redeployFOBUnits.sqf";
fnc_createpatrolFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_createpatrolFOB.sqf";publicVariable "fnc_createpatrolFOB";
fnc_locatorZones_manual = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_manual.sqf";publicVariable "fnc_locatorZones_manual";
fnc_createZone = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createZone.sqf";publicVariable "fnc_createZone";
fnc_intel_payout = compile preprocessFileLineNumbers "duws\server\misc\fnc_intel_payout.sqf";
fnc_intel_search = compile preprocessFileLineNumbers "duws\server\misc\fnc_intel_search.sqf";
// Copies a spent attempt back onto the body a player is currently in. The record is the UID entry
// in playerIntelSearchTick and that is what refuses a search, so this only brings the client-visible
// flag back in line with it -- a respawned or joining player would otherwise be shown an action the
// server silently refuses. Safe to let the client ask for: nothing here grants anything.
// Not published; fnc_intel_search_action remoteExecs it.
fnc_intel_search_restore = {
	if (!isServer) exitWith {};
	params ["_player"];
	if (isNull _player) exitWith {};
	if ((playerIntelSearchTick getOrDefault [getPlayerUID _player, -1]) == econ_tick) then {
		_player setVariable ["DUWS_intel_searched", true, true];
	};
};
fnc_debug_intel_search = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_intel_search.sqf";
fnc_debug_force_mission = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_force_mission.sqf";
fnc_intel_search_action = compile preprocessFileLineNumbers "duws\client\misc\fnc_intel_search_action.sqf";publicVariable "fnc_intel_search_action";
fnc_addHQSatelliteActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addHQSatelliteActions.sqf";
publicVariable "fnc_addHQSatelliteActions";
fnc_restHealServer = compile preprocessFileLineNumbers "duws\server\misc\fnc_restHealServer.sqf";
publicVariable "fnc_restHealServer";

// 如果实现了 HQ 建筑动作，也需添加：
fnc_addHQBuildingActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addHQBuildingActions.sqf";
publicVariable "fnc_addHQBuildingActions";
fnc_addTerminalBlackMarketActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addTerminalBlackMarketActions.sqf";
publicVariable "fnc_addTerminalBlackMarketActions";
fnc_blackMarketPurchase = compile preprocessFileLineNumbers "duws\server\misc\fnc_blackMarketPurchase.sqf";
publicVariable "fnc_blackMarketPurchase";
fnc_intelAnalysis = compile preprocessFileLineNumbers "duws\server\misc\fnc_intelAnalysis.sqf";
publicVariable "fnc_intelAnalysis";
// MISSION FUNCTIONS
fnc_stratmap = compile preprocessFileLineNumbers "duws\client\missions\fnc_stratmap.sqf";publicVariable "fnc_stratmap";
fnc_missionLocator = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionLocator.sqf";publicVariable "fnc_missionLocator";


// DIALOG FUNCTIONS
fnc_HQ_faction_dialog = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_faction_dialog.sqf";publicVariable "fnc_HQ_faction_dialog";
fnc_HQ_manual_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_manual_place.sqf";publicVariable "fnc_HQ_manual_place";
fnc_HQ_random_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_random_place.sqf";publicVariable "fnc_HQ_random_place";
fnc_map_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_map_prompt.sqf";publicVariable "fnc_map_prompt";
fnc_enviro_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_enviro_menu.sqf";publicVariable "fnc_enviro_menu";
fnc_campaign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_campaign_menu.sqf";publicVariable "fnc_campaign_menu";
fnc_startup_preset_apply = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_preset_apply.sqf";publicVariable "fnc_startup_preset_apply";
fnc_process_campaign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_process_campaign_menu.sqf";publicVariable "fnc_process_campaign_menu";
fnc_callsign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_menu.sqf";publicVariable "fnc_callsign_menu";
fnc_callsign_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_back.sqf";publicVariable "fnc_callsign_back";
fnc_callsign_confirm = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_confirm.sqf";publicVariable "fnc_callsign_confirm";
fnc_process_enviro_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_process_enviro_menu.sqf";publicVariable "fnc_process_enviro_menu";
fnc_startup_closed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_closed.sqf";publicVariable "fnc_startup_closed";
fnc_startup_next = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_next.sqf";publicVariable "fnc_startup_next";
fnc_startup_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_back.sqf";publicVariable "fnc_startup_back";
fnc_startup_faction_flow = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_faction_flow.sqf";publicVariable "fnc_startup_faction_flow";
fnc_startup_faction_resolve = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_faction_resolve.sqf";publicVariable "fnc_startup_faction_resolve";
fnc_enviro_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_enviro_back.sqf";publicVariable "fnc_enviro_back";
fnc_startup_enviro_closed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_enviro_closed.sqf";publicVariable "fnc_startup_enviro_closed";
fnc_request_unit = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_unit.sqf";publicVariable "fnc_request_unit";
fnc_request_squad = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_squad.sqf";publicVariable "fnc_request_squad";
fnc_request_vehicle = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_vehicle.sqf";publicVariable "fnc_request_vehicle";
fnc_request_support = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_support.sqf";publicVariable "fnc_request_support";
fnc_convertAPtoCP = compile preprocessFileLineNumbers "duws\client\dialog\fnc_convertAPtoCP.sqf";publicVariable "fnc_convertAPtoCP";
fnc_request_unit_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_unit_fob.sqf";publicVariable "fnc_request_unit_fob";
fnc_request_squad_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_squad_fob.sqf";publicVariable "fnc_request_squad_fob";
fnc_request_vehicle_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_vehicle_fob.sqf";publicVariable "fnc_request_vehicle_fob";
fnc_custom_faction_capture = compile preprocessFileLineNumbers "duws\client\dialog\fnc_custom_faction_capture.sqf";publicVariable "fnc_custom_faction_capture";
fnc_custom_faction_parse = compile preprocessFileLineNumbers "duws\shared\functions\fnc_custom_faction_parse.sqf";publicVariable "fnc_custom_faction_parse";
fnc_custom_faction_init = compile preprocessFileLineNumbers "duws\server\dialog\fnc_custom_faction_init.sqf";publicVariable "fnc_custom_faction_init";
fnc_HQ_Request_Menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_Request_Menu.sqf";publicVariable "fnc_HQ_Request_Menu";
fnc_FOB_Request_Menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_Request_Menu.sqf";publicVariable "fnc_FOB_Request_Menu";
fnc_squad_manage = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_manage.sqf";publicVariable "fnc_squad_manage";
fnc_open_action_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_open_action_menu.sqf";publicVariable "fnc_open_action_menu";
fnc_disguise_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_disguise_menu.sqf";publicVariable "fnc_disguise_menu";
fnc_debug_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_menu.sqf";publicVariable "fnc_debug_menu";
fnc_debug_econ_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_econ_menu.sqf";publicVariable "fnc_debug_econ_menu";
fnc_debug_econ_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_econ_fill.sqf";publicVariable "fnc_debug_econ_fill";
// Not broadcast: the window remoteExecs it to the server by name, and it re-checks game_master
// itself because any client could send it.
fnc_debug_econ_server = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_econ_server.sqf";
fnc_debug_mission_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_mission_menu.sqf";publicVariable "fnc_debug_mission_menu";
fnc_dismissHC = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismissHC.sqf";publicVariable "fnc_dismissHC";
fnc_dismiss_playerAI = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismiss_playerAI.sqf";publicVariable "fnc_dismiss_playerAI";
fnc_squad_rename = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_rename.sqf";publicVariable "fnc_squad_rename";
fnc_groupReset = compile preprocessFileLineNumbers "duws\client\dialog\fnc_groupReset.sqf";publicVariable "fnc_groupReset";
fnc_rest_heal = compile preprocessFileLineNumbers "duws\server\dialog\fnc_rest_heal.sqf";publicVariable "fnc_rest_heal";
fnc_FOBmanager = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOBmanager.sqf";publicVariable "fnc_FOBmanager";
fnc_FOB_remove = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_remove.sqf";publicVariable "fnc_FOB_remove";
fnc_FOB_cleanup = compile preprocessFileLineNumbers "duws\server\dialog\fnc_FOB_cleanup.sqf";publicVariable "fnc_FOB_cleanup";
fnc_FOB_fast_travel = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_fast_travel.sqf";publicVariable "fnc_FOB_fast_travel";
fnc_MHQ_select = compile preprocessFileLineNumbers "duws\client\dialog\fnc_MHQ_select.sqf";publicVariable "fnc_MHQ_select";
fnc_MHQ_addActions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_addActions.sqf";publicVariable "fnc_MHQ_addActions";
fnc_MHQ_deploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_deploy.sqf";publicVariable "fnc_MHQ_deploy";
fnc_MHQ_undeploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_undeploy.sqf";publicVariable "fnc_MHQ_undeploy";
fnc_MHQ_destroyed = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_destroyed.sqf";publicVariable "fnc_MHQ_destroyed";
fnc_actionRotary = compile preprocessFileLineNumbers "duws\server\dialog\fnc_actionRotary.sqf";publicVariable "fnc_actionRotary";


// HQ & FOB FUNCTIONS
fnc_draw_HQicon = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_draw_HQicon.sqf";publicVariable "fnc_draw_HQicon";
fnc_HQaddactions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_HQaddactions.sqf";publicVariable "fnc_HQaddactions";
fnc_FOBactions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_FOBactions.sqf";publicVariable "fnc_FOBactions";
fnc_fob_server = compile preprocessFileLineNumbers "duws\server\supports\fnc_fob_server.sqf";publicVariable "fnc_fob_server";


// SUPPORTS FUNCTIONS
fnc_ammobox = compile preprocessFileLineNumbers "duws\client\supports\fnc_ammobox.sqf";publicVariable "fnc_ammobox";
fnc_ammobox_actions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_ammobox_actions.sqf";publicVariable "fnc_ammobox_actions";
fnc_arty = compile preprocessFileLineNumbers "duws\client\supports\fnc_arty.sqf";publicVariable "fnc_arty";
fnc_mapclickarty = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickarty.sqf";publicVariable "fnc_mapclickarty";
fnc_mapclickuav = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickuav.sqf";publicVariable "fnc_mapclickuav";
fnc_uav_scanner = compile preprocessFileLineNumbers "duws\server\supports\fnc_uav_scanner.sqf";publicVariable "fnc_uav_scanner";
fnc_paradrop = compile preprocessFileLineNumbers "duws\client\supports\fnc_paradrop.sqf";publicVariable "fnc_paradrop";
fnc_request_fob = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_fob.sqf";publicVariable "fnc_request_fob";
fnc_request_hcATTchop = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcATTchop.sqf";publicVariable "fnc_request_hcATTchop";
fnc_request_hcCAS = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcCAS.sqf";publicVariable "fnc_request_hcCAS";
fnc_sitrep_support = compile preprocessFileLineNumbers "duws\server\supports\fnc_sitrep_support.sqf";publicVariable "fnc_sitrep_support";
fnc_veh_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_veh_drop.sqf";publicVariable "fnc_veh_drop";
fnc_sawp_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_sawp_drop.sqf";publicVariable "fnc_sawp_drop";
fnc_siva_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_siva_drop.sqf";publicVariable "fnc_siva_drop";
fnc_helotaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_helotaxi.sqf";publicVariable "fnc_helotaxi";
fnc_helolift = compile preprocessFileLineNumbers "duws\client\supports\fnc_helolift.sqf";publicVariable "fnc_helolift";
// Not broadcast: fnc_helolift only ever remoteExecs these to target 2, which resolves the
// name on the server, and every one of them needs the helo group local to run at all.
fnc_helolift_spawnHeli = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_spawnHeli.sqf";
fnc_helolift_ropes = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_ropes.sqf";
fnc_helolift_waypoints = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_waypoints.sqf";
fnc_mapclicklift = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclicklift.sqf";publicVariable "fnc_mapclicklift";

fnc_mapclickhelo = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickhelo.sqf";publicVariable "fnc_mapclickhelo";
fnc_boattaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_boattaxi.sqf";publicVariable "fnc_boattaxi";
fnc_mapclickboat = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickboat.sqf";publicVariable "fnc_mapclickboat";
fnc_taxi_music = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_taxi_music.sqf";publicVariable "fnc_taxi_music";


// MISC FUNCTIONS
fnc_hirePartisans = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans.sqf";
publicVariable "fnc_hirePartisans";
fnc_hirePMC = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePMC.sqf";
publicVariable "fnc_hirePMC";
fnc_scanEnemyGear = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanEnemyGear.sqf";
publicVariable "fnc_scanEnemyGear";
fnc_disguiseAsEnemy = compile preprocessFileLineNumbers "duws\server\misc\fnc_disguiseAsEnemy.sqf";
publicVariable "fnc_disguiseAsEnemy";
fnc_moreUrban_locations = compile preprocessFileLineNumbers "duws\server\misc\fnc_moreUrban_locations.sqf";publicVariable "fnc_moreUrban_locations";
fnc_hc_init = compile preprocessFileLineNumbers "duws\client\misc\fnc_hc_init.sqf";publicVariable "fnc_hc_init";
fnc_zones_bonus = compile preprocessFileLineNumbers "duws\client\misc\fnc_zones_bonus.sqf";publicVariable "fnc_zones_bonus";
fnc_kndr_unit_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_kndr_unit_markers.sqf";publicVariable "fnc_kndr_unit_markers";
fnc_player_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_player_markers.sqf";publicVariable "fnc_player_markers";
fnc_earplugs = compile preprocessFileLineNumbers "duws\client\misc\fnc_earplugs.sqf";publicVariable "fnc_earplugs";
fnc_duws_help = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_help.sqf";publicVariable "fnc_duws_help";
fnc_bottom_right_message = compile preprocessFileLineNumbers "duws\client\misc\fnc_bottom_right_message.sqf";publicVariable "fnc_bottom_right_message";
fnc_duws_senior_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_duws_senior_name.sqf";publicVariable "fnc_duws_senior_name";
fnc_duws_dialogue = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_dialogue.sqf";publicVariable "fnc_duws_dialogue";
fnc_duws_dialogue_drain = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_dialogue_drain.sqf";publicVariable "fnc_duws_dialogue_drain";
fnc_autoSave = compile preprocessFileLineNumbers "duws\server\misc\fnc_autoSave.sqf";publicVariable "fnc_autoSave";
fnc_playerTF_spawn = compile preprocessFileLineNumbers "duws\server\misc\fnc_playerTF_spawn.sqf";publicVariable "fnc_playerTF_spawn";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_HCsquad_spawn = compile preprocessFileLineNumbers "duws\server\misc\fnc_HCsquad_spawn.sqf";
// Hands each player their own SITREP, because one line of it is local to where they stand: the
// reputation of the town they are in. The support runs on the client that bought it and
// civ_town_rep is never broadcast, so nothing client-side can answer that. Not published --
// fnc_sitrep_support remoteExecs it here rather than calling it.
fnc_sitrep_fanout = {
	if (!isServer) exitWith {};
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	{
		private _town = [getPos _x] call fnc_civ_townAt;
		// Sent as text, not a number: open country, a civilians-off campaign and RAVAGE/WBK all
		// register no reputation, and a 0 would report those as a town that feels neutral about
		// the player. Read straight out of the array rather than through fnc_civ_repAt, which
		// cannot make that distinction either.
		private _rep = if (_town >= 0 && _town < count _reps) then {
			str (_reps select _town)
		} else {
			"--"
		};
		[_rep] remoteExec ["fnc_sitrep_display", _x];
	} forEach allPlayers;
};
fnc_sitrep_display = compile preprocessFileLineNumbers "duws\client\misc\fnc_sitrep_display.sqf";publicVariable "fnc_sitrep_display";
fnc_fill_ammobox = compile preprocessFileLineNumbers "duws\server\misc\fnc_fill_ammobox.sqf";publicVariable "fnc_fill_ammobox";
fnc_fill_sawpbox = compile preprocessFileLineNumbers "duws\server\misc\fnc_fill_sawpbox.sqf";publicVariable "fnc_fill_sawpbox";
fnc_delete_napalm = compile preprocessFileLineNumbers "duws\server\misc\fnc_delete_napalm.sqf";publicVariable "fnc_delete_napalm";
fnc_addQuickChangeActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addQuickChangeActions.sqf";
publicVariable "fnc_addQuickChangeActions";
fnc_quick_kits_menu = compile preprocessFileLineNumbers "duws\client\misc\fnc_quick_kits_menu.sqf";
publicVariable "fnc_quick_kits_menu";
fnc_addNearbyUnitsGearToArsenal = compile preprocessFileLineNumbers "duws\server\misc\fnc_addNearbyUnitsGearToArsenal.sqf";
publicVariable "fnc_addNearbyUnitsGearToArsenal";
fnc_scanNearbyUnitsForQuickChange = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanNearbyUnitsForQuickChange.sqf";
publicVariable "fnc_scanNearbyUnitsForQuickChange";
fnc_rearmUnit = compile preprocessFileLineNumbers "duws\server\misc\fnc_rearmUnit.sqf";
publicVariable "fnc_rearmUnit";
fnc_activateBaseRecycleStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRecycleStation.sqf";
publicVariable "fnc_activateBaseRecycleStation";
fnc_activateBaseRepairStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRepairStation.sqf";
publicVariable "fnc_activateBaseRepairStation";
fnc_client_addRecycleActions = compile preprocessFileLineNumbers "duws\client\supports\fnc_client_addRecycleActions.sqf";
publicVariable "fnc_client_addRecycleActions";
fnc_client_addRepairActions = compile preprocessFileLineNumbers "duws\client\supports\fnc_client_addRepairActions.sqf";
publicVariable "fnc_client_addRepairActions";
fnc_redeployHQUnits = compile preprocessFileLineNumbers "duws\server\misc\fnc_redeployHQUnits.sqf";
publicVariable "fnc_redeployHQUnits";
fnc_addRedeployAction = compile preprocessFileLineNumbers "duws\client\misc\fnc_addRedeployAction.sqf";
publicVariable "fnc_addRedeployAction";
fnc_createKillhouse = compile preprocessFileLineNumbers "duws\server\misc\fnc_createKillhouse.sqf";
publicVariable "fnc_createKillhouse";
// WARCOM FUNCTIONS
fnc_WARCOM_mapclick_assault = compile preprocessFileLineNumbers "duws\client\warcom\fnc_WARCOM_mapclick_assault.sqf";publicVariable "fnc_WARCOM_mapclick_assault";

fnc_lbselected = compile preprocessFileLineNumbers "duws\client\operative\fnc_lbselected.sqf";publicVariable "fnc_lbselected";
fnc_operative_mission_complete = compile preprocessFileLineNumbers "duws\server\misc\fnc_operative_mission_complete.sqf";publicVariable "fnc_operative_mission_complete";
fnc_operator_init = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_init.sqf";publicVariable "fnc_operator_init";
fnc_operator_open = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_open.sqf";publicVariable "fnc_operator_open";
fnc_operator_recruit = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_recruit.sqf";publicVariable "fnc_operator_recruit";
fnc_blu_taskforces_launch = compile preprocessFileLineNumbers "duws\server\warcom\fnc_blu_taskforces_launch.sqf";
publicVariable "fnc_blu_taskforces_launch";
fnc_apocalypse_buildings = {
    ["INFO", "SUPPORT", "Starting building destruction with asset protection."] call fnc_log;

    // ---------- 1. 收集所有需要保护的对象 ----------
    private _protected = [];

    // 总部主建筑
    if (!isNil "bluHQ_object" && {!isNull bluHQ_object}) then {
        _protected pushBack bluHQ_object;
    };
    // 军官
    if (!isNil "hq_blu1" && {!isNull hq_blu1}) then {
        _protected pushBack hq_blu1;
    };
    // 移动 HQ（如果存在）
    if (!isNil "MHQ1" && {!isNull MHQ1}) then {
        _protected pushBack MHQ1;
    };
    // 所有已建立的 FOB
    if (!isNil "Array_of_FOBS") then {
        {
            if (!isNull _x) then {
                _protected pushBack _x;
            };
        } forEach Array_of_FOBS;
    };
    // 如果 MHQ 已部署，保护其帐篷和弹药箱
    if (!isNil "MHQ_tent" && {!isNull MHQ_tent}) then {
        _protected pushBack MHQ_tent;
    };
    if (!isNil "MHQ_ammobox" && {!isNull MHQ_ammobox}) then {
        _protected pushBack MHQ_ammobox;
    };

    ["INFO", "SUPPORT", format ["Protected %1 key assets.", count _protected]] call fnc_log;

    // ---------- 2. 获取地图中心点（用于全图扫描） ----------
    private _center = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
    if (_center isEqualTo []) then {
        _center = [worldSize / 2, worldSize / 2, 0];
    };

    // ---------- 3. 施加随机伤害（跳过保护对象） ----------
    private _buildings = nearestObjects [_center, ["Building", "House", "Ruins"], worldSize];
    ["INFO", "SUPPORT", format ["Found %1 potential buildings.", count _buildings]] call fnc_log;

    private _damagedCount = 0;
    {
        if (!isNull _x && {!(_x in _protected)}) then {
            _x allowDamage true;
            private _damage = 0.7 + random 0.15; // 0.7 ~ 0.85
            _x setDamage _damage;
            _damagedCount = _damagedCount + 1;
        };
    } forEach _buildings;

    ["INFO", "SUPPORT", format ["Successfully damaged %1 buildings.", _damagedCount]] call fnc_log;
};
publicVariable "fnc_apocalypse_buildings";
fnc_removeArsenalAction = {
    params ["_obj"];
    if (!hasInterface) exitWith {};
    if (!isNull _obj) then {
        private _id = _obj getVariable ["arsenalActionID", -1];
        if (_id != -1) then {
            _obj removeAction _id;
            _obj setVariable ["arsenalActionID", nil];
        };
    };
};
publicVariable "fnc_removeArsenalAction";
fnc_wbk_survivorKilled_server = {
    params ["_dead", "_killer", "_instigator"];
    private _idx = _dead getVariable ["civ_locIndex", -1];
    if (_idx == -1) exitWith {};
    
    private _remainingVar = format ["civ_remaining_%1", _idx];

    // 检查是否有剩余人口可以补充
    private _remaining = missionNamespace getVariable [_remainingVar, 0];
    if (_remaining > 0) then {
        private _isZombie = _dead getVariable ["isZombie", false];
        private _newUnit = objNull;
        private _newGroup = grpNull;
        private _spawnPos = [_dead, 10, 50, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
        if (_spawnPos isEqualTo [0,0,0]) then { _spawnPos = getPos _dead; };
        
        if (_isZombie) then {
            // 生成僵尸
            private _zombieType = "";
            if (random 1 < 0.9) then {
                _zombieType = selectRandom ["Zombie_Special_OPFOR_Boomer", "Zombie_Special_OPFOR_Leaper_1", "Zombie_Special_OPFOR_Leaper_2", "Zombie_Special_OPFOR_Screamer", "WBK_SpecialZombie_Corrupted_3"];
            } else {
                _zombieType = selectRandom ["WBK_SpecialZombie_Smasher_3", "WBK_SpecialZombie_Smasher_Hellbeast_3", "WBK_SpecialZombie_Smasher_Acid_3", "WBK_Goliaph_3"];
            };
            _newGroup = createGroup EAST;
            _newUnit = _newGroup createUnit [_zombieType, _spawnPos, [], 0, "NONE"];
            _newUnit setBehaviour "COMBAT";
            _newUnit setCombatMode "RED";
            _newUnit setVariable ["isZombie", true, true];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_zombieKilled_server", 2];
            }];
        } else {
            // 生成幸存者
            private _survivorType = selectRandom ["C_man_p_beggar_F", "C_Man_casual_1_F", "C_Man_casual_3_F", "C_Man_casual_8_F", "C_Man_casual_6_v2_F", "C_Man_casual_2_F", "C_Man_UtilityWorker_01_F", "C_Man_Fisherman_01_F", "C_Man_p_shorts_1_F", "C_Man_w_worker_F"];
            _newGroup = createGroup RESISTANCE;
            _newUnit = _newGroup createUnit [_survivorType, _spawnPos, [], 0, "NONE"];
            // 添加装备等
            if (random 1 < 0.7) then {
                private _uniformList = if (random 1 < 0.7) then { blufor_uniforms } else { opfor_uniforms };
                if (count _uniformList > 0) then { _newUnit forceAddUniform (selectRandom _uniformList); };
            };
            if (random 1 < 0.5) then {
                private _helmetList = if (random 1 < 0.7) then { blufor_helmets } else { opfor_helmets };
                if (count _helmetList > 0) then { _newUnit addHeadgear (selectRandom _helmetList); };
            };
            if (random 1 < 0.7) then {
                private _vestList = if (random 1 < 0.7) then { blufor_vests } else { opfor_vests };
                if (count _vestList > 0) then { _newUnit addVest (selectRandom _vestList); };
            };
            _newUnit setBehaviour "CARELESS";
            _newUnit setCombatMode "BLUE";
            [_newUnit] remoteExec ["fnc_addRecruitAction", 0, _newUnit];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_survivorKilled_server", 2];
            }];
        };
        
        _newUnit setVariable ["civ_locIndex", _idx];
        // 将新单位加入城镇的组列表
        private _groups = missionNamespace getVariable [format ["civ_groups_%1", _idx], []];
        _groups pushBack _newGroup;
        missionNamespace setVariable [format ["civ_groups_%1", _idx], _groups];
        
        // 减少剩余人口
        missionNamespace setVariable [_remainingVar, _remaining - 1];
        if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Replacement spawned at location %1, remaining now %2", _idx, _remaining - 1]] call fnc_log; };
    };
    
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Survivor killed at location %1", _idx]] call fnc_log; };
};
publicVariable "fnc_wbk_survivorKilled_server";

// WBK 模式死亡处理函数（服务器执行）
fnc_wbk_unitKilled_server = {
    params ["_dead", "_killer", "_instigator"];
    private _idx = _dead getVariable ["civ_locIndex", -1];
    if (_idx == -1) exitWith {};

    // 增加剩余人口（用于下次补充）
    private _remVar = format ["civ_remaining_%1", _idx];
    private _rem = missionNamespace getVariable [_remVar, 0];
    missionNamespace setVariable [_remVar, _rem + 1];

    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Unit killed at location %1", _idx]] call fnc_log; };
};
publicVariable "fnc_wbk_unitKilled_server";

// 【新增】挂架设置（消耗 5 CP）
fnc_pylon_set_with_cost = {
    if (!isServer) exitWith {};
    params ["_netId", "_pylonIndex", "_magazine", ["_turret", []], "_requestingPlayerUID"];

    // Escalation applied here: this path never reaches the purchase handshake.
    private _cost = [5] call fnc_escalation_cost;

    // 查找请求玩家
    private _player = objNull;
    { if (getPlayerUID _x == _requestingPlayerUID) exitWith { _player = _x } } forEach allPlayers;
    if (isNull _player) exitWith { ["ERROR", "BOOT", "fnc_pylon_set_with_cost: player not found"] call fnc_log;};

    // CP 检查
    if (commandpointsblu1 < _cost) exitWith {
        [_cost] remoteExec ["fnc_pylon_hint_nocp", _player];
    };

    // 扣除 CP 并广播
    // call, not remoteExec to self: a queued debit runs a frame later, leaving the check
    // above and the deduction split across frames for a second request to slip between.
    [-_cost, "pylon_purchase"] call fnc_cp_adjust;

    // 执行挂架设置
    private _veh = objectFromNetId _netId;
    if (isNull _veh) exitWith { ["ERROR", "BOOT", "fnc_pylon_set_with_cost: invalid netId"] call fnc_log;};
    _veh setPylonLoadout [_pylonIndex, _magazine, true, _turret];

    // 成功提示 → 仅通知操作者
    [_cost] remoteExec ["fnc_pylon_hint_success", _player];
};
publicVariable "fnc_pylon_set_with_cost";

// 客户端提示辅助函数
fnc_pylon_hint_nocp = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_NO_CP", _cost];
};
publicVariable "fnc_pylon_hint_nocp";

fnc_pylon_hint_success = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_SET_SUCCESS", _cost];
};
publicVariable "fnc_pylon_hint_success";

// Registry self-check. preprocessFile on a path that does not resolve returns "", which
// compiles to an empty {} and then no-ops at every call site with no error anywhere -- a
// mistyped or moved path is otherwise invisible until some later stage silently never
// happens. Runs once, right after the last entry above.
private _fncs = (allVariables missionNamespace) select {(_x select [0, 4]) == "fnc_"};
private _empty = _fncs select {
    private _v = missionNamespace getVariable _x;
    // An empty body stringifies to "" or "{}" depending on how it was produced; strip
    // whitespace and treat both as the missing-file signature.
    _v isEqualType {} && {((str _v) splitString " " joinString "") in ["", "{}"]}
};
["INFO", "REGISTRY", format ["%1 fnc_* defined", count _fncs]] call fnc_log;
if (count _empty > 0) then {
    ["ERROR", "REGISTRY", format ["%1 compiled EMPTY -- missing or unresolved file: %2",
        count _empty, _empty]] call fnc_log;
};
