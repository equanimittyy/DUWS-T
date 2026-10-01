// Locality: server -- spawned once from server/server_init.sqf to publish the tables below.
//
// Token grammar: a name resolves to a team row (DUWS_teamRosters), else a vehicle row
// (DUWS_spawnVehicles), else stands as a faction-named classname directly. Grammar and team table
// live in shared/functions/fnc_spawn_vocab, loaded early enough to price the BLUFOR squad catalogue;
// this file holds both sides' vehicles and the zone tiers they share.

// Indexed tier-1, absolute not cumulative: a tier is the whole garrison, so a tier IV zone reads off
// one row instead of four summed.
//
// Each entry is one group (posture:team); duplicate entries encode count -- infantry lines repeat
// rather than carrying a count field, the same shape the enemy multiplier writes in at spawn.
//
// Radius does not scale this: a zone is its tier, so scaling by radius would put two zones the map
// reports at the same tier on the ground at different strengths for no reason the player can read.
// --DUWS-UNITCOMP BEGIN name="Zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["widepatrol:patrol", "closepatrol:wp_team", "widepatrol:car", "garrison:garrison_element"],
    ["widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:car", "widepatrol:car", "closepatrol:apc", "garrison:garrison_element"],
    ["widepatrol:sniper_element", "widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "widepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:wp_team", "widepatrol:car", "widepatrol:car", "closepatrol:apc", "closepatrol:ifv", "garrison:garrison_element", "garrison:garrison_element"],
    ["widepatrol:sniper_element", "widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:team", "widepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:wp_team", "widepatrol:wp_team", "widepatrol:car", "widepatrol:car", "closepatrol:ifv", "closepatrol:ifv", "closepatrol:tank", "garrison:garrison_element", "garrison:garrison_element"]
];
// --DUWS-UNITCOMP END--

// Returns the x1 garrison only -- the enemy multiplier no longer scales what stands on the ground,
// it is reserve depth now (surplus mult-1 copies become the zone's reserve pool in fnc_zone_spawn).
// Tier is passed rather than read, so the pick is testable against a stand-in tier.
//
// Tier 0 is no garrison, not the smallest one: clamping it up to I would price a first buy at nothing,
// since the buy charges what the new tier adds over the old.
DUWS_fnc_zoneSpawnList = {
    params ["_tier", ["_side", "OPF"]];
    if (_tier < 1) exitWith { [] };
    private _t = ((round _tier) min (count DUWS_zoneSpawnTiers)) - 1;
    [DUWS_zoneSpawnTiers select _t, _side] call DUWS_fnc_spawnFilter
};

// Dropped, not substituted: substituting was never a choice, only an `if` leaking -- an air slot
// with attack helicopters switched off used to fall through to the general vehicle pool, so a player
// who asked for no helicopters got an extra truck per slot instead of a quieter zone.
//
// Runs before the strength thin, so the thin reduces the force the side can actually field.
//
// An Army Power lock is not a drop: the ledger keeps the token and skips it until the rung is earned.
DUWS_fnc_spawnFilter = {
    params ["_tokens", ["_side", "OPF"]];
    _tokens select { ([_x, _side, true] call DUWS_fnc_tokenClass) != "" }
};

// The enemy multiplier, applied to a composition rather than inside a roster: a x3 garrison's full
// potential holds three patrols where it held one, instead of one patrol of six men.
//
// Rejected the roster-scaling shape: that cost two roster columns (a "core" the multiplier repeated,
// a "tail" added once), made group size a campaign setting the player read as one huge fire team, and
// left a squad leader outnumbered by his own riflemen.
//
// Runs after the filter and before the thin, so a token the side cannot field is never duplicated.
DUWS_fnc_scaleComposition = {
    params ["_tokens", ["_mult", 1]];
    private _n = ((round _mult) max 1);
    if (_n <= 1) exitWith { +_tokens };
    private _out = [];
    { for "_k" from 1 to _n do { _out pushBack _x } } forEach _tokens;
    _out
};

