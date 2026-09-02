// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Stands a hardpoint up on demand to exercise the placement and streaming primitives before OPCOM or
// the zone siting loop drives them. A dev path, not a shipped one. Each spawn takes its own key, so it
// registers as its own streamed site under the type's own radius: walk past it and it stows, come back
// and it raises -- except mortar and artillery, which the type table keeps resident. The men, which
// are not composition members, ride the site roster; the menu's clear row retires every dev key.
params ["_type", "_side", "_pos", ["_dir", 0], ["_variant", "AT"]];
if (!isServer) exitWith {};

// Spawned, not called: a dev spawn lands on the player, so it reads up and fnc_hardpoint_register crews it
// inline -- which sleeps in the static drop-and-settle, and the unscheduled remoteExec target cannot.
_this spawn {
    params ["_type", "_side", "_pos", ["_dir", 0], ["_variant", "AT"]];
    private _n = missionNamespace getVariable ["DUWS_hpdevN", 0];
    missionNamespace setVariable ["DUWS_hpdevN", _n + 1];
    private _key = format ["hpdev_%1", _n];

    // Garrison is the type's, fielded by the spawn from DUWS_hardpointGarrison -- a dev spawn stands up
    // the same defenders a shipped one of that type would, and a minefield still gets none.
    private _objs = [_type, _pos, _dir, _side, _key, _variant] call fnc_hardpoint_build;
    [_key, _type, _pos, _side, "", _dir] call fnc_hardpoint_register;
    DUWS_hpdevKeys = (missionNamespace getVariable ["DUWS_hpdevKeys", []]) + [_key];

    ["INFO", "HARDPOINT", format ["dev spawn: %1 %2 [%3], %4 objects at %5",
        _side, _type, _key, count _objs, mapGridPosition _pos]] call fnc_log;
};
