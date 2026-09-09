// Locality: the requesting client -- fnc_debug_opcom_grid remoteExecs it back each OPCOM tick while the
// overlay is up. Delta draw: the border lattice never moves so it builds once; dots, belief stamps and
// tasking boxes reconcile each tick (add the newly-relevant, drop the stale). A neutral cell draws no dot --
// skipping the empty majority of the map is the bulk of the cost saved. Marker names are stable (cell index
// or running slot) so teardown clears the whole set by the duws_opcom_ prefix.
if (!hasInterface) exitWith {};
params [["_cells", []], ["_bel", []], ["_cell", 500], ["_tasks", []]];

private _half = _cell / 2;
private _eps = 0.05;

// Fixed grid width means the cell count only changes on a first draw or a name-clash guard.
private _sig = [count _cells];
private _rebuild = !(_sig isEqualTo (missionNamespace getVariable ["DUWS_dbgOpcomSig", []]));
if (_rebuild) then {
    { if ((_x find "duws_opcom_") == 0) then { deleteMarkerLocal _x } } forEach allMapMarkers;
    missionNamespace setVariable ["DUWS_dbgOpcomSig", _sig];
    missionNamespace setVariable ["DUWS_dbgOpcomBelN", 0];
    missionNamespace setVariable ["DUWS_dbgOpcomTaskN", 0];
};

private _sample = "";
{
    _x params ["_c", "_f", "_e", "_front", "_land"];
    private _i = _forEachIndex;

    if (_rebuild) then {
        private _bm = format ["duws_opcom_cell_%1", _i];
        createMarkerLocal [_bm, [_c select 0, _c select 1]];
        _bm setMarkerShapeLocal "RECTANGLE";
        _bm setMarkerBrushLocal "Border";
        _bm setMarkerSizeLocal [_half, _half];
        _bm setMarkerColorLocal (["#(0.6,0.2,0.8,1)", "#(1,1,1,1)"] select _land);
        _bm setMarkerAlphaLocal 0.4;
        if (_sample isEqualTo "") then { _sample = _bm };
    };

    // One decimal, not round: per-cell force is often below 1, which round would floor to 0.
    private _dm = format ["duws_opcom_dot_%1", _i];
    if (_front || {_f > _eps} || {_e > _eps}) then {
        if ((getMarkerType _dm) isEqualTo "") then {
            createMarkerLocal [_dm, [_c select 0, _c select 1]];
            _dm setMarkerShapeLocal "ICON";
            _dm setMarkerTypeLocal "mil_dot";
            _dm setMarkerSizeLocal [0.6, 0.6];
        };
        private _col = "#(1,1,0.2,1)";
        if (!_front) then {
            _col = "#(1,1,1,1)";
            if (_f > _e) then { _col = "#(0.4,0.7,1,1)" };
            if (_e > _f) then { _col = "#(1,0.3,0.3,1)" };
        };
        _dm setMarkerColorLocal _col;
        _dm setMarkerTextLocal (format ["%1/%2", _f toFixed 1, _e toFixed 1]);
    } else {
        if ((getMarkerType _dm) isNotEqualTo "") then { deleteMarkerLocal _dm };
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
        _nm setMarkerColorLocal "#(1,0.2,0.2,1)";
        _nm setMarkerSizeLocal [1, 1];
    } else {
        _nm setMarkerPosLocal [_p select 0, _p select 1];
    };
    _nm setMarkerTextLocal format ["threat %1 · %2t", _str, _age];
} forEach _bel;
for "_i" from (count _bel) to (_belN - 1) do { deleteMarkerLocal format ["duws_opcom_bel_%1", _i] };
missionNamespace setVariable ["DUWS_dbgOpcomBelN", count _bel];

// OPFOR box per tasking, blue to match the grid's OPFOR-is-blue dots. A live unit stays at its frozen
// de-virt cell and its tag carries the [*] prefix, so no separate live styling here.
private _taskN = missionNamespace getVariable ["DUWS_dbgOpcomTaskN", 0];
{
    _x params ["_tp", "_icon", "_ttxt"];
    private _nm = format ["duws_opcom_task_%1", _forEachIndex];
    if (_forEachIndex >= _taskN) then {
        createMarkerLocal [_nm, [_tp select 0, _tp select 1]];
        _nm setMarkerShapeLocal "ICON";
    } else {
        _nm setMarkerPosLocal [_tp select 0, _tp select 1];
    };
    _nm setMarkerTypeLocal _icon;
    _nm setMarkerColorLocal "#(0.2,0.6,1,1)";
    _nm setMarkerSizeLocal [0.9, 0.9];
    _nm setMarkerTextLocal _ttxt;
} forEach _tasks;
for "_i" from (count _tasks) to (_taskN - 1) do { deleteMarkerLocal format ["duws_opcom_task_%1", _i] };
missionNamespace setVariable ["DUWS_dbgOpcomTaskN", count _tasks];

["DEBUG", "OPCOM", format ["overlay %1: %2 cells, %3 belief, %4 taskings", ["refresh", "rebuild"] select _rebuild, count _cells, count _bel, count _tasks]] call fnc_log;

// Engine truth on a rebuild: a marker that never registered, or a create that returned "" on a name clash,
// is invisible with no error. Sample one border back to catch a bad pos/colour/size; refresh ticks skip it.
if (_rebuild) then {
    ["DEBUG", "OPCOM", format ["overlay check: registered=%1 mapOpen=%2 | sample=%3 pos=%4 color=%5 size=%6",
        {(_x find "duws_opcom_") == 0} count allMapMarkers,
        visibleMap, _sample, getMarkerPos _sample, getMarkerColor _sample, markerSize _sample]] call fnc_log;
};
