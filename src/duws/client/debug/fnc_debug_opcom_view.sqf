// Locality: client -- an fnc_debug_menu row handler, runs on whoever opened the menu. The OPCOM debug
// overlay: opens the map and draws two server-only pictures the dev otherwise cannot see -- every AoI
// emitter's reach in its side's colour, and the commander's own influence grid (friendly/enemy force
// per cell, the front line, and each belief stamp). A toggle -- a second call clears both. Re-checked
// against game_master because the function is broadcast to every client. English-only, like the rest of
// the debug surface.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

// Overlay up already -> tear it down. The vanishing markers are the feedback; a hint would render
// beneath the open map anyway.
private _aoi = missionNamespace getVariable ["DUWS_dbgAoiMarkers", []];
private _grid = missionNamespace getVariable ["DUWS_dbgOpcomMarkers", []];
if (count _aoi > 0 || count _grid > 0) exitWith {
    { deleteMarkerLocal _x } forEach (_aoi + _grid);
    missionNamespace setVariable ["DUWS_dbgAoiMarkers", []];
    missionNamespace setVariable ["DUWS_dbgOpcomMarkers", []];
    hint "OPCOM view: overlay cleared.";
};

openMap [true, false];
// Both pictures live only on the server (the AOI_* reaches and banded-town reputations; the influence
// grid and belief store), so each is gathered there and handed straight back here to draw.
[player] remoteExec ["fnc_debug_aoi_circles", 2];
[player] remoteExec ["fnc_debug_opcom_grid", 2];
