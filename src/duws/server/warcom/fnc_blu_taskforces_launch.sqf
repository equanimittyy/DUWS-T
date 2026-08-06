// fnc_blu_taskforces_launch.sqf
if (!isServer) exitWith {};

private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
if (count _standby == 0) exitWith {
    ["info", [localize "STR_DUWS_T_no_standby_tf", localize "STR_DUWS_T_no_standby_tf_desc"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_taskforces_launchrqst"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_taskforces_launched"] remoteExec ["fnc_duws_dialogue", 0];
{
    if (!isNull _x) then {
        while {count (waypoints _x) > 0} do {
            deleteWaypoint ((waypoints _x) select 0);
        };
        [_x] spawn fnc_WARCOM_wp_blu_assault;
        // GPS marker already runs from standby and retargets itself; do not respawn it here.
    };
} forEach _standby;

missionNamespace setVariable ["blu_taskforces_standby", [], true];


["info", [localize "STR_DUWS_T_taskforces_launched_title", localize "STR_DUWS_T_taskforces_launched_desc"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];