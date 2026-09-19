// Locality: server -- createMine and revealMine must run where the mines are made.
//
// One square per call; a larger field is several squares laid by the caller, stepped by DUWS_mineSquare.
//
// Vanilla mine classes only: the same footing as the Land_* props the compositions use, so nothing
// here forces a mod. east revealMine marks each mine as OPFOR-laid, which keeps OPFOR AI off its own
// field and leaves BLUFOR to detect and clear it.

#define MINE_CELL 10
// A mine may land this far from its cell's centre, 5 m past the cell edge, so neighbouring cells overlap
// and the field clumps and gaps like a hand-laid one instead of tiling evenly.
#define MINE_SPREAD 10

DUWS_mineSquare = 50;

// [variant, classes, mines per cell]. A table beside its only reader,
// the way DUWS_staticRoles sits by its resolver, so the AT/AP sets are edited as data not code.
// A fractional count is rolled per cell, so AP's 1.1 averages 27.5 mines a square.
DUWS_mineVariants = [
    ["AT", ["ATMine"], 1],
    ["AP", ["APERSMine", "APERSBoundingMine"], 1.1]
];

// [_center, _dir, _variant, _key] call fnc_hardpoint_minefield -> [mines]
//   _dir     degrees         clockwise like setDir
//   _variant "AT" | "AP"     resolved through DUWS_mineVariants; an unknown token falls to AT
//   _key     site key        files each mine under the key for teardown and the clearance count;
//                            "" leaves them unmanaged
fnc_hardpoint_minefield = {
    params ["_center", "_dir", ["_variant", "AT"], ["_key", ""]];

    private _hit = DUWS_mineVariants findIf { (_x select 0) isEqualTo (toUpper _variant) };
    (if (_hit >= 0) then { DUWS_mineVariants select _hit } else { ["AT", ["ATMine"], 1] }) params ["", "_classes", "_perCell"];

    private _cx = _center select 0;
    private _cy = _center select 1;
    private _half = DUWS_mineSquare / 2;
    private _mines = [];
    for "_i" from 0 to (DUWS_mineSquare / MINE_CELL - 1) do {
        for "_j" from 0 to (DUWS_mineSquare / MINE_CELL - 1) do {
            for "_k" from 1 to (floor (_perCell + random 1)) do {
                private _off = [
                    (_i + 0.5) * MINE_CELL + ((random 2) - 1) * MINE_SPREAD - _half,
                    (_j + 0.5) * MINE_CELL + ((random 2) - 1) * MINE_SPREAD - _half,
                    _dir] call fnc_hardpoint_rotate;
                private _mine = createMine [selectRandom _classes, [_cx + (_off select 0), _cy + (_off select 1), 0], [], 0];
                east revealMine _mine;
                if (_key != "") then { [_mine, _key] call fnc_duws_keep };
                _mines pushBack _mine;
            };
        };
    };

    // Inner 80% only: a sign on the edge would trace the field for the player.
    for "_i" from 1 to (1 + floor random 2) do {
        private _off = [((random 2) - 1) * _half * 0.8, ((random 2) - 1) * _half * 0.8, _dir] call fnc_hardpoint_rotate;
        private _sign = createVehicle ["Land_Sign_Mines_F", [_cx + (_off select 0), _cy + (_off select 1), 0], [], 0, "CAN_COLLIDE"];
        _sign setDir (random 360);
        if (_key != "") then { [_sign, _key] call fnc_duws_keep };
    };

    // Filed by key so the clearance check can read what is left: the field is spent when no armed mine
    // remains, and its own hazard list is the only count of that. Signs are not in it -- a warning
    // marker is not a hazard, and a field of only signs is a cleared field. Appended, so every square
    // laid under one key clears as one field.
    if (_key != "") then {
        private _var = format ["DUWS_hpMines_%1", _key];
        missionNamespace setVariable [_var, (missionNamespace getVariable [_var, []]) + _mines];
    };

    _mines
};

// [_center, _dir, _cols, _rows] call fnc_hardpoint_minefield_grid -> [[x,y], ...] square centres of a
// block _cols wide and _rows deep about _center, rows stacked along _dir.
fnc_hardpoint_minefield_grid = {
    params ["_center", "_dir", "_cols", "_rows"];
    private _out = [];
    for "_c" from 0 to (_cols - 1) do {
        for "_r" from 0 to (_rows - 1) do {
            private _off = [(_c - (_cols - 1) / 2) * DUWS_mineSquare, (_r - (_rows - 1) / 2) * DUWS_mineSquare, _dir]
                call fnc_hardpoint_rotate;
            _out pushBack [(_center select 0) + (_off select 0), (_center select 1) + (_off select 1)];
        };
    };
    _out
};
