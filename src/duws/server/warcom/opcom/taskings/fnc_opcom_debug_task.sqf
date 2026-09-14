// Locality: server. Phase 3 hand-drive harness: recruit, order and inspect taskings from the server console (the
// manual stand-in for the decision loop). Logs every verb under "OPCOMDBG". The order verbs zero the commit hold
// first, so hand-driving re-tasks on demand where the automated loop would wait it out.
//   ["menu"]                        -- list the recruit rows and their live prices
//   ["recruit", row, pos, zoneKey]  -- hire a row; returns the tasking id (or -1)
//   ["task", id, order, targetPos]  -- give tasking `id` an active order to a target
//   ["regarrison", id, zoneKey]     -- send `id` to a zone; it settles into that garrison on arrival
//   ["supply", id, targetPos]       -- send `id` on a supply run; deleted and completed on arrival
//   ["teleport", id, pos]           -- snap `id` (stored point + live group) to a pos, then hold on guard there
//   ["list"] / ["clear"]            -- dump every tasking's state / delete all and empty the store
// e.g. ["recruit", "rifles", getPosASL player] call fnc_opcom_debug_task;
params ["_verb", ["_a", ""], ["_b", ""], ["_c", ""]];
if (!isServer) exitWith { ["WARN", "OPCOMDBG", "must run on the server"] call fnc_log; -1 };

switch (_verb) do {
    case "menu": {
        {
            _y params ["_comp", "_flags"];
            private _force = [_comp] call DUWS_fnc_tokenListForce;
            ["INFO", "OPCOMDBG", format ["row %1: comp %2 flags %3 force %4 cost %5 AP", _x, _comp, _flags, _force, ceil (_force * OPCOM_AP_PER_FORCE)]] call fnc_log;
        } forEach DUWS_opcom_recruitMenu;
        true
    };
    case "recruit": {
        private _t = [_a, _b, _c] call fnc_opcom_recruit;
        if (isNil "_t") then { -1 } else { _t get "id" }
    };
    case "task": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) then {
            ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false
        } else {
            private _t = DUWS_opcom_taskings select _i;
            _t set ["hold", 0];
            [_t, _b, _c] call fnc_opcom_task
        };
    };
    case "regarrison": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) then {
            ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false
        } else {
            private _t = DUWS_opcom_taskings select _i;
            private _site = [_b] call fnc_site_at;
            private _pos = _site getOrDefault ["pos", []];
            if (_pos isEqualTo []) then {
                ["WARN", "OPCOMDBG", format ["regarrison: no zone %1", _b]] call fnc_log; false
            } else {
                // A boat cannot rest inland: home it on nearest navigable water, refusing a landlocked zone.
                private _target = _pos;
                private _ok = true;
                if ((_t get "moveType") isEqualTo "boat") then {
                    _target = [_pos] call DUWS_fnc_opcom_nearestWater;
                    if ((_target distance2D _pos) > ((_site getOrDefault ["radius", 0]) + DUWS_streamArrivalMargin)) then {
                        ["WARN", "OPCOMDBG", format ["regarrison: zone %1 is landlocked -- no water to home a boat", _b]] call fnc_log;
                        _ok = false;
                    };
                };
                _t set ["hold", 0];
                if (_ok) then { [_t, "move", _target, _b] call fnc_opcom_task } else { false }
            };
        };
    };
    case "supply": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) then {
            ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false
        } else {
            private _t = DUWS_opcom_taskings select _i;
            _t set ["hold", 0];
            [_t, "move", _b, "", true] call fnc_opcom_task
        };
    };
    case "teleport": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) exitWith { ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false };
        private _t = DUWS_opcom_taskings select _i;
        // A live carry binds transport and rider by position; snapping one half alone strands the pair.
        if ((_t getOrDefault ["carrying", -1]) >= 0 || {(_t getOrDefault ["ridingOn", -1]) >= 0}) exitWith {
            ["WARN", "OPCOMDBG", format ["teleport: tasking %1 is mid-ferry -- release it first", _a]] call fnc_log; false
        };
        private _dest = [_b select 0, _b select 1, getTerrainHeightASL _b];
        _t set ["pos", _dest];
        _t set ["route", []];   // stale from the old pos
        private _grp = groupFromNetId (_t get "grp");   // grpNull when virtual, so the live snap is skipped
        if (!isNull _grp) then {
            private _hulls = [];
            { private _v = vehicle _x; if (_v != _x && {!(_v in _hulls)}) then { _hulls pushBack _v } } forEach units _grp;
            { _x setPos [_b select 0, _b select 1, (getPosATL _x) select 2] } forEach _hulls;   // keep altitude: a grounded air hull explodes
            { if (vehicle _x == _x) then { _x setPos [(_b select 0) + (random 8 - 4), (_b select 1) + (random 8 - 4), 0] } } forEach units _grp;
        };
        // The stale order/target would re-route it back; re-hold on guard (hold zeroed, as the other verbs do).
        _t set ["hold", 0];
        [_t, "guard"] call fnc_opcom_task;
        ["INFO", "OPCOMDBG", format ["teleported tasking %1 to %2, holding on guard", _a, _dest apply { round _x }]] call fnc_log;
        true
    };
    case "list": {
        ["INFO", "OPCOMDBG", format ["%1 tasking(s):", count DUWS_opcom_taskings]] call fnc_log;
        {
            ["INFO", "OPCOMDBG", format ["  id %1 %2/%3 pos %4 eff %5/%6 leg %7/%8 %9",
                _x get "id", _x get "order", _x get "status",
                (_x get "pos") apply { round _x },
                round (_x get "effForce"), round (_x get "fullForce"),
                _x get "leg", count (_x get "route"), _x get "moveType"]] call fnc_log;
        } forEach DUWS_opcom_taskings;
        true
    };
    case "clear": {
        { if ((_x get "grp") isNotEqualTo "") then {
            private _grp = groupFromNetId (_x get "grp");
            if (!isNull _grp) then { { deleteVehicle _x } forEach units _grp; deleteGroup _grp };
        } } forEach DUWS_opcom_taskings;
        DUWS_opcom_taskings = [];
        ["INFO", "OPCOMDBG", "store cleared"] call fnc_log;
        true
    };
    default { ["WARN", "OPCOMDBG", format ["unknown verb %1", _verb]] call fnc_log; false };
};
