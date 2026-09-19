// Locality: server -- client/debug/fnc_debug_hardpoint_menu.sqf remoteExecs it to target 2.

// Clears every dev-spawned hardpoint. Per key: delete the men the site holds -- they are not
// composition members, so the key cannot reach them -- then retire the site so the poller stops
// asking about it, release the composition to the map sweep, and drop its peak. Finally the dev rows
// leave the broadcast registry. Retire is safe here where the zone poller cannot call it: this runs
// outside the pass, remoteExec'd from the debug menu.
if (!isServer) exitWith {};

private _keys = missionNamespace getVariable ["DUWS_hpdevKeys", []];
{
    private _k = _x;
    { deleteVehicle _x } forEach (([_k] call fnc_site_roster) select { !isNull _x });
    [_k] call fnc_site_retire;
    [_k] call fnc_duws_release;
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _k], nil];
    missionNamespace setVariable [format ["DUWS_hpMines_%1", _k], nil];
} forEach _keys;

// Drop the dev rows only, leaving any zone- or OPCOM-placed hardpoint in the registry untouched.
DUWS_hardpoints = DUWS_hardpoints select { !((_x select 0) in _keys) };
publicVariable "DUWS_hardpoints";
call DUWS_fnc_opcom_gridDirtyAll;

DUWS_hpdevKeys = [];
["INFO", "HARDPOINT", "dev clear: retired and released every dev hardpoint"] call fnc_log;
