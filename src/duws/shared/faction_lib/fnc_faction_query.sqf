// Locality: split -- fnc_faction_query runs on the server (fnc_faction_ask remoteExecCalls it to
// target 2); fnc_faction_ask and fnc_faction_reply run on the asking client.
//
// The setup screens run on a client, whose mods need not match the server's, and the server is what
// builds the faction. So whatever decides what a faction may hold is answered here. remoteExecCall
// keeps the query unscheduled: a class list for ALL walks CfgVehicles and would crawl at the
// scheduler's frame budget.

DUWS_factionParseCache = createHashMap;

fnc_faction_query = {
    if (!isServer) exitWith {};
    params ["_op", "_args", "_requester", "_replyVar"];
    private _result = switch (_op) do {
        // Scope 2 only: fnc_faction_keep drops anything less at the commit.
        case "classes": {
            _args params ["_faction", "_kind"];
            private _cond = if (_faction isEqualTo "__ALL__") then {
                "getNumber(_x >> 'scope') == 2"
            } else {
                "(getNumber(_x >> 'scope') == 2) && (gettext (_x >> 'faction') == _faction)"
            };
            private _classes = (_cond configClasses (configFile >> "CfgVehicles")) apply { configName _x };
            _classes = switch (_kind) do {
                case "man":    { _classes select { _x isKindOf "CAManBase" } };
                case "static": { _classes select { _x isKindOf "StaticWeapon" } };
                default {
                    _classes select {
                        !(_x isKindOf "CAManBase") && {!(_x isKindOf "StaticWeapon")}
                        && {_x isKindOf "LandVehicle" || {_x isKindOf "Air"} || {_x isKindOf "Ship"}}
                    }
                };
            };
            private _rows = _classes apply {
                private _name = getText (configFile >> "CfgVehicles" >> _x >> "displayName");
                [if (_name isEqualTo "") then {_x} else {_name}, _x]
            };
            _rows sort true;
            _rows
        };
        // Asked only with a main set, and fnc_faction_list_base ignores _current then.
        case "base": {
            [_args select 0, [], DUWS_factionParseCache] call fnc_faction_list_base
        };
        // Verdict only: the build parses the paste again for itself.
        case "validate": {
            (_args call fnc_custom_faction_parse) select [1, 2]
        };
        default {
            ["ERROR", "FACTION", format ["fnc_faction_query: unknown op %1", _op]] call fnc_log;
            []
        };
    };
    [_replyVar, _result] remoteExecCall ["fnc_faction_reply", _requester];
};

fnc_faction_reply = {
    params ["_replyVar", "_result"];
    missionNamespace setVariable [_replyVar, [_result]];
};

// Blocks until the server answers, so callers must be scheduled. A query that throws on the server
// sends no reply at all, which without the deadline hangs the screen for good.
fnc_faction_ask = {
    params ["_op", "_args", "_default"];
    duws_faction_ask_seq = (missionNamespace getVariable ["duws_faction_ask_seq", 0]) + 1;
    private _replyVar = format ["duws_faction_reply_%1", duws_faction_ask_seq];
    [_op, _args, player, _replyVar] remoteExecCall ["fnc_faction_query", 2];
    private _deadline = diag_tickTime + 30;
    waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
    private _reply = missionNamespace getVariable [_replyVar, []];
    missionNamespace setVariable [_replyVar, nil];
    if (_reply isEqualTo []) exitWith {
        ["ERROR", "FACTION", format ["Server gave no answer to faction query %1", _op]] call fnc_log;
        _default
    };
    _reply select 0
};
