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
//  12 roadDir      deg    bearing the nearest road runs; 0 when none is in scan range
//  13 roadLos      bool   line of sight from the gun to that road clears the terrain between
//  14 fofDist      m      open field of fire down the fall line before terrain masks the shot
//  15 nestDist     m      to the nearest MG/AT/GMG neighbour, else a large sentinel
//  16 nestDir      deg    that neighbour's facing; the interlock check compares it to this fall line

#define HP_FOF_STEP 40    // field-of-fire march: metres between samples down the fall line
#define HP_FOF_MAX  320   // ... and how far out to look before calling it fully open

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
    private _roadDir = 0;
    private _roadLos = 0;
    private _road = [_p, 40] call BIS_fnc_nearestRoad;
    if (!isNull _road) then {
        private _rp = getPosASL _road;
        _roadDist = _p distance2D _rp;
        private _roadZ = getTerrainHeightASL [_rp select 0, _rp select 1];
        _roadDrop = _candZ - _roadZ;
        // Line of sight gun -> road: a rise between the two masks the road even when the nest sits above
        // it, so overwatch must not score a road the gun cannot see. Muzzle ~2 m, a target on the road
        // ~1 m; terrainIntersectASL is true when the ground blocks the line, so a clear shot is index 0.
        _roadLos = [1, 0] select (terrainIntersectASL [[_p select 0, _p select 1, _candZ + 2], [_rp select 0, _rp select 1, _roadZ + 1]]);
        // Bearing the road runs, taken from this segment to a connected one so a roadblock can face
        // along it and sit square across the carriageway. atan2(east, north), the compass convention
        // the fall line above uses. A dead-end segment has no connection; fall back to its own heading.
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
    // Wider structure count for the gun nests: a cluster of buildings or containers inside 50 m walls
    // off a static's fields of fire. A count, penalised not vetoed -- one shed is fine, a compound is not.
    private _clutter50 = count (nearestTerrainObjects [_p, ["House", "Building"], 50, false]);

    private _hpDist = 1e9;
    // Measured against the live registry, so a cleared hardpoint no longer blocks new ground and the
    // siting loop spaces each placement off the ones already down. Row shape [key, pos, type, ..., dir].
    // Nearest nest neighbour (MG/AT/GMG) is tracked apart from _hpDist for the interlock score: only guns
    // that cross direct fire interlock, so an AA or battery next door is not one, and its facing (row
    // index 6) is what the convergence check reads. hpDist stays nearest-of-any, for spacing.
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

    // Field of fire down the fall line: march out along the facing bearing and find how far a level shot
    // clears before terrain masks it. Along the fall line because that is where an overwatch nest points;
    // flat ground never masks, so it reads fully open. Muzzle and a standing target both ~2 m ASL. A few
    // terrain-only rays, generation-time only.
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

// [_facts, _type] call fnc_hardpoint_score -> multiplier on the type's base weight; 0 is unplaceable.
//
// The number is the terrain factor the weighted roll multiplies base weights by. Returning 0 drops a
// type from the roll at a site that cannot hold it: water for every type, plus the per-type vetoes
// below -- artillery needs level ground, a roadblock needs a road, a minefield needs open clear
// ground. MG and AT never require a road: a hill overlooking nothing is still a firing position, so a
// road multiplies the score and its absence does not veto it.
fnc_hardpoint_score = {
    params ["_facts", "_type"];
    // roadDir (index 12) is the facing's, not the score's -- skipped. roadLos/fofDist default to "clear"
    // and "open", and nestDist/nestDir to "no neighbour", so a fixture row that omits them (the unit tests)
    // reads no LOS, field-of-fire or interlock penalty. 240 is the _fof ramp's open end; a literal, not
    // HP_FOF_MAX -- the score is pure and must not depend on the survey's march define, which the unit
    // harness does not preprocess.
    _facts params ["_onWater", "_relElev", "_slope", "_roadDist", "_roadDrop", "_treeNear", "_treeWide", "_buildingCnt", "_hpDist", ["_clutter50", 0], ["_aspect", 0], ["_aspectMag", 0], "", ["_roadLos", 1], ["_fofDist", 240], ["_nestDist", 1e9], ["_nestDir", 0]];

    if (_onWater) exitWith { 0 };

    private _ramp = { params ["_v", "_lo", "_hi"]; (((_v - _lo) / (_hi - _lo)) max 0) min 1 };

    private _high = [_relElev, 0, 6] call _ramp;                // local rise, 0..1
    private _flat = 1 - ([_slope, 0.6, 4] call _ramp);          // 1 flat, 0 rough
    private _roadNear = 1 - ([_roadDist, 0, 40] call _ramp);    // 1 on the road, 0 at/over 40 m
    private _overwatch = _roadNear * ([_roadDrop, 0, 4] call _ramp) * _roadLos;  // near, above AND visible
    private _clear = 1 - 0.6 * ([_clutter50, 0, 6] call _ramp); // 1 open, 0.4 walled in by structures
    // Interlock: a nest crosses fire with a nearby nest only if their arcs actually overlap. Proximity is
    // the gap to the nearest OTHER nest (MG/AT/GMG -- an AA or battery next door is no interlock); it lifts
    // the band a gun line sits in. Convergence gates that on the two guns' facings agreeing: a neighbour
    // facing the opposite way (delta near 180) covers the other direction and earns nothing, where the old
    // distance-only bonus paid out regardless. The candidate faces its fall line (_aspect); on flat ground
    // (aspectMag < 2.5) that facing is the outward radial the score cannot see, so convergence is skipped
    // (proximity only). A lone nest (_nestDist sentinel) has zero proximity, so no bonus either way.
    private _delta = abs (_aspect - _nestDir) % 360;
    if (_delta > 180) then { _delta = 360 - _delta };
    private _conv = if (_aspectMag < 2.5) then { 1 } else { 1 - ([_delta, 90, 180] call _ramp) };
    private _support = 1 + 0.6 * (1 - ([_nestDist, 150, 300] call _ramp)) * _conv; // 1.6 interlocked, 1.0 alone/opposed
    // Field of fire: a nest that can shoot only a short way before terrain masks it is worth less than one
    // looking down an open field. Floored at 0.6 -- close cover is still a position, not a veto.
    private _fof = 0.6 + 0.4 * ([_fofDist, 40, 240] call _ramp); // 0.6 boxed in, 1.0 open at 240 m+

    switch (_type) do {
        // Uphill is the whole point; a road below to fire along multiplies it, but only a road the gun
        // can see -- _overwatch is gated by line of sight, so a rise masking the road scores no bonus. AT
        // gains more from the road because the road is what its gun kills on, so with a good one it
        // roughly triples. All three fall off as structures crowd the arc (_clear) or a short field of
        // fire boxes them in (_fof), and lift where they interlock (_support).
        case "MG":  { (0.5 + 1.0 * _high) * (1 + 0.8 * _overwatch) * _clear * _support * _fof };
        case "AT":  { (0.5 + 1.0 * _high) * (1 + 1.5 * _overwatch) * _clear * _support * _fof };

        // A gun nest like the MG, but it lobs grenades over cover rather than firing down a road, so a
        // road below counts for less.
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
        // enough to lay. Derived from the plan's siting note, not the placement-preference list.
        case "MORTAR": { (0.4 + 1.2 * ([- _relElev, 0, 6] call _ramp)) * (0.5 + 0.5 * _flat) };

        // The mined patch itself must be open: a tree, a building or another emplacement on top of it
        // is each a veto, not a penalty.
        case "MINEFIELD": {
            if (_treeNear > 0 || {_buildingCnt > 0} || {_hpDist < 30}) exitWith { 0 };
            0.4 + 1.6 * _flat
        };

        // A radio mast wants a hilltop crest: high above the ring, with the ground falling away on
        // every bearing. _high rewards the rise; _crest rewards a fall line that cancels (aspectMag
        // near 0, a symmetric dome) and docks a one-sided slope (a hillside, high aspectMag). A flat
        // plain has no fall line either, so _high is what tells a crest from the flat. Never zero:
        // terrain is a preference for the deliberate seed, never a veto.
        case "RADIO": {
            private _crest = 1 - ([_aspectMag, 2.5, 12] call _ramp);  // 1 symmetric, 0 one clear downhill
            (0.3 + 1.7 * _high) * (0.4 + 0.6 * _crest)
        };

        // An unmapped type sites anywhere until it is given a preference.
        default { 1 };
    };
};

// [_type, _aspectDir, _aspectMag, _radialDir, _roadDir] call fnc_hardpoint_facing -> heading in degrees.
//
// The heading a sited emplacement faces. A roadblock sits square across the carriageway -- its gate spans
// the road -- and of the road's two headings takes the one nearer _radialDir, so its guns point up the
// approach rather than back down the road behind it. _radialDir is outward from the zone for the ring, and
// toward BLU HQ for the corridor pass, so a corridor block faces the way the player drives in. The overwatch
// nests are the other point of this: sited on a rise above a road, a radial heading can face the gun back
// into the hillside while the road it overlooks sits off its shoulder. Those face the fall line instead --
// down the slope, at the low ground the position exists to watch. Below a faint gradient there is no single
// downhill (flat ground, or a symmetric crest whose fall vectors cancel), so they fall back to radial rather
// than snap to a bearing that is noise. The remaining flat types' heading is cosmetic, so they keep the
// outward radial the loop hands in (zone centre toward the approach). Pure, so the choice is unit-tested.
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
