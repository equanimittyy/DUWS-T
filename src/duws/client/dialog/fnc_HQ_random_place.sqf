// Locality: client; the map-click bodies below run on the machine that triggers them, not here (invoked from a dialog action).

["info",[localize "STR_DUWS_T_ci827d0e",localize "STR_DUWS_T_uof7n8iu"]] call bis_fnc_showNotification;
hint localize "STR_DUWS_T_fcdu8ct2";

random_placement = true;

_found = false;
_foundSafePos = [];

["INFO", "BOOT", "Start fnc_HQ_random_place"] call fnc_log;

waitUntil {sleep 0.1;count MASTER_allLocationsPos > 100};
_location_count = count MASTER_allLocationsPos;

while {!_found} do {

	_location = MASTER_allLocationsPos select (floor (random _location_count));
	_foundSafePos = [_location, 200, 500,10,0,0.15,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
	
	_count = 1;
	while {true} do {
		if (_count > 100) exitWith {}; 
		_Building = nearestBuilding _foundSafePos;
		_foundSafePos = [_Building, 50, 100,15,0,0.08,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
		_nearRoad = [_foundSafePos,20] call BIS_fnc_nearestRoad;
		if (_foundSafePos select 0 != 0 &&
			_foundSafePos select 1 != 0 &&
			isNull _nearRoad) exitWith {_found=true};
		_count = _count + 1;	
	};		
};

// Broadcast with the assignment, not at the end of this script. The AO-direction wait below
// blocks on a human map click, and until this lands every other machine still holds the
// server_var_init default of []. Manual placement already publishes at its assignment.
PosOfBLUHQ = _foundSafePos;
publicVariable "PosOfBLUHQ";

titleCut ["", "BLACK IN", 10];
clicked = false;
forceMap true;
mapAnimAdd [3, 1, [5000,5000]];
mapAnimCommit;
sleep 3;
openMap [true, false]; 

// Literal, not localize: a translated log line makes the rpt unreadable to anyone whose
// client language differs from the reader's.
["INFO", "BOOT", format ["HQ random placement found safe pos %1", _foundSafePos]] call fnc_log;
player globalChat format ["foundSafePos: %1", _foundSafePos];

onMapSingleClick "";

[] call fnc_HQ_placement_finish;

