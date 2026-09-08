// Locality: server -- remoteExec'd to 2 by fnc_debug_furnish_view. Builds (or reads the cache of) the
// requested building's floor-plan grid and hands the drawable cells back to the requesting client, the
// way fnc_debug_opcom_grid answers for the OPCOM overlay. Server-only, not broadcast.
if (!isServer) exitWith {};
params ["_building", "_requester", ["_mode", "state"]];
if (isNull _building) exitWith {};

private _grid = [_building] call fnc_furnish_grid;
// Lite rows: the drawer needs only where each cell is, its state and its room id.
private _cells = _grid apply { [_x select 0, _x select 1, _x select 4] };
["DEBUG", "FURNISH", format ["overlay gather: %1 cell(s) (%2) -> %3", count _cells, _mode, _requester]] call fnc_log;
[_cells, _mode] remoteExec ["fnc_debug_furnish_grid_draw", _requester];
