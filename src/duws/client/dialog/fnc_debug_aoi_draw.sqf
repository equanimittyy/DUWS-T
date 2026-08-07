// Locality: the client that asked -- fnc_debug_aoi_circles remoteExecs it back here. Draws each AoI
// reach hatched in its side's colour, local so only the dev sees them, and records the marker names so
// the toggle can clear them. Refreshes: any previous overlay is cleared first, so re-opening redraws the
// current state rather than stacking a second set. English-only, like the rest of the debug surface.
if (!hasInterface) exitWith {};
params [["_circles", []]];

{ deleteMarkerLocal _x } forEach (missionNamespace getVariable ["DUWS_dbgAoiMarkers", []]);

private _names = [];
{
    _x params ["_c", "_r", ["_side", "opfor"]];
    private _nm = format ["duws_aoi_dbg_%1", _forEachIndex];
    createMarkerLocal [_nm, [_c select 0, _c select 1]];
    _nm setMarkerShapeLocal "ELLIPSE";
    // Diagonal hatch in the emitter's side colour, not a thin outline: a faint white border on a
    // kilometres-wide ring was there but near-invisible on the map. The hatch reads at a glance, and its
    // gaps keep the ground under it legible where a solid disc would white the map out. Opposite
    // diagonals per side so overlapping OPFOR and BLUFOR coverage stays tellable apart.
    private _blu = _side isEqualTo "blufor";
    _nm setMarkerBrushLocal (["FDiagonal", "BDiagonal"] select _blu);
    _nm setMarkerColorLocal (["ColorEAST", "ColorWEST"] select _blu);
    _nm setMarkerSizeLocal [_r, _r];
    _nm setMarkerAlphaLocal 0.5;
    _names pushBack _nm;
} forEach _circles;
missionNamespace setVariable ["DUWS_dbgAoiMarkers", _names];
