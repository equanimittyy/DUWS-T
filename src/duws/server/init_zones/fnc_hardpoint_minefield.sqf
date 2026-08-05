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

// [_center, _dir, _variant, _cols, _rows, _spacing, _jitter, _key] call fnc_hardpoint_minefield -> [mines]
//   _center  [x,y]           field centre in world coordinates
//   _dir     degrees         facing; +Y of the lattice points down it, clockwise like setDir
//   _variant "AT" | "AP"     anything but "AP" lays anti-tank, the safe default for a stray token
//   _key     site key        files each mine for streaming / teardown; "" leaves them unmanaged
fnc_hardpoint_minefield = {
    params ["_center", "_dir", ["_variant", "AT"], ["_cols", 6], ["_rows", 3], ["_spacing", 4], ["_jitter", 1.2], ["_key", ""]];

    private _classes = switch (toUpper _variant) do {
        case "AP": { ["APERSMine", "APERSBoundingMine"] };
        default { ["ATMine"] };
    };

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

    _mines
};
