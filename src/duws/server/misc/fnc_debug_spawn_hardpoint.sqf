// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Stands a hardpoint up on demand to exercise fnc_hardpoint_build before OPCOM or the zone siting
// loop drives it. A dev path, not a shipped one: no garrison, no streaming, no state -- just the
// composition, so the placement primitive can be seen in isolation. Everything is filed under one
// key, "hpdev", so the menu's clear row releases the lot.
params ["_type", "_side", "_pos", ["_dir", 0]];
if (!isServer) exitWith {};

private _placed = [_type, _pos, _dir, _side, "hpdev"] call fnc_hardpoint_build;
["INFO", "HARDPOINT", format ["dev spawn: %1 %2, %3 objects at %4",
    _side, _type, count _placed, mapGridPosition _pos]] call fnc_log;
_placed
