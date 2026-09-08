// Locality: server -- the GEOM/floor raycasts run where the building is. Definition only; registered in
// server_fnc_init.sqf before fnc_furnish_building, which consumes it. Server-only, not broadcast.
//
// Reconstructs a building's interior as a per-storey grid of floor cells, class-agnostic (no command
// reports rooms or walls, so it is inferred by geometry -- the one shape that survives a modded map).
// buildingPos nav points seed the interior extent and split the storeys; a ~0.5 m cell grid over that
// extent is carved to the real (concave) room by two probes per cell -- a floor down-ray and an 8-ray
// GEOM wall ring -- then the surviving cells flood-fill into rooms. Cached on the building, built once.
//
// Cell: [posASL, state, nearBearing, clearance, roomId, occupied, i, j, storey]
//   state       "open" (nothing in reach) | "near" (wall to back onto) | "door" (a wall gap, kept clear) |
//               "blocked" (too tight to hold)
//   nearBearing bearing of the nearest wall, or -1 if none within reach
//   clearance   nearest-wall distance in metres (a full miss reads as the ray length)
//   roomId      flood-fill room label; blocked cells stay -1
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
    #define CELL_CAP 1200      // per storey; the pitch coarsens rather than exceed it

    private _seeds = _building buildingPos -1;
    if (_seeds isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["%1 has no interior positions; empty grid", typeOf _building]] call fnc_log;
        []
    };

    // Split storeys on a height jump: buildingPos -1 spans every floor, and a ray must never treat the
    // floor above as this storey's wall. Sorted by Z, a gap over STOREY_GAP is a storey boundary.
    private _sorted = [_seeds, [], { _x select 2 }, "ASCEND"] call BIS_fnc_sortBy;
    private _storeys = [];
    private _cur = [];
    private _prevZ = -1e9;
    {
        if ((_x select 2) - _prevZ > STOREY_GAP && {_cur isNotEqualTo []}) then {
            _storeys pushBack _cur; _cur = [];
        };
        _cur pushBack _x;
        _prevZ = _x select 2;
    } forEach _sorted;
    if (_cur isNotEqualTo []) then { _storeys pushBack _cur };

    private _cells = [];
    private _rays = 0;
    private _ringBearings = [0, 45, 90, 135, 180, 225, 270, 315];

    {
        private _sIdx = _forEachIndex;
        private _sSeeds = _x;
        // Interior extent from the seed bounding box, not the building footprint (which includes roof
        // overhang). Floor plane is the storey's mean seed height; each cell then snaps to its own floor hit.
        private _minX = 1e12; private _maxX = -1e12; private _minY = 1e12; private _maxY = -1e12; private _sumZ = 0;
        {
            _minX = _minX min (_x select 0); _maxX = _maxX max (_x select 0);
            _minY = _minY min (_x select 1); _maxY = _maxY max (_x select 1);
            _sumZ = _sumZ + (_x select 2);
        } forEach _sSeeds;
        private _floorZ = _sumZ / count _sSeeds;

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
                private _cx = _ox + (_i + 0.5) * _pitch;
                private _cy = _oy + (_j + 0.5) * _pitch;
                private _guessASL = AGLToASL [_cx, _cy, _floorZ];

                // Floor down-ray (GEOM, building un-ignored): a hit near the plane is real floor, and its
                // Z snaps the cell exactly onto the floor. A miss is a hole or outside the room -- drop it.
                private _fb = _guessASL vectorAdd [0, 0, 0.4];
                private _fe = _guessASL vectorAdd [0, 0, -0.6];
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
                    } forEach _ringBearings;

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

    // Flood-fill non-blocked cells into rooms. A wall between two areas holds a run of blocked cells the
    // fill cannot cross, so it splits them; a doorway (a gap in the wall) leaves them one room, which reads
    // fine. 4-neighbour adjacency within a storey, keyed by storey/i/j.
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

    ["INFO", "FURNISH", format ["%1: grid %2 cell(s), %3 room(s), %4 ray(s)", typeOf _building, count _cells, _room, _rays]] call fnc_log;
    _building setVariable ["DUWS_furnishGrid", _cells];
    _cells
};