// Team resolution is not this function's business -- fnc_factionRoles already drops the roles a
// faction leaves undefined.
DUWS_fnc_tokenClass = {
    params ["_token", ["_side", "OPF"], ["_ignoreLock", false]];
    // Posture resolved here, before the classname passthrough below: fnc_spawn_vehicle needs a bare
    // classname, and "closepatrol:O_MBT_02_cannon_F" is not one.
    private _name = [_token] call DUWS_fnc_tokenName;
    if !(([_name] call DUWS_fnc_teamRow) isEqualTo []) exitWith { _name };
    private _row = [_name, _side] call DUWS_fnc_vehicleRow;
    if (_row isEqualTo []) exitWith { _name };
    _row params ["", "_role", "_setting"];
    // Missing setting defaults to on, so a campaign that predates a new rule keeps the token instead
    // of quietly losing it.
    if (_setting != "" && {(missionNamespace getVariable [_setting, 1]) != 1}) exitWith { "" };
    if (!_ignoreLock && {[_name, _side] call DUWS_fnc_tokenLocked}) exitWith { "" };
    // Drawn per spawn rather than held as one campaign-wide value, so two zones raised in the same
    // second don't both put down the identical APC.
    //
    // car/apc/ifv/tank keep a gun hull -- a missile-only one parks at range and duels instead of
    // taking the objective -- while at_car/aa_car take the gunless AT/AA hulls car drops.
    private _filter = switch true do {
        case (_name in ["car", "apc", "ifv", "tank"]): { DUWS_fnc_classGroundCapable };
        case (_name == "at_car"):                      { DUWS_fnc_classAT };
        case (_name == "aa_car"):                      { DUWS_fnc_classAA };
        default                                        { [] };
    };
    [_role, _filter] call fnc_faction_pick
};

// Multiset diff (counts duplicates, not set difference): two patrols wanted against one already
// standing yields one patrol. This is what lets a garrison upgrade mid-fight -- reinforcement raises
// just the difference and lands beside the survivors, instead of re-raising the whole list and
// doubling the town.
DUWS_fnc_spawnDiff = {
    params ["_have", "_want"];
    private _pool = +_have;
    private _out = [];
    {
        private _i = _pool find _x;
        if (_i < 0) then { _out pushBack _x } else { _pool deleteAt _i };
    } forEach _want;
    _out
};

// Staggered (per-token sleep) so a whole composition never spawns in one frame. Returns the groups
// rather than appending: safe because nothing reads a zone's roster mid-place -- the capture test
// refuses until the garrison is flagged live, which happens after this returns.
DUWS_fnc_raiseGarrison = {
    params ["_tokens", "_pos", "_radius", ["_side", "OPF"]];
    private _grps = [];
    {
        // A player driving in reaches the band during the stagger; a group with no clear point is refunded as a reserve wave.
        private _grp = [_x, _pos, _radius, "", [], _side, DUWS_zoneReserveSpawnDist] call DUWS_fnc_zoneSpawnOne;
        if (!isNull _grp) then { _grps pushBack _grp };
        if (_forEachIndex < (count _tokens) - 1) then { sleep 2 };
    } forEach _tokens;

    // Fall damage from the placement itself: a man raised above his position lands on it hurt, and
    // the damage arrives when he lands rather than when he appears -- checking immediately finds
    // every man whole. Also undoes one shot from a player firing on the spawn, unnoticed at that size.
    sleep 3;
    {
        private _grp = _x;
        { if (alive _x && {damage _x > 0}) then { _x setDamage 0 } } forEach (units _grp);
    } forEach _grps;
    _grps
};

