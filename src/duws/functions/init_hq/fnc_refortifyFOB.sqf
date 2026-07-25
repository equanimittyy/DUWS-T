// Locality: client -- an addAction function value, so it runs on whoever refortifies. The
// action is added on every machine, so it carries no turret references: the server reads the
// current ring off the FOB, which keeps every player's copy valid after someone rebuilds.
// Only the affordability check and the sound are local; the server owns the rest.
params ["_fob"];

private _cost = 5;

if (commandpointsblu1 <= _cost) exitWith {
    hint format [localize "STR_DUWS_T_p6sb3ply", _cost];
};

[-_cost] remoteExec ["fnc_cp_adjust", 2];
playSound "loadgun";

// The cost travels so the server can refund it if another player's rebuild is already running.
[getPos _fob, _fob, true, _cost] remoteExec ["fnc_fortifyFOB", 2];
