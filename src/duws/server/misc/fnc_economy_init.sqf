// Command points, arsenal points, coins and the shared spend pools.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

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

fnc_pool_reply = {
	params [["_replyVar", ""], ["_ok", false]];
	missionNamespace setVariable [_replyVar, _ok];
};
