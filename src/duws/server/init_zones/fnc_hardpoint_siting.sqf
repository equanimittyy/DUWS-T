// Locality: server -- every consumer (the siting loop, the minefield generator) runs where zones are
// built and the faction globals are authoritative. These are definitions only; the placer that calls
// them is greenfield.
//
// Siting is split so the arithmetic can be tested. fnc_hardpoint_survey reads the terrain -- the only
// part that needs the engine, kept thin -- and returns a facts row; fnc_hardpoint_score is pure and
// turns that row plus a type into a placement multiplier. sqf-vm carries no terrain, so the survey
// cannot be unit-tested and the scoring weights can.
//
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

fnc_hardpoint_survey = {
    params ["_pos"];
    private _p = [_pos select 0, _pos select 1];

    private _onWater = surfaceIsWater _p;
    private _candZ = getTerrainHeightASL _p;

    // Local relief off an eight-point ring: a cheap proxy for whether this spot stands above, and how
    // even it is against, the ground immediately around it. One ring reads the perch not the region,
    // which is enough to tell a hilltop from a hollow -- what every type keys off.
    private _ringR = 30;
    private _angles = [0, 45, 90, 135, 180, 225, 270, 315];
    private _zs = [];
    { _zs pushBack (getTerrainHeightASL [(_p select 0) + _ringR * sin _x, (_p select 1) + _ringR * cos _x]) }
        forEach _angles;
    private _mean = 0; { _mean = _mean + _x } forEach _zs; _mean = _mean / (count _zs);
    private _relElev = _candZ - _mean;
    private _slope = (selectMax _zs) - (selectMin _zs);

    // Fall line off the same ring: each point pulls a vector toward it in proportion to how far the
    // ground drops that way, so a uniform slope resolves to the downhill bearing and a symmetric crest
    // cancels to near zero. The magnitude says how pronounced that downhill is -- the facing gate reads
    // it to tell a real slope from flat ground where there is no single way to face.
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
    private _road = [_p, 40] call BIS_fnc_nearestRoad;
    if (!isNull _road) then {
        private _rp = getPosASL _road;
        _roadDist = _p distance2D _rp;
        _roadDrop = _candZ - (getTerrainHeightASL [_rp select 0, _rp select 1]);
    };

    private _treeKinds = ["TREE", "SMALL TREE", "BUSH"];
    private _treeNear = count (nearestTerrainObjects [_p, _treeKinds, 12, false]);
    private _treeWide = count (nearestTerrainObjects [_p, _treeKinds, 40, false]);
    private _buildingCnt = count (nearestTerrainObjects [_p, ["House", "Building"], 25, false]);
    // Wider structure count for the gun nests: a cluster of buildings or containers inside 50 m walls
    // off a static's fields of fire. A count, penalised not vetoed -- one shed is fine, a compound is not.
    private _clutter50 = count (nearestTerrainObjects [_p, ["House", "Building"], 50, false]);

    private _hpDist = 1e9;
    // Measured against the live registry, so a cleared hardpoint no longer blocks new ground and the
    // siting loop spaces each placement off the ones already down. Row shape [key, pos, type, ...].
    { _hpDist = _hpDist min (_p distance2D (_x select 1)) } forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);

    [_onWater, _relElev, _slope, _roadDist, _roadDrop, _treeNear, _treeWide, _buildingCnt, _hpDist, _clutter50, _aspect, _aspectMag]
};

