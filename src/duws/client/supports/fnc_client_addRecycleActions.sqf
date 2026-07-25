// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
if (!hasInterface) exitWith {};
params ["_depot", "_trgNetId"];
if (isNull _depot) exitWith {};

if (_depot getVariable ["recycle_actions_done", false]) exitWith {};
_depot setVariable ["recycle_actions_done", true, true];

private _trg = objectFromNetId _trgNetId;
if (isNull _trg) exitWith { diag_log "[RECYCLE] Trigger null on client"; };

_depot addAction [
    localize "STR_DUWS_T_VEHICLE_RECYCLING",
    {
        params ["_t", "_c", "_i", "_trg"];
        [localize "STR_DUWS_T_VEHICLE_RECYCLING", [
            [localize "STR_DUWS_T_huishouzaijv",          { params ["_trg"]; [player, _trg] remoteExec ["fnc_veh_recycle_action", 2]; }, [_trg]],
            [localize "STR_DUWS_T_PREVIEW_RECYCLE_VALUE", { params ["_trg"]; [player, _trg] remoteExec ["fnc_veh_recycle_preview_server", 2]; }, [_trg]]
        ]] call fnc_open_action_menu;
    },
    _trg,
    70,
    true,
    true,
    "",
    "_this distance _target < 8"   // 限制 8 米内可见
];
