// Site-finder for the destroy-tower mission. Dual-mode, matching surveyKind "hardpoint" (fnc_mission_findSite):
//   ["ALL"]         -> enumerate every live OPFOR standalone RADIO hardpoint position: the survey's candidates.
//   [_candidatePos] -> vet: nearest live RADIO hardpoint to the candidate, or [] if none left.
// The survey lists the towers directly (one candidate each), so two towers far apart both get offered -- no
// random-dot survey to snap many dots onto whichever tower sits nearest a zone cluster and never surface the
// rest. The vet re-resolves a picked candidate to a still-live tower (it may have fallen since enumeration)
// and hands back that position. None live -> [], and the offer is dropped. Intel is not a prerequisite here:
// the revealed flag is ignored, unlike the recon picker.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only the broadcast
// DUWS_hardpoints. Presence in that array == the tower is alive: the streamer deletes the row the instant it
// is wrecked, so no separate liveness query is needed. Row: [key, pos, type, side, zoneKey, revealed, dir].
//
// Contract: ["ALL"] -> [pos, ...] ; [_candidatePos] -> [] reject, or [_hpPos] accept.
params ["_arg"];

private _radios = (missionNamespace getVariable ["DUWS_hardpoints", []]) select {
    (_x select 2) isEqualTo "RADIO" && {(_x select 3) isEqualTo "opfor"} && {(_x select 4) isEqualTo ""}
};
if (_arg isEqualTo "ALL") exitWith { _radios apply { _x select 1 } };

// Vet: _arg is the picker candidate. Nearest live RADIO hardpoint -- for an enumerated candidate that is
// itself, but it re-resolves cleanly if the tower fell in the gap between offer and pick.
private _best = [];
private _bestD = 1e10;
{
    private _d = (_x select 1) distance2D _arg;
    if (_d < _bestD) then { _bestD = _d; _best = _x select 1 };
} forEach _radios;

if (_best isEqualTo []) exitWith { [] };
[_best]
