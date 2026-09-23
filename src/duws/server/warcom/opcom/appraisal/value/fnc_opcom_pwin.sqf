// Locality: server, [] call'd at load. P(win), the odds a unit sent into contact wins it, read off the force grid
// (opcom_plan.md §Appraisal). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_blockForce = {
    params ["_pos"];
    private _fri = 0;
    private _ene = 0;
    {
        _fri = _fri + (DUWS_opcom_grid_fri select _x);
        _ene = _ene + (DUWS_opcom_grid_ene select _x);
    } forEach ([[_pos] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells);
    [_fri, _ene]
};

// Whether a unit sent into contact wins it -- an attacking order's term, never a buy's: a garrison purchase stocks
// ground OPCOM already holds, and its site is gated on being uncontested anyway.
// Lanchester-square: parity is a coin flip, a 2:1 edge about 0.8. The +1 keeps unopposed ground off a divide by zero.
DUWS_fnc_opcom_pWinAt = {
    params ["_fri", "_ene"];
    private _r = _fri / (_ene + 1);
    (_r ^ 2) / ((_r ^ 2) + 1)
};

DUWS_fnc_opcom_pWin = {
    params ["_pos"];
    if (isNil "DUWS_opcom_grid_w") exitWith { 1 };
    ([_pos] call DUWS_fnc_opcom_blockForce) call DUWS_fnc_opcom_pWinAt
};

// A force as the 3x3 block reads it once it stands at the block's centre: the grid deposits a force spread over
// OPCOM_GRID_SPREAD, so the block sums about four times the raw figure, and a raw add would undercount the unit sent.
DUWS_fnc_opcom_blockGain = {
    private _g = 0;
    for "_dy" from -1 to 1 do {
        for "_dx" from -1 to 1 do {
            _g = _g + ((1 - OPCOM_GRID_CELL * sqrt (_dx * _dx + _dy * _dy) / OPCOM_GRID_SPREAD) max 0);
        };
    };
    _g
};

// The odds with a force the grid does not already count at _pos: a unit sent in, or one OPCOM has yet to hire.
DUWS_fnc_opcom_pWinWith = {
    params ["_pos", "_force"];
    ([_pos] call DUWS_fnc_opcom_blockForce) params ["_fri", "_ene"];
    [_fri + _force * (call DUWS_fnc_opcom_blockGain), _ene] call DUWS_fnc_opcom_pWinAt
};

// The odds with the unit sent added, unless it already stands inside the block and the grid counts it there.
DUWS_fnc_opcom_pWinSend = {
    params ["_pos", "_from", "_force"];
    private _add = [0, _force] select (([_pos, _from] call DUWS_fnc_opcom_cellDist) > 1);
    [_pos, _add] call DUWS_fnc_opcom_pWinWith
};
