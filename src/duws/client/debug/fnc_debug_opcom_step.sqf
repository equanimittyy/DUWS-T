// Locality: client -- one step of an OPCOM debug chain: [_key, _mode, _ctx] call fnc_debug_opcom_step. Called by the
// rows fnc_debug_opcom_pick opens and by the submenus below, so a chain re-enters here rather than nesting a copy of
// the step it wants. Every server read goes back through fnc_debug_opcom, which owns the store.
//
// State that outlives a click is threaded through args, never an enclosing local -- SQF blocks are not closures
// (docs/info/architecture/arma_engine_gotchas.md).
if (!hasInterface) exitWith {};
params ["_key", "_mode", ["_ctx", ""]];

private _c = [1, 0.667, 0, 1];
private _hpTypes = ["MG", "GMG", "AT", "AA", "ROADBLOCK", "OP", "MORTAR", "ARTY", "RADIO", "MINEFIELD"];

switch (_mode) do {
    // Every order starts from one tasking, so they share its list and branch here.
    case "order": {
        [format ["Tasking %1: order", _key], ["capture", "move", "guard", "regarrison", "supply", "intercept", "teleport"] apply {
            [_x, { params ["_id", "_next"]; [_id, _next] call fnc_debug_opcom_step }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    case "capture";
    case "move": {
        [_key, _mode] spawn {
            params ["_id", "_o"];
            private _pos = [format ["<t size='2' color='#00ffff'>Click the %1 target for tasking %2.</t><br/>Close the map to cancel.", _o, _id]] call fnc_map_pick_pos;
            if (_pos isEqualTo []) exitWith {};
            ["task", _id, _o, _pos, player] remoteExec ["fnc_debug_opcom", 2];
        };
    };
    case "guard": { ["task", _key, "guard", [], player] remoteExec ["fnc_debug_opcom", 2] };
    case "regarrison": { ["zonelist", _key, "regarrison_zone", "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "regarrison_zone": { ["regarrison", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "supply": {
        private _errands = ["reinforce", "fortify", "rapport"] apply {
            [format ["%1 a town", _x], { params ["_id", "_kind"]; ["townlist", _id, _kind, "", player] remoteExec ["fnc_debug_opcom", 2] }, [_key, _x], _c]
        };
        _errands pushBack ["build a hardpoint", { params ["_id"]; [_id, "supply_build"] call fnc_debug_opcom_step }, [_key], _c];
        [format ["Tasking %1: errand", _key], _errands] call fnc_open_action_menu;
    };
    case "supply_build": {
        [format ["Tasking %1: build which type?", _key], _hpTypes apply {
            [_x, {
                params ["_id", "_type"];
                [_id, _type] spawn {
                    params ["_id", "_type"];
                    private _pos = [format ["<t size='2' color='#00ffff'>Click where tasking %1 builds a %2.</t><br/>Close the map to cancel.", _id, _type]] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    ["supply", _id, _pos, ["build", _pos, _type], player] remoteExec ["fnc_debug_opcom", 2];
                };
            }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    case "supply_town": { ["supply", _ctx select 0, [], [_ctx select 1, _key], player] remoteExec ["fnc_debug_opcom", 2] };
    case "intercept": { ["sightinglist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "intercept_row": { ["intercept", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "teleport": {
        [_key] spawn {
            params ["_id"];
            private _pos = [format ["<t size='2' color='#00ffff'>Click where to teleport tasking %1.</t><br/>Close the map to cancel.", _id], {true}, "", true] call fnc_map_pick_pos;
            if (_pos isEqualTo []) exitWith {};
            ["teleport", _id, _pos, "", player] remoteExec ["fnc_debug_opcom", 2];
        };
    };
    case "recruit": { ["zonelist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "recruit_zone": { ["recruit", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "zonebuy": {
        private _buys = ["reinforce", "fortify"] apply {
            [_x, { params ["_zk", "_kind"]; ["zone", _kind, _zk, "", player] remoteExec ["fnc_debug_opcom", 2] }, [_key, _x], _c]
        };
        _buys pushBack ["build a hardpoint", { params ["_zk"]; [_zk, "zone_build"] call fnc_debug_opcom_step }, [_key], _c];
        [format ["%1: defensive tasking", _key], _buys] call fnc_open_action_menu;
    };
    case "zone_build": {
        [format ["%1: build which type?", _key], _hpTypes apply {
            [_x, { params ["_zk", "_type"]; ["zone", "build", _zk, _type, player] remoteExec ["fnc_debug_opcom", 2] }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    case "firemission": {
        [format ["%1: how many rounds a gun?", _key], [2, 4, 6, 8] apply {
            [str _x, {
                params ["_hp", "_rounds"];
                [_hp, _rounds] spawn {
                    params ["_hp", "_rounds"];
                    private _pos = [format ["<t size='2' color='#00ffff'>Click the target for %1 (%2 rounds a gun).</t><br/>Close the map to cancel.", _hp, _rounds]] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    ["fire", _hp, _pos, _rounds, player] remoteExec ["fnc_debug_opcom", 2];
                };
            }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    default {};
};
