// [[zones],posHQblu,posHQop,blufor AP,opfor AP, blu attack delay, blu skill range, opfor skill range, opf attack delay] spawn fnc_WARCOM_init
//               |         |     |        |          |            |
//         array of arrays |   array      |        number         |
//                      array           number                  number
if (!isServer) exitWith {};
[{player globalChat localize "STR_DUWS_T_jl4gqjpf"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

_array_of_zones_total =_this select 0;
_blu_hq_pos =_this select 1;
_blufor_ap =_this select 3;
_opfor_ap =_this select 4;
_blu_attack_delay =_this select 5;


// INIT VARIABLES
// WARCOM uses PosOfBLUHQ+16m to keep waypoints and spawn points away from HQ building
WARCOM_blu_hq_pos = [_blu_hq_pos select 0, (_blu_hq_pos select 1) + 16];
// The preset seeds both halves from the same value: the earned counter (the ladder input, and the
// tier derived from it) and the spendable wallet. A side set to start at a tier begins with the wallet
// to act at it -- OPCOM can fortify, BLUFOR can field -- instead of idling at capability it cannot pay
// for until income accrues. The earned counter is the one-way ratchet; the wallet is spent from here.
WARCOM_blufor_ap_earned = _blufor_ap;
WARCOM_opfor_ap_earned = _opfor_ap;
WARCOM_blufor_tier = [_blufor_ap] call DUWS_fnc_ap_tier;
WARCOM_opfor_tier = [_opfor_ap] call DUWS_fnc_ap_tier;
WARCOM_blufor_ap = _blufor_ap;
WARCOM_opfor_ap = _opfor_ap;
WARCOM_blu_attack_delay = _blu_attack_delay;
WARCOM_marker_num = 0;
publicVariable "WARCOM_blufor_ap";
publicVariable "WARCOM_opfor_ap";
publicVariable "WARCOM_blufor_ap_earned";
publicVariable "WARCOM_opfor_ap_earned";
publicVariable "WARCOM_blufor_tier";
publicVariable "WARCOM_opfor_tier";
publicVariable "WARCOM_blu_hq_pos";

sleep 5;

// SORT ARRAY OF OPFOR ZONES ACCORDING TO DISTANCE FROM BLUHQ
WARCOM_createdZones = [_array_of_zones_total,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
publicVariable "WARCOM_createdZones";

// Campaign-size throttle, from the ACTUAL count rather than the requested zones_number (generation
// can fall short). At or below the reference size the factor is 1 and nothing throttles; above it
// total passive income at full control grows as sqrt(zones), so four times the zones pay twice the
// passive income, not four -- which is what stops a host's high zones_number from handing everyone a
// proportionally larger war chest. k toward 1 flattens income across sizes, toward 0 restores the
// linear payout. Both are the tuning surface.
private _REF_ZONES = 6;
private _k = 0.5;
DUWS_econ_throttle = (_REF_ZONES / ((count WARCOM_createdZones) max _REF_ZONES)) ^ _k;
["INFO", "ECON", format ["econ throttle %1 for %2 zones", DUWS_econ_throttle, count WARCOM_createdZones]] call fnc_log;

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

// OPCOM's hardpoint director: the one thing that spawns OPFOR after generation, and the reader the
// AP pool and the stored zone caps were built waiting for. It spends OPFOR Army Power to fortify the
// ground the enemy holds -- topping up cleared zone emplacements, thickening the band, raising radio
// towers -- replacing the blind AP-timers this init deleted with something the enemy is trying to do.
["INFO", "WARCOM", "Init OPCOM hardpoint director"] call fnc_log;
[] spawn fnc_WARCOM_opf_hardpoints;

// None of the old blind OPFOR timers run here any more. The roaming patrols, the attack waves and the
// random air were three timers each dropping live groups on the map for the rest of the campaign,
// answering to Army Power alone rather than to anything the enemy was trying to achieve -- and they
// are what put permanently simulated AI between the zones and on the road to the BLUFOR HQ. Enemy
// presence is now zone garrisons, side-mission guards and OPCOM's deliberate fortification above:
// emplacements it sites and pays for, not live groups a clock drips onto the map.

WARCOM_init_done = true;
publicVariable "WARCOM_init_done";

[{player globalChat localize "STR_DUWS_T_zc9z2znr"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];



