// Locality: client -- an fnc_debug_menu row handler, runs on whoever opened the menu. Toggles the AoI
// overlay: every AoI emitter's reach ringed in its side's colour, a server-only picture the dev otherwise
// cannot see. Independent of the OPCOM grid toggle (fnc_debug_opcom_view) -- each owns its own marker set
// and clears only its own. A second call clears it. Re-checked against game_master because the function
// is broadcast to every client. English-only, like the rest of the debug surface.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

private _aoi = missionNamespace getVariable ["DUWS_dbgAoiMarkers", []];
if (count _aoi > 0) exitWith {
    { deleteMarkerLocal _x } forEach _aoi;
    missionNamespace setVariable ["DUWS_dbgAoiMarkers", []];
    hint "AoI view: overlay cleared.";
};

openMap [true, false];
// The AoI reaches live only on the server, so they are gathered there and handed back here to draw.
[player] remoteExec ["fnc_debug_aoi_circles", 2];