// A token names one vehicle and never a bucket to roll in: a pool weighting four trucks alongside
// three APCs and a tank under the name "armored" once stood a supply truck on an objective roughly
// one armour slot in six. Variety isn't lost with it -- the role column names a faction pool and
// fnc_faction_pick draws from it as each vehicle is placed, so two zones raised in the same second
// still field different APCs.
//
// role -- the faction global holding the classname, named rather than referenced: a faction table
//         that omits a role leaves its global undefined, which an array literal can't test for.
// setting -- a campaign setting that must read 1, or "" for a vehicle nothing gates.
// ap -- earned Army Power (WARCOM_opfor_ap_earned) required, 0 from the start. Mirrors BLUFOR's
//       thresholds so both sides climb one ladder; which token sits on which rung is tuning.
// --DUWS-UNITCOMP BEGIN name="OPFOR vehicles" kind=team row="token, role, setting, ap" fields="token, faction role, campaign setting, AP required" prefix=opfor_--
DUWS_spawnVehicles = [
    ["car",        "opfor_ARMED_CAR1_X",    "",           60],
    ["at_car",     "opfor_ARMED_CAR1_X",    "",           60],
    ["aa_car",     "opfor_ARMED_CAR1_X",    "",           60],
    ["truck",      "opfor_COVERED_TRUCK_X", "",           0],
    ["transport",  "opfor_TRANS_TRUCK_X",   "",           0],
    ["ammo",       "opfor_AMMO_TRUCK_X",    "",           0],
    ["repair",     "opfor_REPAIR_TRUCK_X",  "",           0],
    ["apc",        "opfor_APC1_X",          "",           150],
    ["ifv",        "opfor_APC2_X",          "",           150],
    ["aa",         "opfor_AA_APC_X",        "",           150],
    ["tank",       "opfor_MBT_TANK1_X",     "HeavyArmor", 350],
    ["attackheli", "opfor_ATTACK_HELI_X",   "AttackHeli", 350],
    ["transheli",  "opfor_TRANS_HELI_X",    "AttackHeli", 150],
    ["plane",      "opfor_MISC_AIR_X",      "AttackHeli", 600],
    ["boat",       "opfor_BOAT_ARMED_X",    "",           0]
];
// --DUWS-UNITCOMP END--

// Mirror of DUWS_spawnVehicles, same tokens/rungs resolving to BLUFOR's role globals; only the
// tokens BLUFOR actually raises are listed. No setting column: the asset toggles (HeavyArmor,
// AttackHeli) are the enemy's, BLUFOR answers to the ladder alone.
// transheli resolves to the armed HELI_TRANS_ARM_X; the unarmed TRANS_HELI_X is the taxi left to the
// support functions.
//
// Fenced because a tier row both armies raise needs both tables: a token this one misses resolves to its
// own bare name and reaches createVehicle as a class that does not exist.
// --DUWS-UNITCOMP BEGIN name="BLUFOR vehicles" kind=team row="token, role, setting, ap" fields="token, faction role, campaign setting, AP required" prefix=blufor_--
DUWS_spawnVehiclesBlu = [
    ["truck",      "blufor_COVERED_TRUCK_X",  "", 0],
    ["transport",  "blufor_TRANS_TRUCK_X",    "", 0],
    ["car",        "blufor_ARMED_CAR1_X",     "", 60],
    ["at_car",     "blufor_ARMED_CAR1_X",     "", 60],
    ["aa_car",     "blufor_ARMED_CAR1_X",     "", 60],
    ["apc",        "blufor_APC1_X",           "", 150],
    ["ifv",        "blufor_APC2_X",           "", 150],
    ["tank",       "blufor_MBT_TANK1_X",      "", 350],
    ["transheli",  "blufor_HELI_TRANS_ARM_X", "", 150],
    ["attackheli", "blufor_ATTACK_HELI_X",    "", 350],
    ["plane",      "blufor_MISC_AIR_X",       "", 600]
];
// --DUWS-UNITCOMP END--

DUWS_fnc_vehicleRow = {
    params ["_token", ["_side", "OPF"]];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _table = [DUWS_spawnVehicles, DUWS_spawnVehiclesBlu] select (_side == "BLU");
    private _i = _table findIf { (_x select 0) isEqualTo _name };
    if (_i < 0) then { [] } else { _table select _i }
};

// Gated on the earned counter, not the spendable wallet: a token the side has reached the rung for must
// not relock because the wallet dipped from spending.
DUWS_fnc_tokenLocked = {
    params ["_token", ["_side", "OPF"]];
    private _row = [_token, _side] call DUWS_fnc_vehicleRow;
    if (_row isEqualTo []) exitWith { false };
    private _earnedVar = ["WARCOM_opfor_ap_earned", "WARCOM_blufor_ap_earned"] select (_side == "BLU");
    (missionNamespace getVariable [_earnedVar, 0]) < (_row select 3)
};

