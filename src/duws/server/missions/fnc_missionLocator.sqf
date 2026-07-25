// Locality: server -- inherited from init/server_init.sqf.
////////////////////////////////
/// DUWS_T "More Urban" changes
////////////////////////////////

_half = worldSize / 2;
_safehalf = worldSize / 2.2;  //STAY OFF THE EDGES OF SMALL MAPS
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

waitUntil {sleep 0.1;!isNil "WARCOM_init_done"};
waitUntil {sleep 0.1;WARCOM_init_done};

//_ZnObjects = nearestLocations [PosOfBLUHQ, ["NameCityCapital","NameVillage","NameCity","Name","Hill"], (zones_max_dist_from_hq*1.5)];
_ZnObjects = MASTER_allLocations_filtered;

/*
_placesCfg = configFile >> "CfgWorlds" >> worldName >> "Names";
_namesToKeep = ["MILITARY","CAMP","FOB","OUTPOST","FACTORY","POWER","TRAIN","AIRFIELD","AIRSTRIP","DAM","CASTLE","STORAGE","WAREHOUSE","LUMBER","HOSPITAL","BRIDGE"];
_typesToChk =["NameLocal", "ViewPoint", "NameMarine", "Strategic", "StrongPointArea"];
_places = [];
for "_i" from 0 to (count _placesCfg)-1 do {
	_place = _placesCfg select _i;
	_name = toUpper(getText(_place >> "name"));
	_position = getArray (_place >> "position");
	_type = getText(_place >> "type");
	_location = nearestLocation [_position, _type];
//	if((_type in _typesToChk) && (_name in _namesToKeep))then {
	if(_type in _typesToChk) then {
		{
			if (_x in _name) exitWith {_ZnObjects = _ZnObjects + [_location]};
		} forEach _namesToKeep;
	};
};	

{
	_ZnObjects = _ZnObjects + [_x];
} forEach (nearestTerrainObjects [PosOfBLUHQ, ["TRANSMITTER", "FORTRESS"], (zones_max_dist_from_hq*1.5), false,true]);
*/

MissionLocations = [];
{
	if (((getPos _x) distance PosOfBLUHQ) > 1500) then {
		MissionLocations pushBack _x;
	};
} forEach _ZnObjects;
publicVariable "MissionLocations";
