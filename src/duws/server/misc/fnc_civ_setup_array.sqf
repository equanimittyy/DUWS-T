/*
    Builds civ_array (the civilian body-model pool) on the server, independent of whether the
    ambient population spawns. PMC and partisan hiring draw their unit models from civ_array,
    so it must be populated even when civilians are OFF (CIV_PRESENCE == "NONE").
*/
if (!isServer) exitWith {};

[] call compile preprocessFileLineNumbers "duws\shared\factions\CIV_FACTIONS.sqf";
missionNamespace setVariable ["civ_array", civ_array];

// Civilian vehicle pool, detected the same way combat vehicles are: read the config faction off
// each civilian body model and take that faction's unarmed transport cars (fnc_parseFaction
// return index 18, _carTransport). A civ mod that ships only men yields none, so fall back to the
// vanilla civilian faction, then to a fixed pool if even that config is unreadable -- traffic
// must never be nil for the fill to draw from.
private _civFactions = (civ_array apply { getText (configFile >> "CfgVehicles" >> _x >> "faction") }) select { _x != "" };
_civFactions = _civFactions arrayIntersect _civFactions;

private _cars = [];
if (!isNil "fnc_parseFaction") then {
    { _cars append (([_x] call fnc_parseFaction) param [18, []]) } forEach _civFactions;
    if (_cars isEqualTo []) then { _cars = (["CIV_F"] call fnc_parseFaction) param [18, []] };
};
_cars = _cars arrayIntersect _cars;
if (_cars isEqualTo []) then {
    _cars = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F", "C_Quadbike_01_F"];
};
missionNamespace setVariable ["civ_veh_array", _cars, true];

// Civilian air pool, same detection as cars: each faction's unarmed transport helicopters
// (fnc_parseFaction index 23, _heliTransport). Most civ factions ship only men and cars, so this
// is usually empty and falls back to the vanilla civilian light helicopter; a men-only mod with no
// vanilla civ config leaves it empty and the heli event no-ops rather than fielding a soldier's airframe.
private _helis = [];
if (!isNil "fnc_parseFaction") then {
    { _helis append (([_x] call fnc_parseFaction) param [23, []]) } forEach _civFactions;
    if (_helis isEqualTo []) then { _helis = (["CIV_F"] call fnc_parseFaction) param [23, []] };
};
_helis = _helis arrayIntersect _helis;
if (_helis isEqualTo []) then { _helis = ["C_Heli_Light_01_civil_F"] };
missionNamespace setVariable ["civ_heli_array", _helis, true];
