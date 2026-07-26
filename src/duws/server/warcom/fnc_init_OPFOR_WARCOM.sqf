
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

// Civilian towns are chosen from the zones, so generation is a step of zone placement rather
// than a separate race against it. This is the one point both the random and the manual
// locator funnel through on the server, so the kick-off lives here instead of in each path.
// Spawned: WARCOM below must not wait for build-out. Counted against serv_zones_array, not
// zones_number -- the origin keep-out in fnc_locatorzones_random can drop a zone slot, and a
// zones_number target would then never be reached.
[] spawn {
    while {!(["CIV", "all zones built out",
        {zones_buildout_done >= count serv_zones_array}, 300] call fnc_waitLogged)} do {};
    if (!isNil "CIV_PRESENCE" && {CIV_PRESENCE != "NONE"}) then { [] call fnc_civ_init_Tomata; };
};

////////////////////////////////////////
//  INIT WARCOM FOR BLUFOR AND OPFOR
////////////////////////////////////////
["INFO", "WARCOM", "Opfor Warcom Start WARCOM zone patrols."] call fnc_log;

[serv_zones_array, PosOfBLUHQ, [0,0,0], WARCOM_blufor_ap, WARCOM_opfor_ap, 1800, blufor_ai_skill, opfor_ai_skill, 1800] spawn fnc_WARCOM_init; // 2700 is 40 mins
while {!(["WARCOM", "WARCOM_init_done", {WARCOM_init_done}, 300] call fnc_waitLogged)} do {};
sleep 1;