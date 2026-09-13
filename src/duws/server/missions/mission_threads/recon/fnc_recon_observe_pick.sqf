// Shared target-picker for the recon-observe mission. ["ALL"] lists every eligible target position for the
// enumerate survey (fnc_mission_findSite, surveyKind "onzone"); [_pos] returns the nearest eligible target,
// tagged by kind. Called by BOTH the site-finder (client-side, in the strategic-map picker) and the thread
// (server) so the two agree on WHICH position is scouted. A disagreement leaves the overwatch verified
// against one target and the hold judged against another, and the hold never completes -- the one bug the
// finder/thread split is written to avoid. Reads only broadcast state: zone_namePOS_pairs,
// WARCOM_zones_controled_by_OPFOR and DUWS_hardpoints are all publicVariable'd, so the client half reaches
// the same verdict as the server half.
//
// A target is an UNREVEALED OPFOR position -- a zone or a standalone hardpoint -- the reveal is the whole
// payoff, so a position already on the map is no target. Hardpoints are standalone only (zoneKey ""): a
// zone-child emplacement reveals with its zone and sits inside its footprint. The fire-support batteries
// (mortar, artillery) and minefields are excluded -- a minefield has no emplacement to glass, and the
// batteries are not the frontline strongpoints recon is meant to scout out.
//
// Contract: ["ALL"] -> [pos, ...] every target | [_pos] -> ["zone", _pos] | ["hp", _pos, _key] | [] none.
params ["_pos"];

// The excluded types, named as a literal rather than read from DUWS_hardpointStreaming's neverStream flag
// so the client finder reaches the same verdict without that server table being broadcast.
#define RECON_HP_EXCLUDE ["MORTAR", "ARTY", "MINEFIELD"]

private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];

// Eligibility filtered once so the ALL list and the nearest pick can never disagree on what counts.
private _zones = (missionNamespace getVariable ["zone_namePOS_pairs", []]) select {
    _x params ["", "_zp", "_revealed"];
    !_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}
};
// Row: [key, pos, type, side, zoneKey, revealed, dir].
private _hps = (missionNamespace getVariable ["DUWS_hardpoints", []]) select {
    _x params ["", "", "_type", "_side", "_zoneKey", "_revealed"];
    !_revealed && {_side isEqualTo "opfor"} && {_zoneKey isEqualTo ""} && {!(_type in RECON_HP_EXCLUDE)}
};

if (_pos isEqualTo "ALL") exitWith { (_zones apply { _x select 1 }) + (_hps apply { _x select 1 }) };

private _best = [];
private _bestD = 1e9;
{
    private _d = (_x select 1) distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _best = ["zone", _x select 1] };
} forEach _zones;
{
    private _d = (_x select 1) distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _best = ["hp", _x select 1, _x select 0] };
} forEach _hps;

_best
