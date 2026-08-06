// fnc_collectEquipmentFromUnits.sqf
if (!isServer) exitWith {};

["INFO", "GEAR", "Collecting equipment from nearby units..."] call fnc_log;

blufor_helmets = [];
blufor_vests = [];
blufor_uniforms = [];
opfor_helmets = [];
opfor_vests = [];
opfor_uniforms = [];

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["ERROR", "GEAR", "No HQ position, abort."] call fnc_log; };

private _bluUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select { alive _x && side _x == WEST };
{
    private _h = headgear _x;
    private _v = vest _x;
    private _u = uniform _x;
    if (_h != "") then { blufor_helmets pushBackUnique _h };
    if (_v != "") then { blufor_vests pushBackUnique _v };
    if (_u != "") then { blufor_uniforms pushBackUnique _u };
} forEach _bluUnits;

private _opfZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
{
    private _zonePos = _x;
    private _opfUnits = nearestObjects [_zonePos, ["CAManBase"], 300] select { alive _x && side _x == EAST };
    {
        private _h = headgear _x;
        private _v = vest _x;
        private _u = uniform _x;
        if (_h != "") then { opfor_helmets pushBackUnique _h };
        if (_v != "") then { opfor_vests pushBackUnique _v };
        if (_u != "") then { opfor_uniforms pushBackUnique _u };
    } forEach _opfUnits;
} forEach _opfZones;

["INFO", "GEAR", format ["BLUFOR collected: H=%1 V=%2 U=%3", count blufor_helmets, count blufor_vests, count blufor_uniforms]] call fnc_log;
["INFO", "GEAR", format ["OPFOR collected: H=%1 V=%2 U=%3", count opfor_helmets, count opfor_vests, count opfor_uniforms]] call fnc_log;

publicVariable "blufor_helmets";
publicVariable "blufor_vests";
publicVariable "blufor_uniforms";
publicVariable "opfor_helmets";
publicVariable "opfor_vests";
publicVariable "opfor_uniforms";