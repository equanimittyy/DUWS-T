
/////////////////////
//  DO THE ZONES
/////////////////////
if (!isServer) exitWith {};
diag_log format ["Opfor Warcom Start Zone Placement. Manual: %1",  manually_chosen];

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
if (DUWS_MODE != "DOMINATION") then {
	[] spawn fnc_zonesundercontrol;
};

waitUntil {sleep 0.1;count serv_zones_array > 0};
sleep 1;
diag_log format ["Opfor Warcom Zones Placement Complete."];
sleep 1;
diag_log format ["Opfor Warcom serv_zones_array: %1", serv_zones_array];


////////////////////////////////////////
//  INIT WARCOM FOR BLUFOR AND OPFOR
////////////////////////////////////////
diag_log format ["Opfor Warcom Start WARCOM zone patrols."];

[serv_zones_array, PosOfBLUHQ, [0,0,0], WARCOM_blufor_ap, WARCOM_opfor_ap, 1800, blufor_ai_skill, opfor_ai_skill, 1800] spawn fnc_WARCOM_init; // 2700 is 40 mins
waitUntil {sleep 0.1;WARCOM_init_done};
sleep 1;