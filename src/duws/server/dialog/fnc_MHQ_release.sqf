// Locality: server -- callers remoteExec to target 2.
//
// Releasing is not undeploying. Undeploy packs the crate, the net and the respawn point so the
// vehicle can be driven somewhere else and set up again: that is how the MHQ moves, it is the
// common action, and it has to stay cheap. This ends the designation instead -- the vehicle goes
// back to being an ordinary truck and a different one can be chosen. Conflating the two would
// charge a re-designation for every reposition.
if (!isServer) exitWith {};

if (isNil "MHQ1") exitWith {};

// The deployed state owns a respawn point, a crate and a net. The action is only offered while
// undeployed, so reaching here deployed means something else called this.
if (missionNamespace getVariable ["MHQ_deployed", false]) exitWith {
	["WARN", "SUPPORT", "fnc_MHQ_release: refused, MHQ is still deployed"] call fnc_log;
};

private _veh = MHQ1;

// Bumped before the variable is cleared, so fnc_MHQ_destroyed stands down rather than tearing down
// a designation that has already ended -- or surviving to see the next one.
MHQ_generation = (missionNamespace getVariable ["MHQ_generation", 0]) + 1;

removeAllActions _veh;
_veh forceFlagTexture "";
_veh setVehicleVarName "";
[_veh] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated, false];
// The ring's own follower thread only ends when the vehicle dies, and this one is still alive.
deleteMarker "base_range_mhq";

MHQ1 = nil;
publicVariable "MHQ1";
// The deploy and undeploy entries are JIP-flagged under this id, so without clearing it a joining
// client is handed an action against a vehicle that stopped being the MHQ before they arrived.
remoteExec ["", "duws_mhq_actions"];
// The map icon is JIP-flagged the same way; drop it too, or a late joiner marks a truck that is no longer the MHQ.
remoteExec ["", "duws_mhq_marker"];

["INFO", "SUPPORT", "MHQ released"] call fnc_log;
["info", [localize "STR_DUWS_T_MHQ_RELEASED_TITLE", localize "STR_DUWS_T_MHQ_RELEASED_MSG"]]
	remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
