// Locality: server -- inherited from init/server_init.sqf.

// ZONE SIZE FUNCTIONS

fnc_100_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;

};

fnc_250_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;

	if (count (call BIS_fnc_listPlayers) > 2) then {
		[_spawnPos, _size] spawn fnc_createoppatrol2;
		sleep 5;
		[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
		sleep 5;
	} else {
		[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;
	};	

};

fnc_500_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;

	if (count (call BIS_fnc_listPlayers) > 2) then {
		[_spawnPos, _size] spawn fnc_createopteam2;
		sleep 5;
		[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	};

};

fnc_1000_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"air",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;

	if (count (call BIS_fnc_listPlayers) > 2) then {
		[_spawnPos, _size] spawn fnc_createoppatrol2;
		sleep 5;
		[_spawnPos, _size] spawn fnc_createopteam2;
		sleep 5;
		[_spawnPos, _size] spawn fnc_createopwpteam;
		sleep 5;
		[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	};

};

fnc_1500_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"air",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;

	if (count (call BIS_fnc_listPlayers) > 2) then {
		[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
		sleep 5;
		[_spawnPos, _size] spawn fnc_createopteam2;
		sleep 5;
		[_spawnPos, _size] spawn fnc_createopwpteam;
		sleep 5;
		[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	};

};

fnc_1501_zone = {

	params ["_spawnPos","_size"];

	[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol_sniper;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopwpteam;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createopteam2;
	sleep 5;
	[_spawnPos, _size] spawn fnc_createoppatrol2;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"armored",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"air",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"air",_spawnPos,_size] spawn fnc_random_veh;
	sleep 5;
	[OPFOR_Faction_X,"car",_spawnPos,_size] spawn fnc_random_veh;
};
