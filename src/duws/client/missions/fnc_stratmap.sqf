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
                    private _missionName = switch (_type) do {
                        case 0: { localize "STR_DUWS_T_c0" };       // 营救小队
                        case 1: { localize "STR_DUWS_T_c1" };       // 窃取补给
                        case 2: { localize "STR_DUWS_T_c2" };       // 击杀 HVT
                        case 3: {                                         // 摧毁塔
                            switch (VERSION_X) do {
                                case "MODERN":  { localize "STR_DUWS_T_c3" };
                                default         { localize "STR_DUWS_T_c3" };
                            };
                        };
                        case 4: { localize "STR_DUWS_T_c4" };       // 营救飞行员
                        case 5: { localize "STR_DUWS_T_c5" };       // 猎杀狙击手
                        case 6: { localize "STR_DUWS_T_c6" };       // 窃取工程车
                        case 7: { localize "STR_DUWS_T_c7" };       // 击杀装甲 HVT
                        case 8: {                                         // 破坏笔记本/无线电
                            switch (VERSION_X) do {
                                case "MODERN":  { localize "STR_DUWS_T_c8" };
                                default         { localize "STR_DUWS_T_c8" };
                            };
                        };
                        case 9: { localize "STR_DUWS_T_c9" };       // 摧毁弹药库
                        case 10: {                                        // 摧毁雷达
                            switch (VERSION_X) do {
                                case "MODERN":  { localize "STR_DUWS_T_c10" };
                                default         { localize "STR_DUWS_T_c10" };
                            };
                        };
                        case 11: { localize "STR_DUWS_T_c11" }; // 清理区域 CQB
                        case 12: { localize "STR_DUWS_T_c12" }; // 坚守阵地
                        case 13: { localize "STR_DUWS_T_c13" };     // 占领
                        case 14: { localize "STR_DUWS_T_c14" };     // 保护平民
                        case 15: { localize "STR_DUWS_T_c15" };      // 运输 IDAP
                        case 16: { localize "STR_DUWS_T_c16" };      // 突击指挥部
                        default { format ["未知任务 %1", _type] };
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

  // CURRENTLY 15 MISSIONS AVAILABLE, 0 indexed
  _missionConfig = [];
  _missionCount = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
  _missionShuffle = _missionCount call BIS_fnc_arrayShuffle;
  
  while {_counter < count _missionCount} do {

	_progress = 0.1 * _counter;
	progressLoadingScreen _progress;
	
	//////////////////////////////////////////////
	/// DUWS_T "More Urban" changes
	///  - put near a building
	///  - stay away from zone centers
	//////////////////////////////////////////////

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
		
		if (_counter == (count _missionCount)-1) then {failsafe_not_found = false;};
		_currentMission = _missionShuffle select _counter;

		// Add each mission type to stratmap array

        switch (_currentMission) do {

			case 0: { // mission RESCUE SQUAD
				mission0_pos = _foundSafepos;
                mission0_name = [0] call fnc_random_name;
    
                _missionConfig = [
                    mission0_pos,
					{_handle = [mission0_pos,mission0_name] remoteExec ["fnc_rescue_squad_mission", 2]},
                    mission0_name,
                    localize "STR_DUWS_T_kievbwmd",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 1: { // mission STEAL SUPPLY
                mission1_name = [0] call fnc_random_name;
                mission1_pos = _foundSafepos;

                _missionConfig = [
                    mission1_pos,
					{_handle = [mission1_pos,mission1_name] remoteExec ["fnc_steal_supply_mission", 2]},
                    mission1_name,
                    localize "STR_DUWS_T_p7qawzl4",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 2: { // mission TARGET HVT
                mission2_name = [0] call fnc_random_name;
                mission2_pos = _foundSafepos;
    
                _missionConfig = [
                    mission2_pos,
					{_handle = [mission2_pos,mission2_name] remoteExec ["fnc_target_hvt_mission", 2]},
                    mission2_name,
                    localize "STR_DUWS_T_19ajhe1d",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 3: { // mission DESTROY TOWER
                mission3_name = [0] call fnc_random_name;
                mission3_pos = _foundSafepos;

				switch (VERSION_X) do {
					case "MODERN": {  // RADIO TOWER
						_missionConfig = [
							mission3_pos,
							{_handle = [mission3_pos,mission3_name] remoteExec ["fnc_destroy_tower_mission", 2]},
							mission3_name,
							localize "STR_DUWS_T_dgpqenyw",
							"",
							"\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",
							1,
							[]
						];
					};
				};
                array_of_missions = array_of_missions + [_missionConfig];
			};

            case 4: { // mission RESCUE PILOT
                mission4_name = [0] call fnc_random_name;
                mission4_pos = _foundSafepos;
    
                _missionConfig = [
                    mission4_pos,
					{_handle = [mission4_pos,mission4_name] remoteExec ["fnc_rescue_pilot_mission", 2]},
                    mission4_name,
                    localize "STR_DUWS_T_njsu8ofz",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa", 
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 5: { // mission Sniper HUNT
                mission5_name = [0] call fnc_random_name;
                mission5_pos = _foundSafepos;
    
                _missionConfig = [
                    mission5_pos,
					{_handle = [mission5_pos,mission5_name] remoteExec ["fnc_target_sniper_mission", 2]},
                    mission5_name,
                    localize "STR_DUWS_T_16dh939j",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
			
            case 6: { // mission Steal BUILDER
                mission6_name = [0] call fnc_random_name;
                mission6_pos = _foundSafepos;
    
                _missionConfig = [
                    mission6_pos,
					{_handle = [mission6_pos,mission6_name] remoteExec ["fnc_steal_builder_mission", 2]},
                    mission6_name,
                    localize "STR_DUWS_T_czpvn5z1",
					"",
					"\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa",
					1,
					[]
				];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 7: { // mission TARGET ARMOR HVT
                mission7_name = [0] call fnc_random_name;
                mission7_pos = _foundSafepos;
    
                _missionConfig = [
                    mission7_pos,
					{_handle = [mission7_pos,mission7_name] remoteExec ["fnc_target_armor_mission", 2]},
                    mission7_name,
                    localize "STR_DUWS_T_y7z1cx6j",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 8: { // mission SABOTAGE LAPTOP
                mission8_name = [0] call fnc_random_name;
                mission8_pos = _foundSafepos;
    
				switch (VERSION_X) do {
					case "MODERN": {
						_missionConfig = [
							mission8_pos,
							{_handle = [mission8_pos,mission8_name] remoteExec ["fnc_sabotage_laptop_mission", 2]},
							mission8_name,
							localize "STR_DUWS_T_j97ecrsh",
							"",
							"\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",
							1,
							[]
						];
					};
				};
                array_of_missions = array_of_missions + [_missionConfig];
            };

            case 9: { // mission DESTROY AMMO CACHE
                mission9_name = [0] call fnc_random_name;
                mission9_pos = _foundSafepos;
    
                _missionConfig = [
                    mission9_pos,
					{_handle = [mission9_pos,mission9_name] remoteExec ["fnc_destroy_cache_mission", 2]},
                    mission9_name,
                    localize "STR_DUWS_T_geryeddp",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
		
			case 10: { // mission DESTROY RADAR
                mission10_name = [0] call fnc_random_name;
                mission10_pos = _foundSafepos;
    
				switch (VERSION_X) do {
					case "MODERN": {
						_missionConfig = [
							mission10_pos,
							{_handle = [mission10_pos,mission10_name] remoteExec ["fnc_destroy_radar_mission", 2]},
							mission10_name,
							localize "STR_DUWS_T_n4uc7t2x",
							"",
							"\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",
							1,
							[]
						];
						array_of_missions = array_of_missions + [_missionConfig];
					};
				};
			};
            case 11: { // mission CLEAR THE AREA CQB
                mission11_name = [0] call fnc_random_name;
                mission11_pos = _foundSafepos;
    
                _missionConfig = [
                    mission11_pos,
					{_handle = [mission11_pos,mission11_name] remoteExec ["fnc_clearthearea_cqb_mission", 2]},
                    mission11_name,
                    localize "STR_DUWS_T_shentouxiaodui",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
            case 12: { // mission HOLD THE POSITION
                mission12_name = [0] call fnc_random_name;
                mission12_pos = _foundSafepos;
    
                _missionConfig = [
                    mission12_pos,
					{_handle = [mission12_pos,mission12_name] remoteExec ["fnc_holdposition_mission", 2]},
                    mission12_name,
                    localize "STR_DUWS_T_jianshouzhendi",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
            case 13: { // mission DOMINATION
                mission13_name = [0] call fnc_random_name;
                mission13_pos = _foundSafepos;
    
                _missionConfig = [
                    mission13_pos,
					{_handle = [mission13_pos,mission13_name] remoteExec ["fnc_domination_mission", 2]},
                    mission13_name,
                    localize "STR_DUWS_T_domination",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
            case 14: { // mission CIVILIANPROTECTION
                mission14_name = [0] call fnc_random_name;
                mission14_pos = _foundSafepos;
    
                _missionConfig = [
                    mission14_pos,
					{_handle = [mission14_pos,mission14_name] remoteExec ["fnc_protect_civ_mission", 2]},
                    mission14_name,
                    localize "STR_DUWS_T_protectciv",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
            case 15: { // mission TransportIDAP
                mission15_name = [0] call fnc_random_name;
                mission15_pos = _foundSafepos;
    
                _missionConfig = [
                    mission15_pos,
					{_handle = [mission15_pos,mission15_name] remoteExec ["fnc_transport_IDAP_mission", 2]},
                    mission15_name,
                    localize "STR_DUWS_T_transIDAP",
                    "",
                    "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa",
                    1,
                    []
                ];
                array_of_missions = array_of_missions + [_missionConfig];
            };
            case 16: { // 情报搜集任务
            mission16_name = [0] call fnc_random_name;
            mission16_pos = _foundSafepos;
            _missionConfig = [
            mission16_pos,
            {_handle = [mission16_pos, mission16_name] remoteExec ["fnc_intel_gathering_mission", 2]},
             mission16_name,
             localize "STR_DUWS_T_INTEL_GATHERING_DESC",
               "",
               "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa",
               1,
               []
           ];
             array_of_missions = array_of_missions + [_missionConfig];
           };
		};
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

