// Locality: client -- a row body in the FOB's request menu, so it runs on whoever redeploys. It
// carries no reference to the garrison it replaces: the server reads the current guards and
// turrets off the FOB, which keeps the row valid after someone else rebuilds. The check here is
// advisory, exactly as the HQ's redeploy row does it -- fnc_redeployFOBUnits checks, charges
// and rebuilds.
params ["_fob"];

if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };

playSound "loadgun";

[_fob] remoteExec ["fnc_redeployFOBUnits", 2];
