// Locality: the client that asked -- fnc_debug_opcom_grid remoteExecs it back here each OPCOM tick while
// the overlay is up. Draws the whole-map influence grid: a neutral border per cell (the lattice) and a
// centre dot coloured by who leads it -- red OPFOR, blue BLU (its force plus belief), yellow on the front
// line, white where empty -- with an "OPF/BLU" force readout as text; belief stamps ride on top as blue
// warnings.
//
// Delta, not full redraw: the lattice and dot positions never move, so the first call builds every marker
// and later calls only recolour/retext the dots and reconcile the belief set (whose count varies). A full
// rebuild runs only when the drawn set changes -- first draw or the water toggle. Marker names are the
// absolute cell index, stable across ticks; teardown deletes by the duws_opcom_ prefix. Water cells are
// skipped unless DUWS_dbgOpcomGridWater is set. Local; English-only, like the rest of the debug surface.
if (!hasInterface) exitWith {};
params [["_cells", []], ["_bel", []], ["_cell", 500]];

private _half = _cell / 2;
private _water = missionNamespace getVariable ["DUWS_dbgOpcomGridWater", false];

// Rebuild the lattice only when the drawn set changes; else reuse it and just update the dots. Grid width
// is fixed for the session, so the water flag is the only thing that shifts which cells draw.
private _sig = [count _cells, _water];
private _rebuild = !(_sig isEqualTo (missionNamespace getVariable ["DUWS_dbgOpcomSig", []]));
if (_rebuild) then {
    { if ((_x find "duws_opcom_") == 0) then { deleteMarkerLocal _x } } forEach allMapMarkers;
    missionNamespace setVariable ["DUWS_dbgOpcomSig", _sig];
    missionNamespace setVariable ["DUWS_dbgOpcomBelN", 0];
};

private _sample = "";
{
    _x params ["_c", "_f", "_e", "_front", "_land"];
    // Sea carries no force and only clutters the lattice; keep it out unless explicitly asked.
    if (_land || _water) then {
        private _i = _forEachIndex;

        // Colour and text recomputed every tick so a cell that flips lead or empties out repaints. One
        // decimal, not round: Phase 1 per-cell force is often below 1, which round would show as 0.
        private _col = "#(1,1,1,1)";
        if (_front) then {
            _col = "#(1,1,0.2,1)";
        } else {
            if (_f > _e) then { _col = "#(1,0.3,0.3,1)" };
            if (_e > _f) then { _col = "#(0.4,0.7,1,1)" };
        };
        private _txt = "";
        if (_f > 0.05 || _e > 0.05) then { _txt = format ["OPF %1 BLU %2", _f toFixed 1, _e toFixed 1] };

        private _dm = format ["duws_opcom_dot_%1", _i];
        if (_rebuild) then {
            private _bm = format ["duws_opcom_cell_%1", _i];
            createMarkerLocal [_bm, [_c select 0, _c select 1]];
            _bm setMarkerShapeLocal "RECTANGLE";
            _bm setMarkerBrushLocal "Border";
            _bm setMarkerSizeLocal [_half, _half];
            _bm setMarkerColorLocal "#(1,1,1,1)";
            _bm setMarkerAlphaLocal 0.4;

            createMarkerLocal [_dm, [_c select 0, _c select 1]];
            _dm setMarkerShapeLocal "ICON";
            _dm setMarkerTypeLocal "mil_dot";
            _dm setMarkerSizeLocal [0.6, 0.6];
            if (_sample isEqualTo "") then { _sample = _dm };
        };
        _dm setMarkerColorLocal _col;
        _dm setMarkerTextLocal _txt;
    };
} forEach _cells;

// Belief is a small, shifting set: reuse the markers still standing, spawn any extra, delete last tick's
// surplus. A reused slot holds a different stamp, so its position and text are always reset.
private _belN = missionNamespace getVariable ["DUWS_dbgOpcomBelN", 0];
{
    _x params ["_p", "_age", "_str"];
    private _nm = format ["duws_opcom_bel_%1", _forEachIndex];
    if (_forEachIndex >= _belN) then {
        createMarkerLocal [_nm, [_p select 0, _p select 1]];
        _nm setMarkerShapeLocal "ICON";
        _nm setMarkerTypeLocal "mil_warning";
        _nm setMarkerColorLocal "#(0.3,0.6,1,1)";
        _nm setMarkerSizeLocal [1, 1];
    } else {
        _nm setMarkerPosLocal [_p select 0, _p select 1];
    };
    _nm setMarkerTextLocal format ["threat %1 · %2t", _str, _age];
} forEach _bel;
for "_i" from (count _bel) to (_belN - 1) do { deleteMarkerLocal format ["duws_opcom_bel_%1", _i] };
missionNamespace setVariable ["DUWS_dbgOpcomBelN", count _bel];

["DEBUG", "OPCOM", format ["overlay %1: %2 cells, %3 belief", ["refresh", "rebuild"] select _rebuild, count _cells, count _bel]] call fnc_log;

// Engine truth on a rebuild: a marker that never registered, or a create that returned "" on a name clash,
// is invisible with no error. Sample one dot back to catch a bad pos/colour/size; refresh ticks skip it.
if (_rebuild) then {
    ["DEBUG", "OPCOM", format ["overlay check: registered=%1 mapOpen=%2 | sample=%3 pos=%4 color=%5 size=%6",
        {(_x find "duws_opcom_") == 0} count allMapMarkers,
        visibleMap, _sample, getMarkerPos _sample, getMarkerColor _sample, markerSize _sample]] call fnc_log;
};
