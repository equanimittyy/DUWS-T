// Locality: server -- the flag is authored here. Clients only ever read it.
//
// Broadcast: the search action's condition runs on the client that would draw it. Combat corpses carry no
// flag; they roll at the search.
//
// GCblackList: the AGC mod rebuilds a distant corpse as a new object, dropping the flag. Unread without AGC.
if (!isServer) exitWith {};

params ["_units", "_source"];

private _config = DUWS_searchSources getOrDefault [_source, []];
if (_config isEqualTo []) exitWith {
    ["WARN", "INTEL", format ["search source '%1' is not in DUWS_searchSources; nothing flagged", _source]] call fnc_log;
};

private _chance = _config select 0;

{
    if (alive _x && {random 1 < _chance}) then {
        _x setVariable ["DUWS_search_src", _source, true];
        _x setVariable ["GCblackList", true, true];
    };
} forEach _units;
