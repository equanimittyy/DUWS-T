// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
// fnc_createZone.sqf
//  _generatezonescript = [format["Zone %1",_i],_points_zone,_zone_radius,_MissionPos,_fortified,true,_i] spawn fnc_createzone
//  Name of the place,pts,radius,position,fortified,prefab,zone#
//

_name = _this select 0; //name
_points = _this select 1;
_size = _this select 2;
_zonePos = _this select 3;  //position
_fortified = _this select 4;
_prefab = _this select 5;
_zone_num = _this select 6;
// Zone visibility
_visible = true;
if (hardcore_mode_enable) then {_visible = false};


amount_zones_created = amount_zones_created + 1;
publicVariable "amount_zones_created";
zones_created = true; // Tell that at least 1 zone is created
publicVariable "zones_created";

// Add the zone to the array of zones (need for manual placement of zones and WARCOM)
if (isNil ("Array_of_OPFOR_zones")) then {Array_of_OPFOR_zones = [];};
Array_of_OPFOR_zones = Array_of_OPFOR_zones + [_zonePos];
// Add the zone name, position, and visibility(hardcore) to zone_namePOS_pairs 
zone_namePOS_pairs = zone_namePOS_pairs + [[_name,_zonePos,_visible]];
publicVariable "zone_namePOS_pairs";

// Add zone to the spawn/despawn array [number, blufor_close, noDespawn]
zone_spawn_array = zone_spawn_array + [[_zone_num,false,false]];

["INFO", "ZONES", format ["zone %1 registered at %2, worth %3, size %4, fortified=%5, prefab=%6",
	_zone_num, _zonePos, _points, _size, _fortified, _prefab]] call fnc_log;

