// Locality: server -- createVehicle and the GEOM raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled, which it calls. Not broadcast: callers
// remoteExec it to the server.
//
// No per-class template and no authored offsets, so the mission survives modded and unrecognised buildings.
// The interior is inferred (buildingPos nav points + GEOM-LOD wall probes) and the furniture packed from
// boundingBoxReal at runtime -- spacing, facing, tabletop height, wall backing, clip avoidance all computed.
// So a chair faces its table by construction (heading = bearing to the table centre), not a hand-set angle.
//
// The engine cannot report a class's role (a stool and a small crate measure alike), so the library groups
// classes by role rather than guessing:
//   anchor   a surface things sit at and on (table, desk); the centre of a cluster.
//   seat     placed at the anchor's edges, facing in.
//   surface  sits on an anchor's top (props or inventory items both).
//   floor    stands on the floor, backed against a wall (bed, crate, cabinet).
//
// A building with no GEOM walls (a ruin, a view-only prop) still furnishes, logged, so the degrade shows.
//
// Contract: [_building, _key, _sets, _quota] -> [_objs placed]
//   _building  OBJECT to furnish
//   _key       teardown key filed through fnc_place_settled / fnc_duws_keep
//   _sets      eligible cluster-set names (e.g. ["living"]); [] = all
//   _quota     max clusters; <= 0 scales from the interior slot count
fnc_furnish_building = {
    if (!isServer) exitWith { [] };
    params ["_building", ["_key", "furnish"], ["_sets", []], ["_quota", 0]];
    if (isNull _building) exitWith { [] };

    // [setName, [[role, [classes]], ...]]. Placeholder classes -- swap in real ones per role.
    private _lib = [
        ["living", [
            ["anchor",  ["Land_CampingTable_F"]],
            ["seat",    ["Land_CampingChair_V1_F", "Land_CampingChair_V2_F"]],
            ["surface", ["ItemMap", "ItemWatch"]],
            ["floor",   ["Land_WoodenBox_TarpAll_F"]]
        ]],
        ["sleeping", [
            ["floor",   ["Land_Sleeping_bag_blue_F", "Land_Suitcase_F", "Land_WoodenBox_TarpAll_F"]]
        ]],
        ["work", [
            ["anchor",  ["Land_CampingTable_F"]],
            ["seat",    ["Land_CampingChair_V1_F"]],
            ["surface", ["ItemGPS", "FirstAidKit"]],
            ["floor",   ["Land_PlasticCase_01_medium_F", "Land_WoodenBox_TarpAll_F"]]
        ]]
    ];

    private _eligible = if (_sets isEqualTo []) then { _lib } else { _lib select { (_x select 0) in _sets } };
    if (_eligible isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["no cluster set matched %1", _sets]] call fnc_log; []
    };

    private _slots = _building buildingPos -1;
    if (_slots isEqualTo []) exitWith {
        ["WARN", "FURNISH", format ["%1 has no interior positions", typeOf _building]] call fnc_log; []
    };

    if (_quota <= 0) then { _quota = (1 max round ((count _slots) / 6)) min 4 };

    // Inner-first by centroid distance, then probe only the innermost handful: bounds the raycast cost on a
    // building with dozens of positions, and open-floor slots are what furniture wants anyway.
    private _sx = 0; private _sy = 0;
    { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _slots;
    private _cen = [_sx / count _slots, _sy / count _slots, 0];
    private _ranked = _slots apply { [_cen distance2D _x, _x] };
    _ranked sort true;
    private _cand = (_ranked apply { _x select 1 }) select [0, 12 min count _slots];

    #define REACH 2.5
    #define CHEST 1.1
    private _bdir = getDir _building;

    // 8 rays at chest height, not the floor, so a low sill is not read as a wall; GEOM LOD, so a thin view
    // shell a body would walk through does not count; building un-ignored, so its own walls register.
    // clearance = nearest hit over the ring (a miss counts the full reach); wall bearing = its direction.
    private _probed = _cand apply {
        private _slot = _x;
        private _begin = (AGLToASL _slot) vectorAdd [0, 0, CHEST];
        private _clear = REACH; private _wallDir = -1; private _hit = false;
        {
            private _end = _begin vectorAdd [REACH * sin _x, REACH * cos _x, 0];
            private _r = lineIntersectsSurfaces [_begin, _end, objNull, objNull, true, 1, "GEOM"];
            if (_r isNotEqualTo []) then {
                _hit = true;
                private _d = _begin distance ((_r select 0) select 0);
                if (_d < _clear) then { _clear = _d; _wallDir = _x };
            };
        } forEach [0, 45, 90, 135, 180, 225, 270, 315];
        [_clear, _slot, _wallDir, _hit]
    };

    if ((_probed findIf { _x select 3 }) < 0) then {
        ["WARN", "FURNISH", format ["%1 yielded no GEOM walls; furnishing flat", typeOf _building]] call fnc_log;
    };

    _probed sort false;   // most open first

    #define SEAT_GAP 0.45      // table edge to seat centre
    #define MIN_CLEAR 0.6      // a slot tighter than this holds nothing
    #define MIN_SPACING 2.0    // between cluster centres, so adjacent nav points do not stack
    #define WALL_NEAR 1.6      // a wall this close makes a slot a floor-piece spot, not a table spot

    // Which classes a set lists for a role, or [].
    private _roleClasses = {
        params ["_set", "_role"];
        private _r = (_set select 1) select { (_x select 0) == _role };
        if (_r isEqualTo []) then { [] } else { (_r select 0) select 1 }
    };

    private _objs = [];
    private _placed = [];   // cluster centres, for the spacing gate
    {
        if (count _placed < _quota) then {
            _x params ["_clear", "_slot", "_wallDir", "_hit"];
            if (_clear >= MIN_CLEAR && {(_placed findIf { (_slot distance _x) < MIN_SPACING }) < 0}) then {
                private _set = selectRandom _eligible;
                private _anchors = [_set, "anchor"] call _roleClasses;
                private _floors  = [_set, "floor"]  call _roleClasses;

                // Tables in open floor; floor pieces where a wall is close to back onto. A set with no anchor
                // is floor-only, one with no floor is anchor-only.
                private _useFloor = (_anchors isEqualTo []) ||
                    {_floors isNotEqualTo [] && {_wallDir >= 0 && {_clear < WALL_NEAR}}};

                // Face away from the nearest wall, snapped to the building's own axis so the cluster reads
                // parallel to the room. No wall in reach -> the axis, quarter-turned by order for variety.
                private _face = if (_wallDir >= 0) then {
                    _bdir + 90 * round (((_wallDir + 180) - _bdir) / 90)
                } else {
                    _bdir + (if ((count _placed) mod 2 == 0) then { 0 } else { 90 })
                };

                // Invisible frame at the slot for fnc_place_settled to ride; up is vertical, since a storey
                // is flat within itself.
                private _frame = createVehicle ["Land_HelipadEmpty_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
                _frame setPosASL (AGLToASL _slot);
                _frame setVectorDirAndUp [[sin _face, cos _face, 0], [0, 0, 1]];

                private _did = false;
                if (_useFloor && {_floors isNotEqualTo []}) then {
                    _objs append ([[[selectRandom _floors, 0, 0, 0, 0]], _frame, _key, true, false] call fnc_place_settled);
                    _did = true;
                } else {
                    if (_anchors isNotEqualTo []) then {
                        // Anchor first, then measure it: seat and tabletop offsets come from its real bounds,
                        // so the pack fits any table without a per-class number.
                        private _aObj = ([[[selectRandom _anchors, 0, 0, 0, 0]], _frame, _key, true, false] call fnc_place_settled) select 0;
                        _objs pushBack _aObj;
                        _did = true;

                        private _bb = boundingBoxReal _aObj;
                        private _hx = (abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0));
                        private _hy = (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1));
                        private _topZ = (_bb select 1) select 2;

                        // Seats at the edge mid-points, only where the seat still fits the measured clearance.
                        // Heading is the bearing from the seat back to the anchor centre, so it faces the table.
                        private _seatCls = [_set, "seat"] call _roleClasses;
                        if (_seatCls isNotEqualTo []) then {
                            private _edges = [];
                            if (_hy + SEAT_GAP <= _clear) then { _edges append [[0, _hy + SEAT_GAP], [0, -(_hy + SEAT_GAP)]] };
                            if (_hx + SEAT_GAP <= _clear) then { _edges append [[_hx + SEAT_GAP, 0], [-(_hx + SEAT_GAP), 0]] };
                            private _seatRows = _edges apply {
                                _x params ["_ox", "_oy"];
                                [selectRandom _seatCls, _ox, _oy, 0, (- _ox) atan2 (- _oy)]
                            };
                            if (_seatRows isNotEqualTo []) then {
                                _objs append ([_seatRows, _frame, _key, true, false] call fnc_place_settled);
                            };
                        };

                        // Surface items across the tabletop, anchored on the anchor object so the resting
                        // height is its real top. A prop and an inventory item take different seating in
                        // fnc_place_settled (raw createVehicle vs a GroundWeaponHolder), so split by config.
                        private _surf = [_set, "surface"] call _roleClasses;
                        if (_surf isNotEqualTo []) then {
                            private _n = count _surf;
                            private _rows = [];
                            { _rows pushBack [_x, (_forEachIndex - (_n - 1) / 2) * 0.3, 0, _topZ, 0] } forEach _surf;
                            private _propRows = _rows select { isClass (configFile >> "CfgVehicles" >> (_x select 0)) };
                            private _lootRows = _rows select { !(isClass (configFile >> "CfgVehicles" >> (_x select 0))) };
                            if (_propRows isNotEqualTo []) then { _objs append ([_propRows, _aObj, _key, true, false] call fnc_place_settled) };
                            if (_lootRows isNotEqualTo []) then { _objs append ([_lootRows, _aObj, _key, true, true] call fnc_place_settled) };
                        };
                    };
                };

                deleteVehicle _frame;
                if (_did) then { _placed pushBack _slot };
            };
        };
    } forEach _probed;

    ["INFO", "FURNISH", format ["%1: placed %2 cluster(s)", typeOf _building, count _placed]] call fnc_log;
    _objs
};
