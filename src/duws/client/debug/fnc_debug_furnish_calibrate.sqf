// Locality: client -- an fnc_debug_furnish_menu row handler, runs on whoever opened the menu. Lists the
// catalog classes whose facing matters (a chair, sofa, bed, desk -- not flat clutter or a rug) and spawns
// the picked one at heading 0 so the dev can read its front bearing and record frontYaw in
// furniture_catalog.hpp. No SQF command reports a model's front, so this hand-calibration is the only way
// to get it. Re-checked against game_master because the function is broadcast. English-only debug.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

private _catalog = [
#include "..\..\shared\includes\furniture_catalog.hpp"
];
private _classes = (_catalog select { (_x select 1) in ["anchor", "seat", "wall"] }) apply { _x select 0 };

private _rows = [["-- clear spawned --", { ["", player] remoteExec ["fnc_furnish_calibrate_spawn", 2] }, [], [1, 0.4, 0.4, 1]]];
{
    _rows pushBack [_x, { _this remoteExec ["fnc_furnish_calibrate_spawn", 2] }, [_x, player], [1, 0.667, 0, 1]];
} forEach _classes;

["Calibrate furniture fronts", _rows] call fnc_open_action_menu;
