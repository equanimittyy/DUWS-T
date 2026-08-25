// Garrison attrition, shared by every kind of ground that holds one.
//
// Executed by the registry rather than stored as one function: this file defines several. Loaded
// ahead of both fnc_zone_state_init and fnc_civ_state_init, which are its two consumers.
//
// A zone and a town differ in what they *are* -- one has an owner, the other an opinion -- but not in
// how a garrison wears down: both raise a composition, get ground down by the same player, and come
// back at what was left, not what they started with. So this is one store keyed by a string:
// `zone_<x>_<y>` for a zone, `town_<n>` for a town. Callers own the key format; nothing here inspects it.
//
// Attrition is a **ledger of lost whole tokens**, not a scalar men-thin. A garrison's full fighting
// potential is a multiset of composition tokens (mult copies of its filtered tier list); the ledger
// records which tokens are destroyed, and everything a site fields derives from full minus lost. A
// token is lost when its group is wiped -- destroy one tank, lose one tank -- so a mauled zone comes
// back specifically the units it lost, not thinner everywhere. The model is
// docs/info/gameplay/garrison_and_reserves.md. spawnDiff/tokenListMen resolve at call time, living in
// fnc_zone_spawn_sizes and fnc_spawn_vocab; every function here runs at gameplay, long after both load.

// The full fighting potential, stamped once at raise (and re-stamped on a town tier buy, which grows
// it). Stored as the token list and its men count both: the list drives surviving/seed/loss, the men
// count is the projection's and the break test's denominator and is read often enough to keep hot.
DUWS_fnc_garrisonFull = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_garrisonFull_%1", _key], []]
};

DUWS_fnc_garrisonFullMen = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_garrisonFullMen_%1", _key], 0]
};

DUWS_fnc_garrisonSetFull = {
	params ["_key", "_full"];
	missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _key], _full];
	missionNamespace setVariable [format ["DUWS_garrisonFullMen_%1", _key], [_full] call DUWS_fnc_tokenListMen];
};

// The lost ledger: a flat token list, a multiset by value. Persists across a stow -- attrition is what
// outlives a garrison leaving -- and is cleared only by a fresh campaign or a seed (recapture / clear).
DUWS_fnc_garrisonLost = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_garrisonLost_%1", _key], []]
};

// What still stands: the full multiset less the lost one. spawnDiff removes one full entry per lost
// entry by value, so multiplicity is exact -- two patrols lost against three owed leaves one.
DUWS_fnc_garrisonSurviving = {
	params ["_key"];
	[[_key] call DUWS_fnc_garrisonLost, [_key] call DUWS_fnc_garrisonFull] call DUWS_fnc_spawnDiff
};

// The whole-token derivation a zone raise and a town raise share: given the filtered x1 tier list and
// the multiplier, stamp the site's full potential (mult copies of x1), seed its live reserve pool, and
// return [garrison, pool]. The survivors split by the standing template -- its worth is the garrison,
// the surplus is the pool -- so a site's losses come out of its reserve depth before they thin the
// garrison. The caller raises the garrison and tops it up from the pool; here is only the accounting.
//
// _stand is the standing template, a subset of x1 (default x1). Both zones and towns pass a
// garrison-density-thinned list so fewer patrols stand at once and the trimmed ones fall to the pool;
// full potential stays mult copies of x1 either way -- density defers force, it does not remove it. The
// default is retained only as the safe fallback for a caller that passes none.
DUWS_fnc_garrisonDerive = {
	params ["_key", "_x1", "_mult", ["_stand", []]];
	if (_stand isEqualTo []) then { _stand = _x1 };
	private _full = [_x1, _mult] call DUWS_fnc_scaleComposition;
	[_key, _full] call DUWS_fnc_garrisonSetFull;
	private _surviving = [_key] call DUWS_fnc_garrisonSurviving;
	private _pool = [_stand, _surviving] call DUWS_fnc_spawnDiff;
	private _garrison = [_pool, _surviving] call DUWS_fnc_spawnDiff;
	[_key, _pool] call DUWS_fnc_garrisonReserveSet;
	[_garrison, _pool]
};

