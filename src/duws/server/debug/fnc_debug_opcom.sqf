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
        // OPCOM recruits only into an OPFOR-owned zone -- every zone BLUFOR has not captured. _a carries the
        // chosen recruit row through to the recruit verb.
        private _rows = (zone_meta_array select {
            private _zp = _x select 1;
            (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _zp) < 1 }) < 0
        }) apply {
            private _zp = _x select 1;
            [[_zp] call fnc_zone_key, format ["%1  (%2)", [_zp] call fnc_zone_key, _zp apply { round _x }]]
        };
        if (_rows isEqualTo []) exitWith { "No OPFOR-owned zone to recruit at (BLUFOR holds them all)." remoteExec ["hint", _caller] };
        ["Recruit at which zone?", _rows, "recruit_zone", _a] remoteExec ["fnc_debug_opcom_pick", _caller];
    };
    case "tasklist": {
        private _rows = (DUWS_opcom_taskings select { (_x get "grp") isEqualTo "" }) apply {
            [_x get "id", format ["id %1  %2/%3  %4", _x get "id", _x get "order", _x get "status", _x get "moveType"]]
        };
        if (_rows isEqualTo []) exitWith { "No virtual taskings to order (recruit one; a live unit cannot be re-tasked)." remoteExec ["hint", _caller] };
        ["Task a tasking", _rows, "task", ""] remoteExec ["fnc_debug_opcom_pick", _caller];
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
        (if (_ok) then { format ["Tasking %1 -> %2.", _a, _b] } else { format ["Task refused for %1 (held / live / bad target). See the log.", _a] }) remoteExec ["hint", _caller];
    };
    case "list": {
        if (DUWS_opcom_taskings isEqualTo []) exitWith { "No taskings." remoteExec ["hint", _caller] };
        private _lines = DUWS_opcom_taskings apply {
            format ["id %1  %2/%3  eff %4/%5  leg %6/%7  %8", _x get "id", _x get "order", _x get "status", round (_x get "effForce"), round (_x get "fullForce"), _x get "leg", count (_x get "route"), _x get "moveType"]
        };
        { diag_log format ["[OPCOMDBG] %1", _x] } forEach _lines;
        (_lines joinString "\n") remoteExec ["hint", _caller];
    };
    case "clear": {
        ["clear"] call fnc_opcom_debug_task;
        "OPCOM store cleared." remoteExec ["hint", _caller];
    };
    default {};
};
