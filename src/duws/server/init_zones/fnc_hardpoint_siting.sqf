// Server-only: the siting loop runs where zones are built and faction globals
// are authoritative; this file defines the primitives, the (greenfield) placer calls them.
// Split for testability: fnc_hardpoint_survey is the thin, engine-only terrain read; fnc_hardpoint_score
// is pure. sqf-vm carries no terrain, so only the survey escapes unit testing.
// Facts row, the contract between the two:
//   0 onWater      bool   any type on water is unplaceable
//   1 relElev      m      candidate height minus the mean of a ring around it; >0 locally raised
//   2 slope        m      height spread across that ring; 0 is flat
//   3 roadDist     m      to the nearest road within the scan, else a large sentinel
//   4 roadDrop     m      candidate height minus the road's; >0 overlooks the road
//   5 treeNear     count  trees within the concealment radius
//   6 treeWide     count  trees within the sightline / clearance radius
//   7 buildingCnt  count  houses within the keep-clear radius
//   8 hpDist       m      to the nearest existing hardpoint, else a large sentinel
//   9 clutter50    count  structures within 50 m; a gun nest boxed in by them loses its arcs
//  10 aspect       deg    bearing of steepest descent (the fall line); which way is downhill
//  11 aspectMag    m      strength of that fall line; near 0 on flat ground or a symmetric crest
//  12 roadDir      deg    bearing the nearest road runs; 0 when none is in scan range
//  13 roadLos      bool   line of sight from the gun to that road clears the terrain between
//  14 fofDist      m      open field of fire down the fall line before terrain masks the shot
//  15 nestDist     m      to the nearest MG/AT/GMG neighbour, else a large sentinel
//  16 nestDir      deg    that neighbour's facing; the interlock check compares it to this fall line

#define HP_FOF_STEP 40
#define HP_FOF_MAX  320
// Must cover both the overwatch ramp (score reads roadDist over 0..300) and the 100 m keep-clear veto;
// a road past this reads as none (roadDist stays the 1e9 sentinel).
#define HP_ROAD_SCAN 300

fnc_hardpoint_survey = {
    params ["_pos"];
    private _p = [_pos select 0, _pos select 1];

    private _onWater = surfaceIsWater _p;
    private _candZ = getTerrainHeightASL _p;

    // Eight-point ring: a cheap proxy for how this spot stands relative to its immediate surrounds.
    // Reads the perch not the region -- enough to tell a hilltop from a hollow, what every type keys off.
    private _ringR = 30;
    private _angles = [0, 45, 90, 135, 180, 225, 270, 315];
    private _zs = [];
    { _zs pushBack (getTerrainHeightASL [(_p select 0) + _ringR * sin _x, (_p select 1) + _ringR * cos _x]) }
        forEach _angles;
    private _mean = 0; { _mean = _mean + _x } forEach _zs; _mean = _mean / (count _zs);
    private _relElev = _candZ - _mean;
    private _slope = (selectMax _zs) - (selectMin _zs);

    // Fall line off the same ring: each point pulls toward it by how far the ground drops that way, so a
    // uniform slope resolves to the downhill bearing and a symmetric crest cancels near zero. The facing
    // gate reads the magnitude to tell a real slope from flat ground with no single way to face.
    private _dx = 0;
    private _dy = 0;
    {
        private _drop = _candZ - (_zs select _forEachIndex);
        _dx = _dx + _drop * sin _x;
        _dy = _dy + _drop * cos _x;
    } forEach _angles;
    private _aspect = _dx atan2 _dy;
    private _aspectMag = sqrt (_dx * _dx + _dy * _dy);

    private _roadDist = 1e9;
    private _roadDrop = 0;
    private _roadDir = 0;
    private _roadLos = 0;
    private _road = [_p, HP_ROAD_SCAN] call BIS_fnc_nearestRoad;
    if (!isNull _road) then {
        private _rp = getPosASL _road;
        _roadDist = _p distance2D _rp;
        private _roadZ = getTerrainHeightASL [_rp select 0, _rp select 1];
        _roadDrop = _candZ - _roadZ;
        // A rise between gun and road can mask it even when the nest sits above; overwatch must not score
        // a road it cannot see. terrainIntersectASL is true when blocked, so a clear shot is index 0.
        _roadLos = [1, 0] select (terrainIntersectASL [[_p select 0, _p select 1, _candZ + 2], [_rp select 0, _rp select 1, _roadZ + 1]]);
        // Bearing to a connected segment, not this one's own heading, so a roadblock can face along the
        // road and sit square across it. atan2(east, north), same compass convention as the fall line.
        // A dead-end segment has no connection; falls back to its own heading.
        private _cons = roadsConnectedTo _road;
        _roadDir = if (count _cons > 0) then {
            private _c0 = getPosASL (_cons select 0);
            ((_c0 select 0) - (_rp select 0)) atan2 ((_c0 select 1) - (_rp select 1))
        } else {
            getDir _road
        };
    };

    private _treeKinds = ["TREE", "SMALL TREE", "BUSH"];
    private _treeNear = count (nearestTerrainObjects [_p, _treeKinds, 12, false]);
    private _treeWide = count (nearestTerrainObjects [_p, _treeKinds, 40, false]);
    private _buildingCnt = count (nearestTerrainObjects [_p, ["House", "Building"], 25, false]);
    // A cluster of buildings within 50 m walls off a static's arcs. Penalised not vetoed -- one shed is
    // fine, a compound is not.
    private _clutter50 = count (nearestTerrainObjects [_p, ["House", "Building"], 50, false]);

    private _hpDist = 1e9;
    // Live registry, so a cleared hardpoint stops blocking new ground. Row shape [key, pos, type, ..., dir].
    // nestDist/nestDir track only MG/AT/GMG neighbours (row index 6 is facing) for the interlock score --
    // an AA or battery next door doesn't interlock -- separate from hpDist's nearest-of-any spacing.
    private _nestDist = 1e9;
    private _nestDir = 0;
    {
        private _d = _p distance2D (_x select 1);
        _hpDist = _hpDist min _d;
        if (_d < _nestDist && {(_x select 2) in ["MG", "AT", "GMG"]}) then {
            _nestDist = _d;
            _nestDir = _x param [6, 0];
        };
    } forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);

    // March out along the fall line -- where an overwatch nest points -- and find how far a level shot
    // clears before terrain masks it; flat ground never masks, so it reads fully open. A few terrain-only
    // rays, generation-time only.
    private _fofDist = HP_FOF_MAX;
    private _gunEye = [_p select 0, _p select 1, _candZ + 2];
    for "_d" from HP_FOF_STEP to HP_FOF_MAX step HP_FOF_STEP do {
        private _tx = (_p select 0) + _d * sin _aspect;
        private _ty = (_p select 1) + _d * cos _aspect;
        if (terrainIntersectASL [_gunEye, [_tx, _ty, (getTerrainHeightASL [_tx, _ty]) + 2]]) exitWith {
            _fofDist = _d - HP_FOF_STEP;
        };
    };

    [_onWater, _relElev, _slope, _roadDist, _roadDrop, _treeNear, _treeWide, _buildingCnt, _hpDist, _clutter50, _aspect, _aspectMag, _roadDir, _roadLos, _fofDist, _nestDist, _nestDir]
};

