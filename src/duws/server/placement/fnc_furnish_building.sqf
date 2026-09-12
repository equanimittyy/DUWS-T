// Locality: server -- createVehicle and the grid raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled, fnc_furnish_grid, fnc_furnish_catalog and
// fnc_furnish_room, which it calls. Not broadcast: callers remoteExec it to the server.
//
// Class-agnostic on the building (survives modded/unrecognised maps), catalog-driven on the furniture
// (which is ours). fnc_furnish_grid infers the interior as a per-storey cell grid split into rooms; this
// reserves the nav corridor, then furnishes every room at once -- one fnc_furnish_room thread each, so their
// per-piece settle waits overlap in wall-clock instead of summing. Rooms are independent (blocked doorway
// cells wall them apart), so each thread reserves only its own cells; no trooper is sealed behind a sofa and
// no door is blocked. Pieces settle frozen and the whole house thaws once every room is done. An empty grid
// (a ruin, a view-only prop) degrades to the seed nav points, flat, logged.
//
// Contract: [_building, _key, _quota] -> [_objs placed]
//   _building  OBJECT to furnish
//   _key       teardown key filed through fnc_place_settled / fnc_duws_keep
//   _quota     retained for the caller contract; placement density is grid-derived, so <= 0 = default
fnc_furnish_building = {
    if (!isServer) exitWith { [] };
    params ["_building", ["_key", "furnish"], ["_quota", 0]];
    if (isNull _building) exitWith { [] };

    private _catalog = call fnc_furnish_catalog;
    private _grid = [_building] call fnc_furnish_grid;

    // No interior geometry: synthesise open cells at the seed nav points so the room pass still runs
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
    // Deep copy: fnc_furnish_grid caches the cells on the building, and the room threads stamp the `occupied`
    // flag on each -- mutating the cache would leave a re-furnish seeing last run's reservations.
    _grid = +_grid;

    // Grid axis. Floor pieces face this to sit square to the room; a world-north heading skews them diagonally
    // across the grid on a rotated building.
    private _bdir = getDir _building;

    // Mark every grid cell within _r of a point occupied (the corridor pass below). One-shot server pass.
    private _reserve = {
        params ["_p", "_r"];
        { if ((_p distance2D (_x select 0)) <= _r) then { _x set [5, true] } } forEach _grid;
    };

    private _rooms = createHashMap;
    {
        private _rid = _x select 4;
        if (_rid >= 0) then { private _l = _rooms getOrDefault [_rid, []]; _l pushBack _x; _rooms set [_rid, _l] };
    } forEach _grid;

    // Path preservation: reserve a thin corridor along the segments linking consecutive nav points, so a
    // walk path stays clear -- the garrison-conflict fix, leaving the nav lattice open rather than sealing
    // a trooper behind furniture. Skipped on the degraded seed grid, where the seeds ARE the only cells.
    // Long jumps (a segment crossing the shell) are dropped so the corridor stays local, not diagonal.
    // Runs before the room threads spawn, so every thread sees the reserved cells.
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

    // Furnish every room concurrently: one thread each, joined below. The rooms' settle waits overlap instead
    // of running end to end, and disjoint cells mean the threads never contend. Frozen pieces land in _placed.
    private _placed = [];
    private _handles = [];
    {
        _handles pushBack ([_rooms get _x, _catalog, _bdir, _key, _placed] spawn fnc_furnish_room);
    } forEach (keys _rooms);
    { waitUntil { scriptDone _x } } forEach _handles;

    // Whole-house thaw: each piece rests where it settled, so going live adds no impulse; live, they fall into
    // rubble when the building is destroyed.
    { _x enableSimulationGlobal true } forEach _placed;

    { [_x] remoteExec ["fnc_furnish_push_addAction", 0, _x] } forEach _placed;

    ["INFO", "FURNISH", format ["%1: placed %2 object(s) across %3 room(s)", typeOf _building, count _placed, count _rooms]] call fnc_log;
    _placed
};
