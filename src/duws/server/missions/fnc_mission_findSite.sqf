// Locality: server + all clients (publicVariable'd). Unscheduled-safe -- a pure call with no
// suspension -- so the strategic-map picker can call it inside its search thread and the server-side
// debug force tool can call it directly.

// The single source for where a side mission is sited. The strategic-map picker
// (client/missions/fnc_stratmap.sqf) offers several of these per request; the debug force tool
// (server/misc/fnc_debug_force_mission.sqf) sites one. Both route here, so a forced mission lands
// exactly where a picked one could and the weighting lives in one place rather than drifting between
// a real copy and a debug copy.
//
// Frontline-seam vs deep-enemy weighting, the OPFOR-zone band search, the fnc_pos_claimed standoff,
// the origin/HQ distance gates, and the per-type site-finder handshake all happen here. Returns the
// finder's precise position, or [] when no candidate satisfied the finder within the reject cap: the
// picker drops that offer, the debug tool logs and aborts.
//
//   _threadName  the mission thread's global name; its finder is fnc_<name>_site, else the accept-all generic
//   _hard        true routes to the deep-enemy score, false to the frontline seam
//   _origin      the requester reference for the >1500 m keep-away gate (picker: the player; debug: HQ)
//   _avoid       positions to stay >=250 m from, so co-offered missions do not stack on one spot
//   _allowUrban  true lets the urban named-location branch run; the picker drops it after its 20s
//                failsafe, and it is forced off where the map has no named locations
//
// Contract: [_threadName, _hard, _origin, _avoid, _allowUrban] -> _pos | [].
params [
    "_threadName",
    ["_hard", false],
    ["_origin", PosOfBLUHQ],
    ["_avoid", []],
    ["_allowUrban", ((missionNamespace getVariable ["moreUrban", 0]) == 1)]
];

// The type's site-finder: fnc_<name>_site if the mission defines one, else the accept-all generic.
// Stripping "_mission" (8 chars) off the thread name is the same rule the picker used inline; keeping
// it here alone means the picker and the debug tool cannot drift on it.
private _finder = missionNamespace getVariable [
    (_threadName select [0, (count _threadName) - 8]) + "_site", fnc_site_generic];

private _frontWidth   = 0.3;    // frontline spread: half-weight this fraction either side of the seam
private _zoneRepel     = 1200;  // zone-edge standoff the easy weight fights for, metres -- aggressive
private _hpRepel       = 300;   // hardpoint standoff the easy weight fights for, metres -- soft
private _frontierBand  = 2000;  // metres past an OPFOR zone edge the easy countryside search spans
private _depthScale    = 1500;  // hard: depth half-weight distance from friendly-held ground, metres
private _densRadius     = 1500; // hard: only enemy features within this feed the "surrounded" score; none -> dropped
private _gauntCorr      = 400;  // hard: approach-corridor half-width, metres
private _hardBand       = 800;  // hard: metres past a chosen zone edge the objective may drift -- tight, to hug the cluster
private _peakEnemyness  = 0.5;  // seam target for the easy urban bell; hard offers ignore it

private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
private _friendlyAnchors = +_bluHeld;
if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

private _zoneFoot = zone_meta_array apply {_x params ["", "_zp", "_zs"]; [_zp, _zs]};
private _hpFoot = if (isNil "DUWS_hardpoints") then {[]} else {DUWS_hardpoints apply {[_x select 1, 0]}};

private _opforZoneCands = [];
{
    _x params ["", "_zp", "_zs"];
    if ((_bluHeld findIf {(_x distance2D _zp) < 1}) < 0) then {
        _opforZoneCands pushBack [[_zp, _zs], _zp];
    };
} forEach zone_meta_array;
private _opforCenters = _opforZoneCands apply {_x select 1};

private _enemyPts = (_opforZoneCands apply {[_x select 1, (_x select 0) select 1]}) + _hpFoot;

