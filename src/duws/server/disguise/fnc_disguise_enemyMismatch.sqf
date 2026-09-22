// Locality: server. The kit that gives the player away, as [slot, class]: an item OPFOR does not issue,
// or "" for a slot the player left empty that OPFOR fills.
// A weapon matches by its arsenal base row too, so a looted rifle with a different optic still passes.
// DUWS_enemyKit holds lowercase classes, because `in` compares strings by case and a mod's baseWeapon
// entry need not match its class's case.
// An empty slot counts only when every OPFOR class fills it, so a rifleman with no launcher passes. A
// vest and headgear count whenever empty: a soldier without them reads wrong even where a pilot or an
// officer in the roster goes without.
params ["_player"];

private _optional = DUWS_enemyKit get "optional";
private _fnc_lacks = {
    params ["_slot"];
    _slot in ["vest", "headgear"] || {!(_slot in _optional)}
};

private _out = [];
{
    _x params ["_slot", "_cls"];
    if (_cls == "") then {
        if ([_slot] call _fnc_lacks) then { _out pushBack [_slot, ""] };
    } else {
        if (!((toLowerANSI _cls) in (DUWS_enemyKit get _slot))) then { _out pushBack [_slot, _cls] };
    };
} forEach [["vest", vest _player], ["headgear", headgear _player], ["backpack", backpack _player], ["nvg", hmd _player]];

private _weapons = DUWS_enemyKit get "weapon";
{
    _x params ["_slot", "_cls"];
    if (_cls == "") then {
        if ([_slot] call _fnc_lacks) then { _out pushBack [_slot, ""] };
    } else {
        if (!((toLowerANSI _cls) in _weapons)
            && {(([[_cls]] call fnc_arsenal_base_weapons) findIf { (toLowerANSI _x) in _weapons }) < 0}) then {
            _out pushBack [_slot, _cls];
        };
    };
} forEach [["primary", primaryWeapon _player], ["launcher", secondaryWeapon _player], ["handgun", handgunWeapon _player]];

private _veh = vehicle _player;
if (_veh != _player) then {
    private _type = typeOf _veh;
    if (!((toLowerANSI _type) in (DUWS_enemyKit get "vehicle"))
        && {getNumber (configFile >> "CfgVehicles" >> _type >> "side") != 3}) then {
        _out pushBack ["vehicle", _type];
    };
};
_out
