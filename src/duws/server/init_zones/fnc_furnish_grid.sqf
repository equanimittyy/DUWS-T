// Locality: server -- the GEOM/floor raycasts run where the building is. Definition only; registered in
// server_fnc_init.sqf before fnc_furnish_building, which consumes it. Server-only, not broadcast.
//
// Reconstructs a building's interior as a per-storey grid of floor cells, class-agnostic (no command
// reports rooms or walls, so it is inferred by geometry -- the one shape that survives a modded map).
// The grid is laid in the building's own frame so it tracks a rotated building's walls, split into
// storeys by nav-point height density (robust to a stairway bridging two floors), and each ~0.5 m cell
// is carved to the real room by two probes -- a floor down-ray and a heading-aligned 8-ray GEOM wall
// ring. Surviving cells flood-fill into rooms; a room too small to use is dropped. Cached, built once.
//
// Cell: [posASL, state, nearBearing, clearance, roomId, occupied, i, j, storey]
//   state       "open" (nothing in reach) | "near" (wall to back onto) | "blocked" (too tight to hold, a
//               wall, or a doorway blocked off so furniture cannot bridge the gap)
//   nearBearing bearing of the nearest wall, or -1 if none within reach
//   clearance   nearest-wall distance in metres (a full miss reads as the ray length)
//   roomId      flood-fill room label; a blocked or dropped-room cell stays -1
//   occupied    reservation flag, false here; the placer sets it
//   i, j        storey grid coords, for room adjacency
//
// Contract: [_building] -> [cells]  ([] when no interior geometry -- caller falls back and logs)
fnc_furnish_grid = {
    if (!isServer) exitWith { [] };
    params ["_building"];
    if (isNull _building) exitWith { [] };

    private _cached = _building getVariable ["DUWS_furnishGrid", []];
    if (_cached isNotEqualTo []) exitWith { _cached };

    #define GRID_CELL 0.5
    #define WALL_REACH 1.5
    #define GRID_CHEST 1.1
    #define WALL_NEAR 0.85
    #define BLOCKED_CLEAR 0.35
    #define STOREY_GAP 2.5
    #define STOREY_BIN 0.5     // Z histogram bin for the floor-level split
    #define MIN_ROOM_CELLS 20  // a room below this is a stairwell/sliver: dropped, not furnished
    #define MIN_ROOM_SQUARE 4  // and it must hold one clear NxN cell block, or a piece has nowhere to sit
    #define CELL_CAP 1200      // per storey; the pitch coarsens rather than exceed it

    private _seeds = _building buildingPos -1;
    if (_seeds isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["%1 has no interior positions; empty grid", typeOf _building]] call fnc_log;
        []
    };

    // Work in the building's own frame: buildingPos are world points, so a world-axis grid sits skewed
    // across a rotated building and straddles its walls. worldToModel drops every seed into local X/Y/Z,
    // the grid is laid on those axes, and modelToWorld projects each cell back -- so the rows run along
    // the walls, and the wall ring is turned by the same heading to shoot along them.
    private _bdir = getDir _building;
    private _ringBearings = [0, 45, 90, 135, 180, 225, 270, 315];
    private _ring = _ringBearings apply { _x + _bdir };
    private _lseeds = _seeds apply { _building worldToModel _x };

    // Floor levels by Z density, not gaps: a stairway bridges two floors, so a gap-since-last-point split
    // fuses them. Anchor each dense run at its lowest bin -- the floor down-ray starts just above the level,
    // so a higher anchor lifts that start onto a sill.
    private _zs = _lseeds apply { _x select 2 };
    private _z0 = selectMin _zs;
    private _binN = 1 + floor ((selectMax _zs - _z0) / STOREY_BIN);
    private _hist = []; for "_b" from 1 to _binN do { _hist pushBack 0 };
    {
        private _bi = floor ((_x - _z0) / STOREY_BIN);
        _hist set [_bi, (_hist select _bi) + 1];
    } forEach _zs;
    private _thr = 3 max ceil ((count _zs) / _binN * 0.75);

    private _dense = [];
    { if (_x >= _thr) then { _dense pushBack (_z0 + (_forEachIndex + 0.5) * STOREY_BIN) } } forEach _hist;

    private _levels = [];
    if (_dense isNotEqualTo []) then {
        private _floorZ = _dense select 0;
        private _lastZ = _floorZ;
        for "_k" from 1 to (count _dense - 1) do {
            private _z = _dense select _k;
            if (_z - _lastZ >= STOREY_GAP) then {
                _levels pushBack _floorZ;
                _floorZ = _z;
            };
            _lastZ = _z;
        };
        _levels pushBack _floorZ;
    };
    if (_levels isEqualTo []) then { _levels = [(_z0 + selectMax _zs) / 2] };

    private _buckets = _levels apply { [] };
    {
        private _z = _x select 2;
        private _best = 0; private _bd = 1e9;
        { private _dd = abs (_z - _x); if (_dd < _bd) then { _bd = _dd; _best = _forEachIndex } } forEach _levels;
        (_buckets select _best) pushBack _x;
    } forEach _lseeds;
    private _storeys = [];
    { if (_x isNotEqualTo []) then { _storeys pushBack [_levels select _forEachIndex, _x] } } forEach _buckets;

    private _cells = [];
    private _rays = 0;

    {
        private _sIdx = _forEachIndex;
        _x params ["_floorZ", "_sSeeds"];
        // Interior extent from the local seed box, not the building footprint (which includes roof overhang).
        private _minX = 1e12; private _maxX = -1e12; private _minY = 1e12; private _maxY = -1e12;
        {
            _minX = _minX min (_x select 0); _maxX = _maxX max (_x select 0);
            _minY = _minY min (_x select 1); _maxY = _maxY max (_x select 1);
        } forEach _sSeeds;

        // Pad the box half a cell so wall-hugging floor is not clipped, then size the grid; coarsen the
        // pitch if the cell count would blow the cap on a large building.
        private _spanX = (_maxX - _minX) + GRID_CELL;
        private _spanY = (_maxY - _minY) + GRID_CELL;
        private _pitch = GRID_CELL;
        private _nx = ceil (_spanX / _pitch);
        private _ny = ceil (_spanY / _pitch);
        if (_nx * _ny > CELL_CAP) then {
            _pitch = _pitch * sqrt ((_nx * _ny) / CELL_CAP);
            _nx = ceil (_spanX / _pitch);
            _ny = ceil (_spanY / _pitch);
        };
        private _ox = ((_minX + _maxX) / 2) - (_nx * _pitch) / 2;
        private _oy = ((_minY + _maxY) / 2) - (_ny * _pitch) / 2;

        for "_i" from 0 to (_nx - 1) do {
            for "_j" from 0 to (_ny - 1) do {
                private _lx = _ox + (_i + 0.5) * _pitch;
                private _ly = _oy + (_j + 0.5) * _pitch;
                private _guessASL = AGLToASL (_building modelToWorld [_lx, _ly, _floorZ]);

                // Floor down-ray (GEOM, building un-ignored): a hit near the plane is real floor and samples
                // its Z (flattened to one plane per storey below). A miss is a hole or outside the room -- drop it.
                private _fb = _guessASL vectorAdd [0, 0, 0.5];
                private _fe = _guessASL vectorAdd [0, 0, -0.8];
                _rays = _rays + 1;
                private _fr = lineIntersectsSurfaces [_fb, _fe, objNull, objNull, true, 1, "GEOM"];
                if (_fr isNotEqualTo []) then {
                    private _floorASL = (_fr select 0) select 0;

                    // Wall ring at chest height, not the floor, so a low sill is not read as a wall.
                    private _cb = _floorASL vectorAdd [0, 0, GRID_CHEST];
                    private _clear = WALL_REACH; private _nearBearing = -1;
                    private _dist = [];
                    {
                        private _ce = _cb vectorAdd [WALL_REACH * sin _x, WALL_REACH * cos _x, 0];
                        _rays = _rays + 1;
                        private _r = lineIntersectsSurfaces [_cb, _ce, objNull, objNull, true, 1, "GEOM"];
                        private _d = WALL_REACH;
                        if (_r isNotEqualTo []) then {
                            _d = _cb distance ((_r select 0) select 0);
                            if (_d < _clear) then { _clear = _d; _nearBearing = _x };
                        };
                        _dist pushBack _d;
                    } forEach _ring;

                    // Doorway: a wall in reach on two opposite ring bearings with the cross axis open is a jamb
                    // pair, not a backing wall -- tag it so furniture skips the gap while flood-fill still joins
                    // the rooms through it (non-blocked). Opposite of ring index k is k+4, perpendicular axis k+2.
                    private _door = false;
                    {
                        private _o = (_x + 2) mod 4;
                        if ((_dist select _x) <= WALL_NEAR && {(_dist select (_x + 4)) <= WALL_NEAR}
                            && {(_dist select _o) > WALL_NEAR} && {(_dist select (_o + 4)) > WALL_NEAR})
                            exitWith { _door = true };
                    } forEach [0, 1, 2, 3];

                    private _state = if (_clear < BLOCKED_CLEAR) then { "blocked" }
                        else { if (_door) then { "door" }
                        else { if (_clear <= WALL_NEAR) then { "near" } else { "open" } } };

                    _cells pushBack [_floorASL, _state, _nearBearing, _clear, -1, false, _i, _j, _sIdx];
                };
            };
        };
    } forEach _storeys;

    // One floor Z per storey: a floor is level, so collapse the per-cell down-ray Z (wobbles a cm or two,
    // catches the odd sill) to the storey median -- a single plane is what the settle Z-gate checks against.
    private _zByStorey = createHashMap;
    { private _s = _x select 8; _zByStorey set [_s, (_zByStorey getOrDefault [_s, []]) + [(_x select 0) select 2]] } forEach _cells;
    private _floorZof = createHashMap;
    {
        private _zs2 = _zByStorey get _x;
        _zs2 sort true;
        _floorZof set [_x, _zs2 select (floor (count _zs2 / 2))];
    } forEach (keys _zByStorey);
    { private _p = _x select 0; _x set [0, [_p select 0, _p select 1, _floorZof get (_x select 8)]] } forEach _cells;

    // Doorways blocked, not skipped: a bare "door" cell still let a piece in an adjacent open cell overhang
    // the opening. Blocking splits the rooms at the gap; reserving the neighbours keeps a piece off the mouth.
    private _ij = createHashMap;
    { _x params ["", "", "", "", "", "", "_i", "_j", "_s"]; _ij set [format ["%1_%2_%3", _s, _i, _j], _forEachIndex] } forEach _cells;
    private _doors = [];
    { if ((_x select 1) == "door") then { _doors pushBack _forEachIndex } } forEach _cells;
    {
        private _d = _cells select _x;
        _d set [1, "blocked"];
        _d set [5, true];
        _d params ["", "", "", "", "", "", "_i", "_j", "_s"];
        {
            _x params ["_dx", "_dy"];
            private _ni = _ij getOrDefault [format ["%1_%2_%3", _s, _i + _dx, _j + _dy], -1];
            if (_ni >= 0) then { (_cells select _ni) set [5, true] };
        } forEach [[1,0],[-1,0],[0,1],[0,-1]];
    } forEach _doors;

    // Flood-fill non-blocked cells into rooms. Blocked cells -- walls, and the doorways blocked above -- hold
    // runs the fill cannot cross, so each enclosed area becomes its own room. 4-neighbour adjacency within a
    // storey, keyed by storey/i/j.
    private _idx = createHashMap;
    {
        _x params ["", "_st", "", "", "", "", "_i", "_j", "_sIdx"];
        if (_st != "blocked") then { _idx set [format ["%1_%2_%3", _sIdx, _i, _j], _forEachIndex] };
    } forEach _cells;

    private _room = 0;
    {
        if ((_x select 1) != "blocked" && {(_x select 4) < 0}) then {
            private _queue = [_forEachIndex];
            while { count _queue > 0 } do {
                private _ci = _queue deleteAt 0;
                private _c = _cells select _ci;
                if ((_c select 4) < 0) then {
                    _c set [4, _room];
                    _c params ["", "", "", "", "", "", "_ci_i", "_ci_j", "_ci_s"];
                    {
                        _x params ["_dx", "_dy"];
                        private _k = format ["%1_%2_%3", _ci_s, _ci_i + _dx, _ci_j + _dy];
                        private _ni = _idx getOrDefault [_k, -1];
                        if (_ni >= 0 && {((_cells select _ni) select 4) < 0}) then { _queue pushBack _ni };
                    } forEach [[1, 0], [-1, 0], [0, 1], [0, -1]];
                };
            };
            _room = _room + 1;
        };
    } forEach _cells;

    // Drop a room that cannot take a piece: fewer than MIN_ROOM_CELLS cells (a stairwell, a balcony sliver, a
    // closet), or no clear MIN_ROOM_SQUARE-cell square anywhere in it (a corridor or an L has the area but no
    // square patch a table sits in). A dropped room's cells stay walkable but lose their room id.
    private _roomSize = createHashMap;
    private _cellRoom = createHashMap;   // "storey_i_j" -> roomId, over room cells only, for the square test
    {
        private _r = _x select 4;
        if (_r >= 0) then {
            _roomSize set [_r, (_roomSize getOrDefault [_r, 0]) + 1];
            _x params ["", "", "", "", "", "", "_i", "_j", "_s"];
            _cellRoom set [format ["%1_%2_%3", _s, _i, _j], _r];
        };
    } forEach _cells;

    // A room holds a square if some cell is the low corner of a full MIN_ROOM_SQUARE block in the same room.
    private _hasSquare = createHashMap;
    {
        private _r = _x select 4;
        if (_r >= 0 && {!(_hasSquare getOrDefault [_r, false])}) then {
            _x params ["", "", "", "", "", "", "_i", "_j", "_s"];
            private _ok = true;
            for "_di" from 0 to (MIN_ROOM_SQUARE - 1) do {
                for "_dj" from 0 to (MIN_ROOM_SQUARE - 1) do {
                    if ((_cellRoom getOrDefault [format ["%1_%2_%3", _s, _i + _di, _j + _dj], -1]) != _r) exitWith { _ok = false };
                };
                if (!_ok) exitWith {};
            };
            if (_ok) then { _hasSquare set [_r, true] };
        };
    } forEach _cells;

    {
        private _r = _x select 4;
        if (_r >= 0 && {(_roomSize getOrDefault [_r, 0]) < MIN_ROOM_CELLS || {!(_hasSquare getOrDefault [_r, false])}}) then {
            _x set [4, -1];
        };
    } forEach _cells;
    private _keptN = 0;
    { if ((_roomSize get _x) >= MIN_ROOM_CELLS && {_hasSquare getOrDefault [_x, false]}) then { _keptN = _keptN + 1 } } forEach (keys _roomSize);

    ["INFO", "FURNISH", format ["%1: grid %2 cell(s), %3 room(s) (%4 dropped), %5 storey(s), %6 ray(s)",
        typeOf _building, count _cells, _keptN, _room - _keptN, count _storeys, _rays]] call fnc_log;
    _building setVariable ["DUWS_furnishGrid", _cells];
    _cells
};
