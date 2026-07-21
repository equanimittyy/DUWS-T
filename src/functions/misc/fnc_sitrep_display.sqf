// DISPLAY A SITREP
if (!hasInterface) exitWith {};
sleep 1;

// 安全获取变量，若未定义则使用默认值
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
private _rep = if (!isNil "Player_Reputation") then { str Player_Reputation } else { "0" };
private _weather = if (!isNil "weather_type") then { weather_type } else { "" };
private _timeOfDay = if (!isNil "time_of_day") then { time_of_day } else { 0 };
private _fastTravel = if (!isNil "enable_fast_travel") then { enable_fast_travel } else { false };
private _zeus = if (!isNil "ZeusStatus") then { ZeusStatus } else { 0 };
private _stamina = if (!isNil "staminaEnabled") then { staminaEnabled } else { true };
private _timeMult = if (!isNil "time_Multiplier") then { time_Multiplier } else { 1 };
private _simpleZones = if (!isNil "simple_zones_enable") then { simple_zones_enable } else { false };
private _civ = if (!isNil "CIV_PRESENCE") then { CIV_PRESENCE } else { "NONE" };

hint format [localize "STR_DUWS_T_jjl0pm74",
    _aliveAllUnits, _cp, _bluAp, _opfAp, _aliveAllTanks, _aliveAllAir,
    _bluZones, _opfZonesCount, _rep, _primary_target,
    _weather, _timeOfDay, _chopper, _fastTravel,
    _zeus, _stamina, _timeMult, _simpleZones, _civ
];