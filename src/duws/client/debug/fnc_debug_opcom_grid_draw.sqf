// Locality: the client that asked -- fnc_debug_opcom_grid remoteExecs it back here. Draws the whole-map
// influence grid: a neutral-white border per cell (the lattice) and a centre dot coloured by who leads
// the cell -- blue friendly (OPFOR holdings), red enemy (BLU + belief), yellow on the front line, white
// where empty -- with a "friendly/enemy" force readout as its text. Belief stamps ride on top as red
// warnings. Water cells are skipped unless DUWS_dbgOpcomGridWater is set. Local, so only the dev sees
// them; names are recorded so fnc_debug_opcom_view can clear them. English-only, like the rest of the
// debug surface.
if (!hasInterface) exitWith {};
params [["_cells", []], ["_bel", []], ["_cell", 500]];

{ deleteMarkerLocal _x } forEach (missionNamespace getVariable ["DUWS_dbgOpcomMarkers", []]);

private _names = [];
private _half = _cell / 2;
private _water = missionNamespace getVariable ["DUWS_dbgOpcomGridWater", false];

{
    _x params ["_c", "_f", "_e", "_front", "_land"];
    // Sea carries no force and only clutters the lattice; keep it out unless explicitly asked.
    if (_land || _water) then {
        private _i = _forEachIndex;

        private _bm = format ["duws_opcom_cell_%1", _i];
        createMarkerLocal [_bm, [_c select 0, _c select 1]];
        _bm setMarkerShapeLocal "RECTANGLE";
        _bm setMarkerBrushLocal "Border";
        _bm setMarkerSizeLocal [_half, _half];
        _bm setMarkerColorLocal "#(1,1,1,1)";
        _bm setMarkerAlphaLocal 0.4;
        _names pushBack _bm;

        // Centre dot: colour states who leads, text gives the two force numbers. Empty cells stay a bare
        // white dot with no text so the lattice reads without 3000 "0/0" labels.
        private _col = "#(1,1,1,1)";
        if (_front) then {
            _col = "#(1,1,0.2,1)";
        } else {
            if (_f > _e) then { _col = "#(0.4,0.7,1,1)" };
            if (_e > _f) then { _col = "#(1,0.3,0.3,1)" };
        };
        private _dm = format ["duws_opcom_dot_%1", _i];
        createMarkerLocal [_dm, [_c select 0, _c select 1]];
        _dm setMarkerShapeLocal "ICON";
        _dm setMarkerTypeLocal "mil_dot";
        _dm setMarkerColorLocal _col;
        _dm setMarkerSizeLocal [0.6, 0.6];
        // One decimal, not round: Phase 1 per-cell force is often below 1, which round would show as 0.
        if (_f > 0.05 || _e > 0.05) then {
            _dm setMarkerTextLocal format ["%1/%2", _f toFixed 1, _e toFixed 1];
        };
        _names pushBack _dm;
    };
} forEach _cells;

{
    _x params ["_p", "_age", "_str"];
    private _nm = format ["duws_opcom_bel_%1", _forEachIndex];
    createMarkerLocal [_nm, [_p select 0, _p select 1]];
    _nm setMarkerShapeLocal "ICON";
    _nm setMarkerTypeLocal "mil_warning";
    _nm setMarkerColorLocal "#(1,0.2,0.2,1)";
    _nm setMarkerSizeLocal [1, 1];
    _nm setMarkerTextLocal format ["threat %1 · %2t", _str, _age];
    _names pushBack _nm;
} forEach _bel;

missionNamespace setVariable ["DUWS_dbgOpcomMarkers", _names];

["DEBUG", "OPCOM", format ["overlay draw: %1 markers (%2 cells, %3 belief)", count _names, count _cells, count _bel]] call fnc_log;

// Engine truth, not just what we asked for: a marker that never registered, or a create that returned ""
// on a name clash, is invisible with no error. Sample reads marker 0 back to catch a bad pos/colour/size.
private _first = _names param [0, ""];
["DEBUG", "OPCOM", format ["overlay check: registered=%1 blank=%2 mapOpen=%3 | first=%4 pos=%5 color=%6 size=%7 alpha=%8",
    {(_x find "duws_opcom_") == 0} count allMapMarkers,
    {_x isEqualTo ""} count _names,
    visibleMap, _first, getMarkerPos _first, getMarkerColor _first, markerSize _first, markerAlpha _first]] call fnc_log;
