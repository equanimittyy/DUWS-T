// Locality: server -- callers remoteExec to target 2.

// Same cover as the deploy, in the other direction: the crate and the net vanishing out from under
// someone standing there reads exactly as badly as them appearing. Guarded rather than called
// straight, because the branch below tolerates this function running on a client, where the
// server-only fade helper does not exist.
private _fadePlayers = [];
if (isServer) then { _fadePlayers = ["OUT", getPos MHQ1] call fnc_baseFade };

{
    deleteVehicle _x;
} forEach crew MHQ1;

deleteVehicle MHQ_tent;
deleteVehicle MHQ_ammobox;

if (isServer) then { ["IN", _fadePlayers] call fnc_baseFade };

_markerType = "b_motor_inf";
if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,false];
sleep 0.2;
[MHQ1, _markerType, "ColorBlue", 1, 1, localize "STR_DUWS_T_9ziy0qai"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,"duws_mhq_marker"];

if (isServer) then {
    if (!isNil "MHQ_respawn") then {
        MHQ_respawn call BIS_fnc_removeRespawnPosition;
        ["INFO", "SUPPORT", format ["Respawn position %1 removed", MHQ_respawn]] call fnc_log;
        MHQ_respawn = nil;
        publicVariable "MHQ_respawn";
    };
    // Force clients to refresh their respawn-point list
    [] remoteExec ["BIS_fnc_forceRespawn", 0];
} else {
    // Client mis-call: bounce it to the server (failsafe)
    [] remoteExec ["fnc_MHQ_undeploy", 2];
};

MHQ_deployed = false;
publicVariable "MHQ_deployed";

["INFO", "SUPPORT", "MHQ undeployed"] call fnc_log;

MHQ1 setVehicleLock "UNLOCKED";

["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,"duws_mhq_actions"];