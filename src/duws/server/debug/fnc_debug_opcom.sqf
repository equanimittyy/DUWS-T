// Locality: server -- remoteExec'd to 2 by the OPCOM and OPCOM AI debug menus. Every hand-drive verb in one entry:
// action verbs run through fnc_opcom_debug_task and hint the result back; *list verbs read the server-owned
// store (recruit rows, taskings) and ship rows to the caller's picker, which cannot see the store from a
// remote client. English-only, like the rest of the debug surface.
if (!isServer) exitWith {};
params ["_verb", ["_a", ""], ["_b", ""], ["_c", ""], ["_caller", objNull]];
if (isNull _caller) exitWith {};

switch (_verb) do {
    case "recruitlist": {
        private _rows = (keys DUWS_opcom_recruitMenu) apply {
            private _comp = (DUWS_opcom_recruitMenu get _x) select 0;
            private _force = [_comp] call DUWS_fnc_tokenListForce;
            [_x, format ["%1  (force %2, %3 AP)", _x, _force, OPCOM_AP_UNIT getOrDefault [_x, 0]]]
        };
        ["Recruit a unit", _rows, "recruit", ""] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "garrisonlist": {
        // _a = tasking id. The OPFOR ground a unit can settle into: every zone BLUFOR has not captured, and every
        // town holding a garrison. Both file under one site key, so the settle and its reserve sync read the same.
        private _rows = [];
        {
            private _zp = _x select 1;
            if ((WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _zp) < 1 }) < 0) then {
                private _d = _caller distance2D _zp;
                _rows pushBack [_d, [_zp] call fnc_zone_key, format ["zone %1  (%2 m away)", [_zp] call fnc_zone_key, round _d]];
            };
        } forEach zone_meta_array;
        // A boat garrisons a zone's port, so it is never offered a town.
        private _t = [_a] call DUWS_fnc_opcom_byId;
        private _boat = !isNil "_t" && {(_t get "moveType") isEqualTo "boat"};
        {
            private _tier = [_forEachIndex] call fnc_town_garrison_tierAt;
            if (!_boat && {_tier >= 1}) then {
                private _d = _caller distance2D (getPos _x);
                _rows pushBack [_d, [_forEachIndex] call fnc_town_site_key, format ["town %1  (tier %2, %3 m away)", text _x, _tier, round _d]];
            };
        } forEach (missionNamespace getVariable ["civ_locations", []]);
        if (_rows isEqualTo []) exitWith { "No OPFOR zone or garrisoned town." remoteExec ["hint", _caller] };
        _rows sort true;
        ["Garrison which site?", _rows apply { [_x select 1, _x select 2] }, "garrison_site", _a] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "zonelist": {
        // OPCOM recruits and buys only in an OPFOR-owned zone -- every zone BLUFOR has not captured.
        // _a carries context (recruit row or tasking id) to the next step; _b names that step's picker mode.
        private _next = ["recruit_zone", _b] select (_b isNotEqualTo "");
        private _rows = (zone_meta_array select {
            private _zp = _x select 1;
            (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _zp) < 1 }) < 0
        }) apply {
            private _zp = _x select 1;
            [[_zp] call fnc_zone_key, format ["%1  (%2)", [_zp] call fnc_zone_key, _zp apply { round _x }]]
        };
        if (_rows isEqualTo []) exitWith { "No OPFOR-owned zone (BLUFOR holds them all)." remoteExec ["hint", _caller] };
        private _title = ["Defensive tasking at which zone?", "Recruit at which zone?"] select (_next isEqualTo "recruit_zone");
        [_title, _rows, _next, _a] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "tasklist": {
        // Everything OPCOM can be given an order is one list: taskings keyed by their numeric id, emplacements by
        // their string key, which is how the picked row tells the step which orders it has (fnc_debug_opcom_step).
        // Live taskings included: fnc_opcom_task re-orders a de-virtualised group in place (reOrderLive), the
        // same primitive OPCOM's loop drives -- only a bound ferry carry is refused, and by the primitive.
        private _rows = DUWS_opcom_taskings apply {
            [_x get "id", format ["id %1  %2/%3  %4  (%5)", _x get "id", _x get "order", _x get "status", _x get "moveType", ["virtual", "live"] select ((_x get "grp") isNotEqualTo "")]]
        };
        {
            _x params ["_key", "_pos", "_type"];
            _rows pushBack [_key, format ["%1  %2  (%3 m away)", _type, _key, round (_caller distance2D _pos)]];
        } forEach ([getPosASL _caller] call DUWS_fnc_opcom_batteries);
        if (_rows isEqualTo []) exitWith { "Nothing to order (recruit a unit first)." remoteExec ["hint", _caller] };
        ["Order which unit or gun?", _rows, "order", ""] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "townlist": {
        // _a = tasking id, _b = errand kind. Nearest first; reinforce and fortify list only towns with a garrison.
        private _locs = missionNamespace getVariable ["civ_locations", []];
        private _reps = missionNamespace getVariable ["civ_town_rep", []];
        private _rows = [];
        {
            private _tier = [_forEachIndex] call fnc_town_garrison_tierAt;
            if (_b isEqualTo "rapport" || {_tier >= 1}) then {
                _rows pushBack [_caller distance2D (getPos _x), _forEachIndex, format ["%1  (rep %2, tier %3, strength %4)", text _x, _reps param [_forEachIndex, 0], _tier,
                    ([_forEachIndex] call fnc_town_garrison_strengthAt) toFixed 2]];
            };
        } forEach _locs;
        if (_rows isEqualTo []) exitWith { format ["No town to %1.", _b] remoteExec ["hint", _caller] };
        _rows sort true;
        [format ["%1 which town?", _b], _rows apply { [_x select 1, _x select 2] }, "supply_town", [_a, _b]] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "sightinglist": {
        // _a = tasking id. A row is where OPCOM believes the group is, not where it stands.
        private _rows = [];
        {
            if ([_x] call DUWS_fnc_opcom_beliefIsSighting) then {
                private _bp = DUWS_opcom_belief_pos select _forEachIndex;
                _rows pushBack [_caller distance2D _bp, _x, format ["%1  (%2 m away, force %3, %4 ticks old)", _x, round (_caller distance2D _bp),
                    round (DUWS_opcom_belief_str select _forEachIndex), DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex)]];
            };
        } forEach DUWS_opcom_belief_key;
        if (_rows isEqualTo []) exitWith { "No BLUFOR sightings in OPCOM belief." remoteExec ["hint", _caller] };
        _rows sort true;
        ["Intercept which sighting?", _rows apply { [_x select 1, _x select 2] }, "intercept_row", _a] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "recruit": {
        // _a = row, _b = zone key. Site at the zone centre and home the unit there, so homeZone drives the
        // garrison-reserve coupling.
        private _i = zone_meta_array findIf { ([_x select 1] call fnc_zone_key) isEqualTo _b };
        if (_i < 0) exitWith { format ["Recruit: zone %1 is gone.", _b] remoteExec ["hint", _caller] };
        private _id = ["recruit", _a, (zone_meta_array select _i) select 1, _b] call fnc_opcom_debug_task;
        (if (_id < 0) then { format ["Recruit refused: %1 (wallet / tier / unresolved force). See the log.", _a] } else { format ["Recruited %1 at %2 -> tasking id %3.", _a, _b, _id] }) remoteExec ["hint", _caller];
    };
    case "task": {
        private _ok = ["task", _a, _b, _c] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Tasking %1 -> %2.", _a, _b] } else { format ["Task refused for %1 (mid-ferry carry / bad target). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "garrison": {
        private _ok = ["garrison", _a, _b] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Tasking %1 garrisons %2.", _a, _b] } else { format ["Garrison refused for %1 (mid-ferry carry / landlocked boat / gone). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "supply": {
        // _b = drop point, or [] for a town errand, which drives to the town centre.
        private _pos = _b;
        if (_pos isEqualTo []) then { _pos = getPos ((missionNamespace getVariable ["civ_locations", []]) select (_c select 1)) };
        private _ok = ["supply", _a, _pos, _c] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Tasking %1 runs %2 to %3.", _a, _c select 0, _pos apply { round _x }] } else { format ["Errand refused for %1 (not a supply unit / mid-ferry carry / bad target). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "fire": {
        private _n = ["fire", _a, _b, _c] call fnc_opcom_debug_task;
        (if (_n > 0) then { format ["%1 fires %2 rounds at %3.", _a, _n, _b apply { round _x }] } else { format ["%1 has no gun bearing on that. See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "intercept": {
        private _ok = ["intercept", _a, _b] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Tasking %1 intercepts %2.", _a, _b] } else { format ["Intercept refused for %1 (mid-ferry carry / row gone). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "zone": {
        private _ok = ["zone", _a, _b, _c] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Zone %1: %2 %3 done. See the log.", _b, _a, _c] } else { format ["Zone %1: %2 refused. See the log.", _b, _a] }) remoteExec ["hint", _caller];
    };
    case "teleport": {
        private _ok = ["teleport", _a, _b] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Teleported %1 -> %2.", _a, _b apply { round _x }] } else { format ["Teleport refused for %1 (gone / mid-ferry). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "list": {
        if (DUWS_opcom_taskings isEqualTo []) exitWith { "No taskings." remoteExec ["hint", _caller] };
        private _lines = DUWS_opcom_taskings apply {
            format ["id %1  %2/%3  eff %4/%5  leg %6/%7  %8", _x get "id", _x get "order", _x get "status", round (_x get "effForce"), round (_x get "fullForce"), _x get "leg", count (_x get "route"), _x get "moveType"]
        };
        { diag_log format ["[OPCOMDBG] %1", _x] } forEach _lines;
        (_lines joinString "\n") remoteExec ["hint", _caller];
    };
    case "unitstatus": {
        // Nearest tasking to the map click: a de-virtualised one sits at its live leader, a still-virtual one
        // at its grid-tracked point. _a carries the clicked [x,y,z].
        if (DUWS_opcom_taskings isEqualTo []) exitWith { "No taskings." remoteExec ["hint", _caller] };
        private _click = _a;
        private _bestT = DUWS_opcom_taskings select 0;
        private _bd = 1e12;
        {
            private _p = _x get "pos";
            if ((_x get "grp") isNotEqualTo "") then {
                private _g = groupFromNetId (_x get "grp");
                if (!isNull _g && {!isNull (leader _g)}) then { _p = getPosATL (leader _g) };
            };
            private _d = _click distance2D _p;
            if (_d < _bd) then { _bd = _d; _bestT = _x };
        } forEach DUWS_opcom_taskings;
        private _flags = _bestT get "flags";
        private _tgt = _bestT get "target";
        private _men = "-";
        if ((_bestT get "grp") isNotEqualTo "") then {
            private _g = groupFromNetId (_bestT get "grp");
            if (!isNull _g) then { _men = { alive _x } count (units _g) };
        };
        private _lines = [
            format ["id %1  (%2 m away, %3)", _bestT get "id", round _bd, ["virtual", "live"] select ((_bestT get "grp") isNotEqualTo "")],
            format ["type: %1  [%2]  move %3  hull %4", _bestT get "menu", (_bestT get "comp") joinString "+", _bestT get "moveType", _bestT getOrDefault ["spawnClass", "-"]],
            format ["strength: eff %1/%2  men %3", round (_bestT get "effForce"), round (_bestT get "fullForce"), _men],
            format ["flags: %1", [_flags joinString ", ", "none"] select (_flags isEqualTo [])],
            format ["tasking: %1/%2  target %3  leg %4/%5", _bestT get "order", _bestT get "status", [str (_tgt apply { round _x }), "none"] select (_tgt isEqualTo []), _bestT get "leg", count (_bestT get "route")]
        ];
        (_lines joinString "\n") remoteExec ["hint", _caller];
    };
    case "ferry": {
        // The ferry fields "list" omits: live carry bindings and the free-lift pools. No excluded id, so the land
        // pool is the exact set a debug Move's taxiBind picks from.
        if (DUWS_opcom_taskings isEqualTo []) exitWith { "No taskings." remoteExec ["hint", _caller] };
        private _carries = DUWS_opcom_taskings select { (_x getOrDefault ["carrying", -1]) >= 0 || {(_x getOrDefault ["ridingOn", -1]) >= 0} };
        private _lines = [];
        if (_carries isEqualTo []) then {
            _lines pushBack "No active carry.";
        } else {
            {
                _lines pushBack format ["id %1  %2  carrying=%3 ridingOn=%4 embarked=%5  leg %6/%7",
                    _x get "id", _x get "moveType", _x getOrDefault ["carrying", -1], _x getOrDefault ["ridingOn", -1], _x getOrDefault ["embarked", false], _x get "leg", count (_x get "route")];
            } forEach _carries;
        };
        _lines pushBack format ["Water lift pool: %1", ([] call DUWS_fnc_opcom_ferryPool) apply { format ["%1(%2)", _x get "id", _x get "moveType"] }];
        _lines pushBack format ["Land lift pool: %1", ([] call DUWS_fnc_opcom_taxiPool) apply { format ["%1(%2)", _x get "id", _x get "moveType"] }];
        { diag_log format ["[OPCOMDBG] ferry: %1", _x] } forEach _lines;
        (_lines joinString "\n") remoteExec ["hint", _caller];
    };
    case "clear": {
        ["clear"] call fnc_opcom_debug_task;
        "OPCOM store cleared." remoteExec ["hint", _caller];
    };
    case "aimode": {
        DUWS_opcom_aiMode = _a;
        ["INFO", "OPCOM", format ["AI mode -> %1", _a]] call fnc_log;
        format ["OPCOM AI: mode %1.", _a] remoteExec ["hint", _caller];
    };
    case "griddrift": {
        DUWS_opcom_gridDriftAsk = _caller;
        "OPCOM grid: drift check runs on the next tick." remoteExec ["hint", _caller];
    };
    case "pickonce": {
        DUWS_opcom_pickOnce = _a;
        format ["OPCOM AI: one %1 pick on the next tick.", _a] remoteExec ["hint", _caller];
    };
    case "difficulty": {
        private _steps = [0.25, 0.5, 1, 2];
        DUWS_opcom_picksPerTick = _steps select (((_steps find DUWS_opcom_picksPerTick) + 1) mod count _steps);
        ["INFO", "OPCOM", format ["AI difficulty -> %1 picks per tick", DUWS_opcom_picksPerTick]] call fnc_log;
        format ["OPCOM AI: %1 picks per tick.", DUWS_opcom_picksPerTick] remoteExec ["hint", _caller];
    };
    default {};
};
