// Locality: server -- spawned once from server/server_init.sqf to publish the tables below.
//
// The OPFOR spawn composition framework, shared by zones and by town garrisons. A token names a row
// in DUWS_teamRosters (a team) or in DUWS_spawnVehicles (a vehicle). A token neither table claims is
// a vehicle classname a faction file named directly, and spawns as itself.
//
// The token grammar and the team table are shared/functions/fnc_spawn_vocab: both armies raise teams
// out of them, and that file loads early enough to price the BLUFOR squad catalogue. What is here is
// OPFOR's -- the vehicles and the tiers that name them.
//
// Zones and towns keep separate composition sets so the two can diverge -- a town fields a zone
// tier's infantry but none of its heavy armour or air, which is what keeps the two reading
// differently on the ground -- but share the token vocabulary, the tables and the spawner here, so
// a new team or vehicle is added in one place rather than two.

// What a zone of each tier fields, indexed tier-1. Absolute, not cumulative: a tier is the whole
// garrison, so what a tier IV zone is can be read off one row instead of assembled from four.
//
// Every entry is one A3 group: a posture and the team standing up under it. A duplicated entry is
// how a tier fields two of something -- which is why the infantry lines repeat rather than carrying
// a count, and it is the same shape the enemy multiplier writes in at spawn.
//
// Radius reaches none of this: a zone is its tier, and the ground it holds only decides how far the
// same men are spread. Scaling a composition by radius puts two zones the map reports at the same
// tier on the ground at different strengths, for a reason the player cannot read off either.
//
// Tier therefore carries the whole spread, and the dug-in half is where it is carried: garrison
// slots climb from none at tier I to six at tier IV, so the lightest zone is all mobile and only the
// heavier ones dig in. A flat count on every row leaves a tier I zone and a tier IV zone far closer
// than the rest of their rows suggest.
// --DUWS-UNITCOMP BEGIN name="Zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:team", "closepatrol:wp_team", "widepatrol:car"],
    ["widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:car", "widepatrol:car", "closepatrol:apc", "garrison:garrison_element", "garrison:garrison_element"],
    ["widepatrol:sniper_element", "widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:wp_team", "widepatrol:car", "widepatrol:car", "closepatrol:apc", "closepatrol:ifv", "closepatrol:tank", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element"],
    ["widepatrol:sniper_element", "widepatrol:sniper_element", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "widepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:team", "widepatrol:team", "closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:wp_team", "widepatrol:wp_team", "widepatrol:car", "widepatrol:car", "widepatrol:car", "closepatrol:apc", "closepatrol:ifv", "closepatrol:ifv", "closepatrol:tank", "closepatrol:tank", "widepatrol:attackheli", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element"]
];
// --DUWS-UNITCOMP END--

// A zone's spawn list: its tier composition, less whatever this side cannot field right now. The x1
// garrison and nothing more -- the enemy multiplier no longer scales what stands on the ground. It is
// reserve depth now, applied in fnc_zone_spawn: the initial garrison is always this list, and the
// surplus (mult-1) copies of it become the zone's reserve pool. The tier is passed rather than read,
// so the pick is testable against a stand-in tier rather than against zone state.
//
// Neither radius nor player count enters into it. A zone is its tier -- one lever the player can see
// and the commander can spend against.
DUWS_fnc_zoneSpawnList = {
    params ["_tier"];
    private _t = (((round _tier) max 1) min (count DUWS_zoneSpawnTiers)) - 1;
    [DUWS_zoneSpawnTiers select _t] call DUWS_fnc_spawnFilter
};

// Drops the tokens this side cannot field right now. Three separate reasons, one answer: the token
// leaves the composition and nothing takes its place.
//
// Dropped, not substituted: substituting was never a choice, only the shape of an `if` leaking --
// an air slot with attack helicopters switched off fell through to the general vehicle pool, so a
// player who asked for no helicopters got an extra truck per slot instead of a quieter zone.
//
// Runs before the strength thin: filtering first thins the force the side can actually field, where
// thinning first reduces a composition and then reduces it again.
DUWS_fnc_spawnFilter = {
    params ["_tokens"];
    _tokens select { ([_x] call DUWS_fnc_tokenClass) != "" }
};

// The enemy multiplier, applied to a composition rather than inside a roster. A x3 town garrison
// fields three patrols where it fielded one, instead of one patrol of six men. Town garrisons alone
// call this now: a zone turns the same multiplier into reserve depth (fnc_zone_spawn) rather than
// putting the extra copies on the ground at once, so this no longer sits on the zone spawn path.
//
// Scaling men was the older shape and it cost two roster columns to express: a "core" the multiplier
// repeated and a "tail" added once, so a x3 setting fielded one marksman rather than three. It also
// made a group's size a campaign setting, which the player reads as one enormous fire team rather
// than as more of them, and left a squad's leader outnumbered by his own automatic riflemen.
//
// Runs after the filter and before the thin: duplicating a token the side cannot field would
// multiply nothing, and attrition has to reduce the force that is actually going to stand up.
DUWS_fnc_scaleComposition = {
    params ["_tokens", ["_mult", 1]];
    private _n = ((round _mult) max 1);
    if (_n <= 1) exitWith { +_tokens };
    private _out = [];
    { for "_k" from 1 to _n do { _out pushBack _x } } forEach _tokens;
    _out
};

// The classname behind a token, or "" when it cannot be fielded. A team is not this function's
// business and answers itself -- fnc_factionRoles already drops the roles a faction leaves undefined.
DUWS_fnc_tokenClass = {
    params ["_token", ["_side", "OPF"]];
    // The posture goes here rather than downstream: the passthrough below hands its answer to
    // fnc_spawn_vehicle as a classname, and "closepatrol:O_MBT_02_cannon_F" is not one.
    private _name = [_token] call DUWS_fnc_tokenName;
    if !(([_name] call DUWS_fnc_teamRow) isEqualTo []) exitWith { _name };
    private _row = [_name, _side] call DUWS_fnc_vehicleRow;
    // Not in either table: a faction file named a classname directly, and it stands as itself.
    if (_row isEqualTo []) exitWith { _name };
    _row params ["", "_role", "_setting", "_ap"];
    // Missing setting defaults to on: a campaign that predates a new rule fields what it always did
    // rather than quietly losing the token.
    if (_setting != "" && {(missionNamespace getVariable [_setting, 1]) != 1}) exitWith { "" };
    // Gated on the earned counter for the side raising the token, not the spendable wallet: a
    // commander draws its wallet down as it buys, and a token the side has reached the tier for must
    // not vanish because the wallet dipped.
    private _earnedVar = ["WARCOM_opfor_ap_earned", "WARCOM_blufor_ap_earned"] select (_side == "BLU");
    if (_ap > 0 && {(missionNamespace getVariable [_earnedVar, 0]) < _ap}) exitWith { "" };
    // Drawn per spawn, not held as one value the whole campaign fields at once: two zones raised in
    // the same second should not both put down the identical APC.
    //
    // Each combat token filters its pool by armament (the predicates above): car/apc/ifv/tank keep a gun
    // hull -- a missile-only one parks at range and duels from spawn instead of taking the objective --
    // while at_car/aa_car take the gunless AT/AA hulls car drops. "" when nothing in the pool matches, so
    // fnc_zoneSpawnList / fnc_spawnFilter drop the token.
    private _filter = switch true do {
        case (_name in ["car", "apc", "ifv", "tank"]): { DUWS_fnc_classGroundCapable };
        case (_name == "at_car"):                      { DUWS_fnc_classAT };
        case (_name == "aa_car"):                      { DUWS_fnc_classAA };
        default                                        { [] };
    };
    [_role, _filter] call fnc_faction_pick
};

// What is missing from _have to make it _want, counting duplicates: two patrols wanted against one
// already standing yields one patrol. This is what makes absolute composition lists workable for a
// garrison that can be upgraded mid-fight -- reinforcement raises the difference and lands beside
// the survivors, where re-raising the whole list would double the town.
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

// Raises a token list to groups, in order, for both the zone band and a town garrison. Staggered
// (per-token sleep) so a whole composition never spawns in one frame. Returns the groups rather than
// appending: safe because nothing reads a zone's roster mid-place -- the capture test refuses until the
// garrison is flagged live, which happens after this returns.
DUWS_fnc_raiseGarrison = {
    params ["_tokens", "_pos", "_radius"];
    private _grps = [];
    {
        private _grp = [_x, _pos, _radius] call DUWS_fnc_zoneSpawnOne;
        if (!isNull _grp) then { _grps pushBack _grp };
        if (_forEachIndex < (count _tokens) - 1) then { sleep 2 };
    } forEach _tokens;

    // Fall damage from the placement itself, not from anything the zone chose: a man raised above his
    // position lands on it hurt. Read after a pause, because the damage arrives when he lands rather
    // than when he appears -- a pass run the instant the last group returns finds every man whole.
    // One shot from a player firing on the spawn is undone with it, and goes unnoticed at that size.
    sleep 3;
    {
        private _grp = _x;
        { if (alive _x && {damage _x > 0}) then { _x setDamage 0 } } forEach (units _grp);
    } forEach _grps;
    _grps
};

// Every vehicle the OPFOR side fields, one row each, in the same shape as a team's: what it is
// called, what it fields, and what it requires.
//
// A token names one vehicle and never a bucket to roll in: a pool weighting four trucks alongside
// three APCs and a tank under the name "armored" stood a supply truck on an objective roughly one
// armour slot in six. Variety is not lost with it: the role below names a faction
// pool, and fnc_faction_pick draws from that pool as each vehicle is placed, so two zones raised in
// the same second field different APCs. What goes is the randomness no table could see -- a bucket
// the composition named but could not describe.
//
// role -- the faction global holding the classname, named rather than referenced: a faction table
//         that omits a role leaves its global undefined, and an undefined name inside an array
//         literal is not something the spawner can test for afterwards.
// setting -- a campaign setting that must read 1, or "" for a vehicle nothing gates.
// ap -- the earned Army Power (WARCOM_opfor_ap_earned) the OPFOR side must have reached, 0 for a
//       vehicle available from the start. These mirror BLUFOR's wave/vehicle thresholds so both sides
//       climb one honest ladder; which token hangs off which rung is a balance decision, and tuning.
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
    ["plane",      "opfor_MISC_AIR_X",      "AttackHeli", 600]
];
// --DUWS-UNITCOMP END--

