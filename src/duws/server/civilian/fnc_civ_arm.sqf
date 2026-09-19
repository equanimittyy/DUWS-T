// Locality: server. Arms civ-costume or bandit bodies with a loadout from the detected-faction gear pools,
// and optionally flips them to a hostile cell. Shared by the safehouse raid, angry mob, informant flee,
// protect-civ protectee and bandits.
//
// isHostile is the exemption fnc_civ_handler checks: without it a civ-body kill still bills a civilian
// death after the body joins EAST. Weapons chamber via addWeaponItem so a pocketless costume still fires
// the loaded round.
//
// Contract: [_units, _side, _pool, _spec, _opts] -> _group (grpNull when not flipping / none alive)
//   _side  "EAST"|"WEST"|"IND" -- group side a hostile flip joins; decoupled from _pool, so an IND cell
//          can carry OPFOR kit. Ignored when not flipping.
//   _pool  "opfor"|"blufor", or an array of both -- which factions' weapon/vest/backpack pools to draw from.
//   _spec  tokens, gear before weapons:
//            weapons pistol|submachinegun|assault_rifle|machinegun|sniper -- one of that
//              BIS_fnc_itemType subcategory from the pool; launcher -- an AT tube, never AA;
//              grenadier -- a rifle with an underbarrel GL, both muzzles loaded; a plain rifle when the
//              pool has none. Chambered + spares.
//            vest / civ_backpack / backpack -- from the matching pool, the lowest 3 by armour/capacity.
//            medic -- Medikit and first aid kits, and the Medic trait.
//          A nested array is "pick one of these", e.g. ["vest", ["submachinegun","assault_rifle"], "pistol"];
//          "NONE" in a set is an empty chance, so ["submachinegun","NONE"] gives an SMG or nothing.
//   _opts  [_hostile, _skill, _stance, _mags]: flip on/off; six aim-skills to _skill (-1 = leave);
//            setUnitPos _stance ("" = leave); _mags spare magazines (default 3).
if (!isServer) exitWith { grpNull };
params ["_units", ["_side", "EAST"], ["_pool", "opfor"], ["_spec", ["pistol"]], ["_opts", []]];
_opts params [["_hostile", false], ["_skill", -1], ["_stance", ""], ["_mags", 3]];
_units = _units select { alive _x };
if (_units isEqualTo []) exitWith { grpNull };

private _sideObj = switch (toUpper _side) do {
    case "WEST": { WEST };
    case "IND";
    case "GUER";
    case "INDEPENDENT": { INDEPENDENT };
    default { EAST };
};
private _prefixes = if (_pool isEqualType "") then { [_pool] } else { _pool };
private _union = {
    params ["_suffix"];
    private _all = [];
    { _all append (missionNamespace getVariable [toLower _x + _suffix, []]) } forEach _prefixes;
    _all
};

// Any pool may be empty on a stripped faction -- the per-slot fallbacks below cover that.
private _weaponPool = ["_ammobox_weapons"] call _union;
private _vestPool   = ["_vests"] call _union;
private _sideBags   = ["_backpacks"] call _union;
private _civBags    = missionNamespace getVariable ["DUWS_civBackpacks", []];

private _isSubcat = { params ["_w", "_sub"]; ((_w call BIS_fnc_itemType) select 1) == _sub };
private _weaponMatch = createHashMapFromArray [
    ["pistol",        { [_this, "Handgun"] call _isSubcat }],
    ["submachinegun", { [_this, "SubmachineGun"] call _isSubcat }],
    ["assault_rifle", { [_this, "AssaultRifle"] call _isSubcat }],
    ["machinegun",    { [_this, "MachineGun"] call _isSubcat }],
    ["sniper",        { [_this, "SniperRifle"] call _isSubcat }],
    // Not a subcategory: BIS_fnc_itemType files a tube under Launcher, MissileLauncher or RocketLauncher by class.
    ["launcher",      { !(_this call fnc_IsAA) && {_this call fnc_IsAT} }],
    ["grenadier",     { _this call fnc_IsGrenadier }]
];

// Raise the scalar armour by the max HitpointsProtectionInfo child: chest/body carry the real number
// where the top-level ItemInfo>>armor reads 0.
private _vestArmor = {
    params ["_v"];
    private _ii = configFile >> "CfgWeapons" >> _v >> "ItemInfo";
    private _a = getNumber (_ii >> "armor");
    private _hp = _ii >> "HitpointsProtectionInfo";
    if (isClass _hp) then { { _a = _a max (getNumber (_x >> "armor")) } forEach ("true" configClasses _hp) };
    _a
};
private _capOf = { params ["_cc"]; getNumber (configFile >> "CfgVehicles" >> _cc >> "maximumLoad") };
private _vestScore = {
    params ["_v"];
    private _cc = getText (configFile >> "CfgWeapons" >> _v >> "ItemInfo" >> "containerClass");
    ((_v call _vestArmor) * 10000) + (_cc call _capOf)   // armour primary, capacity tiebreak
};
private _bagScore = { params ["_b"]; _b call _capOf };

