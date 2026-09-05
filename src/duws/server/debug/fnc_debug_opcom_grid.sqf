// Locality: server -- remoteExec'd to 2 by fnc_debug_opcom_view alongside the AoI gather. Reads the
// server-local influence grid and belief store (no client sees them) and hands the drawable back to the
// requesting client, the way fnc_debug_aoi_circles answers for the AoI reaches. Only cells carrying
// force are emitted, so the marker count tracks the active front, not the whole 3844-cell grid.
if (!isServer) exitWith {};
params ["_requester"];
if (isNil "DUWS_opcom_grid_w") exitWith {};   // loop has not built the grid yet

private _w = DUWS_opcom_grid_w;
private _cell = OPCOM_GRID_CELL;
private _fri = DUWS_opcom_grid_fri;
private _ene = DUWS_opcom_grid_ene;
private _eps = 0.05;

// [centre, fri, ene, isFront]. Front = the balance's sign differs from an orthogonal neighbour's: the
// zero-crossing band between friendly and enemy ground.
private _cells = [];
for "_i" from 0 to (_w * _w - 1) do {
    private _f = _fri select _i;
    private _e = _ene select _i;
    if (_f > _eps || _e > _eps) then {
        private _ix = _i mod _w;
        private _iy = floor (_i / _w);
        private _bal = _f - _e;
        private _front = false;
        if (abs _bal > _eps) then {
            {
                _x params ["_dx", "_dy"];
                private _nx = _ix + _dx;
                private _ny = _iy + _dy;
                if (_nx >= 0 && {_nx < _w} && {_ny >= 0} && {_ny < _w}) then {
                    private _nbal = (_fri select (_ny * _w + _nx)) - (_ene select (_ny * _w + _nx));
                    if (_nbal * _bal < 0) then { _front = true };
                };
            } forEach [[1, 0], [-1, 0], [0, 1], [0, -1]];
        };
        _cells pushBack [[(_ix + 0.5) * _cell, (_iy + 0.5) * _cell], _f, _e, _front];
    };
};

// Belief stamps: position, age in ticks, and the stamped threat (headcount with humans weighted).
private _bel = [];
{
    _bel pushBack [_x, DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex), DUWS_opcom_belief_str select _forEachIndex];
} forEach DUWS_opcom_belief_pos;

[_cells, _bel] remoteExec ["fnc_debug_opcom_grid_draw", _requester];
