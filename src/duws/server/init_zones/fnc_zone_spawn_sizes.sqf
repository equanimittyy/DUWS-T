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
// Zones and towns keep separate composition sets -- a town garrison must not field what a zone does,
// or the two stop reading differently on the ground -- but share the token vocabulary, the tables
// and the spawner here, so a new team or vehicle is added in one place rather than two.

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
    ["closepatrol:patrol", "closepatrol:patrol", "closepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:wp_team", "closepatrol:car"],
    ["closepatrol:patrol", "closepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:wp_team", "widepatrol:wp_team", "closepatrol:car", "closepatrol:apc", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element"],
    ["closepatrol:sniper_element", "closepatrol:sniper_element", "closepatrol:patrol", "closepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:wp_team", "widepatrol:wp_team", "closepatrol:car", "closepatrol:apc", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element"],
    ["closepatrol:sniper_element", "closepatrol:sniper_element", "closepatrol:patrol", "closepatrol:patrol", "closepatrol:patrol", "closepatrol:patrol", "closepatrol:team", "closepatrol:team", "widepatrol:wp_team", "widepatrol:wp_team", "closepatrol:car", "closepatrol:tank", "closepatrol:attackheli", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element", "garrison:garrison_element"]
];
// --DUWS-UNITCOMP END--

// A zone's spawn list: its tier composition, less whatever this side cannot field right now, times
// the campaign's enemy multiplier. The tier is passed rather than read, so the pick is testable
// against a stand-in tier rather than against zone state.
//
// Neither radius nor player count enters into it. A zone is its tier -- one lever the player can see
// and the commander can spend against. The multiplier is a second lever, but the player set it once
// at start and it reads the same at every zone, so it cannot make two tier IVs differ.
DUWS_fnc_zoneSpawnList = {
    params ["_tier"];
    private _t = (((round _tier) max 1) min (count DUWS_zoneSpawnTiers)) - 1;
    [[DUWS_zoneSpawnTiers select _t] call DUWS_fnc_spawnFilter,
        missionNamespace getVariable ["enemyunitMultiplier", 1]] call DUWS_fnc_scaleComposition
};

// Drops the tokens this side cannot field right now. Three separate reasons, one answer: the token
// leaves the composition and nothing takes its place.
//
// Substituting is what this replaces and it was never chosen -- it was the shape of an `if` leaking.
// An air slot with attack helicopters switched off fell through to the general vehicle pool, so a
// player who asked for no helicopters got an extra truck per slot instead of a quieter zone.
//
// Runs before the strength thin: filtering first thins the force the side can actually field, where
// thinning first reduces a composition and then reduces it again.
DUWS_fnc_spawnFilter = {
    params ["_tokens"];
    _tokens select { ([_x] call DUWS_fnc_tokenClass) != "" }
};

// The enemy multiplier, applied to the composition rather than inside a roster. A x3 zone fields
// three patrols where it fielded one, instead of one patrol of six men.
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

// What attrition does to one token. A composition entry is not a unit -- "patrol" is two men, "team"
// is five, "car" is a vehicle -- so dropping entries at random meant two zones reported at the same
// strength could differ by twenty men, and the bar the readout draws did not mean what it said.
// Attrition is a fraction of *men*, and every token carries its own share of it.
//
// Two answers, and which one a token gets is what it is made of rather than which system raised it:
//
//   _strength  a team, which drops men and keeps its leader. A garrison slot is a team too, so a
//              worn zone holds the same buildings with fewer men in each rather than fewer
//              buildings: one squad to one structure, however thin the squad has become.
//   0 or 1     a vehicle, whole or not at all. There is no partial vehicle -- a crew short of a
//              driver is a wreck the player walks past -- so a zone ground below half stops
//              fielding them, which is one rule a player can learn.
DUWS_fnc_tokenStrength = {
    params ["_token", ["_strength", 1]];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith { _strength };
    [0, 1] select (_strength >= 0.5)
};

// The composition a site actually raises: every token that still places something. Nothing is
// dropped at random here -- the tokens that survive are the same ones at the same strength every
// time, so a zone the player wore down comes back as the zone they wore down.
DUWS_fnc_thinComposition = {
    params ["_tokens", ["_strength", 1]];
    _tokens select { ([_x, _strength] call DUWS_fnc_tokenStrength) > 0 }
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
    [_role] call fnc_faction_pick
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

// Raises a token list and hands back the groups it made, in order. The one place a composition
// becomes men, shared by the zone band and the town garrison: the stagger and the search flag are
// rules about raising a garrison, not about which kind of ground is raising one.
//
// Staggered, not batched: each token raises a group, and firing a whole composition in one frame is
// what the per-call sleep this replaces existed to avoid. None after the last.
//
// Returns groups rather than appending to a caller's roster, so a caller that keeps one appends
// after. Nothing reads a zone's roster meaningfully while its band is still placing -- the capture
// test refuses on the missing peak, and the peak is taken after this returns.
DUWS_fnc_raiseGarrison = {
    params ["_tokens", "_pos", "_radius", ["_strength", 1]];
    private _grps = [];
    {
        // Attrition reaches every token here, as its own share of the fraction, rather than by
        // taking entries out of the list before it arrives.
        private _tokenStrength = [_x, _strength] call DUWS_fnc_tokenStrength;

        private _grp = [_x, _pos, _radius, _tokenStrength] call DUWS_fnc_zoneSpawnOne;
        if (!isNull _grp) then {
            // Flagged where the group is raised, so the two cannot drift: every spawner here already
            // carried the loot pass and none of them carried this one, which once left the 50 %
            // garrison rate firing on side-mission garrisons and nowhere else.
            [_grp, "garrison"] call fnc_search_flag_group;
            _grps pushBack _grp;
        };
        if (_forEachIndex < (count _tokens) - 1) then { sleep 5 };
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
// A token names one vehicle and never a bucket to roll in. The pool this replaces weighted four
// trucks alongside three APCs and a tank under the name "armored", so roughly one armour slot in six
// stood a supply truck on an objective. Variety is not lost with it: the role below names a faction
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

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
//
// The tables decide, not a switch: a token the team roster claims is a team and fnc_spawn_team
// raises it whatever it is called; anything else resolves to a classname and is placed as a vehicle.
// A team or a vehicle added to a table spawns without a case being written for it.
//
// A token whose class resolves to "" is refused rather than spawned. The composition was filtered
// before it got here, so this is a caller that skipped the filter, and spawning "" is a nil vehicle.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size", ["_strength", 1]];
    private _posture = [_token] call DUWS_fnc_tokenPosture;
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        [_token, _pos, _size, _strength, _posture] call fnc_spawn_team
    };
    private _class = [_token] call DUWS_fnc_tokenClass;
    if (_class == "") exitWith {
        ["WARN", "ZONES", format ["%1 cannot be fielded here and was not filtered out", _token]] call fnc_log;
        grpNull
    };
    [_class, _pos, _size, _posture] call fnc_spawn_vehicle
};

// Called by the zone raise worker, which owns the streaming decisions around it. Nothing guards a
// stale cycle here any more: the worker holds the raise flag for the whole placement, and the tick
// that set it will not start a second one or tear the zone down until it reports.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _tier = [_zoneKey] call fnc_zone_tier;
    private _spawns = [_tier] call DUWS_fnc_zoneSpawnList;
    if (_spawns isEqualTo []) exitWith {
        ["ERROR", "ZONES", format ["tier %1 fields nothing this side can raise, so %2 stands empty",
            _tier, _zoneKey]] call fnc_log;
    };

    // The composition is what the zone fields intact; it deploys at whatever its garrison was ground
    // down to. Without this, breaking a garrison and leaving buys the player nothing -- the same
    // fight is waiting at full strength when they come back.
    //
    // The list only loses what a fraction cannot place at all; everything else carries the fraction
    // into the raise and fields its own reduced share.
    private _strength = [_zoneKey] call fnc_zone_strength;
    _spawns = [_spawns, _strength] call DUWS_fnc_thinComposition;

    { _roster append (units _x) } forEach ([_spawns, _spawnPos, _size, _strength] call DUWS_fnc_raiseGarrison);

    // The strength fnc_zone_capture_ready judges this zone against, and the only place it is set.
    // fnc_zone_garrison_dropped is the only place it is cleared, and states the contract binding
    // the two.
    //
    // Anchored to the men this zone's first completed cycle placed, not to what just deployed: a
    // garrison that comes back at six tenths is still measured against the ten, so the men killed
    // last visit stay killed. Re-basing the peak on the reduced garrison would restore the whole
    // 80%-to-beat every time the zone streamed out, which is the refund attrition exists to stop.
    private _placed = [_zoneKey] call fnc_zone_garrison_count;
    private _baseVar = format ["DUWS_zoneBase_%1", _zoneKey];
    private _baseline = missionNamespace getVariable [_baseVar, 0];
    if (_baseline <= 0) then {
        _baseline = _placed;
        missionNamespace setVariable [_baseVar, _baseline];
    };
    missionNamespace setVariable [format ["DUWS_zonePeak_%1", _zoneKey], _baseline];
    // Men are standing, so the zone has finished mobilising. Cleared beside the peak rather than at
    // the head of the spawn, because the peak is the point at which the garrison is real -- a band
    // still placing has neither, and a torn-down one exits above without publishing either.
    missionNamespace setVariable [format ["DUWS_zoneMobilising_%1", _zoneKey], nil];
    ["INFO", "ZONES", format ["%1 deployed %2 men at tier %3, %4 strength; garrison peak %5",
        _zoneKey, _placed, _tier, [_zoneKey] call fnc_zone_strength, _baseline]] call fnc_log;
};
