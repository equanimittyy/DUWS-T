// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Clears every dev-spawned hardpoint. The men are deleted outright -- they are not composition
// members, so the key cannot reach them -- and the composition is released to the map sweep.
if (!isServer) exitWith {};

{ deleteVehicle _x } forEach (missionNamespace getVariable ["DUWS_hpdevMen", []]);
DUWS_hpdevMen = [];
["hpdev"] call fnc_duws_release;
["INFO", "HARDPOINT", "dev clear: released the hpdev composition and deleted its men"] call fnc_log;
