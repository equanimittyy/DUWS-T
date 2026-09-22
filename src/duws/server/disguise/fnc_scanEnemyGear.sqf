// Locality: server. Builds DUWS_enemyKit, the OPFOR issue the enemy disguise matches against, once the
// faction has resolved.
// From the roster, not config side 0: auto-detection can field a faction as OPFOR whose units are
// side 2 in config, and a side test would reject its uniforms. Each class is spawned and read rather
// than read from linkedItems[], so gear an init script adds is seen too. A mod that rolls gear per
// spawn shows the scan one roll per class, so its other rolls read as mismatched.
if (!isServer) exitWith {};

private _men = ["opfor", "man"] call fnc_faction_unit_keylist;
private _vehicles = (["opfor", "vehicle"] call fnc_faction_unit_keylist) + (["opfor", "static"] call fnc_faction_unit_keylist);
private _safePos = [worldSize / 2, worldSize / 2, 0];

private _kit = createHashMapFromArray [
    ["uniform", []], ["vest", []], ["headgear", []], ["backpack", []], ["nvg", []], ["weapon", []]
];
// The slots some OPFOR class leaves empty, so an empty one on the player is still OPFOR issue.
private _optional = [];
private _grp = createGroup east;
{
    private _unit = _grp createUnit [_x, _safePos, [], 0, "NONE"];
    if (!isNull _unit) then {
        sleep 0.05;
        {
            _x params ["_slot", "_set", "_cls"];
            if (_cls == "") then { _optional pushBackUnique _slot } else { (_kit get _set) pushBackUnique (toLowerANSI _cls) };
        } forEach [
            ["uniform", "uniform", uniform _unit], ["vest", "vest", vest _unit], ["headgear", "headgear", headgear _unit],
            ["backpack", "backpack", backpack _unit], ["nvg", "nvg", hmd _unit], ["primary", "weapon", primaryWeapon _unit],
            ["launcher", "weapon", secondaryWeapon _unit], ["handgun", "weapon", handgunWeapon _unit]
        ];
        deleteVehicle _unit;
    };
} forEach _men;
deleteGroup _grp;

private _weapons = _kit get "weapon";
{ _weapons pushBackUnique (toLowerANSI _x) } forEach ([_weapons] call fnc_arsenal_base_weapons);
_kit set ["vehicle", _vehicles apply { toLowerANSI _x }];
_kit set ["optional", _optional];

DUWS_enemyKit = _kit;
["INFO", "GEAR", format ["enemy kit: %1 uniforms, %2 vests, %3 headgear, %4 backpacks, %5 NVGs, %6 weapons, %7 vehicles, optional slots %8",
    count (_kit get "uniform"), count (_kit get "vest"), count (_kit get "headgear"), count (_kit get "backpack"),
    count (_kit get "nvg"), count _weapons, count (_kit get "vehicle"), _optional]] call fnc_log;