// Soft repulsion from a footprint set: 0 on the nearest feature's edge, 0.5 at _scale beyond it,
// approaching 1 far out. Empty set -> 1 (no push).
private _fnRepel = {
    params ["_pos", "_feats", "_scale"];
    if (_feats isEqualTo []) exitWith {1};
    private _d = 0 max (selectMin (_feats apply {(_pos distance2D (_x select 0)) - (_x select 1)}));
    _d / (_d + _scale)
};

// [_cands, _fnWeight] -> one item. _cands are [item, pos] pairs; _fnWeight scores a position in
// [0,1]. All weights zero (or no candidates) -> flat random, so a degenerate map never returns nil.
private _fnPick = {
    params ["_cands", "_fnWeight"];
    private _items = _cands apply {_x select 0};
    if (_items isEqualTo []) exitWith {objNull};
    private _weights = _cands apply {(_x select 1) call _fnWeight};
    if ((_weights findIf {_x > 0}) < 0) exitWith {selectRandom _items};
    _items selectRandomWeighted _weights
};

// Perpendicular distance from feature _f to the approach segment _a->_p, plus the projection
// parameter _t (0 at _a, 1 at _p).
private _fnSegDist = {
    params ["_a", "_p", "_f"];
    private _dx = (_p select 0) - (_a select 0);
    private _dy = (_p select 1) - (_a select 1);
    private _len2 = _dx*_dx + _dy*_dy;
    if (_len2 < 1) exitWith {[_f distance2D _a, 0]};   // _a ~ _p: no meaningful approach line
    private _t = (((_f select 0) - (_a select 0))*_dx + ((_f select 1) - (_a select 1))*_dy) / _len2;
    private _tc = 0 max (_t min 1);
    private _cx = (_a select 0) + _tc*_dx;
    private _cy = (_a select 1) + _tc*_dy;
    [sqrt ((((_f select 0)-_cx)^2) + (((_f select 1)-_cy)^2)), _t]
};

// Hard-offer score. Density of nearby enemy placements leads and gates: a spot with no enemy zone or
// hardpoint within _densRadius scores 0 and is never offered. Depth behind friendly lines and an
// approach gauntlet only rank the survivors. selectRandomWeighted normalises, so magnitudes only rank.
private _fnHardScore = {
    private _pos = _this;

    private _dens = 0;
    {
        private _de = 0 max ((_pos distance2D (_x select 0)) - (_x select 1));
        if (_de < _densRadius) then { _dens = _dens + (1 - _de / _densRadius) };
    } forEach _enemyPts;
    if (_dens <= 0) exitWith {0};

    private _fDists = if (_friendlyAnchors isEqualTo []) then {[]} else {_friendlyAnchors apply {_pos distance2D _x}};
    private _dFri = if (_fDists isEqualTo []) then {_depthScale} else {selectMin _fDists};
    private _fDepth = _dFri / (_dFri + _depthScale);

    private _fGaunt = 0.2;
    if !(_fDists isEqualTo []) then {
        private _a = _friendlyAnchors select (_fDists find _dFri);
        {
            ([_a, _pos, _x select 0] call _fnSegDist) params ["_perp", "_t"];
            if (_perp < _gauntCorr && _t > 0.15 && _t < 0.95) then {
                _fGaunt = _fGaunt + (1 - _perp / _gauntCorr);
            };
        } forEach _enemyPts;
    };

    (_dens ^ 2) * (0.15 + _fDepth) * _fGaunt
};

// Urban weight (easy offers): a bell peaked on the seam. Hard offers exit early to _fnHardScore.
private _fnUrbanWeight = {
    private _pos = _this;
    if (_hard) exitWith { _pos call _fnHardScore };
    private _dFri = if (_friendlyAnchors isEqualTo []) then {1e6} else {selectMin (_friendlyAnchors apply {_pos distance2D _x})};
    private _dOpf = if (_opforCenters isEqualTo []) then {_dFri} else {selectMin (_opforCenters apply {_pos distance2D _x})};
    private _enemyness = _dFri / ((_dFri + _dOpf) max 1);
    private _front = 1 / (1 + (((_enemyness - _peakEnemyness) / _frontWidth) ^ 2));
    _front
      * ([_pos, _zoneFoot, _zoneRepel] call _fnRepel)
      * ([_pos, _hpFoot, _hpRepel] call _fnRepel)
};

