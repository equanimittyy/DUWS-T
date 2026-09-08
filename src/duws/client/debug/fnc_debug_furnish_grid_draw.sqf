// Locality: the client that asked -- fnc_furnish_grid_gather remoteExecs it back here once, after the
// overlay is toggled on. Only stows the cells; the Draw3D handler installed by fnc_debug_furnish_view is
// the drawer, so a re-request (mode switch) repaints without touching the handler. Broadcast; local draw.
if (!hasInterface) exitWith {};
params [["_cells", []], ["_mode", "state"]];
DUWS_dbgFurnishCells = _cells;
DUWS_dbgFurnishMode = _mode;
["DEBUG", "FURNISH", format ["overlay: %1 cell(s) received (%2)", count _cells, _mode]] call fnc_log;
