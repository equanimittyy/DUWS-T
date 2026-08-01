// Locality: server -- inherited from server/server_init.sqf.
// DUWS_T "More Urban" changes

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
