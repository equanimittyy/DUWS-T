
/////////////////////
//  DO THE ZONES
/////////////////////
if (!isServer) exitWith {};
["INFO", "WARCOM", format ["Opfor Warcom Start Zone Placement. Manual: %1",  manually_chosen]] call fnc_log;

 if (!manually_chosen) then {
	if (!zones_created) then {      // CHECK IF ZONES ALREADY PLACED,  RANDOM
		[50,0.2] spawn fnc_locatorZones_random; 
    };
 } else {
    if (!zones_created) then {      // CHECK IF ZONES ALREADY PLACED,  MANUAL
		[50,0.2] remoteExec ["fnc_locatorZones_manual", player1, false];
    };
 };

//Execution Order requires zone bonus and reward before WARCOM INIT
// Spawned exactly once, so territory income does not stack per zone captured.
[] spawn fnc_zonesundercontrol;

while {!(["ZONES", "serv_zones_array populated by the zone locator", {count serv_zones_array > 0}, 300] call fnc_waitLogged)} do {};
sleep 1;
["INFO", "WARCOM", "Opfor Warcom Zones Placement Complete."] call fnc_log;
sleep 1;
["INFO", "WARCOM", format ["Opfor Warcom serv_zones_array: %1", serv_zones_array]] call fnc_log;


////////////////////////////////////////
//  INIT WARCOM FOR BLUFOR AND OPFOR
////////////////////////////////////////
["INFO", "WARCOM", "Opfor Warcom Start WARCOM zone patrols."] call fnc_log;

[serv_zones_array, PosOfBLUHQ, [0,0,0], WARCOM_blufor_ap, WARCOM_opfor_ap, 1800, blufor_ai_skill, opfor_ai_skill, 1800] spawn fnc_WARCOM_init; // 2700 is 40 mins
while {!(["WARCOM", "WARCOM_init_done", {WARCOM_init_done}, 300] call fnc_waitLogged)} do {};
sleep 1;