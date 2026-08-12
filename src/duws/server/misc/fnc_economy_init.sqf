// Command points, arsenal points, money and the shared spend pools.
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

// The Army Power tier ladder. A side's tier is how many rungs its EARNED counter has crossed -- a
// one-way ratchet, because the earned counter only ever rises (fnc_ap_adjust credits it from the
// recurring faucets and spending never touches it), so a wallet spent down cannot drop the tier.
// Capability sites read the earned counter directly against their own thresholds; this integer is
// the coarse summary of the same climb, for the readout and (later) the save, and the shared scale
// both sides' capability gates sit on. Five tiers: tier 1 is infantry at 0 AP (always available), and
// the four rungs gate the vehicle classes above it, steepening past tier 2. Against OPFOR's ~94 AP/hr
// from six zones that paces motorised ~0.6 h, mechanised ~1.6 h, armour ~3.7 h, jets ~6.4 h.
DUWS_ap_tier_rungs = [60, 150, 350, 600]; publicVariable "DUWS_ap_tier_rungs";
// Tier 1 (infantry) is the floor at earned 0, so the tier is one plus the rungs crossed, ranging 1-5.
DUWS_fnc_ap_tier = {
	params ["_earned"];
	1 + ({ _earned >= _x } count DUWS_ap_tier_rungs)
};

