// Locality: the client that asked -- fnc_debug_aoi_circles remoteExecs it back here. Draws each AoI
// reach as a faint white ring, local so only the dev sees them, and records the marker names so the
// toggle can clear them. Refreshes: any previous overlay is cleared first, so re-opening redraws the
// current state rather than stacking a second set. English-only, like the rest of the debug surface.
if (!hasInterface) exitWith {};
params [["_circles", []]];

{ deleteMarkerLocal _x } forEach (missionNamespace getVariable ["DUWS_dbgAoiMarkers", []]);

private _names = [];
{
    _x params ["_c", "_r"];
    private _nm = format ["duws_aoi_dbg_%1", _forEachIndex];
    createMarkerLocal [_nm, [_c select 0, _c select 1]];
    _nm setMarkerShapeLocal "ELLIPSE";
    // Outline, not fill: the reaches are kilometres across, so a filled disc would white out the map;
    // a low-alpha ring shows the radius without swallowing what is under it.
    _nm setMarkerBrushLocal "Border";
    _nm setMarkerColorLocal "ColorWhite";
    _nm setMarkerSizeLocal [_r, _r];
    _nm setMarkerAlphaLocal 0.35;
    _names pushBack _nm;
} forEach _circles;
missionNamespace setVariable ["DUWS_dbgAoiMarkers", _names];
