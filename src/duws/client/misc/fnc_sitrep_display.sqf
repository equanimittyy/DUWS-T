// DISPLAY A SITREP
// The reputation figure arrives as an argument rather than being read here: it is the standing of
// the town this player is in, and that array lives on the server alone. fnc_sitrep_fanout resolves
// it per player.
if (!hasInterface) exitWith {};
params [["_rep", "--"]];
sleep 1;

private _allUnits = if (!isNil "allUnits") then { allUnits } else { [] };
private _aliveAllUnits = {alive _x} count _allUnits;

private _vehicles = if (!isNil "vehicles") then { vehicles } else { [] };
private _aliveAllTanks = {(alive _x) && ((_x isKindOf "Tank") || (_x isKindOf "car"))} count _vehicles;
private _aliveAllAir = {_x isKindOf "Air" && alive _x} count _vehicles;

private _opfZones = if (!isNil "WARCOM_zones_controled_by_OPFOR") then { WARCOM_zones_controled_by_OPFOR } else { [] };
private _primary_waypoint = if (count _opfZones > 0) then { _opfZones select 0 } else { [] };
private _primary_target = "";
private _zonePairs = if (!isNil "zone_namePOS_pairs") then { zone_namePOS_pairs } else { [] };
{
    if (str (_x select 1) == str (_primary_waypoint)) then {
        _primary_target = _x select 0;
    };
} forEach _zonePairs;

private _cp = if (!isNil "commandpointsblu1") then { commandpointsblu1 } else { 0 };
private _bluAp = if (!isNil "WARCOM_blufor_ap") then { WARCOM_blufor_ap } else { 0 };
private _opfAp = if (!isNil "WARCOM_opfor_ap") then { WARCOM_opfor_ap } else { 0 };
private _bluZones = if (!isNil "WARCOM_zones_controled_by_BLUFOR") then { count WARCOM_zones_controled_by_BLUFOR } else { 0 };
private _opfZonesCount = count _opfZones;
private _weather = if (!isNil "weather_type") then { weather_type } else { "" };
private _timeOfDay = if (!isNil "time_of_day") then { time_of_day } else { 0 };
private _fastTravel = if (!isNil "enable_fast_travel") then { enable_fast_travel } else { false };
private _zeus = if (!isNil "ZeusStatus") then { ZeusStatus } else { 0 };
private _stamina = if (!isNil "staminaEnabled") then { staminaEnabled } else { true };
private _simpleZones = if (!isNil "simple_zones_enable") then { simple_zones_enable } else { false };
private _civ = if (!isNil "CIV_PRESENCE") then { CIV_PRESENCE } else { "NONE" };
// The ladder tier beside each side's Army Power wallet: the pool figure alone stops describing
// capability the moment spending starts, so the readout prints what each side has reached as well as
// what it holds. Appended as args 19/20 so the existing 1-18 order the other languages rely on is
// untouched; only the English string references the new placeholders.
private _bluTier = if (!isNil "WARCOM_blufor_tier") then { WARCOM_blufor_tier } else { 0 };
private _opfTier = if (!isNil "WARCOM_opfor_tier") then { WARCOM_opfor_tier } else { 0 };

hint format [localize "STR_DUWS_T_jjl0pm74",
    _aliveAllUnits, _cp, _bluAp, _opfAp, _aliveAllTanks, _aliveAllAir,
    _bluZones, _opfZonesCount, _rep, _primary_target,
    _weather, _timeOfDay, _chopper, _fastTravel,
    _zeus, _stamina, _simpleZones, _civ,
    _bluTier, _opfTier
];