// Locality: server. Flips a set of blended civilians into an armed, elite EAST cell and returns the new
// group. Shared by the angry-mob escalation (fnc_random_event_mob) and the safehouse-raid breach
// (fnc_raid_safehouse_breach) so the "a civilian pulls a weapon and fights" shape lives in one place.
//
// isHostile is stamped so the kill no longer bills a civilian death: fnc_civ_handler exempts only
// isHostile / resistance, so a bare EAST civ body still charges. Weapons are chambered via addWeaponItem
// so a pocketless civ costume still fights with a round already up the pipe.
//
// Contract: [_units, _weaponMode, _skill] -> _group (grpNull if none alive)
//   _weaponMode  "pistol"     -- the Rook40 sidearm the mob has always fielded.
//                "opfor_auto" -- a full-auto primary drawn from the detected OPFOR armory
//                               (opfor_ammobox_weapons), so the cell carries faction weapons, not vanilla.
//                               Falls back to the pistol shape if the armory has no auto weapon.
//   _skill       0..1, set across all six aim/spot skills (both callers field an elite cell at 1).
if (!isServer) exitWith { grpNull };
params ["_units", ["_weaponMode", "pistol"], ["_skill", 1]];
_units = _units select { alive _x };
if (_units isEqualTo []) exitWith { grpNull };

private _east = createGroup [EAST, true];

// Full-auto primaries from the OPFOR armory: non-launcher weapons carrying a mode with autoFire set.
// Resolved once, not per unit. Empty (armory not built yet, or nothing automatic) drops to the pistol.
private _autoPool = [];
if (_weaponMode isEqualTo "opfor_auto") then {
    private _pool = missionNamespace getVariable ["opfor_ammobox_weapons", []];
    _autoPool = _pool select {
        private _cfg = configFile >> "CfgWeapons" >> _x;
        !(_x isKindOf ["Launcher", configFile >> "CfgWeapons"]) &&
        {
            ((getArray (_cfg >> "modes")) findIf {
                private _node = if (_x == "this") then { _cfg } else { _cfg >> _x };
                getNumber (_node >> "autoFire") == 1
            }) >= 0
        }
    };
};
private _useAuto = _weaponMode isEqualTo "opfor_auto" && {!(_autoPool isEqualTo [])};

private _skills = ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "general"];
{
    private _u = _x;
    _u setVariable ["isHostile", true];
    _u setCaptive false;
    [_u] joinSilent _east;

    if (_useAuto) then {
        // Rifle mags need a container the plain civ costume may lack, or they drop on the floor.
        if (vest _u == "") then { _u addVest "V_TacVest_blk" };  // TUNABLE
        private _w = selectRandom _autoPool;
        _u addWeapon _w;
        private _mags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
        if !(_mags isEqualTo []) then {
            private _mag = _mags select 0;
            _u addWeaponItem [_w, _mag, true];
            for "_j" from 1 to 4 do { _u addMagazine _mag };
            _u selectWeapon _w;
        };
    } else {
        _u addWeapon "hgun_Rook40_F";
        _u addWeaponItem ["hgun_Rook40_F", "16Rnd_9x21_Mag", true];
        _u addMagazines ["16Rnd_9x21_Mag", 2];
    };

    { _u setSkill [_x, _skill] } forEach _skills;
    _u enableAI "PATH";
    _u setUnitPos "UP";
} forEach _units;

_east setBehaviour "COMBAT";
_east setCombatMode "RED";
_east setSpeedMode "NORMAL";
_east
