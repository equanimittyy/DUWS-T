// Locality: server at the commit (server/server_init.sqf), and every client after it re-runs the
// faction file for itself (client/client_init.sqf).
//
// Lays the table the player confirmed on the faction confirmation screen over whatever is currently
// in the role globals, then -- on the server -- republishes the pools so fnc_faction_pick draws
// from the edited values.
//
// Two callers because two machines can end up holding the file's raw values. The server resolves
// once and would otherwise ship what the faction file said rather than what the player confirmed;
// a client re-runs the whole faction file locally on join, to get the request-menu catalogue the
// schema does not cover, and that run overwrites the edits again.
//
// duws_faction_locked carries every key, not just the edited ones, so this is a straight apply
// rather than a reconciliation: an untouched key writes back what resolution already produced.
//
// A value may be a single classname or an array -- the pool the key editor built from the picked
// class's role bucket, so an edit keeps the per-spawn variety AutoDetect exists to give. An empty
// value is the player having cleared the key. It is written through as-is: the warning on the way
// out of that screen is the whole of the enforcement, and a spawner reading a blank global is a
// case the mission already tolerates.

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
