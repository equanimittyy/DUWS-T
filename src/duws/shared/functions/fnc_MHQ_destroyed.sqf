// Locality: all machines -- inherited from shared/functions/fnc_MHQ_addActions.sqf.

// Released designations end this watch as well as destroyed ones. Both tests are needed: the
// variable is cleared on release, so reading `alive MHQ1` alone would throw, and the generation
// catches the case where a replacement was designated inside one ten-second interval -- without it
// this thread would adopt the new MHQ and tear it down alongside the watcher spawned for it.
params [["_generation", 0]];

waituntil {sleep 10; (missionNamespace getVariable ["MHQ_generation", 0]) != _generation || {isNil "MHQ1"} || {!alive MHQ1}};

if ((missionNamespace getVariable ["MHQ_generation", 0]) != _generation || {isNil "MHQ1"}) exitWith {};

if (MHQ_deployed) then {

	MHQ_respawn call BIS_fnc_removeRespawnPosition;
    MHQ_respawn = nil;
    publicVariable "MHQ_respawn";

	deleteVehicle MHQ_tent;
	deleteVehicle MHQ_ammobox;
	
	MHQ_deployed = false;
	publicVariable "MHQ_deployed";

};

removeAllActions MHQ1;

// Drop both JIP orders so a client joining before the next designation isn't handed a deploy action or map icon
// against the wreck (the release path clears these; destruction is the other way the MHQ ends). This thread runs
// on every machine but the server owns the JIP queue, so clear once there.
if (isServer) then {
    remoteExec ["", "duws_mhq_actions"];
    remoteExec ["", "duws_mhq_marker"];
};

// Stamped here and not on the release path, which this thread never reaches: handing a working
// vehicle back is not what is being priced. Mission time, like every other cooldown here.
MHQ_lockout_until = time + MHQ_lockout_seconds;
publicVariable "MHQ_lockout_until";
["INFO", "SUPPORT", format ["MHQ destroyed: designation locked out for %1 s", MHQ_lockout_seconds]] call fnc_log;

["alert",[localize "STR_DUWS_T_scudflh9",
	format [localize "STR_DUWS_T_MHQ_LOCKOUT", ceil (MHQ_lockout_seconds / 60)]]]
	remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	
