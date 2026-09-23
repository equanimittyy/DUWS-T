// Garrison attrition, shared by every kind of ground that holds one (zone or town): both wear down the
// same way, so this is one store keyed by a caller-owned string (`zone_<x>_<y>` / `town_<n>`). Defines
// several functions, so it is executed by the registry and must load ahead of its two consumers,
// fnc_zone_state_init and fnc_civ_state_init.
//
// Attrition is a ledger of lost whole tokens, not a men-thin scalar: a garrison's potential is a multiset
// of composition tokens, and everything it fields is full minus lost -- so a mauled site comes back
// missing specifically what it lost (destroy one tank, lose one tank). Model:
// docs/info/gameplay/garrison_and_reserves.md.

// Whose garrison a site holds, derived rather than stored: a stored copy is one more thing every flip has
// to remember to move. Ground with no holder answers "OPF".
DUWS_fnc_garrisonSideOf = {
	params ["_key"];
	if ((_key select [0, 5]) isEqualTo "town_") exitWith {
		if (([[parseNumber (_key select [5])] call fnc_civ_repAt] call fnc_civ_townOwner) isEqualTo "BLU")
			then { "BLU" } else { "OPF" }
	};
	if ([_key] call fnc_zone_bluforHeld) exitWith { "BLU" };
	"OPF"
};

// The full fighting potential, stamped at raise and re-stamped by a tier buy, an OPFOR cap or a town clear. Every strength
// measure counts tokens, not men: a tank weighs the same as a patrol.
// Tokens behind an unearned Army Power rung are skipped at read, not stamp, so a site gains them the moment the rung is
// earned. Tested per distinct token: the force grid reads every site's full each rebuild.
DUWS_fnc_garrisonFull = {
	params ["_key"];
	private _full = missionNamespace getVariable [format ["DUWS_garrisonFull_%1", _key], []];
	private _side = [_key] call DUWS_fnc_garrisonSideOf;
	_full - ((_full arrayIntersect _full) select { [_x, _side] call DUWS_fnc_tokenLocked })
};

DUWS_fnc_garrisonLocked = {
	params ["_key"];
	(missionNamespace getVariable [format ["DUWS_garrisonFull_%1", _key], []]) - ([_key] call DUWS_fnc_garrisonFull)
};

DUWS_fnc_garrisonSetFull = {
	params ["_key", "_full"];
	missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _key], _full];
	[_key] call DUWS_fnc_opcom_gridDirty;
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

// The infantry men a garrison fields, crew excluded (a vehicle token owes no men). Live counts alive
// roster infantry (a casualty drops it that tick); stowed falls to the ledger's surviving-token men. The
// men component of DUWS_fnc_garrisonForce below, which is what the grid and the readout actually deposit.
DUWS_fnc_garrisonMen = {
	params ["_key"];
	if ([_key] call DUWS_fnc_garrisonHeld) exitWith {
		{ alive _x && {!(([(group _x) getVariable ["DUWS_srcToken", ""]] call DUWS_fnc_teamRow) isEqualTo [])} } count ([_key] call fnc_site_roster)
	};
	[[_key] call DUWS_fnc_garrisonSurviving] call DUWS_fnc_tokenListMen
};