// Classifies into [hasGun, hasMissile, hasAirMissile] in one config walk, feeding all three token
// filters below. Gun = bullets/shells/grenades; missile = guided (shotMissile); air missile =
// auto-locks air (airLock >= 2). A magazineWell-only turret reads unarmed -- fail-safe, so a
// borderline hull is dropped rather than fielded as a gunless combatant.
// Memoised: a filtered faction pick walks every class in the pool, and OPCOM's hire roster resolves its
// vehicle rows through it on every pick. Class config is fixed for the session.
DUWS_classArmsMemo = createHashMap;
DUWS_fnc_classArms = {
    params ["_class"];
    private _arms = DUWS_classArmsMemo get _class;
    if (isNil "_arms") then {
        private _guns = ["shotBullet", "shotShell", "shotGrenade", "shotSpread", "shotSubmunitions"];
        private _queue = "true" configClasses (configFile >> "CfgVehicles" >> _class >> "Turrets");
        private _gun = false; private _msl = false; private _air = false;
        while { count _queue > 0 } do {
            private _t = _queue deleteAt 0;
            private _mags = +(getArray (_t >> "magazines"));
            { _mags append (getArray (configFile >> "CfgWeapons" >> _x >> "magazines")) } forEach (getArray (_t >> "weapons"));
            {
                private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
                private _sim = getText (configFile >> "CfgAmmo" >> _ammo >> "simulation");
                if (_sim in _guns) then { _gun = true };
                if (_sim == "shotMissile") then {
                    _msl = true;
                    if (getNumber (configFile >> "CfgAmmo" >> _ammo >> "airLock") >= 2) then { _air = true };
                };
            } forEach _mags;
            _queue append ("true" configClasses (_t >> "Turrets"));
        };
        _arms = [_gun, _msl, _air];
        DUWS_classArmsMemo set [_class, _arms];
    };
    _arms
};

// Disjoint by construction: an air-lock round is itself a shotMissile, so AT excludes _air and AA
// requires it; a gun hull passes neither.
DUWS_fnc_classGroundCapable = { (_this call DUWS_fnc_classArms) select 0 };
DUWS_fnc_classAT = { (_this call DUWS_fnc_classArms) params ["_g", "_m", "_a"]; _m && !_g && !_a };
DUWS_fnc_classAA = { (_this call DUWS_fnc_classArms) params ["_g", "_m", "_a"]; _a && !_g };

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
//
// The tables decide, not a switch: a token in the team roster raises via fnc_spawn_team whatever it
// is called, anything else resolves to a classname and is placed as a vehicle -- so a team or vehicle
// added to a table spawns without a case being written for it.
//
// A token resolving to "" is refused rather than spawned, since the composition should already be
// filtered and spawning "" is a nil vehicle. _postureOverride/_spawnPos are for the reserve path
// alone -- a reserve rides "hunt" orders regardless of its pool token's own posture, and spawns where
// the pass chose on the zone's far side rather than in the token's own radius band.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size", ["_postureOverride", ""], ["_spawnPos", []], ["_side", "OPF"], ["_floor", 0]];
    // The token layer spells a side "OPF"/"BLU" and the placers "opfor"/"blufor"; one boundary, here.
    private _army = ["opfor", "blufor"] select (_side isEqualTo "BLU");
    private _posture = [_token] call DUWS_fnc_tokenPosture;
    // An OPCOM reserve token's prefix is its tasking id, not a posture.
    if ((_token select [0, 8]) == "opcomdef") then { _posture = "closepatrol" };
    if (_postureOverride != "") then { _posture = _postureOverride };
    private _grp = grpNull;
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) then {
        _grp = [_token, _pos, _size, _posture, _spawnPos, _army, [], _floor] call fnc_spawn_team;
    } else {
        private _class = [_token, _side] call DUWS_fnc_tokenClass;
        if (_class == "") exitWith {
            ["WARN", "ZONES", format ["%1 cannot be fielded here and was not filtered out", _token]] call fnc_log;
            grpNull
        };
        _grp = [_class, _pos, _size, _posture, _spawnPos, _army, _floor] call fnc_spawn_vehicle;
    };
    // The source token rides the group so the killed handler can record which composition entry died
    // (DUWS_fnc_garrisonReserveWatch reads it back). A group that failed to field exited above, so a
    // tagged group is always a real one.
    if (!isNull _grp) then { _grp setVariable ["DUWS_srcToken", _token] };
    _grp
};

