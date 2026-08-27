#include "..\..\shared\includes\action_style.hpp"
// Locality: server -- called from the cache/supply mission threads. Attaches the one-shot "seize"
// arsenal action to a captured crate or truck.
//
// The action is added inside a remoteExec'd closure with the JIP flag set, so it stands up on every
// machine including late joiners -- a client that missed the spawn still sees the action. The
// arsenalUsed flag is the one-shot guard, broadcast so the first taker closes it everywhere at once.
params ["_obj"];

[_obj, {
    private _actionID = _this addAction [
        ACT_EQUIP("STR_DUWS_T_CACHE_SEIZE"),
        {
            params ["_target", "_caller", "_actionId"];
            if (!(_target getVariable ["arsenalUsed", false])) then {
                _target setVariable ["arsenalUsed", true, true];
                _target removeAction _actionId;
                [_target] remoteExec ["fnc_removeArsenalAction", 0];
                ["arsenal", [localize "STR_DUWS_T_CACHE_SEIZED_TITLE", localize "STR_DUWS_T_CACHE_SEIZED_DESC"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
                [] remoteExec ["fnc_captured_pool_cache_deposit", 2];
            };
        },
        [],
        80,
        true,
        true,
        "",
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_obj setVariable ["arsenalUsed", false, true];
