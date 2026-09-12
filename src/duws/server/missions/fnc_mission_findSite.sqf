// Locality: server + all clients (publicVariable'd). Unscheduled-safe (pure call, no suspension), so
// the strategic-map picker can call it inside its search thread and the debug force tool can call it
// directly.

// Single source for where a side mission is sited. The strategic-map picker
// (client/missions/fnc_stratmap.sqf) offers several of these per request; the debug force tool
// (server/debug/fnc_debug_force_mission.sqf) sites one. Both route here, so a forced mission lands
// exactly where a picked one could, and the weighting lives in one place instead of drifting between
// a real copy and a debug copy.
//
// Two placement phases. Phase 2 SURVEYS: walks the candidate features (OPFOR zones, towns for a town-survey
// type, or a whole-map sample for a map-survey type), keeps the ones that pass cheap validity (inside HQ reach; for a convoy, a far-enough
// destination zone with a BLUFOR-clear corridor exists), each scored by the placement dial. Phase 3 picks
// one feature from that shortlist weighted by the dial (frontline for easy, deep for hard) and only then
// REALISES an exact position (BIS_fnc_findSafePos, the fnc_pos_claimed standoff, origin/HQ gates, the
// per-type finder), retrying the next feature on a reject. findSafePos, the costly step, runs only on the
// few features actually picked, never on the whole survey.
//
// Returns [_pos, _dest], or [] when the shortlist is empty or no feature realised within the cap (picker
// draws a different type; debug tool logs and aborts). _dest is the vetted OPFOR destination zone when the
// rule asks for one, else []; a convoy thread runs to it instead of recomputing its own.
//
//   _threadName  the mission thread's global name; its finder is fnc_<name>_site, else the accept-all generic
//   _hard        the placement dial: true favours deep enemy ground, false the frontline seam
//   _origin      the requester reference for the >1500 m keep-away gate (picker: the player; debug: HQ)
//   _avoid       positions to stay >=250 m from, so co-offered missions do not stack on one spot
//   _spawnRule   the type's placement contract from mission_types.hpp: [needDestZone, minCorridor,
//                routeAvoidBlufor, hardEligible, weight, surveyKind]. Reads the destination fields (1-3)
//                and surveyKind (6); the draw (fnc_stratmap) reads hardEligible/weight.
//
// Contract: [_threadName, _hard, _origin, _avoid, _spawnRule] -> [_pos, _dest] | [].
params [
    "_threadName",
    ["_hard", false],
    ["_origin", PosOfBLUHQ],
    ["_avoid", []],
    ["_spawnRule", [false, 0, false, false, 1, "zone"]]
];
_spawnRule params ["_needDest", "_minCorridor", "_routeAvoid", "", "", ["_surveyKind", "zone"]];

// The type's site-finder: fnc_<name>_site if the mission defines one, else the accept-all generic.
// Stripping "_mission" (8 chars) off the thread name matches the rule the picker used inline; keeping
// it here alone keeps the picker and the debug tool from drifting on it.
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
private _routeClearReach = 1200; // convoy corridor: metres a route sample must keep from BLUFOR ground
private _mapTheaterReach = 3000; // map survey: a sample is valid only within this of an enemy zone/hardpoint
                                 // edge -- keeps offers in contested ground without gluing them to a zone,
                                 // and stops the easy frontline bell peaking on empty equidistant corners

private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
private _friendlyAnchors = +_bluHeld;
if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

// Straight-line proxy for a convoy corridor _a->_b: reject if any interior sample sits within
// _routeClearReach of BLUFOR-held ground. Endpoints are enemy (an anchor and an OPFOR zone), so only
// the interior is tested. Not the actual road path: convoys snap to roads and follow the bearing, and
// a per-node path test is far heavier for a picker that runs unscheduled, once per offer candidate.
private _fnRouteClear = {
    params ["_a", "_b"];
    if (_friendlyAnchors isEqualTo []) exitWith {true};
    private _d = _a distance2D _b;
    if (_d < 1) exitWith {true};
    private _steps = ceil (_d / 250);
    private _ok = true;
    private _i = 1;
    while {_ok && _i < _steps} do {
        private _t = _i / _steps;
        private _px = (_a select 0) + ((_b select 0) - (_a select 0)) * _t;
        private _py = (_a select 1) + ((_b select 1) - (_a select 1)) * _t;
        if ((_friendlyAnchors findIf {[_px, _py] distance2D _x < _routeClearReach}) >= 0) then { _ok = false };
        _i = _i + 1;
    };
    _ok
};

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

