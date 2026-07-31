// Locality: server -- the flag is authored here. Clients only ever read it.
//
// Stage one of a search. Rolls once per unit at the moment the unit is created and marks the
// winners with the source whose payout table they will later be drawn against. An unmarked thing
// holds nothing, deterministically, and offers no action to say so.
//
// Rolled at creation rather than at the action: how much intel exists is then a function of how
// much OPFOR the campaign put on the ground, not of how often a key was pressed. It also means
// only the flagged share carries any state at all, rather than every corpse the campaign
// produces.
//
// Broadcast because the search action's condition is evaluated on the client that would draw it.
// That makes the flag readable by a client with the debug console open, which is accepted here:
// this is co-op against AI, and the alternative -- offering the action on every body and
// answering "nothing" from the server -- puts a prompt on every body the campaign produces.
//
// Takes a group or a plain array of units, because the mission patrol spawners hold neither
// shape consistently.
if (!isServer) exitWith {};

params ["_units", ["_source", "garrison"]];

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
