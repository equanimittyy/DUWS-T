// Locality: client -- an addAction function value, so it runs on whoever reguards. The action
// is added on every machine, so it carries no group references: the server reads the current
// garrison off the FOB, which keeps every player's copy valid after someone rebuilds.
// Only the affordability check and the sound are local; the server owns the rest.
params ["_fob"];

private _cost = 15;

if !(["CP", _cost] call fnc_pool_spend) exitWith {
    hint format [localize "STR_DUWS_T_p6sb3ply", _cost];
};

playSound "loadgun";

// The cost travels so the server can refund it if another player's rebuild is already running.
[getPos _fob, _fob, _cost] remoteExec ["fnc_guardsFOB", 2];
