
// FOUND INTEL
if (!hasInterface) exitWith {};
if ((random 10) < (master_Intel_chance + master_Intel_boost)) then {
	_random_zone = selectRandom zone_namePOS_pairs;
	_zonePos = _random_zone select 1;
	
	[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_u18xeu4p"] remoteExec ["fnc_duws_dialogue", 0];

	sleep 5;
	
	if (_random_zone select 2 == false) then {
		["ONE",_zonePos] remoteExec ['fnc_zone_reveal', 2];
	} else {
		[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_8skllpyx"] remoteExec ["fnc_duws_dialogue", 0];
	};

} else {

	sleep 2;
	// Local call, unlike the two lines above: this answers one player's search, and the
	// globalChat it replaced reached only that player's machine.
	[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_b22m11b0"] call fnc_duws_dialogue;

};