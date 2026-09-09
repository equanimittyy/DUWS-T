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
// Contract: [_rows, _anchor, _key, _invuln, _asLoot, _freeze] -> [_objs]
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
fnc_place_settled = {
    params ["_rows", "_anchor", "_key", ["_invuln", true], ["_asLoot", false], ["_freeze", false]];
    private _up = vectorUp _anchor;
    private _baseDir = getDir _anchor;

    private _objs = [];
    {
        _x params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0]];
        // ASL, not ATL: the seat is measured against the anchor's own surface, and setPosASL commits it there
        // without the roof/terrain ambiguity ATL carries over a body.
        private _pos = AGLToASL (_anchor modelToWorld [_ox, _oy, _oz]);
        private _dirDeg = _baseDir + _dir;

        private _obj = objNull;
        if (_asLoot) then {
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
            _obj = _holder;
        } else {
            // Create, seat, then freeze in one unscheduled pass. A CAN_COLLIDE body seated flush on the floor
            // is thrown up by the first physics tick, so it must be frozen before any tick -- but freezing
            // before the seat drops the setPos onto a dead body. isNil runs the block unscheduled, so no tick
            // interleaves: the seat lands on a live body, then the freeze holds it at rest.
            isNil {
                private _o = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
                if (_invuln) then { _o allowDamage false };
                _o setVectorDirAndUp [[sin _dirDeg, cos _dirDeg, 0], _up];
                // Seat the base, not the origin: _pos is the surface point but setPosASL positions the model
                // origin, so a prop whose lowest point sits below its origin sinks by that gap. Back it out
                // along the up axis (boundingBoxReal is orientation-free).
                private _baseZ = (boundingBoxReal _o select 0) select 2;
                _o setPosASL (_pos vectorAdd (_up vectorMultiply (- _baseZ)));
                _o setVelocity [0, 0, 0];
                if (_freeze) then { _o enableSimulationGlobal false };
                _obj = _o;
            };
        };

        [_obj, _key] call fnc_duws_keep;
        _objs pushBack _obj;
    } forEach _rows;
    _objs
};
