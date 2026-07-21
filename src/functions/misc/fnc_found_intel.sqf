
// FOUND INTEL
if (!hasInterface) exitWith {};
if ((random 10) < (master_Intel_chance + master_Intel_boost)) then {
	_random_zone = selectRandom zone_namePOS_pairs;
	_zonePos = _random_zone select 1;
	
	[localize "STR_DUWS_T_u18xeu4p"] spawn fnc_sideChat_filter;

	sleep 5;
	
	if (_random_zone select 2 == false) then {
		["ONE",_zonePos] remoteExec ['fnc_zone_reveal', 2];
	} else {
		[localize "STR_DUWS_T_8skllpyx"] spawn fnc_sideChat_filter;
	};

} else {

	sleep 2;
	player globalChat localize "STR_DUWS_T_b22m11b0";
	[] remoteExec ["fnc_broadcastRadioChatter", 0];

};