// The firepower a garrison contributes to the force grid: its infantry men (garrisonMen), the power of its
// surviving vehicle tokens, and a zone's centre statics (DUWS_fnc_zoneStaticForce). Vehicle attrition is
// whole-token -- a destroyed vehicle leaves the surviving set through the loss ledger, so a mauled garrison
// weighs less with no per-object health tracked.
DUWS_fnc_garrisonForce = {
	params ["_key"];
	private _vehTokens = ([_key] call DUWS_fnc_garrisonSurviving) select {
		([[_x] call DUWS_fnc_tokenName] call DUWS_fnc_teamRow) isEqualTo []
	};
	([_key] call DUWS_fnc_garrisonMen) + ([_vehTokens] call DUWS_fnc_tokenListForce) + ([_key] call DUWS_fnc_zoneStaticForce)
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

// The ceiling is the standing template's count, not what deployed: a mauled garrison stands fewer groups, and reserves
// bring it back up to this. The derive rebuilds only the base pool, so OPCOM's pooled tokens are carried across it and
// its accounted units stay in the ceiling; the sync then diffs against them. -> garrison
DUWS_fnc_garrisonRestand = {
	params ["_key", "_x1"];
	private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
	private _side = [_key] call DUWS_fnc_garrisonSideOf;
	private _stand = [_x1 select { !([_x, _side] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_zoneDensityStand;
	private _opcom = ([_key] call DUWS_fnc_garrisonReserve) select { (_x select [0, 8]) == "opcomdef" };
	private _garrison = ([_key, _x1, _mult, _stand] call DUWS_fnc_garrisonDerive) select 0;
	([_key] call DUWS_fnc_garrisonReserve) append _opcom;
	missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _key],
		count _stand + count (missionNamespace getVariable [format ["DUWS_zoneReserveOpcom_%1", _key], []])];
	if (!isNil "DUWS_fnc_opcom_zoneReserveSync") then { [_key] call DUWS_fnc_opcom_zoneReserveSync };
	_garrison
};

// A raise stands its gap now, not on the refill's next wave, which can be five minutes off. -> garrison plus the draw
DUWS_fnc_garrisonStandFill = {
	params ["_key", "_garrison"];
	private _side = [_key] call DUWS_fnc_garrisonSideOf;
	private _room = ((missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0]) - count _garrison)
		min (DUWS_zoneGroupCeiling - ([_side] call DUWS_fnc_sideGroupCount) - count _garrison);
	if (_room <= 0) exitWith { _garrison };
	private _pool = [_key] call DUWS_fnc_garrisonReserve;
	private _fieldable = _pool select { ([_x, _side] call DUWS_fnc_tokenClass) != "" };
	private _base = _fieldable select { (_x select [0, 8]) != "opcomdef" };
	private _drawn = [];
	while { count _drawn < _room && {count _base > 0} } do { _drawn pushBack (_base deleteAt (floor random count _base)) };
	_drawn append ((_fieldable select { (_x select [0, 8]) == "opcomdef" }) select [0, _room - count _drawn]);
	[_key, [_drawn, _pool] call DUWS_fnc_spawnDiff] call DUWS_fnc_garrisonReserveSet;
	_garrison + _drawn
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
	[_key] call DUWS_fnc_opcom_gridDirty;
};

// The strength a garrison redeploys at, as a fraction: surviving tokens over full tokens. Full for ground
// nobody has fought over (no full stamped yet). Counted off the surviving multiset rather than the lost count,
// so losses filed against an older, larger full never read below empty.
DUWS_fnc_garrisonStrength = {
	params ["_key"];
	private _full = count ([_key] call DUWS_fnc_garrisonFull);
	if (_full <= 0) exitWith { 1 };
	(count ([_key] call DUWS_fnc_garrisonSurviving)) / _full
};

// Keeps _keep random tokens of full and files the rest lost; the caller picks the rounding. The raise fills the
// garrison before the pool, so a thin seed leaves a thin single garrison with no reserve depth.
// Locked tokens are filed lost too, so earning their rung never refills ground a seed emptied.
DUWS_fnc_garrisonSeed = {
	params ["_key", "_keep"];
	private _lost = +([_key] call DUWS_fnc_garrisonFull);
	for "_i" from 1 to (_keep min count _lost) do { _lost deleteAt (floor random count _lost) };
	missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _key], _lost + ([_key] call DUWS_fnc_garrisonLocked)];
	[_key] call DUWS_fnc_opcom_gridDirty;
};

// Full is stamped here, not left to the raise, because the seed thins against it: a retaken zone still carries its
// old tier's full, and a town just back in the band has none. Rounded up so a small tier I still stands one token.
DUWS_fnc_garrisonSeedOpforCap = {
	params ["_key", "_x1"];
	private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
	private _full = [_x1, _mult] call DUWS_fnc_scaleComposition;
	[_key, _full] call DUWS_fnc_garrisonSetFull;
	[_key, ceil (0.1 * count ([_key] call DUWS_fnc_garrisonFull))] call DUWS_fnc_garrisonSeed;
};

// Buys _n random destroyed tokens back. The reinforce purchase's hook -- a paid replacement, the one thing that raises
// strength, and deliberately not a heal (it costs, and the men still have to walk in on the next refill wave).
// A locked token is not bought back: it would lift no strength until its rung.
DUWS_fnc_garrisonUnlose = {
	params ["_key", "_n"];
	private _var = format ["DUWS_garrisonLost_%1", _key];
	private _all = missionNamespace getVariable [_var, []];
	private _side = [_key] call DUWS_fnc_garrisonSideOf;
	private _lost = _all select { !([_x, _side] call DUWS_fnc_tokenLocked) };
	for "_i" from 1 to (_n min count _lost) do { _lost deleteAt (floor random count _lost) };
	missionNamespace setVariable [_var, _lost + (_all select { [_x, _side] call DUWS_fnc_tokenLocked })];
	[_key] call DUWS_fnc_opcom_gridDirty;
};

// Shared by town and zone, so both climb by one rule. An empty _x1 skips the re-stand, since deriving from it would
// stamp full to nothing: a town dropped to tier 0 stays live until its next tick collects it.
#define REINFORCE_STEP 0.3
DUWS_fnc_garrisonReinforceCount = {
	params ["_key"];
	floor (REINFORCE_STEP * count ([_key] call DUWS_fnc_garrisonFull))
};

DUWS_fnc_garrisonReinforce = {
	params ["_key", "_x1"];
	[_key, [_key] call DUWS_fnc_garrisonReinforceCount] call DUWS_fnc_garrisonUnlose;
	if (([_key] call DUWS_fnc_garrisonHeld) && {_x1 isNotEqualTo []}) then { [_key, _x1] call DUWS_fnc_garrisonRestand };
};

