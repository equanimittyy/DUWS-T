// Locality: client -- an fnc_debug_furnish_menu row handler, runs on whoever opened the menu. Lists every
// catalog class and spawns the picked one at heading 0: for anchor/seat/wall the dev reads its front bearing
// off that to record frontYaw; clutter and freestand have no facing and spawn only to be eyeballed.
// game_master because broadcast. English-only debug.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

private _catalog = [
#include "..\..\shared\includes\furniture_catalog.hpp"
];
private _classes = _catalog apply { _x select 0 };

private _rows = [["-- clear spawned --", { ["", player] remoteExec ["fnc_furnish_calibrate_spawn", 2] }, [], [1, 0.4, 0.4, 1]]];
{
    _rows pushBack [_x, { _this remoteExec ["fnc_furnish_calibrate_spawn", 2] }, [_x, player], [1, 0.667, 0, 1]];
} forEach _classes;

["Calibrate furniture fronts", _rows] call fnc_open_action_menu;
