// Site-finder for the destroy-tower mission. Accepts a picker candidate only where a live OPFOR RADIO
// hardpoint -- a standalone signal mast -- sits within reach, and returns that mast's position. The
// mission destroys an existing enemy radio tower rather than a spawned stand-in, so with none in range
// the offer is dropped. Intel is not a prerequisite here: the row's revealed flag is ignored, unlike the
// recon picker.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only the broadcast
// DUWS_hardpoints. Presence in that array == the mast is alive: the streamer deletes the row the instant
// the mast is wrecked, so no separate liveness query is needed.
//
// Contract: [_candidatePos] -> [] reject, or [_hpPos] accept.
params ["_pos"];

// Nearest live OPFOR standalone RADIO mast anywhere on the map -- no distance cap. Masts are few (seeded on
// hilltops, off the OPFOR zones this picker's survey draws its candidates from), so gating the offer on one
// happening to sit near the survey candidate starved the mission to near-never. Snap the offer to the
// nearest mast instead; the offer position becomes that mast, and the thread's own re-scan runs from there.
// Row: [key, pos, type, side, zoneKey, revealed, dir].
private _best = [];
private _bestD = 1e10;
{
    _x params ["", "_hp", "_type", "_side", "_zoneKey"];
    if (_type isEqualTo "RADIO" && {_side isEqualTo "opfor"} && {_zoneKey isEqualTo ""}) then {
        private _d = _hp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _best = _hp };
    };
} forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);

if (_best isEqualTo []) exitWith { [] };
[_best]