// Town survey samples MissionLocations; with none present (a server may not carry them) it falls back to the
// zone survey. The "More Urban" toggle stays out of the mission survey -- it already urbanises offers by
// seating the zones this survey anchors on, so town-forcing here would only double-count.
private _mLocs = missionNamespace getVariable ["MissionLocations", []];
private _useTown = (_surveyKind isEqualTo "town") && {!(_mLocs isEqualTo [])};
private _useMap = !_useTown && {_surveyKind isEqualTo "map"};
private _useHardpoint = !_useTown && {_surveyKind isEqualTo "hardpoint"};
// Capture-zone enumerates OPFOR zones as hardpoint enumerates emplacements, but anchors ON the target
// zone -- so it alone skips the zone-interior claimed gate below.
private _useCapture = !_useTown && {_surveyKind isEqualTo "capturezone"};
private _band = if (_hard) then {_hardBand} else {_frontierBand};

// The features phase 2 surveys: town centres, the live target hardpoints, a whole-map sample, or OPFOR zones
// as [centre, bandMin, bandMax] the realise step feeds straight to findSafePos. Hardpoint, map and zone
// features share that triple shape, so phase 3's realise reads them without a branch.
private _features = if (_useTown) then {
    +_mLocs   // MissionLocations is already a list of town-centre positions
} else {
    if (_useHardpoint || _useCapture) then {
        // Enumerate: one candidate per discrete target -- a live hardpoint, or an OPFOR zone for the capture
        // type -- via the type's finder in ["ALL"] mode, so an enumerate type MUST define a finder answering
        // ["ALL"]. Listing directly gives every target an even shot where a random-dot survey would cluster
        // onto whichever sits nearest a zone. Tiny realise band -- the vet snaps back exactly.
        (["ALL"] call _finder) apply { [_x, 0, 50] }
    } else {
        if (_useMap) then {
            // Whole-map source for a type that need not tether to a zone: sample the HQ-reach disc directly, so
            // the offer can land anywhere and the hard/easy weight (not a zone anchor) decides where it clusters.
            // r = R*sqrt(random) spreads points by area rather than radius; phase-2 farthest-point sampling then
            // thins the 64 to an even map-wide 16. A tiny realise band keeps the settled pos near its sample.
            private _R = zones_max_dist_from_hq * 1.5;
            private _pts = [];
            for "_i" from 1 to 64 do {
                _pts pushBack [PosOfBLUHQ getPos [_R * sqrt (random 1), random 360], 0, 300];
            };
            _pts
        } else {
            private _fs = _opforZoneCands apply { (_x select 0) params ["_zp", "_zs"]; [_zp, _zs, _zs + _band] };
            // Win state -- every zone BLUFOR-held: one HQ-ring feature so a non-convoy mission can still seat.
            if (_fs isEqualTo []) then { _fs = [[PosOfBLUHQ, 0, (zones_max_dist_from_hq*1.5)]] };
            _fs
        };
    };
};

private _shortlistCap = 16;   // shortlist handed to phase 3; a wider survey is thinned to an even spread
private _realizeCap   = 8;    // features to findSafePos + finder before giving up on this type

// PHASE 2 -- survey: collect every valid feature (cheap check, no findSafePos).
private _valid = [];
{
    private _fData = _x;
    private _fCenter = if (_useTown) then { _fData } else { _fData select 0 };
    private _ok = (_fCenter distance2D PosOfBLUHQ) < (zones_max_dist_from_hq*1.5);
    // A convoy is valid only where a destination zone at least _minCorridor out has a BLUFOR-clear
    // corridor; checked cheaply on the feature centre, re-derived exactly on the realised position.
    if (_ok && _needDest) then {
        _ok = (_opforCenters findIf {
            (_fCenter distance2D _x) >= _minCorridor && {(!_routeAvoid) || {[_fCenter, _x] call _fnRouteClear}}
        }) >= 0;
    };
    // A map sample must sit within reach of an enemy zone or hardpoint edge. Zone/town features are already
    // enemy-anchored, so this only gates the whole-map source: it keeps offers in contested ground and
    // stops the easy frontline bell rewarding empty corners equidistant from both sides.
    if (_ok && _useMap) then {
        _ok = (_enemyPts findIf { ((_fCenter distance2D (_x select 0)) - (_x select 1)) < _mapTheaterReach }) >= 0;
    };
    if (_ok) then {
        // _fnUrbanWeight scores an arbitrary position (frontline bell for easy, _fnHardScore for hard), so it
        // serves the town, map and hardpoint surveys; _fnZoneWeight is zone-list-specific and stays for zones.
        private _score = if (_useTown || _useMap || _useHardpoint || _useCapture) then { _fCenter call _fnUrbanWeight } else { _fCenter call _fnZoneWeight };
        _valid pushBack [_fData, _fCenter, _score];
    };
} forEach _features;

