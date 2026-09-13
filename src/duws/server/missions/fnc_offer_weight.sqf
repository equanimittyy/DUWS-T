// Offer-time placement weight for a candidate position: higher = a better spot to offer a side mission on.
// fnc_mission_findSite scores every survey candidate through this, then draws one weighted by the result
// (selectRandomWeighted), so "where a mission clusters" lives here -- apart from the survey/realise machinery
// that lists candidates and settles an exact position. Pure: a position and a world snapshot in, a number out,
// no engine query and no side effect, so it can be exercised on a synthetic world without standing up siting.
//
// selectRandomWeighted normalises across the survey, so only the relative magnitudes rank, not their scale.
//
// _hard is the offer's placement dial: true scores deep enemy ground (density leads and gates), false the
// frontline seam. _mode shapes only the easy (front) branch -- hard ignores it and both route to the density
// score:
//   "urban"  town / map / hardpoint / capture surveys -- a bell peaked on the seam, repelled off footprints
//   "zone"   countryside off OPFOR zones -- favour the zone nearest friendly-held ground
// _world is findSite's snapshot, built once and passed on every candidate:
//   [_friendlyAnchors, _enemyPts, _opforCenters, _zoneFoot, _hpFoot]
//   _friendlyAnchors  HQ + FOBs + BLUFOR-held zone centres
//   _enemyPts         [centre, radius] of every OPFOR zone and hardpoint -- the density and gauntlet source
//   _opforCenters     OPFOR-held zone centres -- the easy seam's enemy pole
//   _zoneFoot/_hpFoot [centre, radius] footprints the easy urban bell repels away from
//
// Contract: [_pos, _hard, _mode, _world] -> _weight (>= 0).
params ["_pos", "_hard", "_mode", "_world"];
_world params ["_friendlyAnchors", "_enemyPts", "_opforCenters", "_zoneFoot", "_hpFoot"];

private _frontWidth    = 0.3;   // frontline spread: half-weight this fraction either side of the seam
private _zoneRepel     = 1200;  // zone-edge standoff the easy weight fights for, metres -- aggressive
private _hpRepel       = 300;   // hardpoint standoff the easy weight fights for, metres -- soft
private _depthScale    = 1500;  // hard: depth half-weight distance from friendly-held ground, metres
private _densRadius    = 1500;  // hard: only enemy features within this feed the "surrounded" score; none -> 0
private _gauntCorr     = 400;   // hard: approach-corridor half-width, metres
private _peakEnemyness = 0.5;   // seam target for the easy urban bell; hard offers ignore it

// Caller guards the empty set. A reduce, not selectMin, so the scorer stays runnable in the pure-SQF
// unit VM, which has no working selectMin.
private _fnMinDist = {
    params ["_p", "_pts"];
    private _m = 1e12;
    { _m = _m min (_p distance2D _x) } forEach _pts;
    _m
};

// Soft repulsion from a footprint set: 0 on the nearest feature's edge, 0.5 at _scale beyond it,
// approaching 1 far out. Empty set -> 1 (no push).
private _fnRepel = {
    params ["_p", "_feats", "_scale"];
    if (_feats isEqualTo []) exitWith {1};
    private _d = 1e12;
    { _d = _d min ((_p distance2D (_x select 0)) - (_x select 1)) } forEach _feats;
    _d = 0 max _d;
    _d / (_d + _scale)
};

// Hard-offer score. Density of nearby enemy placements leads and gates: a spot with no enemy zone or
// hardpoint within _densRadius scores 0 and is never offered. Depth behind friendly lines and an
// approach gauntlet only rank the survivors.
private _fnHardScore = {
    private _at = _this;

    private _dens = 0;
    {
        private _de = 0 max ((_at distance2D (_x select 0)) - (_x select 1));
        if (_de < _densRadius) then { _dens = _dens + (1 - _de / _densRadius) };
    } forEach _enemyPts;
    if (_dens <= 0) exitWith {0};

    // Nearest friendly anchor and its distance in one pass -- selectMin + find on the distance would
    // reject a legitimate min to floating-point inequality. No anchor -> depth-scale distance, no gauntlet.
    private _dFri = _depthScale;
    private _a = [];
    {
        private _d = _at distance2D _x;
        if (_a isEqualTo [] || {_d < _dFri}) then { _dFri = _d; _a = _x };
    } forEach _friendlyAnchors;
    private _fDepth = _dFri / (_dFri + _depthScale);

    private _fGaunt = 0.2;
    if !(_a isEqualTo []) then {
        private _dx = (_at select 0) - (_a select 0);
        private _dy = (_at select 1) - (_a select 1);
        private _len2 = _dx*_dx + _dy*_dy;   // _a ~ _at (< 1) -> _t 0, so no enemy passes the corridor test
        {
            private _f = _x select 0;
            private _t = if (_len2 < 1) then { 0 } else {
                (((_f select 0) - (_a select 0))*_dx + ((_f select 1) - (_a select 1))*_dy) / _len2
            };
            private _tc = 0 max (_t min 1);
            private _cx = (_a select 0) + _tc*_dx;
            private _cy = (_a select 1) + _tc*_dy;
            private _perp = sqrt ((((_f select 0)-_cx)^2) + (((_f select 1)-_cy)^2));
            if (_perp < _gauntCorr && _t > 0.15 && _t < 0.95) then {
                _fGaunt = _fGaunt + (1 - _perp / _gauntCorr);
            };
        } forEach _enemyPts;
    };

    (_dens ^ 2) * (0.15 + _fDepth) * _fGaunt
};

if (_hard) exitWith { _pos call _fnHardScore };

if (_mode isEqualTo "zone") exitWith {
    // Easy countryside: favour the OPFOR zone nearest friendly-held ground (the frontline zone).
    private _dFri = if (_friendlyAnchors isEqualTo []) then {1} else {1 max ([_pos, _friendlyAnchors] call _fnMinDist)};
    1 / _dFri
};

// Easy urban: a bell peaked on the seam, damped by repulsion off zone and hardpoint footprints.
private _dFri = if (_friendlyAnchors isEqualTo []) then {1e6} else {[_pos, _friendlyAnchors] call _fnMinDist};
private _dOpf = if (_opforCenters isEqualTo []) then {_dFri} else {[_pos, _opforCenters] call _fnMinDist};
private _enemyness = _dFri / ((_dFri + _dOpf) max 1);
private _front = 1 / (1 + (((_enemyness - _peakEnemyness) / _frontWidth) ^ 2));
_front
  * ([_pos, _zoneFoot, _zoneRepel] call _fnRepel)
  * ([_pos, _hpFoot, _hpRepel] call _fnRepel)
