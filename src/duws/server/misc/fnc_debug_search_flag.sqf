// Locality: server -- the flag is authored here, where fnc_search_flag_group authors it, and
// broadcast for the same reason: the search action's condition is evaluated on the client that
// would draw it.
/*
    fnc_debug_search_flag.sqf
    Developer tool: mark whatever the caller was looking at as searchable under a chosen source,
    so a payout table can be exercised on a chair instead of on a garrison that has to be fought
    first. Reached from client/dialog/fnc_debug_search_menu.sqf.
*/
if (!isServer) exitWith {};

params ["_caller", ["_target", objNull], ["_source", "garrison"]];
if (isNull _caller) exitWith {};

// Re-checked here rather than trusted to the menu: this is reachable by remoteExec from any
// client, and what it plants pays out.
if !((vehicleVarName _caller) in game_master) exitWith {};

if (isNull _target) exitWith {
    ["Search flag (debug)\n\nNothing under the cursor."] remoteExec ["hint", _caller];
};

private _config = DUWS_searchSources getOrDefault [_source, []];
if (_config isEqualTo []) exitWith {
    [format ["Search flag (debug)\n\nNo source named '%1' in DUWS_searchSources.", _source]] remoteExec ["hint", _caller];
};

// Stage one's roll is skipped rather than faked: waiting out an 8% garrison chance to reach the
// payout under test is the whole reason this exists. Everything past the flag is the real path,
// so the claim is still taken on the server and still broadcast -- one search for the team.
_target setVariable ["DUWS_search_src", _source, true];
// Cleared as well, because a target searched once is spent for good: without this a second press
// hands back an object whose action no longer shows.
_target setVariable ["DUWS_search_done", false, true];

// The one condition the flag cannot satisfy on its own, reported rather than worked around -- a
// debug path that lifted it would stop exercising the gate the real action runs.
private _blockers = [];
if (_target isKindOf "CAManBase" && {alive _target}
    && {!(_target getVariable ["isSurrendered", false])}) then {
    _blockers pushBack "a living man is excluded until surrendered";
};

private _name = typeOf _target;
if (_name isEqualTo "") then { _name = str _target };

[format [
    "Search flag (debug)\n\n%1\nflagged as '%2'\nWeights: %3\n\n%4\n\nThe claim is taken on the server and broadcast, so the\nfirst player to finish the hold spends it for everyone.",
    _name,
    _source,
    _config select 1,
    if (_blockers isEqualTo []) then {
        "Stand within 3 m and hold the search action."
    } else {
        format ["No action will show: %1.", _blockers joinString "; "]
    }
]] remoteExec ["hint", _caller];
