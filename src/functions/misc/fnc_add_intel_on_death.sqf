if (!isServer) exitWith {};
params ["_unit"];
_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _netId = netId _unit;
    [_netId] remoteExec ["fnc_corpse_search_action", 0, true];
}];