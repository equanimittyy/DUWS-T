// Locality: server -- remoteExec'd to 2 by the OPCOM debug menu. Every Phase 3 hand-drive verb in one entry:
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
            [_x, format ["%1  (force %2, %3 AP)", _x, _force, ceil (_force * OPCOM_AP_PER_FORCE)]]
        };
        ["Recruit a unit", _rows, "recruit", ""] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "zonelist": {
        // OPCOM recruits and re-garrisons only into an OPFOR-owned zone -- every zone BLUFOR has not captured.
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
        private _title = ["Re-garrison to which zone?", "Recruit at which zone?"] select (_next isEqualTo "recruit_zone");
        [_title, _rows, _next, _a] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "tasklist": {
        // _a names the picker mode (default "task"); re-garrison passes "regarrison" (routes to a zone pick) and
        // supply passes "supply" (routes to a drop map-pick), reusing the one tasking list for all three.
        private _mode = ["task", _a] select (_a isNotEqualTo "");
        // Live taskings included: fnc_opcom_task re-orders a de-virtualised group in place (reOrderLive), the
        // same primitive OPCOM's loop drives -- only a bound ferry carry is refused, and by the primitive.
        private _rows = DUWS_opcom_taskings apply {
            [_x get "id", format ["id %1  %2/%3  %4  (%5)", _x get "id", _x get "order", _x get "status", _x get "moveType", ["virtual", "live"] select ((_x get "grp") isNotEqualTo "")]]
        };
        if (_rows isEqualTo []) exitWith { "No taskings (recruit one first)." remoteExec ["hint", _caller] };
        private _title = switch (_mode) do {
            case "supply": { "Supply-run which tasking?" };
            case "regarrison": { "Re-garrison which tasking?" };
            default { "Task a tasking" };
        };
        [_title, _rows, _mode, ""] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "teleportlist": {
        // Every tasking, live included; a teleport also snaps the live group's hulls, not just the stored point.
        if (DUWS_opcom_taskings isEqualTo []) exitWith { "No taskings." remoteExec ["hint", _caller] };
        private _rows = DUWS_opcom_taskings apply {
            [_x get "id", format ["id %1  %2/%3  %4  (%5)", _x get "id", _x get "order", _x get "status", _x get "moveType", ["virtual", "live"] select ((_x get "grp") isNotEqualTo "")]]
        };
        ["Teleport which tasking?", _rows, "teleport", ""] remoteExec ["fnc_debug_opcom_pick", _caller];
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
    case "regarrison": {
        private _ok = ["regarrison", _a, _b] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Re-garrison %1 -> %2.", _a, _b] } else { format ["Re-garrison refused for %1 (mid-ferry carry / landlocked boat / gone). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "supply": {
        private _ok = ["supply", _a, _b] call fnc_opcom_debug_task;
        (if (_ok) then { format ["Supply-run %1 -> %2.", _a, _b apply { round _x }] } else { format ["Supply-run refused for %1 (mid-ferry carry / bad target). See the log.", _a] }) remoteExec ["hint", _caller];
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
        // The ferry fields "list" omits: live carry bindings and the free-lift pool. No excluded id, so the
        // pool is the exact set borrowFerry would pick from.
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
        _lines pushBack format ["Free lift pool: %1", ([] call DUWS_fnc_opcom_ferryPool) apply { format ["%1(%2)", _x get "id", _x get "moveType"] }];
        { diag_log format ["[OPCOMDBG] ferry: %1", _x] } forEach _lines;
        (_lines joinString "\n") remoteExec ["hint", _caller];
    };
    case "clear": {
        ["clear"] call fnc_opcom_debug_task;
        "OPCOM store cleared." remoteExec ["hint", _caller];
    };
    default {};
};
