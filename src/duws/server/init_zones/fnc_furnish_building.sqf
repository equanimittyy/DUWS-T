// Locality: server -- createVehicle and the grid raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled, fnc_furnish_grid and fnc_furnish_catalog,
// which it calls. Not broadcast: callers remoteExec it to the server.
//
// Furnishes an arbitrary building lived-in, class-agnostic on the building (so it survives modded/
// unrecognised maps) but catalog-driven on the furniture (which is ours). fnc_furnish_grid infers the
// interior as a per-storey cell grid split into rooms; this places furniture over it in ordered passes,
// each reserving the cells it fills in the grid's own `occupied` flag -- so two pieces can never take the
// same cell (deterministic clip-avoidance) and the nav-path cells stay clear (so a garrison trooper is
// not sealed behind a sofa). Facing is by construction: a seat's heading is the bearing to its anchor,
// a wall piece's front points off its wall -- each corrected by the class's catalog frontYaw.
//
// A building with no usable interior geometry (a ruin, a view-only prop) yields an empty grid; furnish
// then degrades to the seed nav points, flat, and logs it, rather than silently doing nothing.
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

    private _catalog = call fnc_furnish_catalog;
    private _objs = [];

    // Mark every grid cell within _r of a point occupied. One-shot server pass, so a linear scan is fine.
    private _reserve = {
        params ["_p", "_r"];
        { if ((_p distance2D (_x select 0)) <= _r) then { _x set [5, true] } } forEach _grid;
    };
    // Nearest grid cell to a world point within a cell's reach, or [].
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
        _c isNotEqualTo [] && {!(_c select 5)} && {(_c select 1) != "blocked"}
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
        if (_propRows isNotEqualTo []) then { _out append ([_propRows, _aObj, _key, true, false] call fnc_place_settled) };
        if (_lootRows isNotEqualTo []) then { _out append ([_lootRows, _aObj, _key, true, true] call fnc_place_settled) };
        _out
    };

    // An invisible frame the placement rides, so fnc_place_settled seats the piece on the floor at the
    // cell with the wanted heading; deleted by the caller after the piece is measured off it.
    private _frameAt = {
        params ["_posASL", "_heading"];
        private _f = createVehicle ["Land_HelipadEmpty_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _f setPosASL _posASL;
        _f setVectorDirAndUp [[sin _heading, cos _heading, 0], [0, 0, 1]];
        _f
    };

    // Place an anchor (table/desk) at a cell, then its seats per the catalog `seats` rule and its clutter.
    // A dining table (seats -1) takes a chair on each open side; a desk (seats N) takes N on its front.
    // Reserves the anchor footprint and every seated cell. Returns the objects placed.
    private _placeAnchor = {
        params ["_cell", "_class", "_set"];
        (_catalog get _class) params ["", "_fy", "", "_seats"];
        _cell params ["_cpos"];

        // Anchors sit in the open, no wall backing, so a fixed heading; a desk's single seat still lands
        // on its real front via the frontYaw offset in the seat block below.
        private _frame = [_cpos, 0] call _frameAt;
        private _aObj = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false] call fnc_place_settled) select 0;
        deleteVehicle _frame;
        private _out = [_aObj];

        private _bb = boundingBoxReal _aObj;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
        private _topZ = (_bb select 1) select 2;

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
                private _rows = [];
                {
                    _x params ["_ox", "_oy"];
                    private _wp = _aObj modelToWorld [_ox, _oy, 0];
                    if ([_wp] call _seatOK) then {
                        private _cc = selectRandom _chairs;
                        private _cfy = (_catalog get _cc) select 1;
                        // Heading is the bearing from the seat back to the anchor centre, less the chair's
                        // own front offset, so the seat faces the table by construction.
                        _rows pushBack [_cc, _ox, _oy, 0, ((- _ox) atan2 (- _oy)) - _cfy];
                        [_wp, 0.3] call _reserve;
                    };
                } forEach _edges;
                if (_rows isNotEqualTo []) then {
                    _out append ([_rows, _aObj, _key, true, false] call fnc_place_settled);
                };
            };
        };

        _out append ([_aObj, _hx, _hy, _topZ, _set] call _surfacePack);
        [_aObj, (_hx max _hy) + SEAT_GAP + 0.2] call _reserve;
        _out
    };

    // Place a single back-to-wall piece (sofa/bed/cabinet) at a near cell, front off the wall.
    private _placeWall = {
        params ["_cell", "_class"];
        (_catalog get _class) params ["", "_fy"];
        _cell params ["_cpos", "", "_nearB"];
        private _heading = if (_nearB >= 0) then { (_nearB + 180) - _fy } else { - _fy };
        private _frame = [_cpos, _heading] call _frameAt;
        private _o = ([[[_class, 0, 0, 0, 0]], _frame, _key, true, false] call fnc_place_settled) select 0;
        deleteVehicle _frame;
        private _bb = boundingBoxReal _o;
        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
        [_o, (_hx max _hy) + 0.2] call _reserve;
        _o
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

        // Wall pass: wall pieces onto near cells, perpendicular to the wall, spaced by reservation.
        private _wallClasses = ["wall", _set] call fnc_furnish_classesFor;
        if (_wallClasses isNotEqualTo []) then {
            private _nWall = floor ((count (_rcells select { (_x select 1) == "near" })) / WALL_DIV);
            for "_k" from 1 to _nWall do {
                private _free = _rcells select { (_x select 1) == "near" && {!(_x select 5)} };
                if (_free isEqualTo []) exitWith {};
                _objs pushBack ([selectRandom _free, selectRandom _wallClasses] call _placeWall);
            };
        };

        // Anchor pass: anchors into the roomiest free open cells first.
        private _anchorClasses = ["anchor", _set] call fnc_furnish_classesFor;
        if (_anchorClasses isNotEqualTo []) then {
            private _nAnch = 1 max floor ((count (_rcells select { (_x select 1) == "open" })) / FILL_DIV);
            for "_k" from 1 to _nAnch do {
                private _free = _rcells select { (_x select 1) == "open" && {!(_x select 5)} };
                if (_free isEqualTo []) exitWith {};
                private _cell = ([_free, [], { -(_x select 3) }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                _objs append ([_cell, selectRandom _anchorClasses, _set] call _placeAnchor);
            };
        };

        // Rug pass: flat covers on any free floor (open or near-wall), reserved so nothing packs onto them.
        private _rugClasses = ["rug", _set] call fnc_furnish_classesFor;
        if (_rugClasses isNotEqualTo []) then {
            private _nRug = floor ((count (_rcells select { (_x select 1) != "blocked" })) / RUG_DIV);
            for "_k" from 1 to _nRug do {
                private _free = _rcells select { (_x select 1) != "blocked" && {!(_x select 5)} };
                if (_free isEqualTo []) exitWith {};
                private _cell = selectRandom _free;
                private _frame = [_cell select 0, 0] call _frameAt;
                _objs pushBack (([[selectRandom _rugClasses, 0, 0, 0, 0], _frame, _key, true, false] call fnc_place_settled) select 0);
                deleteVehicle _frame;
                [_cell select 0, 0.5] call _reserve;
            };
        };
    } forEach _bySize;

    ["INFO", "FURNISH", format ["%1: placed %2 object(s) across %3 room(s)", typeOf _building, count _objs, count _bySize]] call fnc_log;
    _objs
};