// The commander pays reinforcements to field the rest of a bought tier. Bounded by the new full: a cleared town's
// ledger can still hold the tokens of the higher tier it was cleared at. Full is stamped now, not at the next raise,
// so the grid and the readout see the buy at once. The caller re-stands a standing garrison.
DUWS_fnc_garrisonBuyTier = {
	params ["_key", "_oldX1", "_newX1"];
	private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
	private _full = [_newX1, _mult] call DUWS_fnc_scaleComposition;
	private _owed = [[_oldX1, _mult] call DUWS_fnc_scaleComposition, _full] call DUWS_fnc_spawnDiff;
	private _side = [_key] call DUWS_fnc_garrisonSideOf;
	private _open = _owed select { !([_x, _side] call DUWS_fnc_tokenLocked) };
	for "_i" from 1 to ceil (0.1 * count _open) do { _open deleteAt (floor random count _open) };
	_owed = _open + (_owed select { [_x, _side] call DUWS_fnc_tokenLocked });
	private _var = format ["DUWS_garrisonLost_%1", _key];
	private _lost = missionNamespace getVariable [_var, []];
	{
		private _token = _x;
		if (({ _x isEqualTo _token } count _lost) < ({ _x isEqualTo _token } count _full)) then { _lost pushBack _token };
	} forEach _owed;
	missionNamespace setVariable [_var, _lost];
	[_key, _full] call DUWS_fnc_garrisonSetFull;
};

// Forgets a site's garrison entirely: full potential and loss ledger both cleared. For a site that
// stops being a garrison at all -- a town worked back out of the OPFOR band -- so if it becomes one
// again it starts fresh, rather than redeploying the remains of a garrison the ground no longer holds.
// A zone is never forgotten: it is always OPFOR-generated ground, and a recapture seeds it instead.
DUWS_fnc_garrisonForget = {
	params ["_key"];
	missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _key], nil];
	missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _key], nil];
	[_key] call DUWS_fnc_opcom_gridDirty;
};

// Liveness: a garrison is live from the moment its raise finishes placing men to the stow or capture
// that tears it down. The capture and clear tests refuse on a garrison that is not live -- stowed,
// mid-raise, or gone -- so empty ground cannot be taken before its men have arrived, and the reserve
// pass has nothing to top up. Per awake session; the ledger and the full potential outlive it. Both a
// zone and a town set and clear it, the one signal that the garrison on the ground is real.
// Zones and towns only. A hardpoint's liveness is its own broadcast DUWS_hardpoints row (latched on
// clear, read client-side by the strat-map pickers), which this server-only graded ledger cannot model.
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
	[_key] call DUWS_fnc_opcom_gridDirty;
};

// The key a town files under. Delegates to fnc_town_site_key -- the one derivation of a town's key --
// rather than repeating its format, so the ledger this file keys and the site store the garrison code
// keys can never drift apart on a town. Zones derive theirs through fnc_zone_key; a town has no such
// key of its own, so this is the whole of it.
DUWS_fnc_townStrengthKey = {
	params ["_townIndex"];
	[_townIndex] call fnc_town_site_key
};

// Built from the accessors above, not recomputed, so it prints what the model acts on. A string row opens a section;
// a [label, value, detail] row fills it.
DUWS_fnc_garrisonDebug = {
	params ["_key"];
	private _full = [_key] call DUWS_fnc_garrisonFull;
	private _locked = [_key] call DUWS_fnc_garrisonLocked;
	// A seed or tier buy files locked tokens lost, but they never fielded: they read under Locked until their rung.
	private _lost = ([_key] call DUWS_fnc_garrisonLost) select { !([_x] call DUWS_fnc_tokenLocked) };
	private _surv = [_key] call DUWS_fnc_garrisonSurviving;

	// Awake-session fielding: the x1 group ceiling (the most that stands on the ground at once), what is
	// on it right now, and the reserve pool waiting to backfill. All three are nil/empty once the site
	// stows, so they read as 0 unless the site is live.
	private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
	private _onGround = [_key] call DUWS_fnc_garrisonGroupCount;
	private _pool = [_key] call DUWS_fnc_garrisonReserve;

	// Tallied, not listed flat, which runs off the hint box at x3.
	private _tally = {
		params ["_tokens"];
		if (_tokens isEqualTo []) exitWith { "" };
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
		"Garrison",
		["Live on ground", ["no", "yes"] select ([_key] call DUWS_fnc_garrisonHeld)],
		["Strength", ([_key] call DUWS_fnc_garrisonStrength) toFixed 2, format ["%1 available / %2 full tokens", count _surv, count _full]],
		["Max tokens", format ["%1 (%2 men)", count _full, [_full] call DUWS_fnc_tokenListMen], [_full] call _tally],
		["Locked", str count _locked, [_locked] call _tally],
		["Available", format ["%1 (%2 men)", count _surv, [_surv] call DUWS_fnc_tokenListMen], [_surv] call _tally],
		["On ground", format ["%1 / %2 groups (x1 cap)", _onGround, _ceiling]],
		["Reserve", format ["%1 (%2 men)", count _pool, [_pool] call DUWS_fnc_tokenListMen], [_pool] call _tally],
		["Dead", format ["%1 (%2 men)", count _lost, [_lost] call DUWS_fnc_tokenListMen], [_lost] call _tally]
	]
};
