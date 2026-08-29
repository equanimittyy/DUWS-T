// Locality: server -- createVehicle runs where the objects are built, always the server. Definition only;
// registered in server_fnc_init.sqf ahead of every caller (it needs fnc_duws_keep). Server-only, not broadcast.
//
// The settled-object counterpart to fnc_composition_place. That primitive freezes its props (unkillable,
// motionless cover); this one leaves each object fully simulated but held at rest, for a composition whose
// pieces have to stay live -- loot the player picks up, a body a particle source stands on, anything that a
// freeze or an attachTo would strip of its pickup or its physics. Same idea as ZEN's object placement: seat
// the object exactly on the surface, align it to the surface, then zero its velocity so PhysX carries no
// residual motion. Dropped from height a simulated item bounces and scatters; seated with no velocity it rests
// where it is put and stays interactable.
//
// Offsets ride the anchor's frame, so the caller authors a layout once (a row of documents across a table top)
// and it rotates and travels with the anchor. The anchor should already be settled/frozen: the seats are read
// off it once, so a seat that moves afterwards leaves its object behind.
//
// Contract: [_rows, _anchor, _key, _invuln] -> [_objs]
//   _rows    [class, offX, offY, offZ, dir] rows in the anchor's model frame. offZ is where the object's
//            resting base sits above the anchor origin, not where its model origin goes (the caller places a
//            table-top row at the table's boundingBoxReal top); the object's own base offset is backed out so
//            a prop whose origin rides above its lowest point does not sink. dir adds to the anchor heading.
//            offZ and dir default to 0.
//   _anchor  OBJECT the offsets are measured from -- its position, heading and up.
//   _key     composition key the objects are filed under for teardown (fnc_duws_keep).
//   _invuln  allowDamage false on each placed object (default true). They stay simulated either way; this only
//            stops stray fire, it is not the freeze that fnc_composition_place applies.
fnc_place_settled = {
    params ["_rows", "_anchor", "_key", ["_invuln", true]];
    private _up = vectorUp _anchor;
    private _baseDir = getDir _anchor;

    private _objs = [];
    {
        _x params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0]];
        // ASL, not ATL: the seat is measured against the anchor's own surface, and setPosASL commits it there
        // without the roof/terrain ambiguity ATL carries over a body.
        private _pos = AGLToASL (_anchor modelToWorld [_ox, _oy, _oz]);
        private _obj = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
        if (_invuln) then { _obj allowDamage false };

        // Orient first (setVectorDirAndUp does not move the object, so no position to re-assert after it),
        // then place, then kill velocity. The velocity zero is the load-bearing step: a freshly created
        // ground-holder spawns with physics live and would drift or topple off the seat without it.
        private _dirDeg = _baseDir + _dir;
        _obj setVectorDirAndUp [[sin _dirDeg, cos _dirDeg, 0], _up];
        // Seat the object's base, not its origin: _pos is the surface point, but setPosASL positions the
        // model origin, so a prop whose lowest point sits below its origin (a laptop, a crate) would sink by
        // that gap. Back the gap out along the anchor's up axis (boundingBoxReal is orientation-independent).
        private _baseZ = (boundingBoxReal _obj select 0) select 2;
        _obj setPosASL (_pos vectorAdd (_up vectorMultiply (- _baseZ)));
        _obj setVelocity [0, 0, 0];

        [_obj, _key] call fnc_duws_keep;
        _objs pushBack _obj;
    } forEach _rows;
    _objs
};
