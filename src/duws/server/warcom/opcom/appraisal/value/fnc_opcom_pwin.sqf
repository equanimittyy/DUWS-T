// Locality: server, [] call'd at load. P(win), the odds a unit sent into contact wins it, read off the force grid
// (opcom_plan.md §Appraisal). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_blockForce = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    private _c = [_pos] call DUWS_fnc_opcom_w2c;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _fri = 0;
    private _ene = 0;
    for "_iy" from ((_cy - 1) max _minCy) to ((_cy + 1) min _maxCy) do {
        for "_ix" from ((_cx - 1) max _minCx) to ((_cx + 1) min _maxCx) do {
            private _i = _iy * _w + _ix;
            _fri = _fri + (DUWS_opcom_grid_fri select _i);
            _ene = _ene + (DUWS_opcom_grid_ene select _i);
        };
    };
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
