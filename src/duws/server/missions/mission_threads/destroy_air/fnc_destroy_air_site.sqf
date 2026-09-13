// Site-finder for Destroy Air Asset. Gates the offer on OPFOR having earned the Armor tier (AP 350):
// below it the side fields neither a gunship nor a jet, so the "air asset" would have nothing to spawn.
// Which aircraft the thread raises -- the attack helicopter earned at Armor, the jet once the side
// reaches the Air tier (AP 600) -- is decided there from what the side can field; this only decides
// whether the offer appears at all.
//
// Also gated on the AttackHeli campaign toggle: it is the one switch governing every OPFOR air token
// (attackheli, transheli, plane in DUWS_spawnVehicles), so with it off the side fields no aircraft and
// the mission must never offer -- the thread would find both tokens empty and abort.
//
// Position-independent -- it rejects every candidate or none -- so a below-tier or air-disabled OPFOR
// yields no site and the slot draws another type. Runs client-side inside the picker (fnc_stratmap), so
// it reads only broadcast state: DUWS_fnc_ap_unlocked resolves against WARCOM_opfor_ap_earned and
// DUWS_ap_tier_rungs, both publicVariable'd, and AttackHeli is broadcast from server_var_init.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.

params ["_pos"];

if !(["OPF", 4] call DUWS_fnc_ap_unlocked) exitWith { [] };
if ((missionNamespace getVariable ["AttackHeli", 1]) != 1) exitWith { [] };

[_pos]
