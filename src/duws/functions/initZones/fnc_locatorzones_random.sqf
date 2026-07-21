// fnc_locatorZones_random.sqf
//////////////////
// Random Zones
//////////////////
diag_log "WAITING FOR MASTER_allLocations_filtered";
waitUntil {sleep 0.1;count(MASTER_allLocations_filtered) > 0};
diag_log "RECEIVED MASTER_allLocations_filtered";

_radius = _this select 0;
_diff = _this select 1;
_infinite_failsafe_loop = true;
failsafe_zones_not_found1 = false;
failsafe_zones_not_found2 = false;
_zones_array = [];

_ZnObjects = MASTER_allLocations_filtered;

_half = worldSize / 2;
_safehalf = worldSize / 2.2;
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

// Spawn failsafe 1
[] spawn {  
	for [{_i=1}, {_i<=2}, {_i=_i+1}] do {
		sleep 30;
		if !(WARCOM_init_done) then {
			[{hint localize "STR_DUWS_T_2amacebc"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
		};	
	};
	sleep 30;
	failsafe_zones_not_found1 = true;
};

[{hint localize "STR_DUWS_T_2amacebc"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

_worldName = getText(configFile >> "cfgWorlds" >> worldName >> "description");

_fortified = false;

_zones_array = [[-9999,-9999,-9999]];
_distances = [];

////////////////////////
// Loop for each zone
////////////////////////
for "_i" from 1 to zones_number do {
	[{hint localize "STR_DUWS_T_2amacebc"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
	trap = _i;
	publicVariable "trap";
	[{player globalChat format[localize "STR_DUWS_T_dkajkn5v",trap]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
	_found = false;
	_zone_radius = 0;
	_points_zone = 0;

	while {_zone_radius<=zones_min_radius} do { 
		_random_zones_max_radius = random zones_max_radius;
		_zone_radius = round _random_zones_max_radius;   
		_points_zone = round (_zone_radius/10);
	}; 
	
	while {!_found} do
	{
		if (failsafe_zones_not_found1) then {
			hintSilent localize "STR_DUWS_T_zjb75rxm";
			_ZnObjects = [];
			_ZnObjects = nearestLocations [PosOfBLUHQ, ["NameLocal","Hill"], (zones_max_dist_from_hq*1.2)];
			[] spawn {
				sleep 60;
				failsafe_zones_not_found2 = true;
			};
			if (failsafe_zones_not_found2) exitWith {
				forceMap false;
				openMap [false, false];
				closeDialog 0;
				while {_infinite_failsafe_loop} do {
					[{player globalChat localize "STR_DUWS_T_1rqkf85t"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
					[{hint localize "STR_DUWS_T_4zwea7it"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
					failsafe_zones_not_found2 = false; 
					chosen_settings = false;
					sleep 1;
				};
			};
		};
		
		_Posfound = false;
		_ZnLocation = [];
		_zonePos = [];

		while {!_Posfound} do {
		
			if (moreUrban == 1) then {
				// ========== 改进版：选取建筑群中心 ==========
				private _anchor = _ZnObjects select (floor (random (count _ZnObjects)));
				private _anchorPos = getPos _anchor;
				private _nearBuildings = nearestTerrainObjects [_anchorPos, ["House","Building"], 400, true];
				
				if (count _nearBuildings == 0) then {
					// 没有建筑，回退到原逻辑
					private _randomPos = [_anchorPos, 100, 400, 10, 0, 0.14, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					private _building = nearestBuilding _randomPos;
					_zonePos = getPos _building;
				} else {
					// 计算建筑群中心
					private _centerX = 0;
					private _centerY = 0;
					{ _centerX = _centerX + (getPos _x select 0); _centerY = _centerY + (getPos _x select 1); } forEach _nearBuildings;
					_centerX = _centerX / count _nearBuildings;
					_centerY = _centerY / count _nearBuildings;
					private _centerPos = [_centerX, _centerY, 0];
					
					// 使用与 HQ 相同的安全点查找参数（0-10米）
					_zonePos = [_centerPos, 0, 10, 5, 0, 0.14, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					if (_zonePos isEqualTo [0,0,0]) then {
						_zonePos = _centerPos;
					};
				};
				
				// 避免放在道路上
				private _nearRoad = [_zonePos, 5] call BIS_fnc_nearestRoad;
				if (!isNull _nearRoad) then {
					_zonePos = [_zonePos, 5, random 360] call BIS_fnc_relPos;
				};
				
				// 检查是否靠近已有战区或 FOB（DOMINATION 模式）
				if (DUWS_MODE == "DOMINATION") then {
					private _too_close = false;
					{
						private _dist = _zonePos distance (getPos _x);
						if (_dist < 1500) exitWith { _too_close = true; };
					} forEach Array_of_FOBS;
					{
						private _dist = _zonePos distance _x;
						if (_dist < 1500) exitWith { _too_close = true; };
					} forEach serv_zones_array_temp;
					if (_too_close) then {
						_Posfound = false;
						continue;
					};
				};
				
				_Posfound = true;
				
			} else {
				// LESS URBAN 保持不变
				private _count = 1;
				while {true} do {
					if (_count > 10) exitWith {};
					private _inArc = false; 
					while {!_inArc} do {
						_ZnLocation = [_mapcenter, 0, _mapradius,5,0,0.14,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
						if (count(AO_direction) > 0) then {
							private _direction = PosOfBLUHQ getDir AO_direction;
							_inArc = [ PosOfBLUHQ, _direction, 135, _ZnLocation ] call BIS_fnc_inAngleSector;
						} else {
							_inArc = true;
						};
					};
					if (DUWS_MODE == "DOMINATION") then {
						private _too_close = false;
						{
							private _dist = _ZnLocation distance (getPos _x);
							if (_dist < 1500) exitWith { _too_close = true; };
						} forEach Array_of_FOBS;
						{
							private _dist = _ZnLocation distance _x;
							if (_dist < 1500) exitWith { _too_close = true; };
						} forEach serv_zones_array_temp;
						if (_too_close) then { _count = 11; };
					};
					if (_count == 11) exitWith {}; 
					private _building = nearestBuilding _ZnLocation;
					_zonePos = [_building, 0, 10, 5, 0, 0.14, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					if (_zonePos isEqualTo [0,0,0]) then { _zonePos = getPos _building; };
					private _nearRoad = [_zonePos,10] call BIS_fnc_nearestRoad;
					if (_zonePos select 0 != 0 && _zonePos select 1 != 0 && isNull _nearRoad) then {_Posfound=true;_count = 11;};
					_count = _count + 1;
				};
			};
		};

		private _playerDistance = _zonePos distance PosOfBLUHQ;

		if (_playerDistance > (zones_max_radius + 1000) && (PosOfBLUHQ distance _zonePos) <= zones_max_dist_from_hq) then {  

			private _found_distance = true;
			private _distanceCheck = [];     
			for [{_t=1}, {_t<=count _zones_array}, {_t=_t+1}] do {
				private _idx = _t-1;
				_distanceCheck pushBack ((_zones_array select _idx) distance _zonePos);
			};
			for [{_t=1}, {_t<=count _distanceCheck}, {_t=_t+1}] do {
				private _idx = _t-1;
				private _check = _distanceCheck select _idx;
				if (_check < zones_spacing) then {
					_found_distance = false;
				};
			};
     
if (_found_distance) then {
    // ========== 原点防护：禁止在距离 [0,0,0] 500 米内生成战区 ==========
    if (_zonePos distance2D [0,0,0] < 500) exitWith {
        diag_log format ["[Zone] Zone %1 position %2 is within 500m of origin, retrying...", _i, _zonePos];
        // 不设置 _found = true，让外层循环继续寻找新位置
    };
    // ================================================================
    
    trap = _i;
    publicVariable "trap";
    _zonePos = [round(_zonePos select 0), round(_zonePos select 1)];
    diag_log format ["Create Zone start: %1", _i];
    private _prefabFlag = true;
    if (simple_zones_enable) then { _prefabFlag = false };
    [format[localize "STR_DUWS_T_39z6pg7y",_i], _points_zone, _zone_radius, _zonePos, _fortified, _prefabFlag, _i] spawn fnc_createZone;
    _found = true;
    _zones_array pushBack _zonePos; 
    [{player globalChat format[localize "STR_DUWS_T_vai9q3po",trap]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    sleep 1;
    [{player globalChat format[localize "STR_DUWS_T_1lfvd9iw",trap]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
};
		};
	};
};

sleep 1;
trap = _worldName;
publicVariable "trap";
[{player globalChat format[localize "STR_DUWS_T_d5e848d8",trap,profileName]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
[{player globalChat localize "STR_DUWS_T_518bqchj"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
[{hint format[localize "STR_DUWS_T_7mog9k78",
	zones_number,zones_max_radius,zones_min_radius,zones_max_dist_from_hq,
	weather_type,time_of_day,enable_fast_travel,
	ZeusStatus,staminaEnabled,VCOM_AI_enable,time_Multiplier,simple_zones_enable,CIV_PRESENCE
]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

_zones_array = [_zones_array, 0] call BIS_fnc_removeIndex;
serv_zones_array = [] + _zones_array;
publicVariable "serv_zones_array";

[
	[
		[localize "STR_DUWS_T_518bqchj","<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"],
		[localize "STR_DUWS_T_37xxl2nt","<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"],
		[format[localize "STR_DUWS_T_dqxeffa2",_worldName,profilename],"<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"]
	]
] spawn BIS_fnc_typeText;