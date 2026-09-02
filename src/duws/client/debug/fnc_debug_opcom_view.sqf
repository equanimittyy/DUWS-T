// Locality: client -- an fnc_debug_menu row handler, runs on whoever opened the menu. The first of the
// OPCOM debug tooling: opens the map and overlays every AoI emitter's reach hatched in its side's
// colour, so the influence field the commander reads and the drift writes through is visible where it
// is otherwise only inferred from town colours. A toggle -- a second call clears the overlay. Re-checked
// against game_master because the function is broadcast to every client. English-only, like the rest of
// the debug surface.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

// Overlay up already -> tear it down. The vanishing rings are the feedback; a hint would render
// beneath the open map anyway.
private _shown = missionNamespace getVariable ["DUWS_dbgAoiMarkers", []];
if (count _shown > 0) exitWith {
    { deleteMarkerLocal _x } forEach _shown;
    missionNamespace setVariable ["DUWS_dbgAoiMarkers", []];
    hint "OPCOM view: AoI overlay cleared.";
};

openMap [true, false];
// The reaches (AOI_*) and the banded-town reputations are server-only, so the server gathers the
// circles and hands them straight back here to draw, the way fnc_map_readout_query answers the board.
[player] remoteExec ["fnc_debug_aoi_circles", 2];
