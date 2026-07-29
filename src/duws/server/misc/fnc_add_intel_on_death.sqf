if (!isServer) exitWith {};
params ["_unit"];
_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _netId = netId _unit;
    // Keyed to the corpse, not a bare true: the entry then dies with the body, and
    // missions/fnc_missionTimer.sqf already clears allDeadMen on every mission-slot release.
    // A bare true queued one call per corpse the campaign ever produced, for the whole session.
    [_netId] remoteExec ["fnc_corpse_search_action", 0, _unit];
}];