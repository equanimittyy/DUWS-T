// Locality: server -- called at the commit (server/server_init.sqf). Clients take the result from its
// broadcast; none runs a faction file.
//
// Lays the player-confirmed table over the role globals, then republishes the pools so fnc_faction_pick
// draws the edited values. duws_faction_locked carries every key, so this is a straight apply, not a
// reconciliation. A value may be a class or a pool array (keeping per-spawn variety); an empty value is a
// cleared key, written through as-is (the screen's exit warning is the whole enforcement).
//
// A row is [key, value, record]; a vehicle row the player edited carries its list record
// (fnc_faction_lists.sqf). That row is rebuilt from the record instead of from the client's list, so a
// commit and a restore share one path.

if (duws_faction_locked isEqualTo []) exitWith {
    ["INFO", "FACTION", "No locked faction table; keeping resolved values."] call fnc_log;
};

private _edited = [];
{
    _x params ["_side", "_rows"];
    private _cleared = [];
    private _written = [];

    {
        _x params ["_key", "_value", ["_record", []]];
        if !(_record isEqualTo []) then {
            _edited pushBack ([_key] + _record);
        } else {
            missionNamespace setVariable [_key, _value, true];
            _written pushBack _key;
            if (_value isEqualTo "" || {_value isEqualTo []}) then { _cleared pushBack _key; };
        };
    } forEach _rows;

    // Republished from the applied values rather than the resolved ones: a stale pool would keep
    // serving the class the player just replaced. An edited row is left out: its pool is the base its
    // record resolves against.
    [_written] call fnc_faction_pools_publish;

    ["INFO", "FACTION", format ["Locked %1 faction: %2 keys applied, %3 cleared %4",
        _side, count _rows, count _cleared, if (_cleared isEqualTo []) then {""} else {str _cleared}]] call fnc_log;
} forEach duws_faction_locked;

[_edited] call fnc_faction_edits_apply;
