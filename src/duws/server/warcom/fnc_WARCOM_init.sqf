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

WARCOM_createdZones = [_array_of_zones_total,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
publicVariable "WARCOM_createdZones";

// Campaign-size income throttle, from the ACTUAL zone count (generation can fall short of zones_number).
// At or below the reference size the factor is 1; above it, passive income grows as sqrt(zones), so 4x the
// zones pay 2x -- stopping a host's high zones_number from handing everyone a proportionally larger war
// chest. k tunes the curve (1 flattens across sizes, 0 restores linear).
private _REF_ZONES = 6;
private _k = 0.5;
DUWS_econ_throttle = (_REF_ZONES / ((count WARCOM_createdZones) max _REF_ZONES)) ^ _k;
["INFO", "ECON", format ["econ throttle %1 for %2 zones", DUWS_econ_throttle, count WARCOM_createdZones]] call fnc_log;

WARCOM_zones_controled_by_BLUFOR = [];
publicVariable "WARCOM_zones_controled_by_BLUFOR";

// make sure it's not a reference
_WARCOM_zones_controled_by_OPFOR = WARCOM_createdZones;
WARCOM_zones_controled_by_OPFOR = [] + _WARCOM_zones_controled_by_OPFOR;
publicVariable "WARCOM_zones_controled_by_OPFOR";

[{player globalChat localize "STR_DUWS_T_42esdbvb"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

["INFO", "WARCOM", "Init BLU patrols"] call fnc_log;
[] spawn fnc_WARCOM_blu_patrol;

// OPCOM's hardpoint director: the one thing that spawns OPFOR after generation, and the reader the
// AP pool and the stored zone caps were built waiting for. It spends OPFOR Army Power to fortify the
// ground the enemy holds -- topping up cleared zone emplacements, thickening the band, raising radio
// towers -- replacing the blind AP-timers this init deleted with something the enemy is trying to do.
["INFO", "WARCOM", "Init OPCOM hardpoint director"] call fnc_log;
[] spawn fnc_WARCOM_opf_hardpoints;

// No blind OPFOR spawn timers here: enemy presence is zone garrisons, side-mission guards and OPCOM's
// deliberate fortification above -- emplacements it sites and pays for, not live groups an AP clock
// drips onto the map, which would put permanently simulated AI between the zones and on the road to
// the HQ.

WARCOM_init_done = true;
publicVariable "WARCOM_init_done";

[{player globalChat localize "STR_DUWS_T_zc9z2znr"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];



