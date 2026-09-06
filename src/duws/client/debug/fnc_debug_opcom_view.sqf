// Locality: client -- an fnc_debug_menu row handler, runs on whoever opened the menu. Toggles the OPCOM
// influence-grid overlay: the commander's own grid (friendly/enemy force per cell, the front line, and
// each belief stamp), a server-only picture the dev otherwise cannot see. Independent of the AoI toggle
// (fnc_debug_aoi_view) -- each owns its own marker set and clears only its own. A second call clears it.
// Re-checked against game_master because the function is broadcast to every client. English-only debug.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

// Overlay up already -> tear it down. The vanishing markers are the feedback; a hint would render
// beneath the open map anyway.
private _grid = missionNamespace getVariable ["DUWS_dbgOpcomMarkers", []];
if (count _grid > 0) exitWith {
    { deleteMarkerLocal _x } forEach _grid;
    missionNamespace setVariable ["DUWS_dbgOpcomMarkers", []];
    hint "OPCOM grid: overlay cleared.";
};

openMap [true, false];
// The grid and belief store live only on the server, so they are gathered there and handed back to draw.
[player] remoteExec ["fnc_debug_opcom_grid", 2];
