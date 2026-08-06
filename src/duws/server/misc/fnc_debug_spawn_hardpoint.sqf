// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Stands a hardpoint up on demand to exercise the placement and streaming primitives before OPCOM or
// the zone siting loop drives them. A dev path, not a shipped one. Each spawn takes its own key, so it
// registers as its own streamed site: walk 600 m off and it stows, come back and it raises. The men,
// which are not composition members, ride the site roster; the menu's clear row retires every dev key.
params ["_type", "_side", "_pos", ["_dir", 0]];
if (!isServer) exitWith {};

// Spawned, not called: fnc_hardpoint_spawn sleeps in the static drop-and-settle, which the
// unscheduled remoteExec target cannot do.
_this spawn {
    params ["_type", "_side", "_pos", ["_dir", 0]];
    private _n = missionNamespace getVariable ["DUWS_hpdevN", 0];
    missionNamespace setVariable ["DUWS_hpdevN", _n + 1];
    private _key = format ["hpdev_%1", _n];

    // Three soldiers for the dev spawn, empty for a minefield -- men would stand on its mines. Chosen
    // here, the way an authored garrison composition sets it, rather than special-cased in the
    // primitive. The AP-laddered composition is OPCOM's job later.
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _garrison = [[_soldier, _soldier, _soldier], []] select (_type isEqualTo "MINEFIELD");

    ([_type, _pos, _dir, _side, _key, _garrison] call fnc_hardpoint_spawn) params ["_objs", "_men"];
    [_key, _pos, 600, _men, 300, _side, _garrison] call fnc_hardpoint_register;
    DUWS_hpdevKeys = (missionNamespace getVariable ["DUWS_hpdevKeys", []]) + [_key];

    ["INFO", "HARDPOINT", format ["dev spawn: %1 %2 [%3], %4 objects %5 men at %6",
        _side, _type, _key, count _objs, count _men, mapGridPosition _pos]] call fnc_log;
};
