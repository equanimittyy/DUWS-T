// Locality: server. Never spends a ladder step, so testing does not move the live ladder.
if (!isServer) exitWith {};

params ["_caller", ["_source", "combat"], ["_forceIntel", false]];
if (isNull _caller) exitWith {};

private _config = if (_source isEqualTo "combat") then {
    private _times = (missionNamespace getVariable ["DUWS_searchTimes", []]) select {time - _x < DUWS_searchCooldown};
    DUWS_searchLadder select ((count _times) min (count DUWS_searchLadder - 1))
} else {
    DUWS_searchSources getOrDefault [_source, []]
};
if (_config isEqualTo []) exitWith {
    [format ["Intel search (debug)\n\nNo source named '%1' in DUWS_searchSources.", _source]] remoteExec ["hint", _caller];
};

// Names copied out as strings: zones, hardcore-hidden towns and hardpoint keys. The entries themselves
// are handed out by reference, so a snapshot of them would mutate along with the array and show
// nothing changed.
private _fnc_hidden = {
    private _out = (zone_namePOS_pairs select {!(_x select 2)}) apply {_x select 0};
    private _towns = missionNamespace getVariable ["civ_locations", []];
    {
        if (!_x) then {
            private _name = text (_towns select _forEachIndex);
            _out pushBack (if (_name != "") then {_name} else {format ["Town %1", _forEachIndex]});
        };
    } forEach (missionNamespace getVariable ["civ_visible", []]);
    { if (!(_x select 5)) then { _out pushBack (_x select 0) } } forEach DUWS_hardpoints;
    _out
};

private _hiddenBefore = call _fnc_hidden;

private _kind = if (_forceIntel) then { "intel" } else { [_config select 1] call fnc_search_drawKind };
private _outcome = format ["drew '%1'", _kind];

// Only the intel kind can decline, and only the intel kind is worth showing the pool for. The
// other kinds are reported as drawn rather than paid, so a debug press cannot quietly hand out CP.
if (_kind isEqualTo "intel") then {
    _outcome = if ([getPosATL _caller, _caller] call fnc_intel_payout) then {
        format ["intel - revealed %1", (_hiddenBefore - (call _fnc_hidden)) param [0, "?"]]
    } else {
        "intel - but every payout pool is empty, so a real search would re-draw"
    };
};

[format [
    "Intel search (debug)\n\nSource '%1', chance %2%7\nWeights: %3\n\n%4\n\nHidden positions: %5 -> %6",
    _source,
    (_config select 0) * 100,
    _config select 1,
    _outcome,
    count _hiddenBefore,
    count (call _fnc_hidden),
    "%"
]] remoteExec ["hint", _caller];