// Only patrol-posture tokens (widepatrol/closepatrol) are thinned by garrison_density; dug-in
// garrison-posture tokens always stand, so a lower density thins the screen without abandoning the
// strongpoint. Trimmed patrols fall to the reserve pool rather than vanish, lowering the group
// ceiling so even a x1 site reinforces back up to the reduced count. Thinned evenly across the
// patrols rather than off the tail, so the standing force keeps the composition's mix instead of
// shedding every vehicle first.
DUWS_fnc_zoneDensityStand = {
	params ["_x1"];
	private _d = ((missionNamespace getVariable ["garrison_density", 1]) max 0) min 1;
	if (_d >= 1) exitWith { +_x1 };
	private _patrolN = { ([_x] call DUWS_fnc_tokenPosture) != "garrison" } count _x1;
	if (_patrolN == 0) exitWith { +_x1 };
	private _keepN = ((round (_d * _patrolN)) max 1); // never thin the screen to nothing
	private _stand = [];
	private _p = 0;
	{
		if (([_x] call DUWS_fnc_tokenPosture) == "garrison") then {
			_stand pushBack _x;
		} else {
			// Keep when the running keep-count steps past the last index: keepN kept, evenly spread.
			if ((floor ((_p + 1) * _keepN / _patrolN)) > (floor (_p * _keepN / _patrolN))) then {
				_stand pushBack _x;
			};
			_p = _p + 1;
		};
	} forEach _x1;
	_stand
};

// Nothing guards a stale cycle here: the calling raise worker holds the raise flag for the whole
// placement, and won't start a second one or tear the zone down until this reports.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _tier = [_zoneKey] call fnc_zone_tier;
    private _side = [_zoneKey] call DUWS_fnc_garrisonSideOf;
    private _x1 = [_tier, _side] call DUWS_fnc_zoneSpawnList;
    if (_x1 isEqualTo []) exitWith {
        ["ERROR", "ZONES", format ["tier %1 fields nothing this side can raise, so %2 stands empty",
            _tier, _zoneKey]] call fnc_log;
    };

    // Reserve depth: mult copies of x1 make the zone's full fighting potential, not what stands up at
    // once. The ledger derives what survives (full minus every token lost across visits) and splits it
    // by the standing template -- its worth stands as the garrison, the surplus waits as reserve, so a
    // lost token comes out of the pool before it thins the garrison. Reseeded every raise from the
    // ledger: the pool is per-awake-session, the losses behind it persist.
    private _spawns = [_zoneKey, [_zoneKey, _x1] call DUWS_fnc_garrisonRestand] call DUWS_fnc_garrisonStandFill;

    private _grps = [_spawns, _spawnPos, _size, _side] call DUWS_fnc_raiseGarrison;
    { _roster append (units _x) } forEach _grps;
    [_zoneKey, _spawns, _grps] call DUWS_fnc_garrisonRefundUnplaced;
    [_zoneKey, _grps] call DUWS_fnc_garrisonReserveWatch;

    // Live/mobilised flags let the capture test judge the zone and the reserve pass top it up; cleared
    // by the stow or capture that walks the garrison off (fnc_zone_garrison_dropped). The capture test
    // measures against the ledger's full potential, fixed across visits, so a garrison that comes back
    // mauled is still judged against the whole.
    [_zoneKey, true] call DUWS_fnc_garrisonSetLive;
    missionNamespace setVariable [format ["DUWS_zoneMobilising_%1", _zoneKey], nil];
    private _placed = [_zoneKey] call fnc_site_alive;
    ["INFO", "ZONES", format ["%1 deployed %2 %3 men (%4 groups) at tier %5, %6 strength; full %7 tokens, reserve pool %8",
        _zoneKey, _placed, _side, count _grps, _tier, [_zoneKey] call fnc_zone_strength, count ([_zoneKey] call DUWS_fnc_garrisonFull), count ([_zoneKey] call DUWS_fnc_garrisonReserve)]] call fnc_log;
};
