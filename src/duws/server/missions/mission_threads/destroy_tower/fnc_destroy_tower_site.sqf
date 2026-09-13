// Site-finder for the destroy-tower mission (surveyKind "enumerate"). ["ALL"] enumerates candidates,
// [_pos] vets one, re-resolving to a still-live tower if the picked one fell since the offer. Listed
// directly, one per tower, so two far apart both get offered rather than a random-dot survey clustering
// onto whichever sits nearest a zone.
//
// RADIO standalone only. Intel is NOT a prerequisite here (unlike the recon picker): the revealed flag is
// ignored, so an unfound tower can still be tasked.
//
// Called from both the client picker and the launching thread; reads only broadcast DUWS_hardpoints
// (presence == alive) so both reach the same verdict. Row: [key, pos, type, side, zoneKey, revealed, dir].
//
// Contract: ["ALL"] -> [pos, ...] ; [_candidatePos] -> [] reject, or [_hpPos, _hpKey] accept.
params ["_arg"];

private _radios = (missionNamespace getVariable ["DUWS_hardpoints", []]) select {
    (_x select 2) isEqualTo "RADIO" && {(_x select 3) isEqualTo "opfor"} && {(_x select 4) isEqualTo ""}
};
if (_arg isEqualTo "ALL") exitWith { _radios apply { _x select 1 } };

private _best = [];
private _bestD = 1e10;
{
    private _d = (_x select 1) distance2D _arg;
    if (_d < _bestD) then { _bestD = _d; _best = [_x select 1, _x select 0] };
} forEach _radios;

_best