// Server-authoritative Army Power mutation -- same delta contract as fnc_cp_adjust:
// callers remoteExec a signed delta, nothing else assigns the pools. An unrecognised
// side drops the delta and logs rather than crediting the wrong pool; no HUD counter
// to refresh. Floored at 0 like CP: losing a zone subtracts the zone's full worth, so
// an unclamped pool could sit deeply negative.
//
// Integer invariant, the CP writer's verbatim: every ladder gate reads "> N", so a pool
// resting at 39.97 fails a > 40 gate while a rounded readout prints 40 and the player has
// no way to tell why. Round the total rather than the delta -- that also normalises a pool
// already holding a fraction. Sub-point payouts must accumulate whole points at the caller;
// rounding here would swallow them, so a fractional delta is logged.
fnc_ap_adjust = {
	if (!isServer) exitWith {};
	// _earned is the part of a positive delta that also credits the one-way earned counter and so can
	// raise the tier. The recurring faucets each side genuinely earns pass it -- BLUFOR's zone trickle,
	// missions and first-capture bonus; OPFOR's town, zone and flat income. Spends, swings, consolation
	// and refunds leave it 0, so ground regained and money spent never move the ladder. Never negative:
	// the counter only rises, which is what makes the tier a ratchet.
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
				};
			};
			["INFO", "ECON", format ["OPF AP %1 -> %2 (%3)", _delta, WARCOM_opfor_ap, _reason]] call fnc_log;
		};
		case "BLU": {
			WARCOM_blufor_ap = round ((WARCOM_blufor_ap + _delta) max 0); publicVariable "WARCOM_blufor_ap";
			if (_earned > 0) then {
				WARCOM_blufor_ap_earned = round (WARCOM_blufor_ap_earned + _earned); publicVariable "WARCOM_blufor_ap_earned";
				private _t = [WARCOM_blufor_ap_earned] call DUWS_fnc_ap_tier;
				if (_t != WARCOM_blufor_tier) then {
					WARCOM_blufor_tier = _t; publicVariable "WARCOM_blufor_tier";
					["INFO", "ECON", format ["BLU tier -> %1 (earned %2)", _t, WARCOM_blufor_ap_earned]] call fnc_log;
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

// Posts one card for a town and a cause once that pair stops moving, and names the town, the
// cause and the applied figure.
//
// One card per burst, not per charge: a fire mission changes the damage state of dozens of
// buildings within a few seconds and each one is its own charge, so a card each buries the screen
// and pushes everything else off it. Accumulating also means the number the player reads is what
// the barrage actually cost rather than the last -2 of forty.
//
// The cause is half the key rather than a field, so a barrage that levels houses *and* kills
// civilians posts one card for each. Summing across causes would report a figure under a heading
// that only explains part of it -- and with a heal and a demolition in the same window the two
// could cancel into a card that named the wrong direction, or into no card at all.
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
		case "civilian_arrested":     { "STR_DUWS_T_civ_rep_why_arrested" };
		case "idap_success":          { "STR_DUWS_T_civ_rep_why_aid" };
		case "idap_failed":           { "STR_DUWS_T_civ_rep_why_aid_failed" };
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

// Per-town reputation, and the only reputation there is: server-only, signed delta, the writer
// owns the rounding, callers never assign. Deltas are fractional (+0.5, -0.3), so two callers
// rounding differently would compound drift into what a town will sell.
// A town index of -1 is dropped rather than charged somewhere else. Every caller resolves its
// index through fnc_civ_townAt, which answers -1 for open country, a civilians-off campaign and
// RAVAGE/WBK alike -- and reputation is territory, so harm done where no town can see it costs
// nothing. Not broadcast: no client reads civ_town_rep, and the markers below are painted with
// global-effect commands.
//
// The player is told here rather than by each caller. Eight sites announced their own change in
// six different wordings, two announced nothing, and one quoted a figure the clamp had already
// reduced. Queued off the applied change, so a town pinned at a bound contributes nothing at all
// instead of claiming a charge it absorbed.
// _silent suppresses only the notification card, not the write, the marker repaint or the log. The
// passive AoI drift charges every covered town each economy tick, so a card apiece would post a
// dozen at once and bury the event cards this queue exists to keep legible; the town's own marker
// colour is the drift's feedback instead. Every event caller leaves it default, so their cards stand.
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
	// A town crossing the OPFOR band (in either direction) changes the placement keep-out list.
	if ((_old <= -10) != (_new <= -10)) then { [] call fnc_enemy_towns_refresh };
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

// The keep-out list the placement gate (shared/functions/fnc_pos_near_enemy.sqf) reads for towns.
// Broadcast as positions because the gate runs on clients, where civ_town_rep does not exist. Rebuilt
// whole rather than patched: towns number in the tens and a band crossing is rare, so the cost is
// noise and the whole-list form cannot drift out of step with civ_town_rep the way an add/remove can.
fnc_enemy_towns_refresh = {
	if (!isServer) exitWith {};
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	private _locs = missionNamespace getVariable ["civ_locations", []];
	DUWS_enemy_town_pos = [];
	{ if (_x <= -10) then { DUWS_enemy_town_pos pushBack (getPos (_locs select _forEachIndex)) } } forEach _reps;
	publicVariable "DUWS_enemy_town_pos";
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
// the union and cannot report less money than the player is holding. Counting magazines alone
// -- which two of the four purchase paths used to do -- can only ever undercount, and an
// undercount tells a player who can afford something that they cannot.
// Available on clients too: the civilian menu shows the player what they are carrying.
fnc_money_count = {
	params ["_unit"];
	if (isNull _unit) exitWith { 0 };
	{ _x == "Money_roll" } count (itemsWithMagazines _unit)
};

// Spends money and reports whether it could. Server-only, and the caller says nothing about the
// price until this returns: a client's count is a snapshot, and in co-op two players can spend
// the same money, so this read and the removal are adjacent statements on the one machine that
// owns the inventory -- the same reason fnc_pool_try_spend exists for CP.
//
// Both removal commands are needed because both slots are counted, and each ignores the other's.
// Callers own the refusal message: the four purchase paths word it differently and one of them
// closes a civilian on top.
fnc_money_spend = {
	if (!isServer) exitWith { false };
	params ["_unit", ["_amount", 0]];
	if (([_unit] call fnc_money_count) < _amount) exitWith { false };
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

// Client half of the purchase handshake: blocks until the server rules on the request,
// so callers must already be scheduled -- every purchase entry point is spawned. Refuses
// on timeout rather than falling through: silence must not let a purchase happen.
// A zero cost short-circuits, because several comm-menu supports are charged at unlock
// time and pass 0 here.
// duws_last_charge carries what was actually debited, for the one caller that has to record it
// (client/supports/fnc_supports_init.sqf). Returned on the side rather than in place of the
// verdict so the forty existing call sites, which read this as a guard clause, stay as they are.
fnc_pool_spend = {
	params [["_pool", "CP"], ["_cost", 0]];
	duws_last_charge = 0;
	// Zero cost short-circuits: several comm-menu supports are charged at unlock and pass 0 here. A
	// dual price is [cp, ap] and short-circuits only when both halves are zero. duws_last_charge then
	// carries a [cp, ap] pair back to the one caller that records it (the support refund), a scalar
	// otherwise, matching what fnc_pool_try_spend replied.
	private _zero = if (_pool == "CPAP") then { (_cost param [0, 0]) <= 0 && {(_cost param [1, 0]) <= 0} } else { _cost <= 0 };
	if (_zero) exitWith { true };
	duws_spend_seq = (missionNamespace getVariable ["duws_spend_seq", 0]) + 1;
	private _replyVar = format ["duws_spend_reply_%1", duws_spend_seq];
	[_pool, _cost, player, _replyVar] remoteExec ["fnc_pool_try_spend", 2];
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

// ---------------------------------------------------------------------------
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

// Tally class -> count from a getUnitLoadout array. The loadout nests counts in three shapes -- a
// weapon's loaded magazine is [mag, ammo] (one magazine), a container holds [class, count] pairs,
// and worn/assigned slots are bare strings -- so a flat pushBackUnique scan would both lose counts
// and miss magazines. Returns a HashMap.
fnc_captured_loadout_counts = {
	params [["_loadout", []]];
	private _counts = createHashMap;
	private _bump = {
		params ["_cls", ["_n", 1]];
		if (_cls isEqualType "" && {_cls != ""}) then {
			_counts set [_cls, (_counts getOrDefault [_cls, 0]) + _n];
		};
	};
	// primary/secondary/handgun/binocular share this shape: 0 name, 1 muzzle, 2 pointer, 3 optic,
	// 4/5 [mag, ammo], 6 bipod.
	private _weapon = {
		params ["_w"];
		if (!(_w isEqualType []) || {_w isEqualTo []}) exitWith {};
		{ [_w param [_x, ""]] call _bump; } forEach [0, 1, 2, 3, 6];
		{
			private _m = _w param [_x, []];
			if (_m isEqualType [] && {(count _m) >= 1}) then { [_m select 0, 1] call _bump; };
		} forEach [4, 5];
	};
	// uniform/vest/backpack: [name, [[class, count], ...]].
	private _container = {
		params ["_c"];
		if (!(_c isEqualType []) || {_c isEqualTo []}) exitWith {};
		[_c param [0, ""]] call _bump;
		private _contents = _c param [1, []];
		if (_contents isEqualType []) then {
			{
				if (_x isEqualType [] && {(count _x) >= 1}) then { [_x select 0, _x param [1, 1]] call _bump; };
			} forEach _contents;
		};
	};
	{ [_loadout param [_x, []]] call _weapon; } forEach [0, 1, 2, 8];
	{ [_loadout param [_x, []]] call _container; } forEach [3, 4, 5];
	[_loadout param [6, ""]] call _bump;   // headgear
	[_loadout param [7, ""]] call _bump;   // facewear
	private _assigned = _loadout param [9, []];
	if (_assigned isEqualType []) then { { [_x] call _bump; } forEach _assigned; };
	_counts
};

// Arsenal close (server). Diffs the loadout the player opened with against the one they closed with,
// per foreign class: a class present at close but not open (or in a greater count) was withdrawn from
// the shelf; a lesser count was deposited. net = close - open. A friendly class is skipped -- it is
// unlimited and never touches the pool. Overdraw (net beyond what the pool held) is answered by
// replying the excess back to the client to strip, which is what makes a count-1 rifle yield one.
fnc_captured_pool_settle = {
	if (!isServer) exitWith {};
	params [["_openLoadout", []], ["_closeLoadout", []], ["_requester", objNull], ["_replyVar", ""]];
	call fnc_captured_pool_friendly;
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
		if (!DUWS_arsenalLimited && {_cls in DUWS_friendlyArsenal}) then { continue };
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
	if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["pool settle: touched=%1 excess=%2", _classes, _excess]] call fnc_log; };
	publicVariable "DUWS_capturedPool";
	if (_replyVar != "") then { [_replyVar, true, _excess] remoteExec ["fnc_pool_reply", _requester]; };
};

// Deposit a whole loadout (server). The quick-kit swap wipes the player's gear, so its pre-swap
// loadout is banked wholesale. Same exemptions as settle: untracked ammo and (outside Limited)
// friendly gear are not pooled.
fnc_captured_pool_deposit_loadout = {
	if (!isServer) exitWith {};
	params [["_loadout", []]];
	call fnc_captured_pool_friendly;
	private _c = [_loadout] call fnc_captured_loadout_counts;
	{
		private _cls = _x;
		if (!DUWS_trackAmmo && {isClass (configFile >> "CfgMagazines" >> _cls)}) then { continue };
		if (!DUWS_arsenalLimited && {_cls in DUWS_friendlyArsenal}) then { continue };
		[_cls, ([_cls] call fnc_captured_pool_getCount) + (_c get _cls)] call fnc_captured_pool_setCount;
	} forEach (keys _c);
	if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["pool deposit_loadout: %1", keys _c]] call fnc_log; };
	publicVariable "DUWS_capturedPool";
};

// Deposit explicit [class, count] pairs (server). Friendly classes are skipped: pooling one is
// harmless (friendly is unlimited regardless) but pointless. Used by the loot caches.
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

// Loot-cache reward (server). Spreads the pool wide and shallow: a fixed few kinds of OPFOR gear,
// each at a small random count, so clearing a cache broadens the shelf rather than stockpiling one
// item. Weapons come from the built OPFOR ammobox list; wearables and attachments are read from the
// OPFOR role units' config loadouts, since the ammobox item list holds neither worn nor mounted gear.
fnc_captured_pool_cache_deposit = {
	if (!isServer) exitWith {};
	private _pick = {
		params ["_src", "_n"];
		private _bag = +_src;
		private _out = [];
		for "_i" from 1 to (_n min (count _bag)) do { _out pushBack (_bag deleteAt (floor random (count _bag))); };
		_out
	};
	private _wear = [];
	private _attach = [];
	{
		private _uc = _x;
		if (_uc isEqualType "" && {_uc != ""} && {isClass (configFile >> "CfgVehicles" >> _uc)}) then {
			private _l = getUnitLoadout _uc;
			{
				private _c = _l param [_x, []];
				if (_c isEqualType [] && {(_c param [0, ""]) != ""}) then { _wear pushBackUnique (_c select 0); };
			} forEach [3, 4, 5];   // uniform/vest/backpack
			private _hg = _l param [6, ""];
			if (_hg != "") then { _wear pushBackUnique _hg; };
			{
				private _w = _l param [_x, []];
				if (_w isEqualType []) then {
					{ private _a = _w param [_x, ""]; if (_a != "") then { _attach pushBackUnique _a; }; } forEach [1, 2, 3, 6];
				};
			} forEach [0, 1, 2];   // primary/secondary/handgun attachment slots
		};
	} forEach [opfor_SOLDIER_X, opfor_SPECOPS_X, opfor_SPECOPS_MEDIC_X, opfor_LAT_SOLDIER_X];
	private _pairs = [];
	// rand(3-10) inclusive per line.
	{ _pairs pushBack [_x, 3 + floor random 8]; } forEach (
		([opfor_ammobox_weapons, 3] call _pick) + ([_wear, 2] call _pick) + ([_attach, 2] call _pick)
	);
	[_pairs] call fnc_captured_pool_deposit_counts;
};