// CREATE MARKER (ICON)
_markername = format["%1%2",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
_markerstr = createMarker [str(_markername),_zonePos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "o_inf";
str(_markername) setMarkerColor "ColorRed";
str(_markername) setMarkerText _name;
str(_markername) setMarkerSize [0, 0];
if (hardcore_mode_enable) then {
	str(_markername) setMarkerAlpha 0; 
} else {	
	str(_markername) setMarkerAlpha 1; 
};

// CREATE MARKER (ELLIPSE ZONE)
_markername2 = format["%1%2ellipse",round(_zonePos select 0),round(_zonePos select 1)];
_markerstr2 = createMarker [str(_markername2),_zonePos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "ColorRed";
str(_markername2) setMarkerSize [_size, _size];
if (hardcore_mode_enable) then {
	str(_markername2) setMarkerAlpha 0; 
} else {	
	str(_markername2) setMarkerAlpha 0.3; 
};

// ========== 清理战区中心周围的障碍物 ==========
if (_prefab) then {
    private _clearRadius = 35;
    private _allObjects = nearestObjects [_zonePos, [], _clearRadius];
    private _deletedCount = 0;
    private _hiddenCount = 0;
    {
        if (!isPlayer _x && 
            !(_x isKindOf "Man") && 
            !(_x isKindOf "Land_HelipadEmpty_F") && 
            !(_x isKindOf "FlagPole_F") &&
            !(_x isEqualTo bluHQ_object) &&
            !(_x in Array_of_FOBS)) then 
        {
            deleteVehicle _x;
            _deletedCount = _deletedCount + 1;
            if (!isNull _x) then {
                _x hideObjectGlobal true;
                _hiddenCount = _hiddenCount + 1;
            };
        };
    } forEach _allObjects;
    if (_deletedCount > 0 || _hiddenCount > 0) then {
        ["INFO", "ZONES", format ["Cleaned up %1 objects at zone center %2", _deletedCount + _hiddenCount, _zonePos]] call fnc_log;
    };
    sleep 0.5;
};

// CREATE PREFAB
if (_prefab) then {
	_array_of_prefabs = [];

	switch (VERSION_X) do {
		case "MODERN": {
			_array_of_prefabs = [
				["Vehicle Refit",true,fnc_modern_vehfittingstation,0.1],
				["Storage Bunker",true,fnc_modern_StorageBunker,0.12],
				["Comm Station",true,fnc_modern_CommStation,0.14],
				["Recon Outpost",true,fnc_modern_reconOutpost,0.1],
				["Outpost",true,fnc_modern_outpost1,0.1],
				["Outpost",true,fnc_modern_Outpost2,0.1],
                ["Field Hospital", true, fnc_modern_FieldHospital, 0.2]
			];
		};
	};
	_amount_of_prefabs = count _array_of_prefabs;
	_indexedAmount = _amount_of_prefabs - 1;
	_dice = round random _indexedAmount;

	_prefab_array = selectRandomWeighted [
		(_array_of_prefabs select 0),((_array_of_prefabs select 0) select 3),	
		(_array_of_prefabs select 1),((_array_of_prefabs select 1) select 3),	
		(_array_of_prefabs select 2),((_array_of_prefabs select 2) select 3),	
		(_array_of_prefabs select 3),((_array_of_prefabs select 3) select 3),	
		(_array_of_prefabs select 4),((_array_of_prefabs select 4) select 3),	
		(_array_of_prefabs select 5),((_array_of_prefabs select 5) select 3),
		(_array_of_prefabs select 6),((_array_of_prefabs select 6) select 3)
	];
	 
	_name = _prefab_array select 0;
	_fortified = _prefab_array select 1;
	_path = _prefab_array select 2;

	[_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1. %2", _zone_num, _name];

} else {
	switch (VERSION_X) do {
		case "MODERN": {
			_prefab = ["Outpost",true,fnc_modern_simple_zone];
		};
	};
	_name = _prefab select 0;
	_fortified = _prefab select 1;
	_path = _prefab select 2;

	[_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1. %2", _zone_num, _name];
};

// ========== 随机放置 3-4 个工事建筑，并记录到全局数组 ==========
private _fortificationClasses = [
    "Land_GuardTower_02_F",
    "Land_Cargo_Tower_V2_F",
    "Land_Cargo_Patrol_V2_F",
    "Land_BagBunker_Tower_F",
    "Land_Bunker_01_tall_F"
];
private _fortificationCount = 3 + floor random 2; // 3-4 个
private _radius = _size * 0.7; // 在战区半径70%范围内放置
private _zoneFortifications = []; // 存储放置的建筑对象
for "_i" from 1 to _fortificationCount do {
    private _angle = random 360;
    private _dist = random _radius;
    private _candidatePos = _zonePos getPos [_dist, _angle];
    private _safePos = [0,0,0];
    private _waterCheck = true;
    private _attempts = 0;
    
    // 循环直到找到非水域位置（最多10次）
    while {_waterCheck && _attempts < 10} do {
        _angle = random 360;
        _dist = random _radius;
        _candidatePos = _zonePos getPos [_dist, _angle];
        _safePos = [_candidatePos, 0, 50, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        if (_safePos isEqualTo [0,0,0]) then { _safePos = _candidatePos; };
        // 检查是否在水面上
        if (!surfaceIsWater _safePos) then {
            _waterCheck = false;
        };
        _attempts = _attempts + 1;
    };
    // 如果最终位置仍在水面，跳过该建筑
    if (surfaceIsWater _safePos) then {
        ["WARN", "ZONES", format ["Skipping fortification due to water at %1", _safePos]] call fnc_log;
        continue;
    };
    
    private _nearRoad = [_safePos, 10] call BIS_fnc_nearestRoad;
    if (!isNull _nearRoad) then {
        _safePos = [_safePos getPos [15, _angle], 0, 10, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_safePos isEqualTo [0,0,0]) then { continue };
        if (surfaceIsWater _safePos) then { continue };
    };
    private _nearObjs = nearestObjects [_safePos, [], 8];
    if (count _nearObjs > 0) then { continue };
    private _fortClass = selectRandom _fortificationClasses;
    private _fort = createVehicle [_fortClass, _safePos, [], 0, "CAN_COLLIDE"];
    _fort setDir (random 360);
    _fort setVectorUp [0,0,1];
    _fort allowDamage true;
    _zoneFortifications pushBack _fort;
    ["INFO", "ZONES", format ["Placed fortification %1 at %2 for zone %3", _fortClass, _safePos, _zone_num]] call fnc_log;
};
missionNamespace setVariable [format ["ZoneFortifications_%1", _zone_num], _zoneFortifications];
// ================================================

// ADD THE QRF OBJECT
_vehicle_0 = objNull;
_vehicle_0 = createVehicle ["Land_MultiMeter_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_vehicle_0 allowDamage false;
_vehicle_0 setPos [(_zonePos select 0)+20,(_zonePos select 1)];
hideObjectGlobal _vehicle_0;
_null = _vehicle_0 addEventHandler ["FiredNear", {[_this select 0] spawn fnc_QRF_test}];

// CREATE ZONE NOTIFICATION TRIGGER
_trg2=createTrigger["EmptyDetector",_zonePos];
_trg2 setTriggerArea[_size,_size,0,false];
_trg2 setTriggerActivation["ANYPLAYER","PRESENT",true];
_trg2 setTriggerStatements["this", format["['Zone %1',%2,'%3','%4',thislist] spawn fnc_enterlocation;",_zone_num,_zonePos,_markername,_markername2], ""];
_zonePosName2 = format["trigger2%1%2",round (_zonePos select 0),round (_zonePos select 1)];
call compile format["%1 = _trg2",_zonePosName2];
_spawnPos = _zonePos;

///////////////////////////////////////////////
// CREATE OPFOR
///////////////////////////////////////////////
_index = zone_spawn_array find [_zone_num,false,false];
_opfor_spawn = (zone_spawn_array select _index) select 1;
_noDespawn = (zone_spawn_array select _index) select 2;

sleep 60;
[_spawnPos,_size,_index] spawn fnc_spawnWait;

_fnc_spawn_size = "";
switch (true) do {
	case (_size < 101): { _fnc_spawn_size = fnc_100_zone; };
	case (_size < 251): { _fnc_spawn_size = fnc_250_zone; };
	case (_size < 501): { _fnc_spawn_size = fnc_500_zone; };
	case (_size < 1001): { _fnc_spawn_size = fnc_1000_zone; };
	case (_size < 1501): { _fnc_spawn_size = fnc_1500_zone; };
	case (_size > 1500): { _fnc_spawn_size = fnc_1501_zone; };
};

// ========== 战区直升机增援监控初始化 ==========
private _zoneCenter = _zonePos;
private _zoneRadius = _size;
private _zoneNum = _zone_num;

// 生成唯一变量后缀
private _varSuffix = format ["zone_%1_%2", round(_zoneCenter select 0), round(_zoneCenter select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];

// 初始计数设为0，实际统计在 fnc_spawnWait 首次生成敌军时完成
missionNamespace setVariable [_initialCountVar, 0, true];
missionNamespace setVariable [_triggeredVar, false, true];

// 存储变量名到战区，以便后续重置时使用
_zonePosName = format ["zoneVars_%1", _zoneNum];
missionNamespace setVariable [_zonePosName, [_initialCountVar, _triggeredVar, _zoneCenter, _zoneRadius], true];
// ================================================

// ✅ 修复：将占领触发器和旗杆创建代码移到 while 循环之前，确保它们能够执行

// CREATE ZONE CAPTURABLE TRIGGER
_trg = createTrigger ["EmptyDetector", _zonePos];
_trg setTriggerArea [_size, _size, 0, false];
_trg setTriggerActivation ["WEST SEIZED", "PRESENT", true];
_trg setTriggerStatements ["this", format["[""%1"",%2,""%3"",""%4"",%5,%6] spawn fnc_captured", _name, _points, _markername, _markername2, _zonePos, _size], ""];
_trg setTriggerTimeout [30, 40, 50, true];

// 存储触发器变量（统一使用 floor abs 避免负号）
private _trgVarName = format["trigger_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
missionNamespace setVariable [_trgVarName, _trg];
_trg setVariable ["isZoneCaptureTrigger", true];

// IF MODERN or SIMPLE ZONES, CREATE ZONE FLAG WITH RANDOM OFFSET AND STORE VARIABLE
if (VERSION_X == "MODERN" || simple_zones_enable) then {
    // 随机偏移距离：15 到 25 米
    private _offsetDist = 15 + random 10;
    // 随机方向
    private _offsetDir = random 360;
    // 计算偏移后的位置
    private _flagPos = _zonePos getPos [_offsetDist, _offsetDir];
    
    // 确保旗杆不悬空（使用安全位置查找）
    private _safePos = [_flagPos, 0, 3, 1, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then { _safePos = _flagPos };
    _safePos set [2, 0];
    
    private _flg = "FlagPole_F" createVehicle _safePos;
    private _flagVarName = format["flag_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
    missionNamespace setVariable [_flagVarName, _flg];
    _flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
};

// ✅ 战区重生/清理循环（必须在最后，因为它是无限循环）
while {true} do {
	if (_opfor_spawn == true) then {
		_opfor_spawn = false;
		(zone_spawn_array select _index) set [1,false];
		[_spawnPos] spawn fnc_createopfortified;
		sleep 2;
		[_spawnPos,_size] spawn _fnc_spawn_size;
		
		// ========== 战区增援：重置计数并启动监控 ==========
		sleep 5; // 等待敌军完全生成
		private _varSuffix = format ["zone_%1_%2", round(_spawnPos select 0), round(_spawnPos select 1)];
		private _initialCountVar = format ["opf_initial_%1", _varSuffix];
		private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
		
		private _nearbyEnemies = _spawnPos nearEntities [["CAManBase", "LandVehicle", "Air"], _size * 1.2] select { side _x == EAST };
		private _initialEnemyCount = count _nearbyEnemies;
		
		missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
		missionNamespace setVariable [_triggeredVar, false, true];
		
		["INFO", "ZONES", format ["Zone %1: Initial enemy count reset to %2", _zone_num, _initialEnemyCount]] call fnc_log;
		
		[_spawnPos, _size, _initialCountVar, _triggeredVar, "", true] spawn fnc_opf_heli_reinforce;
		// ==============================================
	};
	while {true} do {
		if (_opfor_spawn == true || _noDespawn == true) exitWith {};
		sleep 10;
		_opfor_spawn = (zone_spawn_array select _index) select 1;
		_noDespawn = (zone_spawn_array select _index) select 2;
	};
	if (_noDespawn == true) then {
		waitUntil {sleep 60;(!(_spawnPos in WARCOM_zones_controled_by_OPFOR) || count WARCOM_zones_controled_by_OPFOR < 1)};
		if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
		waitUntil {sleep 60;(_spawnPos in WARCOM_zones_controled_by_OPFOR || count WARCOM_zones_controled_by_OPFOR < 1)};
		if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
		_opfor_spawn = false;
		_noDespawn = false;
		(zone_spawn_array select _index) set [1,false];
		(zone_spawn_array select _index) set [2,false];
	};
	if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
};