// [_facts, _type] call fnc_hardpoint_score -> terrain multiplier on the type's base weight; 0 vetoes the
// site (water, or a per-type gate below).
fnc_hardpoint_score = {
    params ["_facts", "_type"];
    // roadDir (index 12) is the facing's, not the score's -- skipped. The remaining defaults ("clear",
    // "open", "no neighbour") mean a fixture row that omits them (the unit tests) reads no LOS, field-of-
    // fire or interlock penalty. 240 is a literal, not HP_FOF_MAX -- the score is pure and the unit
    // harness does not preprocess defines.
    _facts params ["_onWater", "_relElev", "_slope", "_roadDist", "_roadDrop", "_treeNear", "_treeWide", "_buildingCnt", "_hpDist", ["_clutter50", 0], ["_aspect", 0], ["_aspectMag", 0], "", ["_roadLos", 1], ["_fofDist", 240], ["_nestDist", 1e9], ["_nestDir", 0]];

    if (_onWater) exitWith { 0 };

    // Every emplacement but the roadblock keeps 100 m off any road -- trivially spotted and bypassed on
    // the verge; overwatch nests fire on it from a standoff, not atop it. Roadblock has its own gate below.
    if (!(_type isEqualTo "ROADBLOCK") && {_roadDist < 100}) exitWith { 0 };

    private _ramp = { params ["_v", "_lo", "_hi"]; (((_v - _lo) / (_hi - _lo)) max 0) min 1 };

    private _high = [_relElev, 0, 6] call _ramp;                // local rise, 0..1
    private _flat = 1 - ([_slope, 0.6, 4] call _ramp);          // 1 flat, 0 rough
    private _roadNear = 1 - ([_roadDist, 0, 300] call _ramp);   // 1 at the road, 0 at/over 300 m; the keep-clear floors the gun at 100 m, so in practice 0.67 down
    private _overwatch = _roadNear * ([_roadDrop, 0, 4] call _ramp) * _roadLos;  // near, above AND visible
    private _clear = 1 - 0.6 * ([_clutter50, 0, 6] call _ramp); // 1 open, 0.4 walled in by structures
    // Interlock: a nest crosses fire with a nearby MG/AT/GMG only if their arcs actually overlap, not just
    // by proximity. Convergence gates the bonus on the two guns' facings agreeing -- a neighbour facing
    // opposite (delta near 180) earns nothing, unlike the old distance-only bonus it replaced. On flat
    // ground (aspectMag < 2.5) the candidate's facing is the outward radial, not a real bearing, so
    // convergence is skipped (proximity only); a lone nest has zero proximity either way.
    private _delta = abs (_aspect - _nestDir) % 360;
    if (_delta > 180) then { _delta = 360 - _delta };
    private _conv = if (_aspectMag < 2.5) then { 1 } else { 1 - ([_delta, 90, 180] call _ramp) };
    private _support = 1 + 0.6 * (1 - ([_nestDist, 150, 300] call _ramp)) * _conv; // 1.6 interlocked, 1.0 alone/opposed
    // Floored at 0.6 -- close cover is still a position, not a veto.
    private _fof = 0.6 + 0.4 * ([_fofDist, 40, 240] call _ramp); // 0.6 boxed in, 1.0 open at 240 m+

    switch (_type) do {
        // Uphill is the point; overwatch multiplies it only for a road the gun can see (LOS-gated). AT
        // weighs the road heavier (1.5 vs MG's 0.8) since the road is what its gun kills on.
        case "MG":  { (0.5 + 1.0 * _high) * (1 + 0.8 * _overwatch) * _clear * _support * _fof };
        case "AT":  { (0.5 + 1.0 * _high) * (1 + 1.5 * _overwatch) * _clear * _support * _fof };

        // Lobs grenades over cover rather than firing down a road, so a road below counts for less.
        case "GMG": { (0.5 + 1.0 * _high) * (1 + 0.5 * _overwatch) * _clear * _support * _fof };

        // Flat and clear of trees; heading is cosmetic. Trees tank it but do not forbid it -- "prefer".
        case "AA":  { (0.3 + 1.4 * _flat) * (0.2 + 0.8 * (1 - ([_treeWide, 0, 6] call _ramp))) };

        // The tube needs level ground; too rough is out, not merely worse.
        case "ARTY": { if (_slope > 4) exitWith { 0 }; 0.3 + 1.7 * _flat };

        // A block off the road blocks nothing.
        case "ROADBLOCK": { if (_roadDist > 8) exitWith { 0 }; 1.0 + 0.5 * _roadNear };

        // High ground for the view, a few close trees for cover, but a thicket beyond blinds it.
        case "OP": {
            private _conceal = [_treeNear, 0, 4] call _ramp;
            private _dense = [_treeWide, 8, 20] call _ramp;
            (0.4 + 1.6 * _high) * (1 + 0.5 * _conceal) * (1 - 0.5 * _dense)
        };

        // A tube in defilade hides below the line it supports; reward sitting lower, on ground level
        // enough to lay.
        case "MORTAR": { (0.4 + 1.2 * ([- _relElev, 0, 6] call _ramp)) * (0.5 + 0.5 * _flat) };

        // The mined patch itself must be open: a tree, a building or another emplacement on top of it
        // is each a veto, not a penalty.
        case "MINEFIELD": {
            if (_treeNear > 0 || {_buildingCnt > 0} || {_hpDist < 30}) exitWith { 0 };
            0.4 + 1.6 * _flat
        };

        // A radio mast wants a hilltop crest: high above the ring, ground falling away on every bearing.
        // _crest rewards a cancelling fall line (aspectMag near 0) and docks a one-sided slope; _high is
        // what tells a crest from flat ground, which has no fall line either. Never zero -- terrain here
        // is a preference for the deliberate seed, not a veto.
        case "RADIO": {
            private _crest = 1 - ([_aspectMag, 2.5, 12] call _ramp);  // 1 symmetric, 0 one clear downhill
            (0.3 + 1.7 * _high) * (0.4 + 0.6 * _crest)
        };

        // An unmapped type sites anywhere until it is given a preference.
        default { 1 };
    };
};

// [_type, _aspectDir, _aspectMag, _radialDir, _roadDir] call fnc_hardpoint_facing -> heading in degrees.
// Roadblock faces along the road (whichever of its two headings is nearer _radialDir), so its guns point
// up the approach, not back down it. MG/AT/GMG face the fall line -- downhill, at the ground they watch --
// since a radial heading can point the gun into the hillside it sits on; below a faint gradient (no single
// downhill) they fall back to radial like the remaining, cosmetic-heading types.
fnc_hardpoint_facing = {
    params ["_type", "_aspectDir", "_aspectMag", "_radialDir", ["_roadDir", 0]];
    if (_type isEqualTo "ROADBLOCK") exitWith {
        private _d = abs (_roadDir - _radialDir) % 360;
        if (_d > 180) then { _d = 360 - _d };
        [_roadDir, _roadDir + 180] select (_d > 90)
    };
    if (!(_type in ["MG", "AT", "GMG"]) || {_aspectMag < 2.5}) exitWith { _radialDir };
    _aspectDir
};
