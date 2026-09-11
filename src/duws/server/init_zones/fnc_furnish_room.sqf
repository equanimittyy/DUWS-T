// Locality: server -- createVehicle and the settle raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled/grid/catalog and before fnc_furnish_building,
// which spawns one instance per room. Server-only, not broadcast.
//
// Furnishes one room of the grid: 4-10 wall pieces onto near cells, then a central anchor (80% chance) with its
// seats and surface clutter, then a wall-backed anchor such as a desk (40% chance), then (50% chance) 1-3
// freestanding floor pieces such as a crate stack in the open middle. An anchor draws its seats
// and clutter from its own catalog family, so a desk gets an office chair and a dining table its own. Runs as
// its own scheduled thread so the per-piece settle waits of every room overlap in wall-clock instead of summing
// -- SQF is cooperative, so the win is the overlapped waits, not CPU. Rooms are independent (separated by
// blocked doorway cells), so each works on its own cell list with no shared occupancy across a wall; placed
// frozen objects are appended to the caller's shared _out, which the caller thaws once the house is laid out.
//
// Contract: [_rcells, _catalog, _bdir, _key, _out] -> appends placed frozen objects to _out
//   _rcells  this room's grid cells (the only cells this thread reads or reserves)
//   _catalog catalog hashmap from fnc_furnish_catalog
//   _bdir    building heading; floor pieces face it to sit square to the room
//   _key     teardown key filed through fnc_place_settled / fnc_duws_keep
//   _out     shared results array; the room's frozen objects are appended at the end
fnc_furnish_room = {
    if (!isServer) exitWith {};
    params ["_rcells", "_catalog", "_bdir", "_key", "_out"];
    if (_rcells isEqualTo []) exitWith {};
    private _grid = _rcells;

    #define SEAT_GAP 0.45
    #define TOP_CELL 0.4       // tabletop clutter grid pitch and min gap
    #define TOP_MARGIN 0.12    // keep clutter off the table lip
    #define CLUTTER_CAP 8      // max clutter items on one table
    #define PLACE_RETRY 3      // stop a room's pass after this many overlap rejects in a row (saturated)

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
        params ["_aObj", "_hx", "_hy", "_topZ", "_family"];
        private _surf = ["clutter", _family] call fnc_furnish_classesFor;
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
        private _out2 = [];
        private _propRows = _rows select { isClass (configFile >> "CfgVehicles" >> (_x select 0)) };
        private _lootRows = _rows select { !(isClass (configFile >> "CfgVehicles" >> (_x select 0))) };
        if (_propRows isNotEqualTo []) then { _out2 append ([_propRows, _aObj, _key, true, false, true, true] call fnc_place_settled) };
        if (_lootRows isNotEqualTo []) then { _out2 append ([_lootRows, _aObj, _key, true, true] call fnc_place_settled) };
        _out2
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
    // are capped out (which stops the pass). One _classCount per room (this whole call is one room).
    private _classCount = createHashMap;
    private _pickCapped = {
        params ["_pool"];
        private _avail = _pool select {
            private _m = (_catalog get _x) select 5;
            _m <= 0 || {(_classCount getOrDefault [_x, 0]) < _m}
        };
        if (_avail isEqualTo []) exitWith { "" };
        private _c = selectRandom _avail;
        _classCount set [_c, (_classCount getOrDefault [_c, 0]) + 1];
        _c
    };

    // Freeze each piece as it settles so a later piece's drop cannot knock it (thawed by the caller once the
    // house is laid out). Global, not local: the local form leaves clients simulating it. Filed under _key for GC.
    private _keepFrozen = {
        { _x enableSimulationGlobal false; _objs pushBack _x } forEach _this;
    };

    // _nearB < 0 seats the anchor central, facing the grid axis; _nearB >= 0 backs it onto that wall bearing
    // front-inward (a desk), so its wall-side seat slots fall on blocked cells and _seatOK drops them.
    private _placeAnchor = {
        params ["_cell", "_class", ["_nearB", -1]];
        (_catalog get _class) params ["", "_fy", "_family", "_seats"];
        _cell params ["_cpos", "", "", "_clear"];
        private _heading = if (_nearB >= 0) then { (_nearB + 180) - _fy } else { _bdir };
        private _frame = [_cpos, _heading] call _frameAt;
        private _aObj = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false, true, true] call fnc_place_settled) select 0;
        deleteVehicle _frame;

        private _bb = boundingBoxReal _aObj;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
        private _topZ = (_bb select 1) select 2;

        // Central: a half-extent past the cell clearance would overhang a wall; the wall anchor's backing self-checks.
        if (_nearB >= 0 && {!([_aObj, _nearB, _clear, _hx, _hy, _heading] call _backToWall)}) exitWith { deleteVehicle _aObj; [] };
        if (_nearB < 0 && {(_hx max _hy) > _clear}) exitWith { deleteVehicle _aObj; [] };

        private _fpCells = [getPosASL _aObj, _heading, _hx, _hy, 0.15] call _boxCells;
        if ((_fpCells findIf { _x select 5 }) >= 0) exitWith { deleteVehicle _aObj; [] };
        private _out2 = [_aObj];

        if (_seats != 0) then {
            private _chairs = ["seat", _family] call fnc_furnish_classesFor;
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
                    _out2 append ([_rows, _aObj, _key, true, false, true, true] call fnc_place_settled);
                };
            };
        };

        // Family "" is a freestand piece: skip the tabletop pass, whose "" family key would otherwise draw every clutter class.
        if (_family != "") then { _out2 append ([_aObj, _hx, _hy, _topZ, _family] call _surfacePack) };
        // Reserve the table plus its seat ring as one oriented footprint so nothing later packs into the chairs.
        { _x set [5, true] } forEach ([getPosASL _aObj, _heading, _hx + SEAT_GAP, _hy + SEAT_GAP, 0.1] call _boxCells);
        _out2
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

    // Back a wall-seated piece onto its wall, pulling clear in 0.1 m steps; true if it ends unburied. Shift is
    // clearance minus box depth (deep piece pulls off, shallow closes the gap). setPosWorld: a frozen body ignores setPosASL.
    private _backToWall = {
        params ["_o", "_nearB", "_clear", "_hx", "_hy", "_heading"];
        private _th = _nearB - _heading;
        private _depth = _hx * abs (sin _th) + _hy * abs (cos _th);
        private _shift = _clear - _depth;
        _o setPosWorld ((getPosWorld _o) vectorAdd [_shift * sin _nearB, _shift * cos _nearB, 0]);
        private _steps = 0;
        while { [_o, _hx, _hy] call _clipsBuilding && {_steps < 4} } do {
            _o setPosWorld ((getPosWorld _o) vectorAdd [-0.1 * sin _nearB, -0.1 * cos _nearB, 0]);
            _steps = _steps + 1;
        };
        !([_o, _hx, _hy] call _clipsBuilding)
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
        params ["_cell", "_class", ["_dropOnFail", false]];
        (_catalog get _class) params ["", "_fy"];
        _cell params ["_cpos", "", "_nearB", "_clear"];
        // Snap a corner cell's 45-degree ring read to the nearest grid axis so the piece sits square, not
        // diagonal; a straight wall already reads a cardinal and is untouched.
        if (_nearB >= 0) then { _nearB = _bdir + 90 * round ((_nearB - _bdir) / 90) };
        private _heading = if (_nearB >= 0) then { (_nearB + 180) - _fy } else { - _fy };
        private _frame = [_cpos, _heading] call _frameAt;
        private _o = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false, true, true, _dropOnFail] call fnc_place_settled) select 0;
        deleteVehicle _frame;
        if (isNull _o) exitWith { [] };
        private _bb = boundingBoxReal _o;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));

        if (_nearB >= 0 && {!([_o, _nearB, _clear, _hx, _hy, _heading] call _backToWall)}) exitWith { deleteVehicle _o; [] };
        // Reject if the seated footprint overlaps an already-placed piece (or the push-out drove it into
        // one); otherwise reserve the true oriented footprint.
        private _fpCells = [getPosASL _o, _heading, _hx, _hy, 0.1] call _boxCells;
        if ((_fpCells findIf { _x select 5 }) >= 0) exitWith { deleteVehicle _o; [] };
        { _x set [5, true] } forEach _fpCells;
        [_o]
    };

    // Wall pass: 4-10 wall pieces onto near cells, perpendicular to the wall, spaced by reservation. Best-effort
    // -- an overlap reject frees the cap slot and counts a miss; PLACE_RETRY misses in a row reads the room as
    // saturated and stops the pass. A placement resets the run, so a crowded corner does not cut it short.
    private _wallClasses = ["wall"] call fnc_furnish_classesFor;
    if (_wallClasses isNotEqualTo []) then {
        private _nWall = 4 + floor random 7;
        private _placed = 0; private _miss = 0;
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

    // Loop a few anchor classes so a table too big for this room yields to a smaller one.
    private _centerAnchors = ["anchor", "center"] call fnc_furnish_classesFor;
    if (_centerAnchors isNotEqualTo [] && {random 1 < 0.8}) then {
        private _cx = 0; private _cy = 0;
        { _cx = _cx + ((_x select 0) select 0); _cy = _cy + ((_x select 0) select 1) } forEach _rcells;
        _cx = _cx / (count _rcells); _cy = _cy / (count _rcells);

        private _got = false; private _tries = 0;
        while { !_got && _tries < PLACE_RETRY } do {
            private _cls = [_centerAnchors] call _pickCapped;
            if (_cls == "") exitWith {};
            ([_cls] call _dimsOf) params ["_ahx", "_ahy"];
            private _riX = ceil ((_ahx + SEAT_GAP) / _pitch);
            private _riY = ceil ((_ahy + SEAT_GAP) / _pitch);
            private _fit = _rcells select { (_x select 1) == "open" && {!(_x select 5)} && {[_x, _riX, _riY] call _ringsClear} };
            if (_fit isEqualTo []) then {
                _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                _tries = _tries + 1;
            } else {
                private _cell = ([_fit, [], { private _p = _x select 0; private _dx = (_p select 0) - _cx; private _dy = (_p select 1) - _cy; _dx * _dx + _dy * _dy }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                private _res = [_cell, _cls] call _placeAnchor;
                if (_res isEqualTo []) then {
                    _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                    _tries = _tries + 1;
                } else {
                    _res call _keepFrozen;
                    _got = true;
                };
            };
        };
    };

    // Independent second roll, not gated on the central slot above: a wall-backed anchor (a desk).
    private _wallAnchors = ["anchor", "wall"] call fnc_furnish_classesFor;
    if (_wallAnchors isNotEqualTo [] && {random 1 < 0.4}) then {
        private _wcls = [_wallAnchors] call _pickCapped;
        if (_wcls != "") then {
            private _wfree = _rcells select { (_x select 1) == "near" && {!(_x select 5)} };
            private _wgot = false; private _wtries = 0;
            while { !_wgot && _wtries < PLACE_RETRY && {count _wfree > 0} } do {
                private _cell = selectRandom _wfree;
                _wfree = _wfree - [_cell];
                private _nb = _cell select 2;
                if (_nb >= 0) then { _nb = _bdir + 90 * round ((_nb - _bdir) / 90) };
                private _res = [_cell, _wcls, _nb] call _placeAnchor;
                if (_res isEqualTo []) then { _wtries = _wtries + 1 } else { _res call _keepFrozen; _wgot = true };
            };
            if (!_wgot) then { _classCount set [_wcls, ((_classCount getOrDefault [_wcls, 0]) - 1) max 0] };
        };
    };

    // Freestanding floor bulk (a crate stack, a sack heap): reuses the central-anchor path, but its catalog
    // family "" makes _placeAnchor skip seats and (guarded above) the tabletop, so the piece lands inert.
    private _freeStand = ["freestand"] call fnc_furnish_classesFor;
    if (_freeStand isNotEqualTo [] && {random 1 < 0.5}) then {
        private _cx = 0; private _cy = 0;
        { _cx = _cx + ((_x select 0) select 0); _cy = _cy + ((_x select 0) select 1) } forEach _rcells;
        _cx = _cx / (count _rcells); _cy = _cy / (count _rcells);

        private _n = 1 + floor random 3;
        private _placed = 0; private _miss = 0;
        while { _placed < _n && _miss < PLACE_RETRY } do {
            private _cls = [_freeStand] call _pickCapped;
            if (_cls == "") exitWith {};
            ([_cls] call _dimsOf) params ["_ahx", "_ahy"];
            private _riX = ceil ((_ahx + SEAT_GAP) / _pitch);
            private _riY = ceil ((_ahy + SEAT_GAP) / _pitch);
            private _fit = _rcells select { (_x select 1) == "open" && {!(_x select 5)} && {[_x, _riX, _riY] call _ringsClear} };
            if (_fit isEqualTo []) then {
                _classCount set [_cls, ((_classCount getOrDefault [_cls, 0]) - 1) max 0];
                _miss = _miss + 1;
            } else {
                private _cell = ([_fit, [], { private _p = _x select 0; private _dx = (_p select 0) - _cx; private _dy = (_p select 1) - _cy; _dx * _dx + _dy * _dy }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                private _res = [_cell, _cls] call _placeAnchor;
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

    _out append _objs;
};
