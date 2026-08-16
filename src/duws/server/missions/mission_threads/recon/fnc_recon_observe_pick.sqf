// Shared target-picker for the recon-observe mission, called by BOTH the site-finder (client-side, in
// the strategic-map picker) and the thread (server) so the two agree on WHICH position is scouted. A
// disagreement leaves the overwatch verified against one target and the hold judged against another, and
// the hold never completes -- the one bug the finder/thread split is written to avoid. Reads only
// broadcast state: zone_namePOS_pairs, WARCOM_zones_controled_by_OPFOR and DUWS_hardpoints are all
// publicVariable'd, so the client half reaches the same verdict as the server half.
//
// The target is the nearest UNREVEALED OPFOR position to _pos, a zone or a standalone hardpoint -- the
// reveal is the whole payoff, so a position already on the map is no target. Hardpoints are standalone
// only (zoneKey ""): a zone-child emplacement reveals with its zone and sits inside its footprint. The
// fire-support batteries (mortar, artillery) and minefields are excluded -- a minefield has no emplacement
// to glass, and the batteries are not the frontline strongpoints recon is meant to scout out.
//
// Contract: [_pos] -> ["zone", _targetPos] | ["hp", _targetPos, _hpKey] | [] none left.
params ["_pos"];

// The excluded types, named as a literal rather than read from DUWS_hardpointStreaming's neverStream flag
// so the client finder reaches the same verdict without that server table being broadcast.
#define RECON_HP_EXCLUDE ["MORTAR", "ARTY", "MINEFIELD"]

private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];

private _best = [];
private _bestD = 1e9;

// Unrevealed OPFOR-held zones: revealed (index 2) skipped, and OPFOR-held when the pos is in the enemy list.
{
    _x params ["", "_zp", "_revealed"];
    if (!_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        private _d = _zp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _best = ["zone", _zp] };
    };
} forEach (missionNamespace getVariable ["zone_namePOS_pairs", []]);

// Standalone unrevealed OPFOR hardpoints of a representable type. Row: [key, pos, type, side, zoneKey, revealed, dir].
{
    _x params ["_key", "_hp", "_type", "_side", "_zoneKey", "_revealed"];
    if (
        !_revealed
        && {_side isEqualTo "opfor"}
        && {_zoneKey isEqualTo ""}
        && {!(_type in RECON_HP_EXCLUDE)}
    ) then {
        private _d = _hp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _best = ["hp", _hp, _key] };
    };
} forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);

_best
