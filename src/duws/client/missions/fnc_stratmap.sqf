// Locality: client -- invoked from a dialog action.


///// DUWS_T  RERUN THE OPFOR FACTION FILE FOR JIP SIDE MISSION GEN
if (hasInterface && isMultiplayer)	then {
	[] call fnc_OPFOR_FactionFile_X;
	sleep 1;
};

if (isnil ("Mission_available")) then {Mission_available = true;publicVariable "Mission_available"};
if (!Mission_available) exitWith {
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_missioncooldown"] call fnc_cs);
_message1 = localize "STR_DUWS_T_missioncooldown2";
[localize "STR_DUWS_T_b68ftbvf",{hint _this}] remoteExec ["BIS_fnc_Spawn", player1];
[_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
};

if (!((vehiclevarname player) in game_master)) exitWith {hint ([localize "STR_DUWS_T_eck4xh9m"] call fnc_cs)};

// ==================== 任务冷却监控（服务器端） ====================
if (isServer && isNil "missionCooldownMonitorRunning") then {
    missionCooldownMonitorRunning = true; // 防止重复启动
    [] spawn {
        // Included inside the block, not above it: a spawned block captures no locals.
        private _defs = [
        #include "..\..\shared\includes\mission_types.hpp"
        ];
        private _wasInCooldown = []; // 记录每个任务是否曾处于冷却中
        for "_i" from 0 to 16 do {
            _wasInCooldown pushBack false;
        };
        while {true} do {
            private _currentTime = diag_tickTime;
            {
                private _type = _forEachIndex;
                private _cooldown = missionNamespace getVariable [format ["mission_cooldown_%1", _type], 0];
                private _inCooldown = _cooldown > _currentTime;

                // 如果当前处于冷却中，标记为 true
                if (_inCooldown) then {
                    _wasInCooldown set [_type, true];
                };

                // 如果之前标记过在冷却中，但现在不在冷却中，说明刚刚结束
                if (!_inCooldown && (_wasInCooldown select _type)) then {
                    // 获取该任务类型的本地化名称
                    private _missionName = if (_type < count _defs) then {
                        localize ((_defs select _type) select 1)
                    } else {
                        format ["未知任务 %1", _type]
                    };
                    // 发送通知
                    ["info", [localize "STR_DUWS_T_MISSION_READY1", format [localize "STR_DUWS_T_MISSION_READY", _missionName] ]] remoteExec ["BIS_fnc_showNotification", 0];
                    // 重置标记
                    _wasInCooldown set [_type, false];
                };
            } forEach _wasInCooldown; // 遍历数组，利用 _forEachIndex 作为任务类型
            sleep 10; // 每10秒检查一次
        };
    };
};
// ==================== 监控代码结束 ====================

// init the array of missions
array_of_missions = [];

failsafe_not_found = true;
failsafe_not_found2 = false;
_failsafe2 = [] spawn {  // Spawn the secondary failsafe
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
		
		// STAY AWAY FROM CENTER OF ZONES
		_zonesArray = WARCOM_zones_controled_by_OPFOR + WARCOM_zones_controled_by_BLUFOR;
		for [{_t=1}, {_t <= count _zonesArray}, {_t=_t+1}] do 
		{                                         
			// get the index of the element
			_zonesArray_index = _t-1;
			_distance = (_zonesArray select _zonesArray_index) distance (_foundSafePos);
			if (_distance < (zones_max_radius*0.75)) then {_Posfound = false};
		};
		
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
endLoadingScreen;
terminate _handle;

if (failsafe_not_found == true) exitWith {hint localize "STR_DUWS_T_crtzxs0j"};

hint localize "STR_DUWS_T_mission_selector_title";

// NOW OPEN THE MAP
_isNight = false;
if ((20 < daytime) OR (daytime < 5)) then {_isNight=true};

// https://community.bistudio.com/wiki/BIS_fnc_StrategicMapOpen
// 0: DISPLAY - parent display. When empty, mission display is used.
// 1: ARRAY - default view position in format [x,y,y] or [x,y]
// 2: ARRAY - list of missions in format:
// 3: ARRAY - list of ORBAT groups in format:
// 4: ARRAY - list of markers revealed in strategic map (will be hidden when map is closed)
// 5: ARRAY - list of custom images in format:
// 6: NUMBER - value in range <0-1> defining weather on strategic map (i.e. density of clouds)
// 7: BOOL - true for night version of strategic map (darker with blue tone)

[(findDisplay 46), getpos player, array_of_missions, [], [], [], 1, _isNight] call BIS_fnc_strategicMapOpen;

