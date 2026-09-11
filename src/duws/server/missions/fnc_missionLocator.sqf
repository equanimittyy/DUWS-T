// Locality: server -- inherited from server/server_init.sqf.

waitUntil {sleep 0.1;!isNil "WARCOM_init_done"};
waitUntil {sleep 0.1;WARCOM_init_done};

// Real town centres only (duws_town_circles, the civ town list from fnc_civ_init_Tomata), not the map-wide
// location set the zone placer uses: the sole reader is fnc_mission_findSite's town survey, whose civ-town
// finders reject anywhere but a registered town. Set synchronously before WARCOM_init_done, so ready here.
MissionLocations = [];
{
	private _p = _x select 0;
	if ((_p distance PosOfBLUHQ) > 1500) then {
		MissionLocations pushBack _p;
	};
} forEach (missionNamespace getVariable ["duws_town_circles", []]);
publicVariable "MissionLocations";
