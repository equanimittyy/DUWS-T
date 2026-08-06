// Pylon loadout purchase and its two client-side hints.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

fnc_pylon_set_with_cost = {
    if (!isServer) exitWith {};
    params ["_netId", "_pylonIndex", "_magazine", ["_turret", []], "_requestingPlayerUID"];

    // Escalation applied here: this path never reaches the purchase handshake.
    private _cost = [5] call fnc_escalation_cost;

    private _player = objNull;
    { if (getPlayerUID _x == _requestingPlayerUID) exitWith { _player = _x } } forEach allPlayers;
    if (isNull _player) exitWith { ["ERROR", "BOOT", "fnc_pylon_set_with_cost: player not found"] call fnc_log;};

    if (commandpointsblu1 < _cost) exitWith {
        [_cost] remoteExec ["fnc_pylon_hint_nocp", _player];
    };

    // call, not remoteExec to self: a queued debit runs a frame later, leaving the check
    // above and the deduction split across frames for a second request to slip between.
    [-_cost, "pylon_purchase"] call fnc_cp_adjust;

    private _veh = objectFromNetId _netId;
    if (isNull _veh) exitWith { ["ERROR", "BOOT", "fnc_pylon_set_with_cost: invalid netId"] call fnc_log;};
    _veh setPylonLoadout [_pylonIndex, _magazine, true, _turret];

    [_cost] remoteExec ["fnc_pylon_hint_success", _player];
};

fnc_pylon_hint_nocp = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_NO_CP", _cost];
};

fnc_pylon_hint_success = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_SET_SUCCESS", _cost];
};
