// Locality: server -- createVehicle runs where the objects are built, always the server. Definition only;
// registered in server_fnc_init.sqf ahead of every caller (it needs fnc_duws_keep). Server-only, not broadcast.
//
// Seats a set of objects flush on an anchor's surface and holds them at rest. Same idea as ZEN's object
// placement: align each to the surface, seat it exactly on it, then hold it so PhysX carries no residual
// motion -- dropped from height a simulated item bounces and scatters; seated and held it rests where it is
// put. Two hold modes, chosen by _freeze, because different props stay put by different means:
//   simulated (default) -- velocity zeroed, object left live. For a piece that has to stay interactive or
//     keep its physics: loot the player picks up, a body a particle source stands on, anything a freeze or an
//     attachTo would strip.
//   frozen (_freeze)    -- enableSimulationGlobal false. For a piece PhysX will not hold seated: a
//     WeaponHolderSimulated item (the Item_* intel classes) is ejected off a surface it is placed on and
//     hangs in the air, so it stays put only once frozen. Global, not local, so a client renders it seated
//     too rather than falling.
//
// Offsets ride the anchor's frame, so the caller authors a layout once (a row of documents across a table
// top) and it rotates and travels with the anchor. The anchor should already be settled/frozen: the seats
// are read off it once, so a seat that moves afterwards leaves its object behind.
//
// Contract: [_rows, _anchor, _key, _invuln, _freeze] -> [_objs]
//   _rows    [class, offX, offY, offZ, dir] rows in the anchor's model frame. offZ is where the object's
//            resting base sits above the anchor origin, not where its model origin goes (the caller places a
//            table-top row at the table's boundingBoxReal top); the object's own base offset is backed out so
//            a prop whose origin rides above its lowest point does not sink. dir adds to the anchor heading.
//            offZ and dir default to 0.
//   _anchor  OBJECT the offsets are measured from -- its position, heading and up.
//   _key     composition key the objects are filed under for teardown (fnc_duws_keep).
//   _invuln  allowDamage false on each placed object (default true). Stops stray fire; independent of _freeze.
//   _freeze  freeze each object rather than leave it simulated (default false). See the hold modes above.
fnc_place_settled = {
    params ["_rows", "_anchor", "_key", ["_invuln", true], ["_freeze", false]];
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
        // then place, then hold.
        private _dirDeg = _baseDir + _dir;
        _obj setVectorDirAndUp [[sin _dirDeg, cos _dirDeg, 0], _up];
        // Seat the object's base, not its origin: _pos is the surface point, but setPosASL positions the
        // model origin, so a prop whose lowest point sits below its origin (a laptop, a crate) would sink by
        // that gap. Back the gap out along the anchor's up axis (boundingBoxReal is orientation-independent).
        private _baseZ = (boundingBoxReal _obj select 0) select 2;
        _obj setPosASL (_pos vectorAdd (_up vectorMultiply (- _baseZ)));
        // Hold at rest: a freshly created ground-holder spawns with physics live and would drift or topple
        // off the seat otherwise. No sleep precedes this, so no simulation step ejects the object first.
        if (_freeze) then { _obj enableSimulationGlobal false } else { _obj setVelocity [0, 0, 0] };

        [_obj, _key] call fnc_duws_keep;
        _objs pushBack _obj;
    } forEach _rows;
    _objs
};
