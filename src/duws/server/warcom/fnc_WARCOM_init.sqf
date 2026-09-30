// [[zones], posBLUHQ, blufor AP, opfor AP] spawn fnc_WARCOM_init
if (!isServer) exitWith {};
[{player globalChat localize "STR_DUWS_T_jl4gqjpf"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

_array_of_zones_total =_this select 0;
_blu_hq_pos =_this select 1;
_blufor_ap =_this select 2;
_opfor_ap =_this select 3;


// HQ reference that WARCOM here and zone_state_init order zones against, nearest first (+16m off the building).
WARCOM_blu_hq_pos = [_blu_hq_pos select 0, (_blu_hq_pos select 1) + 16];
// Seed both halves from the preset: the earned counter (one-way ratchet, and what the tier derives
// from) and the spendable wallet. Starting at a tier means the wallet to act at it now, not capability
// it cannot pay for until income accrues.
WARCOM_blufor_ap_earned = _blufor_ap;
WARCOM_opfor_ap_earned = _opfor_ap;
WARCOM_blufor_tier = [_blufor_ap] call DUWS_fnc_ap_tier;
WARCOM_opfor_tier = [_opfor_ap] call DUWS_fnc_ap_tier;
WARCOM_blufor_ap = _blufor_ap;
WARCOM_opfor_ap = _opfor_ap;
publicVariable "WARCOM_blufor_ap";
publicVariable "WARCOM_opfor_ap";
publicVariable "WARCOM_blufor_ap_earned";
publicVariable "WARCOM_opfor_ap_earned";
publicVariable "WARCOM_blufor_tier";
publicVariable "WARCOM_opfor_tier";
publicVariable "WARCOM_blu_hq_pos";
if (DUWS_campaignLoaded) then { call DUWS_fnc_restoreLedger };

sleep 5;

WARCOM_createdZones = [_array_of_zones_total,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
publicVariable "WARCOM_createdZones";

// Campaign-size income throttle from the ACTUAL zone count (gen can fall short of zones_number): factor 1
// at or below the reference size, above it income grows as sqrt(zones) so 4x zones pay 2x, up to what
// _MAX_PAID_ZONES unthrottled zones pay (reached at 16), and flat past that -- a high zones_number can't
// hand everyone a bigger war chest. k tunes the curve (1 flat, 0 linear).
private _REF_ZONES = 4;
private _k = 0.5;
private _MAX_PAID_ZONES = 8;
private _zones = (count WARCOM_createdZones) max _REF_ZONES;
DUWS_econ_throttle = ((_REF_ZONES / _zones) ^ _k) min (_MAX_PAID_ZONES / _zones);
["INFO", "ECON", format ["econ throttle %1 for %2 zones", DUWS_econ_throttle, count WARCOM_createdZones]] call fnc_log;

publicVariable "WARCOM_zones_controled_by_BLUFOR";
// A loaded campaign's captures are already in the BLUFOR list here.
WARCOM_zones_controled_by_OPFOR = WARCOM_createdZones select { !([[_x] call fnc_zone_key] call fnc_zone_bluforHeld) };
publicVariable "WARCOM_zones_controled_by_OPFOR";

[{player globalChat localize "STR_DUWS_T_42esdbvb"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

// The random-event runner reads civ_town_rep, which exists only on the plain civilian path -- so it
// starts only there, not under NONE/RAVAGE/WBK.
if (!isNil "CIV_PRESENCE" && {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])}) then {
	["INFO", "WARCOM", "Init random-event runner"] call fnc_log;
	[] spawn fnc_random_event_runner;
};

// No blind OPFOR spawn timers: enemy presence is zone garrisons and side-mission guards -- not live
// groups an AP clock drips onto the map, which would leave permanently simulated AI between the zones and
// on the road to the HQ.

// OPCOM, the opposing commander: its perception loop starts once zones and civ state exist. Ungated by
// game mode -- with no towns it simply has no town sources. Server-only thread.
["INFO", "OPCOM", "Init perception loop"] call fnc_log;
[] spawn fnc_opcom_perception_run;

WARCOM_init_done = true;
publicVariable "WARCOM_init_done";

[{player globalChat localize "STR_DUWS_T_zc9z2znr"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];



