

////////////////////////////////
/// DUWS_T "More Urban" changes
////////////////////////////////
if (!isServer) exitWith {};
_half = worldSize / 2;
_safehalf = worldSize / 2.2;  //STAY OFF THE EDGES OF SMALL MAPS
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

_allLocations = [];
_allTowns = [];
_temp_allTowns = [];
_temp_allLocations = [];
_temp_allLocationsPos = [];

// find all location TYPES
_allLocationTypes = [];
"_allLocationTypes pushBack configName _x" configClasses (configFile >> "CfgLocationTypes");

// Create a MASTER temp list of "all" location positions on the map using TYPES
{
	_temp_allLocations = _temp_allLocations + [_x];
} forEach nearestLocations [_mapcenter, _allLocationTypes, _mapradius];
{
	_temp_allLocationsPos = _temp_allLocationsPos + [(locationPosition _x)];
} forEach _temp_allLocations;

MASTER_allLocationsPos = _temp_allLocationsPos call BIS_fnc_arrayShuffle;
publicVariable "MASTER_allLocationsPos";

// Create a temp list of "all" Cities and Towns (adds weight to the town selection)
{
	_temp_allTowns = _temp_allTowns + [_x];
} forEach nearestLocations [_mapcenter, ["NameCityCapital","NameVillage","NameCity","Name"], _mapradius];

//[{player globalChat "ALL MAP LOCATIONS FOUND."}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

// These two come from the client's setup screens. Until both land the whole campaign is
// blocked behind this function, so a silent stall here reads as "zones never generated".
["INFO", "ZONES", format ["moreUrban gates: dist=%1 chosen=%2 towns=%3 locs=%4",
    zones_max_dist_from_hq, chosen_settings, count _temp_allTowns, count _temp_allLocations]] call fnc_log;
while {!(["ZONES", "zones_max_dist_from_hq from the campaign menu",
    {zones_max_dist_from_hq > 0}, 300] call fnc_waitLogged)} do {};
while {!(["ZONES", "chosen_settings from the callsign screen",
    {chosen_settings}, 300] call fnc_waitLogged)} do {};
["INFO", "ZONES", format ["moreUrban filtering. dist=%1 AO_direction=%2 moreUrban=%3 hq=%4",
    zones_max_dist_from_hq,
    (if (isNil "AO_direction") then {"<nil>"} else {count AO_direction}),
    (if (isNil "moreUrban") then {"<nil>"} else {moreUrban}),
    (if (isNil "PosOfBLUHQ") then {"<nil>"} else {PosOfBLUHQ})]] call fnc_log;

// Exit if zones manually chosen ???  what about missions
//if (manually_chosen) exitWith {};

if (zones_max_dist_from_hq > 10000) then {
	[{hint localize "STR_DUWS_T_eggxrcci"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
} else {
	[{hint localize "STR_DUWS_T_3kascuws"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
};
// Create a list of locations on the map using distance from HQ
{
	if (PosOfBLUHQ distance _x < zones_max_dist_from_hq) then {
		_allLocations = _allLocations + [_x];
	};
} forEach _temp_allLocations;

// Create a list of Cities and Towns using distance from HQ
{
	if (PosOfBLUHQ distance _x < zones_max_dist_from_hq) then {
		_allTowns = _allTowns + [_x];
	};
} forEach _temp_allTowns;

// ZONE DISTANCE FILTER APPLIED.
[{player globalChat localize "STR_DUWS_T_8q8zqlf0"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

/*
_placesCfg = configFile >> "CfgWorlds" >> worldName >> "Names";
_namesToKeep = ["MILITARY","CAMP","FOB","OUTPOST","FACTORY","POWER","TRAIN","AIRFIELD","AIRSTRIP","AIRBASE","DAM","CASTLE","STORAGE","WAREHOUSE","LUMBER","HOSPITAL","BRIDGE"];
_typesToChk =["NameLocal", "ViewPoint", "NameMarine", "Strategic", "StrongPointArea"];
_places = [];
for "_i" from 0 to (count _placesCfg)-1 do {
	_place = _placesCfg select _i;
	_name = toUpper(getText(_place >> "name"));
	_position = getArray (_place >> "position");
	_type = getText(_place >> "type");
	_location = nearestLocation [_position, _type];
	if(_type in _typesToChk) then {
		{
			if (_x in _name) exitWith {_ZnObjects = _ZnObjects + [_location]};
		} forEach _namesToKeep;
	};
};	

{
	_ZnObjects = _ZnObjects + [_x];
} forEach (nearestTerrainObjects [PosOfBLUHQ, ["TRANSMITTER", "FORTRESS"], (zones_max_dist_from_hq*1.2), false,true]);
*/

////////////////////////////////////////////////////////
// Try to use locations in a 135 degree arc from HQ
// - otherwise use 360
///////////////////////////////////////////////////////

if (count(AO_direction) > 0) then {

	_direction = PosOfBLUHQ getDir AO_direction;

	// all locations
	_temp_allLocations = _allLocations;
	_allLocations = [];

	{
		_inArc = [ PosOfBLUHQ, _direction, 135, position _x ] call BIS_fnc_inAngleSector;
		if (_inArc == true) then {_allLocations = _allLocations + [_x]};
	} forEach _temp_allLocations;
	// if not enough locations in the arc, use 360
	if (count _allLocations < 10) then {
		_allLocations = _temp_allLocations;
	};
	
	// Towns and Cities
	_temp_allTowns = _allTowns;
	_allTowns = [];

	{
		_inArc = [ PosOfBLUHQ, _direction, 135, position _x ] call BIS_fnc_inAngleSector;
		if (_inArc == true) then {_allTowns = _allTowns + [_x]};
	} forEach _temp_allTowns;

	// AO DIRECTION FILTER APPLIED
	[{player globalChat localize "STR_DUWS_T_33eyysx9"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

};


/////////////////////////////////////////////////
// Only use locations with enough buildings
/////////////////////////////////////////////////
_temp_allLocations = _allLocations;
_allLocations = [];
{
	_numBuildings = count (nearestTerrainObjects [position _x, ["House"], 100, true]);
	if (_numBuildings > 5) then {_allLocations = _allLocations + [_x]};
} forEach _temp_allLocations;

if (moreUrban == 1) then {
	// URBAN FILTER APPLIED
	[{player globalChat localize "STR_DUWS_T_rb6rlg1b"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
};

["INFO", "ZONES", format ["moreUrban filters done. allLocations=%1 allTowns=%2",
    count _allLocations, count _allTowns]] call fnc_log;
diag_log "BUILDING MASTER_allLocations_filtered";
_temp_Locations_Master = _allLocations call BIS_fnc_arrayShuffle;
_temp_allTowns = _allTowns call BIS_fnc_arrayShuffle;
MASTER_allLocations_filtered = _temp_allTowns + _temp_Locations_Master;
//publicVariable "MASTER_allLocations_filtered";