// Records one destroyed token. Bounded at its count in full: a garrison cannot lose more tanks than it
// ever had, and the bound is also what makes a double-fire of the killed handler -- which runs per unit
// -- a no-op once a token's copies are all accounted for. A token not in full is ignored rather than
// recorded, so a stray group tagged from elsewhere cannot drive strength negative.
DUWS_fnc_garrisonRecordLoss = {
	params ["_key", "_token"];
	private _cap = { _x isEqualTo _token } count ([_key] call DUWS_fnc_garrisonFull);
	if (_cap <= 0) exitWith {};
	private _var = format ["DUWS_garrisonLost_%1", _key];
	private _lost = missionNamespace getVariable [_var, []];
	if (({ _x isEqualTo _token } count _lost) >= _cap) exitWith {};
	_lost pushBack _token;
	missionNamespace setVariable [_var, _lost];
};

// The strength a garrison redeploys at, as a fraction: surviving men over full men. Full for ground
// nobody has fought over (no full stamped yet). The map bar reads this; the raise reads the surviving
// tokens directly. Falls only for a zone -- the ledger only grows -- and rises for a town only when the
// commander buys reserves back (Unlose). No quantisation or floor here: those were the scalar model's,
// and the break test's own tenth is the one number that gates capture.
DUWS_fnc_garrisonStrength = {
	params ["_key"];
	private _fullMen = [_key] call DUWS_fnc_garrisonFullMen;
	if (_fullMen <= 0) exitWith { 1 };
	private _lostMen = [[_key] call DUWS_fnc_garrisonLost] call DUWS_fnc_tokenListMen;
	(((_fullMen - _lostMen) / _fullMen) max 0) min 1
};

// Seeds the ledger to a target survival fraction by marking random tokens lost until survival is at or
// under it. The reserve/garrison split at raise fills the garrison before the pool, so dropping to a
// low fraction empties the pool first and leaves a thin single garrison -- which is what a recaptured
// zone or a cleared town should redeploy as. Vehicles owe no men, so a low seed sheds them freely,
// matching the old 0.3 scratch force that fielded no armour.
DUWS_fnc_garrisonSeed = {
	params ["_key", "_frac"];
	private _target = _frac * ([_key] call DUWS_fnc_garrisonFullMen);
	private _surv = +([_key] call DUWS_fnc_garrisonFull);
	private _lost = [];
	while { count _surv > 0 && {([_surv] call DUWS_fnc_tokenListMen) > _target} } do {
		_lost pushBack (_surv deleteAt (floor random count _surv));
	};
	missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _key], _lost];
};

// Buys destroyed tokens back: removes random lost entries until survival reaches the target fraction.
// The town reinforce purchase's hook -- a paid replacement, the one thing that raises strength, and
// deliberately not a heal (it costs, and the men still have to walk in on the next refill wave).
DUWS_fnc_garrisonUnlose = {
	params ["_key", "_target"];
	private _fullMen = [_key] call DUWS_fnc_garrisonFullMen;
	if (_fullMen <= 0) exitWith {};
	private _var = format ["DUWS_garrisonLost_%1", _key];
	private _lost = +(missionNamespace getVariable [_var, []]);
	private _targetMen = _target * _fullMen;
	while { count _lost > 0 && {(_fullMen - ([_lost] call DUWS_fnc_tokenListMen)) < _targetMen} } do {
		_lost deleteAt (floor random count _lost);
	};
	missionNamespace setVariable [_var, _lost];
};

// Forgets a site's garrison entirely: full potential and loss ledger both cleared. For a site that
// stops being a garrison at all -- a town worked back out of the OPFOR band -- so if it becomes one
// again it starts fresh, rather than redeploying the remains of a garrison the ground no longer holds.
// A zone is never forgotten: it is always OPFOR-generated ground, and a recapture seeds it instead.
DUWS_fnc_garrisonForget = {
	params ["_key"];
	missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _key], nil];
	missionNamespace setVariable [format ["DUWS_garrisonFullMen_%1", _key], nil];
	missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _key], nil];
};

// Liveness: a garrison is live from the moment its raise finishes placing men to the stow or capture
// that tears it down. The capture and clear tests refuse on a garrison that is not live -- stowed,
// mid-raise, or gone -- so empty ground cannot be taken before its men have arrived, and the reserve
// pass has nothing to top up. Per awake session; the ledger and the full potential outlive it. Both a
// zone and a town set and clear it, the one signal that the garrison on the ground is real. It replaces
// the peak's old double duty: the men denominator is DUWS_fnc_garrisonFullMen now, this is the liveness.
DUWS_fnc_garrisonHeld = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_garrisonLive_%1", _key], false]
};

