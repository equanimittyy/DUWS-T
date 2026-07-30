

// DUWS_T "More Urban" changes
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
private _tStage = diag_tickTime;
// Create a list of locations on the map using distance from HQ
{
	if (PosOfBLUHQ distance _x < zones_max_dist_from_hq) then {
		_allLocations pushBack _x;
	};
} forEach _temp_allLocations;

// Create a list of Cities and Towns using distance from HQ
{
	if (PosOfBLUHQ distance _x < zones_max_dist_from_hq) then {
		_allTowns pushBack _x;
	};
} forEach _temp_allTowns;

["INFO", "ZONES", format ["moreUrban distance filter: %1 -> %2 locs, %3 -> %4 towns, %5s",
    count _temp_allLocations, count _allLocations, count _temp_allTowns, count _allTowns,
    round (diag_tickTime - _tStage)]] call fnc_log;
_tStage = diag_tickTime;
// ZONE DISTANCE FILTER APPLIED.
[{player globalChat localize "STR_DUWS_T_8q8zqlf0"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

if (count(AO_direction) > 0) then {

	_direction = PosOfBLUHQ getDir AO_direction;

	// all locations
	_temp_allLocations = _allLocations;
	_allLocations = [];

	{
		_inArc = [ PosOfBLUHQ, _direction, 135, position _x ] call BIS_fnc_inAngleSector;
		if (_inArc) then {_allLocations pushBack _x};
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
		if (_inArc) then {_allTowns pushBack _x};
	} forEach _temp_allTowns;

	// AO DIRECTION FILTER APPLIED
	[{player globalChat localize "STR_DUWS_T_33eyysx9"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

};


["INFO", "ZONES", format ["moreUrban arc filter: %1 locs, %2 towns, %3s",
    count _allLocations, count _allTowns, round (diag_tickTime - _tStage)]] call fnc_log;
_tStage = diag_tickTime;

// The dominant cost of zone generation: one nearestTerrainObjects sweep per surviving
// candidate, and the pass is linear in that count. What swings it is the arc filter, whose
// yield depends on where HQ landed -- the same 15 km radius has produced both 1144 and 5909
// candidates, so this count is the figure to compare across a fast and a slow run.
["INFO", "ZONES", format ["moreUrban building filter over %1 candidates -- the slow pass",
    count _allLocations]] call fnc_log;
_temp_allLocations = _allLocations;
_allLocations = [];
// The setup phase forces the map open, and hint/globalChat both render *beneath* it -- a
// progress message sent that way is invisible until the map closes, then the whole run
// arrives as one burst. fnc_map_prompt draws on findDisplay 12 itself, so it is the only
// channel a player actually sees during this pass.
private _total = count _temp_allLocations;
private _lastPing = 0;
private _next = 0;
private _sweepTime = 0;
while {_next < _total} do {
	// Batched inside isNil, whose code the engine runs unscheduled and uninterrupted. A
	// scheduled loop only gets the ~3 ms per frame rationed across every script running at
	// boot, which measured out at about one candidate per frame -- 5909 took 114 s. isNil
	// shares this scope, so the cursor and output array are the ones declared above.
	private _t0 = diag_tickTime;
	isNil {
		// Frame budget, not a candidate count: per-sweep cost varies with the terrain around
		// each site, and clients sit in the setup screens waiting on the server.
		private _deadline = diag_tickTime + 0.015;
		while {_next < _total && {diag_tickTime < _deadline}} do {
			private _location = _temp_allLocations select _next;
			// sorted=false: only the count is read, so ranking every hit by distance is pure
			// waste on the hottest call in zone generation -- one sweep per candidate.
			if (count (nearestTerrainObjects [position _location, ["House"], 100, false]) > 5)
				then {_allLocations pushBack _location};
			_next = _next + 1;
		};
	};
	_sweepTime = _sweepTime + (diag_tickTime - _t0);

	// Throttled by time, not by index: candidate counts swing by an order of magnitude with
	// the chosen radius, so a fixed every-Nth would be silent on small maps and spam on big.
	if (diag_tickTime - _lastPing > 1.5) then {
		_lastPing = diag_tickTime;
		[format ["Generating zones...<br/>surveying terrain  %1%2  (%3 of %4 sites)",
			round (100 * _next / (1 max _total)), "%", _next, _total]]
			remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
	};

	// Hand the frame back explicitly: the scheduler would suspend us anyway once a batch blew
	// its slice, but relying on that makes a server freeze the failure mode if it ever won't.
	sleep 0;
};

// Each phase owns its own banner: the zone locator sets its own progress next, and the
// manual placement path sets none at all, so leave nothing of ours on screen either way.
[""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

if (moreUrban == 1) then {
	// URBAN FILTER APPLIED
	[{player globalChat localize "STR_DUWS_T_rb6rlg1b"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
};

// Wall vs sweeping splits the two possible costs: converging means the engine lookups are
// the floor and only cutting candidates helps; a wide gap means frames still go elsewhere.
["INFO", "ZONES", format ["moreUrban filters done. allLocations=%1 allTowns=%2, building pass %3s wall / %4s sweeping",
    count _allLocations, count _allTowns, round (diag_tickTime - _tStage),
    round (_sweepTime * 10) / 10]] call fnc_log;
_temp_Locations_Master = _allLocations call BIS_fnc_arrayShuffle;
_temp_allTowns = _allTowns call BIS_fnc_arrayShuffle;
MASTER_allLocations_filtered = _temp_allTowns + _temp_Locations_Master;
//publicVariable "MASTER_allLocations_filtered";
