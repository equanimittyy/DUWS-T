// Locality: server -- inherited from server/server_init.sqf.
// DUWS_T "More Urban" changes

waitUntil {sleep 0.1;!isNil "WARCOM_init_done"};
waitUntil {sleep 0.1;WARCOM_init_done};

_ZnObjects = MASTER_allLocations_filtered;

// Store each location's position, not the LOCATION object: this global is publicVariable'd and
// saved, and LOCATION has no fast serializer -- carrying the handles logged one slow generic
// serialization write per entry, every broadcast and save. The only reader (the town survey in
// fnc_mission_findSite) wants the position anyway.
MissionLocations = [];
{
	private _p = getPos _x;
	if ((_p distance PosOfBLUHQ) > 1500) then {
		MissionLocations pushBack _p;
	};
} forEach _ZnObjects;
publicVariable "MissionLocations";
