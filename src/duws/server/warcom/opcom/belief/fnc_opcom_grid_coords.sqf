// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. They load before the grid exists and read it at call time, so a caller guards on isNil "DUWS_opcom_grid_w".
if (!isServer) exitWith {};

DUWS_fnc_opcom_w2c = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    // Clamp to the play box: a point outside it resolves to the nearest edge cell, keeping routed/streamed cells inside.
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _cx = (floor ((_pos select 0) / OPCOM_GRID_CELL)) max _minCx min _maxCx;
    private _cy = (floor ((_pos select 1) / OPCOM_GRID_CELL)) max _minCy min _maxCy;
    _cy * _w + _cx
};

DUWS_fnc_opcom_c2w = {
    params ["_ci"];
    private _w = DUWS_opcom_grid_w;
    [((_ci mod _w) + 0.5) * OPCOM_GRID_CELL, ((floor (_ci / _w)) + 0.5) * OPCOM_GRID_CELL, 0]
};

DUWS_fnc_opcom_nearestWater = {
    params ["_pos"];
    private _best = _pos;
    private _bd = 1e12;
    {
        if (_x >= 0) then {
            private _c = [_forEachIndex] call DUWS_fnc_opcom_c2w;
            private _dd = _pos distance2D _c;
            if (_dd < _bd) then { _bd = _dd; _best = _c };
        };
    } forEach DUWS_opcom_grid_water;
    _best
};
