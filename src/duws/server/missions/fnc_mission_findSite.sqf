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
//   _hard        the placement dial: true favours deep enemy ground, false the frontline seam
//   _origin      the requester reference for the >1500 m keep-away gate (picker: the player; debug: HQ)
//   _avoid       positions to stay >=250 m from, so co-offered missions do not stack on one spot
//   _spawnRule   the type's placement contract from mission_types.hpp: [needDestZone, minCorridor,
//                routeAvoidBlufor, surveyKind, finderName, finderArgs]. Reads the destination fields
//                (1-3), surveyKind (4) and the finder (5-6).
//
// Contract: [_hard, _origin, _avoid, _spawnRule] -> [_pos, _dest] | [].
params [
    ["_hard", false],
    ["_origin", PosOfBLUHQ],
    ["_avoid", []],
    ["_spawnRule", [false, 0, false, "zone", "", []]]
];
_spawnRule params ["_needDest", "_minCorridor", "_routeAvoid", ["_surveyKind", "zone"], ["_finderName", ""], ["_finderArgs", []]];

// The type's site-finder, named in its mission_types.hpp row; "" is the sentinel for no per-type finder,
// so the accept-all generic. Client-safe: the row is #included into the picker and every named finder is
// broadcast, so this resolves off the host too.
private _finder = if (_finderName isEqualTo "") then { fnc_site_generic } else { missionNamespace getVariable [_finderName, fnc_site_generic] };

private _frontierBand   = 2000; // metres past an OPFOR zone edge the easy countryside search spans
private _hardBand       = 800;  // hard: metres past a chosen zone edge the objective may drift -- tight, to hug the cluster
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

// fnc_offer_weight is pure, so siting hands it this world snapshot rather than have it query engine state
// -- which would also break the client-side picker.
private _world = [_friendlyAnchors, _enemyPts, _opforCenters, _zoneFoot, _hpFoot];

// Town survey samples MissionLocations; with none present (a server may not carry them) it falls back to the
// zone survey. The "More Urban" toggle stays out of the mission survey -- it already urbanises offers by
// seating the zones this survey anchors on, so town-forcing here would only double-count.
private _mLocs = missionNamespace getVariable ["MissionLocations", []];
private _useTown = (_surveyKind isEqualTo "town") && {!(_mLocs isEqualTo [])};
private _useMap = !_useTown && {_surveyKind isEqualTo "map"};
private _useHardpoint = !_useTown && {_surveyKind isEqualTo "hardpoint"};
// The "onzone" kind enumerates enemy sites whose objective anchors on claimed ground -- capture on the
// OPFOR zone it takes, recon on the zone or emplacement it scouts -- so it alone skips the zone-interior
// claimed gate below, unlike "hardpoint" whose targets are always standalone.
private _useOnZone = !_useTown && {_surveyKind isEqualTo "onzone"};
private _band = if (_hard) then {_hardBand} else {_frontierBand};
private _scoreMode = if (_useTown || _useMap || _useHardpoint || _useOnZone) then { "urban" } else { "zone" };

// The features phase 2 surveys: town centres, the live target hardpoints, a whole-map sample, or OPFOR zones
// as [centre, bandMin, bandMax] the realise step feeds straight to findSafePos. Hardpoint, map and zone
// features share that triple shape, so phase 3's realise reads them without a branch.
private _features = if (_useTown) then {
    +_mLocs   // MissionLocations is already a list of town-centre positions
} else {
    if (_useHardpoint || _useOnZone) then {
        // Enumerate: one candidate per discrete target -- a live hardpoint, an OPFOR zone (capture), or an
        // unrevealed enemy position to scout (recon) -- via the type's finder in ["ALL"] mode, so an
        // enumerate type MUST define a finder answering ["ALL"]. Listing directly gives every target an even
        // shot where a random-dot survey would cluster onto whichever sits nearest a zone. Tiny realise band
        // -- the vet snaps back exactly.
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
        private _score = [_fCenter, _hard, _scoreMode, _world] call fnc_offer_weight;
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

    // Off every zone/town by 400 m, leaving headroom for a thread's own tight local settle so an anchor a
    // metre outside a boundary does not seat the objective back inside it.
    // The onzone kind is exempt like town: both deliberately anchor on claimed ground -- an OPFOR zone, a
    // town -- which this gate rejects, and a town survey's every candidate sits on the town its finder works.
    if (!_useOnZone && !_useTown && {[_cand, 400] call fnc_pos_claimed}) then { continue };

    if (!(_cand distance _origin > 1500 && {_cand distance PosOfBLUHQ < (zones_max_dist_from_hq*1.5)})) then { continue };

    // The type's finder gets the last word: reject -> drop this feature and draw the next; accept -> its
    // precise position (a town centre for intel, the candidate unchanged for the generic) wins.
    private _site = ([_cand] + _finderArgs) call _finder;
    if (_site isEqualTo []) then { _shortlist = _shortlist select {!((_x select 0) isEqualTo _fData)}; continue };

    // Flatten to 2D: a snapping finder can return a getPos-derived centre whose Z sits below the surface.
    // A 3D offer position offsets its strategic-map icon's clickable hotspot, so match the flat [x,y].
    private _p = _site select 0;
    private _pos2d = [_p select 0, _p select 1];

    // Keep-apart on the settled position, not the pre-finder candidate: a relocating finder (town-centre
    // snap, HVT eject) pulls the offer onto a co-offer the raw candidate cleared -- stacked two town offers.
    private _clear = true;
    { if (_pos2d distance _x < 250) exitWith { _clear = false } } forEach _avoid;
    if (!_clear) then { continue };

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
