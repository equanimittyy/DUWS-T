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
    // Same ELLIPSE mechanic the zone rings draw with -- SolidBorder fill in the emitter's side colour
    // at low alpha (fnc_createzone, fnc_baseRangeMarker) -- because the diagonal-hatch brushes tried
    // before did not paint on these local markers. Side by colour, not brush: OPFOR ColorEAST, BLUFOR
    // ColorWEST. Alpha 0.3 like the zone rings, so overlapping coverage tints rather than whites out.
    private _blu = _side isEqualTo "blufor";
    _nm setMarkerBrushLocal "SolidBorder";
    _nm setMarkerColorLocal (["ColorEAST", "ColorWEST"] select _blu);
    _nm setMarkerSizeLocal [_r, _r];
    _nm setMarkerAlphaLocal 0.3;
    _names pushBack _nm;
} forEach _circles;
missionNamespace setVariable ["DUWS_dbgAoiMarkers", _names];
