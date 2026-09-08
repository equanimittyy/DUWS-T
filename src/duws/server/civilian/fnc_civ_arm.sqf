// Locality: server. Arms civ-costume bodies with a loadout from the detected-faction gear pools, and
// optionally flips them to a hostile cell. Shared by the safehouse raid, angry mob, informant flee and
// protect-civ protectee.
//
// isHostile is the exemption fnc_civ_handler checks: without it a civ-body kill still bills a civilian
// death after the body joins EAST. Weapons chamber via addWeaponItem so a pocketless costume still fires
// the loaded round.
//
// Contract: [_units, _side, _pool, _spec, _opts] -> _group (grpNull when not flipping / none alive)
//   _side  "EAST"|"WEST"|"IND" -- group side a hostile flip joins; decoupled from _pool, so an IND cell
//          can carry OPFOR kit. Ignored when not flipping.
//   _pool  "opfor"|"blufor" -- which faction's weapon/vest/backpack pools to draw from.
//   _spec  tokens, gear before weapons:
//            weapons pistol|submachinegun|assault_rifle|machinegun|sniper|launcher -- one of that
//              BIS_fnc_itemType subcategory from the pool, chambered + spares.
//            vest / civ_backpack / backpack -- from the matching pool, the lowest 3 by armour/capacity.
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
private _prefix = toLower _pool;

// Any pool may be empty on a stripped faction -- the per-slot fallbacks below cover that.
private _weaponPool = missionNamespace getVariable [_prefix + "_ammobox_weapons", []];
private _vestPool   = missionNamespace getVariable [_prefix + "_vests", []];
private _sideBags   = missionNamespace getVariable [_prefix + "_backpacks", []];
private _civBags    = missionNamespace getVariable ["DUWS_civBackpacks", []];

private _subcatOf = createHashMapFromArray [
    ["pistol", "Handgun"], ["submachinegun", "SubmachineGun"], ["assault_rifle", "AssaultRifle"],
    ["machinegun", "MachineGun"], ["sniper", "SniperRifle"], ["launcher", "Launcher"]
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
            case "backpack": {
                private _b = [_sideBags, _bagScore] call _lowPick;
                if (_b isEqualTo "") then { _b = [_civBags, _bagScore] call _lowPick };
                if !(_b isEqualTo "") then { _u addBackpackGlobal _b };
            };
            default {
                private _sub = _subcatOf getOrDefault [_tok, ""];
                if !(_sub isEqualTo "") then {
                    private _cands = _weaponPool select { ((_x call BIS_fnc_itemType) select 1) == _sub };
                    // Empty category: pistol falls back to a vanilla sidearm; anything else is skipped.
                    private _w = if (_cands isEqualTo []) then {
                        if (_tok == "pistol") then { "hgun_Rook40_F" } else { "" }
                    } else { selectRandom _cands };
                    if !(_w isEqualTo "") then {
                        if (vest _u == "" && {_tok != "pistol"}) then { _u addVest "V_TacVest_blk" };  // hold rifle mags
                        _u addWeapon _w;
                        private _magList = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
                        if !(_magList isEqualTo []) then {
                            private _mag = _magList select 0;
                            _u addWeaponItem [_w, _mag, true];
                            for "_j" from 1 to _mags do { _u addMagazine _mag };
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
