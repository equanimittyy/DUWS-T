// A vehicle role's edits from the confirmation screen, kept as intent rather than a finished list:
// [main, added, dropped]. A later detection rebuilds the detected part (the base) and the edits land
// on top, so a restore after a mod update still picks up the vehicles the update added.
//
// main is the parent: once set, the base is the rung of the role's ladder that holds main
// (fnc_faction_pool_for_role), not the pool resolution built. main heads the resolved list, where
// fnc_faction_pools_publish reads the representative.

fnc_faction_list_resolve = {
    params ["_base", "_record"];
    _record params ["_main", "_added", "_dropped"];
    private _list = ([_main] - [""]) + (_base - _dropped) + _added;
    _list arrayIntersect _list
};

// Add and remove test the resolved list, not the record alone: after a Make main re-parents the role,
// an added class can also sit in the new base, and a remove that only cleared it from added would
// leave it listed.
fnc_faction_list_edit = {
    params ["_record", "_op", "_class", "_base"];
    _record params ["_main", "_added", "_dropped"];
    switch (_op) do {
        case "add": {
            _dropped = _dropped - [_class];
            if !(_class in ([_base, [_main, _added, _dropped]] call fnc_faction_list_resolve)) then { _added = _added + [_class]; };
        };
        case "remove": {
            _added = _added - [_class];
            if (_class in ([_base, [_main, _added, _dropped]] call fnc_faction_list_resolve)) then { _dropped = _dropped + [_class]; };
        };
        case "main": {
            _added = _added - [_class];
            // A replaced main the player chose stays listed; the detected one leaves with its bucket.
            if !(_main in ["", _class]) then { _added = _added + [_main]; };
            _main = _class;
        };
        case "reset": { _main = ""; _added = []; _dropped = []; };
    };
    [_main, _added, _dropped]
};

// _current is the role's value before any edit, a class or a pool. _cache maps faction to parse: the
// parse walks a whole faction's CfgVehicles.
fnc_faction_list_base = {
    params ["_key", "_record", "_current", "_cache"];
    private _main = _record select 0;
    if (_main isEqualTo "") exitWith { if (_current isEqualType []) then { _current } else { [_current] - [""] } };
    private _faction = getText (configFile >> "CfgVehicles" >> _main >> "faction");
    private _parsed = _cache get _faction;
    if (isNil "_parsed") then {
        _parsed = [_faction] call fnc_parseFaction;
        _cache set [_faction, _parsed];
    };
    [_key, _main, _parsed] call fnc_faction_pool_for_role
};

// Locality: server. The one path from a record to a live pool, for the commit and for a restore alike,
// so it resolves from the record rather than trusting a list a client built.
fnc_faction_edits_apply = {
    params ["_rows"];
    private _cache = createHashMap;
    {
        _x params ["_key", "_main", "_added", "_dropped"];
        // A saved main this install lacks: fall back to the base resolution built.
        if (_main != "" && {([[_main], "vehicle"] call fnc_faction_keep) isEqualTo []}) then { _main = ""; };
        private _record = [_main, _added, _dropped];
        // Same fallback the preview broadcast takes, so the server rebuilds the base the screen showed.
        private _current = missionNamespace getVariable [format ["DUWS_factionPool_%1", _key], []];
        if (_current isEqualTo []) then { _current = missionNamespace getVariable [_key, ""]; };
        private _list = [[[_key, _record, _current, _cache] call fnc_faction_list_base, _record] call fnc_faction_list_resolve, "vehicle"] call fnc_faction_keep;
        if (_list isEqualTo []) then {
            ["WARN", "FACTION", format ["%1 list edits left no spawnable class -- kept the resolved pool", _key]] call fnc_log;
        } else {
            missionNamespace setVariable [_key, _list];
            [[_key]] call fnc_faction_pools_publish;
            ["INFO", "FACTION", format ["%1 list edits applied: %2", _key, _list]] call fnc_log;
        };
    } forEach _rows;
    DUWS_factionListEdits = _rows;
};
