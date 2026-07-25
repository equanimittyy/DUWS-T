
_index = lbCurSel 2121;

_group = "";
_grouptype = "";
_HCsquadtype = "";
_cost = "";
_playerName = vehiclevarname player;
_not_enough = false;
_task_force = false;

///////////////////////////////////
// Check which Squad was selected
///////////////////////////////////
switch (VERSION_X) do {
	
	case "MODERN": {	///  8 SQUADS MAX

		if (_index < 2 || _index == 5) exitWith {hint localize "STR_DUWS_T_9607znvh"};
		
		switch (_index) do
		{
			case 2: {
				_cost = blufor_RECON_TEAM_X select 2;
				_grouptype = (blufor_RECON_TEAM_X select 0);
				_HCsquadtype = "Infantry";
			};
			case 3: {
				_cost = blufor_INF_SQUAD_X select 2;
				_grouptype = (blufor_INF_SQUAD_X select 0);
				_HCsquadtype = "Infantry";
			};
			case 4: {
				_cost = blufor_MOTOR_SECTION_X select 2;
				_grouptype = (blufor_MOTOR_SECTION_X select 0);
				_HCsquadtype = "Motor";
			};
	
		//  case 5: EMPTY	

			case 6: {
				_cost = blufor_RECON_TEAM_X select 2;
				_grouptype = (blufor_RECON_TEAM_X select 0);
				_task_force = true;
			};
			case 7: {
				_cost = blufor_INF_SQUAD_X select 2;
				_grouptype = (blufor_INF_SQUAD_X select 0);
				_task_force = true;
			};
			case 8: {
				_cost = blufor_MOTOR_SECTION_X select 2;
				_grouptype = (blufor_MOTOR_SECTION_X select 0);
				_task_force = true;
			};
			case 9: {
				_cost = blufor_MECH_SECTION_X select 2;
				_grouptype = (blufor_MECH_SECTION_X select 0);
				_task_force = true;
			};
			case 10: {
				_cost = blufor_ARMOR_SECTION_X select 2;
				_grouptype = (blufor_ARMOR_SECTION_X select 0);
				_task_force = true;
			};
		};
	};
};	

if (_task_force == true && hardcore_visibleZone_found == false) exitWith {hint localize "STR_DUWS_T_b20y3byh"};

_spawnPos = getpos player;
if (_task_force == true) then {_spawnPos = PosOfBLUHQ;};
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],300,400,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;

_TFname = [1] call fnc_random_name;
sleep 2;

if (commandpointsblu1 >= _cost) then {

	_group = [];
	if (_task_force == true) then {
		[_spawnPos,_grouptype, _TFname] remoteExec ["fnc_playerTF_spawn", 2, false];
	} else {
		_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
		_group deleteGroupWhenEmpty true;
	};
	
	[-_cost] remoteExec ["fnc_cp_adjust", 2];
	
	if (_task_force == true) exitWith {hint localize "STR_DUWS_T_0a6o9dsm"};

	player hcsetgroup [_group,""];
	_group setFormation "STAG COLUMN";

	switch (_HCsquadtype) do
	{
		case "Infantry": {
			DUWS_number_fireteam = DUWS_number_fireteam + 1;
			_group setGroupId [format["Inf %1",DUWS_number_fireteam]];
		};
		case "Motor": {
			DUWS_number_motor = DUWS_number_motor + 1;
			_group setGroupId [format["Motor %1",DUWS_number_motor]];
			_groupLeader = leader _group;
			_veh = vehicle _groupLeader;
			_group addVehicle _veh;
		};
	};
	//add group to players HC array for disconnect event
	_groupName = groupId _group;
	_var = format["%1HC", _playerName];
	_HCgroups = call (compile _var);
	_HCgroups = _HCgroups + [_group];
	missionNamespace setVariable [_var, _HCgroups, true];
  
	hint localize "STR_DUWS_T_gu6cbc5f";
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

} else {
	_not_enough = true;
};

if (_not_enough) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};

if (_task_force == true) exitWith {};
// SQUADS NEED TO SPAWN AWAY FROM HQ THEN MOVE CLOSER
{
	_x allowDamage false;
} forEach (units _group);
sleep 15;
{
	_x allowDamage true;
} forEach (units _group);

_muster = getpos player;
_muster = [(_muster select 0)+100, _muster select 1];
_group setCombatMode "YELLOW";
_wp = _group addWaypoint [_muster, 50];
_wp setWaypointType "MOVE";
_wp setWaypointFormation  "COLUMN";
_wp setWaypointCompletionRadius 100;


