// Locality: server -- createVehicle runs where the objects are built, always the server. Definition only;
// registered in server_fnc_init.sqf ahead of every caller (it needs fnc_duws_keep). Server-only, not broadcast.
//
// Seats objects flush on an anchor's surface and holds them at rest: align to the surface, seat on it, zero
// residual motion, so a piece that would otherwise bounce or drift rests where it is put. Two object kinds,
// chosen by _asLoot:
//   prop (default) -- a CfgVehicles object (a laptop, a crate), created directly and seated on its base.
//   loot (_asLoot) -- a pickup-able inventory item, seated in a GroundWeaponHolder rather than a raw
//     WeaponHolderSimulated so PhysX cannot fling it off the surface. See the gotchas note on Item_* holders.
//
// Offsets ride the anchor's frame, so the caller authors a layout once (a row of documents across a table
// top) and it rotates and travels with the anchor. The anchor should already be settled/frozen: the seats
// are read off it once, so a seat that moves afterwards leaves its object behind.
//
// Contract: [_rows, _anchor, _key, _invuln, _asLoot, _freeze, _settle, _dropOnFail] -> [_objs]
//   _rows    [class, offX, offY, offZ, dir] in the anchor's model frame. offZ is where the object's resting
//            base sits above the anchor origin (the caller places a table-top row at the table's
//            boundingBoxReal top); dir adds to the anchor heading. offZ and dir default to 0. When _asLoot,
//            class is the bare inventory class (CfgWeapons item or CfgMagazines), not an Item_* body.
//   _anchor  OBJECT the offsets are measured from -- its position, heading and up.
//   _key     composition key the objects are filed under for teardown (fnc_duws_keep).
//   _invuln  allowDamage false on each placed object (default true). Stops stray fire; independent of _asLoot.
//   _asLoot  each class is a pickup-able inventory item, seated in a GroundWeaponHolder (default false).
//   _freeze  props only: leave the piece frozen (enableSimulationGlobal false) once seated, so no physics
//            tick unseats a flush body (default false). Seated live then frozen; loot has no PhysX to freeze.
//            A caller that repositions the returned frozen piece must use setPosWorld, not setPosASL.
//   _settle  props only: drop the piece just above its point and let physics seat it on the real floor (a
//            wrong seat Z self-corrects), confirm it lands upright and in place, jitter-retry up to 3, and if it
//            still will not settle seat it square at the point (unless _dropOnFail), then freeze (default false).
//            Overrides _freeze. Pieces settle two at a time, each pair the farthest-apart still pending, so two
//            live bodies never shove each other and both damp on one shared wait -- the caller runs scheduled.
//   _dropOnFail settle only: a piece that still will not settle after the retries is deleted and its return slot
//            is objNull, rather than seated square -- a guaranteed piece is better absent than placed broken
//            (default false).
fnc_place_settled = {
    params ["_rows", "_anchor", "_key", ["_invuln", true], ["_asLoot", false], ["_freeze", false], ["_settle", false], ["_dropOnFail", false]];
    private _up = vectorUp _anchor;
    private _baseDir = getDir _anchor;

    private _objs = [];

    if (_asLoot) then {
        {
            _x params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0]];
            // ASL, not ATL: the seat is measured against the anchor's own surface, and setPosASL commits it
            // there without the roof/terrain ambiguity ATL carries over a body.
            private _pos = AGLToASL (_anchor modelToWorld [_ox, _oy, _oz]);
            private _dirDeg = _baseDir + _dir;
            private _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
            // Cargo slot is class-dependent; an empty holder self-deletes within a second, so fill it now.
            if (isClass (configFile >> "CfgMagazines" >> _class)) then {
                _holder addMagazineCargoGlobal [_class, 1];
            } else {
                _holder addItemCargoGlobal [_class, 1];
            };
            if (_invuln) then { _holder allowDamage false };
            _holder setVectorDirAndUp [[sin _dirDeg, cos _dirDeg, 0], _up];
            // Holder origin sits at its base, so seat a hair above the surface. No PhysX, so it holds unfrozen
            // -- and unfrozen is what keeps its inventory openable.
            _holder setPosASL (_pos vectorAdd (_up vectorMultiply 0.02));
            _holder setVelocity [0, 0, 0];
            [_holder, _key] call fnc_duws_keep;
            _objs pushBack _holder;
        } forEach _rows;
    } else {
        if (!_settle) then {
            // Seat live then freeze: a frozen body ignores setPosASL (freeze-first strands the piece), and a
            // live flush CAN_COLLIDE body is ejected by the next physics tick. isNil runs unscheduled, so
            // create-seat-freeze completes before any tick can land.
            {
                _x params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0]];
                private _pos = AGLToASL (_anchor modelToWorld [_ox, _oy, _oz]);
                private _dirDeg = _baseDir + _dir;
                private _obj = objNull;
                isNil {
                    private _o = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
                    if (_invuln) then { _o allowDamage false };
                    _o setVectorDirAndUp [[sin _dirDeg, cos _dirDeg, 0], _up];
                    // Seat the base, not the origin: setPosASL places the model origin, so a prop whose lowest
                    // point is below its origin sinks by that gap unless backed out (boundingBoxReal is orientation-free).
                    private _baseZ = (boundingBoxReal _o select 0) select 2;
                    _o setPosASL (_pos vectorAdd (_up vectorMultiply (- _baseZ)));
                    _o setVelocity [0, 0, 0];
                    if (_freeze) then { _o enableSimulationGlobal false };
                    _obj = _o;
                };
                if (!isNull _obj) then { [_obj, _key] call fnc_duws_keep };
                _objs pushBack _obj;
            } forEach _rows;
        } else {
            // Physics-settle, not seat-and-freeze: gravity finds the real floor even when the seat Z is wrong,
            // and a bad landing (tipped or flung) retries rather than freezing in. Settled in farthest-apart
            // pairs so two live bodies never interfere and both damp on one wait.
            private _n = count _rows;
            private _jobs = _rows apply {
                _x params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0]];
                [_class, AGLToASL (_anchor modelToWorld [_ox, _oy, _oz]), _baseDir + _dir]
            };
            private _slot = []; for "_k" from 0 to (_n - 1) do { _slot pushBack objNull };
            private _pending = []; for "_k" from 0 to (_n - 1) do { _pending pushBack _k };

            private _dropOne = {
                params ["_idx", "_jx", "_jy"];
                (_jobs select _idx) params ["_class", "_pos", "_dir"];
                private _o = createVehicle [_class, ASLToAGL _pos, [], 0, "CAN_COLLIDE"];
                if (_invuln) then { _o allowDamage false };
                _o setVectorUp [0, 0, 1];
                _o setDir _dir;
                _o setPosASL (_pos vectorAdd [_jx, _jy, 0.15]);
                _o setVelocity [0, 0, 0];
                _o
            };
            // Base-on-floor Z gate: distance2D alone passes a piece that fell to a lower storey or perched at
            // the same XY. Band is loose -- a correctly-rested piece sits several cm off the median plane (PhysX
            // contact, per-class bbox-LOD) -- but far under a storey drop or a perch.
            private _restOK = {
                params ["_o", "_pos"];
                private _restBaseZ = (getPosASL _o select 2) + ((boundingBoxReal _o select 0) select 2);
                alive _o
                    && {vectorMagnitude (velocity _o) < 0.05}
                    && {(vectorUp _o select 2) > 0.985}
                    && {(_o distance2D (ASLToAGL _pos)) < 0.6}
                    && {abs (_restBaseZ - (_pos select 2)) < 0.15}
            };

            while { count _pending > 0 } do {
                // This wave: the two farthest-apart still-pending points (or the lone last one), so the pair
                // cannot touch while both settle.
                private _wave = [];
                if (count _pending == 1) then { _wave = [_pending select 0] } else {
                    private _bestD = -1; private _bi = 0; private _bj = 1;
                    for "_a" from 0 to (count _pending - 2) do {
                        for "_b" from (_a + 1) to (count _pending - 1) do {
                            private _d = ((_jobs select (_pending select _a)) select 1) distance ((_jobs select (_pending select _b)) select 1);
                            if (_d > _bestD) then { _bestD = _d; _bi = _a; _bj = _b };
                        };
                    };
                    _wave = [_pending select _bi, _pending select _bj];
                };
                _pending = _pending - _wave;

                // Drop the wave, one shared wait for both to come to rest (escape at 3 s so a never-settling
                // piece cannot stall), validate each, jitter-retry the unsettled -- up to 3 tries.
                private _todo = +_wave;
                private _tries = 0;
                while { count _todo > 0 && {_tries < 3} } do {
                    private _live = _todo apply {
                        private _jx = 0; private _jy = 0;
                        if (_tries > 0) then { _jx = (random 0.4) - 0.2; _jy = (random 0.4) - 0.2 };
                        [_x, [_x, _jx, _jy] call _dropOne]
                    };
                    private _t0 = time;
                    sleep 0.25;   // gravity not yet engaged: the just-zeroed bodies read at-rest on frame 1
                    waitUntil { (_live findIf { vectorMagnitude (velocity (_x select 1)) >= 0.05 }) < 0 || {time - _t0 >= 3} };
                    private _stillTodo = [];
                    {
                        _x params ["_idx", "_o"];
                        if ([_o, (_jobs select _idx) select 1] call _restOK) then {
                            // A settled piece only needs its rest tilt re-levelled, then freeze so no later tick unseats it.
                            _o setVectorUp [0, 0, 1];
                            _o setVelocity [0, 0, 0];
                            _o enableSimulationGlobal false;
                            _slot set [_idx, _o];
                        } else {
                            deleteVehicle _o;
                            _stillTodo pushBack _idx;
                        };
                    } forEach _live;
                    _todo = _stillTodo;
                    _tries = _tries + 1;
                };

                // Never settled (tipped, slid, dropped a storey): _dropOnFail leaves the slot null rather than
                // freeze a broken piece; otherwise seat it square at the point and freeze.
                {
                    private _idx = _x;
                    (_jobs select _idx) params ["_class", "_pos", "_dir"];
                    if (_dropOnFail) then {
                        _slot set [_idx, objNull];
                    } else {
                        private _o = createVehicle [_class, ASLToAGL _pos, [], 0, "CAN_COLLIDE"];
                        if (_invuln) then { _o allowDamage false };
                        _o setVectorDirAndUp [[sin _dir, cos _dir, 0], [0, 0, 1]];
                        _o setPosASL (_pos vectorAdd [0, 0, - ((boundingBoxReal _o select 0) select 2)]);
                        _o setVelocity [0, 0, 0];
                        _o enableSimulationGlobal false;
                        _slot set [_idx, _o];
                    };
                } forEach _todo;
            };

            {
                if (!isNull _x) then { [_x, _key] call fnc_duws_keep };
                _objs pushBack _x;
            } forEach _slot;
        };
    };

    _objs
};