// Countryside weight: easy offers favour front OPFOR zones (nearest friendly ground); hard offers
// score each zone centre by _fnHardScore.
private _fnZoneWeight = {
    if (_hard) exitWith { _this call _fnHardScore };
    private _dFri = if (_friendlyAnchors isEqualTo []) then {1} else {1 max (selectMin (_friendlyAnchors apply {_this distance2D _x}))};
    1 / _dFri
};

// The urban branch samples MissionLocations; with none present (server may not carry them) it cannot
// run, so force the countryside branch rather than picking objNull.
private _mLocs = missionNamespace getVariable ["MissionLocations", []];
_allowUrban = _allowUrban && {!(_mLocs isEqualTo [])};

// Per-offer search. Only a finder reject counts toward the cap that drops the offer; a claimed or
// out-of-gate candidate is redrawn for free, exactly as the picker did. _maxTries is a backstop the
// picker did not need: it ran in a spawned thread the loadingscreen terminated at 60s, but this runs
// as an unscheduled call that terminate cannot interrupt, so an unwinnable map must end the loop here.
private _finderReject = 0;
private _finderCap = 20;
private _maxTries = 200;
private _tries = 0;
private _result = [];

while {_result isEqualTo [] && {_finderReject < _finderCap} && {_tries < _maxTries}} do {
    _tries = _tries + 1;

    private _cand = [];
    if (_allowUrban) then {
        // Named location, weighted onto the frontline and off the fortifications, snapped to a building.
        private _znAnchor = position ([_mLocs apply {[_x, position _x]}, _fnUrbanWeight] call _fnPick);
        private _zl = [_znAnchor, 100, 400, 10, 0, 0.3, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        private _bld = nearestBuilding _zl;
        _cand = [(getPos _bld) select 0, (getPos _bld) select 1];
    } else {
        if (_opforZoneCands isEqualTo []) then {
            // Every zone already BLUFOR-held (win state): fall back to the old HQ ring.
            _cand = [PosOfBLUHQ, 0, (zones_max_dist_from_hq*1.5), 5, 0, 0.3, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        } else {
            ([_opforZoneCands, _fnZoneWeight] call _fnPick) params ["_pzp", "_pzs"];
            private _band = if (_hard) then {_hardBand} else {_frontierBand};
            _cand = [_pzp, _pzs, _pzs + _band, 5, 0, 0.3, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        };
    };

    // Off every zone/town by 400 m -- the drift a thread's objective takes from this anchor before
    // fnc_missionTargetPos settles it, so an anchor a metre outside a boundary does not hand that
    // thread fifty rejections and an abort. A claimed candidate is redrawn.
    if ([_cand, 400] call fnc_pos_claimed) then { continue };

    // Not stacked on a co-offered mission.
    private _clear = true;
    { if (_cand distance _x < 250) exitWith { _clear = false } } forEach _avoid;
    if (!_clear) then { continue };

    // Clear of the requester, inside the campaign's HQ radius.
    if (!(_cand distance _origin > 1500 && {_cand distance PosOfBLUHQ < (zones_max_dist_from_hq*1.5)})) then { continue };

    // The type's finder gets the last word: reject -> count it toward the cap and redraw; accept ->
    // its precise position (a town centre for intel, the candidate unchanged for the generic) wins.
    private _site = [_cand] call _finder;
    if (_site isEqualTo []) then {
        _finderReject = _finderReject + 1;
    } else {
        _result = _site select 0;
    };
};

_result
