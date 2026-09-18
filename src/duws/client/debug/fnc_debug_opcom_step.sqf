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
    // Everything orderable shares one list, so the order it offers is chosen here. A string key is an emplacement,
    // whose only order is the fire mission; a number is a tasking.
    case "order": {
        if (_key isEqualType "") exitWith { [_key, "firemission"] call fnc_debug_opcom_step };
        // An errand is an order in its own right here: the move that carries it is implied, not picked first.
        [format ["Tasking %1: order", _key], [
            ["capture", "capture"], ["move", "move"], ["guard", "guard"], ["garrison", "garrison"],
            ["reinforce a town", "reinforce"], ["fortify a town", "fortify"], ["rapport a town", "rapport"],
            ["build a hardpoint", "build"], ["intercept", "intercept"], ["teleport", "teleport"]
        ] apply {
            _x params ["_label", "_next"];
            [_label, { params ["_id", "_n"]; [_id, _n] call fnc_debug_opcom_step }, [_key, _next], _c]
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
    case "garrison": { ["garrisonlist", _key, "", "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "garrison_site": { ["garrison", _ctx, _key, "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "reinforce";
    case "fortify";
    case "rapport": { ["townlist", _key, _mode, "", player] remoteExec ["fnc_debug_opcom", 2] };
    case "build": {
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
        [format ["%1: fire in which shape?", _key], [["saturate a point", "fire_saturate"], ["creeping barrage", "fire_creep"]] apply {
            _x params ["_label", "_next"];
            [_label, { params ["_hp", "_n"]; [_hp, _n] call fnc_debug_opcom_step }, [_key, _next], _c]
        }] call fnc_open_action_menu;
    };
    case "fire_saturate": {
        [format ["%1: saturate how wide?", _key], [50, 100, 150, 250] apply {
            [format ["%1 m radius", _x], { params ["_hp", "_r"]; [_hp, "fire_rounds", ["saturate", _r]] call fnc_debug_opcom_step }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    case "fire_creep": {
        [format ["%1: creep how wide?", _key], [50, 100, 200, 300] apply {
            [format ["%1 m wide", _x], { params ["_hp", "_w"]; [_hp, "fire_rounds", ["creep", _w]] call fnc_debug_opcom_step }, [_key, _x], _c]
        }] call fnc_open_action_menu;
    };
    case "fire_rounds": {
        [format ["%1: how many rounds a gun?", _key], [2, 4, 6, 8] apply {
            [str _x, {
                params ["_hp", "_shape", "_rounds"];
                [_hp, _shape, _rounds] spawn {
                    params ["_hp", "_shape", "_rounds"];
                    private _creep = (_shape select 0) isEqualTo "creep";
                    private _pos = [format ["<t size='2' color='#00ffff'>Click the %1 for %2 (%3 rounds a gun).</t><br/>Close the map to cancel.",
                        ["target", "creep's start"] select _creep, _hp, _rounds], {true}, "", _creep] call fnc_map_pick_pos;
                    if (_pos isEqualTo []) exitWith {};
                    if (_creep) then {
                        private _end = [format ["<t size='2' color='#00ffff'>Click where %1's creep ends.</t><br/>Close the map to cancel.", _hp]] call fnc_map_pick_pos;
                        _shape = if (_end isEqualTo []) then { [] } else { _shape + [_pos distance2D _end, _pos getDir _end] };
                    };
                    if (_shape isEqualTo []) exitWith {};
                    ["fire", _hp, _pos, [_rounds, _shape], player] remoteExec ["fnc_debug_opcom", 2];
                };
            }, [_key, _ctx, _x], _c]
        }] call fnc_open_action_menu;
    };
    default {};
};
