// Locality: server. The Phase 3 hand-drive harness: spawn a unit, order it, watch it -- the manual stand-in
// for the decision loop until Phase 4 automates the calls. Run on the server (directly in the server console,
// or remoteExec'd to 2). Every verb logs to the RPT under "OPCOMDBG" so a play-test leaves a trace.
//   ["menu"]                              -- list the recruit rows and their live prices
//   ["recruit", row, pos, zoneKey]        -- hire a row at a world pos; returns the tasking id (or -1)
//   ["task", id, order, targetPos]        -- give tasking `id` an active order to a target
//   ["list"]                              -- dump every live tasking's state
//   ["clear"]                             -- re-virtualise and delete every tasking, empty the store
// Example: private _id = ["recruit", "rifles", getPosASL player] call fnc_opcom_debug_task;
//          [_id, "assault", getPosASL player] call fnc_opcom_debug_task;
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
            [DUWS_opcom_taskings select _i, _b, _c] call fnc_opcom_task
        };
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
