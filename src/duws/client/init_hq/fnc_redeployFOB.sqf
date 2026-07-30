// Locality: client -- an addAction function value, so it runs on whoever redeploys. The action is
// added on every machine and carries no references to the garrison it replaces: the server reads
// the current guards and turrets off the FOB, which keeps every player's copy valid after someone
// rebuilds. The check here is advisory, exactly as the HQ's redeploy action does it --
// fnc_redeployFOBUnits checks, charges and rebuilds.
params ["_fob"];

if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };

playSound "loadgun";

[_fob] remoteExec ["fnc_redeployFOBUnits", 2];