// BLUFOR's vehicles: the mirror of the table above -- the same tokens and the same rungs, resolving
// to BLUFOR's own role globals. BLUFOR fields a smaller set than OPFOR (it defines no truck, ammo or
// AA roles of its own), so only the tokens it actually raises are listed. No setting column gates
// these: the asset toggles (HeavyArmor, AttackHeli) are the enemy's, and BLUFOR air and armour answer
// to the ladder alone. Kept in lockstep with DUWS_spawnVehicles by hand -- the rungs are shared.
// transheli resolves to the armed transport HELI_TRANS_ARM_X, the combat bird; the unarmed
// TRANS_HELI_X is the taxi the support functions fly and is left to them.
DUWS_spawnVehiclesBlu = [
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

DUWS_fnc_vehicleRow = {
    params ["_token", ["_side", "OPF"]];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _table = [DUWS_spawnVehicles, DUWS_spawnVehiclesBlu] select (_side == "BLU");
    private _i = _table findIf { (_x select 0) isEqualTo _name };
    if (_i < 0) then { [] } else { _table select _i }
};

// A vehicle's turret armament, walked once into [hasGun, hasMissile, hasAirMissile]: a gun fires
// bullets/shells/grenades, a missile is guided (shotMissile), an air missile auto-locks air
// (airLock >= 2). One walk feeds all three token filters below. A magazineWell-only turret resolves no
// ammo and reads unarmed -- fail-safe: it drops a borderline hull rather than field a gunless combatant.
DUWS_fnc_classArms = {
    params ["_class"];
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
    [_gun, _msl, _air]
};

// Token pool filters over those flags: classGroundCapable keeps a gun hull for car/apc/ifv/tank, classAT
// and classAA the gunless dedicated AT and AA hulls. Disjoint by construction -- an air-lock round is
// itself a shotMissile, so AT excludes _air and AA requires it; a gun hull passes neither.
DUWS_fnc_classGroundCapable = { (_this call DUWS_fnc_classArms) select 0 };
DUWS_fnc_classAT = { (_this call DUWS_fnc_classArms) params ["_g", "_m", "_a"]; _m && !_g && !_a };
DUWS_fnc_classAA = { (_this call DUWS_fnc_classArms) params ["_g", "_m", "_a"]; _a && !_g };

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
//
// The tables decide, not a switch: a token the team roster claims is a team and fnc_spawn_team
// raises it whatever it is called; anything else resolves to a classname and is placed as a vehicle.
// A team or a vehicle added to a table spawns without a case being written for it.
//
// A token whose class resolves to "" is refused rather than spawned: the composition should already be
// filtered, so this is a caller that skipped it, and spawning "" is a nil vehicle. _postureOverride and
// _spawnPos belong to the reserve path alone -- a reserve rides the "hunt" orders regardless of its
// pool token's own posture, and spawns where the pass chose on the zone's far side rather than in the
// token's own radius band. Empty defaults leave the ordinary garrison path untouched.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size", ["_postureOverride", ""], ["_spawnPos", []]];
    private _posture = [_token] call DUWS_fnc_tokenPosture;
    if (_postureOverride != "") then { _posture = _postureOverride };
    private _grp = grpNull;
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) then {
        _grp = [_token, _pos, _size, _posture, _spawnPos] call fnc_spawn_team;
    } else {
        private _class = [_token] call DUWS_fnc_tokenClass;
        if (_class == "") exitWith {
            ["WARN", "ZONES", format ["%1 cannot be fielded here and was not filtered out", _token]] call fnc_log;
            grpNull
        };
        _grp = [_class, _pos, _size, _posture, _spawnPos] call fnc_spawn_vehicle;
    };
    // The source token rides the group so the killed handler can record which composition entry died
    // (DUWS_fnc_garrisonReserveWatch reads it back and copies it to each unit). A vehicle that failed to
    // field left through the exit above, so a tagged group is always a real one.
    if (!isNull _grp) then { _grp setVariable ["DUWS_srcToken", _token] };
    _grp
};

