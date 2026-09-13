// Site-finder for Destroy Vehicle Patrol. Gates the offer on OPFOR having earned the Motorised tier:
// below it the side fields no vehicles, so a "roving vehicle patrol" would spawn a fallback truck column
// that makes no sense as the objective. Reject there and the offer is dropped rather than sited.
//
// Position-independent -- it rejects every candidate or none -- so a below-tier OPFOR yields no site and
// the slot draws another type. Runs client-side inside the picker (fnc_stratmap), so it reads only
// broadcast state: DUWS_fnc_ap_unlocked resolves against WARCOM_opfor_ap_earned and DUWS_ap_tier_rungs,
// both publicVariable'd.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.

params ["_pos"];

if !(["OPF", 2] call DUWS_fnc_ap_unlocked) exitWith { [] };

[_pos]