DUWS_fnc_garrisonSetLive = {
	params ["_key", "_live"];
	missionNamespace setVariable [format ["DUWS_garrisonLive_%1", _key], _live];
	// The live sites are also the registry the reserve pass iterates -- the one list where a zone and a
	// town meet as garrison sites. Kept in lockstep with the flag: a site is on it exactly while live.
	private _sites = missionNamespace getVariable ["DUWS_garrisonSites", []];
	if (_live) then {
		_sites pushBackUnique _key;
	} else {
		private _i = _sites find _key;
		if (_i >= 0) then { _sites deleteAt _i };
	};
	missionNamespace setVariable ["DUWS_garrisonSites", _sites];
};

// The key a town files under. Delegates to fnc_town_site_key -- the one derivation of a town's key --
// rather than repeating its format, so the ledger this file keys and the site store the garrison code
// keys can never drift apart on a town. Zones derive theirs through fnc_zone_key; a town has no such
// key of its own, so this is the whole of it.
DUWS_fnc_townStrengthKey = {
	params ["_townIndex"];
	[_townIndex] call fnc_town_site_key
};

// The dev readout for one site's ledger: the four numbers the model turns on -- full potential, what
// still stands, what is dead, and the strength maths tying them. Read-only, and every value comes from
// the accessors above rather than being recomputed, so what it prints is what the model acts on. The
// Debug menu's garrison row and its server query are the only callers.
DUWS_fnc_garrisonDebug = {
	params ["_key"];
	private _full = [_key] call DUWS_fnc_garrisonFull;
	private _lost = [_key] call DUWS_fnc_garrisonLost;
	private _surv = [_key] call DUWS_fnc_garrisonSurviving;
	private _fullMen = [_key] call DUWS_fnc_garrisonFullMen;
	private _lostMen = [_lost] call DUWS_fnc_tokenListMen;
	private _survMen = [_surv] call DUWS_fnc_tokenListMen;

	// Awake-session fielding: the x1 group ceiling (the most that stands on the ground at once), what is
	// on it right now, and the reserve pool waiting to backfill. All three are nil/empty once the site
	// stows, so they read as 0 unless the site is live -- the "live on ground" line below says which.
	private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
	private _onGround = [_key] call DUWS_fnc_garrisonGroupCount;
	private _pool = [_key] call DUWS_fnc_garrisonReserve;
	private _poolMen = [_key] call DUWS_fnc_garrisonReserveMen;

	// Multiset tally: "2x closepatrol:team, 1x armour:tank" rather than a raw flat list, which for a x3
	// garrison runs off the hint box. First-seen order, so full/available/dead columns read alike.
	private _tally = {
		params ["_tokens"];
		if (_tokens isEqualTo []) exitWith { "(none)" };
		private _seen = [];
		private _num = [];
		{
			private _i = _seen find _x;
			if (_i < 0) then { _seen pushBack _x; _num pushBack 1 }
			else { _num set [_i, (_num select _i) + 1] };
		} forEach _tokens;
		(_seen apply { format ["%1x %2", _num select (_seen find _x), _x] }) joinString ", "
	};

	[
		format ["[GARRISON %1]", _key],
		format ["  live on ground: %1", [_key] call DUWS_fnc_garrisonHeld],
		format ["  max tokens: %1 (%2 men)  %3", count _full, _fullMen, [_full] call _tally],
		format ["  available:  %1 (%2 men)  %3", count _surv, _survMen, [_surv] call _tally],
		format ["    on ground: %1 / %2 groups (x1 cap)", _onGround, _ceiling],
		format ["    reserve:   %1 (%2 men)  %3", count _pool, _poolMen, [_pool] call _tally],
		format ["  dead:       %1 (%2 men)  %3", count _lost, _lostMen, [_lost] call _tally],
		format ["  strength: (%1 full - %2 dead) / %1 = %3", _fullMen, _lostMen, [_key] call DUWS_fnc_garrisonStrength]
	]
};
