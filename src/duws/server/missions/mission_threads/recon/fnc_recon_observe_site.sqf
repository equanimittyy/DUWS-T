// Site-finder for the recon-observe mission. Accepts a picker candidate only where an unrevealed
// OPFOR-held zone sits within reach and at least one standoff overwatch with clear terrain
// line-of-sight to it exists, and returns that zone's position. The mission is about scouting a
// position the player has not seen yet, so a zone already on the strategic map is no target -- the
// reveal is the whole payoff.
//
// It returns the TARGET, not the overwatch, on purpose: fnc_mission_findSite keeps only `select 0` of a
// finder's result, and re-deriving the target from an overwatch ("nearest unrevealed OPFOR zone") is
// ambiguous where zones sit close -- it can pick a different zone than LOS was verified against and leave
// the hold unwinnable. The target re-derives exactly; the thread computes the overwatch itself.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only broadcast
// state: zone_namePOS_pairs (name, pos, revealed -- published by fnc_zone_reveal) and
// WARCOM_zones_controled_by_OPFOR. The feasibility raycast is terrain-only (terrainIntersectASL, a
// single cheap query); the thread adds object occlusion once for the launched mission rather than for
// all seven drawn offers.
//
// Contract: [_candidatePos] -> [] reject, or [_targetPos] accept.
params ["_pos"];

// TUNABLE. Standoff band the overwatch must exist within, and how far the target may sit from where the
// picker wanted the offer before it drags the mission across the map. Kept in step with the thread.
#define OBS_MIN_DIST   600
#define OBS_MAX_DIST   800
#define ACCEPT_RADIUS  2500
#define ZONE_CLEAR     250
#define HP_CLEAR       300

private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
if (_pairs isEqualTo []) exitWith { [] };
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
if (_enemyZones isEqualTo []) exitWith { [] };

// Nearest UNREVEALED OPFOR-held zone to the candidate. Revealed (index 2) zones are skipped -- nothing
// to scout on a position already drawn on the map -- and a zone is OPFOR-held when its position is in
// the broadcast enemy list.
private _target = [];
private _bestD = 1e9;
{
    _x params ["", "_zp", "_revealed"];
    if (!_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        private _d = _zp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _target = _zp };
    };
} forEach _pairs;
if (_target isEqualTo [] || {_bestD > ACCEPT_RADIUS}) exitWith { [] };

// Feasibility: at least one standoff bearing has clear terrain LOS onto the target AND stands clear of
// every other enemy zone and hardpoint. None qualifying rejects, so a target whose overwatches are all
// blind or on enemy ground is never offered -- the thread would otherwise abort after the pick.
private _tgtASL = [_target select 0, _target select 1, (getTerrainHeightASL _target) + 5];
private _avoidZones = (missionNamespace getVariable ["zone_meta_array", []]) select {
    private _zp = _x select 1;
    (_zp distance2D _target > 1) && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}
};
private _hps = missionNamespace getVariable ["DUWS_hardpoints", []];
private _feasible = false;
for "_i" from 0 to 11 do {
    if (!_feasible) then {
        private _r = OBS_MIN_DIST + random (OBS_MAX_DIST - OBS_MIN_DIST);
        private _cand = _target getPos [_r, _i * 30];
        private _eyeASL = [_cand select 0, _cand select 1, (getTerrainHeightASL _cand) + 1.5];
        if (
            !(terrainIntersectASL [_eyeASL, _tgtASL])
            && {(_avoidZones findIf { _cand distance2D (_x select 1) < ((_x select 2) + ZONE_CLEAR) }) < 0}
            && {(_hps findIf { _cand distance2D (_x select 1) < HP_CLEAR }) < 0}
        ) then { _feasible = true };
    };
};
if (!_feasible) exitWith { [] };

[_target]
