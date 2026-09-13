// Site-finder for the capture-zone mission (surveyKind "enumerate"). ["ALL"] enumerates one candidate
// per OPFOR-held zone; [_pos] snap-vets one to the nearest still-OPFOR zone, in case the picked one was
// taken between offer and launch. One per zone, so every held zone gets an even shot.
//
// Revealed zones only (zone_namePOS_pairs flag): intel is a prerequisite, so the player is never sent
// after a zone they have not discovered -- only bites in hardcore, else all zones spawn revealed.
//
// A zone's identity is its centre: fnc_captured records that centre in WARCOM_zones_controled_by_BLUFOR
// on capture, so ownership is matched on a sub-metre distance (float identity), as fnc_pos_claimed does.
//
// Client picker and launching thread both call it; reads only broadcast globals so both agree.
//
// Contract: ["ALL"] -> [centre, ...] ; [_candidatePos] -> [] reject, or [_zonePos, _zoneSize] accept.
params ["_arg"];

private _blu = missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []];
private _known = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _opfor = (missionNamespace getVariable ["zone_meta_array", []]) select {
    private _zp = _x select 1;
    (_blu findIf { (_x distance2D _zp) < 1 }) < 0
    && {(_known findIf { (_x select 2) && {((_x select 1) distance2D _zp) < 1} }) >= 0}
};
if (_arg isEqualTo "ALL") exitWith { _opfor apply { _x select 1 } };

private _best = [];
private _bestD = 1e10;
{
    private _d = (_x select 1) distance2D _arg;
    if (_d < _bestD) then { _bestD = _d; _best = [_x select 1, _x select 2] };
} forEach _opfor;

_best
