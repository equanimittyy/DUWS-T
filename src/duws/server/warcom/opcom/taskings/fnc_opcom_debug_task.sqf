// Locality: server. Hand-drive harness: recruit, order and inspect taskings from the server console (the
// manual stand-in for the decision loop). Logs every verb under "OPCOMDBG". The order verbs zero the commit hold
// first, so hand-driving re-tasks on demand where the automated loop would wait it out.
//   ["menu"]                        -- list the recruit rows and their live prices
//   ["recruit", row, pos, zoneKey]  -- hire a row; returns the tasking id (or -1)
//   ["task", id, order, targetPos]  -- give tasking `id` an active order to a target ("move", "patrol", "capture")
//   ["garrison", id, siteKey]       -- return `id` to a zone or town; it settles into that garrison on arrival
//   ["supply", id, targetPos, errand] -- send `id` on a supply run; its errand lands on arrival (fnc_opcom_task)
//   ["zone", "reinforce" | "fortify" | "build", zoneKey, type] -- a zone buy, landed this call (type: build only)
//   ["intercept", id, rowKey]       -- send `id` after a belief row (a BLUFOR group's netId)
//   ["ferry", id]                   -- lift `id`, stopped at a water leg, on the nearest free boat or helicopter
//   ["fire", hpKey, targetPos, [rounds, shape]] -- a fire mission from a mortar pit or battery; returns rounds ordered
//                                   (shape ["saturate", radius] | ["creep", width, length, bearing]; a creep ignores rounds)
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
            ["INFO", "OPCOMDBG", format ["row %1: comp %2 flags %3 force %4 cost %5 AP", _x, _comp, _flags, _force, OPCOM_AP_UNIT getOrDefault [_x, 0]]] call fnc_log;
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
            private _ok = [_t, _b, _c] call fnc_opcom_task;
            // A hand order carries no Value; any positive stand-in has taxiBind pick the hull saving the most time.
            if (_ok && {_b isEqualTo "move"}) then { _t set ["expValue", 1]; [_t] call DUWS_fnc_opcom_taxiBind };
            _ok
        };
    };
    case "garrison": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) then {
            ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false
        } else {
            private _t = DUWS_opcom_taskings select _i;
            private _site = [_b] call fnc_site_at;
            private _pos = _site getOrDefault ["pos", []];
            if (_pos isEqualTo []) then {
                ["WARN", "OPCOMDBG", format ["garrison: no site %1", _b]] call fnc_log; false
            } else {
                _t set ["hold", 0];
                [_t, "return", _pos, _b] call fnc_opcom_task
            };
        };
    };
    case "supply": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) then {
            ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false
        } else {
            private _t = DUWS_opcom_taskings select _i;
            if !(_c isEqualType [] && {_c isNotEqualTo []}) exitWith {
                ["WARN", "OPCOMDBG", format ["supply: tasking %1 needs an errand", _a]] call fnc_log; false
            };
            _t set ["hold", 0];
            [_t, "errand", _b, "", _c] call fnc_opcom_task
        };
    };
    case "intercept": {
        private _i = DUWS_opcom_taskings findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) exitWith { ["WARN", "OPCOMDBG", format ["no tasking id %1", _a]] call fnc_log; false };
        private _t = DUWS_opcom_taskings select _i;
        _t set ["hold", 0];
        [_t, "intercept", _b] call fnc_opcom_task
    };
    case "ferry": {
        private _r = [_a] call DUWS_fnc_opcom_byId;
        if (isNil "_r" || {(_r getOrDefault ["strandTicks", 0]) <= 0}) exitWith {
            ["WARN", "OPCOMDBG", format ["ferry: tasking %1 is not stopped at a water leg", _a]] call fnc_log; false
        };
        // Past the nearest: a boat on another body of water has no route to the rider.
        private _pool = ([_a] call DUWS_fnc_opcom_ferryPool) apply { [(_x get "pos") distance2D (_r get "pos"), _x get "id"] };
        _pool sort true;
        private _ok = (_pool findIf { [[["free", _x select 1], _a]] call DUWS_fnc_opcom_ferryRun }) >= 0;
        if (!_ok) then { ["WARN", "OPCOMDBG", format ["ferry: no free boat or helicopter reaches tasking %1", _a]] call fnc_log };
        _ok
    };
    case "fire": {
        _c params ["_rounds", "_shape"];
        [_a, _b, _rounds, _shape] call DUWS_fnc_opcom_fireMission
    };
    case "zone": {
        if ((([_b] call fnc_site_at) getOrDefault ["pos", []]) isEqualTo []) exitWith {
            ["WARN", "OPCOMDBG", format ["zone: no zone %1", _b]] call fnc_log; false
        };
        switch (_a) do {
            case "reinforce": { ([_b, "opcom_debug"] call fnc_zone_garrison_reinforce) >= 0 };
            case "fortify": { ([_b, "opcom_debug"] call fnc_zone_garrison_fortify) >= 0 };
            case "build": { [_c, _b] call DUWS_fnc_opcom_build };
            default { ["WARN", "OPCOMDBG", format ["zone: unknown buy %1", _a]] call fnc_log; false };
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
            ["INFO", "OPCOMDBG", format ["  id %1 %2 %3/%4 pos %5 eff %6/%7 leg %8/%9 %10",
                _x get "id", toUpper (_x getOrDefault ["menu", [(_x get "comp") param [0, ""]] call DUWS_fnc_tokenName]),
                _x get "order", _x get "status",
                (_x get "pos") apply { round _x },
                round (_x get "effForce"), round (_x get "fullForce"),
                _x get "leg", count (_x get "route"), _x get "moveType"]] call fnc_log;
        } forEach DUWS_opcom_taskings;
        true
    };
    case "clear": {
        { if ((_x get "grp") isNotEqualTo "") then {
            private _grp = groupFromNetId (_x get "grp");
            if (!isNull _grp) then { [_grp] call DUWS_fnc_opcom_despawn };
        } } forEach DUWS_opcom_taskings;
        DUWS_opcom_taskings = [];
        ["INFO", "OPCOMDBG", "store cleared"] call fnc_log;
        true
    };
    default { ["WARN", "OPCOMDBG", format ["unknown verb %1", _verb]] call fnc_log; false };
};
