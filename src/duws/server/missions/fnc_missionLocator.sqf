// Locality: server -- inherited from server/server_init.sqf.
// DUWS_T "More Urban" changes

_half = worldSize / 2;
_safehalf = worldSize / 2.2;  //STAY OFF THE EDGES OF SMALL MAPS
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

waitUntil {sleep 0.1;!isNil "WARCOM_init_done"};
waitUntil {sleep 0.1;WARCOM_init_done};

//_ZnObjects = nearestLocations [PosOfBLUHQ, ["NameCityCapital","NameVillage","NameCity","Name","Hill"], (zones_max_dist_from_hq*1.5)];
_ZnObjects = MASTER_allLocations_filtered;

MissionLocations = [];
{
	if (((getPos _x) distance PosOfBLUHQ) > 1500) then {
		MissionLocations pushBack _x;
	};
} forEach _ZnObjects;
publicVariable "MissionLocations";
