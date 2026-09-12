// Locality: client -- remoteExec'd back to the caller by fnc_debug_opcom with a freshly-read list. Opens the
// row picker; a pick runs the mode's next step (recruit chains row then OPFOR zone, task chains order then a
// map-picked target cell, re-garrison chains tasking then OPFOR zone, supply and teleport chain tasking then a
// map-picked point). State that outlives the click is threaded
// through args, never an enclosing local -- SQF blocks are not closures (docs/info/architecture/arma_engine_gotchas.md).
if (!hasInterface) exitWith {};
params ["_title", "_rows", "_mode", ["_ctx", ""]];
if (_rows isEqualTo []) exitWith {};

private _c = [1, 0.667, 0, 1];
private _entries = _rows apply {
    _x params ["_key", "_label"];
    [_label, {
        params ["_key", "_mode", "_ctx"];
        switch (_mode) do {
            case "recruit": { ["zonelist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "recruit_zone": { ["recruit", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "regarrison": { ["zonelist", _key, "regarrison_zone", "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "regarrison_zone": { ["regarrison", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "supply": {
                [_key] spawn {
                    params ["_id"];
                    private _pos = [format ["<t size='2' color='#00ffff'>Click the supply drop for tasking %1.</t><br/>Close the map to cancel.", _id]] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    ["supply", _id, _pos, "", player] remoteExec ["fnc_debug_opcom", 2];
                };
            };
            case "teleport": {
                [_key] spawn {
                    params ["_id"];
                    private _pos = [format ["<t size='2' color='#00ffff'>Click where to teleport tasking %1.</t><br/>Close the map to cancel.", _id]] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    ["teleport", _id, _pos, "", player] remoteExec ["fnc_debug_opcom", 2];
                };
            };
            case "task": {
                private _oc = [1, 0.667, 0, 1];
                private _orders = ["assault", "move", "guard"] apply {
                    [_x, {
                        params ["_id", "_o"];
                        if (_o isEqualTo "guard") exitWith { ["task", _id, "guard", [], player] remoteExec ["fnc_debug_opcom", 2] };
                        [_id, _o] spawn {
                            params ["_id", "_o"];
                            private _pos = [format ["<t size='2' color='#00ffff'>Click the %1 target for tasking %2.</t><br/>Close the map to cancel.", _o, _id]] call fnc_map_pick_pos;
                            if (_pos isEqualTo []) exitWith {};
                            ["task", _id, _o, _pos, player] remoteExec ["fnc_debug_opcom", 2];
                        };
                    }, [_key, _x], _oc]
                };
                [format ["Tasking %1: order", _key], _orders] call fnc_open_action_menu;
            };
            default {};
        };
    }, [_key, _mode, _ctx], _c]
};
["OPCOM: " + _title, _entries] call fnc_open_action_menu;
