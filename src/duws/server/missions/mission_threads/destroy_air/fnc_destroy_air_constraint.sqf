// Eligibility gate for Destroy Air Asset: OPFOR must be able to field an aircraft, or the thread finds
// both air tokens empty and aborts. Position-independent, so fnc_mission_findSite checks it once per draw
// before siting, not once per candidate.
//
// Gated on the Armor AP tier (below it the side fields neither gunship nor jet) and the AttackHeli campaign
// toggle (the one switch over every OPFOR air token). Client-safe: reads only broadcast state --
// DUWS_fnc_ap_unlocked resolves against WARCOM_opfor_ap_earned and DUWS_ap_tier_rungs, both publicVariable'd;
// AttackHeli is broadcast from server_var_init.
//
// Contract: [] -> true eligible, false not.
if !(["OPF", 4] call DUWS_fnc_ap_unlocked) exitWith { false };
(missionNamespace getVariable ["AttackHeli", 1]) == 1
