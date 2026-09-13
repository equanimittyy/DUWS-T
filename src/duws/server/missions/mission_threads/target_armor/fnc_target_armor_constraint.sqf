// Eligibility gate for Destroy Vehicle Patrol: OPFOR must have earned the Motorised tier, or the side
// fields no vehicles and the "roving patrol" degrades to a nonsensical fallback truck column. Position-
// independent, so fnc_mission_findSite checks it once per draw before siting, not once per candidate.
// Client-safe: reads only broadcast AP state (DUWS_fnc_ap_unlocked resolves against WARCOM_opfor_ap_earned
// and DUWS_ap_tier_rungs, both publicVariable'd).
//
// Contract: [] -> true eligible, false not.
["OPF", 2] call DUWS_fnc_ap_unlocked
