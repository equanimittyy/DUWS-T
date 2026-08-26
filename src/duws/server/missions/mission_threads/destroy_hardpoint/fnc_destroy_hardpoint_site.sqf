// Site-finder for the destroy-hardpoint mission. Dual-mode, matching surveyKind "hardpoint" (fnc_mission_findSite):
//   ["ALL"]         -> enumerate every live, revealed OPFOR standalone hardpoint of a destructible type.
//   [_candidatePos] -> vet: nearest such hardpoint to the candidate, or [] if none left.
// The survey lists these emplacements directly (one candidate each), so sparse, scattered hardpoints each get
// offered -- no random-dot survey to snap many dots onto whichever sits nearest a zone cluster. The vet
// re-resolves a picked candidate to a still-live emplacement and hands back its position. None live -> [].
//
// Intel IS a prerequisite, unlike the tower picker: only a revealed row (index 5) qualifies, so the mission
// never sends the player after an emplacement they have not found. Under non-hardcore fog every hardpoint
// spawns revealed, so the flag only bites in hardcore mode.
//
// Excludes RADIO (its own Destroy Signal Tower mission) and MINEFIELD (a hazard cleared, not a garrison
// beaten). Standalone only (zoneKey ""): a zone-child hardpoint reveals with its zone and sits inside its
// footprint, so it is taken by capturing the zone, not as a discrete objective, and pays no bounty.
//
// Client-side in the picker (client/missions/fnc_stratmap.sqf), reads only broadcast DUWS_hardpoints;
// presence == alive (streamer deletes the row the instant it clears). Row: [key, pos, type, side, zoneKey,
// revealed, dir].
//
// Contract: ["ALL"] -> [pos, ...] ; [_candidatePos] -> [] reject, or [_hpPos] accept.
params ["_arg"];

private _hps = (missionNamespace getVariable ["DUWS_hardpoints", []]) select {
    !((_x select 2) in ["RADIO", "MINEFIELD"])
    && {(_x select 3) isEqualTo "opfor"}
    && {(_x select 4) isEqualTo ""}
    && {_x select 5}
};
if (_arg isEqualTo "ALL") exitWith { _hps apply { _x select 1 } };

private _best = [];
private _bestD = 1e10;
{
    private _d = (_x select 1) distance2D _arg;
    if (_d < _bestD) then { _bestD = _d; _best = _x select 1 };
} forEach _hps;

if (_best isEqualTo []) exitWith { [] };
[_best]