// The standing garrison a zone or town fields at once, thinned to garrison_density of its mobile tokens.
// Only patrol-posture tokens (widepatrol/closepatrol) are held back; dug-in garrison-posture tokens
// always stand, so a lower density thins the screen without abandoning the strongpoint. The trimmed
// patrols fall to the reserve pool and lower the group ceiling, so even a x1 site reinforces back up to
// this reduced count as its patrols are killed. Thinned evenly across the patrols rather than off the tail,
// so the standing force keeps the composition's mix instead of shedding every vehicle first. Density 1
// (the default) returns x1 unchanged and the whole feature stays inert.
DUWS_fnc_zoneDensityStand = {
	params ["_x1"];
	private _d = ((missionNamespace getVariable ["garrison_density", 1]) max 0) min 1;
	if (_d >= 1) exitWith { +_x1 };
	private _patrolN = { ([_x] call DUWS_fnc_tokenPosture) != "garrison" } count _x1;
	if (_patrolN == 0) exitWith { +_x1 };            // an all-static garrison has nothing to thin
	private _keepN = ((round (_d * _patrolN)) max 1); // never thin the screen to nothing
	private _stand = [];
	private _p = 0;
	{
		if (([_x] call DUWS_fnc_tokenPosture) == "garrison") then {
			_stand pushBack _x;
		} else {
			// Keep this patrol when the running keep-count steps past the last: keepN kept, evenly spread.
			if ((floor ((_p + 1) * _keepN / _patrolN)) > (floor (_p * _keepN / _patrolN))) then {
				_stand pushBack _x;
			};
			_p = _p + 1;
		};
	} forEach _x1;
	_stand
};

