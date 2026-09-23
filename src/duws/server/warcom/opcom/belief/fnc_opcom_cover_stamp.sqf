// Locality: server. Coverage faucet for the staleness layer: stamp the current tick into every cell within
// _k Chebyshev cells of _point, catch or not. Absence of a fresh stamp is what lets the readers tell
// swept-clear ground from never- or long-unseen -- the distinction the force belief store cannot carry.
if (isNil "DUWS_opcom_grid_w") exitWith {};
params ["_point", "_k"];

private _t = DUWS_opcom_tick;
{ DUWS_opcom_grid_seen set [_x, _t] } forEach ([[_point] call DUWS_fnc_opcom_w2c, _k] call DUWS_fnc_opcom_blockCells);