// Shortlist [featureData, score]: every valid feature, or -- when more qualify than the cap -- an even
// spatial spread of them by farthest-point sampling (seed one, then repeatedly add the valid feature
// whose nearest already-chosen feature is farthest). A blind truncation could hand phase 3 a clustered
// subset and skew its dial pick to one corner of the map; the spread keeps the options map-wide.
private _shortlist = [];
if (count _valid <= _shortlistCap) then {
    _shortlist = _valid apply { [_x select 0, _x select 2] };
} else {
    private _chosen = [selectRandom _valid];
    while { count _chosen < _shortlistCap } do {
        private _best = [];
        private _bestD = -1;
        {
            private _c = _x select 1;
            if ((_chosen findIf { (_x select 1) isEqualTo _c }) < 0) then {
                private _near = selectMin (_chosen apply { _c distance2D (_x select 1) });
                if (_near > _bestD) then { _bestD = _near; _best = _x };
            };
        } forEach _valid;
        if (_best isEqualTo []) exitWith {};
        _chosen pushBack _best;
    };
    _shortlist = _chosen apply { [_x select 0, _x select 2] };
};

// PHASE 3 -- realise: pick a feature by the dial score and settle an exact position. A transient miss
// (claimed spot, stacked on a co-offer, too near the requester) redraws for another findSafePos roll of
// the same shortlist; a structural reject (the finder says no, or a convoy has no clean destination) drops
// the feature for good. All weights zero -> flat random, so a degenerate shortlist never stalls.
private _result = [];
private _realizeTries = 0;
while {_result isEqualTo [] && {!(_shortlist isEqualTo [])} && {_realizeTries < _realizeCap}} do {
    _realizeTries = _realizeTries + 1;

    private _items = _shortlist apply {_x select 0};
    private _weights = _shortlist apply {_x select 1};
    private _fData = if ((_weights findIf {_x > 0}) < 0) then { selectRandom _items } else { _items selectRandomWeighted _weights };

    private _cand = if (_useTown) then {
        private _zl = [_fData, 100, 400, 10, 0, 0.3, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        private _bld = nearestBuilding _zl;
        [(getPos _bld) select 0, (getPos _bld) select 1]
    } else {
        _fData params ["_zp", "_zbMin", "_zbMax"];
        [_zp, _zbMin, _zbMax, 5, 0, 0.3, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos
    };

    // BIS_fnc_findSafePos returns the centre of its blacklist -- [0,0] for the [[0,0],[0,0]] arg above --
    // when it exhausts its attempts without settling a spot (a sample or town with no clear ground in band).
    // [0,0] is open sea off Altis' SW corner yet clears every gate below (far from all zones, ~10 km from an
    // HQ well inside the 1.5x reach), so unguarded it would be offered and started. Drop the feature.
    if (((_cand select 0) == 0) && {(_cand select 1) == 0}) then { _shortlist = _shortlist select {!((_x select 0) isEqualTo _fData)}; continue };

    // Off every zone/town by 400 m -- the drift a thread's objective takes before fnc_missionTargetPos
    // settles it, so an anchor a metre outside a boundary does not hand that thread a string of rejects.
    // Capture and town types are exempt: both deliberately anchor on claimed ground -- a zone, a town --
    // which this gate rejects, and a town survey's every candidate sits on the town its finder works.
    if (!_useCapture && !_useTown && {[_cand, 400] call fnc_pos_claimed}) then { continue };

    private _clear = true;
    { if (_cand distance _x < 250) exitWith { _clear = false } } forEach _avoid;
    if (!_clear) then { continue };

    if (!(_cand distance _origin > 1500 && {_cand distance PosOfBLUHQ < (zones_max_dist_from_hq*1.5)})) then { continue };

    // The type's finder gets the last word: reject -> drop this feature and draw the next; accept -> its
    // precise position (a town centre for intel, the candidate unchanged for the generic) wins.
    private _site = [_cand] call _finder;
    if (_site isEqualTo []) then { _shortlist = _shortlist select {!((_x select 0) isEqualTo _fData)}; continue };

    // Flatten to 2D: a snapping finder can return a getPos-derived centre whose Z sits below the surface.
    // A 3D offer position offsets its strategic-map icon's clickable hotspot, so match the flat [x,y].
    private _p = _site select 0;
    private _pos2d = [_p select 0, _p select 1];
    if (_needDest) then {
        // Destination = the nearest OPFOR zone at least _minCorridor out with a BLUFOR-clear corridor from
        // the settled position. None -> this feature cannot run a convoy; drop it and draw the next.
        private _destCands = _opforCenters select {
            (_pos2d distance2D _x) >= _minCorridor && {(!_routeAvoid) || {[_pos2d, _x] call _fnRouteClear}}
        };
        if (_destCands isEqualTo []) then { _shortlist = _shortlist select {!((_x select 0) isEqualTo _fData)}; continue };
        _result = [_pos2d, [_destCands, [_pos2d], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy select 0];
    } else {
        _result = [_pos2d, []];
    };
};

_result
