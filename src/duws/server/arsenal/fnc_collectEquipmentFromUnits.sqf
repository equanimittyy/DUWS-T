if (!isServer) exitWith {};

["INFO", "GEAR", "Collecting equipment from nearby units..."] call fnc_log;

blufor_helmets = [];
blufor_vests = [];
blufor_uniforms = [];
blufor_backpacks = [];
opfor_helmets = [];
opfor_vests = [];
opfor_uniforms = [];
opfor_backpacks = [];

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["ERROR", "GEAR", "No HQ position, abort."] call fnc_log; };

private _bluUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select { alive _x && side _x == WEST };
{
    private _h = headgear _x;
    private _v = vest _x;
    private _u = uniform _x;
    private _b = backpack _x;
    if (_h != "") then { blufor_helmets pushBackUnique _h };
    if (_v != "") then { blufor_vests pushBackUnique _v };
    if (_u != "") then { blufor_uniforms pushBackUnique _u };
    if (_b != "") then { blufor_backpacks pushBackUnique _b };
} forEach _bluUnits;

private _opfZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
{
    private _zonePos = _x;
    private _opfUnits = nearestObjects [_zonePos, ["CAManBase"], 300] select { alive _x && side _x == EAST };
    {
        private _h = headgear _x;
        private _v = vest _x;
        private _u = uniform _x;
        private _b = backpack _x;
        if (_h != "") then { opfor_helmets pushBackUnique _h };
        if (_v != "") then { opfor_vests pushBackUnique _v };
        if (_u != "") then { opfor_uniforms pushBackUnique _u };
        if (_b != "") then { opfor_backpacks pushBackUnique _b };
    } forEach _opfUnits;
} forEach _opfZones;

["INFO", "GEAR", format ["BLUFOR collected: H=%1 V=%2 U=%3 B=%4", count blufor_helmets, count blufor_vests, count blufor_uniforms, count blufor_backpacks]] call fnc_log;
["INFO", "GEAR", format ["OPFOR collected: H=%1 V=%2 U=%3 B=%4", count opfor_helmets, count opfor_vests, count opfor_uniforms, count opfor_backpacks]] call fnc_log;

publicVariable "blufor_helmets";
publicVariable "blufor_vests";
publicVariable "blufor_uniforms";
publicVariable "blufor_backpacks";
publicVariable "opfor_helmets";
publicVariable "opfor_vests";
publicVariable "opfor_uniforms";
publicVariable "opfor_backpacks";
