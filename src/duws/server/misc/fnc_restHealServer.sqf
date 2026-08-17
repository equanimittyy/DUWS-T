if (!isServer) exitWith {};

params ["_caller", "_restSite"];

// The confirmation belongs to fnc_rest_heal, after its fade to black has finished. Sent from
// here it reached the players' screens while they were still watching daylight, so the line
// announcing the rest arrived before the rest visibly began.
[_restSite] remoteExec ["fnc_rest_heal", 2];
