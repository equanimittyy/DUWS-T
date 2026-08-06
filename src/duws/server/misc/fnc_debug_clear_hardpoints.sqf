// Locality: server -- client/dialog/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Clears every dev-spawned hardpoint. Per key: delete the men the site holds -- they are not
// composition members, so the key cannot reach them -- then retire the site so the poller stops
// asking about it, and release the composition to the map sweep.
if (!isServer) exitWith {};

{
    private _k = _x;
    { deleteVehicle _x } forEach (([_k] call fnc_site_roster) select { !isNull _x });
    [_k] call fnc_site_retire;
    [_k] call fnc_duws_release;
} forEach (missionNamespace getVariable ["DUWS_hpdevKeys", []]);
DUWS_hpdevKeys = [];
["INFO", "HARDPOINT", "dev clear: retired and released every dev hardpoint"] call fnc_log;
