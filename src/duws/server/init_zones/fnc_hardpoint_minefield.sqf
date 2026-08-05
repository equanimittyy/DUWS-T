// Locality: server -- createMine and revealMine must run where the mines are made.
//
// A minefield is not a prop composition: it is a lattice of mine objects laid over open ground, so it
// has its own generator rather than a fenced row list. Two variants -- anti-tank for a vehicle route,
// anti-personnel for an infantry approach -- and the field's size is the commander's to set. Longer
// or deeper is more cols or rows; strung fields are several calls, each origin stepped along a
// bearing by roughly the field's own frontage.
//
// Vanilla mine classes only: the same footing as the Land_* props the compositions use, so nothing
// here forces a mod. east revealMine marks each mine as OPFOR-laid, which keeps OPFOR AI off its own
// field and leaves BLUFOR to detect and clear it.
//
// A handful of Land_Sign_Mines_F sit inside the field as dressing -- warning enough for a careful
// player to notice, too sparse and too interior to trace where its edges are.

// The classes each variant draws from, one picked per lattice cell. A table beside its only reader,
// the way DUWS_staticRoles sits by its resolver, so the AT/AP sets are edited as data not code.
DUWS_mineVariants = [
    ["AT", ["ATMine"]],
    ["AP", ["APERSMine", "APERSBoundingMine"]]
];

// [_center, _dir, _variant, _cols, _rows, _spacing, _jitter, _key] call fnc_hardpoint_minefield -> [mines]
//   _center  [x,y]           field centre in world coordinates
//   _dir     degrees         facing; +Y of the lattice points down it, clockwise like setDir
//   _variant "AT" | "AP"     resolved through DUWS_mineVariants; an unknown token falls to AT
//   _key     site key        files each mine for streaming / teardown; "" leaves them unmanaged
fnc_hardpoint_minefield = {
    params ["_center", "_dir", ["_variant", "AT"], ["_cols", 6], ["_rows", 3], ["_spacing", 4], ["_jitter", 1.2], ["_key", ""]];

    private _hit = DUWS_mineVariants findIf { (_x select 0) isEqualTo (toUpper _variant) };
    private _classes = if (_hit >= 0) then { (DUWS_mineVariants select _hit) select 1 } else { ["ATMine"] };

    private _cx = _center select 0;
    private _cy = _center select 1;
    private _mines = [];
    {
        _x params ["_lx", "_ly"];
        private _jx = _lx + _jitter * ((random 2) - 1);
        private _jy = _ly + _jitter * ((random 2) - 1);
        // Rotate the local offset onto the field's heading, then place on the surface.
        private _wx = _cx + _jx * cos _dir + _jy * sin _dir;
        private _wy = _cy - _jx * sin _dir + _jy * cos _dir;
        private _mine = createMine [selectRandom _classes, [_wx, _wy, 0], [], 0];
        east revealMine _mine;
        if (_key != "") then { [_mine, _key] call fnc_duws_keep };
        _mines pushBack _mine;
    } forEach ([_cols, _rows, _spacing] call fnc_hardpoint_minefield_lattice);

    // Count scales with the field but caps low, and the roll makes some fields go unmarked. Placed
    // within the inner 80% so no sign sits on the boundary it would otherwise betray. Signs are
    // dressing, filed for teardown but kept out of the returned hazard list.
    private _maxSigns = (round ((_cols * _rows) / 12)) min 4;
    private _halfW = (_cols - 1) * _spacing / 2;
    private _halfD = (_rows - 1) * _spacing / 2;
    for "_i" from 1 to (round (random _maxSigns)) do {
        private _sx = ((random 2) - 1) * _halfW * 0.8;
        private _sy = ((random 2) - 1) * _halfD * 0.8;
        private _wx = _cx + _sx * cos _dir + _sy * sin _dir;
        private _wy = _cy - _sx * sin _dir + _sy * cos _dir;
        private _sign = createVehicle ["Land_Sign_Mines_F", [_wx, _wy, 0], [], 0, "CAN_COLLIDE"];
        _sign setDir (random 360);
        if (_key != "") then { [_sign, _key] call fnc_duws_keep };
    };

    _mines
};
