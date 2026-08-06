// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Stands a hardpoint up on demand to exercise fnc_hardpoint_spawn before OPCOM or the zone siting
// loop drives it. A dev path, not a shipped one: no streaming or state yet -- the composition, its
// defenders and its crewed guns, so the placement can be seen and fought in isolation. Everything is
// filed under one key, "hpdev"; its men, which are not composition members, are tracked in
// DUWS_hpdevMen so the menu's clear row can delete them.
params ["_type", "_side", "_pos", ["_dir", 0]];
if (!isServer) exitWith {};

// Spawned, not called: fnc_hardpoint_spawn sleeps in the static drop-and-settle, which the
// unscheduled remoteExec target cannot do.
_this spawn {
    params ["_type", "_side", "_pos", ["_dir", 0]];
    // Three soldiers for the dev spawn, empty for a minefield -- men would stand on its mines. Chosen
    // here, the way an authored garrison composition sets it, rather than special-cased in the
    // primitive. The AP-laddered composition is OPCOM's job later.
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _garrison = [[_soldier, _soldier, _soldier], []] select (_type isEqualTo "MINEFIELD");
    ([_type, _pos, _dir, _side, "hpdev", _garrison] call fnc_hardpoint_spawn) params ["_objs", "_men"];
    DUWS_hpdevMen = (missionNamespace getVariable ["DUWS_hpdevMen", []]) + _men;
    ["INFO", "HARDPOINT", format ["dev spawn: %1 %2, %3 objects %4 men at %5",
        _side, _type, count _objs, count _men, mapGridPosition _pos]] call fnc_log;
};
