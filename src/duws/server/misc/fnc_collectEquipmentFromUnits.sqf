// fnc_collectEquipmentFromUnits.sqf
if (!isServer) exitWith {};

diag_log "[Equipment] Collecting equipment from nearby units...";

// 初始化列表
blufor_helmets = [];
blufor_vests = [];
blufor_uniforms = [];
opfor_helmets = [];
opfor_vests = [];
opfor_uniforms = [];

// 获取 HQ 位置
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { diag_log "[Equipment] No HQ position, abort."; };

// 收集 HQ 附近 500 米内的蓝方单位
private _bluUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select { alive _x && side _x == WEST };
{
    private _h = headgear _x;
    private _v = vest _x;
    private _u = uniform _x;
    if (_h != "") then { blufor_helmets pushBackUnique _h };
    if (_v != "") then { blufor_vests pushBackUnique _v };
    if (_u != "") then { blufor_uniforms pushBackUnique _u };
} forEach _bluUnits;

// 获取所有敌占区
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

diag_log format ["[Equipment] BLUFOR collected: H=%1 V=%2 U=%3", count blufor_helmets, count blufor_vests, count blufor_uniforms];
diag_log format ["[Equipment] OPFOR collected: H=%1 V=%2 U=%3", count opfor_helmets, count opfor_vests, count opfor_uniforms];

// 公开变量
publicVariable "blufor_helmets";
publicVariable "blufor_vests";
publicVariable "blufor_uniforms";
publicVariable "opfor_helmets";
publicVariable "opfor_vests";
publicVariable "opfor_uniforms";