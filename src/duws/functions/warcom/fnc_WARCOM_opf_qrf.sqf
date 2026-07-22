
if (!WARCOM_qrf_ready) exitWith {};

_attachedUnit = _this select 0;
_unitPos = getpos _attachedUnit;

// Make sure zone is OPFOR 
_opforZone = false;
{
	if (_x distance _unitPos < 100) then {_opforZone = true};
} forEach WARCOM_zones_controled_by_OPFOR;
if !(_opforZone) exitWith {};

// Only spawn QRF against players, not AI patrols
_allPlayers = call BIS_fnc_listPlayers;
_players_close = false;
{
	if (_x distance _unitPos < 1000) then {
		_players_close = true;
	};
} forEach _allPlayers;

if (!_players_close) exitWith {};

WARCOM_qrf_ready = false;

_spawnLoc = "";

// Attack waves main

	if (count WARCOM_zones_controled_by_OPFOR > 0) then {	// make sure opfor is controlling at least 1 zones
		sleep 2;
			  
		// find a zone to spawn OPF wave away from zone and player *** BEGIN
		_found = false;
		_randomZone = [];
		_failSafe = 0;
		_spawnMin = 400;
		_spawnMax = 600;

		// sort zones by distance from calling Unit
		_sorted_zones = [WARCOM_zones_controled_by_OPFOR,[_unitPos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;

		while {!_found} do {
			//_randomZone = WARCOM_zones_controled_by_OPFOR call BIS_fnc_selectRandom;
			_randomZone = _sorted_zones select _failsafe;
			if (count WARCOM_zones_controled_by_OPFOR > 1) then {
				if (_randomZone distance _attachedUnit > 1500 && _randomZone distance player > 1500) then {
					_found=true;
				} else {	
					sleep 0.2;
					_failSafe = _failSafe + 1;
					if (_failsafe > (count _sorted_zones)-1) then {   // assume only one zone left, keep spawning reinforcements somewhere
						_spawnMin = 1500;
						_spawnMax = 2000;
						_found = true;
					};
				};
			} else {
				_spawnMin = 1500;
				_spawnMax = 2000;
				_found = true;
			};	
		};
		// find a zone *** END 
		  
		// Find a safe location FAR FROM ZONE CENTER (keeps buggy zone selection from surprising BLUFOR)
		_found = false;
		while {!_found} do {
			_spawnLoc = [[(_randomZone select 0), (_randomZone select 1)],_spawnMin,_spawnMax,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
			if (_spawnLoc distance player > 1500 && _spawnLoc distance WARCOM_blu_hq_pos > 1500) then {
				_found = true;
			};
			sleep 0.1;
		};
		
		_group = "";
		_spawncount = [];
		
		if (count (call BIS_fnc_ListPlayers) > 2) then {
			_spawncount = [1,2,3,4];
		} else {
			_spawncount = [1,2];
		};
		{
			if (WARCOM_opfor_ap>100) then {
				_group = [_spawnLoc, EAST, WARCOM_opf_patrol_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				sleep 5;
				_addgroup = [_spawnLoc, EAST, opfor_INFTEAM_X,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				sleep 5;
				_addgroup deleteGroupWhenEmpty true;
				(units _addgroup) joinSilent _group;
				_groupLeader = leader _group;
				_veh = vehicle _groupLeader;
				_group addVehicle _veh;
				_group deleteGroupWhenEmpty true;
			} else { 
				_group = [_spawnLoc, EAST, WARCOM_opf_patrol_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				_group deleteGroupWhenEmpty true;
			};
			sleep 10; // give squads a chance to mount up
			[_group,_unitPos, _x] spawn fnc_WARCOM_wp_opf_qrf;
			sleep 120;
		} forEach _spawncount;
	};			  
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_opforqrf1";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 900;  // 15 min

WARCOM_qrf_ready = true;
