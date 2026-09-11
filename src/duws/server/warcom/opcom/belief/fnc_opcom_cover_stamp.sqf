// Locality: server. Coverage faucet for the staleness layer: stamp the current tick into every cell within
// _k Chebyshev cells of _point, catch or not. Absence of a fresh stamp is what lets the readers tell
// swept-clear ground from never- or long-unseen -- the distinction the force belief store cannot carry.
// Every writer routes through here, so the box clamp and cell math live in one place.
if (isNil "DUWS_opcom_grid_w") exitWith {};
params ["_point", "_k"];

private _w = DUWS_opcom_grid_w;
// w2c already clamps to the box, so the box bounds below only trim the k-halo, never the centre.
(missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
private _c  = [_point] call DUWS_fnc_opcom_w2c;
private _cx = _c mod _w;
private _cy = floor (_c / _w);
private _t  = DUWS_opcom_tick;

for "_iy" from ((_cy - _k) max _minCy) to ((_cy + _k) min _maxCy) do {
    for "_ix" from ((_cx - _k) max _minCx) to ((_cx + _k) min _maxCx) do {
        DUWS_opcom_grid_seen set [_iy * _w + _ix, _t];
    };
};