// Lowest N by the scorer, then random among them -- picks light armour / small capacity by design.
private _lowPick = {
    params ["_pool", "_scorer", ["_n", 3]];
    if (_pool isEqualTo []) exitWith { "" };
    private _scored = _pool apply { [_x call _scorer, _x] };
    _scored sort true;
    (selectRandom (_scored select [0, _n min count _scored])) select 1
};
private _addBag = {
    params ["_u"];
    private _b = [_sideBags, _bagScore] call _lowPick;
    if (_b isEqualTo "") then { _b = [_civBags, _bagScore] call _lowPick };
    if !(_b isEqualTo "") then { _u addBackpackGlobal _b };
};

private _newGrp = grpNull;
if (_hostile) then { _newGrp = createGroup [_sideObj, true] };
private _skills = ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "general"];

{
    private _u = _x;
    if (_hostile) then {
        _u setVariable ["isHostile", true];
        _u setCaptive false;
        [_u] joinSilent _newGrp;
    };

    {
        private _tok = _x;
        if (_tok isEqualType []) then { _tok = selectRandom _tok };   // nested array = pick one of the set
        if (toUpper _tok == "NONE") then { continue };                // "NONE" = an empty slot (a chance of nothing)
        switch (_tok) do {
            case "vest": {
                private _v = [_vestPool, _vestScore] call _lowPick;
                if (_v isEqualTo "") then { _v = "V_TacVest_blk" };
                _u addVest _v;
            };
            case "civ_backpack": {
                private _b = [_civBags, _bagScore] call _lowPick;
                if !(_b isEqualTo "") then { _u addBackpackGlobal _b };
            };
            case "backpack": { [_u] call _addBag };
            case "medic": {
                if (backpack _u == "") then { [_u] call _addBag };
                _u addItem "Medikit";
                for "_j" from 1 to 4 do { _u addItem "FirstAidKit" };
                _u setUnitTrait ["Medic", true];
            };
            default {
                if (_tok in _weaponMatch) then {
                    private _match = _weaponMatch get _tok;
                    private _cands = _weaponPool select { _x call _match };
                    if (_cands isEqualTo [] && {_tok == "grenadier"}) then {
                        private _rifle = _weaponMatch get "assault_rifle";
                        _cands = _weaponPool select { _x call _rifle };
                    };
                    // Empty category: pistol falls back to a vanilla sidearm; anything else is skipped.
                    private _w = if (_cands isEqualTo []) then {
                        if (_tok == "pistol") then { "hgun_Rook40_F" } else { "" }
                    } else { selectRandom _cands };
                    if !(_w isEqualTo "") then {
                        if (vest _u == "" && {_tok != "pistol"}) then { _u addVest "V_TacVest_blk" };  // hold rifle mags
                        // Belts and rockets are too bulky for a vest -- a bag carries the spares.
                        if (_tok in ["machinegun", "launcher"] && {backpack _u == ""}) then { [_u] call _addBag };
                        _u addWeapon _w;
                        private _magList = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
                        if !(_magList isEqualTo []) then {
                            private _mag = _magList select 0;
                            _u addWeaponItem [_w, _mag, true];
                            for "_j" from 1 to _mags do { _u addMagazine _mag };
                        };
                        if (_tok == "grenadier") then {
                            private _muzzles = getArray (configFile >> "CfgWeapons" >> _w >> "muzzles");
                            private _gl = _muzzles findIf {
                                _x != "this" && {(getArray (configFile >> "CfgWeapons" >> _w >> _x >> "magazines")) isNotEqualTo []}
                            };
                            if (_gl >= 0) then {
                                private _glMuzzle = _muzzles select _gl;
                                private _glMag = (getArray (configFile >> "CfgWeapons" >> _w >> _glMuzzle >> "magazines")) select 0;
                                _u addWeaponItem [_w, [_glMag, 1, _glMuzzle], true];
                                for "_j" from 1 to _mags do { _u addMagazine _glMag };
                            };
                        };
                    };
                };
            };
        };
    } forEach _spec;

    // Draw the primary: else the last-added sidearm stays in hand.
    if (primaryWeapon _u != "") then { _u selectWeapon (primaryWeapon _u) };
    if (_skill >= 0) then { { _u setSkill [_x, _skill] } forEach _skills };
    if !(_stance isEqualTo "") then { _u setUnitPos _stance };
    // Only a flip regains PATH: an armed-in-place unit (protectee, guards on their fuse) keeps the caller's.
    if (_hostile) then { _u enableAI "PATH" };
} forEach _units;

if (_hostile) then {
    _newGrp setBehaviour "COMBAT";
    _newGrp setCombatMode "RED";
    _newGrp setSpeedMode "NORMAL";
};
_newGrp
