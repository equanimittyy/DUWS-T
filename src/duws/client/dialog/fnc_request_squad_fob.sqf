// Locality: client -- invoked from a dialog action (shared/includes/request_fob_menu.hpp:88).

_index = lbCurSel 2121;

_grouptype = "";
_HCsquadtype = "";
_cost = 0;
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

// Charge before spawning: the server rules on affordability, so a refused request must
// not leave a squad standing.
if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};

if (_task_force == true) then {
	[_spawnPos,_grouptype, _TFname] remoteExec ["fnc_playerTF_spawn", 2, false];
} else {
	// Spawn, name, register and muster all happen on the server; it hands
	// hcSetGroup back here, since that needs this machine's own player.
	[_spawnPos, _grouptype, _HCsquadtype, player] remoteExec ["fnc_HCsquad_spawn", 2];
};

if (_task_force == true) exitWith {hint localize "STR_DUWS_T_0a6o9dsm"};

hint localize "STR_DUWS_T_gu6cbc5f";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];


