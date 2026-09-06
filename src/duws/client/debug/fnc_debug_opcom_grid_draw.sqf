// Locality: the client that asked -- fnc_debug_opcom_grid remoteExecs it back here. Draws the influence
// grid as one local marker per force-carrying cell (blue where friendly force leads, red where enemy
// leads, alpha by magnitude), the zero-crossing front-line cells in yellow, and a dot at each belief
// stamp tagged with its age. Local, so only the dev sees them; names are recorded so fnc_debug_opcom_view
// can clear them. English-only, like the rest of the debug surface.
if (!hasInterface) exitWith {};
params [["_cells", []], ["_bel", []], ["_cell", 500]];

{ deleteMarkerLocal _x } forEach (missionNamespace getVariable ["DUWS_dbgOpcomMarkers", []]);

private _names = [];
private _half = _cell / 2;
{
    _x params ["_c", "_f", "_e", "_front"];
    private _nm = format ["duws_opcom_cell_%1", _forEachIndex];
    createMarkerLocal [_nm, [_c select 0, _c select 1]];
    _nm setMarkerShapeLocal "RECTANGLE";
    _nm setMarkerBrushLocal "Solid";
    _nm setMarkerSizeLocal [_half, _half];
    if (_front) then {
        _nm setMarkerColorLocal "#(1,1,0.2,1)";
        _nm setMarkerAlphaLocal 0.8;
    } else {
        // #(r,g,b,a) inline form, not a CfgMarkerColors name (the map has no cyan); alpha carries
        // magnitude, capped at 30 men so a strong cell does not saturate flat.
        _nm setMarkerColorLocal (["#(1,0.3,0.3,1)", "#(0.4,0.7,1,1)"] select ((_f - _e) > 0));
        _nm setMarkerAlphaLocal (0.15 + 0.5 * ((abs (_f - _e)) min 30) / 30);
    };
    _names pushBack _nm;
} forEach _cells;

{
    _x params ["_p", "_age", "_str"];
    private _nm = format ["duws_opcom_bel_%1", _forEachIndex];
    createMarkerLocal [_nm, [_p select 0, _p select 1]];
    _nm setMarkerShapeLocal "ICON";
    _nm setMarkerTypeLocal "mil_dot";
    _nm setMarkerColorLocal "#(1,0.3,0.3,1)";
    _nm setMarkerTextLocal format ["threat %1 · %2t", _str, _age];
    _names pushBack _nm;
} forEach _bel;

missionNamespace setVariable ["DUWS_dbgOpcomMarkers", _names];

["DEBUG", "OPCOM", format ["overlay draw: %1 markers (%2 cells, %3 belief)", count _names, count _cells, count _bel]] call fnc_log;
