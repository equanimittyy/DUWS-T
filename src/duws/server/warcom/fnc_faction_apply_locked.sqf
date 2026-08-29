// Locality: server applies this at the commit (server/server_init.sqf); every client re-runs the faction
// file itself after (client/client_init.sqf), so both machines need this apply.
//
// Lays the player-confirmed table over the role globals, then -- on the server -- republishes the pools so
// fnc_faction_pick draws the edited values. Two callers because two machines end up holding raw values:
// the server resolves once (else it ships the faction file's values, not the confirmed ones), and a client
// re-runs the whole faction file on join (for the request-menu catalogue the schema doesn't cover), which
// overwrites the edits. duws_faction_locked carries every key, so this is a straight apply, not a
// reconciliation. A value may be a class or a pool array (keeping per-spawn variety); an empty value is a
// cleared key, written through as-is (the screen's exit warning is the whole enforcement).

if (duws_faction_locked isEqualTo []) exitWith {
    ["INFO", "FACTION", "No locked faction table; keeping resolved values."] call fnc_log;
};

{
    _x params ["_side", "_rows"];
    private _cleared = [];

    {
        _x params ["_key", "_value"];
        // Broadcast only from the server. A client applying its own copy must not push it back at
        // everyone else, and it is the server's resolution that is authoritative anyway.
        missionNamespace setVariable [_key, _value, isServer];
        if (_value isEqualTo "" || {_value isEqualTo []}) then { _cleared pushBack _key; };
    } forEach _rows;

    // Pools are read only by the spawn paths, which are server-side. Republished from the applied
    // values rather than the resolved ones: a stale pool would keep serving the class the player
    // just replaced.
    if (isServer) then { [_rows apply {_x select 0}] call fnc_faction_pools_publish; };

    ["INFO", "FACTION", format ["Locked %1 faction: %2 keys applied, %3 cleared %4",
        _side, count _rows, count _cleared, if (_cleared isEqualTo []) then {""} else {str _cleared}]] call fnc_log;
} forEach duws_faction_locked;
