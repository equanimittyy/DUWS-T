// Site-finder for the destroy-hardpoint mission (surveyKind "enumerate"). ["ALL"] enumerates candidates,
// [_pos] vets one, re-resolving to a still-live emplacement if the picked one fell since the offer. Listed
// directly, one per emplacement, so scattered hardpoints each get offered rather than a random-dot survey
// clustering onto whichever sits nearest a zone.
//
// Revealed rows only (index 5): intel is a prerequisite here (unlike the tower picker), so the player is
// never sent after an emplacement they have not found -- only bites in hardcore, else all spawn revealed.
// Excludes RADIO (its own mission) and MINEFIELD (a hazard, not a garrison). Standalone only (zoneKey ""):
// a zone-child reveals with its zone and is taken by capturing it, not as a discrete objective.
//
// Called from both the client picker and the launching thread; reads only broadcast DUWS_hardpoints
// (presence == alive) so both reach the same verdict. Row: [key, pos, type, side, zoneKey, revealed, dir].
//
// Contract: ["ALL"] -> [pos, ...] ; [_candidatePos] -> [] reject, or [_hpPos, _hpKey] accept.
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
    if (_d < _bestD) then { _bestD = _d; _best = [_x select 1, _x select 0] };
} forEach _hps;

_best
