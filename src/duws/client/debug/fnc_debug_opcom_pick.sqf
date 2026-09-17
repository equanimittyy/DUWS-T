// Locality: client -- remoteExec'd back to the caller by fnc_debug_opcom with a freshly-read list. Opens the
// row picker; a pick runs the mode's next step. State that outlives the click is threaded through args, never an
// enclosing local -- SQF blocks are not closures (docs/info/architecture/arma_engine_gotchas.md).
if (!hasInterface) exitWith {};
params ["_title", "_rows", "_mode", ["_ctx", ""]];
if (_rows isEqualTo []) exitWith {};

private _c = [1, 0.667, 0, 1];
private _hpTypes = ["MG", "GMG", "AT", "AA", "ROADBLOCK", "OP", "MORTAR", "ARTY", "RADIO", "MINEFIELD"];
private _entries = _rows apply {
    _x params ["_key", "_label"];
    [_label, {
        params ["_key", "_mode", "_ctx", "_hpTypes"];
        private _oc = [1, 0.667, 0, 1];
        switch (_mode) do {
            case "recruit": { ["zonelist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "recruit_zone": { ["recruit", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "regarrison": { ["zonelist", _key, "regarrison_zone", "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "regarrison_zone": { ["regarrison", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "supply": {
                private _errands = ["reinforce", "fortify", "rapport"] apply {
                    [format ["%1 a town", _x], { params ["_id", "_kind"]; ["townlist", _id, _kind, "", player] remoteExec ["fnc_debug_opcom", 2] }, [_key, _x], _oc]
                };
                _errands pushBack ["build a hardpoint", {
                    params ["_id", "_hpTypes", "_oc"];
                    [format ["Tasking %1: build which type?", _id], _hpTypes apply {
                        [_x, {
                            params ["_id", "_type"];
                            [_id, _type] spawn {
                                params ["_id", "_type"];
                                private _pos = [format ["<t size='2' color='#00ffff'>Click where tasking %1 builds a %2.</t><br/>Close the map to cancel.", _id, _type]] call fnc_map_pick_pos;
                                if (_pos isEqualTo []) exitWith {};
                                ["supply", _id, _pos, ["build", _pos, _type], player] remoteExec ["fnc_debug_opcom", 2];
                            };
                        }, [_id, _x], _oc]
                    }] call fnc_open_action_menu;
                }, [_key, _hpTypes, _oc], _oc];
                [format ["Tasking %1: errand", _key], _errands] call fnc_open_action_menu;
            };
            case "supply_town": { ["supply", _ctx select 0, [], [_ctx select 1, _key], player] remoteExec ["fnc_debug_opcom", 2] };
            case "intercept": { ["sightinglist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "intercept_row": { ["intercept", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
            case "zonebuy": {
                private _buys = ["reinforce", "fortify"] apply {
                    [_x, { params ["_zk", "_kind"]; ["zone", _kind, _zk, "", player] remoteExec ["fnc_debug_opcom", 2] }, [_key, _x], _oc]
                };
                _buys pushBack ["build a hardpoint", {
                    params ["_zk", "_hpTypes", "_oc"];
                    [format ["%1: build which type?", _zk], _hpTypes apply {
                        [_x, { params ["_zk", "_type"]; ["zone", "build", _zk, _type, player] remoteExec ["fnc_debug_opcom", 2] }, [_zk, _x], _oc]
                    }] call fnc_open_action_menu;
                }, [_key, _hpTypes, _oc], _oc];
                [format ["%1: buy", _key], _buys] call fnc_open_action_menu;
            };
            case "teleport": {
                [_key] spawn {
                    params ["_id"];
                    private _pos = [format ["<t size='2' color='#00ffff'>Click where to teleport tasking %1.</t><br/>Close the map to cancel.", _id], {true}, "", true] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    ["teleport", _id, _pos, "", player] remoteExec ["fnc_debug_opcom", 2];
                };
            };
            case "task": {
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
    }, [_key, _mode, _ctx, _hpTypes], _c]
};
["OPCOM: " + _title, _entries] call fnc_open_action_menu;
