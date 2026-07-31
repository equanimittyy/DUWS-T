// [[zones],posHQblu,posHQop,blufor AP,opfor AP, blu attack delay, blu skill range, opfor skill range, opf attack delay] spawn fnc_WARCOM_init
//               |         |     |        |          |            |
//         array of arrays |   array      |        number         |
//                      array           number                  number
if (!isServer) exitWith {};
[{player globalChat localize "STR_DUWS_T_jl4gqjpf"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

_array_of_zones_total =_this select 0;
_blu_hq_pos =_this select 1;
_op_hq_pos =_this select 2;
_blufor_ap =_this select 3;
_opfor_ap =_this select 4;
_blu_attack_delay =_this select 5;
_blu_ai_skill_range =_this select 6;
_opfor_ai_skill = _this select 7;
_opfor_assault_delay = _this select 8;


// INIT VARIABLES
// WARCOM uses PosOfBLUHQ+16m to keep waypoints and spawn points away from HQ building
WARCOM_blu_hq_pos = [_blu_hq_pos select 0, (_blu_hq_pos select 1) + 16];
WARCOM_blufor_ap = _blufor_ap;    
WARCOM_opfor_ap = _opfor_ap;
WARCOM_blu_attack_delay = _blu_attack_delay;
WARCOM_marker_num = 0;
publicVariable "WARCOM_blufor_ap";
publicVariable "WARCOM_opfor_ap";
publicVariable "WARCOM_blu_hq_pos";

sleep 5;

// SORT ARRAY OF OPFOR ZONES ACCORDING TO DISTANCE FROM BLUHQ 
WARCOM_createdZones = [_array_of_zones_total,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
publicVariable "WARCOM_createdZones";

// ARRAY OF ZONES UNDER BLUFOR CONTROL
WARCOM_zones_controled_by_BLUFOR = [];
publicVariable "WARCOM_zones_controled_by_BLUFOR";

// ARRAY OF ZONES UNDER OPFOR CONTROL 
// make sure it's not a reference
_WARCOM_zones_controled_by_OPFOR = WARCOM_createdZones;
WARCOM_zones_controled_by_OPFOR = [] + _WARCOM_zones_controled_by_OPFOR;
publicVariable "WARCOM_zones_controled_by_OPFOR";

[{player globalChat localize "STR_DUWS_T_42esdbvb"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

// Init BLU patrols
["INFO", "WARCOM", "Init BLU patrols"] call fnc_log;
[] spawn fnc_WARCOM_blu_patrol;

// Initialize the BLU attack waves
["INFO", "WARCOM", "Initialize the BLU attack waves"] call fnc_log;
[] spawn fnc_WARCOM_blu_assault;

// Nothing spawns OPFOR here any more. The roaming patrols, the attack waves and the random air
// were three timers each dropping live groups on the map for the rest of the campaign, answering
// to Army Power alone rather than to anything the enemy was trying to achieve -- and they are what
// put permanently simulated AI between the zones and on the road to the BLUFOR HQ. Enemy presence
// is zone garrisons and side-mission guards until an OPFOR commander decides it.

WARCOM_init_done = true;
publicVariable "WARCOM_init_done";

[{player globalChat localize "STR_DUWS_T_zc9z2znr"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];



