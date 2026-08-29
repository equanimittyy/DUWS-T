// Locality: the client that asked -- fnc_debug_aoi_circles remoteExecs it back here. Draws each AoI
// reach as a translucent disc in its side's colour, local so only the dev sees them, records the names so
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
    // Solid fill, no border: the per-circle border ring made overlapping reaches read as separate
    // discs, so dropping it blends a side's coverage into one soft field. Diagonal-hatch brushes did
    // not paint on these local markers. Colour is the inline #(r,g,b,a) form, not a CfgMarkerColors
    // name (the map has no cyan); the marker alpha below -- not the string's 4th channel -- is kept
    // low so a double overlap barely darkens, holding the union close to flat. Pastel rose OPFOR,
    // pastel sky BLUFOR, kept light so overlaps sit easier on the eyes.
    private _blu = _side isEqualTo "blufor";
    _nm setMarkerBrushLocal "Solid";
    _nm setMarkerColorLocal (["#(1,0.62,0.72,1)", "#(0.6,0.82,1,1)"] select _blu);
    _nm setMarkerSizeLocal [_r, _r];
    _nm setMarkerAlphaLocal 0.28;
    _names pushBack _nm;
} forEach _circles;
missionNamespace setVariable ["DUWS_dbgAoiMarkers", _names];
