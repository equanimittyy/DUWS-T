// Locality: client; the map-click bodies below run on the machine that triggers them, not here (invoked from a dialog action).

["info",[localize "STR_DUWS_T_ci827d0e",localize "STR_DUWS_T_uof7n8iu"]] call bis_fnc_showNotification;
hint localize "STR_DUWS_T_fcdu8ct2";

random_placement = true;

_found = false;
_foundSafePos = [];

["INFO", "BOOT", "Start fnc_HQ_random_place"] call fnc_log;

_half = worldSize / 2;
_safehalf = worldSize / 2.2;  //STAY OFF THE EDGES OF SMALL MAPS
_mapradius = sqrt 2 * _safehalf;
_mapcenter = [_half, _half, 0];

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
		// DON'T SPAWN ON ROADS
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

// create temp marker on HQ
_markername = "foo";
_markerstr = createMarker [str(_markername), PosOfBLUHQ];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "mil_flag";
str(_markername) setMarkerColor "ColorBlue";

sleep 2;

// wait for AO direction or "ESC"
forceMap false;
[localize "STR_DUWS_T_k9kxtm85"] call fnc_map_prompt;OnMapSingleClick "ClickedPos2 = _pos; clicked = true;";
waituntil {sleep 0.1;clicked or !(visiblemap)};
if (clicked) then {
	AO_direction = ClickedPos2;
	publicVariable "AO_direction";
	// create temp marker on HQ
	_markername2 = "foo2";
	_markerstr2 = createMarker [str(_markername2), AO_direction];
	_markerstr2 setMarkerShape "ICON";
	str(_markername2) setMarkerType "mil_flag";
	str(_markername2) setMarkerColor "ColorRed";
	sleep 2;
	deletemarker str(_markername2);
};	
deletemarker str(_markername);
hint "";
[""] call fnc_map_prompt;
openMap [false, false];
titleCut ["", "BLACK FADED", 999];

// server_init.sqf gates the whole campaign on this flag, so it must be the last thing sent:
// everything it implies is already published above.
chosen_hq_placement = true;
publicVariable "chosen_hq_placement";