// [_facts, _type] call fnc_hardpoint_score -> multiplier on the type's base weight; 0 is unplaceable.
//
// The number is the terrain factor the weighted roll multiplies base weights by. Returning 0 drops a
// type from the roll at a site that cannot hold it: water for every type, plus the per-type vetoes
// below -- artillery needs level ground, a roadblock needs a road, a minefield needs open clear
// ground. MG and AT never require a road: a hill overlooking nothing is still a firing position, so a
// road multiplies the score and its absence does not veto it.
fnc_hardpoint_score = {
    params ["_facts", "_type"];
    _facts params ["_onWater", "_relElev", "_slope", "_roadDist", "_roadDrop", "_treeNear", "_treeWide", "_buildingCnt", "_hpDist", ["_clutter50", 0]];

    if (_onWater) exitWith { 0 };

    private _ramp = { params ["_v", "_lo", "_hi"]; (((_v - _lo) / (_hi - _lo)) max 0) min 1 };

    private _high = [_relElev, 0, 6] call _ramp;                // local rise, 0..1
    private _flat = 1 - ([_slope, 0.6, 4] call _ramp);          // 1 flat, 0 rough
    private _roadNear = 1 - ([_roadDist, 0, 40] call _ramp);    // 1 on the road, 0 at/over 40 m
    private _overwatch = _roadNear * ([_roadDrop, 0, 4] call _ramp);  // near AND above the road
    private _clear = 1 - 0.6 * ([_clutter50, 0, 6] call _ramp); // 1 open, 0.4 walled in by structures
    // Mutual support: a nest within interlock range of one already down crosses fire with it, so an
    // approach in one gun's arc is in two. hpDist is the gap to the nearest placed hardpoint; reward the
    // band a line of guns sits in. Bonus only -- a lone commanding spot is still worth taking. The first
    // nest in a zone has no neighbour (hpDist is the sentinel) and so takes no bonus.
    private _support = 1 + 0.6 * (1 - ([_hpDist, 150, 300] call _ramp)); // 1.6 interlocked, 1.0 alone

    switch (_type) do {
        // Uphill is the whole point; a road below to fire along multiplies it. AT gains more from the
        // road because the road is what its gun kills on, so with a good one it roughly triples. All
        // three fall off as structures crowd the arc (_clear) and lift where they interlock (_support).
        case "MG":  { (0.5 + 1.0 * _high) * (1 + 0.8 * _overwatch) * _clear * _support };
        case "AT":  { (0.5 + 1.0 * _high) * (1 + 1.5 * _overwatch) * _clear * _support };

        // A gun nest like the MG, but it lobs grenades over cover rather than firing down a road, so a
        // road below counts for less.
        case "GMG": { (0.5 + 1.0 * _high) * (1 + 0.5 * _overwatch) * _clear * _support };

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
        // enough to lay. Derived from the plan's siting note, not the placement-preference list.
        case "MORTAR": { (0.4 + 1.2 * ([- _relElev, 0, 6] call _ramp)) * (0.5 + 0.5 * _flat) };

        // The mined patch itself must be open: a tree, a building or another emplacement on top of it
        // is each a veto, not a penalty.
        case "MINEFIELD": {
            if (_treeNear > 0 || {_buildingCnt > 0} || {_hpDist < 30}) exitWith { 0 };
            0.4 + 1.6 * _flat
        };

        // An unmapped type sites anywhere until it is given a preference.
        default { 1 };
    };
};

// [_type, _aspectDir, _aspectMag, _radialDir] call fnc_hardpoint_facing -> heading in degrees.
//
// The heading a sited emplacement faces. The flat types' heading is cosmetic, so they keep the outward
// radial one the loop hands in (zone centre toward the approach). The overwatch nests are the point of
// this: sited on a rise above a road, a radial heading can face the gun back into the hillside while the
// road it overlooks sits off its shoulder. Those face the fall line instead -- down the slope, at the
// low ground the position exists to watch. Below a faint gradient there is no single downhill (flat
// ground, or a symmetric crest whose fall vectors cancel), so they too fall back to radial rather than
// snap to a bearing that is noise. Pure, so the choice is unit-tested.
fnc_hardpoint_facing = {
    params ["_type", "_aspectDir", "_aspectMag", "_radialDir"];
    if (!(_type in ["MG", "AT", "GMG"]) || {_aspectMag < 2.5}) exitWith { _radialDir };
    _aspectDir
};

// [_cols, _rows, _spacing] call fnc_hardpoint_minefield_lattice -> [[x,y], ...] centred on the origin.
//
// One field in the composition frame (+Y is the field's facing). _cols is the frontage across the
// approach, _rows the depth toward it; the commander widens or deepens a field by asking for more of
// either, and strings fields by laying several origins along a line. Alternate rows are offset half a
// spacing so no straight lane runs through -- an aligned grid lets a vehicle thread a column gap
// untouched. Pure: the grid is deterministic so it can be tested; the placer jitters and lays it.
fnc_hardpoint_minefield_lattice = {
    params ["_cols", "_rows", ["_spacing", 4]];
    private _x0 = - (_cols - 1) * _spacing / 2;
    private _y0 = - (_rows - 1) * _spacing / 2;
    private _out = [];
    for "_r" from 0 to (_rows - 1) do {
        private _shift = (_r % 2) * _spacing / 2;
        for "_c" from 0 to (_cols - 1) do {
            _out pushBack [_x0 + _c * _spacing + _shift, _y0 + _r * _spacing];
        };
    };
    _out
};
