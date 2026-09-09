// Command points, arsenal points, money and the shared spend pools.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// Server-authoritative command-point mutation. Every CP change routes here via remoteExec [..., 2]
// with a signed delta; nothing else may assign commandpointsblu1 or publicVariable it. The engine
// runs each delta as one uninterruptible statement on the single server copy, so concurrent changes
// from different machines serialize instead of clobbering each other with stale absolute values (a
// client's read-modify-write of its local copy otherwise duplicated or lost CP for the whole
// session in co-op).
fnc_cp_adjust = {
	if (!isServer) exitWith {};
	// _reason exists only for the log: a bare "CP -5" cannot be told apart from a death
	// penalty, a purchase or a lost zone after the fact. Optional so a missed call site still works.
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

// The Army Power tier ladder. A side's tier is how many rungs its EARNED counter has crossed -- a one-way
// ratchet (earned only ever rises; spending never touches it), so a spent-down wallet cannot drop the tier.
// Capability sites read the earned counter directly; this integer is only the readout/save summary.
// Five tiers, steepening past tier 2 against OPFOR's ~94 AP/hr from six zones (motorised ~0.6 h to jets ~6.4 h).
DUWS_ap_tier_rungs = [60, 150, 350, 600]; publicVariable "DUWS_ap_tier_rungs";
// Tier 1 (infantry) is the floor at earned 0, so the tier is one plus the rungs crossed, ranging 1-5.
DUWS_fnc_ap_tier = {
	params ["_earned"];
	1 + ({ _earned >= _x } count DUWS_ap_tier_rungs)
};

// Server-authoritative Army Power mutation -- same delta contract as fnc_cp_adjust: callers
// remoteExec a signed delta, nothing else assigns the pools. An unrecognised side drops the delta
// and logs rather than crediting the wrong pool; no HUD counter to refresh. Floored at 0 like CP:
// losing a zone subtracts the zone's full worth, so an unclamped pool could sit deeply negative.
//
// Integer invariant, same rounding rule as fnc_cp_adjust: every ladder gate reads "> N", so a pool
// resting at 39.97 fails a > 40 gate while a rounded readout prints 40 and the player has no way to tell why.
fnc_ap_adjust = {
	if (!isServer) exitWith {};
	// _earned credits the one-way earned counter (never the ladder wallet), so it is passed only by
	// the recurring faucets each side genuinely earns -- BLUFOR's zone trickle, missions and
	// first-capture bonus; OPFOR's town, zone and flat income. Spends, swings, consolation and refunds
	// leave it 0, so ground regained and money spent never move the ladder.
	params [["_side", ""], ["_delta", 0], ["_reason", ""], ["_earned", 0]];
	if (_delta != round _delta) then {
		["WARN", "ECON", format ["fractional AP delta %1 rounded into the pool (%2)", _delta, _reason]] call fnc_log;
	};
	switch (_side) do {
		case "OPF": {
			WARCOM_opfor_ap = round ((WARCOM_opfor_ap + _delta) max 0); publicVariable "WARCOM_opfor_ap";
			if (_earned > 0) then {
				WARCOM_opfor_ap_earned = round (WARCOM_opfor_ap_earned + _earned); publicVariable "WARCOM_opfor_ap_earned";
				private _t = [WARCOM_opfor_ap_earned] call DUWS_fnc_ap_tier;
				if (_t != WARCOM_opfor_tier) then {
					WARCOM_opfor_tier = _t; publicVariable "WARCOM_opfor_tier";
					["INFO", "ECON", format ["OPF tier -> %1 (earned %2)", _t, WARCOM_opfor_ap_earned]] call fnc_log;
					// Enemy escalation is team news like the BLUFOR rise: same card, red, but no sound.
					["tier_up_opfor", [[_t] call DUWS_fnc_tierName]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
				};
			};
			["INFO", "ECON", format ["OPF AP %1 -> %2 (%3)", _delta, WARCOM_opfor_ap, _reason]] call fnc_log;
		};
		case "BLU": {
			WARCOM_blufor_ap = round ((WARCOM_blufor_ap + _delta) max 0); publicVariable "WARCOM_blufor_ap";
			// Same host PV gap as fnc_cp_adjust above (ctrl 1002, the request menu AP box).
			if (hasInterface) then { ctrlSetText [1002, format ["%1", WARCOM_blufor_ap]]; };
			if (_earned > 0) then {
				WARCOM_blufor_ap_earned = round (WARCOM_blufor_ap_earned + _earned); publicVariable "WARCOM_blufor_ap_earned";
				private _t = [WARCOM_blufor_ap_earned] call DUWS_fnc_ap_tier;
				if (_t != WARCOM_blufor_tier) then {
					WARCOM_blufor_tier = _t; publicVariable "WARCOM_blufor_tier";
					["INFO", "ECON", format ["BLU tier -> %1 (earned %2)", _t, WARCOM_blufor_ap_earned]] call fnc_log;
					// Skip a dedicated server, which has no screen or audio device to receive this on.
					["tier_up", [[_t] call DUWS_fnc_tierName]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
					"boots" remoteExec ["playSound", [0,-2] select isDedicated];
				};
			};
			["INFO", "ECON", format ["BLU AP %1 -> %2 (%3)", _delta, WARCOM_blufor_ap, _reason]] call fnc_log;
		};
		default { ["ERROR", "ECON", format ["fnc_ap_adjust: unrecognised side '%1', dropped delta %2", _side, _delta]] call fnc_log; };
	};
};

// How long a town has to stop taking a given kind of charge before its card is posted, in seconds.
// Long enough that the shells of one fire mission land inside one window, short enough that a lone
// act -- a civilian treated, an arrest -- is still answered while the player is standing over it.
#define REP_ANNOUNCE_WINDOW 4

// Pending reputation cards, keyed by town and cause together: [delta, deadline]. Server state
// with one reader, and an entry's presence is also the flag saying a card is already queued for
// that pair, which is what keeps one announce thread per pair rather than one per charge.
civ_rep_pending = createHashMap;

// One card per burst, not per charge: a fire mission changes the damage state of dozens of
// buildings within a few seconds and each one is its own charge, so a card each would bury the
// screen -- and accumulating means the number reported is the whole barrage, not the last -2 of forty.
//
// The cause is half the key rather than a field, so a barrage that levels houses *and* kills
// civilians posts one card for each; summing across causes would report a figure under a heading
// that only explains part of it, and a heal alongside a demolition in one window could cancel into
// a card naming the wrong direction, or no card at all.
fnc_town_rep_announce = {
	params ["_townIndex", "_reason"];
	private _key = format ["%1:%2", _townIndex, _reason];
	// Each further charge of the same cause pushes the deadline out rather than spawning a second
	// thread, so this waits out the whole barrage however long it runs.
	waitUntil { sleep 1; diag_tickTime > ((civ_rep_pending getOrDefault [_key, [0, 0]]) select 1) };
	// Charges that cancel out inside one window leave nothing to report.
	private _delta = (round (((civ_rep_pending deleteAt _key) select 0) * 100)) / 100;
	if (_delta == 0) exitWith {};

	private _name = text ((missionNamespace getVariable ["civ_locations", []]) param [_townIndex, locationNull]);
	if (_name isEqualTo "") then { _name = format ["Unnamed%1", _townIndex] };

	private _why = localize (switch (_reason) do {
		case "building_destroyed":    { "STR_DUWS_T_civ_rep_why_building" };
		case "civilian_harmed":       { "STR_DUWS_T_civ_rep_why_harmed" };
		case "healed_civilian":       { "STR_DUWS_T_civ_rep_why_healed" };
		case "roadside_help":         { "STR_DUWS_T_civ_rep_why_roadside" };
		case "civilian_arrested":     { "STR_DUWS_T_civ_rep_why_arrested" };
		case "idap_success":          { "STR_DUWS_T_civ_rep_why_aid" };
		case "idap_failed":           { "STR_DUWS_T_civ_rep_why_aid_failed" };
		case "idap_deadline":         { "STR_DUWS_T_civ_rep_why_aid_failed" };
		case "protect_civ_success":   { "STR_DUWS_T_civ_rep_why_escort" };
		case "protect_civ_casualty":  { "STR_DUWS_T_civ_rep_why_escort_lost" };
		case "garrison_cleared":      { "STR_DUWS_T_civ_rep_why_garrison" };
		case "vehicle_stolen":        { "STR_DUWS_T_civ_rep_why_vehicle" };
		default                       { "STR_DUWS_T_civ_rep_why_other" };
	});

	// A negative figure prints its own sign; a positive one has none to print.
	private _amount = format ["%1%2", ["", "+"] select (_delta > 0), _delta];
	private _card = if (_delta > 0) then {
		["repup", [localize "STR_DUWS_T_rqwho9bq",
			format [localize "STR_DUWS_T_civ_rep_up", _name, _why, _amount]]]
	} else {
		["repdown", [localize "STR_DUWS_T_reputationdown",
			format [localize "STR_DUWS_T_civ_rep_down", _name, _why, _amount]]]
	};
	_card remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
};

// Per-town reputation, the only reputation there is: server-only, signed delta, the writer owns the
// rounding so callers never assign (fractional deltas would compound into drift). A town index of -1
// (open country, civilians off, RAVAGE/WBK -- all via fnc_civ_townAt) is dropped, not charged elsewhere,
// since reputation is territory. Not broadcast (no client reads civ_town_rep; markers repaint globally).
// The player is told here, not per caller (callers announced in six wordings, some not at all), queued
// off the applied change so a town pinned at a bound claims nothing. _silent suppresses only the card --
// the passive AoI drift charges every covered town per tick, so a card apiece would bury the event cards.
fnc_town_rep_adjust = {
	if (!isServer) exitWith {};
	params [["_townIndex", -1], ["_delta", 0], ["_reason", ""], ["_silent", false]];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex < 0 || _townIndex >= count _reps) exitWith {};
	private _old = _reps select _townIndex;
	private _new = ((_old + _delta) max -20) min 20;
	_new = (round (_new * 100)) / 100;
	if (abs _new < 0.01) then { _new = 0 };
	_reps set [_townIndex, _new];
	[_townIndex] call fnc_civ_townRender;
	// A town crossing either faction band (in either direction) changes the broadcast town-centre lists.
	if (((_old <= -10) != (_new <= -10)) || {(_old >= 10) != (_new >= 10)}) then { [] call fnc_enemy_towns_refresh };
	["INFO", "CIV", format ["TOWNREP %1: %2 -> %3 (%4)", _townIndex, _old, _new, _reason]] call fnc_log;

	if (_new == _old || _silent) exitWith {};
	private _key = format ["%1:%2", _townIndex, _reason];
	private _queued = _key in civ_rep_pending;
	private _entry = civ_rep_pending getOrDefault [_key, [0, 0]];
	_entry set [0, (_entry select 0) + (_new - _old)];
	_entry set [1, diag_tickTime + REP_ANNOUNCE_WINDOW];
	civ_rep_pending set [_key, _entry];
	if (!_queued) then { [_townIndex, _reason] spawn fnc_town_rep_announce };
};

// The town-centre lists client-side gates read, since civ_town_rep is server-only: the OPFOR band feeds
// the placement keep-out (shared/functions/fnc_pos_near_enemy.sqf); both bands feed the rescue-hostage
// site rule, which bars a covert site in a side-held town. Rebuilt whole rather than patched: towns number
// in the tens and a band crossing is rare, so the cost is noise and the whole-list form cannot drift out
// of step with civ_town_rep the way an add/remove can.
fnc_enemy_towns_refresh = {
	if (!isServer) exitWith {};
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	private _locs = missionNamespace getVariable ["civ_locations", []];
	DUWS_enemy_town_pos = [];
	DUWS_blufor_town_pos = [];
	{
		if (_x <= -10) then { DUWS_enemy_town_pos pushBack (getPos (_locs select _forEachIndex)) };
		if (_x >= 10) then { DUWS_blufor_town_pos pushBack (getPos (_locs select _forEachIndex)) };
	} forEach _reps;
	publicVariable "DUWS_enemy_town_pos";
	publicVariable "DUWS_blufor_town_pos";
};

// A cost with escalation applied, rounded up so a scaled price is never cheaper than the base
// one. Defined here rather than in fnc_escalation so the purchase path does not depend on
// whether escalation ever started -- with no multiplier published this is the identity.
// Available on clients too: the request menus display what a purchase will actually cost.
fnc_escalation_cost = {
	params [["_cost", 0]];
	ceil (_cost * (missionNamespace getVariable ["escalation_multiplier", 1]))
};

// Money in hand. Money_roll is added as a magazine, but the ground pickup and the arsenal can
// land one in either the magazine or the item slots, so both are counted: itemsWithMagazines is
// the union and cannot report less money than the player is holding. Counting magazines alone can
// only ever undercount, and an undercount tells a player who can afford something that they cannot.
// Available on clients too: the civilian menu shows the player what they are carrying.
fnc_money_count = {
	params ["_unit"];
	if (isNull _unit) exitWith { 0 };
	{ _x == "Money_roll" } count (itemsWithMagazines _unit)
};

// Server-only, and the caller says nothing about the price until this returns: a client's count
// is a snapshot, and in co-op two players can spend the same money, so this read and the removal
// are adjacent statements on the one machine that owns the inventory -- the same reason
// fnc_pool_try_spend exists for CP.
//
// Both slots are counted, so both removals run. removeItem is local-effect and no-ops for a player
// not local to the server, so issue it at the unit's owner; removeMagazineGlobal already lands
// everywhere. Callers own the refusal message, worded per purchase path.
fnc_money_spend = {
	if (!isServer) exitWith { false };
	params ["_unit", ["_amount", 0]];
	if (([_unit] call fnc_money_count) < _amount) exitWith { false };
	private _left = _amount;
	{
		if (_x == "Money_roll" && _left > 0) then {
			if (local _unit) then { _unit removeItem "Money_roll"; }
			else { [_unit, "Money_roll"] remoteExec ["removeItem", _unit]; };
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

// Drops [class, count] pairs into one ground holder at a position. Server-only: createVehicle is
// global. Used for money/intel that will not fit back into a full inventory when the arsenal closes.
// A holder with addItemCargo/addMagazineCargo takes raw inventory classes directly, so it handles the
// intel items too, which have no "Item_" ground variant to hand to fnc_search_dropItems. Untagged, so
// the map cleanup -- which keys off composition membership -- leaves the player's cash where it fell.
fnc_money_drop = {
	if (!isServer) exitWith {};
	params [["_pairs", []], ["_pos", [0,0,0]]];
	if (_pairs isEqualTo []) exitWith {};
	private _holder = createVehicle ["GroundWeaponHolder", [0,0,0], [], 0, "CAN_COLLIDE"];
	_holder setPosATL [_pos select 0, _pos select 1, (_pos select 2) + 0.05];
	{
		_x params ["_cls", ["_n", 0]];
		if (_n > 0) then {
			if (isClass (configFile >> "CfgMagazines" >> _cls)) then {
				_holder addMagazineCargoGlobal [_cls, _n];
			} else {
				_holder addItemCargoGlobal [_cls, _n];
			};
		};
	} forEach _pairs;
};

// Server-authoritative purchase, closing a stale-read race: a client testing its own pool copy is a
// round-trip out of date, so two clients each seeing 10 CP both pass a 10 CP gate and the second debit
// goes free. Here test and debit are adjacent against the one server copy, so no request lands between.
// The verdict returns as a named reply (fnc_pool_spend is the other half). The debit is `call`, not
// remoteExec-to-self, which would queue a later-frame job and reopen the gap.
fnc_pool_try_spend = {
	if (!isServer) exitWith {};
	params [["_pool", ""], ["_cost", 0], ["_requester", objNull], ["_replyVar", ""], ["_gate", []]];
	// Server-side tier backstop: the ladder was gated only on the client's greyed row, so a bypass
	// could debit for an unearned tier. Re-derive the tier from the item's class here, never from a
	// client-named value. Guards the debit, not the client-side effect -- a free 0-cost bypass slips.
	if !(_gate isEqualTo []) then {
		_gate params ["_gateKind", "_gateId"];
		private _reqTier = switch (_gateKind) do {
			case "support": { [_gateId] call fnc_support_tier };
			case "veh": { [_gateId] call DUWS_fnc_vehTier };
			default { 1 };
		};
		if !(["BLU", _reqTier] call DUWS_fnc_ap_unlocked) exitWith {
			["WARN", "ECON", format ["tier gate refused %1 '%2' (tier %3) for %4",
				_gateKind, _gateId, _reqTier, name _requester]] call fnc_log;
			[_replyVar, false, 0] remoteExec ["fnc_pool_reply", _requester];
		};
	};
	private _ok = false;
	// Attribution comes from _requester, not a threaded-through label: all client purchase sites
	// reach here via fnc_pool_spend, which knows the cost but not what the player was buying.
	private _who = format ["purchase by %1", name _requester];
	// What was actually charged, sent back with the verdict so a refund pays exactly this and
	// never the base price. A scalar for CP/AP, a [cp, ap] pair for the dual case. Escalation is
	// applied here and nowhere else, and only to CP: an AP purchase is permanent, so scaling it
	// would make buying early strictly better than buying well. The four server-side paths that
	// call fnc_cp_adjust directly bypass this handshake and apply escalation themselves.
	private _charged = 0;
	switch (_pool) do {
		case "CP": {
			private _c = [_cost] call fnc_escalation_cost;
			if (commandpointsblu1 >= _c) then { [-_c, _who] call fnc_cp_adjust; _ok = true; };
			_charged = _c;
		};
		case "AP": {
			if (WARCOM_blufor_ap >= _cost) then { ["BLU", -_cost, _who] call fnc_ap_adjust; _ok = true; };
			_charged = _cost;
		};
		// Dual price, one purchase. Both pools are tested before either is debited and both debits
		// are adjacent statements against the one server copy, so partial success is impossible and
		// no other machine's spend lands between them -- the single-pool race, closed one level up.
		case "CPAP": {
			_cost params [["_cp", 0], ["_ap", 0]];
			private _cpScaled = [_cp] call fnc_escalation_cost;
			if (commandpointsblu1 >= _cpScaled && {WARCOM_blufor_ap >= _ap}) then {
				[-_cpScaled, _who] call fnc_cp_adjust;
				["BLU", -_ap, _who] call fnc_ap_adjust;
				_ok = true;
			};
			_charged = [_cpScaled, _ap];
		};
		default { ["ERROR", "ECON", format ["fnc_pool_try_spend: unrecognised pool '%1', refused %2", _pool, _cost]] call fnc_log; };
	};
	[_replyVar, _ok, _charged] remoteExec ["fnc_pool_reply", _requester];
};

// Client half of the purchase handshake: blocks until the server rules on the request, so callers
// must already be scheduled -- every purchase entry point is spawned. Refuses on timeout rather than
// falling through: silence must not let a purchase happen. The charge amount is returned on the side
// (duws_last_charge) rather than in place of the verdict, so the forty existing call sites, which
// read this as a guard clause, stay as they are.
fnc_pool_spend = {
	params [["_pool", "CP"], ["_cost", 0], ["_gate", []]];
	duws_last_charge = 0;
	// Zero cost short-circuits: several comm-menu supports are charged at unlock and pass 0 here. A
	// dual price is [cp, ap] and short-circuits only when both halves are zero. duws_last_charge then
	// carries a [cp, ap] pair back to the one caller that records it (the support refund), a scalar
	// otherwise, matching what fnc_pool_try_spend replied.
	private _zero = if (_pool == "CPAP") then { (_cost param [0, 0]) <= 0 && {(_cost param [1, 0]) <= 0} } else { _cost <= 0 };
	if (_zero) exitWith { true };
	duws_spend_seq = (missionNamespace getVariable ["duws_spend_seq", 0]) + 1;
	private _replyVar = format ["duws_spend_reply_%1", duws_spend_seq];
	[_pool, _cost, player, _replyVar, _gate] remoteExec ["fnc_pool_try_spend", 2];
	private _deadline = diag_tickTime + 5;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _replied = !isNil _replyVar;
	(missionNamespace getVariable [_replyVar, [false, 0]]) params ["_ok", "_charged"];
	duws_last_charge = _charged;
	missionNamespace setVariable [_replyVar, nil];
	// A timeout and a refusal look identical to the caller, so log the difference: without
	// it a dropped reply reads in-game as "not enough CP" with a full pool.
	if (!_replied) then { ["WARN", "ECON", format ["fnc_pool_spend: no reply for %1 %2, refused", _cost, _pool]] call fnc_log; };
	_ok
};

fnc_pool_reply = {
	params [["_replyVar", ""], ["_ok", false], ["_charged", 0]];
	missionNamespace setVariable [_replyVar, [_ok, _charged]];
};

// Captured-materiel pool. Server-authoritative like the CP/AP pools above: the read and the write
// are adjacent statements on the one machine that owns DUWS_capturedPool, so two clients banking or
// drawing the last of a class cannot both win. Clients never assign the pool; they remoteExec these
// writers to the server, which mutates and re-broadcasts.

// The friendly set the classifier tests against: standard-issue gear is unlimited and never pooled.
// Captured once at boot by fnc_create_ammo_lists, before any foreign class can reach the cargo (the
// client's shelf-stocking on arsenal open adds foreign only to its own local cargo). This lazy
// fallback rebuilds it from the server cargo if the boot capture was somehow missed -- still
// foreign-free, because foreign never enters the server's cargo.
fnc_captured_pool_friendly = {
	if (!isServer) exitWith {};
	if (!isNil "DUWS_friendlyArsenal") exitWith {};
	private _u = [];
	{
		_u append flatten (missionNamespace getVariable [_x, []]);
	} forEach ["bis_addVirtualWeaponCargo_cargo", "bis_addVirtualItemCargo_cargo",
		"bis_addVirtualMagazineCargo_cargo", "bis_addVirtualBackpackCargo_cargo"];
	DUWS_friendlyArsenal = _u arrayIntersect _u;
};

// Count of one class in the pool. Reads the broadcast array, so it is correct on the server; the
// pool is [[class, count], ...] with zero-count classes dropped, so absence means zero.
fnc_captured_pool_getCount = {
	params ["_cls"];
	private _i = DUWS_capturedPool findIf { (_x select 0) isEqualTo _cls };
	if (_i < 0) then { 0 } else { (DUWS_capturedPool select _i) select 1 }
};

// Server-only. Sets a class to an absolute count, dropping the entry at zero so "present" means
// "count > 0". Does not broadcast -- callers batch several writes then publicVariable once.
fnc_captured_pool_setCount = {
	if (!isServer) exitWith {};
	params ["_cls", "_n"];
	private _i = DUWS_capturedPool findIf { (_x select 0) isEqualTo _cls };
	if (_n <= 0) then {
		if (_i >= 0) then { DUWS_capturedPool deleteAt _i; };
	} else {
		if (_i >= 0) then { DUWS_capturedPool set [_i, [_cls, _n]]; }
		else { DUWS_capturedPool pushBack [_cls, _n]; };
	};
};


// Arsenal close (server). Diffs the loadout the player opened with against the one they closed with,
// per foreign class: a class present at close but not open (or in a greater count) was withdrawn from
// the shelf; a lesser count was deposited. net = close - open. A friendly class is skipped -- it is
// unlimited and never touches the pool. Overdraw (net beyond what the pool held) is answered by
// replying the excess back to the client to strip, which is what makes a count-1 rifle yield one.
fnc_captured_pool_settle = {
	if (!isServer) exitWith {};
	params [["_openLoadout", []], ["_closeLoadout", []], ["_requester", objNull], ["_replyVar", ""]];
	// Close is read on the client, like open, not re-read here: getUnitLoadout on the remote requester
	// lagged its replication, so a grab just before close settled against a stale loadout and stripped
	// gear off an honest co-op player. Trusting the client is the price; the accepted cheat is in the doc.
	call fnc_captured_pool_friendly;
	// A disposable launcher (CUP NLAW/M136/RPG18) is stocked and shown by its base row but leaves the
	// arsenal as a distinct loaded fire-class (CUP_launch_NLAW -> CUP_launch_NLAW_Loaded) the raw
	// friendly set never holds. Resolve back to the arsenal base -- the same mapping that built the set
	// -- before the unlimited-floor skip, else the unlimited launcher settles as a count-0 foreign
	// overdraw and is stripped off the player.
	private _friendlyHit = {
		params ["_c"];
		if (_c in DUWS_friendlyArsenal) exitWith { true };
		count (([[_c]] call fnc_arsenal_base_weapons) arrayIntersect DUWS_friendlyArsenal) > 0
	};
	private _openC = [_openLoadout] call fnc_captured_loadout_counts;
	private _closeC = [_closeLoadout] call fnc_captured_loadout_counts;
	private _classes = (keys _openC) + (keys _closeC);
	_classes = _classes arrayIntersect _classes;
	private _excess = [];
	{
		private _cls = _x;
		// Ammo untracked: magazines never touch the pool. Hybrid keeps friendly as the unlimited
		// floor and skips it; Limited tracks friendly too, so that skip is dropped.
		if (!DUWS_trackAmmo && {isClass (configFile >> "CfgMagazines" >> _cls)}) then { continue };
		if (!DUWS_arsenalLimited && {[_cls] call _friendlyHit}) then { continue };
		private _net = (_closeC getOrDefault [_cls, 0]) - (_openC getOrDefault [_cls, 0]);
		if (_net == 0) then { continue };
		private _cur = [_cls] call fnc_captured_pool_getCount;
		if (_net < 0) then {
			[_cls, _cur + (- _net)] call fnc_captured_pool_setCount;
		} else {
			private _grant = _net min _cur;
			[_cls, _cur - _grant] call fnc_captured_pool_setCount;
			if (_net - _grant > 0) then { _excess pushBack [_cls, _net - _grant]; };
		};
	} forEach _classes;
	// A worn container that overdrew -- uniform/vest/backpack -- is pulled off the player by
	// removeUniform/Vest/Backpack, and those also destroy its contents, including gear the pool DID
	// cover and already debited. Re-credit that covered gear to the shelf so it returns to stock
	// rather than leaking out of the economy when the client strips the container. Only the covered
	// part: a content class that itself overdrew was never granted, and the draw's own skips (friendly
	// floor, untracked ammo) keep a class the pool never debited from being credited now. Reading the
	// destroyed container's OWN contents, not the flat per-class total, makes the credit match what
	// removeVest burns; subtracting the flat excess can only under-credit on a rare cross-container
	// split, never mint stock, so it errs toward the shelf, never inflation.
	private _exMap = createHashMap;
	{ _exMap set [_x select 0, _x select 1]; } forEach _excess;
	private _salvaged = [];
	{
		_x params ["_cls"];
		private _idx = [3, 4, 5] findIf { ((_closeLoadout param [_x, []]) param [0, ""]) isEqualTo _cls };
		if (_idx < 0) then { continue };   // not a worn container (headgear/goggles/loose item)
		{
			_x params ["_cc", ["_cn", 1]];
			if (!DUWS_trackAmmo && {isClass (configFile >> "CfgMagazines" >> _cc)}) then { continue };
			if (!DUWS_arsenalLimited && {[_cc] call _friendlyHit}) then { continue };
			private _keep = _cn - (_exMap getOrDefault [_cc, 0]);
			if (_keep > 0) then {
				[_cc, ([_cc] call fnc_captured_pool_getCount) + _keep] call fnc_captured_pool_setCount;
				_salvaged pushBack [_cc, _keep];
			};
		} forEach ((_closeLoadout param [([3, 4, 5] select _idx), []]) param [1, []]);
	} forEach _excess;

	if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["pool settle: touched=%1 excess=%2 salvaged=%3", _classes, _excess, _salvaged]] call fnc_log; };
	publicVariable "DUWS_capturedPool";
	if (_replyVar != "") then { [_replyVar, true, _excess] remoteExec ["fnc_pool_reply", _requester]; };
};

// Deposit explicit [class, count] pairs (server). Friendly classes are skipped: pooling one is
// harmless (friendly is unlimited regardless) but pointless.
fnc_captured_pool_deposit_counts = {
	if (!isServer) exitWith {};
	params [["_pairs", []]];
	call fnc_captured_pool_friendly;
	{
		_x params ["_cls", ["_n", 0]];
		if (_n > 0 && {!(_cls in DUWS_friendlyArsenal)}) then {
			[_cls, ([_cls] call fnc_captured_pool_getCount) + _n] call fnc_captured_pool_setCount;
		};
	} forEach _pairs;
	if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["pool deposit_counts: %1", _pairs]] call fnc_log; };
	publicVariable "DUWS_capturedPool";
};