// Called by the zone raise worker, which owns the streaming decisions around it. Nothing guards a
// stale cycle here any more: the worker holds the raise flag for the whole placement, and the tick
// that set it will not start a second one or tear the zone down until it reports.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _tier = [_zoneKey] call fnc_zone_tier;
    private _x1 = [_tier] call DUWS_fnc_zoneSpawnList;
    if (_x1 isEqualTo []) exitWith {
        ["ERROR", "ZONES", format ["tier %1 fields nothing this side can raise, so %2 stands empty",
            _tier, _zoneKey]] call fnc_log;
    };

    // Reserve depth: the multiplier is how many copies of the x1 list make up the zone's full fighting
    // potential, not how many stand up at once. Stamp that full potential, then let the ledger say what
    // survives -- full minus the tokens the zone has lost across every visit. The survivors split by the
    // standing template: its worth stands up as the garrison, the surplus waits as the reserve pool, so
    // a lost token comes out of the pool before it thins the garrison. Reseeded every raise from the
    // ledger, so the pool is per-awake-session while the losses behind it persist.
    //
    // Garrison density thins the standing template below the full x1 (patrols only), deepening the pool
    // so even a x1 zone holds a reserve; full potential is unchanged, so density defers force not removes it.
    private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
    private _stand = [_x1] call DUWS_fnc_zoneDensityStand;
    ([_zoneKey, _x1, _mult, _stand] call DUWS_fnc_garrisonDerive) params ["_spawns", "_pool"];

    private _grps = [_spawns, _spawnPos, _size] call DUWS_fnc_raiseGarrison;
    { _roster append (units _x) } forEach _grps;

    // The group ceiling the refill tops up to: the standing template's count, not the count that just
    // deployed. A zone raised mauled stands up fewer groups (its lost tokens are simply absent), and
    // reserves exist precisely to bring it back to this ceiling -- so it is what a full standing garrison
    // is, and the pool refills toward it. Density-thinned (patrols held back) and filtered (a token the
    // side cannot yet field is not a slot the refill chases forever); per awake session, since both the
    // density stand and the filter can change between raises as OPFOR earns AP. The killed handler watches
    // the deployed groups (and any reserve that later joins them) so a deep dip pulls an immediate wave,
    // and records each wiped group's token into the ledger.
    missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _zoneKey], count _stand];
    [_zoneKey, _grps] call DUWS_fnc_garrisonReserveWatch;

    // Live and mobilised: men are standing, so the capture test may judge the zone and the reserve pass
    // may top it up. Cleared by the stow or capture that walks the garrison off (fnc_zone_garrison_dropped).
    // The men the capture test measures against are the ledger's full potential (DUWS_fnc_garrisonFullMen,
    // stamped above), fixed across visits -- so a garrison that comes back mauled is still judged against
    // the whole, and the men killed last visit stay killed because they stay in the ledger, not because a
    // peak was anchored to them.
    [_zoneKey, true] call DUWS_fnc_garrisonSetLive;
    missionNamespace setVariable [format ["DUWS_zoneMobilising_%1", _zoneKey], nil];
    private _placed = [_zoneKey] call fnc_zone_garrison_count;
    ["INFO", "ZONES", format ["%1 deployed %2 men (%3 groups) at tier %4, %5 strength; full %6 men, reserve pool %7",
        _zoneKey, _placed, count _grps, _tier, [_zoneKey] call fnc_zone_strength, [_zoneKey] call DUWS_fnc_garrisonFullMen, count _pool]] call fnc_log;
};
