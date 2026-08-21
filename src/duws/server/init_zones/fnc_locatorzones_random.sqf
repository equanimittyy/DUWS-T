// Locality: server -- inherited from server/warcom/fnc_init_OPFOR_WARCOM.sqf.
while {!(["ZONES", "MASTER_allLocations_filtered from fnc_moreUrban_locations", {count(MASTER_allLocations_filtered) > 0}, 300] call fnc_waitLogged)} do {};

_infinite_failsafe_loop = true;
failsafe_zones_not_found1 = false;
failsafe_zones_not_found2 = false;
_zones_array = [];

_ZnObjects = MASTER_allLocations_filtered;

_half = worldSize / 2;
_safehalf = worldSize / 2.2;
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

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

_fortified = false;

_zones_array = [[-9999,-9999,-9999]];

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
				private _anchor = _ZnObjects select (floor (random (count _ZnObjects)));
				private _anchorPos = getPos _anchor;
				private _nearBuildings = nearestTerrainObjects [_anchorPos, ["House","Building"], 400, true];
				
				if (count _nearBuildings == 0) then {
					private _randomPos = [_anchorPos, 100, 400, 10, 0, 0.14, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					private _building = nearestBuilding _randomPos;
					_zonePos = getPos _building;
				} else {
					private _centerX = 0;
					private _centerY = 0;
					{ _centerX = _centerX + (getPos _x select 0); _centerY = _centerY + (getPos _x select 1); } forEach _nearBuildings;
					_centerX = _centerX / count _nearBuildings;
					_centerY = _centerY / count _nearBuildings;
					private _centerPos = [_centerX, _centerY, 0];
					
					// Same safe-pos search radius as the HQ (0-10m).
					_zonePos = [_centerPos, 0, 10, 5, 0, 0.14, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					if (_zonePos isEqualTo [0,0,0]) then {
						_zonePos = _centerPos;
					};
				};
				
				private _nearRoad = [_zonePos, 5] call BIS_fnc_nearestRoad;
				if (!isNull _nearRoad) then {
					_zonePos = [_zonePos, 5, random 360] call BIS_fnc_relPos;
				};
				
				_Posfound = true;
				
			} else {
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
    // Origin guard: refuse to spawn a zone within 500m of [0,0,0].
    if (_zonePos distance2D [0,0,0] < 500) exitWith {
        ["WARN", "ZONES", format ["Zone %1 position %2 is within 500m of origin, retrying...", _i, _zonePos]] call fnc_log;
        // _found stays false, so the outer loop keeps searching for a new position.
    };

    trap = _i;
    publicVariable "trap";
    _zonePos = [round(_zonePos select 0), round(_zonePos select 1)];
    private _prefabFlag = true;
    if (simple_zones_enable) then { _prefabFlag = false };
    ["", _points_zone, _zone_radius, _zonePos, _fortified, _prefabFlag, _i] spawn fnc_createZone;
    _found = true;
    _zones_array pushBack _zonePos;
    // Same map-layer constraint as the terrain survey: the globalChat lines below are
    // invisible while the map is open, so mirror the progress onto the map prompt.
    [format ["Generating zones...<br/>placing zone %1 of %2", _i, zones_number]]
        remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
 
    [{player globalChat format[localize "STR_DUWS_T_vai9q3po",trap]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    sleep 1;
    [{player globalChat format[localize "STR_DUWS_T_1lfvd9iw",trap]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
};
		};
	};
};

sleep 1;
[""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
// No completion announcement here: every one of them fires from fnc_init_OPFOR_WARCOM once
// civilians are registered too. Announcing at this point told the player the campaign was
// ready while towns were still being placed.
_zones_array = [_zones_array, 0] call BIS_fnc_removeIndex;
serv_zones_array = [] + _zones_array;
publicVariable "serv_zones_array";

["INFO", "ZONES", format ["random generation complete: %1 zones", count serv_zones_array]] call fnc_log;