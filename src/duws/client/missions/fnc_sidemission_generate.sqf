// Locality: client. Ensures array_of_missions and DUWS_missionSlots hold a batch of side
// missions, running the safe-pos search when the cache is empty and reusing the cached batch
// otherwise. Returns true when a batch is ready, false when the search failed to place any.
//
// The batch is cached in uiNamespace, not missionNamespace: it is display-scoped session state
// and must not serialise into a save. The same seven missions must survive a map close/reopen
// and the sidebar toggle; only launching one clears the cache (fnc_mission_launch), so the next
// call draws a fresh set once a mission is allowed again.
//
// The gates that decide whether a batch may be drawn at all (a mission already active,
// game-master rights) stay with the caller: fnc_stratmap and the map picker refuse differently
// -- one over the request menu, one over the open map -- and this returns only whether a batch
// exists to show.

if (!hasInterface) exitWith { false };

private _cache = uiNamespace getVariable ["DUWS_sideMissionCache", []];
if (_cache isNotEqualTo []) exitWith {
	array_of_missions = _cache select 0;
	DUWS_missionSlots = _cache select 1;
	true
};

// JIP clients rebuild the OPFOR faction file before a search, so a late joiner generates
// missions against the same faction data the host holds. Only on a real search, not a cache hit.
if (isMultiplayer) then {
	[] call fnc_OPFOR_FactionFile_X;
	sleep 1;
};

// init the array of missions
array_of_missions = [];

failsafe_not_found = true;
failsafe_not_found2 = false;
[] spawn {  // Spawn the secondary failsafe
	uiSleep 20;
	failsafe_not_found2 = true;
};

_handle = [] spawn {  // Spawn the MAIN SEARCH

  _counter = 0;
  [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_missionlook"] remoteExec ["fnc_duws_dialogue", 0];
  _kibot_pos_array_missionPos = [[-99999,-99999,-99999]];

  // Included inside the block, not above it: a spawned block captures no locals.
  private _missionDefs = [
  #include "..\..\shared\includes\mission_types.hpp"
  ];
  // Positions and names the launcher blocks read back, one slot per type. A global because the
  // blocks run later, from the map, and capture nothing.
  DUWS_missionSlots = [];
  { DUWS_missionSlots pushBack [] } forEach _missionDefs;

  _missionCount = [];
  { _missionCount pushBack _forEachIndex } forEach _missionDefs;
  _missionShuffle = _missionCount call BIS_fnc_arrayShuffle;
  // Seven drawn from the shuffled seventeen, not all of them. Every candidate costs a
  // BIS_fnc_findSafePos search before it can be offered, so the full pool spent that search
  // ten extra times to build a list no one reads to the bottom of.
  _missionDraw = 7 min (count _missionCount);

  while {_counter < _missionDraw} do {

	// Proportional to the draw, not a fixed 0.1 a step: that constant was sized for the old
	// full-pool loop and would now stall the bar at 0.6.
	_progress = _counter / _missionDraw;
	progressLoadingScreen _progress;

	// DUWS_T "More Urban": near a building, clear of zone centres.

	_Posfound = false;
	_ZnLocation = [];
	_foundSafePos = [];

	while {!_Posfound} do {

		if (moreUrban == 1 && failsafe_not_found2 == false) then {
			// MORE URBAN
			_ZnAnchor = position (MissionLocations select (floor (random (count MissionLocations))));
			_ZnLocation = [_ZnAnchor, 100, 400,10,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			_Building = nearestBuilding _ZnLocation;
			_foundSafePos = [(getpos _Building select 0),(getpos _Building select 1)];
		}else{
			// LESS URBAN
			_foundSafePos = [PosOfBLUHQ, 0, (zones_max_dist_from_hq*1.5),5,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
		};

		_Posfound = true;

		// Clear of every zone, by the zone's own radius rather than the campaign ceiling. The 400 m
		// on top is roughly what a mission's objective drifts from the anchor offered here
		// (fnc_missionTargetPos), so an anchor accepted a metre outside a zone does not hand that
		// thread fifty rejections and an abort. The drifted position is tested again there, which is
		// the test that actually decides; this one only keeps the offer off a zone.
		if ([_foundSafePos, 400] call fnc_pos_claimed) then {_Posfound = false};

	};

	// CREATE AN ARRAY OF POSSIBLE POSITIONS
    _found_dist_away = true;
    _kibot_distances_array = [];
    // for each element of the array of safe positions,
    for [{_t=1}, {_t <= count _kibot_pos_array_missionPos}, {_t=_t+1}] do
    {
        // get the index of the element
        _kibot_pos_array_missionPos_index = _t-1;
        // create an array of all missionPos distances to current _foundSafePos.
        _kibot_distances_array = _kibot_distances_array +[(_kibot_pos_array_missionPos select _kibot_pos_array_missionPos_index) distance (_foundSafePos)];
    };
    // for each element of the array of distances we just generated...
    for [{_t=1}, {_t<=count _kibot_distances_array}, {_t=_t+1}] do
    {
        // get the index of the tested element
        _kibot_distances_array_index = _t-1;
        // select an element with index so we can check it
        _check = (_kibot_distances_array select _kibot_distances_array_index);
        // check the distances contained in the distances array 1 by 1. If a distance is inferior to defined values, dump it.
        if (_check < 250) then {
            // If any mission is <250m away, tell it to this variable;
            _found_dist_away = false;
        };
    };

    if (_foundsafePos distance player > 1500
        && _found_dist_away
        && _foundsafePos distance hq_blu1 < (zones_max_dist_from_hq*1.5)) then {

        // A VALID POS HAS BEEN FOUND add the position to the array of missionPos
        _kibot_pos_array_missionPos = _kibot_pos_array_missionPos + [_foundSafePos];

		// Clears against the draw, not the pool: the loop stops at _missionDraw, so comparing
		// with the full pool size leaves the failsafe armed and aborts every request.
		if (_counter == _missionDraw-1) then {failsafe_not_found = false;};
		_currentMission = _missionShuffle select _counter;

		// Add each mission type to stratmap array. The row supplies the description, the icon and
		// the launcher; the search supplies the position and the name, which go into the shared
		// slot array the launcher reads back.
		(_missionDefs select _currentMission) params ["", "", "_desc", "_icon", "", "_launcher"];
		private _name = [0] call fnc_random_name;
		DUWS_missionSlots set [_currentMission, [_foundSafepos, _name]];

		array_of_missions pushBack [
			_foundSafepos,
			_launcher,
			_name,
			localize _desc,
			"",
			_icon,
			1,
			[]
		];

        _counter = _counter + 1;
	};
  };
  missionSearchDone = 1;
};

_maxTime = diag_tickTime + 60; // max 60s of loadingscreen before failsafe aborts
startLoadingScreen [localize "STR_DUWS_T_dmfmwmfp"];
waitUntil { uiSleep .01; !isNil "missionSearchDone" || diag_tickTime > _maxTime };
missionSearchDone = nil;
terminate _handle;
endLoadingScreen;

if (failsafe_not_found) exitWith { false };

uiNamespace setVariable ["DUWS_sideMissionCache", [array_of_missions, DUWS_missionSlots]];
true
