// Locality: server -- createMine and revealMine must run where the mines are made.
//
// One square per call; a larger field is several squares laid by the caller.
//
// Vanilla mine classes only: the same footing as the Land_* props the compositions use, so nothing
// here forces a mod. east revealMine marks each mine as OPFOR-laid, which keeps OPFOR AI off its own
// field and leaves BLUFOR to detect and clear it.

#define MINE_SQUARE 50
#define MINE_CELL   10

// The classes each variant draws from. A table beside its only reader,
// the way DUWS_staticRoles sits by its resolver, so the AT/AP sets are edited as data not code.
DUWS_mineVariants = [
    ["AT", ["ATMine"]],
    ["AP", ["APERSMine", "APERSBoundingMine"]]
];

// [_center, _dir, _variant, _key] call fnc_hardpoint_minefield -> [mines]
//   _dir     degrees         clockwise like setDir
//   _variant "AT" | "AP"     resolved through DUWS_mineVariants; an unknown token falls to AT
//   _key     site key        files each mine under the key for teardown and the clearance count;
//                            "" leaves them unmanaged
fnc_hardpoint_minefield = {
    params ["_center", "_dir", ["_variant", "AT"], ["_key", ""]];

    private _hit = DUWS_mineVariants findIf { (_x select 0) isEqualTo (toUpper _variant) };
    private _classes = if (_hit >= 0) then { (DUWS_mineVariants select _hit) select 1 } else { ["ATMine"] };

    private _cx = _center select 0;
    private _cy = _center select 1;
    private _half = MINE_SQUARE / 2;
    private _mines = [];
    for "_i" from 0 to (MINE_SQUARE / MINE_CELL - 1) do {
        for "_j" from 0 to (MINE_SQUARE / MINE_CELL - 1) do {
            private _off = [_i * MINE_CELL + random MINE_CELL - _half, _j * MINE_CELL + random MINE_CELL - _half, _dir]
                call fnc_hardpoint_rotate;
            private _mine = createMine [selectRandom _classes, [_cx + (_off select 0), _cy + (_off select 1), 0], [], 0];
            east revealMine _mine;
            if (_key != "") then { [_mine, _key] call fnc_duws_keep };
            _mines pushBack _mine;
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
    // marker is not a hazard, and a field of only signs is a cleared field.
    if (_key != "") then { missionNamespace setVariable [format ["DUWS_hpMines_%1", _key], _mines] };

    _mines
};
