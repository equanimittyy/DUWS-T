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
    // Same ELLIPSE mechanic as the zone rings -- a SolidBorder fill -- because the diagonal-hatch
    // brushes tried before did not paint on these local markers. Side by colour: pink OPFOR, cyan
    // BLUFOR, as inline #(argb) strings not CfgMarkerColors names (the map has no cyan). Colour-string
    // alpha stays 1; the 0.5 is the marker alpha, so overlapping coverage tints rather than whites out.
    private _blu = _side isEqualTo "blufor";
    _nm setMarkerBrushLocal "SolidBorder";
    _nm setMarkerColorLocal (["#(argb,8,8,3)color(1,0.08,0.58,1)", "#(argb,8,8,3)color(0,1,1,1)"] select _blu);
    _nm setMarkerSizeLocal [_r, _r];
    _nm setMarkerAlphaLocal 0.5;
    _names pushBack _nm;
} forEach _circles;
missionNamespace setVariable ["DUWS_dbgAoiMarkers", _names];
