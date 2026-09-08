// Locality: server -- createVehicle and the GEOM raycasts run where the building is. Definition only;
// registered in server_fnc_init.sqf after fnc_place_settled, which it calls. Not broadcast: callers
// remoteExec it to the server.
//
// No per-class template, because the mission must survive modded and unrecognised buildings: the interior
// is inferred (buildingPos nav points, GEOM-LOD wall probes), never keyed to a classname. A building with
// no GEOM walls (a ruin, a view-only prop) furnishes flat and logs it, so the degrade shows in the RPT.
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

    // Cluster library: [setName, footprint(m), propRows, tableRowIdx, clutterItems].
    //   propRows      fnc_place_settled rows [class, offX, offY, offZ, dir] in the cluster frame; row 0 is
    //                 the anchor piece and +Y is the cluster front.
    //   tableRowIdx   which placed prop carries a tabletop for the clutter pass, or -1 for none.
    //   clutterItems  [item, offX, offY] scattered on that tabletop; the top Z is read off the table at run.
    private _lib = [
        ["living", 1.6,
            [["Land_CampingTable_F", 0, 0, 0, 0], ["Land_CampingChair_V1_F", 0.55, 0.2, 0, 180],
             ["Land_CampingChair_V2_F", -0.55, 0.2, 0, 180], ["Land_WoodenBox_TarpAll_F", 0.95, -0.9, 0, 20]],
            0, [["ItemMap", -0.2, 0.05], ["ItemWatch", 0.2, -0.05]]],
        ["sleeping", 1.4,
            [["Land_Sleeping_bag_blue_F", 0, 0, 0, 0], ["Land_Suitcase_F", 0.85, -0.45, 0, 90],
             ["Land_WoodenBox_TarpAll_F", -0.8, -0.35, 0, 0]],
            -1, []],
        ["work", 1.6,
            [["Land_CampingTable_F", 0, 0, 0, 0], ["Land_CampingChair_V1_F", 0, -0.55, 0, 0],
             ["Land_PlasticCase_01_medium_F", 0.85, 0.3, 0, 0], ["Land_WoodenBox_TarpAll_F", -0.9, -0.2, 0, 30]],
            0, [["ItemGPS", -0.15, 0.1], ["FirstAidKit", 0.15, -0.1]]]
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

    // Most open first, then greedy. The crowd gate below is 3D distance, so a slot on the floor above is
    // never counted as crowding one below it.
    _probed sort false;

    private _objs = [];
    private _placed = [];   // [pos, footprint]
    {
        if (count _placed < _quota) then {
            _x params ["_clear", "_slot", "_wallDir", "_hit"];
            private _fit = _eligible select { (_x select 1) <= _clear };
            if (_fit isNotEqualTo []) then {
                private _cl = selectRandom _fit;
                private _fp = _cl select 1;
                if ((_placed findIf { (_slot distance (_x select 0)) < (_fp + (_x select 1)) }) < 0) then {
                    // Face away from the nearest wall, snapped to the building's own axis so the cluster
                    // reads parallel to the room rather than skew to an arbitrary ray. No wall in reach ->
                    // face the axis, quarter-turned by placement order for variety.
                    private _face = if (_wallDir >= 0) then {
                        private _f = _wallDir + 180;
                        _bdir + 90 * round ((_f - _bdir) / 90)
                    } else {
                        _bdir + (if ((count _placed) mod 2 == 0) then { 0 } else { 90 })
                    };

                    // fnc_place_settled needs an object to ride, so stand an invisible one at the slot to
                    // carry the frame. Up is vertical: a house storey is flat within itself.
                    private _anchor = createVehicle ["Land_HelipadEmpty_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
                    _anchor setPosASL (AGLToASL _slot);
                    _anchor setVectorDirAndUp [[sin _face, cos _face, 0], [0, 0, 1]];

                    _objs append ([_cl select 2, _anchor, _key, true, false] call fnc_place_settled);

                    // Clutter anchored on the table object, so its height is the table's real boundingBoxReal
                    // top rather than a per-class guess.
                    private _ti = _cl select 3;
                    if (_ti >= 0 && {_ti < count _objs}) then {
                        private _tbl = _objs select ((count _objs) - (count (_cl select 2)) + _ti);
                        private _topZ = (boundingBoxReal _tbl select 1) select 2;
                        private _crows = (_cl select 4) apply { [_x select 0, _x select 1, _x select 2, _topZ, 0] };
                        if (_crows isNotEqualTo []) then {
                            _objs append ([_crows, _tbl, _key, true, true] call fnc_place_settled);
                        };
                    };

                    deleteVehicle _anchor;
                    _placed pushBack [_slot, _fp];
                };
            };
        };
    } forEach _probed;

    ["INFO", "FURNISH", format ["%1: placed %2 cluster(s)", typeOf _building, count _placed]] call fnc_log;
    _objs
};
