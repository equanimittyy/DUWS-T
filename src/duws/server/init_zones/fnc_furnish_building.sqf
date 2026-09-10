// Locality: server -- createVehicle and the grid raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled, fnc_furnish_grid and fnc_furnish_catalog,
// which it calls. Not broadcast: callers remoteExec it to the server.
//
// Class-agnostic on the building (survives modded/unrecognised maps), catalog-driven on the furniture
// (which is ours). fnc_furnish_grid infers the interior as a per-storey cell grid split into rooms; this
// fills it in ordered passes, each reserving the cells it takes in the grid's `occupied` flag -- so no two
// pieces share a cell, and the nav-path cells and flagged doorways stay clear (no trooper sealed behind a
// sofa, no door blocked). Facing is
// by construction, corrected per class by catalog frontYaw. Pieces are measured (once per class, cached) and
// fitted to free cells before they spawn, not dropped then rejected on overlap: a wall piece is seated on its
// wall plane (no clip, no float) and an anchor too big for its cell is rejected. A room is
// placed frozen and woken once laid out. An empty grid (a ruin, a view-only prop) degrades to the seed nav
// points, flat, logged.
//
// Contract: [_building, _key, _sets, _quota] -> [_objs placed]
//   _building  OBJECT to furnish
//   _key       teardown key filed through fnc_place_settled / fnc_duws_keep
//   _sets      eligible furniture sets (e.g. ["living"]); [] = all of living/sleeping/work
//   _quota     retained for the caller contract; placement density is grid-derived, so <= 0 = default
fnc_furnish_building = {
    if (!isServer) exitWith { [] };
    params ["_building", ["_key", "furnish"], ["_sets", []], ["_quota", 0]];
    if (isNull _building) exitWith { [] };

    call fnc_furnish_catalog;
    private _grid = [_building] call fnc_furnish_grid;

    // No interior geometry: synthesise open cells at the seed nav points so the passes below still run
    // (seats find no neighbour cell and self-skip, nothing reserves), and log the degrade.
    private _degraded = false;
    if (_grid isEqualTo []) then {
        _degraded = true;
        ["WARN", "FURNISH", format ["%1 has no grid; furnishing seed points flat", typeOf _building]] call fnc_log;
        _grid = (_building buildingPos -1) apply { [AGLToASL _x, "open", -1, 1.5, 0, false, 0, 0, 0] };
    };
    if (_grid isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["%1: nothing to furnish", typeOf _building]] call fnc_log; []
    };
    // Deep copy: fnc_furnish_grid caches the cells on the building, and the passes below stamp the
    // `occupied` flag on each -- mutating the cache would leave a re-furnish seeing last run's reservations.
    _grid = +_grid;

    // Priority order for assigning a set to a room by size (biggest -> living), narrowed to the request.
    private _prio = ["living", "work", "sleeping"] select { _sets isEqualTo [] || {_x in _sets} };
    if (_prio isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["no furniture set matched %1", _sets]] call fnc_log; []
    };

    #define SEAT_GAP 0.45
    #define TOP_CELL 0.4       // tabletop clutter grid pitch and min gap
    #define TOP_MARGIN 0.12    // keep clutter off the table lip
    #define CLUTTER_CAP 8      // max clutter items on one table
    #define FILL_DIV 22        // ~1 anchor per this many open room cells
    #define WALL_DIV 7         // ~1 wall piece per this many near-wall cells
    #define RUG_DIV 40         // ~1 rug per this many open room cells
    #define WALL_MAX 5         // max wall pieces per room
    #define ANCHOR_MAX 2       // max anchors per room
    #define RUG_MAX 2          // max rugs per room
    #define PLACE_RETRY 3      // stop a room's pass after this many overlap rejects in a row (saturated)

    private _catalog = call fnc_furnish_catalog;
    private _objs = [];

    // boundingBoxReal is model-space, so a probe's box equals the placed piece's: measure once per class
    // (cached mission-wide) to know a footprint before spawning, instead of spawning then rejecting on overlap.
    private _dimsOf = {
        params ["_class"];
        private _cache = missionNamespace getVariable ["DUWS_furnishDims", createHashMap];
        private _d = _cache getOrDefault [_class, []];
        if (_d isNotEqualTo []) exitWith { _d };
        private _p = createVehicleLocal [_class, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        private _bb = boundingBoxReal _p;
        deleteVehicle _p;
        _d = [(abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0)),
              (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1))];
        _cache set [_class, _d];
        missionNamespace setVariable ["DUWS_furnishDims", _cache];
        _d
    };

    // Grid axis. Floor pieces face this to sit square to the room; a world-north heading skews them diagonally
    // across the grid on a rotated building.
    private _bdir = getDir _building;

    // Mark every grid cell within _r of a point occupied. One-shot server pass, so a linear scan is fine.
    private _reserve = {
        params ["_p", "_r"];
        { if ((_p distance2D (_x select 0)) <= _r) then { _x set [5, true] } } forEach _grid;
    };
    // Cells whose centre lies inside a piece's real footprint: its oriented box (hx,hy half-extents, model
    // +Y along _heading) grown by _m. A circle mis-covers a long piece, so reserving and testing the true
    // box is what keeps pieces from overlapping -- and overlapping boxes are what physx flings on wake.
    private _boxCells = {
        params ["_p", "_heading", "_hx", "_hy", "_m"];
        private _bx = _hx + _m; private _by = _hy + _m;
        private _s = sin _heading; private _c = cos _heading;
        _grid select {
            private _v = (_x select 0) vectorDiff _p;
            private _lx = (_v select 0) * _c - (_v select 1) * _s;
            private _ly = (_v select 0) * _s + (_v select 1) * _c;
            (abs _lx <= _bx) && {abs _ly <= _by}
        }
    };
    // Occupancy only, not blocked/absent cells: a wall piece's back legitimately grazes the wall, as the
    // post-settle overlap guard also tolerates.
    private _footFree = {
        params ["_center", "_heading", "_hx", "_hy", "_m"];
        (([_center, _heading, _hx, _hy, _m] call _boxCells) findIf { _x select 5 }) < 0
    };
    private _cellAt = {
        params ["_p"];
        private _hit = []; private _bd = 0.5;
        { private _d = _p distance2D (_x select 0); if (_d < _bd) then { _bd = _d; _hit = _x } } forEach _grid;
        _hit
    };
    // A seat slot is placeable only over a free, non-blocked cell -- so a chair never lands in a wall or
    // on another piece. No cell there at all (the degraded seed grid) also reads as no -- seats self-skip.
    private _seatOK = {
        params ["_wp"];
        private _c = [_wp] call _cellAt;
        _c isNotEqualTo [] && {!(_c select 5)} && {(_c select 1) != "blocked"} && {(_c select 1) != "door"}
    };

    // Cell lookup by storey/i/j -- holds references to the grid cells, so a reservation stamped on a cell
    // during the passes is seen through it.
    private _ijCell = createHashMap;
    { _x params ["", "", "", "", "", "", "_i", "_j", "_s"]; _ijCell set [format ["%1_%2_%3", _s, _i, _j], _x] } forEach _grid;

    // Pitch read off the grid, not assumed 0.5: fnc_furnish_grid coarsens it under its cell cap.
    private _pitch = 0.5;
    {
        _x params ["", "", "", "", "", "", "_i", "_j", "_s"];
        private _n = _ijCell getOrDefault [format ["%1_%2_%3", _s, _i + 1, _j], []];
        if (_n isNotEqualTo []) exitWith { _pitch = (_x select 0) distance2D (_n select 0) };
    } forEach _grid;

    // Clear floor sized to the piece: a big table demands more walk-round room than a small one.
    private _ringsClear = {
        params ["_cell", "_riX", "_riY"];
        _cell params ["", "", "", "", "", "", "_i", "_j", "_s"];
        private _clear = true;
        for "_di" from (- _riX) to _riX do {
            for "_dj" from (- _riY) to _riY do {
                private _c = _ijCell getOrDefault [format ["%1_%2_%3", _s, _i + _di, _j + _dj], []];
                if (_c isEqualTo [] || {(_c select 1) == "blocked"} || {_c select 5}) exitWith { _clear = false };
            };
            if (!_clear) exitWith {};
        };
        _clear
    };

    // Grid-pack a random subset of a set's clutter across a placed anchor's measured top, seated on the
    // anchor object so it travels and turns with the table. One class per cell, jittered and randomly
    // turned, split prop vs inventory item (they seat differently in fnc_place_settled).
    private _surfacePack = {
        params ["_aObj", "_hx", "_hy", "_topZ", "_set"];
        private _surf = ["clutter", _set] call fnc_furnish_classesFor;
        if (_surf isEqualTo []) exitWith { [] };
        private _uhx = (_hx - TOP_MARGIN) max 0;
        private _uhy = (_hy - TOP_MARGIN) max 0;
        private _cols = 1 max floor (2 * _uhx / TOP_CELL);
        private _rowsN = 1 max floor (2 * _uhy / TOP_CELL);
        private _cells = [];
        for "_i" from 0 to (_cols - 1) do {
            for "_j" from 0 to (_rowsN - 1) do {
                _cells pushBack [(- _uhx) + TOP_CELL / 2 + _i * TOP_CELL, (- _uhy) + TOP_CELL / 2 + _j * TOP_CELL];
            };
        };
        private _shuf = _cells apply { [random 1, _x] };
        _shuf sort true;
        private _n = ((1 max round ((count _cells) * 0.45)) min CLUTTER_CAP) min (count _cells);
        private _rows = (_shuf select [0, _n]) apply {
            (_x select 1) params ["_cx", "_cy"];
            [selectRandom _surf, _cx + (random 0.12) - 0.06, _cy + (random 0.12) - 0.06, _topZ, random 360]
        };
        private _out = [];
        private _propRows = _rows select { isClass (configFile >> "CfgVehicles" >> (_x select 0)) };
        private _lootRows = _rows select { !(isClass (configFile >> "CfgVehicles" >> (_x select 0))) };
        if (_propRows isNotEqualTo []) then { _out append ([_propRows, _aObj, _key, true, false, true, true] call fnc_place_settled) };
        if (_lootRows isNotEqualTo []) then { _out append ([_lootRows, _aObj, _key, true, true] call fnc_place_settled) };
        _out
    };

    // An invisible frame the placement rides, so fnc_place_settled seats the piece on the floor at the
    // cell with the wanted heading; deleted by the caller after the piece is measured off it.
    private _frameAt = {
        params ["_posASL", "_heading"];
        // Snap to the floor at the piece's own XY: the cell's stored Z is a grid-centre raycast and can sit
        // proud there, and a frozen piece locks that hover in.
        private _hit = lineIntersectsSurfaces [_posASL vectorAdd [0, 0, 0.3], _posASL vectorAdd [0, 0, -0.8], objNull, objNull, true, 1, "GEOM"];
        if (_hit isNotEqualTo []) then { _posASL = (_hit select 0) select 0 };
        private _f = createVehicle ["Land_HelipadEmpty_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _f setPosASL _posASL;
        _f setVectorDirAndUp [[sin _heading, cos _heading, 0], [0, 0, 1]];
        _f
    };

    // maxPerRoom enforcement: _pickCapped returns a random pool class still under its cap, or "" when all
    // are capped out (which stops the pass). _classCount is re-made per room below; both resolve it off the
    // caller's scope at call time.
    private _classCount = createHashMap;
    private _pickCapped = {
        params ["_pool"];
        private _avail = _pool select {
            private _m = (_catalog get _x) select 4;
            _m <= 0 || {(_classCount getOrDefault [_x, 0]) < _m}
        };
        if (_avail isEqualTo []) exitWith { "" };
        private _c = selectRandom _avail;
        _classCount set [_c, (_classCount getOrDefault [_c, 0]) + 1];
        _c
    };

    // Freeze each piece as it settles so a later piece's drop cannot knock it (thawed as a whole once the house
    // is laid out). Global, not local: the local form leaves clients simulating it. Filed under _key for GC.
    private _keepFrozen = {
        { _x enableSimulationGlobal false; _objs pushBack _x } forEach _this;
    };

    // Place an anchor with its seats (per the `seats` rule) and clutter, reserving the footprint and each
    // seated cell.
    private _placeAnchor = {
        params ["_cell", "_class", "_set"];
        (_catalog get _class) params ["", "_fy", "", "_seats"];
        _cell params ["_cpos", "", "", "_clear"];

        // Anchors sit in the open, no wall backing, so face the grid axis (square to the room); a desk's single
        // seat still lands on its real front via the frontYaw offset in the seat block below.
        private _frame = [_cpos, _bdir] call _frameAt;
        private _aObj = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false, true, true] call fnc_place_settled) select 0;
        deleteVehicle _frame;

        private _bb = boundingBoxReal _aObj;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
        private _topZ = (_bb select 1) select 2;

        // Reject an anchor whose half-extent overruns the cell's clearance (its nearest-wall distance): it
        // would overhang a wall. The caller frees the cap slot, so a big table just will not take a tight cell.
        if ((_hx max _hy) > _clear) exitWith { deleteVehicle _aObj; [] };

        // Reject if the footprint overlaps a piece already placed (a wall from the earlier pass).
        private _fpCells = [getPosASL _aObj, _bdir, _hx, _hy, 0.15] call _boxCells;
        if ((_fpCells findIf { _x select 5 }) >= 0) exitWith { deleteVehicle _aObj; [] };
        private _out = [_aObj];

        if (_seats != 0) then {
            private _chairs = ["seat", _set] call fnc_furnish_classesFor;
            if (_chairs isNotEqualTo []) then {
                private _edges = if (_seats < 0) then {
                    [[0, _hy + SEAT_GAP], [0, -(_hy + SEAT_GAP)], [_hx + SEAT_GAP, 0], [-(_hx + SEAT_GAP), 0]]
                } else {
                    // On the front: model-bearing _fy is the desk's real front (it points at _fy at
                    // heading 0), so the chair sits that far along it.
                    private _d = (_hy max _hx) + SEAT_GAP;
                    private _e = [];
                    for "_k" from 1 to _seats do { _e pushBack [_d * sin _fy, _d * cos _fy] };
                    _e
                };
                // One chair class for the whole set, so a table is not ringed by mismatched seats.
                private _cc = selectRandom _chairs;
                private _cfy = (_catalog get _cc) select 1;
                private _rows = [];
                {
                    _x params ["_ox", "_oy"];
                    private _wp = _aObj modelToWorld [_ox, _oy, 0];
                    if ([_wp] call _seatOK) then {
                        // Heading is the bearing from the seat back to the anchor centre, less the chair's
                        // own front offset, so the seat faces the table by construction.
                        _rows pushBack [_cc, _ox, _oy, 0, ((- _ox) atan2 (- _oy)) - _cfy];
                        [_wp, 0.3] call _reserve;
                    };
                } forEach _edges;
                if (_rows isNotEqualTo []) then {
                    _out append ([_rows, _aObj, _key, true, false, true, true] call fnc_place_settled);
                };
            };
        };

        _out append ([_aObj, _hx, _hy, _topZ, _set] call _surfacePack);
        // Reserve the table plus its seat ring as one oriented footprint (the grid axis) so nothing later packs
        // into the chairs.
        { _x set [5, true] } forEach ([getPosASL _aObj, _bdir, _hx + SEAT_GAP, _hy + SEAT_GAP, 0.1] call _boxCells);
        _out
    };

    // True when a seated piece's body is buried in the building: the one-point seat clearance under-reads on an
    // odd profile or a corner. Rays span a slightly-inset footprint ring (its own geometry ignored), so a back
    // merely flush with the wall is not read as a clip.
    private _clipsBuilding = {
        params ["_o", "_hx", "_hy"];
        private _ihx = (_hx - 0.1) max 0.05;
        private _ihy = (_hy - 0.1) max 0.05;
        private _bb = boundingBoxReal _o;
        private _pts = [[_ihx, _ihy], [-_ihx, _ihy], [_ihx, -_ihy], [-_ihx, -_ihy], [0, _ihy], [0, -_ihy], [_ihx, 0], [-_ihx, 0]];
        private _hit = false;
        {
            private _mz = _x;
            private _beg = AGLToASL (_o modelToWorld [0, 0, _mz]);
            {
                _x params ["_lx", "_ly"];
                private _r = lineIntersectsSurfaces [_beg, AGLToASL (_o modelToWorld [_lx, _ly, _mz]), _o, objNull, true, 1, "GEOM"];
                if (_r isNotEqualTo []) exitWith { _hit = true };
            } forEach _pts;
            if (_hit) exitWith {};
        } forEach [((_bb select 0) select 2) + 0.1, ((_bb select 1) select 2) - 0.1];
        _hit
    };

    // Predict the seated pose before spawning so a cell's footprint can be tested; _placeWall re-derives it
    // from the settled object, whose rest position can differ.
    private _wallPose = {
        params ["_cell", "_class"];
        (_catalog get _class) params ["", "_fy"];
        _cell params ["_cpos", "", "_nearB", "_clear"];
        ([_class] call _dimsOf) params ["_hx", "_hy"];
        if (_nearB >= 0) then { _nearB = _bdir + 90 * round ((_nearB - _bdir) / 90) };
        private _heading = if (_nearB >= 0) then { (_nearB + 180) - _fy } else { - _fy };
        private _center = _cpos;
        if (_nearB >= 0) then {
            private _th = _nearB - _heading;
            private _depth = _hx * abs (sin _th) + _hy * abs (cos _th);
            private _shift = _clear - _depth;
            _center = _cpos vectorAdd [_shift * sin _nearB, _shift * cos _nearB, 0];
        };
        [_center, _heading, _hx, _hy]
    };
    private _wallFits = {
        params ["_cell", "_class"];
        ([_cell, _class] call _wallPose) params ["_c", "_h", "_hx", "_hy"];
        [_c, _h, _hx, _hy, 0.1] call _footFree
    };

    // Place a single back-to-wall piece (sofa/bed/cabinet) at a near cell, front off the wall; returns [_o],
    // or [] when the seated footprint would overlap a placed piece or stays buried in the wall.
    private _placeWall = {
        params ["_cell", "_class"];
        (_catalog get _class) params ["", "_fy"];
        _cell params ["_cpos", "", "_nearB", "_clear"];
        // Snap a corner cell's 45-degree ring read to the nearest grid axis so the piece sits square, not
        // diagonal; a straight wall already reads a cardinal and is untouched.
        if (_nearB >= 0) then { _nearB = _bdir + 90 * round ((_nearB - _bdir) / 90) };
        private _heading = if (_nearB >= 0) then { (_nearB + 180) - _fy } else { - _fy };
        private _frame = [_cpos, _heading] call _frameAt;
        private _o = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false, true, true] call fnc_place_settled) select 0;
        deleteVehicle _frame;
        private _bb = boundingBoxReal _o;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));

        // Seat the back on the wall: depth toward the wall is the box projected onto the wall bearing (model
        // +Y points at _heading), so shift the centre by clearance-minus-depth along it -- a deep piece pulls
        // off so it cannot clip through, a shallow one closes the gap.
        if (_nearB >= 0) then {
            private _th = _nearB - _heading;
            private _depth = _hx * abs (sin _th) + _hy * abs (cos _th);
            private _shift = _clear - _depth;
            // setPosWorld, not setPosASL: the piece came back frozen and a frozen body ignores setPosASL.
            _o setPosWorld ((getPosWorld _o) vectorAdd [_shift * sin _nearB, _shift * cos _nearB, 0]);

            // Pull off the wall in 0.1 m steps until the body clears, reject if still buried past 0.4 m.
            private _steps = 0;
            while { [_o, _hx, _hy] call _clipsBuilding && {_steps < 4} } do {
                _o setPosWorld ((getPosWorld _o) vectorAdd [-0.1 * sin _nearB, -0.1 * cos _nearB, 0]);
                _steps = _steps + 1;
            };
            if ([_o, _hx, _hy] call _clipsBuilding) exitWith { deleteVehicle _o; [] };
        };
        // Reject if the seated footprint overlaps an already-placed piece (or the push-out drove it into
        // one); otherwise reserve the true oriented footprint.
        private _fpCells = [getPosASL _o, _heading, _hx, _hy, 0.1] call _boxCells;
        if ((_fpCells findIf { _x select 5 }) >= 0) exitWith { deleteVehicle _o; [] };
        { _x set [5, true] } forEach _fpCells;
        [_o]
    };

    // Group cells by room, largest first, so the main room reads as the living set.
    private _rooms = createHashMap;
    {
        private _rid = _x select 4;
        if (_rid >= 0) then { private _l = _rooms getOrDefault [_rid, []]; _l pushBack _x; _rooms set [_rid, _l] };
    } forEach _grid;
    private _bySize = [keys _rooms, [], { -(count (_rooms get _x)) }, "ASCEND"] call BIS_fnc_sortBy;

    // Path preservation: reserve a thin corridor along the segments linking consecutive nav points, so a
    // walk path stays clear -- the garrison-conflict fix, leaving the nav lattice open rather than sealing
    // a trooper behind furniture. Skipped on the degraded seed grid, where the seeds ARE the only cells.
    // Long jumps (a segment crossing the shell) are dropped so the corridor stays local, not diagonal.
    if (!_degraded) then {
        private _seeds = _building buildingPos -1;
        for "_i" from 0 to ((count _seeds) - 2) do {
            private _a = AGLToASL (_seeds select _i);
            private _b = AGLToASL (_seeds select (_i + 1));
            if (_a distance2D _b < 6) then {
                private _steps = ceil ((_a distance2D _b) / 0.5);
                for "_s" from 0 to _steps do {
                    private _t = if (_steps == 0) then { 0 } else { _s / _steps };
                    [_a vectorAdd ((_b vectorDiff _a) vectorMultiply _t), 0.35] call _reserve;
                };
            };
        };
    };

    {
        private _rid = _x;
        private _rcells = _rooms get _rid;
        private _set = _prio select (_forEachIndex mod (count _prio));
        private _classCount = createHashMap;   // per-room, drives the maxPerRoom caps below

        // Wall pass: wall pieces onto near cells, perpendicular to the wall, spaced by reservation.
        private _wallClasses = ["wall", _set] call fnc_furnish_classesFor;
        if (_wallClasses isNotEqualTo []) then {
            // Fill up to _nWall pieces; an overlap reject frees its cap slot and counts a miss, and
            // PLACE_RETRY misses in a row means the room is saturated, so stop rather than spin. A placement
            // resets the run, so a crowded corner does not cut the whole pass short.
            private _nWall = (floor ((count (_rcells select { (_x select 1) == "near" })) / WALL_DIV)) min WALL_MAX;
            private _placed = 0; private _miss = 0;

            // Required pieces first: a wall class flagged required in the catalog (a bedroom's bed) is attempted
            // before the random fill and regardless of _nWall, so a small room still gets it and a random shelf
            // pick cannot crowd it out. Cap-counted so the fill below will not re-pick it.
            {
                private _reqCls = _x;
                private _tries = 0; private _got = false;
                while { !_got && _tries < PLACE_RETRY } do {
                    private _free = _rcells select { (_x select 1) == "near" && {!(_x select 5)} && {[_x, _reqCls] call _wallFits} };
                    if (_free isEqualTo []) exitWith {};
                    private _res = [selectRandom _free, _reqCls] call _placeWall;
                    if (_res isEqualTo []) then { _tries = _tries + 1 } else {
                        _res call _keepFrozen;
                        _classCount set [_reqCls, (_classCount getOrDefault [_reqCls, 0]) + 1];
                        _placed = _placed + 1;
                        _got = true;
                    };
                };
            } forEach (_wallClasses select { ((_catalog get _x) select 5) > 0 });

            while { _placed < _nWall && _miss < PLACE_RETRY } do {
                private _free = _rcells select { (_x select 1) == "near" && {!(_x select 5)} };
                if (_free isEqualTo []) exitWith {};
                private _cls = [_wallClasses] call _pickCapped;
                if (_cls == "") exitWith {};   // every wall class hit its per-room cap
                private _fit = _free select { [_x, _cls] call _wallFits };
                if (_fit isEqualTo []) then {
                    _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                    _miss = _miss + 1;
                } else {
                    private _res = [selectRandom _fit, _cls] call _placeWall;
                    if (_res isEqualTo []) then {
                        _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                        _miss = _miss + 1;
                    } else {
                        _res call _keepFrozen;
                        _placed = _placed + 1;
                        _miss = 0;
                    };
                };
            };
        };

        // Anchor pass: anchors into the roomiest free open cells first.
        private _anchorClasses = ["anchor", _set] call fnc_furnish_classesFor;
        if (_anchorClasses isNotEqualTo []) then {
            // Retry as the wall pass: a rejected anchor (too big for the cell, or overlapping) frees its cap
            // slot and retries with another class -- the roomiest cell stays the best bet -- giving up after
            // PLACE_RETRY misses in a row.
            private _nAnch = (1 max floor ((count (_rcells select { (_x select 1) == "open" })) / FILL_DIV)) min ANCHOR_MAX;
            private _placed = 0; private _miss = 0;
            while { _placed < _nAnch && _miss < PLACE_RETRY } do {
                private _cls = [_anchorClasses] call _pickCapped;
                if (_cls == "") exitWith {};
                ([_cls] call _dimsOf) params ["_ahx", "_ahy"];
                private _riX = ceil ((_ahx + SEAT_GAP) / _pitch);
                private _riY = ceil ((_ahy + SEAT_GAP) / _pitch);
                private _free = _rcells select { (_x select 1) == "open" && {!(_x select 5)} && {[_x, _riX, _riY] call _ringsClear} };
                if (_free isEqualTo []) then {
                    _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                    _miss = _miss + 1;
                } else {
                    private _cell = ([_free, [], { -(_x select 3) }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                    private _res = [_cell, _cls, _set] call _placeAnchor;
                    if (_res isEqualTo []) then {
                        _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                        _miss = _miss + 1;
                    } else {
                        _res call _keepFrozen;
                        _placed = _placed + 1;
                        _miss = 0;
                    };
                };
            };
        };

        // Rug pass: flat floor covers, footprint-checked and reserved like an anchor -- a rug slid under a
        // placed piece shares its floor-height bounding box and flings both apart on thaw.
        private _rugClasses = ["rug", _set] call fnc_furnish_classesFor;
        if (_rugClasses isNotEqualTo []) then {
            private _nRug = (floor ((count (_rcells select { (_x select 1) != "blocked" && {(_x select 1) != "door"} })) / RUG_DIV)) min RUG_MAX;
            private _placed = 0; private _miss = 0;
            while { _placed < _nRug && _miss < PLACE_RETRY } do {
                private _cls = [_rugClasses] call _pickCapped;
                if (_cls == "") exitWith {};
                ([_cls] call _dimsOf) params ["_rhx", "_rhy"];
                private _free = _rcells select { (_x select 1) != "blocked" && {(_x select 1) != "door"} && {!(_x select 5)} && {[_x select 0, _bdir, _rhx, _rhy, 0.1] call _footFree} };
                if (_free isEqualTo []) then {
                    _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                    _miss = _miss + 1;
                } else {
                    private _cell = selectRandom _free;
                    private _frame = [_cell select 0, _bdir] call _frameAt;
                    private _rugObj = ([[[_cls, 0, 0, 0, 0]], _frame, _key, true, false, true, true] call fnc_place_settled) select 0;
                    deleteVehicle _frame;
                    private _bb = boundingBoxReal _rugObj;
                    private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
                    private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
                    private _fpCells = [getPosASL _rugObj, _bdir, _hx, _hy, 0.1] call _boxCells;
                    if ((_fpCells findIf { _x select 5 }) >= 0) then {
                        deleteVehicle _rugObj;
                        _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                        _miss = _miss + 1;
                    } else {
                        { _x set [5, true] } forEach _fpCells;
                        [_rugObj] call _keepFrozen;
                        _placed = _placed + 1;
                        _miss = 0;
                    };
                };
            };
        };
    } forEach _bySize;

    // Whole-house thaw: each piece rests where it settled, so going live adds no impulse; live, they fall into
    // rubble when the building is destroyed.
    { _x enableSimulationGlobal true } forEach _objs;

    ["INFO", "FURNISH", format ["%1: placed %2 object(s) across %3 room(s)", typeOf _building, count _objs, count _bySize]] call fnc_log;
    _objs
};
