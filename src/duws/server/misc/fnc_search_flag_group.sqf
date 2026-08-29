// Locality: server -- the flag is authored here. Clients only ever read it.
//
// Stage one of a search: rolls once per unit at creation and stamps winners with their payout source, so
// intel scales with OPFOR spawned rather than how often the search key is pressed. Broadcast because the
// search action's condition runs on the client that would draw it. Takes a group or a plain unit array
// (the patrol spawners hold neither shape consistently). Only objective and civ_frisk sources flag here --
// combat corpses roll flag-free at the search.
//
// The flag lives on the object, so a body-swapping GC (the AGC mod) that rebuilds a distant corpse near a
// player drops it. TODO: exempt these bodies with setVariable ['GCblackList', true] at the flag point.
if (!isServer) exitWith {};

params ["_units", ["_source", "combat"]];

private _config = DUWS_searchSources getOrDefault [_source, []];
if (_config isEqualTo []) exitWith {
    ["WARN", "INTEL", format ["search source '%1' is not in DUWS_searchSources; nothing flagged", _source]] call fnc_log;
};

private _chance = _config select 0;
private _list = if (_units isEqualType grpNull) then { units _units } else { _units };

{
    if (alive _x && {random 1 < _chance}) then {
        _x setVariable ["DUWS_search_src", _source, true];
    };
} forEach _list;
