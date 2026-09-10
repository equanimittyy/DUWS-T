// Locality: caller's machine. Spawns the cosmetic transport helo the CP delivery supports fly in on
// (paradrop, supply crate, vehicle drop): offset _dist off a random bearing from _location so it flies
// the run in rather than appearing overhead, +400 up so it comes in high. Returns [_group, _vehicle].
// The caller owns the waypoints, on-station flag, and payload; this only builds the aircraft.

params ["_location", "_dist"];

private _spawnPos = ((vectorNormalized [random [-1,0,1], random [-1,0,1], 0]) vectorMultiply _dist) vectorAdd _location;
_spawnPos set [2, (_spawnPos select 2) + 400];

private _group = [_spawnPos, WEST, [blufor_TRANS_HELI_X], [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
private _pilot = units _group select 0;
private _vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
// Cosmetic transport: crew hold fire and don't acquire, so it flies the drop run instead of engaging.
_pilot disableAI "Target";
_pilot disableAI "AUTOTARGET";
_group setCombatMode "BLUE";
_vehicle engineOn true;

[_group, _vehicle]
